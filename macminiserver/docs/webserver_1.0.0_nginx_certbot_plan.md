# Nginx + Certbot + Cloudflare DNS - Implementation Plan

**Date:** October 27, 2025  
**Goal:** Set up a fully automated webserver with HTTPS that requires zero manual maintenance

## Overview

This plan replaces Caddy with Nginx + Certbot to achieve:
- ✅ Automatic HTTPS certificates via Let's Encrypt
- ✅ Cloudflare DNS-01 challenge (keeps Cloudflare proxy enabled)
- ✅ Automatic updates via Homebrew (both Nginx and Certbot)
- ✅ Automatic certificate renewals via cron
- ✅ Zero manual maintenance

## Architecture

```
Internet → Cloudflare Proxy (DDoS, CDN) → Mac Mini
           (Orange Cloud)                   ↓
                                         Nginx (serves sites)
                                            ↓
                                         Certbot (manages SSL certs)
                                            ↓
                                         Cloudflare API (DNS-01 challenge)
```

**Key Components:**
1. **Nginx** - Web server (from Homebrew)
2. **Certbot** - Certificate manager (from Homebrew)
3. **certbot-dns-cloudflare** - Cloudflare DNS plugin (from pip3)
4. **LaunchDaemon** - Auto-start Nginx at boot
5. **Cron job** - Auto-renew certificates

## Why This Works

### Automatic Updates ✅
- **Nginx updates:** `brew upgrade nginx` (Homebrew handles this)
- **Certbot updates:** `brew upgrade certbot` (Homebrew handles this)
- **Plugin updates:** `pip3 install --upgrade certbot-dns-cloudflare` (can add to cron)
- **All independent** - No custom builds, no version conflicts

### Automatic Certificate Renewal ✅
- Certbot installs a renewal cron job automatically
- Runs twice daily, renews certs within 30 days of expiry
- Reloads Nginx after successful renewal
- No manual intervention needed

### Cloudflare Integration ✅
- Certbot uses Cloudflare API to create DNS TXT records
- Let's Encrypt validates via DNS (no need to reach your server)
- Cloudflare proxy stays enabled (orange cloud)
- You keep DDoS protection, CDN, hidden IP

---

## Phase 1: Install Core Components

### 1.1 Install Nginx

```bash
# Install via Homebrew
brew install nginx

# Verify installation
nginx -v
# Should show: nginx version: nginx/1.x.x

# Check default locations
which nginx
# Should show: /usr/local/bin/nginx (Intel) or /opt/homebrew/bin/nginx (Apple Silicon)

ls -la /usr/local/etc/nginx/
# Should show nginx.conf and other config files
```

**Configuration locations:**
- Binary: `/usr/local/bin/nginx`
- Config: `/usr/local/etc/nginx/nginx.conf`
- Sites: `/usr/local/etc/nginx/servers/` (we'll create this)
- Logs: `/usr/local/var/log/nginx/`
- Web root: We'll use `~/webserver/sites/` (keep existing structure)

### 1.2 Install Certbot

```bash
# Install via Homebrew
brew install certbot

# Verify installation
certbot --version
# Should show: certbot 2.x.x

# Check location
which certbot
# Should show: /usr/local/bin/certbot
```

### 1.3 Install Cloudflare DNS Plugin

```bash
# Install via pip3 (Python package manager)
pip3 install certbot-dns-cloudflare

# Verify installation
pip3 list | grep certbot-dns-cloudflare
# Should show: certbot-dns-cloudflare x.x.x

# Check plugin is recognized
certbot plugins
# Should show: dns-cloudflare in the list
```

**Why pip3 and not Homebrew?**
- Certbot plugins are Python packages
- pip3 is the standard way to install them
- pip3 integrates with Certbot automatically
- Updates independently from core Certbot

---

## Phase 2: Configure Cloudflare Credentials

### 2.1 Create Cloudflare Credentials File

```bash
# Create secure directory for credentials
mkdir -p ~/.secrets
chmod 700 ~/.secrets

# Create credentials file
cat > ~/.secrets/cloudflare.ini << 'EOF'
# Cloudflare API token for Certbot
dns_cloudflare_api_token = YOUR_CLOUDFLARE_API_TOKEN_HERE
EOF

# Secure the file (important!)
chmod 600 ~/.secrets/cloudflare.ini
```

**Security notes:**
- File must be mode 600 (only owner can read/write)
- Never commit this file to git
- Keep your Cloudflare token safe

### 2.2 Verify Cloudflare Token

The token we already created in Phase 1.8 should work. It needs:
- Permission: `Zone / DNS / Edit`
- Zone Resources: `Include / All zones` (or specific zones)

**Test the token works:**
```bash
# This will test the credentials without creating certificates
certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials ~/.secrets/cloudflare.ini \
  --dry-run \
  -d test.nimbus.wtf
```

If it succeeds, you're good to go!

---

## Phase 3: Configure Nginx

### 3.1 Create Directory Structure

```bash
# Create sites directory for individual site configs
sudo mkdir -p /usr/local/etc/nginx/servers

# Create logs directory
mkdir -p /usr/local/var/log/nginx

# Set ownership
sudo chown -R $(whoami):staff /usr/local/etc/nginx
sudo chown -R $(whoami):staff /usr/local/var/log/nginx
```

### 3.2 Create Main nginx.conf

```bash
# Backup original
sudo cp /usr/local/etc/nginx/nginx.conf /usr/local/etc/nginx/nginx.conf.original

# Create our nginx.conf
sudo tee /usr/local/etc/nginx/nginx.conf << 'EOF'
user njoubert staff;
worker_processes auto;

error_log /usr/local/var/log/nginx/error.log;
pid /usr/local/var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /usr/local/var/log/nginx/access.log main;

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
    include /usr/local/etc/nginx/servers/*.conf;
}
EOF
```

**Note:** Replace `njoubert` with your actual username.

### 3.3 Create Hello World Site Config

```bash
# Create hello world site configuration
sudo tee /usr/local/etc/nginx/servers/hello.conf << 'EOF'
# Hello world test site - responds to direct IP access
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    server_name _;
    
    root /Users/njoubert/webserver/sites/hello/public;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    access_log /usr/local/var/log/nginx/hello.access.log;
    error_log /usr/local/var/log/nginx/hello.error.log;
}
EOF
```

### 3.4 Test Nginx Configuration

```bash
# Test configuration syntax
nginx -t
# Should show: test is successful

# Start Nginx manually for testing
nginx

# Test it works
curl http://localhost
# Should show hello world HTML

# Check logs
tail /usr/local/var/log/nginx/access.log
tail /usr/local/var/log/nginx/error.log

# Stop Nginx
nginx -s stop
```

---

## Phase 4: Set Up LaunchDaemon for Nginx

### 4.1 Create LaunchDaemon Plist

```bash
# Create LaunchDaemon for Nginx
sudo tee /Library/LaunchDaemons/com.nginx.nginx.plist << 'EOF'
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
    <string>/usr/local/var/log/nginx/nginx-stdout.log</string>
    
    <key>StandardErrorPath</key>
    <string>/usr/local/var/log/nginx/nginx-stderr.log</string>
    
    <key>WorkingDirectory</key>
    <string>/usr/local/var</string>
    
    <key>UserName</key>
    <string>njoubert</string>
    
    <key>GroupName</key>
    <string>staff</string>
</dict>
</plist>
EOF

# Set permissions
sudo chown root:wheel /Library/LaunchDaemons/com.nginx.nginx.plist
sudo chmod 644 /Library/LaunchDaemons/com.nginx.nginx.plist
```

**Note:** Replace `njoubert` with your actual username and `/usr/local/bin/nginx` with output from `which nginx`.

### 4.2 Load LaunchDaemon

```bash
# Load the LaunchDaemon
sudo launchctl load -w /Library/LaunchDaemons/com.nginx.nginx.plist

# Verify it's running
sudo launchctl list | grep nginx
# Should show: com.nginx.nginx with a PID

ps aux | grep nginx
# Should show nginx processes

# Test it works
curl http://localhost
# Should show hello world HTML
```

### 4.3 Create Nginx Management Script

```bash
# Create management script
cat > ~/webserver/scripts/manage-nginx.sh << 'EOF'
#!/bin/bash
# Nginx Management Script

PLIST_PATH="/Library/LaunchDaemons/com.nginx.nginx.plist"
NGINX_CONF="/usr/local/etc/nginx/nginx.conf"
ERROR_LOG="/usr/local/var/log/nginx/error.log"
ACCESS_LOG="/usr/local/var/log/nginx/access.log"

case "$1" in
  start)
    echo "Starting Nginx..."
    sudo launchctl load -w "$PLIST_PATH"
    sleep 2
    sudo launchctl list | grep nginx
    ;;
    
  stop)
    echo "Stopping Nginx..."
    sudo launchctl unload -w "$PLIST_PATH"
    ;;
    
  restart)
    echo "Restarting Nginx..."
    sudo launchctl unload "$PLIST_PATH"
    sleep 2
    sudo launchctl load "$PLIST_PATH"
    sleep 2
    sudo launchctl list | grep nginx
    ;;
    
  reload)
    echo "Reloading Nginx configuration..."
    nginx -t && nginx -s reload
    ;;
    
  status)
    echo "=== Nginx Service Status ==="
    if sudo launchctl list | grep -q nginx; then
      echo "✅ Nginx LaunchDaemon is loaded"
      sudo launchctl list | grep nginx
    else
      echo "❌ Nginx LaunchDaemon is not loaded"
    fi
    echo ""
    echo "=== Nginx Processes ==="
    ps aux | grep -v grep | grep nginx || echo "No Nginx process found"
    echo ""
    echo "=== Recent Error Log ==="
    if [ -f "$ERROR_LOG" ]; then
      tail -5 "$ERROR_LOG"
    else
      echo "No error log found"
    fi
    ;;
    
  logs)
    if [ "$2" = "error" ]; then
      echo "Tailing Nginx error log (Ctrl+C to exit)..."
      tail -f "$ERROR_LOG"
    elif [ "$2" = "access" ]; then
      echo "Tailing Nginx access log (Ctrl+C to exit)..."
      tail -f "$ACCESS_LOG"
    else
      echo "Usage: $0 logs {error|access}"
      exit 1
    fi
    ;;
    
  test)
    echo "Testing Nginx configuration..."
    nginx -t
    ;;
    
  *)
    echo "Nginx Management Script"
    echo ""
    echo "Usage: $0 {start|stop|restart|reload|status|logs|test}"
    echo ""
    echo "  start    - Start Nginx service"
    echo "  stop     - Stop Nginx service"
    echo "  restart  - Restart Nginx service"
    echo "  reload   - Reload config (zero downtime)"
    echo "  status   - Show service status and recent errors"
    echo "  logs     - Tail logs (error|access)"
    echo "  test     - Test configuration syntax"
    exit 1
    ;;
esac
EOF

# Make executable
chmod +x ~/webserver/scripts/manage-nginx.sh

# Add alias to .zshrc
echo 'alias nginx-manage="~/webserver/scripts/manage-nginx.sh"' >> ~/.zshrc
source ~/.zshrc
```

---

## Phase 5: First SSL Certificate with Certbot

### 5.1 Request Certificate for nimbus.wtf

```bash
# Request certificate using DNS-01 challenge
certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials ~/.secrets/cloudflare.ini \
  --dns-cloudflare-propagation-seconds 30 \
  -d nimbus.wtf \
  -d www.nimbus.wtf \
  --email njoubert@gmail.com \
  --agree-tos \
  --non-interactive

# Certificates will be saved to:
# /etc/letsencrypt/live/nimbus.wtf/fullchain.pem
# /etc/letsencrypt/live/nimbus.wtf/privkey.pem
```

**What happens:**
1. Certbot connects to Cloudflare API
2. Creates a TXT record for _acme-challenge.nimbus.wtf
3. Waits 30 seconds for DNS propagation
4. Let's Encrypt validates the TXT record
5. Certificate is issued and saved

### 5.2 Verify Certificate Was Created

```bash
# List certificates
sudo certbot certificates

# Check certificate files
sudo ls -la /etc/letsencrypt/live/nimbus.wtf/

# Check certificate expiry
sudo openssl x509 -in /etc/letsencrypt/live/nimbus.wtf/fullchain.pem -noout -dates
```

---

## Phase 6: Configure Nginx for HTTPS

### 6.1 Create nimbus.wtf Site Config

```bash
# Create site configuration with HTTPS
sudo tee /usr/local/etc/nginx/servers/nimbus.wtf.conf << 'EOF'
# HTTP - redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name nimbus.wtf www.nimbus.wtf;
    
    # Let's Encrypt ACME challenge (for future renewals)
    location /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
    }
    
    # Redirect everything else to HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS - main site
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name nimbus.wtf www.nimbus.wtf;
    
    # SSL certificate paths
    ssl_certificate /etc/letsencrypt/live/nimbus.wtf/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/nimbus.wtf/privkey.pem;
    
    # SSL configuration (modern, secure)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # HSTS (force HTTPS for 1 year)
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Site root
    root /Users/njoubert/webserver/sites/nimbus.wtf/public;
    index index.html index.htm;
    
    # Try files, then 404
    location / {
        try_files $uri $uri/ =404;
    }
    
    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Logging
    access_log /usr/local/var/log/nginx/nimbus.wtf.access.log;
    error_log /usr/local/var/log/nginx/nimbus.wtf.error.log;
}
EOF
```

### 6.2 Test and Reload Nginx

```bash
# Test configuration
nginx -t
# Should show: test is successful

# Reload Nginx
~/webserver/scripts/manage-nginx.sh reload
# Should reload without errors
```

### 6.3 Test HTTPS

```bash
# Test HTTPS (will only work if DNS points to your server)
curl -I https://nimbus.wtf
# Should show: HTTP/2 200

# Test redirect from HTTP to HTTPS
curl -I http://nimbus.wtf
# Should show: HTTP/1.1 301 Moved Permanently
#              Location: https://nimbus.wtf/

# Check certificate details
echo | openssl s_client -connect nimbus.wtf:443 -servername nimbus.wtf 2>/dev/null | openssl x509 -noout -dates -subject
```

---

## Phase 7: Set Up Automatic Certificate Renewal

### 7.1 Understand Certbot's Auto-Renewal

Certbot installs a cron job automatically when you first request a certificate. Let's verify and configure it.

```bash
# Check if renewal timer/cron exists
# On macOS, Certbot uses launchd instead of cron

# List Certbot-related launch agents
ls -la ~/Library/LaunchAgents/ | grep certbot
ls -la /Library/LaunchAgents/ | grep certbot
ls -la /Library/LaunchDaemons/ | grep certbot

# If no launchd job exists, we'll create one
```

### 7.2 Create Certbot Renewal LaunchDaemon

```bash
# Create renewal script first
sudo tee /usr/local/bin/certbot-renew.sh << 'EOF'
#!/bin/bash
# Certbot renewal script with Nginx reload

# Renew certificates
/usr/local/bin/certbot renew --quiet --dns-cloudflare

# If renewal succeeded, reload Nginx
if [ $? -eq 0 ]; then
    /usr/local/bin/nginx -s reload
fi
EOF

# Make executable
sudo chmod +x /usr/local/bin/certbot-renew.sh

# Create LaunchDaemon for automatic renewal
sudo tee /Library/LaunchDaemons/com.certbot.renew.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.certbot.renew</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/certbot-renew.sh</string>
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
    <string>/usr/local/var/log/certbot-renew.log</string>
    
    <key>StandardErrorPath</key>
    <string>/usr/local/var/log/certbot-renew-error.log</string>
</dict>
</plist>
EOF

# Set permissions
sudo chown root:wheel /Library/LaunchDaemons/com.certbot.renew.plist
sudo chmod 644 /Library/LaunchDaemons/com.certbot.renew.plist

# Load the LaunchDaemon
sudo launchctl load -w /Library/LaunchDaemons/com.certbot.renew.plist

# Verify it's loaded
sudo launchctl list | grep certbot
```

**This renewal job will:**
- Run twice daily (2am and 2pm)
- Check all certificates
- Renew any certificate within 30 days of expiry
- Reload Nginx after successful renewal
- Log all activity

### 7.3 Test Renewal Manually

```bash
# Test renewal (dry run, doesn't actually renew)
sudo certbot renew --dry-run --dns-cloudflare

# Check renewal logs
sudo tail -50 /usr/local/var/log/certbot-renew.log
```

---

## Phase 8: Create Static Site Provisioning Script

Now that Nginx + Certbot is set up, create a script to easily add new static sites.

### 8.1 Create provision_static_site_nginx.sh

```bash
cat > ~/webserver/scripts/provision_static_site_nginx.sh << 'EOF'
#!/bin/bash
#
# Static Site Provisioning Script for Nginx + Certbot
#
# Usage: bash provision_static_site_nginx.sh <domain> [email] [public_dir]
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${NC}$1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }

# Check arguments
if [[ $# -lt 1 ]]; then
    error "Usage: $0 <domain> [email] [public_dir]"
    exit 1
fi

DOMAIN="$1"
EMAIL="${2:-njoubert@gmail.com}"
SOURCE_DIR="${3:-}"
USERNAME=$(whoami)
SITE_DIR="$HOME/webserver/sites/$DOMAIN"
PUBLIC_DIR="$SITE_DIR/public"
NGINX_CONF="/usr/local/etc/nginx/servers/${DOMAIN}.conf"
CLOUDFLARE_INI="$HOME/.secrets/cloudflare.ini"

log "========================================="
log "Static Site Provisioning: $DOMAIN"
log "========================================="
echo ""

# Step 1: Create directory
log "Step 1: Create site directory"
mkdir -p "$PUBLIC_DIR"
success "Created $PUBLIC_DIR"

# Step 2: Install content
log "Step 2: Install static content"
if [[ -n "$SOURCE_DIR" && -d "$SOURCE_DIR" ]]; then
    cp -r "$SOURCE_DIR/"* "$PUBLIC_DIR/"
    success "Copied files from $SOURCE_DIR"
else
    if [[ ! -f "$PUBLIC_DIR/index.html" ]]; then
        cat > "$PUBLIC_DIR/index.html" << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>Coming Soon</title>
    <style>
        body { font-family: system-ui; max-width: 800px; margin: 100px auto; padding: 20px; text-align: center; }
        h1 { color: #2563eb; }
    </style>
</head>
<body>
    <h1>🚀 Site Coming Soon</h1>
    <p>This site is under construction.</p>
</body>
</html>
HTML
        success "Created placeholder index.html"
    else
        warning "index.html already exists, skipping"
    fi
fi

# Step 3: Request SSL certificate
log "Step 3: Request SSL certificate from Let's Encrypt"
if sudo certbot certificates | grep -q "$DOMAIN"; then
    warning "Certificate already exists for $DOMAIN"
else
    log "Requesting certificate via Cloudflare DNS..."
    sudo certbot certonly \
        --dns-cloudflare \
        --dns-cloudflare-credentials "$CLOUDFLARE_INI" \
        --dns-cloudflare-propagation-seconds 30 \
        -d "$DOMAIN" \
        -d "www.$DOMAIN" \
        --email "$EMAIL" \
        --agree-tos \
        --non-interactive
    
    success "Certificate obtained for $DOMAIN"
fi

# Step 4: Create Nginx config
log "Step 4: Create Nginx configuration"
sudo tee "$NGINX_CONF" > /dev/null << NGINX_EOF
# HTTP - redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;
    
    location /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
    }
    
    location / {
        return 301 https://\$host\$request_uri;
    }
}

# HTTPS - main site
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;
    
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    root $PUBLIC_DIR;
    index index.html index.htm;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    access_log /usr/local/var/log/nginx/$DOMAIN.access.log;
    error_log /usr/local/var/log/nginx/$DOMAIN.error.log;
}
NGINX_EOF

success "Created $NGINX_CONF"

# Step 5: Test and reload Nginx
log "Step 5: Reload Nginx"
if nginx -t; then
    nginx -s reload
    success "Nginx reloaded successfully"
else
    error "Nginx configuration test failed!"
    exit 1
fi

# Step 6: Test the site
log "Step 6: Test deployment"
sleep 2

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN 2>/dev/null || echo "000")
if [[ "$HTTP_STATUS" == "200" ]]; then
    success "✅ Site is live at https://$DOMAIN"
else
    warning "Could not reach https://$DOMAIN (status: $HTTP_STATUS)"
    log "This may be normal if DNS hasn't propagated yet"
fi

echo ""
log "========================================="
log "Deployment Complete!"
log "========================================="
echo ""
success "Domain: $DOMAIN"
success "Public directory: $PUBLIC_DIR"
success "Nginx config: $NGINX_CONF"
success "Logs: /usr/local/var/log/nginx/$DOMAIN.*.log"
echo ""
log "Certificate will auto-renew via certbot (runs twice daily)"
log "Next: Point DNS to this server and enable Cloudflare proxy"
echo ""
EOF

chmod +x ~/webserver/scripts/provision_static_site_nginx.sh
```

---

## Phase 9: Clean Up Caddy (Optional)

Since we're switching to Nginx, we can remove Caddy:

```bash
# Stop and unload Caddy LaunchDaemon
sudo launchctl unload -w /Library/LaunchDaemons/com.caddyserver.caddy.plist

# Remove Caddy LaunchDaemon
sudo rm /Library/LaunchDaemons/com.caddyserver.caddy.plist

# Uninstall Caddy (optional - you can keep it for reference)
brew uninstall caddy

# Remove Caddy files (optional)
sudo rm -rf /usr/local/etc/Caddyfile*
sudo rm -rf /usr/local/var/log/caddy/

# Keep the management script for reference
# mv ~/webserver/scripts/manage-caddy.sh ~/webserver/scripts/manage-caddy.sh.old
```

---

## Maintenance & Operations

### Daily Operations

**Nothing! It's all automatic:**
- ✅ Nginx auto-starts at boot
- ✅ Certificates auto-renew (twice daily checks)
- ✅ Software updates via Homebrew
- ✅ Nginx reloads after cert renewal

### Adding a New Site

```bash
cd ~/webserver/scripts
./provision_static_site_nginx.sh newdomain.com
```

### Checking Certificate Status

```bash
# List all certificates and their expiry
sudo certbot certificates

# Test renewal (dry run)
sudo certbot renew --dry-run
```

### Updating Software

```bash
# Update everything
brew update
brew upgrade nginx certbot

# Update Certbot plugins
pip3 install --upgrade certbot-dns-cloudflare

# Restart Nginx
~/webserver/scripts/manage-nginx.sh restart
```

### Viewing Logs

```bash
# Nginx logs
~/webserver/scripts/manage-nginx.sh logs access
~/webserver/scripts/manage-nginx.sh logs error

# Site-specific logs
tail -f /usr/local/var/log/nginx/nimbus.wtf.access.log

# Certbot renewal logs
sudo tail -f /usr/local/var/log/certbot-renew.log
```

### Troubleshooting

**Nginx won't start:**
```bash
# Check configuration
nginx -t

# Check logs
tail -50 /usr/local/var/log/nginx/error.log

# Check if port 80/443 in use
sudo lsof -i :80
sudo lsof -i :443
```

**Certificate renewal fails:**
```bash
# Check Cloudflare credentials
cat ~/.secrets/cloudflare.ini

# Test Cloudflare API access
sudo certbot renew --dry-run --dns-cloudflare -v

# Check renewal logs
sudo tail -100 /usr/local/var/log/certbot-renew-error.log
```

**Site not accessible:**
```bash
# Check Nginx is running
ps aux | grep nginx

# Check site config
nginx -t

# Check DNS
dig nimbus.wtf +short

# Check certificate
sudo openssl x509 -in /etc/letsencrypt/live/nimbus.wtf/fullchain.pem -noout -dates
```

---

## Verification Checklist

After completing all phases:

- [ ] Nginx installed via Homebrew
- [ ] Certbot installed via Homebrew
- [ ] Cloudflare DNS plugin installed via pip3
- [ ] Cloudflare credentials file created and secured (600 permissions)
- [ ] Nginx LaunchDaemon configured and running
- [ ] Hello world site works on HTTP
- [ ] SSL certificate obtained for nimbus.wtf
- [ ] nimbus.wtf works on HTTPS
- [ ] HTTP redirects to HTTPS
- [ ] Certbot renewal LaunchDaemon configured
- [ ] Manual renewal test succeeds
- [ ] Static site provisioning script created and tested
- [ ] All management scripts in ~/webserver/scripts/
- [ ] Can access https://nimbus.wtf from browser

---

## Summary: What We Achieved

✅ **Automatic HTTPS**
- Let's Encrypt certificates via Certbot
- DNS-01 challenge using Cloudflare API
- Certificates renew automatically every 60 days

✅ **Automatic Updates**
- Nginx updates via Homebrew
- Certbot updates via Homebrew  
- Plugin updates via pip3
- No custom builds, no manual intervention

✅ **Cloudflare Integration**
- Cloudflare proxy stays enabled (orange cloud)
- DDoS protection active
- CDN caching active
- Real IP hidden

✅ **Operational Simplicity**
- One command to add new sites
- Auto-start at boot
- Auto-renew certificates
- Simple management scripts
- True "set and forget"

---

## Next Steps

1. **Run the provisioning for nimbus.wtf:**
   ```bash
   cd ~/webserver/scripts
   ./provision_static_site_nginx.sh nimbus.wtf
   ```

2. **Upload your actual site content:**
   ```bash
   # Replace placeholder with real content
   cp -r ~/path/to/nimbus.wtf/site/* ~/webserver/sites/nimbus.wtf/public/
   ```

3. **Update DNS in Cloudflare:**
   - Point nimbus.wtf A record to your Mac Mini IP
   - Enable proxy (orange cloud)
   - Wait for DNS propagation (1-5 minutes)

4. **Test everything:**
   - Visit https://nimbus.wtf
   - Check certificate is valid
   - Verify Cloudflare proxy is active
   - Monitor logs for any errors

5. **Add more sites as needed:**
   ```bash
   ./provision_static_site_nginx.sh nextdomain.com
   ```

---

## Comparison: Caddy vs This Solution

| Aspect | Caddy (with plugins) | Nginx + Certbot |
|--------|---------------------|-----------------|
| Setup complexity | Simple config, complex build | Verbose config, simple packages |
| Updates | Manual rebuild | Automatic via Homebrew |
| Certificate management | Built-in (if you can use it) | Separate tool (Certbot) |
| Cloudflare support | Requires custom build | Standard plugin |
| Long-term maintenance | High (track updates, rebuild) | Low (Homebrew handles it) |
| Community support | Good | Excellent |
| "Set and forget" | No (custom builds) | Yes (standard packages) |

**Winner for home server: Nginx + Certbot** ✅

---

## Appendix: File Locations Reference

```
# Nginx
/usr/local/bin/nginx                              # Nginx binary
/usr/local/etc/nginx/nginx.conf                   # Main config
/usr/local/etc/nginx/servers/*.conf               # Site configs
/usr/local/var/log/nginx/*.log                    # Nginx logs
/Library/LaunchDaemons/com.nginx.nginx.plist      # Auto-start config

# Certbot
/usr/local/bin/certbot                            # Certbot binary
/etc/letsencrypt/live/*/fullchain.pem             # SSL certificates
/etc/letsencrypt/live/*/privkey.pem               # SSL private keys
/usr/local/bin/certbot-renew.sh                   # Renewal script
/Library/LaunchDaemons/com.certbot.renew.plist    # Auto-renew config
/usr/local/var/log/certbot-renew.log              # Renewal logs

# Cloudflare
~/.secrets/cloudflare.ini                          # API credentials (600)

# Sites
~/webserver/sites/*/public/                        # Site content
~/webserver/scripts/                               # Management scripts
```

---

**Document Version:** 1.0  
**Last Updated:** 2025-10-27  
**Status:** Ready for implementation
