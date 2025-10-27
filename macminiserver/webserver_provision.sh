#!/bin/bash
#
# Mac Mini Webserver Provisioning Script v1.0.0
# 
# This script sets up a Caddy-based webserver with Docker containers.
# It's designed to be idempotent - safe to run multiple times.
#
# Usage: bash webserver_provision.sh
#

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    error "This script is designed for macOS only."
    exit 1
fi

# Check if running as regular user (not root)
if [[ $EUID -eq 0 ]]; then
    error "This script should not be run as root. Run as a regular user with sudo access."
    exit 1
fi

log "========================================="
log "Mac Mini Webserver Provisioning v1.0.0"
log "========================================="
echo ""

#==============================================================================
# Phase 1.1: Install Caddy
#==============================================================================

phase_1_1_install_caddy() {
    log "Phase 1.1: Install Caddy"
    echo ""
    
    # Verify Docker Desktop is installed
    log "Checking Docker Desktop installation..."
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed."
        error "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop/"
        exit 1
    fi
    
    # Verify it's Docker Desktop (not homebrew docker)
    if docker context ls 2>&1 | grep -q "desktop-linux"; then
        success "Docker Desktop is installed"
    else
        error "Docker is installed but doesn't appear to be Docker Desktop."
        error "Please uninstall homebrew docker and install Docker Desktop."
        exit 1
    fi
    
    # Install Caddy if not already installed
    log "Checking Caddy installation..."
    if command -v caddy &> /dev/null; then
        CADDY_VERSION=$(caddy version)
        success "Caddy is already installed: $CADDY_VERSION"
    else
        log "Installing Caddy via Homebrew..."
        brew install caddy
        success "Caddy installed successfully"
    fi
    
    # Verify installation
    log "Verifying Caddy installation..."
    CADDY_VERSION=$(caddy version)
    success "Caddy version: $CADDY_VERSION"
    
    # Create necessary directories
    log "Creating directory structure..."
    
    if [[ ! -d /usr/local/var/www/hello ]]; then
        sudo mkdir -p /usr/local/var/www/hello
        success "Created /usr/local/var/www/hello"
    else
        success "Directory /usr/local/var/www/hello already exists"
    fi
    
    if [[ ! -d /usr/local/var/log/caddy ]]; then
        sudo mkdir -p /usr/local/var/log/caddy
        success "Created /usr/local/var/log/caddy"
    else
        success "Directory /usr/local/var/log/caddy already exists"
    fi
    
    if [[ ! -d /usr/local/etc ]]; then
        sudo mkdir -p /usr/local/etc
        success "Created /usr/local/etc"
    else
        success "Directory /usr/local/etc already exists"
    fi
    
    # Set ownership
    log "Setting directory ownership..."
    sudo chown -R $(whoami):staff /usr/local/var/www
    sudo chown -R $(whoami):staff /usr/local/var/log/caddy
    success "Directory ownership set to $(whoami):staff"
    
    echo ""
    success "Phase 1.1 complete!"
    echo ""
}

#==============================================================================
# Phase 1.2: Create Hello World Page
#==============================================================================

phase_1_2_hello_world() {
    log "Phase 1.2: Create Hello World Page"
    echo ""
    
    # Create hello world HTML page
    log "Creating hello world HTML page..."
    
    HELLO_PAGE="/usr/local/var/www/hello/index.html"
    
    if [[ -f "$HELLO_PAGE" ]]; then
        warning "Hello world page already exists at $HELLO_PAGE"
        log "Backing up existing file..."
        cp "$HELLO_PAGE" "$HELLO_PAGE.backup.$(date +%Y%m%d_%H%M%S)"
        success "Backup created"
    fi
    
    cat > "$HELLO_PAGE" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Hello from Mac Mini</title>
    <style>
        body { 
            font-family: system-ui; 
            max-width: 800px; 
            margin: 100px auto; 
            padding: 20px;
            text-align: center;
        }
        h1 { color: #2563eb; }
    </style>
</head>
<body>
    <h1>🎉 Hello from Mac Mini Webserver!</h1>
    <p>Caddy is running successfully.</p>
    <p><small>Served at: <code id="time"></code></small></p>
    <script>
        document.getElementById('time').textContent = new Date().toISOString();
    </script>
</body>
</html>
EOF
    
    success "Created hello world page at $HELLO_PAGE"
    
    # Verify file was created
    if [[ -f "$HELLO_PAGE" ]]; then
        FILE_SIZE=$(stat -f%z "$HELLO_PAGE")
        success "File created successfully ($FILE_SIZE bytes)"
    else
        error "Failed to create hello world page"
        exit 1
    fi
    
    echo ""
    success "Phase 1.2 complete!"
    echo ""
}

#==============================================================================
# Phase 1.3: Create Basic Caddyfile
#==============================================================================

phase_1_3_create_caddyfile() {
    log "Phase 1.3: Create Basic Caddyfile"
    echo ""
    
    CADDYFILE="/usr/local/etc/Caddyfile"
    
    # Backup existing Caddyfile if present
    if [[ -f "$CADDYFILE" ]]; then
        warning "Caddyfile already exists at $CADDYFILE"
        log "Backing up existing file..."
        sudo cp "$CADDYFILE" "$CADDYFILE.backup.$(date +%Y%m%d_%H%M%S)"
        success "Backup created"
    fi
    
    # Create basic Caddyfile (HTTP only for testing)
    log "Creating basic Caddyfile..."
    
    sudo tee "$CADDYFILE" > /dev/null << 'EOF'
{
    # Global options
    admin off
}

# Catch-all for testing - responds to any domain/IP
# Bind only to IPv4
:80 {
    bind 0.0.0.0
    
    root * /usr/local/var/www/hello
    file_server
    
    log {
        output file /usr/local/var/log/caddy/access.log
    }
}
EOF
    
    success "Created Caddyfile at $CADDYFILE"
    
    # Validate Caddyfile syntax
    log "Validating Caddyfile syntax..."
    if caddy validate --config "$CADDYFILE" > /dev/null 2>&1; then
        success "Caddyfile syntax is valid"
    else
        error "Caddyfile syntax validation failed"
        log "Running validation with output:"
        caddy validate --config "$CADDYFILE"
        exit 1
    fi
    
    echo ""
    success "Phase 1.3 complete!"
    echo ""
}

#==============================================================================
# Phase 1.4: Create Management Script
#==============================================================================

phase_1_4_management_script() {
    log "Phase 1.4: Create Management Script"
    echo ""
    
    # Create scripts directory
    log "Creating scripts directory..."
    SCRIPTS_DIR="$HOME/webserver/scripts"
    
    if [[ ! -d "$SCRIPTS_DIR" ]]; then
        mkdir -p "$SCRIPTS_DIR"
        success "Created $SCRIPTS_DIR"
    else
        success "Directory $SCRIPTS_DIR already exists"
    fi
    
    # Create management script
    MANAGE_SCRIPT="$SCRIPTS_DIR/manage-caddy.sh"
    
    if [[ -f "$MANAGE_SCRIPT" ]]; then
        warning "Management script already exists at $MANAGE_SCRIPT"
        log "Backing up existing script..."
        cp "$MANAGE_SCRIPT" "$MANAGE_SCRIPT.backup.$(date +%Y%m%d_%H%M%S)"
        success "Backup created"
    fi
    
    log "Creating Caddy management script..."
    
    cat > "$MANAGE_SCRIPT" << 'EOF'
#!/bin/bash
# Caddy Webserver Management Script

CADDYFILE="/usr/local/etc/Caddyfile"
LOG_DIR="/usr/local/var/log/caddy"
ERROR_LOG="$LOG_DIR/caddy-error.log"
ACCESS_LOG="$LOG_DIR/access.log"
PLIST_PATH="/Library/LaunchDaemons/com.caddyserver.caddy.plist"

case "$1" in
  start)
    echo "Starting Caddy..."
    sudo launchctl load -w "$PLIST_PATH"
    sleep 2
    sudo launchctl list | grep caddy
    ;;
    
  stop)
    echo "Stopping Caddy..."
    sudo launchctl unload -w "$PLIST_PATH"
    ;;
    
  restart)
    echo "Restarting Caddy..."
    sudo launchctl unload "$PLIST_PATH"
    sleep 2
    sudo launchctl load "$PLIST_PATH"
    sleep 2
    sudo launchctl list | grep caddy
    ;;
    
  reload)
    echo "Reloading Caddy configuration (zero downtime)..."
    caddy reload --config $CADDYFILE
    ;;
    
  status)
    echo "=== Caddy Service Status ==="
    if sudo launchctl list | grep -q caddy; then
      echo "✅ Caddy LaunchDaemon is loaded"
      sudo launchctl list | grep caddy
    else
      echo "❌ Caddy LaunchDaemon is not loaded"
    fi
    echo ""
    echo "=== Caddy Process ==="
    ps aux | grep -v grep | grep caddy || echo "No Caddy process found"
    echo ""
    echo "=== Recent Error Log ==="
    if [ -f "$ERROR_LOG" ]; then
      tail -5 "$ERROR_LOG"
    else
      echo "No error log found"
    fi
    ;;
    
  logs)
    if [ "$2" = "error" ]; then
      echo "Tailing Caddy error log (Ctrl+C to exit)..."
      tail -f "$ERROR_LOG"
    elif [ "$2" = "access" ]; then
      echo "Tailing Caddy access log (Ctrl+C to exit)..."
      tail -f "$ACCESS_LOG"
    else
      echo "Usage: $0 logs {error|access}"
      exit 1
    fi
    ;;
    
  validate)
    echo "Validating Caddyfile..."
    caddy validate --config $CADDYFILE
    ;;
    
  *)
    echo "Caddy Webserver Management"
    echo ""
    echo "Usage: $0 {start|stop|restart|reload|status|logs|validate}"
    echo ""
    echo "  start    - Start Caddy service"
    echo "  stop     - Stop Caddy service"
    echo "  restart  - Restart Caddy service (brief downtime)"
    echo "  reload   - Reload config (zero downtime)"
    echo "  status   - Show service status and recent errors"
    echo "  logs     - Tail logs (error|access)"
    echo "  validate - Validate Caddyfile syntax"
    exit 1
    ;;
esac
EOF
    
    success "Created management script at $MANAGE_SCRIPT"
    
    # Make script executable
    log "Making script executable..."
    chmod +x "$MANAGE_SCRIPT"
    success "Script is now executable"
    
    # Add alias to .zshrc if not already present
    log "Adding alias to .zshrc..."
    ALIAS_LINE='alias caddy-manage="$HOME/webserver/scripts/manage-caddy.sh"'
    
    if grep -q "caddy-manage" "$HOME/.zshrc" 2>/dev/null; then
        success "Alias already exists in .zshrc"
    else
        echo "" >> "$HOME/.zshrc"
        echo "# Caddy management alias" >> "$HOME/.zshrc"
        echo "$ALIAS_LINE" >> "$HOME/.zshrc"
        success "Added alias to .zshrc"
        log "Run 'source ~/.zshrc' to load the alias in current shell"
    fi
    
    echo ""
    success "Phase 1.4 complete!"
    log "Management script available at: $MANAGE_SCRIPT"
    log "Use 'caddy-manage' command after sourcing .zshrc"
    echo ""
}

#==============================================================================
# Phase 1.5: Test Basic Caddy
#==============================================================================

phase_1_5_test_caddy() {
    log "Phase 1.5: Test Basic Caddy"
    echo ""
    
    CADDYFILE="/usr/local/etc/Caddyfile"
    
    # Stop any existing Caddy processes
    log "Checking for existing Caddy processes..."
    if pgrep -x caddy > /dev/null; then
        warning "Caddy is already running. Stopping it first..."
        pkill caddy
        sleep 2
        success "Stopped existing Caddy process"
    else
        success "No existing Caddy processes found"
    fi
    
    # Start Caddy in background for testing
    log "Starting Caddy manually for testing..."
    caddy run --config "$CADDYFILE" > /tmp/caddy-test.log 2>&1 &
    CADDY_PID=$!
    
    log "Caddy started with PID: $CADDY_PID"
    log "Waiting for Caddy to start..."
    sleep 3
    
    # Check if Caddy is running
    if ps -p $CADDY_PID > /dev/null; then
        success "Caddy process is running"
    else
        error "Caddy process failed to start"
        log "Check logs at /tmp/caddy-test.log"
        cat /tmp/caddy-test.log
        exit 1
    fi
    
    # Test localhost
    log "Testing hello world page on localhost..."
    if curl -s http://localhost > /dev/null; then
        success "✅ Localhost test passed"
        log "Response preview:"
        curl -s http://localhost | head -3
    else
        error "Failed to access http://localhost"
        log "Check Caddy logs:"
        tail -20 /tmp/caddy-test.log
        pkill caddy
        exit 1
    fi
    
    # Get local IP address
    log "Detecting local IP address..."
    LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "unknown")
    
    if [[ "$LOCAL_IP" != "unknown" ]]; then
        success "Local IP: $LOCAL_IP"
        log "Testing access via local IP..."
        if curl -s "http://$LOCAL_IP" > /dev/null; then
            success "✅ Local IP test passed"
        else
            warning "Could not access via local IP (may need firewall configuration)"
        fi
    else
        warning "Could not detect local IP address"
    fi
    
    # Check access log
    log "Checking if access log is being written..."
    if [[ -f /usr/local/var/log/caddy/access.log ]]; then
        success "Access log exists"
        log "Recent access log entries:"
        tail -5 /usr/local/var/log/caddy/access.log || echo "No entries yet"
    else
        warning "Access log not yet created (will be created on first request)"
    fi
    
    # Test management script validate command
    log "Testing management script validate command..."
    if ~/webserver/scripts/manage-caddy.sh validate > /dev/null 2>&1; then
        success "✅ Management script validate works"
    else
        warning "Management script validate returned an error (expected until LaunchDaemon is set up)"
    fi
    
    # Stop test Caddy process
    log "Stopping test Caddy process..."
    kill $CADDY_PID
    sleep 2
    
    if ps -p $CADDY_PID > /dev/null 2>&1; then
        warning "Caddy didn't stop gracefully, forcing..."
        kill -9 $CADDY_PID
    fi
    
    success "Test Caddy stopped"
    
    echo ""
    success "Phase 1.5 complete!"
    log "Caddy is working correctly!"
    log "Next: Set up LaunchDaemon for automatic startup"
    echo ""
}

#==============================================================================
# Phase 1.6: Setup LaunchDaemon for Auto-Start
#==============================================================================

phase_1_6_launchdaemon() {
    log "Phase 1.6: Setup LaunchDaemon for Auto-Start"
    echo ""
    
    PLIST_PATH="/Library/LaunchDaemons/com.caddyserver.caddy.plist"
    
    # Stop any running Caddy processes
    log "Stopping any running Caddy processes..."
    if pgrep -x caddy > /dev/null; then
        pkill caddy
        sleep 2
        success "Stopped Caddy"
    else
        success "No Caddy process to stop"
    fi
    
    # Find Caddy binary location
    log "Finding Caddy binary location..."
    CADDY_PATH=$(which caddy)
    success "Caddy binary: $CADDY_PATH"
    
    # Get username and home directory
    USERNAME=$(whoami)
    USER_HOME="$HOME"
    
    log "Will run Caddy as user: $USERNAME"
    log "Home directory: $USER_HOME"
    
    # Backup existing plist if present
    if [[ -f "$PLIST_PATH" ]]; then
        warning "LaunchDaemon plist already exists"
        log "Backing up existing plist..."
        sudo cp "$PLIST_PATH" "$PLIST_PATH.backup.$(date +%Y%m%d_%H%M%S)"
        success "Backup created"
        
        # Unload existing LaunchDaemon
        log "Unloading existing LaunchDaemon..."
        sudo launchctl unload "$PLIST_PATH" 2>/dev/null || true
        success "Unloaded existing LaunchDaemon"
    fi
    
    # Create LaunchDaemon plist
    log "Creating LaunchDaemon plist..."
    
    sudo tee "$PLIST_PATH" > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.caddyserver.caddy</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>$CADDY_PATH</string>
        <string>run</string>
        <string>--config</string>
        <string>/usr/local/etc/Caddyfile</string>
        <string>--adapter</string>
        <string>caddyfile</string>
    </array>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    
    <key>StandardOutPath</key>
    <string>/usr/local/var/log/caddy/caddy-stdout.log</string>
    
    <key>StandardErrorPath</key>
    <string>/usr/local/var/log/caddy/caddy-error.log</string>
    
    <key>WorkingDirectory</key>
    <string>/usr/local/var/www</string>
    
    <key>UserName</key>
    <string>$USERNAME</string>
    
    <key>GroupName</key>
    <string>staff</string>
    
    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key>
        <string>$USER_HOME</string>
    </dict>
</dict>
</plist>
EOF
    
    success "Created LaunchDaemon plist at $PLIST_PATH"
    
    # Set correct permissions
    log "Setting permissions on plist..."
    sudo chown root:wheel "$PLIST_PATH"
    sudo chmod 644 "$PLIST_PATH"
    success "Permissions set (root:wheel, 644)"
    
    # Load the LaunchDaemon
    log "Loading LaunchDaemon..."
    sudo launchctl load -w "$PLIST_PATH"
    sleep 3
    success "LaunchDaemon loaded"
    
    # Verify LaunchDaemon is loaded
    log "Verifying LaunchDaemon status..."
    if sudo launchctl list | grep -q "com.caddyserver.caddy"; then
        success "✅ LaunchDaemon is loaded"
        sudo launchctl list | grep caddy
    else
        error "LaunchDaemon failed to load"
        log "Checking error log:"
        tail -20 /usr/local/var/log/caddy/caddy-error.log 2>/dev/null || echo "No error log found"
        exit 1
    fi
    
    # Verify Caddy process is running
    log "Verifying Caddy process..."
    sleep 2
    if ps aux | grep -v grep | grep -q caddy; then
        success "✅ Caddy process is running"
        ps aux | grep -v grep | grep caddy | head -1
    else
        error "Caddy process is not running"
        log "Checking error log:"
        tail -20 /usr/local/var/log/caddy/caddy-error.log 2>/dev/null || echo "No error log found"
        exit 1
    fi
    
    # Test with management script
    log "Testing management script..."
    if ~/webserver/scripts/manage-caddy.sh status > /dev/null 2>&1; then
        success "✅ Management script works"
    else
        warning "Management script returned warnings (may be normal)"
    fi
    
    # Test localhost access
    log "Testing localhost access..."
    sleep 2
    if curl -s http://localhost > /dev/null; then
        success "✅ Localhost test passed"
    else
        error "Failed to access http://localhost"
        exit 1
    fi
    
    echo ""
    success "Phase 1.6 complete!"
    log "Caddy is now set to start automatically at boot!"
    log "Use '~/webserver/scripts/manage-caddy.sh' to manage the service"
    echo ""
}

#==============================================================================
# Phase 1.6.5: Configure macOS Firewall
#==============================================================================

phase_1_6_5_configure_firewall() {
    log "Phase 1.6.5: Configure macOS Firewall"
    echo ""
    
    CADDY_PATH=$(which caddy)
    
    # Check firewall status
    log "Checking firewall status..."
    FIREWALL_STATUS=$(sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate)
    log "Firewall status: $FIREWALL_STATUS"
    
    # Add Caddy to firewall exceptions
    log "Adding Caddy to firewall exceptions..."
    
    if sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add "$CADDY_PATH" 2>&1 | grep -q "already exists"; then
        success "Caddy already in firewall list"
    else
        sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add "$CADDY_PATH"
        success "Added Caddy to firewall"
    fi
    
    # Unblock Caddy (allow incoming connections)
    log "Allowing incoming connections for Caddy..."
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp "$CADDY_PATH"
    success "Caddy is allowed to accept incoming connections"
    
    # Verify Caddy is in the list
    log "Verifying Caddy firewall configuration..."
    if sudo /usr/libexec/ApplicationFirewall/socketfilterfw --listapps | grep -q caddy; then
        success "✅ Caddy is in firewall allowed list"
    else
        warning "Could not verify Caddy in firewall list"
    fi
    
    # Get local IP for testing
    log "Detecting local IP address for testing..."
    LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "unknown")
    
    if [[ "$LOCAL_IP" != "unknown" ]]; then
        success "Local IP: $LOCAL_IP"
        
        log "Testing external access via local IP..."
        log "Waiting a moment for firewall to apply changes..."
        sleep 2
        
        if curl -s --connect-timeout 5 "http://$LOCAL_IP" > /dev/null 2>&1; then
            success "✅ External access test passed!"
            log "Server is accessible at http://$LOCAL_IP"
        else
            warning "External access test failed"
            log "This might be normal if:"
            log "  - You're on a network with client isolation enabled"
            log "  - Additional firewall/router rules are blocking access"
            log "  - Try testing from a different device on the same network"
        fi
    else
        warning "Could not detect local IP address"
        log "You can test external access manually using the Mac Mini's IP address"
    fi
    
    echo ""
    success "Phase 1.6.5 complete!"
    log "Firewall is configured to allow Caddy traffic"
    log "Test from another machine: curl http://$LOCAL_IP"
    echo ""
}

#==============================================================================
# Main execution
#==============================================================================

main() {
    phase_1_1_install_caddy
    phase_1_2_hello_world
    phase_1_3_create_caddyfile
    phase_1_4_management_script
    phase_1_5_test_caddy
    phase_1_6_launchdaemon
    phase_1_6_5_configure_firewall
    phase_1_6_launchdaemon
    
    log "========================================="
    log "Provisioning complete!"
    log "========================================="
    echo ""
    log "✅ Phase 1.1-1.6 Complete!"
    log ""
    log "Caddy webserver is now:"
    log "  - Installed and configured"
    log "  - Serving hello world page"
    log "  - Set to start automatically at boot"
    log "  - Manageable via ~/webserver/scripts/manage-caddy.sh"
    echo ""
    log "Next steps:"
    log "  - Test reboot: sudo reboot (then verify Caddy starts)"
    log "  - Continue with Phase 1.7 (Auto-login configuration)"
    log "  - Or skip to Phase 2 to add your first real site"
    echo ""
}

# Run main function
main
