# MINISFORUM MS-A1 2026.01 (nimbus01)

```
MINISFORUM MS-A2
AMD Ryzen™ 9 9955HX
96GB RAM
2TB SSD
```

# Important: IPv6 Disabled

⚠️ **IPv6 is disabled on this server** via GRUB kernel parameters.

Applications and services (nginx, etc.) must **not** attempt to bind to IPv6 addresses (`[::]` or `::1`). This will cause them to fail to start.

**For nginx configs:** Do not use `listen [::]:80` or `listen [::]:443` directives.

# Log

## 2026.01.23 Upgrade to Ubuntu 24.04 LTS

Many of our packages are old on 22.04 and it sucks. Upgraded.

After upgrade we did have issues with the network. Fixed that as follows:
* disabled ipv6 in GRUB config
* disabld cloud-init network management
* deleted cloud-init completely

We are also having issues with loki and promtail

### Disabling Cloud-Init Network Management on Ubuntu 24.04

After upgrading from Ubuntu 22.04 to 24.04, cloud-init was managing network configuration and overwriting custom netplan settings, causing network interfaces to not come up properly.

### 1. Disable cloud-init entirely

Created a file to disable cloud-init:

```bash
sudo touch /etc/cloud/cloud-init.disabled
```

### 2. Remove cloud-init's netplan config

```bash
sudo rm /etc/netplan/50-cloud-init.yaml
```

### 3. Create custom netplan configuration

Created `/etc/netplan/01-netcfg.yaml` with the desired network configuration.

### 4. Apply the new configuration

```bash
sudo netplan apply
```

### 5. Fix installer config permissions (optional cleanup)

Removed leftover installer files with incorrect permissions:

```bash
sudo rm /etc/cloud/cloud.cfg.d/99-installer.cfg
sudo rm /etc/cloud/cloud.cfg.d/90-installer-network.cfg
```

### 6. Reboot and verify

```bash
sudo reboot
```

After reboot, verified with:

```bash
ip a                          # Check interfaces are up
ls -la /etc/netplan/          # Confirm no cloud-init yaml regenerated
cloud-init status             # Check for errors
```

### Notes

- If you only want to disable cloud-init's network management (while keeping other cloud-init features), create `/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg` with the content `network: {config: disabled}` instead of fully disabling cloud-init.
- Date: January 2026


## 2026.01.22 nginx install, reverse proxy nielsshootsfilm.com and nimbus.wtf

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

## 2026.01.11  LGTM install

Installed LGTM stack, documented in `lgtm/`

Renamed machine to `nimbus01`

## 2026.01.10 Initial Linux Installation

It was a real pain getting Linux running on this box.
* Disable secure boot.
* Use USB port on the back of device, not the front
* Use Ubuntu Server 22.04.5 (not 24.04)

For SSH:
- Disable password logins, only Public Keys.


