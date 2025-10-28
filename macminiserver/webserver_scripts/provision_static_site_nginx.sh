#!/bin/bash
#
# Static Site Provisioning Script
# Provisions a new static site with nginx and SSL certificates
#
# Usage: ./provision_static_site_nginx.sh <domain.com>
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
section() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}\n"; }

# Check if domain is provided
if [ -z "$1" ]; then
    error "Domain name is required!"
    echo ""
    echo "Usage: $0 <domain.com>"
    echo ""
    echo "Example: $0 nimbus.wtf"
    exit 1
fi

DOMAIN="$1"
USER_NAME=$(whoami)
USER_HOME="$HOME"
SITE_ROOT="$USER_HOME/webserver/sites/$DOMAIN"
PUBLIC_DIR="$SITE_ROOT/public"
NGINX_CONF="/usr/local/etc/nginx/servers/$DOMAIN.conf"
CLOUDFLARE_INI="$USER_HOME/.secrets/cloudflare.ini"

section "Provisioning Static Site: $DOMAIN"

# Verify Cloudflare credentials exist
if [ ! -f "$CLOUDFLARE_INI" ]; then
    error "Cloudflare credentials not found!"
    info "Please run provision_webserver.sh first"
    exit 1
fi

# Create site directory
section "Creating Site Directory"

mkdir -p "$PUBLIC_DIR"
success "Created: $PUBLIC_DIR"

# Create placeholder HTML if doesn't exist
if [ ! -f "$PUBLIC_DIR/index.html" ]; then
    cat > "$PUBLIC_DIR/index.html" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$DOMAIN</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            text-align: center;
            padding: 2rem;
        }
        h1 {
            font-size: 3rem;
            margin-bottom: 1rem;
        }
        p {
            font-size: 1.2rem;
            opacity: 0.9;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>$DOMAIN</h1>
        <p>Site coming soon!</p>
    </div>
</body>
</html>
EOF
    success "Created placeholder index.html"
else
    info "index.html already exists"
fi

# Ask about www subdomain
echo ""
read -p "$(echo -e ${BLUE}Include www.$DOMAIN? [Y/n]: ${NC})" www_response
if [[ "$www_response" =~ ^[Nn]$ ]]; then
    INCLUDE_WWW=false
    CERT_DOMAINS="-d $DOMAIN"
    SERVER_NAMES="$DOMAIN"
else
    INCLUDE_WWW=true
    CERT_DOMAINS="-d $DOMAIN -d www.$DOMAIN"
    SERVER_NAMES="$DOMAIN www.$DOMAIN"
fi

# Request SSL certificate
section "Requesting SSL Certificate"

info "This will request a certificate from Let's Encrypt using Cloudflare DNS"
info "Domains: $CERT_DOMAINS"
echo ""

read -p "$(echo -e ${YELLOW}Proceed with certificate request? [Y/n]: ${NC})" cert_response
if [[ "$cert_response" =~ ^[Nn]$ ]]; then
    warning "Skipping certificate request"
    warning "You'll need to obtain certificates manually"
    SKIP_CERT=true
else
    SKIP_CERT=false
    
    # Request email for Let's Encrypt
    echo -e "${BLUE}Email for Let's Encrypt notifications [default: njoubert@gmail.com]: ${NC}"
    read email
    email="${email:-njoubert@gmail.com}"
    
    info "Requesting certificate..."
    
    if sudo certbot certonly \
        --dns-cloudflare \
        --dns-cloudflare-credentials "$CLOUDFLARE_INI" \
        --dns-cloudflare-propagation-seconds 30 \
        $CERT_DOMAINS \
        --email "$email" \
        --agree-tos \
        --non-interactive; then
        success "Certificate obtained successfully!"
        CERT_PATH="/etc/letsencrypt/live/$DOMAIN"
        
        # Fix certificate directory permissions so nginx can read them
        info "Setting certificate permissions..."
        sudo chmod 755 /etc/letsencrypt/live /etc/letsencrypt/archive
        sudo chmod 755 /etc/letsencrypt/archive/$DOMAIN
        sudo chmod 644 /etc/letsencrypt/archive/$DOMAIN/*.pem
        success "Certificate permissions configured"
    else
        error "Failed to obtain certificate!"
        error "You may need to:"
        error "  1. Verify your Cloudflare API token has DNS edit permissions"
        error "  2. Verify the domain exists in your Cloudflare account"
        error "  3. Check the certbot error log above"
        exit 1
    fi
fi

# Create nginx configuration
section "Creating Nginx Configuration"

if [ "$SKIP_CERT" = true ]; then
    # HTTP only configuration
    cat > /tmp/nginx_site.conf << EOF
# $DOMAIN - HTTP only (no SSL certificate)
server {
    listen 80;
    listen [::]:80;
    server_name $SERVER_NAMES;
    
    root $PUBLIC_DIR;
    index index.html index.htm;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    access_log /usr/local/var/log/nginx/$DOMAIN.access.log;
    error_log /usr/local/var/log/nginx/$DOMAIN.error.log;
}
EOF
else
    # Full HTTPS configuration
    cat > /tmp/nginx_site.conf << EOF
# $DOMAIN - HTTP redirect
server {
    listen 80;
    listen [::]:80;
    server_name $SERVER_NAMES;
    
    # Let's Encrypt ACME challenge
    location /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
    }
    
    # Redirect to HTTPS
    location / {
        return 301 https://\$host\$request_uri;
    }
}

# $DOMAIN - HTTPS
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name $SERVER_NAMES;
    
    # SSL certificate
    ssl_certificate $CERT_PATH/fullchain.pem;
    ssl_certificate_key $CERT_PATH/privkey.pem;
    
    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Site root
    root $PUBLIC_DIR;
    index index.html index.htm;
    
    # Try files
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Logging
    access_log /usr/local/var/log/nginx/$DOMAIN.access.log;
    error_log /usr/local/var/log/nginx/$DOMAIN.error.log;
}
EOF
fi

# Show configuration and ask to install
info "Generated nginx configuration:"
echo ""
cat /tmp/nginx_site.conf
echo ""

read -p "$(echo -e ${YELLOW}Install this configuration? [Y/n]: ${NC})" install_response
if [[ "$install_response" =~ ^[Nn]$ ]]; then
    warning "Configuration not installed"
    info "You can manually copy it from /tmp/nginx_site.conf"
    exit 0
fi

sudo cp /tmp/nginx_site.conf "$NGINX_CONF"
sudo chown "$USER_NAME:staff" "$NGINX_CONF"
success "Configuration installed: $NGINX_CONF"

# Create log files with correct permissions
info "Creating log files..."
NGINX_LOGS="/usr/local/var/log/nginx"
sudo touch "$NGINX_LOGS/$DOMAIN.access.log" "$NGINX_LOGS/$DOMAIN.error.log"
sudo chown "$USER_NAME:staff" "$NGINX_LOGS/$DOMAIN.access.log" "$NGINX_LOGS/$DOMAIN.error.log"
success "Log files created"

# Test nginx configuration
section "Testing Nginx Configuration"

if nginx -t 2>&1 | grep -q "successful"; then
    success "Nginx configuration is valid"
else
    error "Nginx configuration test failed!"
    nginx -t
    exit 1
fi

# Reload nginx
info "Reloading nginx..."
nginx -s reload
success "Nginx reloaded successfully"

# Create README for site
cat > "$SITE_ROOT/README.md" << EOF
# $DOMAIN

## Site Information

- **Domain:** $DOMAIN
- **Public Directory:** $PUBLIC_DIR
- **Nginx Config:** $NGINX_CONF
- **SSL Certificate:** ${SKIP_CERT:+Not configured}${SKIP_CERT:-$CERT_PATH}

## Deployment

To update the site, simply replace the contents of:
\`\`\`
$PUBLIC_DIR
\`\`\`

After updating files, you may want to reload nginx:
\`\`\`bash
~/webserver/scripts/manage-nginx.sh reload
\`\`\`

## Logs

- Access log: \`/usr/local/var/log/nginx/$DOMAIN.access.log\`
- Error log: \`/usr/local/var/log/nginx/$DOMAIN.error.log\`

View logs:
\`\`\`bash
tail -f /usr/local/var/log/nginx/$DOMAIN.access.log
tail -f /usr/local/var/log/nginx/$DOMAIN.error.log
\`\`\`

## SSL Certificate

${SKIP_CERT:+SSL certificate not configured. Run certbot manually to add HTTPS.}${SKIP_CERT:-Certificate is managed automatically by certbot.
Certificate auto-renews via LaunchDaemon (runs at 2am and 2pm daily).

Manual renewal test:
\`\`\`bash
sudo certbot renew --dry-run
\`\`\`}

## DNS Configuration

Make sure your DNS is configured:

1. Go to your Cloudflare DNS settings
2. Add an A record:
   - Name: \`@\` (for $DOMAIN)
   - Content: Your server IP
   - Proxy status: Proxied (orange cloud) ✅
${INCLUDE_WWW:+
3. Add a CNAME record for www:
   - Name: \`www\`
   - Content: \`$DOMAIN\`
   - Proxy status: Proxied (orange cloud) ✅
}

## Testing

Test HTTP redirect (if SSL is configured):
\`\`\`bash
curl -I http://$DOMAIN
\`\`\`

Test HTTPS:
\`\`\`bash
curl -I https://$DOMAIN
\`\`\`

## Site Created

$(date)
EOF

success "Created README: $SITE_ROOT/README.md"

# Summary
section "✅ Site Provisioned Successfully!"

echo ""
info "Site Details:"
echo "  Domain:      $DOMAIN"
echo "  Directory:   $PUBLIC_DIR"
echo "  Config:      $NGINX_CONF"
if [ "$SKIP_CERT" != true ]; then
    echo "  SSL:         ✅ Enabled (auto-renewing)"
else
    echo "  SSL:         ⚠️  Not configured"
fi

echo ""
info "Next Steps:"
echo ""
echo "1. Upload your site content to:"
echo "   $PUBLIC_DIR"
echo ""
echo "2. Configure DNS in Cloudflare:"
echo "   - A record: @ → Your server IP (proxied)"
if [ "$INCLUDE_WWW" = true ]; then
    echo "   - CNAME: www → $DOMAIN (proxied)"
fi
echo ""
echo "3. Test your site:"
if [ "$SKIP_CERT" != true ]; then
    echo "   https://$DOMAIN"
else
    echo "   http://$DOMAIN"
fi
echo ""

success "🎉 $DOMAIN is ready!"
