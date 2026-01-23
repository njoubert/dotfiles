# Nimbus01 Webserver Scripts

Provisioning and management scripts for nginx on nimbus01 (Ubuntu Server 22.04).

## Scripts

| Script | Purpose |
|--------|---------|
| `provision_static_site.sh` | Create a new static website with HTTPS |
| `provision_proxy_site.sh` | Create a reverse proxy to a backend service |

## Usage

### Static Site

```bash
# Basic usage
sudo ./provision_static_site.sh example.com

# With custom email
sudo ./provision_static_site.sh example.com admin@example.com

# With source directory to copy
sudo ./provision_static_site.sh example.com admin@example.com /path/to/static/files
```

### Reverse Proxy

```bash
# Basic API proxy
sudo ./provision_proxy_site.sh api.example.com 8080

# Application with health check
sudo ./provision_proxy_site.sh app.example.com 3000 admin@example.com app

# WebSocket service
sudo ./provision_proxy_site.sh ws.example.com 9000 admin@example.com websocket
```

## Prerequisites

Before running these scripts, ensure:

1. nginx is installed and configured (see Phase 1-3 in `nginx_webserver_plan.md`)
2. Cloudflare credentials are set up at `/etc/letsencrypt/cloudflare/credentials.ini`
3. SSL snippets exist at `/etc/nginx/snippets/ssl-params.conf` and `proxy-params.conf`

## Management

After provisioning, use the management script:

```bash
# Check status
manage-nginx.sh status

# View logs
manage-nginx.sh logs access example.com
manage-nginx.sh logs error example.com

# Enable/disable sites
manage-nginx.sh enable example.com
manage-nginx.sh disable example.com

# Reload after manual config changes
manage-nginx.sh reload
```
