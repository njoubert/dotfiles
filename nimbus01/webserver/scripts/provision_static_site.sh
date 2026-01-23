#!/bin/bash

################################################################################
# Static Site Provisioning Script for nginx on Ubuntu
# Usage: sudo ./provision_static_site.sh <domain> [email] [source_dir]
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "${BLUE}==>${NC} $1"; }

# Check root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <domain> [email] [source_dir]"
    echo ""
    echo "Arguments:"
    echo "  domain     - The domain name (e.g., example.com)"
    echo "  email      - Email for Let's Encrypt notifications (default: admin@domain)"
    echo "  source_dir - Optional directory to copy static files from"
    echo ""
    echo "Examples:"
    echo "  $0 mysite.com"
    echo "  $0 mysite.com admin@mysite.com"
    echo "  $0 mysite.com admin@mysite.com /path/to/static/files"
    exit 1
fi

DOMAIN="$1"
EMAIL="${2:-admin@$DOMAIN}"
SOURCE_DIR="${3:-}"
SITE_ROOT="/var/www/$DOMAIN"
PUBLIC_DIR="$SITE_ROOT/public"
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
CLOUDFLARE_CREDS="/etc/letsencrypt/cloudflare/credentials.ini"

echo ""
log_section "Provisioning Static Site: $DOMAIN"
echo ""

# Verify prerequisites
if [ ! -f "$CLOUDFLARE_CREDS" ]; then
    log_error "Cloudflare credentials not found at $CLOUDFLARE_CREDS"
    log_error "Please create credentials file first (see nginx_webserver_plan.md Phase 2)"
    exit 1
fi

# Step 1: Create directory structure
log_section "Step 1: Creating directory structure"
mkdir -p "$PUBLIC_DIR"
chown -R www-data:www-data "$SITE_ROOT"
chmod -R 755 "$SITE_ROOT"
log_info "Created $PUBLIC_DIR"

# Step 2: Copy content or create placeholder
log_section "Step 2: Setting up content"
if [ -n "$SOURCE_DIR" ] && [ -d "$SOURCE_DIR" ]; then
    cp -r "$SOURCE_DIR/"* "$PUBLIC_DIR/"
    chown -R www-data:www-data "$PUBLIC_DIR"
    log_info "Copied content from $SOURCE_DIR"
elif [ ! -f "$PUBLIC_DIR/index.html" ]; then
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
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container { text-align: center; }
        h1 { font-size: 3em; margin-bottom: 0.2em; }
        p { font-size: 1.2em; opacity: 0.9; }
    </style>
</head>
<body>
    <div class="container">
        <h1>$DOMAIN</h1>
        <p>Site is live! Replace this page with your content.</p>
        <p><small>Served by nginx on nimbus01</small></p>
    </div>
</body>
</html>
EOF
    chown www-data:www-data "$PUBLIC_DIR/index.html"
    log_info "Created placeholder index.html"
else
    log_info "Content already exists, skipping"
fi

# Step 3: Request SSL certificate
log_section "Step 3: Requesting SSL certificate"
if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    log_info "Certificate already exists for $DOMAIN"
else
    certbot certonly \
        --dns-cloudflare \
        --dns-cloudflare-credentials "$CLOUDFLARE_CREDS" \
        --dns-cloudflare-propagation-seconds 30 \
        -d "$DOMAIN" \
        --non-interactive \
        --agree-tos \
        --email "$EMAIL"
    log_info "SSL certificate obtained"
fi

# Step 4: Create nginx configuration
log_section "Step 4: Creating nginx configuration"
cat > "$NGINX_CONF" << EOF
# Static site: $DOMAIN
# Generated: $(date)

# HTTP - redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

# HTTPS - static site
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;

    # SSL certificates (Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/nginx/snippets/ssl-params.conf;

    # Document root
    root $PUBLIC_DIR;
    index index.html index.htm;

    # Logging
    access_log /var/log/nginx/${DOMAIN}.access.log main;
    error_log /var/log/nginx/${DOMAIN}.error.log;

    # Rate limiting
    limit_req zone=general burst=20 nodelay;

    # Main location
    location / {
        try_files \$uri \$uri/ =404;
    }

    # Cache static assets aggressively
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|webp|avif)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Security: deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF
log_info "Created nginx config at $NGINX_CONF"

# Step 5: Enable site
log_section "Step 5: Enabling site"
ln -sf "$NGINX_CONF" "/etc/nginx/sites-enabled/$DOMAIN"
log_info "Enabled site"

# Step 6: Test and reload
log_section "Step 6: Testing and reloading nginx"
if nginx -t; then
    systemctl reload nginx
    log_info "nginx reloaded successfully"
else
    log_error "nginx configuration test failed!"
    rm -f "/etc/nginx/sites-enabled/$DOMAIN"
    exit 1
fi

# Summary
echo ""
log_section "Site Provisioned Successfully!"
echo ""
echo "  Domain:      https://$DOMAIN"
echo "  Root:        $PUBLIC_DIR"
echo "  Config:      $NGINX_CONF"
echo "  Access log:  /var/log/nginx/${DOMAIN}.access.log"
echo "  Error log:   /var/log/nginx/${DOMAIN}.error.log"
echo ""
echo "Next steps:"
echo "  1. Point DNS for $DOMAIN to this server (via Cloudflare)"
echo "  2. Replace $PUBLIC_DIR/index.html with your content"
echo ""
