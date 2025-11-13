#!/bin/bash
# Nginx Management Script

PLIST_PATH="/Library/LaunchDaemons/com.nginx.nginx.plist"
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
    if pgrep -f nginx >/dev/null; then
      pgrep -fl nginx
      success "Nginx processes are running"
    else
      warning "No Nginx process found"
    fi
    echo ""
    echo "=== Configuration Test ==="
    nginx -t
    echo ""
    echo "=== HTTP Health Checks ==="
    # Get local LAN IP
    LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "127.0.0.1")
    
    # Check all configured sites
    if [ -d "/usr/local/etc/nginx/servers" ]; then
      for conf in /usr/local/etc/nginx/servers/*.conf; do
        if [ -f "$conf" ]; then
          # Extract server_name from HTTPS server blocks (skip comments)
          server_names=$(grep -A 20 "listen 443" "$conf" | grep "server_name" | grep -v "^[[:space:]]*#" | head -1 | sed 's/.*server_name //; s/;//' | tr ' ' '\n' | grep -v "^$")
          
          for domain in $server_names; do
            # Skip wildcard patterns, regex patterns, www variants, and comments
            if [[ "$domain" != *"*"* ]] && [[ "$domain" != "~"* ]] && [[ "$domain" != "www."* ]] && [[ "$domain" != "#"* ]]; then
              
              # Test 1: Local LAN (bypasses Cloudflare)
              echo -n "  Local  https://$domain ($LOCAL_IP) ... "
              http_code=$(curl -k -s -o /dev/null -w "%{http_code}" --max-time 5 \
                --resolve "$domain:443:$LOCAL_IP" \
                "https://$domain" 2>/dev/null)
              
              if [ "$http_code" = "200" ]; then
                success "OK ($http_code)"
              elif [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
                info "Redirect ($http_code)"
              elif [ -z "$http_code" ]; then
                error "Failed"
              else
                warning "HTTP $http_code"
              fi
              
              # Test 2: Public endpoint (through Cloudflare)
              echo -n "  Public https://$domain (cloudflare) ... "
              http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "https://$domain" 2>/dev/null)
              
              if [ "$http_code" = "200" ]; then
                success "OK ($http_code)"
              elif [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
                info "Redirect ($http_code)"
              elif [ -z "$http_code" ]; then
                error "Failed"
              else
                warning "HTTP $http_code"
              fi
              
            fi
          done
        fi
      done
    fi
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
          info "$(basename "$conf")"
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
