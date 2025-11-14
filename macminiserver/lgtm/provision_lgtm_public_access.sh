#!/bin/bash
#
# Idempotent LGTM Public Access Provisioning Script
# Exposes Grafana via nginx reverse proxy with TLS
#
# Usage: bash provision_lgtm_public_access.sh
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${NC}$1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
section() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}\n"; }

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to show diff and ask to overwrite
check_and_write_file() {
    local file_path="$1"
    local new_content="$2"
    local sudo_required="${3:-false}"
    
    if [ -f "$file_path" ]; then
        echo "$new_content" > /tmp/provision_new_file
        
        # Check if files are identical
        if diff -q "$file_path" /tmp/provision_new_file > /dev/null 2>&1; then
            info "File already exists and is up-to-date: $file_path"
            rm -f /tmp/provision_new_file
            return 0
        fi
        
        # Files differ, show diff and prompt
        warning "File already exists: $file_path"
        info "Showing diff (existing vs new):"
        diff -u "$file_path" /tmp/provision_new_file || true
        
        read -r -p "$(echo -e "${YELLOW}Overwrite this file? [y/N]: ${NC}")" response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            if [ "$sudo_required" = "true" ]; then
                echo "$new_content" | sudo tee "$file_path" > /dev/null
            else
                echo "$new_content" > "$file_path"
            fi
            success "File updated: $file_path"
        else
            info "Skipped: $file_path"
        fi
        rm -f /tmp/provision_new_file
    else
        if [ "$sudo_required" = "true" ]; then
            echo "$new_content" | sudo tee "$file_path" > /dev/null
        else
            echo "$new_content" > "$file_path"
        fi
        success "File created: $file_path"
    fi
}

# Function to check if a string exists in a file
string_in_file() {
    local file="$1"
    local search_string="$2"
    
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    grep -qF "$search_string" "$file"
}

# Detect username
USER_NAME=$(whoami)
USER_HOME="$HOME"

section "LGTM Public Access Provisioning v1.0.0"
info "This script will expose Grafana via nginx reverse proxy with TLS"
info "Running as user: $USER_NAME"
echo ""

# Check prerequisites
section "Phase 1: Checking Prerequisites"

if ! command_exists nginx; then
    error "nginx is not installed!"
    info "Please run provision_webserver.sh first"
    exit 1
fi
success "nginx is installed"

if ! command_exists certbot; then
    error "certbot is not installed!"
    info "Please run provision_webserver.sh first"
    exit 1
fi
success "certbot is installed"

# Check if Grafana is running
if ! curl -s http://127.0.0.1:3000/api/health > /dev/null 2>&1; then
    error "Grafana is not responding on localhost:3000"
    info "Please run provision_lgtm_stack.sh first and ensure Grafana is running"
    exit 1
fi
success "Grafana is running on localhost:3000"

# Check if nginx is managed by LaunchDaemon
if [ ! -f "/Library/LaunchDaemons/com.nginx.nginx.plist" ]; then
    warning "nginx LaunchDaemon not found"
    info "This script assumes nginx is already set up via provision_webserver.sh"
fi

# Confirm with user
section "Phase 2: Confirmation"

echo ""
warning "This will expose Grafana to the public internet via HTTPS!"
info ""
info "Configuration details:"
info "  • Service:  Grafana (localhost:3000)"
info "  • URL:      https://grafana.nielsshootsfilm.com"
info "  • Method:   nginx reverse proxy with TLS termination"
info "  • Security: Let's Encrypt SSL certificate"
info ""
info "You will need to:"
info "  1. Add DNS record in Cloudflare: grafana.nielsshootsfilm.com → your public IP"
info "  2. Decide whether to use Cloudflare proxy (orange cloud) or DNS-only (gray cloud)"
info "     - Orange cloud: DDoS protection, but Cloudflare sees all traffic"
info "     - Gray cloud: Direct connection, lower latency, no Cloudflare logs"
info ""

read -r -p "$(echo -e "${YELLOW}Expose grafana:3000 on TLS at https://grafana.nielsshootsfilm.com through nginx reverse proxy? [y/N]: ${NC}")" response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    info "Aborted by user"
    exit 0
fi

echo ""
success "Proceeding with Grafana public access configuration..."

# Configure Grafana for reverse proxy
section "Phase 3: Configuring Grafana for Reverse Proxy"

GRAFANA_INI="/usr/local/etc/grafana/grafana.ini"

if [ ! -f "$GRAFANA_INI" ]; then
    error "Grafana configuration not found at $GRAFANA_INI"
    exit 1
fi

# Check if Grafana is already configured for reverse proxy
if grep -q "^root_url = https://grafana.nielsshootsfilm.com" "$GRAFANA_INI"; then
    info "Grafana already configured with root_url"
else
    warning "Grafana needs to be configured with root_url for reverse proxy"
    info "Adding root_url to [server] section..."
    
    # Check if root_url exists (commented or not)
    if grep -q "root_url" "$GRAFANA_INI"; then
        # Replace existing root_url
        sudo sed -i.bak 's|^;*root_url =.*|root_url = https://grafana.nielsshootsfilm.com|' "$GRAFANA_INI"
    else
        # Add root_url after domain line
        sudo sed -i.bak '/^domain = /a\
root_url = https://grafana.nielsshootsfilm.com' "$GRAFANA_INI"
    fi
    
    success "Grafana configuration updated"
    
    # Restart Grafana
    info "Restarting Grafana to apply changes..."
    if sudo launchctl list 2>/dev/null | grep -q com.grafana.grafana; then
        sudo launchctl kickstart -k system/com.grafana.grafana
        sleep 2
        if curl -s http://127.0.0.1:3000/api/health > /dev/null 2>&1; then
            success "Grafana restarted successfully"
        else
            error "Grafana failed to restart"
            info "Check logs: tail -f /usr/local/var/log/grafana/grafana.log"
            exit 1
        fi
    else
        warning "Grafana LaunchDaemon not running, skipping restart"
    fi
fi

# Create nginx configuration for subdomain
section "Phase 4: Creating nginx Configuration"

NGINX_CONF_DIR="/usr/local/etc/nginx/servers"
GRAFANA_NGINX_CONF="$NGINX_CONF_DIR/grafana.nielsshootsfilm.com.conf"

sudo mkdir -p "$NGINX_CONF_DIR"

read -r -d '' GRAFANA_NGINX_CONFIG << 'EOF' || true
# grafana.nielsshootsfilm.com - HTTP redirect
server {
    listen 80;
    listen [::]:80;
    server_name grafana.nielsshootsfilm.com;

    # Let's Encrypt ACME challenge
    location /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
    }

    # Redirect to HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}

# grafana.nielsshootsfilm.com - HTTPS reverse proxy
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name grafana.nielsshootsfilm.com;

    # SSL certificate (using wildcard cert for *.nielsshootsfilm.com)
    ssl_certificate /etc/letsencrypt/live/nielsshootsfilm.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/nielsshootsfilm.com/privkey.pem;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Logging
    access_log /usr/local/var/log/nginx/grafana.nielsshootsfilm.com-access.log;
    error_log /usr/local/var/log/nginx/grafana.nielsshootsfilm.com-error.log;

    # Reverse proxy to Grafana
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support (for live updates)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

check_and_write_file "$GRAFANA_NGINX_CONF" "$GRAFANA_NGINX_CONFIG" true

# Test nginx configuration
info "Testing nginx configuration..."
if sudo nginx -t 2>&1 | grep -q "successful"; then
    success "nginx configuration is valid"
else
    error "nginx configuration has errors!"
    sudo nginx -t
    exit 1
fi

# Reload nginx
info "Reloading nginx..."
if sudo launchctl list 2>/dev/null | grep -q com.nginx.nginx; then
    sudo launchctl kickstart -k system/com.nginx.nginx
    success "nginx reloaded"
else
    sudo nginx -s reload
    success "nginx reloaded"
fi

# Configure SSL certificate
section "Phase 5: Configuring SSL Certificate"

# Check if wildcard certificate already exists
if [ -d "/etc/letsencrypt/live/nielsshootsfilm.com" ]; then
    # Check if it's a wildcard cert
    if sudo certbot certificates 2>/dev/null | grep -A 3 "Certificate Name: nielsshootsfilm.com" | grep -q "\*.nielsshootsfilm.com"; then
        success "Wildcard certificate exists for *.nielsshootsfilm.com"
        
        # Show expiry date
        EXPIRY=$(sudo certbot certificates 2>/dev/null | grep -A 5 "Certificate Name: nielsshootsfilm.com" | grep "Expiry Date" | awk '{print $3, $4}')
        info "Certificate expires: $EXPIRY"
        info "This wildcard cert covers grafana.nielsshootsfilm.com"
    else
        warning "Certificate exists but is NOT a wildcard cert"
        info "Current cert only covers: $(sudo certbot certificates 2>/dev/null | grep -A 3 'Certificate Name: nielsshootsfilm.com' | grep Domains | cut -d: -f2)"
        info ""
        info "You need a wildcard certificate for *.nielsshootsfilm.com"
        info ""
        
        read -r -p "$(echo -e "${YELLOW}Obtain wildcard SSL certificate now? [y/N]: ${NC}")" response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            info "Obtaining wildcard SSL certificate via Let's Encrypt with DNS-01 challenge..."
            
            # Check for Cloudflare credentials
            if [ ! -f "$USER_HOME/.secrets/cloudflare.ini" ]; then
                error "Cloudflare credentials not found at $USER_HOME/.secrets/cloudflare.ini"
                info "Run provision_webserver.sh first to configure Cloudflare API"
                exit 1
            fi
            
            # Run certbot with DNS challenge
            sudo certbot certonly \
                --dns-cloudflare \
                --dns-cloudflare-credentials "$USER_HOME/.secrets/cloudflare.ini" \
                --email njoubert@gmail.com \
                --agree-tos \
                --no-eff-email \
                -d "nielsshootsfilm.com" \
                -d "*.nielsshootsfilm.com"
            
            if sudo certbot certificates 2>/dev/null | grep -A 3 "Certificate Name: nielsshootsfilm.com" | grep -q "\*.nielsshootsfilm.com"; then
                success "Wildcard SSL certificate obtained successfully!"
                
                # Reload nginx to use the new certificate
                info "Reloading nginx to apply SSL certificate..."
                if sudo launchctl list 2>/dev/null | grep -q com.nginx.nginx; then
                    sudo launchctl kickstart -k system/com.nginx.nginx
                else
                    sudo nginx -s reload
                fi
                success "nginx reloaded with wildcard SSL certificate"
            else
                error "Failed to obtain wildcard SSL certificate"
                info "Check the error messages above"
                exit 1
            fi
        else
            warning "Skipped wildcard SSL certificate generation"
            info "Run this command later to obtain the wildcard certificate:"
            info "  sudo certbot certonly --dns-cloudflare --dns-cloudflare-credentials ~/.secrets/cloudflare.ini -d 'nielsshootsfilm.com' -d '*.nielsshootsfilm.com'"
        fi
    fi
else
    error "No certificate found for nielsshootsfilm.com"
    info "You need to obtain a wildcard certificate for *.nielsshootsfilm.com"
    info ""
    
    read -r -p "$(echo -e "${YELLOW}Obtain wildcard SSL certificate now? [y/N]: ${NC}")" response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        info "Obtaining wildcard SSL certificate via Let's Encrypt with DNS-01 challenge..."
        
        # Check for Cloudflare credentials
        if [ ! -f "$USER_HOME/.secrets/cloudflare.ini" ]; then
            error "Cloudflare credentials not found at $USER_HOME/.secrets/cloudflare.ini"
            info "Run provision_webserver.sh first to configure Cloudflare API"
            exit 1
        fi
        
        # Run certbot with DNS challenge
        sudo certbot certonly \
            --dns-cloudflare \
            --dns-cloudflare-credentials "$USER_HOME/.secrets/cloudflare.ini" \
            --email njoubert@gmail.com \
            --agree-tos \
            --no-eff-email \
            -d "nielsshootsfilm.com" \
            -d "*.nielsshootsfilm.com"
        
        if [ -d "/etc/letsencrypt/live/nielsshootsfilm.com" ]; then
            success "Wildcard SSL certificate obtained successfully!"
            
            # Reload nginx to use the new certificate
            info "Reloading nginx to apply SSL certificate..."
            if sudo launchctl list 2>/dev/null | grep -q com.nginx.nginx; then
                sudo launchctl kickstart -k system/com.nginx.nginx
            else
                sudo nginx -s reload
            fi
            success "nginx reloaded with wildcard SSL certificate"
        else
            error "Failed to obtain wildcard SSL certificate"
            info "Check the error messages above"
            exit 1
        fi
    else
        warning "Skipped wildcard SSL certificate generation"
        info "Run this command later to obtain the wildcard certificate:"
        info "  sudo certbot certonly --dns-cloudflare --dns-cloudflare-credentials ~/.secrets/cloudflare.ini -d 'nielsshootsfilm.com' -d '*.nielsshootsfilm.com'"
    fi
fi

# Verify the setup
section "Phase 6: Verification"

info "Verifying configuration..."
echo ""

# Check if nginx is running
if pgrep -x "nginx" > /dev/null; then
    success "✓ nginx is running"
else
    error "✗ nginx is not running"
fi

# Check if Grafana is running
if curl -s http://127.0.0.1:3000/api/health > /dev/null 2>&1; then
    success "✓ Grafana is responding on localhost:3000"
else
    error "✗ Grafana is not responding"
fi

# Check if nginx config exists
if [ -f "$GRAFANA_NGINX_CONF" ]; then
    success "✓ nginx configuration exists"
else
    error "✗ nginx configuration missing"
fi

# Check if wildcard certificate exists
if [ -d "/etc/letsencrypt/live/nielsshootsfilm.com" ] && sudo certbot certificates 2>/dev/null | grep -A 3 "Certificate Name: nielsshootsfilm.com" | grep -q "\*.nielsshootsfilm.com"; then
    success "✓ Wildcard SSL certificate exists (covers grafana.nielsshootsfilm.com)"
else
    warning "⚠ Wildcard SSL certificate not yet obtained"
fi

echo ""

# Try to connect to the site
info "Testing connection to https://grafana.nielsshootsfilm.com..."
if curl -s -o /dev/null -w "%{http_code}" https://grafana.nielsshootsfilm.com 2>/dev/null | grep -q "200\|301\|302"; then
    success "✓ Site is accessible via HTTPS"
else
    warning "⚠ Site is not yet accessible (this is expected if DNS is not configured)"
fi

# Final summary
section "✅ Grafana Public Access Configuration Complete!"

echo ""
success "Grafana is now configured for public access via nginx reverse proxy"

echo ""
info "Configuration Summary:"
echo "  • Grafana URL:       https://grafana.nielsshootsfilm.com"
echo "  • Backend:           localhost:3000"
echo "  • nginx config:      $GRAFANA_NGINX_CONF"
echo "  • Grafana config:    $GRAFANA_INI"
echo "  • SSL certificate:   /etc/letsencrypt/live/nielsshootsfilm.com/ (wildcard)"

echo ""
info "Next Steps:"
echo "  1. Add wildcard DNS record in Cloudflare (if not already present):"
echo "     - Type: A"
echo "     - Name: *"
echo "     - Content: [your public IP]"
echo "     - Proxy status: Gray cloud (DNS only) recommended for wildcard"
echo "     Note: Wildcard covers grafana.nielsshootsfilm.com and all other subdomains"
echo ""
echo "  2. If you chose gray cloud (DNS only), no additional setup needed"
echo "     If you chose orange cloud (proxied), Cloudflare will handle SSL"
echo ""
echo "  3. Test access: https://grafana.nielsshootsfilm.com"
echo "     - Should redirect to Grafana login page"
echo "     - Username: admin"
echo "     - Password: [check ~/webserver/symlinks/monitoring/grafana.ini]"
echo ""
echo "  4. The SSL certificate will auto-renew via certbot"
echo "     (managed by the certbot LaunchDaemon)"

echo ""
info "Security Notes:"
echo "  • Grafana is now publicly accessible - ensure strong password"
echo "  • Consider enabling Grafana's built-in auth (GitHub, Google, etc.)"
echo "  • Monitor access logs: tail -f /usr/local/var/log/nginx/grafana.nielsshootsfilm.com-access.log"
echo "  • WebSocket support is enabled for live dashboard updates"

echo ""
info "Troubleshooting:"
echo "  • Test locally: curl -H 'Host: grafana.nielsshootsfilm.com' http://localhost"
echo "  • Check nginx: sudo nginx -t && tail -f /usr/local/var/log/nginx/error.log"
echo "  • Check Grafana: tail -f /usr/local/var/log/grafana/grafana.log"
echo "  • Test SSL: curl -v https://grafana.nielsshootsfilm.com"

echo ""
success "🎉 Grafana is ready for public access!"
