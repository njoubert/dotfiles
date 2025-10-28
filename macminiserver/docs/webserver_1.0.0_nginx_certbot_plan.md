# Mac Mini Webserver version 1.0.0

## Requirements

### General


- **Long Term Supported Static File Server** We want a stable setup that can serve static websites for the next decade with minimal maintenance needed.
- **Multiple Hetrogeneous Sites** The webserver should be able to host my multiple websites and my multiple projects, including my njoubert.com home page which is just a static site, subdomains such as rtc.njoubert.com which is a WebRTC-based video streaming experiment, files.njoubert.com which is just a firestore, and nielsshootsfilm.com which is a hybrid static-dynamic site with a static frontend and a Go API.
- **SSL/TLS Certificates**: Must support HTTPS with automatic cert rotation (likely letsencrypt)
- **Simple Side Addition** We want to make it easy to spin up additional static sites if needed.
- **Efficiency** The design should use the available resources efficiently
- **Fast** The system should be fast, especially the static file serving.
- **Maintainable** It should be dead simple to maintain as I am the only person maintaining this.
- **Dependency Isolation** It should keep the dependencies of different projects well-isolated. The last thing I want is to fight dependency hell between a 3 year old Wordpress website I am maintaining and a bleeding-edge Go app I am experimenting with.
- **Wordpress Support** We want to be able to host Wordpress websites and similar blogging platforms (Ghost?)
- **Wordpress Isolation** Wordpress websites should be well-isolated from all the other systems we might want to run. 
- **Future Dynamic Projects** We want to be able to host my dynamic projects as I dream up ideas over the next decade.
- **Project Isolation** We want good isolation between different projects, including isolation if there is a security vulnerability, getting a zero day on one project shouldnt expose the whole system.
- **Support Being Shashdotted** We want to be prepared if there is an influx of traffic, and use that well for the site that is getting the traffic while the other sites idle. So we do not want to, say, have a single thread or a single process per site! Something more dynamic is needed.
-  **Ratelimiting Hackers** We want to have rate limiting and fail2ban on the root system to protect from attackers.

### Compute Environment

- **Mac Mini Intel Core i3** This system must use the Macmini I have, I will not by buying new hardware.
- **External SSDs** Support additonal storage through adding SSDs as needed.

### Sysadmin

- **Log Management**: Centralized logging, rotation policies (partially in provision.sh already)
- **Sits Behind Cloudflare Dynamic DNS**: The web server is on my consumer fiber internet, exposed via port forwarding of my home gateway (Ubiquiti UniFi). 
- **Auto-Start after Power Failure**: If the mac mini gets hard-rebooted (or soft-rebooted!) then all the sites should launch automatically without intervention.

### Advance Features (v1.2+)

These are features we want to build in a v1.2 of the web server.

- **v1.2: Resource Limits**: Per-container CPU/memory limits to prevent one site from starving others
    - Including individual disk space management. Per-container disk space management, so containers can be configured with a maximum disk space usage.
- **v1.4: Monitoring & Alerting**: System health, disk space, service uptime monitoring (Grafana? Promethues? Other aps?)
- **v1.6: Backup Strategy**: Need automated backups for containers including blogging platforms like Wordpress.

### Allowances aka Non-requirements

- This is not a heavy duty production system. It is okay if there is a bit of downtime due to upgrades.
- We do not need to support a full development/staging/production setup for every app, its okay to generally just have production, and if we want a staging env for a certain application, it's just an application-level decision to runit. 
- It is acceptable if containers are not monitored and restarted or scaled automatically. For v1.0 we want to boot containers automatically on system startup, but if they die, it's okay to rely on the sysadmin to restart the container and debug what is happening.

# Nginx + Certbot + Cloudflare DNS - Implementation Plan

**Date:** October 27, 2025  
**Goal:** Set up a fully automated webserver with HTTPS that requires zero manual maintenance

## Overview

This plan replaces Caddy with Nginx + Certbot to achieve:
- ✅ Automatic HTTPS certificates via Let's Encrypt
- ✅ Cloudflare DNS-01 challenge (keeps Cloudflare proxy enabled)
- ✅ Automatic updates via Homebrew and pip3
- ✅ Automatic certificate renewals via LaunchDaemon
- ✅ Idempotent provisioning script
- ✅ Zero manual maintenance

## Implementation Approach

**IMPORTANT:** This implementation uses an **idempotent provisioning script** as the primary method. You will NOT execute the phase steps manually. Instead:

1. **First:** Complete Caddy cleanup (see `docs/caddy_cleanup.md`)
2. **Then:** Review the phase descriptions below to understand what will happen
3. **Finally:** Run the provisioning script which will execute all phases automatically

The phases below describe what the provisioning script does, not manual steps to execute.

## Prerequisites

**CRITICAL:** Before running the provisioning script, you MUST complete the Caddy cleanup:
- See `docs/caddy_cleanup.md` for complete cleanup instructions
- Verify Caddy is fully removed and ports 80/443 are free
- Backup existing configuration and site data

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
4. **LaunchDaemon** - Auto-start Nginx and auto-renew certificates
5. **Provisioning Script** - Idempotent setup script with user prompts

## Why This Works

### Automatic Updates ✅
- **Homebrew packages:** Automated weekly updates for nginx and certbot
- **pip3 packages:** Automated weekly updates for certbot-dns-cloudflare
- **LaunchDaemon:** Runs weekly update checks
- **All independent** - No custom builds, no version conflicts

### Automatic Certificate Renewal ✅
- LaunchDaemon runs daily certificate renewal checks
- Renews certs within 30 days of expiry
- Reloads Nginx after successful renewal
- Logs all renewal attempts
- No manual intervention needed

### Cloudflare Integration ✅
- Certbot uses Cloudflare API to create DNS TXT records
- Let's Encrypt validates via DNS (no need to reach your server)
- Cloudflare proxy stays enabled (orange cloud)
- You keep DDoS protection, CDN, hidden IP

### Idempotent Provisioning ✅
- Script checks existing installations before installing
- Shows diffs before overwriting configuration files
- Prompts user for required inputs (Cloudflare token, etc.)
- Safe to run multiple times
- Can resume from any step
- Creates convenient symlinks to all config and log files in `~/webserver/symlinks/`

---

## Provisioning Script

The master provisioning script is located at `~/webserver/scripts/provision_webserver.sh`.

**To provision your webserver:**
```bash
cd ~/webserver/scripts
./provision_webserver.sh
```

The script will:
1. Check prerequisites (Homebrew installed)
2. Install all required packages (nginx, certbot, certbot-dns-cloudflare)
3. Prompt for Cloudflare API token (securely stored)
4. Create all necessary directories
5. Generate nginx configuration files (with diff review)
6. Set up LaunchDaemons for auto-start and auto-renewal
7. Configure automatic weekly updates
8. Create convenient symlinks to all config and log files
9. Provide next steps for adding sites

**Features:**
- ✅ **Idempotent** - Safe to run multiple times
- ✅ **Interactive** - Shows diffs, prompts for confirmation
- ✅ **Resumable** - Skip already-completed steps
- ✅ **Safe** - Backs up files before overwriting
- ✅ **Logged** - All actions logged with timestamps

---

## What the Provisioning Script Does

The sections below describe what happens when you run the provisioning script. These are NOT manual steps - the script handles everything automatically.

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

## Phase 8: Set Up Automatic Package Updates

Configure automatic updates for Homebrew and pip3 packages to keep the system secure and up-to-date.

### 8.1 Create Update Script

```bash
# Create scripts directory if it doesn't exist
mkdir -p ~/webserver/scripts

# Create the update script
cat > ~/webserver/scripts/auto_update.sh << 'EOF'
#!/bin/bash
#
# Automatic Package Update Script
# Updates Homebrew packages (nginx, certbot) and pip3 packages (certbot-dns-cloudflare)
#
# This script should be run via LaunchDaemon weekly
#

LOG_FILE="/usr/local/var/log/auto-update.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Starting automatic update check ==="

# Update Homebrew itself
log "Updating Homebrew..."
brew update 2>&1 | tee -a "$LOG_FILE"

# Upgrade all Homebrew packages (nginx, certbot, etc.)
log "Upgrading Homebrew packages..."
brew upgrade 2>&1 | tee -a "$LOG_FILE"

# Upgrade pip3 packages (certbot-dns-cloudflare)
log "Upgrading pip3 packages..."
pip3 install --upgrade certbot-dns-cloudflare 2>&1 | tee -a "$LOG_FILE"

# Cleanup old versions
log "Cleaning up old versions..."
brew cleanup 2>&1 | tee -a "$LOG_FILE"

# Check if nginx needs restart (if binary was updated)
if pgrep -x "nginx" > /dev/null; then
    log "Nginx is running. Checking if restart needed..."
    NGINX_VERSION_RUNNING=$(nginx -v 2>&1 | awk -F'/' '{print $2}')
    NGINX_VERSION_INSTALLED=$(brew list --versions nginx | awk '{print $2}')
    
    if [ "$NGINX_VERSION_RUNNING" != "$NGINX_VERSION_INSTALLED" ]; then
        log "Nginx version mismatch. Reloading nginx..."
        sudo launchctl kickstart -k system/com.nginx.nginx
        log "Nginx reloaded to version $NGINX_VERSION_INSTALLED"
    else
        log "Nginx is up-to-date (version $NGINX_VERSION_RUNNING)"
    fi
fi

log "=== Update check complete ==="
log ""
EOF

# Make it executable
chmod +x ~/webserver/scripts/auto_update.sh
```

### 8.2 Create LaunchDaemon for Automatic Updates

```bash
# Create the LaunchDaemon plist
sudo tee /Library/LaunchDaemons/com.webserver.autoupdate.plist > /dev/null << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.webserver.autoupdate</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/njoubert/webserver/scripts/auto_update.sh</string>
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
    <string>/usr/local/var/log/auto-update-error.log</string>
    
    <key>StandardOutPath</key>
    <string>/usr/local/var/log/auto-update.log</string>
</dict>
</plist>
EOF

# Load the LaunchDaemon
sudo launchctl load /Library/LaunchDaemons/com.webserver.autoupdate.plist
```

**Schedule:** Updates run every Monday at 2:00 AM

### 8.3 Test Update Script

```bash
# Run manually to test
bash ~/webserver/scripts/auto_update.sh

# Check the log
tail -f /usr/local/var/log/auto-update.log
```

### 8.4 Verify LaunchDaemon

```bash
# Check if it's loaded
sudo launchctl list | grep autoupdate

# Check next run time (if available)
sudo launchctl print system/com.webserver.autoupdate
```

**Summary:**
- ✅ Homebrew packages (nginx, certbot) update automatically
- ✅ pip3 packages (certbot-dns-cloudflare) update automatically
- ✅ Nginx reloads automatically if updated
- ✅ Runs weekly (Monday 2 AM)
- ✅ All updates logged

---

## Complete Provisioning Script

Below is the complete, production-ready provisioning script that implements all phases automatically.

### Create ~/webserver/scripts/provision_webserver.sh

```bash
cat > ~/webserver/scripts/provision_webserver.sh << 'SCRIPT_EOF'
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
NC='\033[0m'

log() { echo -e "${NC}$1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to prompt user for input
prompt_user() {
    local prompt="$1"
    local var_name="$2"
    local default="$3"
    
    if [ -n "$default" ]; then
        read -p "$(echo -e ${BLUE}$prompt [default: $default]: ${NC})" input
        eval "$var_name=\"${input:-$default}\""
    else
        read -p "$(echo -e ${BLUE}$prompt: ${NC})" input
        eval "$var_name=\"$input\""
    fi
}

# Function to show diff and ask to overwrite
check_and_write_file() {
    local file_path="$1"
    local new_content="$2"
    local sudo_required="${3:-false}"
    
    if [ -f "$file_path" ]; then
        # File exists, show diff
        local temp_file=$(mktemp)
        echo "$new_content" > "$temp_file"
        
        if ! diff -u "$file_path" "$temp_file" > /dev/null 2>&1; then
            warning "File $file_path already exists and differs from desired content"
            echo ""
            echo "=== DIFF ==="
            diff -u "$file_path" "$temp_file" || true
            echo "============"
            echo ""
            
            read -p "$(echo -e ${YELLOW}Overwrite $file_path? [y/N]: ${NC})" -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                # Backup before overwriting
                local backup_path="${file_path}.backup.$(date +%Y%m%d_%H%M%S)"
                if [ "$sudo_required" = "true" ]; then
                    sudo cp "$file_path" "$backup_path"
                    echo "$new_content" | sudo tee "$file_path" > /dev/null
                else
                    cp "$file_path" "$backup_path"
                    echo "$new_content" > "$file_path"
                fi
                info "Backup saved to $backup_path"
                success "File $file_path updated"
                return 0
            else
                info "Keeping existing $file_path"
                rm "$temp_file"
                return 1
            fi
        else
            success "File $file_path already has correct content"
            rm "$temp_file"
            return 0
        fi
        
        rm "$temp_file"
    else
        # File doesn't exist, create it
        if [ "$sudo_required" = "true" ]; then
            echo "$new_content" | sudo tee "$file_path" > /dev/null
        else
            mkdir -p "$(dirname "$file_path")"
            echo "$new_content" > "$file_path"
        fi
        success "File $file_path created"
        return 0
    fi
}

# Function to create symlink
create_symlink() {
    local target="$1"
    local link_name="$2"
    
    if [ -L "$link_name" ]; then
        local current_target=$(readlink "$link_name")
        if [ "$current_target" = "$target" ]; then
            success "Symlink $link_name already points to $target"
            return 0
        else
            warning "Symlink $link_name exists but points to $current_target"
            read -p "$(echo -e ${YELLOW}Update symlink? [y/N]: ${NC})" -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm "$link_name"
                ln -s "$target" "$link_name"
                success "Symlink $link_name updated"
                return 0
            else
                info "Keeping existing symlink"
                return 1
            fi
        fi
    elif [ -e "$link_name" ]; then
        error "Path $link_name exists but is not a symlink"
        return 1
    else
        mkdir -p "$(dirname "$link_name")"
        ln -s "$target" "$link_name"
        success "Symlink $link_name created"
        return 0
    fi
}

echo ""
log "╔════════════════════════════════════════════════════════════╗"
log "║   Web Server Provisioning Script - nginx + Certbot        ║"
log "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check prerequisites
info "Checking prerequisites..."
if ! command_exists brew; then
    error "Homebrew not installed. Please install from https://brew.sh"
    exit 1
fi
success "Homebrew found"

# Phase 1: Install Core Components
echo ""
log "=== Phase 1: Installing Core Components ==="

if command_exists nginx; then
    success "nginx already installed ($(nginx -v 2>&1))"
else
    info "Installing nginx..."
    brew install nginx
    success "nginx installed"
fi

if command_exists certbot; then
    success "certbot already installed ($(certbot --version))"
else
    info "Installing certbot..."
    brew install certbot
    success "certbot installed"
fi

if pip3 list 2>/dev/null | grep -q certbot-dns-cloudflare; then
    success "certbot-dns-cloudflare already installed"
else
    info "Installing certbot-dns-cloudflare..."
    pip3 install certbot-dns-cloudflare
    success "certbot-dns-cloudflare installed"
fi

# Phase 2: Configure Cloudflare Credentials
echo ""
log "=== Phase 2: Configuring Cloudflare Credentials ==="

CLOUDFLARE_INI="$HOME/.secrets/cloudflare.ini"
if [ -f "$CLOUDFLARE_INI" ]; then
    success "Cloudflare credentials already exist at $CLOUDFLARE_INI"
    read -p "$(echo -e ${YELLOW}Update Cloudflare API token? [y/N]: ${NC})" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        prompt_user "Enter your Cloudflare API token" CLOUDFLARE_TOKEN
        mkdir -p "$HOME/.secrets"
        chmod 700 "$HOME/.secrets"
        echo "dns_cloudflare_api_token = $CLOUDFLARE_TOKEN" > "$CLOUDFLARE_INI"
        chmod 600 "$CLOUDFLARE_INI"
        success "Cloudflare credentials updated"
    fi
else
    prompt_user "Enter your Cloudflare API token" CLOUDFLARE_TOKEN
    mkdir -p "$HOME/.secrets"
    chmod 700 "$HOME/.secrets"
    echo "dns_cloudflare_api_token = $CLOUDFLARE_TOKEN" > "$CLOUDFLARE_INI"
    chmod 600 "$CLOUDFLARE_INI"
    success "Cloudflare credentials created at $CLOUDFLARE_INI"
fi

# Phase 3: Configure directories
echo ""
log "=== Phase 3: Setting Up Directory Structure ==="

mkdir -p ~/webserver/scripts
mkdir -p ~/webserver/sites
mkdir -p ~/webserver/symlinks
mkdir -p /usr/local/etc/nginx/servers
mkdir -p /usr/local/var/log/nginx
success "Directory structure created"

# Phase 4: Configure nginx main config
echo ""
log "=== Phase 4: Configuring nginx ==="

NGINX_CONF=$(cat << 'NGINX_EOF'
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
NGINX_EOF
)

check_and_write_file "/usr/local/etc/nginx/nginx.conf" "$NGINX_CONF" true

# Create hello world site
HELLO_CONF=$(cat << 'HELLO_EOF'
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
HELLO_EOF
)

check_and_write_file "/usr/local/etc/nginx/servers/hello.conf" "$HELLO_CONF" true

# Create hello world content
mkdir -p ~/webserver/sites/hello/public
if [ ! -f ~/webserver/sites/hello/public/index.html ]; then
    cat > ~/webserver/sites/hello/public/index.html << 'HTML_EOF'
<!DOCTYPE html>
<html>
<head>
    <title>nginx + Certbot</title>
    <style>
        body { font-family: system-ui; max-width: 800px; margin: 100px auto; padding: 20px; text-align: center; }
        h1 { color: #2563eb; }
    </style>
</head>
<body>
    <h1>🚀 nginx + Certbot</h1>
    <p>Web server is running!</p>
</body>
</html>
HTML_EOF
    success "Created hello world page"
else
    success "Hello world page already exists"
fi

# Test nginx configuration
if nginx -t 2>&1 | grep -q "successful"; then
    success "nginx configuration is valid"
else
    error "nginx configuration has errors"
    nginx -t
    exit 1
fi

# Phase 5: Set up nginx LaunchDaemon
echo ""
log "=== Phase 5: Setting Up nginx LaunchDaemon ==="

NGINX_PLIST=$(cat << 'PLIST_EOF'
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
PLIST_EOF
)

check_and_write_file "/Library/LaunchDaemons/com.nginx.nginx.plist" "$NGINX_PLIST" true

if check_and_write_file "/Library/LaunchDaemons/com.nginx.nginx.plist" "$NGINX_PLIST" true; then
    sudo chown root:wheel /Library/LaunchDaemons/com.nginx.nginx.plist
    sudo chmod 644 /Library/LaunchDaemons/com.nginx.nginx.plist
    
    # Load or restart the LaunchDaemon
    if sudo launchctl list | grep -q "com.nginx.nginx"; then
        info "nginx LaunchDaemon already loaded, restarting..."
        sudo launchctl kickstart -k system/com.nginx.nginx
    else
        info "Loading nginx LaunchDaemon..."
        sudo launchctl load -w /Library/LaunchDaemons/com.nginx.nginx.plist
    fi
    
    sleep 2
    if ps aux | grep -v grep | grep -q nginx; then
        success "nginx is running"
    else
        warning "nginx LaunchDaemon loaded but process not detected"
    fi
fi

# Phase 6: Create nginx management script
echo ""
log "=== Phase 6: Creating Management Scripts ==="

NGINX_MANAGE=$(cat << 'MANAGE_EOF'
#!/bin/bash
# Nginx Management Script

PLIST_PATH="/Library/LaunchDaemons/com.nginx.nginx.plist"
NGINX_CONF="/usr/local/etc/nginx/nginx.conf"
ERROR_LOG="/usr/local/var/log/nginx/error.log"
ACCESS_LOG="/usr/local/var/log/nginx/access.log"

case "$1" in
  start)
    echo "Starting nginx..."
    sudo launchctl load -w "$PLIST_PATH"
    sleep 2
    sudo launchctl list | grep nginx
    ;;
    
  stop)
    echo "Stopping nginx..."
    sudo launchctl unload -w "$PLIST_PATH"
    ;;
    
  restart)
    echo "Restarting nginx..."
    sudo launchctl unload "$PLIST_PATH"
    sleep 2
    sudo launchctl load "$PLIST_PATH"
    sleep 2
    sudo launchctl list | grep nginx
    ;;
    
  reload)
    echo "Reloading nginx configuration..."
    nginx -t && nginx -s reload
    ;;
    
  status)
    echo "=== nginx Service Status ==="
    if sudo launchctl list | grep -q nginx; then
      echo "✅ nginx LaunchDaemon is loaded"
      sudo launchctl list | grep nginx
    else
      echo "❌ nginx LaunchDaemon is not loaded"
    fi
    echo ""
    echo "=== nginx Processes ==="
    ps aux | grep -v grep | grep nginx || echo "No nginx process found"
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
      echo "Tailing nginx error log (Ctrl+C to exit)..."
      tail -f "$ERROR_LOG"
    elif [ "$2" = "access" ]; then
      echo "Tailing nginx access log (Ctrl+C to exit)..."
      tail -f "$ACCESS_LOG"
    else
      echo "Usage: $0 logs {error|access}"
      exit 1
    fi
    ;;
    
  test)
    echo "Testing nginx configuration..."
    nginx -t
    ;;
    
  *)
    echo "nginx Management Script"
    echo ""
    echo "Usage: $0 {start|stop|restart|reload|status|logs|test}"
    echo ""
    echo "  start    - Start nginx service"
    echo "  stop     - Stop nginx service"
    echo "  restart  - Restart nginx service"
    echo "  reload   - Reload config (zero downtime)"
    echo "  status   - Show service status and recent errors"
    echo "  logs     - Tail logs (error|access)"
    echo "  test     - Test configuration syntax"
    exit 1
    ;;
esac
MANAGE_EOF
)

check_and_write_file "$HOME/webserver/scripts/manage-nginx.sh" "$NGINX_MANAGE" false
chmod +x "$HOME/webserver/scripts/manage-nginx.sh"

# Phase 7: Set up Certbot renewal
echo ""
log "=== Phase 7: Setting Up Certbot Auto-Renewal ==="

CERTBOT_RENEW=$(cat << 'RENEW_EOF'
#!/bin/bash
# Certbot renewal script with nginx reload

/usr/local/bin/certbot renew --quiet --dns-cloudflare

if [ $? -eq 0 ]; then
    /usr/local/bin/nginx -s reload
fi
RENEW_EOF
)

check_and_write_file "/usr/local/bin/certbot-renew.sh" "$CERTBOT_RENEW" true
sudo chmod +x /usr/local/bin/certbot-renew.sh

CERTBOT_PLIST=$(cat << 'CERTBOT_PLIST_EOF'
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
CERTBOT_PLIST_EOF
)

if check_and_write_file "/Library/LaunchDaemons/com.certbot.renew.plist" "$CERTBOT_PLIST" true; then
    sudo chown root:wheel /Library/LaunchDaemons/com.certbot.renew.plist
    sudo chmod 644 /Library/LaunchDaemons/com.certbot.renew.plist
    
    if sudo launchctl list | grep -q "com.certbot.renew"; then
        info "Certbot renewal LaunchDaemon already loaded"
    else
        sudo launchctl load -w /Library/LaunchDaemons/com.certbot.renew.plist
        success "Certbot renewal LaunchDaemon loaded"
    fi
fi

# Phase 8: Set up automatic updates
echo ""
log "=== Phase 8: Setting Up Automatic Updates ==="

AUTO_UPDATE=$(cat << 'UPDATE_EOF'
#!/bin/bash
#
# Automatic Package Update Script
# Updates Homebrew packages (nginx, certbot) and pip3 packages (certbot-dns-cloudflare)
#

LOG_FILE="/usr/local/var/log/auto-update.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Starting automatic update check ==="

# Update Homebrew itself
log "Updating Homebrew..."
brew update 2>&1 | tee -a "$LOG_FILE"

# Upgrade all Homebrew packages (nginx, certbot, etc.)
log "Upgrading Homebrew packages..."
brew upgrade 2>&1 | tee -a "$LOG_FILE"

# Upgrade pip3 packages (certbot-dns-cloudflare)
log "Upgrading pip3 packages..."
pip3 install --upgrade certbot-dns-cloudflare 2>&1 | tee -a "$LOG_FILE"

# Cleanup old versions
log "Cleaning up old versions..."
brew cleanup 2>&1 | tee -a "$LOG_FILE"

# Check if nginx needs restart (if binary was updated)
if pgrep -x "nginx" > /dev/null; then
    log "nginx is running. Checking if restart needed..."
    NGINX_VERSION_RUNNING=$(nginx -v 2>&1 | awk -F'/' '{print $2}')
    NGINX_VERSION_INSTALLED=$(brew list --versions nginx | awk '{print $2}')
    
    if [ "$NGINX_VERSION_RUNNING" != "$NGINX_VERSION_INSTALLED" ]; then
        log "nginx version mismatch. Reloading nginx..."
        sudo launchctl kickstart -k system/com.nginx.nginx
        log "nginx reloaded to version $NGINX_VERSION_INSTALLED"
    else
        log "nginx is up-to-date (version $NGINX_VERSION_RUNNING)"
    fi
fi

log "=== Update check complete ==="
log ""
UPDATE_EOF
)

check_and_write_file "$HOME/webserver/scripts/auto_update.sh" "$AUTO_UPDATE" false
chmod +x "$HOME/webserver/scripts/auto_update.sh"

UPDATE_PLIST=$(cat << 'UPDATE_PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.webserver.autoupdate</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/njoubert/webserver/scripts/auto_update.sh</string>
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
    <string>/usr/local/var/log/auto-update-error.log</string>
    
    <key>StandardOutPath</key>
    <string>/usr/local/var/log/auto-update.log</string>
</dict>
</plist>
UPDATE_PLIST_EOF
)

if check_and_write_file "/Library/LaunchDaemons/com.webserver.autoupdate.plist" "$UPDATE_PLIST" true; then
    sudo chown root:wheel /Library/LaunchDaemons/com.webserver.autoupdate.plist
    sudo chmod 644 /Library/LaunchDaemons/com.webserver.autoupdate.plist
    
    if sudo launchctl list | grep -q "com.webserver.autoupdate"; then
        info "Auto-update LaunchDaemon already loaded"
    else
        sudo launchctl load -w /Library/LaunchDaemons/com.webserver.autoupdate.plist
        success "Auto-update LaunchDaemon loaded"
    fi
fi

# Phase 9: Create convenient symlinks
echo ""
log "=== Phase 9: Creating Convenient Symlinks ==="

# Config file symlinks
create_symlink "/usr/local/etc/nginx/nginx.conf" "$HOME/webserver/symlinks/nginx.conf"
create_symlink "/usr/local/etc/nginx/servers" "$HOME/webserver/symlinks/nginx-sites"
create_symlink "$HOME/.secrets/cloudflare.ini" "$HOME/webserver/symlinks/cloudflare.ini"

# LaunchDaemon symlinks
create_symlink "/Library/LaunchDaemons/com.nginx.nginx.plist" "$HOME/webserver/symlinks/nginx.plist"
create_symlink "/Library/LaunchDaemons/com.certbot.renew.plist" "$HOME/webserver/symlinks/certbot-renew.plist"
create_symlink "/Library/LaunchDaemons/com.webserver.autoupdate.plist" "$HOME/webserver/symlinks/autoupdate.plist"

# Log symlinks
create_symlink "/usr/local/var/log/nginx" "$HOME/webserver/symlinks/nginx-logs"
create_symlink "/usr/local/var/log/certbot-renew.log" "$HOME/webserver/symlinks/certbot-renew.log"
create_symlink "/usr/local/var/log/auto-update.log" "$HOME/webserver/symlinks/auto-update.log"

# Certificate symlinks (will be created after first cert)
if [ -d "/etc/letsencrypt" ]; then
    create_symlink "/etc/letsencrypt/live" "$HOME/webserver/symlinks/certificates"
fi

success "Symlinks created in ~/webserver/symlinks/"

# Summary
echo ""
log "╔════════════════════════════════════════════════════════════╗"
log "║                     Setup Complete!                        ║"
log "╚════════════════════════════════════════════════════════════╝"
echo ""
success "✅ Core components installed (nginx, certbot, certbot-dns-cloudflare)"
success "✅ Cloudflare credentials configured"
success "✅ Directory structure created"
success "✅ nginx configured and running"
success "✅ LaunchDaemons configured (nginx, certbot renewal, auto-updates)"
success "✅ Management scripts created"
success "✅ Convenient symlinks created in ~/webserver/symlinks/"
echo ""
info "📁 Quick access to configs and logs:"
info "   ls -la ~/webserver/symlinks/"
echo ""
info "🔧 Next steps:"
info "1. Add your first site:"
info "   cd ~/webserver/scripts"
info "   ./provision_static_site_nginx.sh yourdomain.com"
echo ""
info "2. Manage nginx:"
info "   ~/webserver/scripts/manage-nginx.sh status"
info "   ~/webserver/scripts/manage-nginx.sh logs error"
echo ""
info "3. Check symlinks:"
info "   ls -la ~/webserver/symlinks/"
echo ""

SCRIPT_EOF

# Make it executable
chmod +x ~/webserver/scripts/provision_webserver.sh
```

### Run the Provisioning Script

```bash
cd ~/webserver/scripts
./provision_webserver.sh
```

The script will:
1. ✅ Check prerequisites
2. ✅ Install all required packages
3. ✅ Prompt for Cloudflare API token
4. ✅ Create directory structure
5. ✅ Generate and install nginx configuration
6. ✅ Set up all LaunchDaemons (nginx, certbot renewal, auto-updates)
7. ✅ Create management scripts
8. ✅ Create convenient symlinks to all configs and logs
9. ✅ Start nginx automatically

---

## Static Site Provisioning Script

Once the main provisioning script has set up your webserver, use this script to easily add new static sites with automatic HTTPS.

### Create ~/webserver/scripts/provision_static_site_nginx.sh

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

**Summary:**
- ✅ Creates site directory structure
- ✅ Installs static content (or creates placeholder)
- ✅ Requests SSL certificate via Cloudflare DNS
- ✅ Creates nginx configuration
- ✅ Tests and reloads nginx
- ✅ Verifies site is live

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

### Actual File Locations

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

### Convenient Symlinks (~/webserver/symlinks/)

The provisioning script creates convenient symlinks for quick access:

```
~/webserver/symlinks/
├── nginx.conf              → /usr/local/etc/nginx/nginx.conf
├── nginx-sites/            → /usr/local/etc/nginx/servers/
├── cloudflare.ini          → ~/.secrets/cloudflare.ini
├── nginx.plist             → /Library/LaunchDaemons/com.nginx.nginx.plist
├── certbot-renew.plist     → /Library/LaunchDaemons/com.certbot.renew.plist
├── autoupdate.plist        → /Library/LaunchDaemons/com.webserver.autoupdate.plist
├── nginx-logs/             → /usr/local/var/log/nginx/
├── certbot-renew.log       → /usr/local/var/log/certbot-renew.log
├── auto-update.log         → /usr/local/var/log/auto-update.log
└── certificates/           → /etc/letsencrypt/live/ (after first cert)
```

**Quick access examples:**
```bash
# View nginx config
cat ~/webserver/symlinks/nginx.conf

# Check site configs
ls -la ~/webserver/symlinks/nginx-sites/

# Tail nginx logs
tail -f ~/webserver/symlinks/nginx-logs/error.log

# View certificates
ls -la ~/webserver/symlinks/certificates/

# Check LaunchDaemons
cat ~/webserver/symlinks/nginx.plist
```

---

**Document Version:** 1.0  
**Last Updated:** 2025-10-27  
**Status:** Ready for implementation
