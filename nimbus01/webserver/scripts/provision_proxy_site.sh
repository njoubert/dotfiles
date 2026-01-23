#!/bin/bash

################################################################################
# Reverse Proxy Site Provisioning Script for nginx on Ubuntu
# Usage: sudo ./provision_proxy_site.sh <domain> <upstream_port> [email] [type]
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
if [ $# -lt 2 ]; then
    echo "Usage: $0 <domain> <upstream_port> [email] [type]"
    echo ""
    echo "Arguments:"
    echo "  domain        - The domain name (e.g., api.example.com)"
    echo "  upstream_port - Port the backend service runs on (e.g., 8080)"
    echo "  email         - Email for Let's Encrypt (default: admin@domain)"
    echo "  type          - Service type: api, app, websocket (default: api)"
    echo ""
    echo "Examples:"
    echo "  $0 api.mysite.com 8080"
    echo "  $0 app.mysite.com 3000 admin@mysite.com app"
    echo "  $0 ws.mysite.com 9000 admin@mysite.com websocket"
    exit 1
fi

DOMAIN="$1"
UPSTREAM_PORT="$2"
EMAIL="${3:-admin@$DOMAIN}"
SERVICE_TYPE="${4:-api}"
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
CLOUDFLARE_CREDS="/etc/letsencrypt/cloudflare/credentials.ini"

# Sanitize domain for use as upstream name
UPSTREAM_NAME=$(echo "$DOMAIN" | tr '.' '_' | tr '-' '_')

echo ""
log_section "Provisioning Reverse Proxy: $DOMAIN → localhost:$UPSTREAM_PORT"
echo ""

# Verify prerequisites
if [ ! -f "$CLOUDFLARE_CREDS" ]; then
    log_error "Cloudflare credentials not found at $CLOUDFLARE_CREDS"
    exit 1
fi

# Check if upstream is reachable (warning only)
log_section "Step 1: Checking upstream service"
if curl -s --connect-timeout 2 "http://127.0.0.1:$UPSTREAM_PORT" > /dev/null 2>&1; then
    log_info "Upstream service is responding on port $UPSTREAM_PORT"
else
    log_warn "Upstream service not responding on port $UPSTREAM_PORT"
    log_warn "Make sure your service is running before using the site"
fi

# Step 2: Request SSL certificate
log_section "Step 2: Requesting SSL certificate"
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

# Step 3: Create nginx configuration based on type
log_section "Step 3: Creating nginx configuration (type: $SERVICE_TYPE)"

# Generate type-specific settings
case "$SERVICE_TYPE" in
    api)
        RATE_LIMIT="limit_req zone=api burst=50 nodelay;"
        EXTRA_LOCATIONS=""
        ;;
    app)
        RATE_LIMIT="limit_req zone=general burst=20 nodelay;"
        EXTRA_LOCATIONS="
    # Health check endpoint (no rate limit)
    location /health {
        include /etc/nginx/snippets/proxy-params.conf;
        proxy_pass http://${UPSTREAM_NAME}_upstream;
        limit_req off;
    }"
        ;;
    websocket)
        RATE_LIMIT="limit_req zone=general burst=20 nodelay;"
        EXTRA_LOCATIONS="
    # WebSocket-specific tuning
    location /ws {
        include /etc/nginx/snippets/proxy-params.conf;
        proxy_pass http://${UPSTREAM_NAME}_upstream;
        
        # Extended timeouts for WebSocket
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }"
        ;;
    *)
        log_error "Unknown service type: $SERVICE_TYPE"
        exit 1
        ;;
esac

cat > "$NGINX_CONF" << EOF
# Reverse proxy: $DOMAIN → localhost:$UPSTREAM_PORT
# Type: $SERVICE_TYPE
# Generated: $(date)

# Upstream definition
upstream ${UPSTREAM_NAME}_upstream {
    server 127.0.0.1:$UPSTREAM_PORT;
    keepalive 32;
}

# HTTP - redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

# HTTPS - reverse proxy
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;

    # SSL certificates (Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/nginx/snippets/ssl-params.conf;

    # Logging
    access_log /var/log/nginx/${DOMAIN}.access.log main;
    error_log /var/log/nginx/${DOMAIN}.error.log;

    # Rate limiting
    $RATE_LIMIT

    # Main proxy location
    location / {
        include /etc/nginx/snippets/proxy-params.conf;
        proxy_pass http://${UPSTREAM_NAME}_upstream;
    }
$EXTRA_LOCATIONS
}
EOF
log_info "Created nginx config at $NGINX_CONF"

# Step 4: Enable site
log_section "Step 4: Enabling site"
ln -sf "$NGINX_CONF" "/etc/nginx/sites-enabled/$DOMAIN"
log_info "Enabled site"

# Step 5: Test and reload
log_section "Step 5: Testing and reloading nginx"
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
log_section "Reverse Proxy Provisioned Successfully!"
echo ""
echo "  Domain:      https://$DOMAIN"
echo "  Upstream:    http://127.0.0.1:$UPSTREAM_PORT"
echo "  Type:        $SERVICE_TYPE"
echo "  Config:      $NGINX_CONF"
echo "  Access log:  /var/log/nginx/${DOMAIN}.access.log"
echo "  Error log:   /var/log/nginx/${DOMAIN}.error.log"
echo ""
echo "Next steps:"
echo "  1. Point DNS for $DOMAIN to this server (via Cloudflare)"
echo "  2. Ensure your backend service is running on port $UPSTREAM_PORT"
echo ""
