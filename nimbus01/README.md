# MINISFORUM MS-A1 2026.01 (nimbus01)

```
MINISFORUM MS-A2
AMD Ryzen™ 9 9955HX
96GB RAM
2TB SSD
```
## Log

### 2026.01.22 nginx install, reverse proxy nielsshootsfilm.com and nimbus.wtf

Installed nginx, along with fail2ban and certbot (with dns-cloudflare plugin for DNS-01 validation).

**Architecture:** nimbus01 is now the single public-facing webserver. It terminates SSL for all domains and reverse proxies to internal LAN servers.

| Domain | Handling |
|--------|----------|
| `weshootfilm.com` | Served directly by nimbus01 |
| `nimbus.wtf` | SSL terminated here, proxied to 10.1.0.2 (HTTP) |
| `nielsshootsfilm.com` | SSL terminated here, proxied to 10.1.0.2 (HTTP) |

**Key configs:**
- `/etc/nginx/sites-available/` - site configs
- `/etc/letsencrypt/cloudflare/credentials.ini` - Cloudflare API token
- Certbot auto-renewal via systemd timer

See `webserver/` for detailed plan and provisioning scripts.

### 2026.01.11  LGTM install

Installed LGTM stack, documented in `lgtm/`

Renamed machine to `nimbus01`

### 2026.01.10 Initial Linux Installation

It was a real pain getting Linux running on this box.
* Disable secure boot.
* Use USB port on the back of device, not the front
* Use Ubuntu Server 22.04.5 (not 24.04)

For SSH:
- Disable password logins, only Public Keys.


