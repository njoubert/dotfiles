# Agent Rules for macminiserver

This directory contains provisioning scripts and configuration for the Mac Mini Server.

## General Principles

- **All services MUST run as the local user (`njoubert:staff`)**, not as root
- **All LaunchDaemons MUST include `UserName` and `GroupName` directives**
- **All file permissions MUST be compatible with non-root execution**

## Service Architecture

The server runs several categories of services:

### Web Services
- **nginx**: Reverse proxy and web server
- Runs as: `njoubert:staff` (via LaunchDaemon)
- Requires: Read access to SSL certificates, write access to logs

### LGTM Stack (Monitoring)
- **Grafana**: Visualization and dashboards
- **Loki**: Log aggregation
- **Prometheus**: Metrics database
- **Promtail**: Log shipper
- **node_exporter**: Host metrics
- **nginx_exporter**: NGINX metrics
- All run as: `njoubert:staff` (via LaunchDaemons)
- Requires: Read/write access to data directories and logs

### Certificate Management
- **certbot**: SSL certificate renewal
- Runs as: `root` (REQUIRED - needs to write to `/etc/letsencrypt`)
- Post-renewal script: Fixes permissions to be readable by `njoubert`

## LaunchDaemon Template

All service LaunchDaemons MUST include these directives:

```xml
<key>UserName</key>
<string>njoubert</string>

<key>GroupName</key>
<string>staff</string>
```

Exception: Only certbot runs as root (no UserName directive) because it requires root privileges to manage certificates in `/etc/letsencrypt/`.

## Directory Ownership

All service data directories MUST be owned by `njoubert:staff`:

```bash
sudo chown -R njoubert:staff /usr/local/var/lib/grafana
sudo chown -R njoubert:staff /usr/local/var/log/grafana
sudo chown -R njoubert:staff /usr/local/var/log/monitoring
sudo chown -R njoubert:staff /usr/local/var/log/nginx
sudo chown -R njoubert:staff /usr/local/var/loki
sudo chown -R njoubert:staff /usr/local/var/prometheus
sudo chown -R njoubert:staff /usr/local/var/promtail-positions.yaml
```

## SSL Certificate Permissions

Certificates in `/etc/letsencrypt/` are managed by root, but MUST be readable by nginx:

```bash
sudo chmod 755 /etc/letsencrypt/live /etc/letsencrypt/archive
sudo chmod 755 /etc/letsencrypt/archive/*/
sudo chmod 644 /etc/letsencrypt/archive/*/*.pem
```

The certbot renewal script automatically fixes these permissions after each renewal.

## Log Rotation

All log rotation configurations MUST specify the correct user:

```
# newsyslog.conf format
/usr/local/var/log/nginx/access.log     njoubert:staff  644  7  10000  *  GZ  /var/run/nginx.pid  30
```

When log files are rotated, newsyslog creates new files with the specified ownership.

## Provisioning Scripts

When adding new services to provisioning scripts:

1. **Always add UserName and GroupName to LaunchDaemon plists**
2. **Always set directory ownership to `njoubert:staff`**
3. **Always verify the service can run without root privileges**
4. **Test that log files are writable by the service user**

## Security Rationale

Running services as non-root follows the **principle of least privilege**:

- Limits damage from compromised services
- Prevents accidental system-wide changes
- Makes file permissions explicit and auditable
- Standard practice for production servers

## Exceptions

The ONLY service that runs as root is:
- **certbot** - Requires root to write certificates to `/etc/letsencrypt/`

All other services run as `njoubert:staff`.

## Verification Commands

To verify services are running as the correct user:

```bash
# Check LaunchDaemon configurations
for plist in /Library/LaunchDaemons/com.{nginx,grafana,prometheus}*.plist; do
  echo "=== $(basename $plist) ==="
  sudo plutil -extract UserName raw "$plist" 2>/dev/null || echo "  No UserName set (runs as root)"
done

# Check running processes
ps aux | grep -E "(nginx|grafana|loki|prometheus|promtail|node_exporter)" | grep -v grep

# All should show 'njoubert' in the USER column, except certbot which runs as root
```

## When Things Go Wrong

If a service fails to start after adding UserName/GroupName:

1. **Check log file ownership**: Service may not be able to write to log files
   ```bash
   ls -la /usr/local/var/log/monitoring/
   ls -la /usr/local/var/log/grafana/
   ls -la /usr/local/var/log/nginx/
   ```

2. **Check data directory ownership**: Service may not be able to write data
   ```bash
   ls -ld /usr/local/var/{prometheus,loki,lib/grafana}
   ```

3. **Check certificate permissions**: nginx may not be able to read SSL certs
   ```bash
   ls -la /etc/letsencrypt/archive/*/
   ```

4. **Fix ownership**: 
   ```bash
   sudo chown -R njoubert:staff /usr/local/var/log/{monitoring,grafana,nginx}
   sudo chown -R njoubert:staff /usr/local/var/{prometheus,loki,lib/grafana}
   sudo chmod 644 /etc/letsencrypt/archive/*/*.pem
   ```

5. **Restart the service**:
   ```bash
   sudo launchctl kickstart -k system/com.grafana.grafana
   ```

## Remember

When you see a service failing with "Permission denied" errors, it's almost always because:
- The service is trying to run as `njoubert` (good!)
- But the files it needs are owned by `root` (bad!)
- Solution: Fix the ownership, not the UserName directive!

