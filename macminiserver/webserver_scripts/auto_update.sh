#!/bin/bash
#
# Automatic Package Update Script
# Updates Homebrew packages and pip3 packages
#

LOG_FILE="/usr/local/var/log/auto-update.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Starting automatic update check ==="

# Update Homebrew itself
log "Updating Homebrew..."
brew update 2>&1 | tee -a "$LOG_FILE"

# Upgrade all Homebrew packages
log "Upgrading Homebrew packages..."
brew upgrade 2>&1 | tee -a "$LOG_FILE"

# Upgrade pip3 packages
log "Upgrading pip3 packages..."
pip3 install --break-system-packages --upgrade certbot-dns-cloudflare 2>&1 | tee -a "$LOG_FILE"

# Cleanup
log "Cleaning up old versions..."
brew cleanup 2>&1 | tee -a "$LOG_FILE"

# Check if nginx needs restart
if pgrep -x "nginx" > /dev/null; then
    log "Nginx is running. Reloading configuration..."
    /usr/local/bin/nginx -s reload
    log "Nginx reloaded"
fi

log "=== Update check complete ==="
log ""
