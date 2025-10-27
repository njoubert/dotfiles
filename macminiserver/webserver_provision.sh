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

# Helper function to install a file only if it differs from expected content
# Shows a diff and prompts user for action if file differs
# Usage: install_file_if_changed "destination_path" "expected_content" [use_sudo]
# Returns: 0 if file was updated or already correct, 1 on error or user chose to keep current
install_file_if_changed() {
    local dest_path="$1"
    local expected_content="$2"
    local use_sudo="${3:-false}"
    local temp_file=$(mktemp)
    
    # Write expected content to temp file
    echo "$expected_content" > "$temp_file"
    
    # Check if destination exists and compare
    if [[ -f "$dest_path" ]]; then
        local files_match=false
        
        if [[ "$use_sudo" == "true" ]]; then
            sudo cmp -s "$temp_file" "$dest_path" && files_match=true
        else
            cmp -s "$temp_file" "$dest_path" && files_match=true
        fi
        
        if [[ "$files_match" == "true" ]]; then
            success "$(basename "$dest_path") already exists and is correct"
            rm "$temp_file"
            return 0
        else
            warning "$(basename "$dest_path") exists but differs from expected content"
            echo ""
            log "Showing differences (- current file, + new content):"
            echo ""
            
            # Show diff
            if [[ "$use_sudo" == "true" ]]; then
                sudo diff -u "$dest_path" "$temp_file" || true
            else
                diff -u "$dest_path" "$temp_file" || true
            fi
            
            echo ""
            log "What would you like to do?"
            echo "  [o] Overwrite with new content (current file will be backed up)"
            echo "  [k] Keep current file (skip this update)"
            echo "  [e] Exit provisioning script"
            echo ""
            read -p "Choice [o/k/e]: " -n 1 -r choice
            echo ""
            
            case "$choice" in
                o|O)
                    log "Backing up existing file..."
                    if [[ "$use_sudo" == "true" ]]; then
                        sudo cp "$dest_path" "$dest_path.backup.$(date +%Y%m%d_%H%M%S)"
                    else
                        cp "$dest_path" "$dest_path.backup.$(date +%Y%m%d_%H%M%S)"
                    fi
                    success "Backup created"
                    ;;
                k|K)
                    warning "Keeping current file, skipping update"
                    rm "$temp_file"
                    return 1
                    ;;
                e|E)
                    error "User requested exit"
                    rm "$temp_file"
                    exit 0
                    ;;
                *)
                    error "Invalid choice, keeping current file"
                    rm "$temp_file"
                    return 1
                    ;;
            esac
        fi
    fi
    
    # Install the file
    if [[ "$use_sudo" == "true" ]]; then
        sudo cp "$temp_file" "$dest_path"
    else
        cp "$temp_file" "$dest_path"
    fi
    rm "$temp_file"
    
    if [[ -f "$dest_path" ]]; then
        success "Installed $(basename "$dest_path")"
        return 0
    else
        error "Failed to install $(basename "$dest_path")"
        return 1
    fi
}

# Helper function to install a file from a temp file if it differs
# Usage: install_temp_file_if_changed "temp_file_path" "destination_path" [use_sudo]
# Returns: 0 if file was updated or already correct, 1 on error
# Note: This function consumes (deletes) the temp file
install_temp_file_if_changed() {
    local temp_file="$1"
    local dest_path="$2"
    local use_sudo="${3:-false}"
    
    # Check if destination exists and compare
    if [[ -f "$dest_path" ]]; then
        local files_match=false
        if [[ "$use_sudo" == "true" ]]; then
            if sudo cmp -s "$temp_file" "$dest_path"; then
                files_match=true
            fi
        else
            if cmp -s "$temp_file" "$dest_path"; then
                files_match=true
            fi
        fi
        
        if [[ "$files_match" == "true" ]]; then
            success "$(basename "$dest_path") already exists and is correct"
            rm "$temp_file"
            return 0
        else
            warning "$(basename "$dest_path") exists but differs from expected content"
            log "Backing up existing file..."
            if [[ "$use_sudo" == "true" ]]; then
                sudo cp "$dest_path" "$dest_path.backup.$(date +%Y%m%d_%H%M%S)"
            else
                cp "$dest_path" "$dest_path.backup.$(date +%Y%m%d_%H%M%S)"
            fi
            success "Backup created"
        fi
    fi
    
    # Install the file
    if [[ "$use_sudo" == "true" ]]; then
        sudo cp "$temp_file" "$dest_path"
    else
        cp "$temp_file" "$dest_path"
    fi
    rm "$temp_file"
    
    if [[ -f "$dest_path" ]]; then
        success "Installed $(basename "$dest_path")"
        return 0
    else
        error "Failed to install $(basename "$dest_path")"
        return 1
    fi
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
    
    HELLO_PAGE="/usr/local/var/www/hello/index.html"
    
    # Define expected content
    read -r -d '' EXPECTED_CONTENT << 'EOF' || true
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
    
    # Install file using helper
    install_file_if_changed "$HELLO_PAGE" "$EXPECTED_CONTENT" false
    
    # Verify file size
    if [[ -f "$HELLO_PAGE" ]]; then
        FILE_SIZE=$(stat -f%z "$HELLO_PAGE")
        log "File size: $FILE_SIZE bytes"
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
    
    # Define expected content
    read -r -d '' EXPECTED_CADDYFILE << 'EOF' || true
{
    # Global options
    admin off
}

# Simple :80 binding responds to all addresses
:80 {
    root * /usr/local/var/www/hello
    file_server
    
    log {
        output file /usr/local/var/log/caddy/access.log
    }
}
EOF
    
    # Install file using helper (with sudo)
    install_file_if_changed "$CADDYFILE" "$EXPECTED_CADDYFILE" true
    
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
    
    # Generate management script content to a temp file first
    TEMP_SCRIPT=$(mktemp)
    
    cat > "$TEMP_SCRIPT" << 'EOF'
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
    
    # Install using helper
    install_temp_file_if_changed "$TEMP_SCRIPT" "$MANAGE_SCRIPT" false
    
    # Make script executable
    log "Making script executable..."
    chmod +x "$MANAGE_SCRIPT"
    success "Script is executable"
    
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
    
    # Generate plist content to temp file first
    TEMP_PLIST=$(mktemp)
    
    # Create LaunchDaemon plist
    log "Generating LaunchDaemon plist..."
    
    cat > "$TEMP_PLIST" << EOF
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
    
    # Check if plist exists and differs
    NEEDS_UPDATE=false
    if [[ -f "$PLIST_PATH" ]]; then
        if ! sudo cmp -s "$TEMP_PLIST" "$PLIST_PATH"; then
            warning "LaunchDaemon plist exists but differs from expected content"
            log "Backing up existing plist..."
            sudo cp "$PLIST_PATH" "$PLIST_PATH.backup.$(date +%Y%m%d_%H%M%S)"
            success "Backup created"
            
            # Unload existing LaunchDaemon before updating
            log "Unloading existing LaunchDaemon..."
            sudo launchctl unload "$PLIST_PATH" 2>/dev/null || true
            success "Unloaded existing LaunchDaemon"
            
            NEEDS_UPDATE=true
        else
            success "LaunchDaemon plist already exists and is correct"
            rm "$TEMP_PLIST"
        fi
    else
        NEEDS_UPDATE=true
    fi
    
    # Update plist if needed
    if [[ "$NEEDS_UPDATE" == "true" ]]; then
        log "Installing LaunchDaemon plist..."
        sudo cp "$TEMP_PLIST" "$PLIST_PATH"
        rm "$TEMP_PLIST"
        success "Installed LaunchDaemon plist"
    fi
    
    # Set correct permissions
    log "Setting permissions on plist..."
    sudo chown root:wheel "$PLIST_PATH"
    sudo chmod 644 "$PLIST_PATH"
    success "Permissions set (root:wheel, 644)"
    
    # Load the LaunchDaemon if not already loaded
    if ! sudo launchctl list | grep -q "com.caddyserver.caddy"; then
        log "Loading LaunchDaemon..."
        sudo launchctl load -w "$PLIST_PATH"
        sleep 3
        success "LaunchDaemon loaded"
    else
        success "LaunchDaemon already loaded"
        # If LaunchDaemon is loaded but process isn't running, kickstart it
        if ! ps aux | grep -v grep | grep -q caddy; then
            log "LaunchDaemon loaded but Caddy not running, kickstarting..."
            sudo launchctl kickstart -k system/com.caddyserver.caddy
            sleep 3
        fi
    fi
    
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
    
    # Verify Caddy process is running (with retries)
    log "Verifying Caddy process..."
    RETRY_COUNT=0
    MAX_RETRIES=3
    while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
        if ps aux | grep -v grep | grep -q caddy; then
            success "✅ Caddy process is running"
            ps aux | grep -v grep | grep caddy | head -1
            break
        else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; then
                warning "Caddy not running yet, waiting... (attempt $RETRY_COUNT/$MAX_RETRIES)"
                sleep 2
            else
                error "Caddy process is not running after $MAX_RETRIES attempts"
                log "Checking error log:"
                tail -20 /usr/local/var/log/caddy/caddy-error.log 2>/dev/null || echo "No error log found"
                exit 1
            fi
        fi
    done
    
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
    log "Phase 1.6.5: Disable macOS Application Firewall"
    echo ""
    
    log "Note: For a home server behind a router firewall, the macOS Application"
    log "Firewall is not necessary and can cause connectivity issues."
    echo ""
    
    # Check firewall status
    log "Checking firewall status..."
    FIREWALL_STATUS=$(sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate)
    log "Current status: $FIREWALL_STATUS"
    
    # Disable the Application Firewall
    log "Disabling Application Firewall..."
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off
    success "Application Firewall disabled"
    
    # Verify it's disabled
    log "Verifying firewall status..."
    FIREWALL_STATUS=$(sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate)
    if echo "$FIREWALL_STATUS" | grep -q "disabled"; then
        success "✅ Firewall is disabled (State = 0)"
    else
        warning "Firewall status unclear: $FIREWALL_STATUS"
    fi
    
    # Get local IP for testing
    log "Detecting local IP address for testing..."
    LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "unknown")
    
    if [[ "$LOCAL_IP" != "unknown" ]]; then
        success "Local IP: $LOCAL_IP"
        
        log "Testing local access via IP address..."
        sleep 2
        
        if curl -s --connect-timeout 5 "http://$LOCAL_IP" > /dev/null 2>&1; then
            success "✅ Local IP access test passed!"
            log "Server is accessible at http://$LOCAL_IP"
        else
            warning "Local IP access test failed"
            log "This might resolve after a moment. Try: curl http://$LOCAL_IP"
        fi
    else
        warning "Could not detect local IP address"
    fi
    
    echo ""
    success "Phase 1.6.5 complete!"
    log "Application Firewall is disabled for server operation"
    log "Your Mac Mini is protected by your router's firewall"
    log "Test from another machine: curl http://$LOCAL_IP"
    echo ""
}

#==============================================================================
# Phase 1.6.7: Create Convenient Symlinks
#==============================================================================

phase_1_6_7_create_symlinks() {
    log "Phase 1.6.7: Create Convenient Symlinks"
    echo ""
    
    SYMLINK_DIR="$HOME/webserver/symlinks"
    
    # Create symlinks directory
    log "Creating symlinks directory..."
    if [[ ! -d "$SYMLINK_DIR" ]]; then
        mkdir -p "$SYMLINK_DIR"
        success "Created $SYMLINK_DIR"
    else
        success "Directory $SYMLINK_DIR already exists"
    fi
    
    # Define symlinks to create
    # Format: "symlink_name:target_path"
    SYMLINKS=(
        "Caddyfile:/usr/local/etc/Caddyfile"
        "www:/usr/local/var/www"
        "caddy-logs:/usr/local/var/log/caddy"
        "caddy-config:/usr/local/etc"
        "launchdaemon-plist:/Library/LaunchDaemons/com.caddyserver.caddy.plist"
    )
    
    log "Creating symlinks..."
    
    for symlink_def in "${SYMLINKS[@]}"; do
        LINK_NAME="${symlink_def%%:*}"
        TARGET_PATH="${symlink_def##*:}"
        LINK_PATH="$SYMLINK_DIR/$LINK_NAME"
        
        # Check if symlink already exists and points to correct target
        if [[ -L "$LINK_PATH" ]]; then
            CURRENT_TARGET=$(readlink "$LINK_PATH")
            if [[ "$CURRENT_TARGET" == "$TARGET_PATH" ]]; then
                success "Symlink $LINK_NAME already exists and is correct"
                continue
            else
                warning "Symlink $LINK_NAME exists but points to wrong target"
                log "Current: $CURRENT_TARGET"
                log "Expected: $TARGET_PATH"
                log "Removing old symlink..."
                rm "$LINK_PATH"
            fi
        elif [[ -e "$LINK_PATH" ]]; then
            warning "Path $LINK_NAME exists but is not a symlink"
            log "Backing up..."
            mv "$LINK_PATH" "$LINK_PATH.backup.$(date +%Y%m%d_%H%M%S)"
            success "Backup created"
        fi
        
        # Create symlink
        if [[ -e "$TARGET_PATH" ]]; then
            ln -s "$TARGET_PATH" "$LINK_PATH"
            success "Created symlink: $LINK_NAME -> $TARGET_PATH"
        else
            warning "Target does not exist, skipping: $TARGET_PATH"
        fi
    done
    
    echo ""
    success "Phase 1.6.7 complete!"
    log "Convenient symlinks available at: $SYMLINK_DIR"
    echo ""
}

#==============================================================================
# Phase 1.7: Configure Auto-Login (Manual Step with Confirmation)
#==============================================================================

phase_1_7_auto_login_prompt() {
    log "Phase 1.7: Configure Auto-Login for Docker Desktop"
    echo ""
    
    warning "⚠️  AUTO-LOGIN CONFIGURATION - MANUAL STEP REQUIRED"
    echo ""
    log "Docker Desktop for Mac only starts when a user is logged in."
    log "To ensure Docker containers start automatically after reboot,"
    log "you need to enable auto-login for your user account."
    echo ""
    log "Security implications:"
    log "  - Your Mac will boot directly to your desktop (no password)"
    log "  - Acceptable for: Home servers with physical security"
    log "  - NOT recommended for: Laptops or shared environments"
    echo ""
    
    log "To enable auto-login:"
    log "  1. Open System Settings"
    log "  2. Go to Users & Groups"
    log "  3. Click 'Automatically log in as:' and select your user"
    echo ""
    log "  OR run this command:"
    log "  sudo defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser \"\$(whoami)\""
    echo ""
    
    log "After enabling auto-login, configure Docker Desktop:"
    log "  1. Open Docker Desktop"
    log "  2. Go to Settings → General"
    log "  3. Enable 'Start Docker Desktop when you log in'"
    echo ""
    
    read -p "Press Enter once you've completed these steps (or skip to continue)..."
    
    echo ""
    success "Phase 1.7 complete!"
    log "If you enabled auto-login, Docker Desktop will start after reboot."
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
    phase_1_6_7_create_symlinks
    phase_1_7_auto_login_prompt
    
    log "========================================="
    log "Provisioning complete!"
    log "========================================="
    echo ""
    log "✅ Phase 1.1-1.7 Complete!"
    log ""
    log "Caddy webserver is now:"
    log "  - Installed and configured"
    log "  - Serving hello world page"
    log "  - Set to start automatically at boot"
    log "  - Manageable via ~/webserver/scripts/manage-caddy.sh"
    log "  - Convenient symlinks at ~/webserver/symlinks/"
    echo ""
    log "Next steps:"
    log "  - Test reboot: sudo reboot (then verify Caddy starts)"
    log "  - Continue with Phase 1.8 (Cloudflare DNS Challenge setup)"
    log "  - Or skip to Phase 2 to add your first real site"
    echo ""
}

# Run main function
main
