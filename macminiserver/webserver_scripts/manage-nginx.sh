#!/bin/bash
# Nginx Management Script

PLIST_PATH="/Library/LaunchDaemons/com.nginx.nginx.plist"
NGINX_CONF="/usr/local/etc/nginx/nginx.conf"
ERROR_LOG="/usr/local/var/log/nginx/error.log"
ACCESS_LOG="/usr/local/var/log/nginx/access.log"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

case "$1" in
  start)
    echo "Starting Nginx..."
    sudo launchctl load -w "$PLIST_PATH"
    sleep 2
    if sudo launchctl list | grep -q com.nginx.nginx; then
      success "Nginx started successfully"
      sudo launchctl list | grep nginx
    else
      error "Failed to start Nginx"
      exit 1
    fi
    ;;
    
  stop)
    echo "Stopping Nginx..."
    sudo launchctl unload -w "$PLIST_PATH"
    sleep 1
    if sudo launchctl list | grep -q com.nginx.nginx; then
      warning "Nginx may still be running"
    else
      success "Nginx stopped successfully"
    fi
    ;;
    
  restart)
    echo "Restarting Nginx..."
    sudo launchctl unload "$PLIST_PATH" 2>/dev/null || true
    sleep 2
    sudo launchctl load "$PLIST_PATH"
    sleep 2
    if sudo launchctl list | grep -q com.nginx.nginx; then
      success "Nginx restarted successfully"
      sudo launchctl list | grep nginx
    else
      error "Failed to restart Nginx"
      exit 1
    fi
    ;;
    
  reload)
    echo "Reloading Nginx configuration..."
    if nginx -t 2>/dev/null; then
      nginx -s reload
      success "Nginx configuration reloaded successfully"
    else
      error "Nginx configuration test failed!"
      nginx -t
      exit 1
    fi
    ;;
    
  status)
    echo "=== Nginx Service Status ==="
    if sudo launchctl list | grep -q com.nginx.nginx; then
      success "Nginx LaunchDaemon is loaded"
      sudo launchctl list | grep nginx
    else
      error "Nginx LaunchDaemon is not loaded"
    fi
    echo ""
    echo "=== Nginx Processes ==="
    if ps aux | grep -v grep | grep nginx >/dev/null; then
      ps aux | grep -v grep | grep nginx
      success "Nginx processes are running"
    else
      warning "No Nginx process found"
    fi
    echo ""
    echo "=== Configuration Test ==="
    nginx -t
    echo ""
    echo "=== Recent Error Log (last 10 lines) ==="
    if [ -f "$ERROR_LOG" ]; then
      tail -10 "$ERROR_LOG"
    else
      info "No error log found"
    fi
    ;;
    
  logs)
    if [ "$2" = "error" ]; then
      echo "Tailing Nginx error log (Ctrl+C to exit)..."
      tail -f "$ERROR_LOG"
    elif [ "$2" = "access" ]; then
      echo "Tailing Nginx access log (Ctrl+C to exit)..."
      tail -f "$ACCESS_LOG"
    else
      echo "Usage: $0 logs {error|access}"
      echo ""
      info "Available logs:"
      echo "  error  - Error log"
      echo "  access - Access log"
      exit 1
    fi
    ;;
    
  test)
    echo "Testing Nginx configuration..."
    if nginx -t; then
      success "Configuration is valid"
    else
      error "Configuration has errors"
      exit 1
    fi
    ;;
    
  sites)
    echo "=== Configured Sites ==="
    if [ -d "/usr/local/etc/nginx/servers" ]; then
      for conf in /usr/local/etc/nginx/servers/*.conf; do
        if [ -f "$conf" ]; then
          echo ""
          info "$(basename $conf)"
          grep -E "server_name|listen|root" "$conf" | sed 's/^/  /'
        fi
      done
    else
      warning "No sites directory found"
    fi
    ;;
    
  *)
    echo "Nginx Management Script"
    echo ""
    echo "Usage: $0 {start|stop|restart|reload|status|logs|test|sites}"
    echo ""
    echo "  start    - Start Nginx service"
    echo "  stop     - Stop Nginx service"
    echo "  restart  - Restart Nginx service"
    echo "  reload   - Reload config (zero downtime)"
    echo "  status   - Show service status and recent errors"
    echo "  logs     - Tail logs (error|access)"
    echo "  test     - Test configuration syntax"
    echo "  sites    - List all configured sites"
    exit 1
    ;;
esac
