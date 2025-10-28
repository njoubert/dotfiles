# Caddy Cleanup Plan

## Overview

This document describes how to cleanly remove the Caddy installation and revert to nginx. This must be executed **before** starting the nginx installation.

## Prerequisites

- Identify all currently running Caddy processes
- Backup any custom configuration or data
- Ensure all sites are documented before removal

## Cleanup Steps

### 1. Stop Caddy Service

Stop the Caddy service if running via brew services:
```bash
# Stop Caddy
brew services stop caddy

# Verify it's stopped
brew services list | grep caddy
ps aux | grep caddy
```

If Caddy is running via LaunchDaemon:
```bash
# Stop and unload the LaunchDaemon
sudo launchctl unload /Library/LaunchDaemons/com.caddyserver.caddy.plist

# Remove the plist file
sudo rm /Library/LaunchDaemons/com.caddyserver.caddy.plist
```

### 2. Backup Caddy Configuration

Before removing, backup any configuration you might need for reference:
```bash
# Create backup directory
mkdir -p ~/webserver-backup/caddy-config

# Backup Caddyfile
if [ -f /usr/local/etc/Caddyfile ]; then
  cp /usr/local/etc/Caddyfile ~/webserver-backup/caddy-config/
fi

# Backup environment file if it exists
if [ -f /usr/local/etc/caddy.env ]; then
  cp /usr/local/etc/caddy.env ~/webserver-backup/caddy-config/
fi

# Backup any other Caddy config directory
if [ -d /usr/local/etc/caddy ]; then
  cp -r /usr/local/etc/caddy ~/webserver-backup/caddy-config/
fi

# Backup logs
if [ -d /usr/local/var/log/caddy ]; then
  cp -r /usr/local/var/log/caddy ~/webserver-backup/caddy-logs/
fi
```

### 3. Remove Caddy Installation

Uninstall Caddy via Homebrew:
```bash
# Uninstall Caddy
brew uninstall caddy

# Verify removal
which caddy  # Should return nothing
```

### 4. Clean Up Caddy Files

Remove remaining Caddy configuration and data files:
```bash
# Remove config files
sudo rm -rf /usr/local/etc/Caddyfile
sudo rm -rf /usr/local/etc/caddy.env
sudo rm -rf /usr/local/etc/caddy/

# Remove data directory (includes SSL certificates)
sudo rm -rf /usr/local/var/lib/caddy/

# Optional: Remove logs (only if you don't need them)
# sudo rm -rf /usr/local/var/log/caddy/
```

### 5. Check for Port Conflicts

Ensure ports 80 and 443 are freed up:
```bash
# Check what's listening on ports 80 and 443
sudo lsof -i :80
sudo lsof -i :443

# If anything is still running, identify and stop it
```

### 6. Verify Docker Containers

Ensure Docker containers are still running and unaffected:
```bash
# Check Docker containers
docker ps

# If any containers were using Caddy as reverse proxy,
# note them down as they'll need to be reconfigured for nginx
```

### 7. STEP REMOVED BY USER

### 8. Cleanup Verification Checklist

Run through this checklist to ensure complete cleanup:

- [ ] Caddy service stopped (`brew services list | grep caddy` shows nothing)
- [ ] Caddy binary removed (`which caddy` returns nothing)
- [ ] Caddyfile backed up and removed
- [ ] Environment files backed up and removed
- [ ] Caddy data directory removed
- [ ] Ports 80 and 443 are free
- [ ] Docker containers still running
- [ ] Site inventory documented
- [ ] SSL certificates noted (may need to regenerate with certbot)

### 9. SSL Certificate Notes

If Caddy was managing SSL certificates:
- Caddy stored certificates in `/usr/local/var/lib/caddy/` (now removed)
- You will need to obtain fresh certificates using certbot with nginx
- Make note of all domains that need certificates
- Cloudflare API token will still work for DNS-01 challenge

## Post-Cleanup

After completing this cleanup:
1. Verify the system is clean: `brew services list`, `sudo lsof -i :80`, `sudo lsof -i :443`
2. Review the site inventory at `~/webserver-backup/site-inventory.txt`
3. Proceed with nginx installation and configuration

## Rollback (If Needed)

If you need to rollback to Caddy:
```bash
# Reinstall Caddy
brew install caddy

# Restore configuration
cp ~/webserver-backup/caddy-config/Caddyfile /usr/local/etc/
cp ~/webserver-backup/caddy-config/caddy.env /usr/local/etc/

# Start Caddy
brew services start caddy
```

## Notes

- Keep the backup directory `~/webserver-backup/` until nginx is fully operational
- No SSL certs have been issues yet, so its fine to start clean
- Docker containers should continue running unaffected during this transition
