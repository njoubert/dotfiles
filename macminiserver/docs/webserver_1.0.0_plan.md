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
- **Wordpress Support** We want to be able to host Wordpress websites and similar blogging platforms (Ghost?) for lydiajoubert.com and zs1aaz.com
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

## Approach: Caddy Server (Hybrid Simplicity)

### Architecture Overview

```
Internet → Router → macOS firewall → Caddy (bare metal)
                                      ├→ Static sites (local files)
                                      ├→ Docker containers (reverse proxy)
                                      │  ├→ WordPress + MySQL containers (lydiajoubert.com)
                                      │  ├→ WordPress + MySQL containers (zs1aaz.com)
                                      │  └→ App containers
```

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

#### 3. Docker Compose
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
