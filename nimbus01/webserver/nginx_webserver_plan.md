# Nimbus01 Nginx Webserver Plan

**Date:** January 22, 2026  
**Server:** nimbus01 (MINISFORUM MS-A2, AMD Ryzen 9 9955HX, 96GB RAM)  
**OS:** Ubuntu Server 22.04.5 LTS  
**Goal:** Production-ready nginx webserver with HTTPS, static sites, and reverse proxies

## Overview

Set up nginx on nimbus01 to serve:
- ✅ Multiple static websites with automatic HTTPS (Let's Encrypt)
- ✅ Reverse proxies to Docker containers
- ✅ Reverse proxies to native services (Go binaries, Node.js apps)
- ✅ WordPress/PHP sites via FastCGI
- ✅ Integration with existing LGTM monitoring stack

## Architecture

```
Internet → Cloudflare (DNS/CDN/DDoS) → Home Router (Port Forward 80,443)
                                              ↓
                                         nimbus01:443
                                              ↓
                                           nginx
                    ┌─────────────────────────┼─────────────────────────┐
                    ↓                         ↓                         ↓
            Static Sites              Reverse Proxies              PHP/WordPress
         /var/www/site1.com      localhost:8080 (Go API)         php-fpm socket
         /var/www/site2.com      localhost:3001 (Node.js)
                                 docker:8081 (Container)
```

## Key Differences from macOS Setup

| Aspect | macOS (macminiserver) | Ubuntu (nimbus01) |
|--------|----------------------|-------------------|
| Package Manager | Homebrew | apt |
| Service Manager | launchd (plist) | systemd (systemctl) |
| Config Location | /usr/local/etc/nginx | /etc/nginx |
| Sites Config | /usr/local/etc/nginx/servers/ | /etc/nginx/sites-available/ + sites-enabled/ |
| Default User | njoubert | www-data |
| Certbot Plugin | pip3 install | apt install python3-certbot-dns-cloudflare |
| Auto-updates | Custom LaunchDaemon | unattended-upgrades |
| Logs | /usr/local/var/log/nginx/ | /var/log/nginx/ |

---

## Phase 1: Install Core Components

### 1.1 Update System

```bash
sudo apt update && sudo apt upgrade -y
```

### 1.2 Install Nginx

```bash
# Install nginx
sudo apt install -y nginx

# Verify installation
nginx -v
# Expected: nginx version: nginx/1.18.0 (Ubuntu)

# Check status
sudo systemctl status nginx

# Enable on boot
sudo systemctl enable nginx
```

**Ubuntu nginx paths:**
- Binary: `/usr/sbin/nginx`
- Main config: `/etc/nginx/nginx.conf`
- Sites available: `/etc/nginx/sites-available/`
- Sites enabled: `/etc/nginx/sites-enabled/`
- Logs: `/var/log/nginx/`
- Default web root: `/var/www/html/`

### 1.3 Install Certbot with Cloudflare DNS Plugin

```bash
# Install certbot and cloudflare plugin from apt
sudo apt install -y certbot python3-certbot-nginx python3-certbot-dns-cloudflare

# Verify installation
certbot --version
certbot plugins
# Should list: dns-cloudflare
```

---

## Phase 2: Configure Cloudflare Credentials

### 2.1 Create Cloudflare API Token

In Cloudflare Dashboard:
1. Go to Profile → API Tokens
2. Create Token → Edit zone DNS template
3. Permissions: Zone / DNS / Edit
4. Zone Resources: Include / All zones (or specific zones)
5. Save the token securely

### 2.2 Create Credentials File

```bash
# Create secure directory
sudo mkdir -p /etc/letsencrypt/cloudflare
sudo chmod 700 /etc/letsencrypt/cloudflare

# Create credentials file
sudo tee /etc/letsencrypt/cloudflare/credentials.ini << 'EOF'
# Cloudflare API token for Certbot DNS validation
dns_cloudflare_api_token = YOUR_CLOUDFLARE_API_TOKEN_HERE
EOF

# Secure the file (CRITICAL)
sudo chmod 600 /etc/letsencrypt/cloudflare/credentials.ini
```

### 2.3 Test Cloudflare Credentials

```bash
# Dry run to verify credentials work
sudo certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /etc/letsencrypt/cloudflare/credentials.ini \
  --dns-cloudflare-propagation-seconds 30 \
  --dry-run \
  -d test.yourdomain.com
```

---

## Phase 3: Configure Nginx Base

### 3.1 Create Directory Structure

```bash
# Create directories for sites
sudo mkdir -p /var/www/default/public
sudo mkdir -p /etc/nginx/snippets

# Set ownership
sudo chown -R www-data:www-data /var/www
sudo chmod -R 755 /var/www
```

### 3.2 Create Shared SSL Configuration Snippet

```bash
# Create SSL configuration snippet (reused by all HTTPS sites)
sudo tee /etc/nginx/snippets/ssl-params.conf << 'EOF'
# SSL Configuration - Modern settings for 2026
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers off;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;

# OCSP Stapling
ssl_stapling on;
ssl_stapling_verify on;
resolver 1.1.1.1 8.8.8.8 valid=300s;
resolver_timeout 5s;

# SSL session settings
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:50m;
ssl_session_tickets off;

# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
EOF
```

### 3.3 Create Proxy Configuration Snippet

```bash
# Create reverse proxy snippet (reused by all proxy sites)
sudo tee /etc/nginx/snippets/proxy-params.conf << 'EOF'
# Reverse Proxy Configuration
proxy_http_version 1.1;
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Forwarded-Host $host;
proxy_set_header X-Forwarded-Port $server_port;

# WebSocket support
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";

# Timeouts
proxy_connect_timeout 60s;
proxy_send_timeout 60s;
proxy_read_timeout 60s;

# Buffering
proxy_buffering on;
proxy_buffer_size 4k;
proxy_buffers 8 4k;
EOF
```

### 3.4 Update Main Nginx Config

```bash
# Backup original
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.original

# Create optimized nginx.conf
sudo tee /etc/nginx/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 1024;
    multi_accept on;
    use epoll;
}

http {
    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    # MIME types
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for" '
                    'rt=$request_time uct="$upstream_connect_time" '
                    'uht="$upstream_header_time" urt="$upstream_response_time"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript 
               application/rss+xml application/atom+xml image/svg+xml;

    # Rate limiting zones
    limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=api:10m rate=30r/s;
    limit_conn_zone $binary_remote_addr zone=conn_limit:10m;

    # Include site configurations
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF
```

### 3.5 Create Default Site (Catch-all)

```bash
# Remove default site
sudo rm -f /etc/nginx/sites-enabled/default

# Create catch-all default site
sudo tee /etc/nginx/sites-available/00-default << 'EOF'
# Default server - catches unmatched requests
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    # Return 444 (connection closed) for unmatched hosts
    # This prevents IP-based scanning from seeing content
    return 444;
}

server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    server_name _;

    # Self-signed cert for default (reject connections)
    ssl_certificate /etc/nginx/ssl/default.crt;
    ssl_certificate_key /etc/nginx/ssl/default.key;

    return 444;
}
EOF

# Create self-signed cert for default server
sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/default.key \
    -out /etc/nginx/ssl/default.crt \
    -subj "/CN=localhost"

# Enable default site
sudo ln -sf /etc/nginx/sites-available/00-default /etc/nginx/sites-enabled/
```

### 3.6 Test and Reload

```bash
# Test configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx

# Verify it's running
sudo systemctl status nginx
curl -I http://localhost
```

---

## Phase 4: Site Templates

### 4.1 Template: Static Site with HTTPS

```bash
# Example: static.example.com
DOMAIN="static.example.com"

# Create site directory
sudo mkdir -p /var/www/$DOMAIN/public
sudo chown -R www-data:www-data /var/www/$DOMAIN

# Request certificate
sudo certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /etc/letsencrypt/cloudflare/credentials.ini \
  --dns-cloudflare-propagation-seconds 30 \
  -d $DOMAIN \
  --non-interactive \
  --agree-tos \
  --email your@email.com

# Create site config
sudo tee /etc/nginx/sites-available/$DOMAIN << EOF
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

    # SSL certificates
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/nginx/snippets/ssl-params.conf;

    # Document root
    root /var/www/$DOMAIN/public;
    index index.html index.htm;

    # Logging
    access_log /var/log/nginx/${DOMAIN}.access.log main;
    error_log /var/log/nginx/${DOMAIN}.error.log;

    # Rate limiting
    limit_req zone=general burst=20 nodelay;

    # Static file handling
    location / {
        try_files \$uri \$uri/ =404;
    }

    # Cache static assets
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Enable site
sudo ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### 4.2 Template: Reverse Proxy to Application

```bash
# Example: api.example.com proxying to Go binary on port 8080
DOMAIN="api.example.com"
UPSTREAM_PORT="8080"

# Request certificate
sudo certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /etc/letsencrypt/cloudflare/credentials.ini \
  --dns-cloudflare-propagation-seconds 30 \
  -d $DOMAIN \
  --non-interactive \
  --agree-tos \
  --email your@email.com

# Create site config
sudo tee /etc/nginx/sites-available/$DOMAIN << EOF
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

    # SSL certificates
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/nginx/snippets/ssl-params.conf;

    # Logging
    access_log /var/log/nginx/${DOMAIN}.access.log main;
    error_log /var/log/nginx/${DOMAIN}.error.log;

    # Rate limiting (higher for API)
    limit_req zone=api burst=50 nodelay;

    location / {
        include /etc/nginx/snippets/proxy-params.conf;
        proxy_pass http://127.0.0.1:$UPSTREAM_PORT;
    }
}
EOF

# Enable site
sudo ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### 4.3 Template: Reverse Proxy to Docker Container

```bash
# Example: app.example.com proxying to Docker container
DOMAIN="app.example.com"
CONTAINER_NAME="myapp"
CONTAINER_PORT="3000"

# Request certificate (same as above)
sudo certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /etc/letsencrypt/cloudflare/credentials.ini \
  --dns-cloudflare-propagation-seconds 30 \
  -d $DOMAIN \
  --non-interactive \
  --agree-tos \
  --email your@email.com

# Create site config with Docker networking
sudo tee /etc/nginx/sites-available/$DOMAIN << EOF
# Define upstream for Docker container
upstream ${CONTAINER_NAME}_upstream {
    server 127.0.0.1:$CONTAINER_PORT;
    keepalive 32;
}

# HTTP - redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

# HTTPS - reverse proxy to Docker
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;

    # SSL certificates
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/nginx/snippets/ssl-params.conf;

    # Logging
    access_log /var/log/nginx/${DOMAIN}.access.log main;
    error_log /var/log/nginx/${DOMAIN}.error.log;

    # Rate limiting
    limit_req zone=general burst=20 nodelay;

    location / {
        include /etc/nginx/snippets/proxy-params.conf;
        proxy_pass http://${CONTAINER_NAME}_upstream;
    }

    # Health check endpoint (bypass rate limiting)
    location /health {
        include /etc/nginx/snippets/proxy-params.conf;
        proxy_pass http://${CONTAINER_NAME}_upstream;
        limit_req off;
    }
}
EOF

# Enable site
sudo ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```


## Phase 5: Automatic Certificate Renewal

### 5.1 Configure Certbot Systemd Timer

Ubuntu's certbot package includes a systemd timer for automatic renewal. Verify it's enabled:

```bash
# Check timer status
sudo systemctl status certbot.timer

# If not enabled, enable it
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

# List timers to verify
sudo systemctl list-timers | grep certbot
```

### 5.2 Configure Post-Renewal Hook

```bash
# Create nginx reload hook
sudo tee /etc/letsencrypt/renewal-hooks/deploy/01-reload-nginx << 'EOF'
#!/bin/bash
# Reload nginx after certificate renewal
systemctl reload nginx
EOF

sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/01-reload-nginx
```

### 5.3 Test Renewal

```bash
# Dry run renewal test
sudo certbot renew --dry-run
```

---

## Phase 6: Monitoring Integration

### 6.1 Enable Nginx Stub Status for Prometheus

```bash
# Create monitoring endpoint config
sudo tee /etc/nginx/conf.d/stub-status.conf << 'EOF'
# Nginx stub status for Prometheus nginx-exporter
server {
    listen 127.0.0.1:8080;
    server_name localhost;

    location /nginx_status {
        stub_status on;
        allow 127.0.0.1;
        deny all;
    }

    # Health check endpoint
    location /health {
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

sudo nginx -t && sudo systemctl reload nginx

# Test stub status
curl http://127.0.0.1:8080/nginx_status
```

### 6.2 Install nginx-prometheus-exporter

```bash
# Download nginx-prometheus-exporter
cd /tmp
wget https://github.com/nginxinc/nginx-prometheus-exporter/releases/download/v1.1.0/nginx-prometheus-exporter_1.1.0_linux_amd64.tar.gz
tar xzf nginx-prometheus-exporter_1.1.0_linux_amd64.tar.gz
sudo mv nginx-prometheus-exporter /usr/local/bin/

# Create systemd service
sudo tee /etc/systemd/system/nginx-prometheus-exporter.service << 'EOF'
[Unit]
Description=Nginx Prometheus Exporter
After=network.target nginx.service

[Service]
Type=simple
ExecStart=/usr/local/bin/nginx-prometheus-exporter -nginx.scrape-uri=http://127.0.0.1:8080/nginx_status
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable nginx-prometheus-exporter
sudo systemctl start nginx-prometheus-exporter

# Verify metrics available
curl http://localhost:9113/metrics
```

### 6.3 Add to Prometheus Scrape Config

Add to your existing Prometheus config (`/etc/prometheus/prometheus.yml`):

```yaml
scrape_configs:
  - job_name: 'nginx'
    static_configs:
      - targets: ['localhost:9113']
```

Then reload Prometheus:
```bash
sudo systemctl reload prometheus
```

---

## Phase 7: Management Script

### 7.1 Create Management Script

```bash
# Create the management script
sudo tee /usr/local/bin/manage-nginx.sh << 'EOF'
#!/bin/bash

################################################################################
# Nginx Management Script for nimbus01
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

status() {
    log_section "Nginx Status"
    echo ""
    
    # Service status
    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}✓${NC} nginx is running"
    else
        echo -e "${RED}✗${NC} nginx is stopped"
    fi
    
    # Configuration test
    if nginx -t 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Configuration is valid"
    else
        echo -e "${RED}✗${NC} Configuration has errors"
    fi
    
    # Enabled sites
    echo ""
    log_section "Enabled Sites"
    for site in /etc/nginx/sites-enabled/*; do
        if [ -f "$site" ]; then
            basename "$site"
        fi
    done
    
    # SSL Certificates
    echo ""
    log_section "SSL Certificates"
    sudo certbot certificates 2>/dev/null || echo "No certificates found"
    
    # Disk usage
    echo ""
    log_section "Log Directory Size"
    du -sh /var/log/nginx/
}

test_config() {
    log_section "Testing nginx configuration..."
    sudo nginx -t
}

reload_nginx() {
    log_section "Reloading nginx..."
    sudo nginx -t && sudo systemctl reload nginx
    log_info "nginx reloaded successfully"
}

restart_nginx() {
    log_section "Restarting nginx..."
    sudo systemctl restart nginx
    log_info "nginx restarted successfully"
}

show_logs() {
    local type="${1:-access}"
    local domain="${2:-}"
    
    if [ -n "$domain" ]; then
        log_file="/var/log/nginx/${domain}.${type}.log"
    else
        log_file="/var/log/nginx/${type}.log"
    fi
    
    if [ -f "$log_file" ]; then
        log_section "Tailing $log_file..."
        sudo tail -f "$log_file"
    else
        log_error "Log file not found: $log_file"
        echo "Available logs:"
        ls -la /var/log/nginx/
    fi
}

list_sites() {
    log_section "Available Sites"
    echo ""
    echo "Sites-available:"
    ls -la /etc/nginx/sites-available/
    echo ""
    echo "Sites-enabled:"
    ls -la /etc/nginx/sites-enabled/
}

enable_site() {
    local site="$1"
    if [ -z "$site" ]; then
        log_error "Usage: $0 enable <site-name>"
        exit 1
    fi
    
    if [ ! -f "/etc/nginx/sites-available/$site" ]; then
        log_error "Site not found: /etc/nginx/sites-available/$site"
        exit 1
    fi
    
    sudo ln -sf "/etc/nginx/sites-available/$site" "/etc/nginx/sites-enabled/$site"
    log_info "Enabled site: $site"
    reload_nginx
}

disable_site() {
    local site="$1"
    if [ -z "$site" ]; then
        log_error "Usage: $0 disable <site-name>"
        exit 1
    fi
    
    if [ ! -L "/etc/nginx/sites-enabled/$site" ]; then
        log_error "Site not enabled: $site"
        exit 1
    fi
    
    sudo rm "/etc/nginx/sites-enabled/$site"
    log_info "Disabled site: $site"
    reload_nginx
}

renew_certs() {
    log_section "Renewing SSL certificates..."
    sudo certbot renew
    reload_nginx
}

usage() {
    cat << EOF
Usage: $0 <command> [options]

Commands:
    status              Show nginx status and overview
    test                Test nginx configuration
    reload              Reload nginx configuration
    restart             Restart nginx service
    logs [type] [domain] Tail logs (access/error, optional domain)
    sites               List available and enabled sites
    enable <site>       Enable a site
    disable <site>      Disable a site
    renew               Renew SSL certificates

Examples:
    $0 status
    $0 logs access
    $0 logs error api.example.com
    $0 enable mysite.com
    $0 disable mysite.com
    $0 renew
EOF
}

case "$1" in
    status)     status ;;
    test)       test_config ;;
    reload)     reload_nginx ;;
    restart)    restart_nginx ;;
    logs)       show_logs "$2" "$3" ;;
    sites)      list_sites ;;
    enable)     enable_site "$2" ;;
    disable)    disable_site "$2" ;;
    renew)      renew_certs ;;
    -h|--help)  usage ;;
    *)
        log_error "Unknown command: $1"
        usage
        exit 1
        ;;
esac
EOF

sudo chmod +x /usr/local/bin/manage-nginx.sh
```

---

## Phase 8: Security Hardening

### 8.1 UFW Firewall Rules

```bash
# Allow SSH (if not already)
sudo ufw allow ssh

# Allow HTTP and HTTPS
sudo ufw allow 'Nginx Full'

# Enable firewall
sudo ufw enable

# Verify
sudo ufw status
```

### 8.2 Fail2ban for Nginx

```bash
# Install fail2ban
sudo apt install -y fail2ban

# Create nginx jail config
sudo tee /etc/fail2ban/jail.d/nginx.conf << 'EOF'
[nginx-http-auth]
enabled = true
port    = http,https
logpath = /var/log/nginx/*error.log
maxretry = 3
bantime = 3600

[nginx-limit-req]
enabled = true
port    = http,https
logpath = /var/log/nginx/*error.log
maxretry = 5
bantime = 3600

[nginx-botsearch]
enabled = true
port    = http,https
logpath = /var/log/nginx/*access.log
maxretry = 2
bantime = 86400
EOF

# Restart fail2ban
sudo systemctl restart fail2ban
sudo systemctl enable fail2ban

# Check status
sudo fail2ban-client status
```

---

## Phase 9: Provisioning Scripts

Create helper scripts in this dotfiles repo to automate common tasks.

### 9.1 provision_static_site.sh

See [provision_static_site.sh](./scripts/provision_static_site.sh)

### 9.2 provision_proxy_site.sh

See [provision_proxy_site.sh](./scripts/provision_proxy_site.sh)

---

## Quick Reference

### File Locations

| Purpose | Path |
|---------|------|
| Main config | `/etc/nginx/nginx.conf` |
| Sites available | `/etc/nginx/sites-available/` |
| Sites enabled | `/etc/nginx/sites-enabled/` |
| SSL snippets | `/etc/nginx/snippets/` |
| Certificates | `/etc/letsencrypt/live/<domain>/` |
| Cloudflare creds | `/etc/letsencrypt/cloudflare/credentials.ini` |
| Access logs | `/var/log/nginx/access.log` |
| Error logs | `/var/log/nginx/error.log` |
| Site logs | `/var/log/nginx/<domain>.*.log` |
| Web roots | `/var/www/<domain>/public/` |

### Common Commands

```bash
# Test configuration
sudo nginx -t

# Reload (graceful)
sudo systemctl reload nginx

# Restart (full)
sudo systemctl restart nginx

# View status
sudo systemctl status nginx

# View logs
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log

# List certificates
sudo certbot certificates

# Renew certificates (dry run)
sudo certbot renew --dry-run

# Management script
manage-nginx.sh status
manage-nginx.sh logs error
manage-nginx.sh enable mysite.com
```

### Port Reference

| Service | Port | Purpose |
|---------|------|---------|
| nginx HTTP | 80 | HTTP → HTTPS redirect |
| nginx HTTPS | 443 | Main traffic |
| nginx stub_status | 8080 (localhost) | Prometheus metrics |
| nginx-prometheus-exporter | 9113 | Metrics endpoint |

---

## Next Steps

1. [ ] Run Phase 1-3 to install and configure nginx base
2. [ ] Set up Cloudflare API token and credentials
3. [ ] Create first static site for testing
4. [ ] Configure monitoring integration with existing LGTM stack
5. [ ] Set up fail2ban for security
6. [ ] Create provisioning scripts for this dotfiles repo
