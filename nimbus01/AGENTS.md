# Agent Rules for nimbus01

This directory contains provisioning scripts, plans, and configuration for nimbus01 (MINISFORUM MS-A2, AMD Ryzen 9 9955HX, 96GB RAM, Ubuntu Server 22.04.5 LTS).

## Keep This File Up To Date

When you make changes to nimbus01's configuration, services, or plans, **update this file** to reflect the current state. This is the single source of truth for agents working on this machine.

## Key Plans and Documentation

| Topic | Location |
|-------|----------|
| Nginx setup (install, config, templates, monitoring, security) | `webserver/nginx_webserver_plan.md` |
| LAN reverse proxy (proxying domains to internal servers) | `webserver/lan_reverse_proxy_plan.md` |
| Site provisioning scripts | `webserver/scripts/` |
| LGTM monitoring stack | `lgtm/` |
| General server setup | `general/` |
| iperf3 network testing | `iperf3/` |

## Server Architecture

- **OS**: Ubuntu Server 22.04.5 LTS
- **Service manager**: systemd (`systemctl`)
- **Web server**: nginx
- **SSL**: Let's Encrypt via certbot with Cloudflare DNS plugin
- **Services run as**: `www-data` (nginx), `root` (certbot)

## Nginx Overview

- **Main config**: `/etc/nginx/nginx.conf`
- **Sites**: `/etc/nginx/sites-available/` and `/etc/nginx/sites-enabled/`
- **Shared snippets**: `/etc/nginx/snippets/ssl-params.conf`, `/etc/nginx/snippets/proxy-params.conf`
- **Logs**: `/var/log/nginx/`
- **Web roots**: `/var/www/<domain>/public/`
- **Global upload limit**: `client_max_body_size 100M` (set in `nginx.conf` `http` block)

### Active Sites

| Domain | Type | Backend |
|--------|------|---------|
| `weshootfilm.com` | Static site | Served locally from `/var/www/weshootfilm.com/public` |
| `nielsshootsfilm.com` | Reverse proxy | `http://10.1.0.2` (macminiserver over LAN) |
| `nimbus.wtf` | Reverse proxy | `http://10.1.0.2` (macminiserver over LAN) |
| `00-default` | Catch-all | Returns 444 (drops unmatched requests) |

### Reverse Proxy Architecture

nimbus01 is the single public-facing server. It terminates SSL and proxies traffic to internal LAN servers over plaintext HTTP. See `webserver/lan_reverse_proxy_plan.md` for details.

## Common Commands

```bash
sudo nginx -t                       # Test config
sudo systemctl reload nginx         # Graceful reload
sudo systemctl status nginx         # Check status
sudo certbot certificates           # List certs
sudo certbot renew --dry-run        # Test renewal
manage-nginx.sh status              # Management script
```
