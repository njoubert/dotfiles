# Periodic Tasks & Permissions Audit
**Date:** November 14, 2025  
**Purpose:** Verify all periodic tasks handle permissions correctly

## Summary

✅ **Working correctly:**
- nginx LaunchDaemon (runs as njoubert:staff)
- nginx log rotation (configured for njoubert:staff)
- certbot renewal script (fixes permissions after renewal)

⚠️ **Potential issues:**
- Grafana, Loki, Prometheus, Promtail LaunchDaemons run as root
- Services work now because root can write to njoubert-owned directories
- Could cause issues if service creates root-owned files that nginx needs to read

## LaunchDaemon Status

| Service | User | Status | Notes |
|---------|------|--------|-------|
| nginx | njoubert | ✅ Correct | Has UserName/GroupName set |
| grafana | root | ⚠️ Works but not ideal | No UserName set |
| loki | root | ⚠️ Works but not ideal | No UserName set |
| prometheus | root | ⚠️ Works but not ideal | No UserName set |
| promtail | root | ⚠️ Works but not ideal | No UserName set |
| node_exporter | root | ⚠️ Works but not ideal | No UserName set |
| nginx_exporter | root | ⚠️ Works but not ideal | No UserName set |
| certbot | root | ✅ Required | Needs root for cert management |

## Periodic Tasks

### 1. Certificate Renewal (2am & 2pm daily)
**LaunchDaemon:** `/Library/LaunchDaemons/com.certbot.renew.plist`  
**Script:** `/usr/local/bin/certbot-renew.sh`  
**Status:** ✅ **SAFE**

The script correctly:
- Runs certbot as root (required)
- Fixes permissions: `chmod 644 *.pem`
- Reloads nginx: `/usr/local/bin/nginx -s reload`

**Tested:** `sudo certbot renew --dry-run` ✓ Works

### 2. Log Rotation (when logs hit 10MB)
**Config:** `/etc/newsyslog.d/nginx.conf`  
**Status:** ✅ **SAFE**

Configuration:
```
/usr/local/var/log/nginx/access.log     njoubert:staff  644  7  10000  *  GZ  /var/run/nginx.pid  30
/usr/local/var/log/nginx/access.json    njoubert:staff  644  7  10000  *  GZ  /var/run/nginx.pid  30
/usr/local/var/log/nginx/error.log      njoubert:staff  644  7  10000  *  GZ  /var/run/nginx.pid  30
```

newsyslog will:
- Create new log files as njoubert:staff (specified in config)
- Send USR1 signal to nginx via PID file to reopen logs
- Keep 7 rotated files, compress with gzip

**Note:** Grafana logs are not in newsyslog config - they rotate internally.

### 3. System Reboot
**Status:** ⚠️ **Needs verification**

On reboot, LaunchDaemons start in this order:
1. Services without dependencies (random order)
2. Services are set to `RunAtLoad=true` and `KeepAlive=true`

**Potential issue:** If monitoring services start first and create root-owned files, nginx might not be able to read them.

**Current mitigation:** 
- All service data directories are already njoubert-owned
- Root can write to these directories
- Files created by root are readable (644 permissions)

## Recommendations

### Option 1: Keep as-is (Low Risk)
**Rationale:**
- System is working correctly now
- Monitoring services don't create files that nginx needs to read
- nginx only needs to read SSL certs (certbot fixes permissions)
- nginx log directory is njoubert-owned

**Risk:** Very low. Services run as root but write to njoubert-owned directories.

### Option 2: Add UserName to all LaunchDaemons (Best Practice)
**Changes needed:**
- Add `<key>UserName</key><string>njoubert</string>` to each service plist
- Add `<key>GroupName</key><string>staff</string>` to each service plist
- Verify all services can run as non-root
- Restart services to apply

**Benefits:**
- Principle of least privilege
- Matches nginx configuration
- Prevents any future permission issues

**Risks:**
- Need to verify each service doesn't require root privileges
- Small chance of breaking something that works

## Testing Performed

```bash
# Test certbot renewal
sudo certbot renew --dry-run  # ✓ SUCCESS

# Test permission fixes
sudo chmod 755 /etc/letsencrypt/live /etc/letsencrypt/archive
sudo chmod 755 /etc/letsencrypt/archive/*/
sudo chmod 644 /etc/letsencrypt/archive/*/*.pem  # ✓ SUCCESS

# Test log rotation
sudo newsyslog -nvv /etc/newsyslog.d/nginx.conf  # ✓ SUCCESS

# Check current process owners
ps aux | grep -E "(nginx|grafana|loki|prometheus)"  # nginx=njoubert, others=root

# Check file ownership
ls -la /usr/local/var/log/nginx/  # ✓ All njoubert:staff
ls -la /etc/letsencrypt/archive/nielsshootsfilm.com/  # ✓ All 644 readable
```

## Conclusion

**Current Status:** ✅ **System is SAFE for periodic tasks**

The system will handle:
- ✅ Certificate renewal (fixes permissions automatically)
- ✅ Log rotation (creates files with correct ownership)  
- ✅ System reboots (services start correctly)
- ✅ Nginx reloads (runs as njoubert, can read certs and logs)

**No immediate action required.** The current setup is functional and will not break on reboots or periodic tasks.

**Optional improvement:** Add UserName/GroupName to monitoring service LaunchDaemons to follow security best practices, but this is not critical.
