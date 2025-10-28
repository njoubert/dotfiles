#!/bin/bash
#
# Idempotent Web Server Provisioning Script
# Sets up nginx + certbot + automatic updates + symlinks
#
# Usage: bash provision_webserver.sh
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

# Function to prompt user for input
prompt_user() {
    local prompt="$1"
    local var_name="$2"
    local default="$3"
    local secret="${4:-false}"
    
    if [ -n "$default" ]; then
        if [ "$secret" = "true" ]; then
            read -s -p "$(echo -e ${BLUE}$prompt [default: ****]: ${NC})" input
            echo ""
        else
            read -p "$(echo -e ${BLUE}$prompt [default: $default]: ${NC})" input
        fi
        eval "$var_name=\"${input:-$default}\""
    else
        if [ "$secret" = "true" ]; then
            read -s -p "$(echo -e ${BLUE}$prompt: ${NC})" input
            echo ""
        else
            read -p "$(echo -e ${BLUE}$prompt: ${NC})" input
        fi
        eval "$var_name=\"$input\""
    fi
}

# Function to show diff and ask to overwrite
check_and_write_file() {
    local file_path="$1"
    local new_content="$2"
    local sudo_required="${3:-false}"
    
    if [ -f "$file_path" ]; then
        warning "File already exists: $file_path"
        echo "$new_content" > /tmp/provision_new_file
        
        info "Showing diff (existing vs new):"
        diff -u "$file_path" /tmp/provision_new_file || true
        
        read -p "$(echo -e ${YELLOW}Overwrite this file? [y/N]: ${NC})" response
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

# Detect username
USER_NAME=$(whoami)
USER_HOME="$HOME"

section "Mac Mini Webserver Provisioning v1.0.0"
info "This script will set up nginx, certbot, and automatic certificate management"
info "Running as user: $USER_NAME"
echo ""

# Check prerequisites
section "Phase 1: Checking Prerequisites"

if ! command_exists brew; then
    error "Homebrew is not installed!"
    info "Install it from: https://brew.sh"
    exit 1
fi
success "Homebrew is installed"

if ! command_exists python3; then
    error "Python3 is not installed!"
    info "Install it with: brew install python3"
    exit 1
fi
success "Python3 is installed"

if ! command_exists pip3; then
    error "pip3 is not installed!"
    info "Install it with: brew install python3"
    exit 1
fi
success "pip3 is installed"

# Install packages
section "Phase 2: Installing Core Packages"

if command_exists nginx; then
    info "nginx is already installed"
    nginx -v
else
    info "Installing nginx..."
    brew install nginx
    success "nginx installed"
fi

if command_exists certbot; then
    info "certbot is already installed"
    certbot --version
else
    info "Installing certbot..."
    brew install certbot
    success "certbot installed"
fi

if pip3 list 2>/dev/null | grep -q certbot-dns-cloudflare; then
    info "certbot-dns-cloudflare is already installed"
    pip3 show certbot-dns-cloudflare | grep Version
else
    info "Installing certbot-dns-cloudflare..."
    pip3 install certbot-dns-cloudflare
    success "certbot-dns-cloudflare installed"
fi

# Configure Cloudflare credentials
section "Phase 3: Configuring Cloudflare API"

CLOUDFLARE_INI="$USER_HOME/.secrets/cloudflare.ini"
mkdir -p "$USER_HOME/.secrets"
chmod 700 "$USER_HOME/.secrets"

if [ -f "$CLOUDFLARE_INI" ]; then
    success "Cloudflare credentials file already exists: $CLOUDFLARE_INI"
    read -p "$(echo -e ${YELLOW}Do you want to update it? [y/N]: ${NC})" response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        CREATE_CLOUDFLARE_INI=true
    else
        CREATE_CLOUDFLARE_INI=false
    fi
else
    CREATE_CLOUDFLARE_INI=true
fi

if [ "$CREATE_CLOUDFLARE_INI" = true ]; then
    echo ""
    info "You need a Cloudflare API token with:"
    info "  - Permission: Zone / DNS / Edit"
    info "  - Zone Resources: Include / All zones"
    echo ""
    info "Create one at: https://dash.cloudflare.com/profile/api-tokens"
    echo ""
    
    prompt_user "Enter your Cloudflare API token" CLOUDFLARE_TOKEN "" true
    
    cat > "$CLOUDFLARE_INI" << EOF
# Cloudflare API token for Certbot
dns_cloudflare_api_token = $CLOUDFLARE_TOKEN
EOF
    
    chmod 600 "$CLOUDFLARE_INI"
    success "Cloudflare credentials saved to $CLOUDFLARE_INI"
fi

# Configure Nginx directories
section "Phase 4: Setting Up Nginx Directories"

NGINX_BASE="/usr/local/etc/nginx"
NGINX_SERVERS="$NGINX_BASE/servers"
NGINX_LOGS="/usr/local/var/log/nginx"
NGINX_RUN="/usr/local/var/run"

info "Creating nginx directories..."
sudo mkdir -p "$NGINX_SERVERS"
sudo mkdir -p "$NGINX_LOGS"
sudo mkdir -p "$NGINX_RUN"

# Set ownership
sudo chown -R "$USER_NAME:staff" "$NGINX_BASE"
sudo chown -R "$USER_NAME:staff" "$NGINX_LOGS"
sudo chown -R "$USER_NAME:staff" "$NGINX_RUN"

success "Nginx directories configured"

# Configure main nginx.conf
section "Phase 5: Configuring Main nginx.conf"

NGINX_CONF="$NGINX_BASE/nginx.conf"

read -r -d '' NGINX_CONF_CONTENT << EOF || true
user $USER_NAME staff;
worker_processes auto;

error_log $NGINX_LOGS/error.log;
pid $NGINX_RUN/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include mime.types;
    default_type application/octet-stream;

    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log $NGINX_LOGS/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 4096;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript 
               application/x-javascript application/xml+rss 
               application/json application/javascript;

    # Security headers (defaults for all sites)
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Include all site configurations
    include $NGINX_SERVERS/*.conf;
}
EOF

check_and_write_file "$NGINX_CONF" "$NGINX_CONF_CONTENT" true

# Create hello world site
section "Phase 6: Creating Hello World Test Site"

HELLO_CONF="$NGINX_SERVERS/hello.conf"

read -r -d '' HELLO_CONF_CONTENT << EOF || true
# Hello world test site - responds to direct IP access
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    server_name _;
    
    root $USER_HOME/webserver/sites/hello/public;
    index index.html;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    access_log $NGINX_LOGS/hello.access.log;
    error_log $NGINX_LOGS/hello.error.log;
}
EOF

check_and_write_file "$HELLO_CONF" "$HELLO_CONF_CONTENT" true

# Create hello world HTML
HELLO_HTML="$USER_HOME/webserver/sites/hello/public/index.html"
mkdir -p "$USER_HOME/webserver/sites/hello/public"

if [ ! -f "$HELLO_HTML" ]; then
    cat > "$HELLO_HTML" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Mac Mini Webserver</title>
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
        .status {
            margin-top: 2rem;
            padding: 1rem;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 8px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Webserver is Running!</h1>
        <p>Mac Mini Webserver v1.0.0</p>
        <div class="status">
            <p>✅ Nginx is working</p>
            <p>✅ Ready to add sites</p>
        </div>
    </div>
</body>
</html>
EOF
    success "Hello world HTML created"
else
    info "Hello world HTML already exists"
fi

# Test nginx configuration
info "Testing nginx configuration..."
if nginx -t 2>&1 | grep -q "successful"; then
    success "Nginx configuration is valid"
else
    error "Nginx configuration has errors!"
    nginx -t
    exit 1
fi

# Create nginx LaunchDaemon
section "Phase 7: Setting Up Nginx Auto-Start"

NGINX_PLIST="/Library/LaunchDaemons/com.nginx.nginx.plist"

read -r -d '' NGINX_PLIST_CONTENT << EOF || true
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.nginx.nginx</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/nginx</string>
        <string>-g</string>
        <string>daemon off;</string>
    </array>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>$NGINX_LOGS/nginx-stdout.log</string>
    
    <key>StandardErrorPath</key>
    <string>$NGINX_LOGS/nginx-stderr.log</string>
    
    <key>WorkingDirectory</key>
    <string>/usr/local/var</string>
    
    <key>UserName</key>
    <string>$USER_NAME</string>
    
    <key>GroupName</key>
    <string>staff</string>
</dict>
</plist>
EOF

check_and_write_file "$NGINX_PLIST" "$NGINX_PLIST_CONTENT" true

if [ -f "$NGINX_PLIST" ]; then
    sudo chown root:wheel "$NGINX_PLIST"
    sudo chmod 644 "$NGINX_PLIST"
    success "Nginx LaunchDaemon configured"
    
    # Load the daemon
    if sudo launchctl list 2>/dev/null | grep -q com.nginx.nginx; then
        info "Nginx LaunchDaemon is already loaded"
        read -p "$(echo -e ${YELLOW}Restart nginx now? [Y/n]: ${NC})" response
        if [[ ! "$response" =~ ^[Nn]$ ]]; then
            sudo launchctl unload "$NGINX_PLIST" 2>/dev/null || true
            sleep 2
            sudo launchctl load -w "$NGINX_PLIST"
            success "Nginx restarted"
        fi
    else
        info "Loading Nginx LaunchDaemon..."
        sudo launchctl load -w "$NGINX_PLIST"
        success "Nginx started"
    fi
    
    sleep 2
    if sudo launchctl list | grep -q com.nginx.nginx; then
        success "Nginx is running"
    else
        warning "Nginx may not be running. Check with: sudo launchctl list | grep nginx"
    fi
fi

# Create certbot renewal script and LaunchDaemon
section "Phase 8: Setting Up Certificate Auto-Renewal"

CERTBOT_RENEW_SCRIPT="/usr/local/bin/certbot-renew.sh"

read -r -d '' CERTBOT_RENEW_SCRIPT_CONTENT << 'EOF' || true
#!/bin/bash
# Certbot renewal script with Nginx reload

# Renew certificates
/usr/local/bin/certbot renew --quiet --dns-cloudflare

# If renewal succeeded, reload Nginx
if [ $? -eq 0 ]; then
    /usr/local/bin/nginx -s reload
fi
EOF

check_and_write_file "$CERTBOT_RENEW_SCRIPT" "$CERTBOT_RENEW_SCRIPT_CONTENT" true
sudo chmod +x "$CERTBOT_RENEW_SCRIPT"

CERTBOT_PLIST="/Library/LaunchDaemons/com.certbot.renew.plist"

read -r -d '' CERTBOT_PLIST_CONTENT << EOF || true
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.certbot.renew</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>$CERTBOT_RENEW_SCRIPT</string>
    </array>
    
    <key>StartCalendarInterval</key>
    <array>
        <dict>
            <key>Hour</key>
            <integer>2</integer>
            <key>Minute</key>
            <integer>0</integer>
        </dict>
        <dict>
            <key>Hour</key>
            <integer>14</integer>
            <key>Minute</key>
            <integer>0</integer>
        </dict>
    </array>
    
    <key>StandardOutPath</key>
    <string>$NGINX_LOGS/certbot-renew.log</string>
    
    <key>StandardErrorPath</key>
    <string>$NGINX_LOGS/certbot-renew-error.log</string>
</dict>
</plist>
EOF

check_and_write_file "$CERTBOT_PLIST" "$CERTBOT_PLIST_CONTENT" true

if [ -f "$CERTBOT_PLIST" ]; then
    sudo chown root:wheel "$CERTBOT_PLIST"
    sudo chmod 644 "$CERTBOT_PLIST"
    
    if sudo launchctl list 2>/dev/null | grep -q com.certbot.renew; then
        info "Certbot renewal LaunchDaemon is already loaded"
        sudo launchctl unload "$CERTBOT_PLIST" 2>/dev/null || true
    fi
    sudo launchctl load -w "$CERTBOT_PLIST"
    success "Certbot auto-renewal configured (runs at 2am and 2pm daily)"
fi

# Create auto-update script and LaunchDaemon
section "Phase 9: Setting Up Automatic Updates"

# Store auto_update.sh in dotfiles repo, symlink from webserver/scripts
AUTO_UPDATE_SCRIPT="$USER_HOME/Code/dotfiles/macminiserver/webserver_scripts/auto_update.sh"
AUTO_UPDATE_SYMLINK="$USER_HOME/webserver/scripts/auto_update.sh"

read -r -d '' AUTO_UPDATE_CONTENT << 'SCRIPT_EOF' || true
#!/bin/bash
#
# Automatic Package Update Script
# Updates Homebrew packages and pip3 packages
#

LOG_FILE="/usr/local/var/log/auto-update.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Starting automatic update check ==="

# Update Homebrew itself
log "Updating Homebrew..."
brew update 2>&1 | tee -a "$LOG_FILE"

# Upgrade all Homebrew packages
log "Upgrading Homebrew packages..."
brew upgrade 2>&1 | tee -a "$LOG_FILE"

# Upgrade pip3 packages
log "Upgrading pip3 packages..."
pip3 install --upgrade certbot-dns-cloudflare 2>&1 | tee -a "$LOG_FILE"

# Cleanup
log "Cleaning up old versions..."
brew cleanup 2>&1 | tee -a "$LOG_FILE"

# Check if nginx needs restart
if pgrep -x "nginx" > /dev/null; then
    log "Nginx is running. Reloading configuration..."
    /usr/local/bin/nginx -s reload
    log "Nginx reloaded"
fi

log "=== Update check complete ==="
log ""
SCRIPT_EOF

check_and_write_file "$AUTO_UPDATE_SCRIPT" "$AUTO_UPDATE_CONTENT" false
chmod +x "$AUTO_UPDATE_SCRIPT"

# Create symlink if it doesn't exist
if [ ! -L "$AUTO_UPDATE_SYMLINK" ]; then
    ln -sf "$AUTO_UPDATE_SCRIPT" "$AUTO_UPDATE_SYMLINK"
    success "Created symlink: $AUTO_UPDATE_SYMLINK"
fi

AUTO_UPDATE_PLIST="/Library/LaunchDaemons/com.webserver.autoupdate.plist"

read -r -d '' AUTO_UPDATE_PLIST_CONTENT << EOF || true
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.webserver.autoupdate</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$USER_HOME/Code/dotfiles/macminiserver/webserver_scripts/auto_update.sh</string>
    </array>
    
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>1</integer>
        <key>Hour</key>
        <integer>2</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    
    <key>StandardErrorPath</key>
    <string>$NGINX_LOGS/auto-update-error.log</string>
    
    <key>StandardOutPath</key>
    <string>$NGINX_LOGS/auto-update.log</string>
</dict>
</plist>
EOF

check_and_write_file "$AUTO_UPDATE_PLIST" "$AUTO_UPDATE_PLIST_CONTENT" true

if [ -f "$AUTO_UPDATE_PLIST" ]; then
    sudo chown root:wheel "$AUTO_UPDATE_PLIST"
    sudo chmod 644 "$AUTO_UPDATE_PLIST"
    
    if sudo launchctl list 2>/dev/null | grep -q com.webserver.autoupdate; then
        info "Auto-update LaunchDaemon is already loaded"
        sudo launchctl unload "$AUTO_UPDATE_PLIST" 2>/dev/null || true
    fi
    sudo launchctl load -w "$AUTO_UPDATE_PLIST"
    success "Automatic updates configured (runs every Monday at 2am)"
fi

# Create convenient symlinks
section "Phase 10: Creating Convenient Symlinks"

SYMLINKS_DIR="$USER_HOME/webserver/symlinks"
mkdir -p "$SYMLINKS_DIR"

ln -sf "$NGINX_BASE/nginx.conf" "$SYMLINKS_DIR/nginx.conf"
ln -sf "$NGINX_SERVERS" "$SYMLINKS_DIR/nginx-sites"
ln -sf "$CLOUDFLARE_INI" "$SYMLINKS_DIR/cloudflare.ini"
ln -sf "$NGINX_PLIST" "$SYMLINKS_DIR/nginx.plist"
ln -sf "$CERTBOT_PLIST" "$SYMLINKS_DIR/certbot-renew.plist"
ln -sf "$AUTO_UPDATE_PLIST" "$SYMLINKS_DIR/autoupdate.plist"
ln -sf "$NGINX_LOGS" "$SYMLINKS_DIR/nginx-logs"

if [ -d "/etc/letsencrypt/live" ]; then
    sudo ln -sf "/etc/letsencrypt/live" "$SYMLINKS_DIR/certificates" 2>/dev/null || true
fi

success "Symlinks created in $SYMLINKS_DIR"

# Final summary
section "✅ Provisioning Complete!"

echo ""
success "Nginx is installed and running"
success "Certbot is installed and configured"
success "Cloudflare DNS authentication configured"
success "Auto-renewal enabled (2am and 2pm daily)"
success "Auto-updates enabled (Mondays at 2am)"
success "Convenient symlinks created"

echo ""
info "Quick Access:"
echo "  Config:  ~/webserver/symlinks/nginx.conf"
echo "  Sites:   ~/webserver/symlinks/nginx-sites/"
echo "  Logs:    ~/webserver/symlinks/nginx-logs/"
echo "  Scripts: ~/webserver/scripts/"

echo ""
info "Test your webserver:"
echo "  curl http://localhost"
echo "  # Should show the hello world page"

echo ""
info "Next Steps:"
echo "  1. Use provision_static_site_nginx.sh to add your first real site"
echo "  2. The script will obtain SSL certificates automatically"
echo "  3. Point your domain's DNS to this server"
echo "  4. Visit https://yourdomain.com"

echo ""
info "Management Commands:"
echo "  Start:   ~/webserver/scripts/manage-nginx.sh start"
echo "  Stop:    ~/webserver/scripts/manage-nginx.sh stop"
echo "  Reload:  ~/webserver/scripts/manage-nginx.sh reload"
echo "  Status:  ~/webserver/scripts/manage-nginx.sh status"
echo "  Logs:    ~/webserver/scripts/manage-nginx.sh logs error"

echo ""
success "🎉 Your webserver is ready to host sites!"
