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

## Approach 1: Bare Metal nginx + Docker Containers

### Architecture Overview

```
Internet → Router (port forward) → macOS firewall → nginx (bare metal)
                                                      ├→ Static sites (local files)
                                                      ├→ Docker containers (reverse proxy)
                                                      │  ├→ wordpress-site1 + mysql1
                                                      │  ├→ wordpress-site2 + mysql2
                                                      │  ├→ go-api-container
                                                      │  └→ webrtc-app-container
```

### How This Meets Requirements

- **✅ Long-term Stability**: nginx is the most battle-tested web server (20+ years)
- **✅ Heterogeneous Sites**: Static files served directly, dynamic apps in containers
- **✅ SSL/TLS**: Certbot with Cloudflare DNS-01 challenge, auto-renewal
- **✅ Simple Addition**: Drop files in `/usr/local/var/www/`, add nginx server block
- **✅ Efficiency**: Minimal overhead for static serving, containers only for what needs isolation
- **✅ Fast**: nginx is one of the fastest static file servers available
- **✅ Maintainable**: Standard tools, well-documented, large community
- **✅ Dependency Isolation**: Each app in separate Docker Compose project
- **✅ WordPress Support**: Official WordPress Docker images, well-maintained
- **✅ WordPress Isolation**: Each WP site in isolated container with own database
- **✅ Future Projects**: Easy to add new Docker Compose projects
- **✅ Project Isolation**: Containers provide process, filesystem, and network isolation
- **✅ Handle Traffic Spikes**: nginx worker processes handle concurrent connections efficiently
- **✅ Rate Limiting**: nginx built-in rate limiting + fail2ban for system-level protection
- **✅ Log Management**: nginx logs + Docker json-file driver with rotation
- **✅ Cloudflare Integration**: DNS-01 challenge works seamlessly with your existing setup

**Advanced Features (v1.2+)**: Resource limits, monitoring/alerting, automated backups

### Detailed Plan

#### 1. nginx Installation & Configuration (Bare Metal)
```bash
brew install nginx
```

Configuration structure:
- Main config: `/usr/local/etc/nginx/nginx.conf`
- Site configs: `/usr/local/etc/nginx/servers/*.conf`
- Static content: `/usr/local/var/www/`
- Logs: `/usr/local/var/log/nginx/`
- Enable as LaunchDaemon for auto-start on boot

#### 2. SSL/TLS Setup (Required)
```bash
brew install certbot
```

**Cloudflare DNS-01 Challenge** (works even without exposed port 80):
```bash
# Set up Cloudflare credentials
export CLOUDFLARE_API_TOKEN="your-token"

# Get wildcard certificate
certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials ~/.cloudflare.ini \
  -d njoubert.com -d *.njoubert.com

# Auto-renewal via LaunchDaemon
```

**Auto-renewal plist**: `/Library/LaunchDaemons/com.certbot.renew.plist`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.certbot.renew</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/certbot</string>
        <string>renew</string>
        <string>--post-hook</string>
        <string>brew services reload nginx</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</dict>
</plist>
```

#### 3. Rate Limiting & Security (Required - nginx config)
```nginx
# /usr/local/etc/nginx/nginx.conf
http {
    # Rate limiting zones - protects against DDoS and abuse
    limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=wordpress:10m rate=2r/s;
    limit_req_zone $binary_remote_addr zone=api:10m rate=20r/s;
    
    # Connection limits per IP
    limit_conn_zone $binary_remote_addr zone=addr:10m;
    limit_conn addr 10;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # Include site-specific configs
    include servers/*;
}
```

#### 4. Static Sites Configuration
```nginx
# /usr/local/etc/nginx/servers/njoubert.com.conf
server {
    listen 80;
    server_name njoubert.com www.njoubert.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name njoubert.com www.njoubert.com;
    
    ssl_certificate /usr/local/etc/letsencrypt/live/njoubert.com/fullchain.pem;
    ssl_certificate_key /usr/local/etc/letsencrypt/live/njoubert.com/privkey.pem;
    
    root /usr/local/var/www/njoubert.com;
    index index.html;
    
    # Enable gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
    
    # Rate limiting
    limit_req zone=general burst=20 nodelay;
    
    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Logging
    access_log /usr/local/var/log/nginx/njoubert.com-access.log;
    error_log /usr/local/var/log/nginx/njoubert.com-error.log;
}

# File server with directory browsing
server {
    listen 443 ssl http2;
    server_name files.njoubert.com;
    
    ssl_certificate /usr/local/etc/letsencrypt/live/njoubert.com/fullchain.pem;
    ssl_certificate_key /usr/local/etc/letsencrypt/live/njoubert.com/privkey.pem;
    
    root /usr/local/var/www/files.njoubert.com;
    autoindex on;
    
    limit_req zone=general burst=20 nodelay;
}
```

#### 4. Docker Compose for Each Project
```yaml
# Example: wordpress-lydiajoubert/docker-compose.yml
version: '3.8'
services:
  wordpress:
    image: wordpress:latest
    restart: always
    ports:
      - "127.0.0.1:8001:80"  # Bind to localhost only - security!
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_DB_USER: wpuser
      WORDPRESS_DB_PASSWORD: ${WP_DB_PASSWORD}
    volumes:
      - ./wp-content:/var/www/html/wp-content
      - ./uploads.ini:/usr/local/etc/php/conf.d/uploads.ini  # Increase upload limits
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  db:
    image: mysql:8.0
    restart: always
    environment:
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wpuser
      MYSQL_PASSWORD: ${WP_DB_PASSWORD}
      MYSQL_RANDOM_ROOT_PASSWORD: '1'
    volumes:
      - ./db-data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 30s
      timeout: 10s
      retries: 3
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

# Isolated network for this project
networks:
  default:
    driver: bridge
```

**Note**: Resource limits (CPU/memory) will be added in v1.2

#### 5. nginx Reverse Proxy Configuration
```nginx
# /usr/local/etc/nginx/servers/lydiajoubert.com.conf
upstream lydiajoubert_wordpress {
    server 127.0.0.1:8001;
    keepalive 32;
}

server {
    listen 80;
    server_name lydiajoubert.com www.lydiajoubert.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name lydiajoubert.com www.lydiajoubert.com;
    
    ssl_certificate /usr/local/etc/letsencrypt/live/lydiajoubert.com/fullchain.pem;
    ssl_certificate_key /usr/local/etc/letsencrypt/live/lydiajoubert.com/privkey.pem;
    
    # WordPress-specific rate limiting
    limit_req zone=wordpress burst=10 nodelay;
    
    # Increase timeouts for WordPress admin
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
    
    # Client body size for file uploads
    client_max_body_size 50M;
    
    location / {
        proxy_pass http://lydiajoubert_wordpress;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # HTTP/1.1 for keepalive
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }
    
    # Cache static assets from WordPress
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg)$ {
        proxy_pass http://lydiajoubert_wordpress;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    # Protect sensitive WordPress files
    location ~ /\. {
        deny all;
    }
    
    location ~ /wp-config.php {
        deny all;
    }
    
    access_log /usr/local/var/log/nginx/lydiajoubert.com-access.log;
    error_log /usr/local/var/log/nginx/lydiajoubert.com-error.log;
}

# Hybrid site: static frontend + API backend
server {
    listen 443 ssl http2;
    server_name nielsshootsfilm.com www.nielsshootsfilm.com;
    
    ssl_certificate /usr/local/etc/letsencrypt/live/nielsshootsfilm.com/fullchain.pem;
    ssl_certificate_key /usr/local/etc/letsencrypt/live/nielsshootsfilm.com/privkey.pem;
    
    root /usr/local/var/www/nielsshootsfilm.com;
    
    # API requests go to container
    location /api/ {
        proxy_pass http://127.0.0.1:8003;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        limit_req zone=api burst=50 nodelay;
    }
    
    # Everything else is static
    location / {
        try_files $uri $uri/ /index.html;
        limit_req zone=general burst=20 nodelay;
    }
}
```

#### 6. Directory Structure
```
/usr/local/var/www/
├── njoubert.com/           # Static site
├── nielsshootsfilm.com/    # Static frontend
└── files.njoubert.com/     # Static file store

~/webserver/
├── scripts/
│   └── manage.sh           # Start/stop/status helper
├── wordpress-lydiajoubert/
│   ├── docker-compose.yml
│   ├── .env                # Secrets (gitignored!)
│   ├── wp-content/         # WordPress files
│   ├── db-data/            # MySQL data
│   └── uploads.ini         # PHP config
├── wordpress-zs1aaz/
│   ├── docker-compose.yml
│   ├── .env
│   ├── wp-content/
│   └── db-data/
├── go-api-nielsshootsfilm/
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── .env
│   └── app/
└── webrtc-rtc/
    ├── Dockerfile
    ├── docker-compose.yml
    ├── .env
    └── app/
```

**Note**: Backup directory structure will be added in v1.6

#### 7. Management & Operations

**Simple management script** (`~/webserver/scripts/manage.sh`):
```bash
#!/bin/bash

case "$1" in
  start)
    echo "Starting nginx..."
    brew services start nginx
    
    echo "Starting Docker containers..."
    for site in ~/webserver/wordpress-* ~/webserver/go-api-* ~/webserver/webrtc-*/; do
      [ -d "$site" ] || continue
      echo "  Starting $(basename $site)..."
      (cd "$site" && docker-compose up -d)
    done
    ;;
    
  stop)
    echo "Stopping Docker containers..."
    for site in ~/webserver/wordpress-* ~/webserver/go-api-* ~/webserver/webrtc-*/; do
      [ -d "$site" ] || continue
      (cd "$site" && docker-compose down)
    done
    
    echo "Stopping nginx..."
    brew services stop nginx
    ;;
    
  restart)
    $0 stop
    sleep 2
    $0 start
    ;;
    
  status)
    echo "=== nginx Status ==="
    brew services list | grep nginx
    echo ""
    echo "=== Docker Containers ==="
    docker ps --format "table {{.Names}}\t{{.Status}}"
    echo ""
    echo "=== Disk Usage ==="
    df -h /
    ;;
    
  logs)
    if [ "$2" = "nginx" ]; then
      tail -f /usr/local/var/log/nginx/error.log
    elif [ -n "$2" ]; then
      docker logs -f "$2"
    else
      echo "Usage: $0 logs <nginx|container-name>"
    fi
    ;;
    
  *)
    echo "Usage: $0 {start|stop|restart|status|logs <service>}"
    exit 1
    ;;
esac
```

**Check log files**:
```bash
# nginx logs
/usr/local/var/log/nginx/access.log
/usr/local/var/log/nginx/error.log
/usr/local/var/log/nginx/<site>-access.log
/usr/local/var/log/nginx/<site>-error.log

# Docker logs (JSON with rotation already configured)
docker logs <container-name>
docker logs -f <container-name>  # Follow
docker logs --tail 100 <container-name>  # Last 100 lines
```

**Advanced Features (v1.2+)**:
- v1.2: Resource limits to prevent containers from starving each other
- v1.4: Prometheus + Grafana monitoring stack with dashboards
- v1.6: Automated backup scripts with retention policies
- v1.6: Automated backup scripts with retention policies

### Pros of Approach 1

- **✅ Maximum Performance**: nginx directly serves static files (zero overhead)
- **✅ Resource Efficient**: Static sites use ~10-20MB RAM (nginx), containers only when needed
- **✅ Battle-tested Stack**: nginx has 20+ years of production use, extremely stable
- **✅ Simple Debugging**: Clear separation - check nginx logs or Docker logs
- **✅ Flexible Scaling**: Each site scales independently based on actual traffic
- **✅ Easy Static Updates**: Edit files directly, nginx auto-reloads
- **✅ Quick v1.0**: Core functionality without complex monitoring/backup setup
- **✅ Clear Upgrade Path**: Easy to add monitoring and backups in v1.2-v1.6

### Cons of Approach 1

- **❌ Manual Configuration**: Adding sites requires editing nginx config files
- **❌ SSL Management**: Need to set up certbot correctly (one-time setup cost)
- **❌ Mixed Management**: nginx (bare metal) + Docker (containers) = two systems to manage
- **❌ No Service Discovery**: Must manually configure reverse proxy for new containers
- **❌ No Built-in Monitoring**: Need to add monitoring stack later (v1.4)
- **❌ Manual Backups**: Need to implement backup scripts later (v1.6)

### When to Choose Approach 1

Choose this if:
- You want maximum performance for static files
- You're comfortable with nginx or want to learn it (valuable skill)
- You want the most widely-deployed, proven solution
- Resource efficiency is important (minimal overhead)
- You prefer starting simple and adding features incrementally

---

## Approach 2: Full Docker with Traefik

### Architecture Overview

```
Internet → Router → macOS firewall → Traefik (Docker) → Docker containers
                                       (SSL, routing)    ├→ Static sites (nginx:alpine containers)
                                                         ├→ WordPress containers
                                                         ├→ Go API containers
                                                         └→ WebRTC containers
```

### Key Changes from Requirements

⚠️ **Relaxed Requirement**: "Bare metal static serving" → "Static sites in lightweight nginx:alpine containers"
- **Rationale**: Unified Docker management, automatic HTTPS, built-in service discovery
- **Trade-off**: ~20-30MB RAM per static site container, but massive simplification
- **Benefit**: Complete project isolation including static sites

### How This Meets Requirements

- **✅ Long-term Stability**: Container images are versioned, reproducible deployments
- **✅ Heterogeneous Sites**: All sites treated equally as containers (consistency!)
- **✅ SSL/TLS**: Traefik auto-provisions Let's Encrypt certs via DNS challenge
- **✅ Simple Addition**: Add new container with labels, zero config file edits
- **✅ Efficiency**: Lightweight alpine images, shared base layers
- **✅ Fast**: nginx:alpine is fast; Traefik adds minimal latency (~1-2ms)
- **✅ Maintainable**: Declarative configuration (labels), visual dashboard
- **✅ Dependency Isolation**: Perfect - every site is fully isolated container
- **✅ WordPress Support**: Standard WordPress containers work seamlessly
- **✅ WordPress Isolation**: Each WP site in own container with private network
- **✅ Future Projects**: Just add docker-compose.yml with Traefik labels
- **✅ Project Isolation**: Maximum isolation - network, filesystem, process
- **✅ Handle Traffic Spikes**: Traefik load balances, easy to add replicas
- **✅ Rate Limiting**: Traefik middleware for rate limiting per route
- **✅ Log Management**: Docker json-file logging with rotation
- **✅ Cloudflare Integration**: Traefik natively supports Cloudflare DNS challenge

**Advanced Features (v1.2+)**: Resource limits, monitoring/alerting, automated backups

### Detailed Plan

#### 1. Network Setup
```bash
# Create shared network for Traefik
docker network create web
```

#### 2. Traefik as Reverse Proxy
```yaml
# ~/webserver/traefik/docker-compose.yml
version: '3.8'

services:
  traefik:
    image: traefik:v2.10
    container_name: traefik
    restart: always
    command:
      # API and dashboard
      - "--api.dashboard=true"
      
      # Docker provider
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=web"
      
      # Entry points
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      
      # Redirect HTTP to HTTPS
      - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
      - "--entrypoints.web.http.redirections.entryPoint.scheme=https"
      
      # SSL/TLS with Let's Encrypt via Cloudflare DNS
      - "--certificatesresolvers.letsencrypt.acme.dnschallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.dnschallenge.provider=cloudflare"
      - "--certificatesresolvers.letsencrypt.acme.email=njoubert@gmail.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
      
      # Access logs
      - "--accesslog=true"
      - "--accesslog.filepath=/var/log/traefik/access.log"
      
      # Log level
      - "--log.level=INFO"
    
    ports:
      - "80:80"
      - "443:443"
    
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt
      - ./logs:/var/log/traefik
    
    environment:
      - CF_DNS_API_TOKEN=${CLOUDFLARE_API_TOKEN}
    
    networks:
      - web
    
    labels:
      # Enable Traefik for itself (dashboard)
      - "traefik.enable=true"
      
      # Dashboard
      - "traefik.http.routers.dashboard.rule=Host(`traefik.njoubert.com`)"
      - "traefik.http.routers.dashboard.entrypoints=websecure"
      - "traefik.http.routers.dashboard.tls.certresolver=letsencrypt"
      - "traefik.http.routers.dashboard.service=api@internal"
      
      # Dashboard auth (generate with: htpasswd -nb admin password)
      - "traefik.http.routers.dashboard.middlewares=dashboard-auth"
      - "traefik.http.middlewares.dashboard-auth.basicauth.users=admin:$$apr1$$hash$$here"
      
      # Global rate limiting middleware
      - "traefik.http.middlewares.rate-limit-general.ratelimit.average=100"
      - "traefik.http.middlewares.rate-limit-general.ratelimit.burst=50"
      - "traefik.http.middlewares.rate-limit-general.ratelimit.period=1m"
      
      # WordPress-specific rate limiting
      - "traefik.http.middlewares.rate-limit-wordpress.ratelimit.average=20"
      - "traefik.http.middlewares.rate-limit-wordpress.ratelimit.burst=10"
      - "traefik.http.middlewares.rate-limit-wordpress.ratelimit.period=1m"
      
      # API rate limiting
      - "traefik.http.middlewares.rate-limit-api.ratelimit.average=50"
      - "traefik.http.middlewares.rate-limit-api.ratelimit.burst=25"
      - "traefik.http.middlewares.rate-limit-api.ratelimit.period=1m"
      
      # Security headers
      - "traefik.http.middlewares.security-headers.headers.frameDeny=true"
      - "traefik.http.middlewares.security-headers.headers.contentTypeNosniff=true"
      - "traefik.http.middlewares.security-headers.headers.browserXssFilter=true"
      - "traefik.http.middlewares.security-headers.headers.stsSeconds=31536000"
      - "traefik.http.middlewares.security-headers.headers.stsIncludeSubdomains=true"

networks:
  web:
    external: true
```

**Note**: Prometheus metrics will be added in v1.4

#### 3. Static Site Container Example
```yaml
# ~/webserver/sites/njoubert-com/docker-compose.yml
version: '3.8'

services:
  web:
    image: nginx:alpine
    container_name: njoubert-com
    restart: always
    volumes:
      - ./html:/usr/share/nginx/html:ro
      - ./nginx.conf:/etc/nginx/nginx.conf:ro  # Custom nginx config
    
    networks:
      - web
    
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3
    
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    
    labels:
      # Enable Traefik
      - "traefik.enable=true"
      
      # Router configuration
      - "traefik.http.routers.njoubert.rule=Host(`njoubert.com`) || Host(`www.njoubert.com`)"
      - "traefik.http.routers.njoubert.entrypoints=websecure"
      - "traefik.http.routers.njoubert.tls.certresolver=letsencrypt"
      
      # Apply middlewares
      - "traefik.http.routers.njoubert.middlewares=rate-limit-general@docker,security-headers@docker"
      
      # Service (port)
      - "traefik.http.services.njoubert.loadbalancer.server.port=80"

networks:
  web:
    external: true
```

**Note**: Resource limits will be added in v1.2
          memory: 16M
    
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3
    
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    
    labels:
      # Enable Traefik
      - "traefik.enable=true"
      
      # Router configuration
      - "traefik.http.routers.njoubert.rule=Host(`njoubert.com`) || Host(`www.njoubert.com`)"
      - "traefik.http.routers.njoubert.entrypoints=websecure"
      - "traefik.http.routers.njoubert.tls.certresolver=letsencrypt"
      
      # Apply middlewares
      - "traefik.http.routers.njoubert.middlewares=rate-limit-general@docker,security-headers@docker"
      
      # Service (port)
      - "traefik.http.services.njoubert.loadbalancer.server.port=80"

networks:
  web:
    external: true
```

**Custom nginx.conf** for better caching:
```nginx
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    sendfile on;
    tcp_nopush on;
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
    
    server {
        listen 80;
        server_name _;
        root /usr/share/nginx/html;
        index index.html;
        
        # Cache static assets
        location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
        
        # Security
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
    }
}
```

#### 4. WordPress Container Example
```yaml
# ~/webserver/sites/lydiajoubert-com/docker-compose.yml
version: '3.8'

services:
  wordpress:
    image: wordpress:latest
    container_name: lydiajoubert-wordpress
    restart: always
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_DB_USER: wpuser
      WORDPRESS_DB_PASSWORD: ${WP_DB_PASSWORD}
    volumes:
      - ./wp-content:/var/www/html/wp-content
      - ./uploads.ini:/usr/local/etc/php/conf.d/uploads.ini
    
    networks:
      - web
      - lydiajoubert-internal
    
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3
    
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.lydiajoubert.rule=Host(`lydiajoubert.com`) || Host(`www.lydiajoubert.com`)"
      - "traefik.http.routers.lydiajoubert.entrypoints=websecure"
      - "traefik.http.routers.lydiajoubert.tls.certresolver=letsencrypt"
      - "traefik.http.routers.lydiajoubert.middlewares=rate-limit-wordpress@docker,security-headers@docker"
      - "traefik.http.services.lydiajoubert.loadbalancer.server.port=80"

  db:
    image: mysql:8.0
    container_name: lydiajoubert-db
    restart: always
    environment:
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wpuser
      MYSQL_PASSWORD: ${WP_DB_PASSWORD}
      MYSQL_RANDOM_ROOT_PASSWORD: '1'
    volumes:
      - db-data:/var/lib/mysql
    
    networks:
      - lydiajoubert-internal
    
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 30s
      timeout: 10s
      retries: 3
    
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

networks:
  web:
    external: true
  lydiajoubert-internal:
    driver: bridge
    internal: true  # No internet access for DB

volumes:
  db-data:
```

**Note**: Resource limits will be added in v1.2

#### 5. Management Scripts
```bash
#!/bin/bash
# ~/webserver/scripts/manage.sh

TRAEFIK_DIR="$HOME/webserver/traefik"
SITES_DIR="$HOME/webserver/sites"

case "$1" in
  start)
    echo "Starting Traefik..."
    (cd "$TRAEFIK_DIR" && docker-compose up -d)
    
    echo "Starting all sites..."
    for site in "$SITES_DIR"/*/; do
      site_name=$(basename "$site")
      echo "  Starting $site_name..."
      (cd "$site" && docker-compose up -d)
    done
    
    echo ""
    echo "All services started!"
    echo "Traefik dashboard: https://traefik.njoubert.com"
    ;;
    
  stop)
    echo "Stopping all sites..."
    for site in "$SITES_DIR"/*/; do
      (cd "$site" && docker-compose down)
    done
    
    echo "Stopping Traefik..."
    (cd "$TRAEFIK_DIR" && docker-compose down)
    ;;
    
  restart)
    $0 stop
    sleep 2
    $0 start
    ;;
    
  status)
    echo "=== Docker Containers ==="
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo "=== Resource Usage ==="
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
    ;;
    
  logs)
    if [ -z "$2" ]; then
      echo "Usage: $0 logs <service-name>"
      echo "Example: $0 logs traefik"
      exit 1
    fi
    docker logs -f "$2"
    ;;
    
  update)
    echo "Pulling latest images..."
    for site in "$SITES_DIR"/*/; do
      (cd "$site" && docker-compose pull)
    done
    (cd "$TRAEFIK_DIR" && docker-compose pull)
    
    echo ""
    echo "Images updated. Run '$0 restart' to apply changes."
    ;;
    
  *)
    echo "Usage: $0 {start|stop|restart|status|logs <name>|update}"
    exit 1
    ;;
esac
```

**Check logs**:
```bash
# Traefik logs
docker logs traefik
docker logs -f traefik  # Follow

# Site logs
docker logs lydiajoubert-wordpress
docker logs lydiajoubert-db

# All container logs
docker-compose logs -f  # From within a site directory
```

**Advanced Features (v1.2+)**:
- v1.2: Resource limits to prevent containers from starving each other
- v1.4: Prometheus metrics integration with Grafana dashboards
- v1.6: Automated backup scripts for Docker volumes and databases

#### 6. Management Scripts
```bash
# ~/webserver/scripts/manage.sh
#!/bin/bash

TRAEFIK_DIR="$HOME/webserver/traefik"
SITES_DIR="$HOME/webserver/sites"
MONITORING_DIR="$HOME/webserver/monitoring"

case "$1" in
  start)
    echo "Starting Traefik..."
    (cd "$TRAEFIK_DIR" && docker-compose up -d)
    
    echo "Starting monitoring..."
    (cd "$MONITORING_DIR" && docker-compose up -d)
    
    echo "Starting all sites..."
    for site in "$SITES_DIR"/*/; do
      site_name=$(basename "$site")
      echo "  Starting $site_name..."
      (cd "$site" && docker-compose up -d)
    done
    
    echo ""
    echo "All services started!"
    echo "Traefik dashboard: https://traefik.njoubert.com"
    echo "Grafana: https://grafana.njoubert.com"
    ;;
    
  stop)
    echo "Stopping all sites..."
    for site in "$SITES_DIR"/*/; do
      (cd "$site" && docker-compose down)
    done
    
    echo "Stopping monitoring..."
    (cd "$MONITORING_DIR" && docker-compose down)
    
    echo "Stopping Traefik..."
    (cd "$TRAEFIK_DIR" && docker-compose down)
    ;;
    
  restart)
    $0 stop
    sleep 2
    $0 start
    ;;
    
  status)
    echo "=== Docker Containers ==="
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo "=== Resource Usage ==="
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
    ;;
    
  logs)
    if [ -z "$2" ]; then
      echo "Usage: $0 logs <service-name>"
      echo "Example: $0 logs traefik"
      exit 1
    fi
    docker logs -f "$2"
    ;;
    
  update)
    echo "Pulling latest images..."
    for site in "$SITES_DIR"/*/; do
      (cd "$site" && docker-compose pull)
    done
    (cd "$TRAEFIK_DIR" && docker-compose pull)
    (cd "$MONITORING_DIR" && docker-compose pull)
    
    echo ""
    echo "Images updated. Run '$0 restart' to apply changes."
    ;;
    
  backup)
    echo "Running backup..."
    "$HOME/webserver/scripts/backup-docker.sh"
    ;;
    
  *)
    echo "Usage: $0 {start|stop|restart|status|logs <name>|update|backup}"
    exit 1
    ;;
esac
```

Make it executable:
```bash
chmod +x ~/webserver/scripts/manage.sh
```

### Pros of Approach 2

- **✅ Unified Management**: Everything in Docker, consistent tooling
- **✅ Automatic HTTPS**: Traefik handles Let's Encrypt automatically
- **✅ Service Discovery**: Add containers with labels, no config file edits
- **✅ Built-in Dashboard**: Traefik dashboard shows all routes and services
- **✅ Better Isolation**: Each static site in own container (security boundaries)
- **✅ Easy Development**: Spin up staging environments trivially
- **✅ Modern Architecture**: Container-native, easier to migrate to k8s later if needed
- **✅ Declarative Config**: Labels in docker-compose make intent clear
- **✅ Quick v1.0**: Core functionality working fast, easy to extend

### Cons of Approach 2

- **❌ Container Overhead**: Each static site needs ~20-50MB RAM (nginx:alpine)
- **❌ Slight Performance Hit**: Extra network hop vs bare metal nginx
- **❌ Docker Desktop Dependency**: More reliance on Docker Desktop for Mac
- **❌ More Containers**: More moving parts than bare metal nginx
- **❌ No Built-in Monitoring**: Need to add monitoring stack later (v1.4)

### When to Choose Approach 2

Choose this if:
- You want everything containerized for consistency
- Service discovery and automatic routing appeal to you
- You plan to experiment frequently with new services
- You value declarative configuration (labels)
- You might migrate to Kubernetes someday
- RAM isn't a concern (you have 32GB!)

---

## Approach 3: Caddy Server (Hybrid Simplicity)

### Architecture Overview

```
Internet → Router → macOS firewall → Caddy (bare metal)
                                      ├→ Static sites (local files)
                                      ├→ Docker containers (reverse proxy)
                                      │  ├→ WordPress + MySQL containers
                                      │  └→ App containers
```

### Key Changes from Requirements

⚠️ **Relaxed Requirement**: "nginx" → "Caddy"
- **Rationale**: Automatic HTTPS, simpler config, modern by default
- **Trade-off**: Less widely deployed than nginx, but excellent for your use case

### How This Meets Requirements

- **✅ Long-term Stability**: Caddy is mature (v2.x), actively maintained, stable releases
- **✅ Heterogeneous Sites**: Static files served directly, dynamic apps in containers
- **✅ SSL/TLS**: Automatic HTTPS with zero configuration (built-in Let's Encrypt)
- **✅ Simple Addition**: Add a site block to Caddyfile, reload Caddy
- **✅ Efficiency**: Similar to nginx for static serving, minimal overhead
- **✅ Fast**: Modern HTTP/2, HTTP/3 support, optimized for static files
- **✅ Maintainable**: Caddyfile is extremely readable, minimal configuration
- **✅ Dependency Isolation**: Each app in separate Docker Compose project
- **✅ WordPress Support**: Standard WordPress containers, reverse proxy
- **✅ WordPress Isolation**: Each WP site in isolated container
- **✅ Future Projects**: Easy to add new containers and proxy routes
- **✅ Project Isolation**: Containers provide full isolation
- **✅ Handle Traffic Spikes**: Caddy handles concurrent connections efficiently
- **✅ Rate Limiting**: Built-in rate limiting middleware
- **✅ Log Management**: Caddy logs + Docker json-file logging
- **✅ Cloudflare Integration**: Native DNS challenge support

**Advanced Features (v1.2+)**: Resource limits, monitoring/alerting, automated backups

### Detailed Plan

#### 1. Caddy Installation
```bash
brew install caddy
```

#### 2. Caddyfile (Complete Config)
```caddy
# /usr/local/etc/Caddyfile

{
    email njoubert@gmail.com
    # Cloudflare DNS challenge for automatic certs
    acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}
}

# Static sites
njoubert.com, www.njoubert.com {
    root * /usr/local/var/www/njoubert.com
    file_server
    encode gzip
    
    # Rate limiting
    rate_limit {
        zone static {
            key {remote_host}
            events 100
            window 1m
        }
    }
    
    log {
        output file /usr/local/var/log/caddy/njoubert.com.log
    }
}

files.njoubert.com {
    root * /usr/local/var/www/files.njoubert.com
    file_server browse
    encode gzip
    
    log {
        output file /usr/local/var/log/caddy/files.njoubert.com.log
    }
}

# WordPress sites
lydiajoubert.com, www.lydiajoubert.com {
    reverse_proxy localhost:8001
    encode gzip
    
    rate_limit {
        zone wordpress {
            key {remote_host}
            window 1m
        }
    }
    
    log {
        output file /usr/local/var/log/caddy/lydiajoubert.com.log
    }
}

zs1aaz.com, www.zs1aaz.com {
    reverse_proxy localhost:8002
    encode gzip
    
    log {
        output file /usr/local/var/log/caddy/zs1aaz.com.log
    }
}

# Hybrid static + API site
nielsshootsfilm.com, www.nielsshootsfilm.com {
    root * /usr/local/var/www/nielsshootsfilm.com
    
    # API routes go to container
    handle /api/* {
        reverse_proxy localhost:8003
        rate_limit {
            zone api {
                key {remote_host}
                events 50
                window 1m
            }
        }
    }
    
    # Everything else is static
    handle {
        file_server
        try_files {path} {path}/ /index.html
    }
    
    encode gzip
    
    log {
        output file /usr/local/var/log/caddy/nielsshootsfilm.com.log
    }
}

# WebRTC experiment
rtc.njoubert.com {
    reverse_proxy localhost:8004
    encode gzip
    
    log {
        output file /usr/local/var/log/caddy/rtc.njoubert.com.log
    }
}
```

#### 3. Docker Compose (Same as Approach 1)
```yaml
# Example: wordpress-lydiajoubert/docker-compose.yml
version: '3.8'
services:
  wordpress:
    image: wordpress:latest
    restart: always
    ports:
      - "127.0.0.1:8001:80"
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_DB_USER: wpuser
      WORDPRESS_DB_PASSWORD: ${WP_DB_PASSWORD}
    volumes:
      - ./wp-content:/var/www/html/wp-content
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  db:
    image: mysql:8.0
    restart: always
    environment:
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wpuser
      MYSQL_PASSWORD: ${WP_DB_PASSWORD}
      MYSQL_RANDOM_ROOT_PASSWORD: '1'
    volumes:
      - ./db-data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 30s
      timeout: 10s
      retries: 3
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

networks:
  default:
    driver: bridge
```

**Note**: Resource limits will be added in v1.2

#### 4. LaunchDaemon for Caddy
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.caddyserver.caddy</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/caddy</string>
        <string>run</string>
        <string>--config</string>
        <string>/usr/local/etc/Caddyfile</string>
        <string>--envfile</string>
        <string>/usr/local/etc/caddy.env</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/usr/local/var/log/caddy-error.log</string>
    <key>StandardOutPath</key>
    <string>/usr/local/var/log/caddy.log</string>
</dict>
</plist>
```

Create environment file for Cloudflare token:
```bash
# /usr/local/etc/caddy.env
CLOUDFLARE_API_TOKEN=your_token_here
```

#### 5. Management & Operations

**Simple management commands**:
```bash
# Start Caddy
brew services start caddy

# Stop Caddy
brew services stop caddy

# Restart Caddy (after config changes)
brew services restart caddy
# Or just reload config without downtime:
caddy reload --config /usr/local/etc/Caddyfile

# Check Caddy status
brew services list | grep caddy

# View logs
tail -f /usr/local/var/log/caddy.log
tail -f /usr/local/var/log/caddy/njoubert.com.log

# Start Docker containers
for site in ~/webserver/wordpress-* ~/webserver/go-api-* ~/webserver/webrtc-*/; do
  (cd "$site" && docker-compose up -d)
done

# Check all services
echo "=== Caddy Status ==="
brew services list | grep caddy
echo ""
echo "=== Docker Containers ==="
docker ps --format "table {{.Names}}\t{{.Status}}"
```

**Advanced Features (v1.2+)**:
- v1.2: Resource limits for Docker containers
- v1.4: Monitoring stack integration
- v1.6: Automated backup scripts

### Pros of Approach 3

- **✅ Simplest Configuration**: Caddyfile is remarkably readable
- **✅ Automatic HTTPS**: Zero configuration, just works with Let's Encrypt
- **✅ Automatic Renewal**: Built-in, no cron jobs or LaunchDaemons needed
- **✅ Modern Defaults**: HTTP/2, HTTP/3, gzip compression, security headers
- **✅ Fast Static Serving**: Comparable to nginx for static content
- **✅ Easy Maintenance**: Config changes are straightforward, reload without downtime
- **✅ Good Documentation**: Modern, well-documented project
- **✅ Cloudflare Integration**: Native DNS challenge support
- **✅ Best for v1.0**: Get serving fast, add features later

### Cons of Approach 3

- **❌ Less Battle-tested**: Newer than nginx (but mature and stable since v2.0)
- **❌ Smaller Ecosystem**: Fewer third-party modules than nginx
- **❌ Memory Usage**: Slightly higher than nginx (~30-50MB vs ~10-20MB)
- **❌ Less Familiarity**: Most sysadmins know nginx better
- **❌ No Built-in Monitoring**: Need to add monitoring later (v1.4)

### When to Choose Approach 3

Choose this if:
- You want the simplest long-term maintenance
- Automatic HTTPS is a priority (it should be!)
- You value readable configuration over everything else
- You want modern defaults without tweaking
- You prefer starting simple and adding complexity only when needed

---

## Recommendation

### For Your v1.0 Requirements: **Approach 3 (Caddy) > Approach 1 (nginx) > Approach 2 (Traefik)**

**Choose Approach 3 (Caddy)** if:
- ✅ You want the simplest long-term maintenance (best match!)
- ✅ Automatic HTTPS is a priority
- ✅ You value readable configuration
- ✅ You want to get v1.0 running quickly and add features in v1.2+

**Choose Approach 1 (nginx)** if:
- ✅ You're already comfortable with nginx
- ✅ You want the absolute fastest static file serving
- ✅ You need specific nginx modules
- ✅ You want the most widely-deployed, proven solution

**Choose Approach 2 (Traefik)** if:
- ✅ You want everything containerized for consistency
- ✅ You plan to experiment frequently with new services
- ✅ Service discovery and dynamic routing appeal to you
- ✅ You might migrate to Kubernetes someday

---

## Next Steps

Once you choose an approach:

1. **Set up base infrastructure** (Approach 1 or 3: install web server; Approach 2: install Docker network)
2. **Configure SSL/TLS** with Cloudflare DNS challenge
3. **Deploy one static site** to verify the setup works
4. **Add rate limiting** and test with curl/ab
5. **Deploy one WordPress site** in Docker to verify reverse proxy
6. **Document your setup** in a runbook for future you
7. **Plan v1.2** features based on actual usage patterns

After v1.0 is stable, add advanced features:
- **v1.0.1**: Dead simple monitoring
- **v1.2**: Resource limits per container
- **v1.4**: Monitoring with Prometheus + Grafana
- **v1.6**: Automated backups with retention policies
