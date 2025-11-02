#!/bin/bash

################################################################################
# iPerf3 Server Management Script
# Manages the iPerf3 server LaunchDaemon on macOS
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PLIST_LABEL="com.njoubert.iperf3"
PLIST_FILE="/Library/LaunchDaemons/${PLIST_LABEL}.plist"
LOG_DIR="/var/log/iperf3"
LOG_FILE="${LOG_DIR}/iperf3-server.log"
ERROR_LOG_FILE="${LOG_DIR}/iperf3-server-error.log"
NEWSYSLOG_CONF="/etc/newsyslog.d/iperf3.conf"
IPERF3_PORT="5201"
IPERF3_USER="njoubert"

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo -e "${BLUE}==>${NC} $1"
}

################################################################################
# Check if running with sudo when needed
################################################################################
check_sudo() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "This command must be run with sudo"
        exit 1
    fi
}

################################################################################
# Provision: Install or update iperf3
################################################################################
provision() {
    log_section "Provisioning iperf3..."
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        log_error "Homebrew is not installed. Please install Homebrew first."
        exit 1
    fi
    
    # Check if iperf3 is installed
    if brew list iperf3 &> /dev/null; then
        log_info "iperf3 is already installed"
        log_info "Checking for updates..."
        brew upgrade iperf3 || log_info "iperf3 is already up to date"
    else
        log_info "Installing iperf3..."
        brew install iperf3
    fi
    
    # Validate installation
    if command -v iperf3 &> /dev/null; then
        local version
        version=$(iperf3 --version | head -n 1)
        log_info "iperf3 installed successfully: $version"
        log_info "Location: $(which iperf3)"
    else
        log_error "iperf3 installation failed"
        exit 1
    fi
    
    log_info "Provisioning complete!"
}

################################################################################
# Install: Set up the LaunchDaemon service
################################################################################
install_service() {
    check_sudo
    
    log_section "Installing iperf3 LaunchDaemon service..."
    
    # Check if iperf3 is installed
    if ! command -v iperf3 &> /dev/null; then
        log_error "iperf3 is not installed. Run './manage-iperf3.sh provision' first."
        exit 1
    fi
    
    local iperf3_path
    iperf3_path=$(which iperf3)
    log_info "Using iperf3 at: $iperf3_path"
    
    # Create log directory
    if [ ! -d "$LOG_DIR" ]; then
        log_info "Creating log directory: $LOG_DIR"
        mkdir -p "$LOG_DIR"
    fi
    
    # Set permissions on log directory
    chown ${IPERF3_USER}:staff "$LOG_DIR"
    chmod 755 "$LOG_DIR"
    log_info "Log directory permissions set"
    
    # Pre-create log files
    log_info "Creating log files..."
    touch "$LOG_FILE" "$ERROR_LOG_FILE"
    chown ${IPERF3_USER}:staff "$LOG_FILE" "$ERROR_LOG_FILE"
    chmod 644 "$LOG_FILE" "$ERROR_LOG_FILE"
    log_info "Log files created with proper permissions"
    
    # Create the plist file
    log_info "Creating LaunchDaemon plist..."
    cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_LABEL}</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>${iperf3_path}</string>
        <string>-s</string>
        <string>--port</string>
        <string>${IPERF3_PORT}</string>
        <string>--bind</string>
        <string>0.0.0.0</string>
    </array>
    
    <key>UserName</key>
    <string>${IPERF3_USER}</string>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>${LOG_FILE}</string>
    
    <key>StandardErrorPath</key>
    <string>${ERROR_LOG_FILE}</string>
</dict>
</plist>
EOF
    
    # Set plist permissions
    chown root:wheel "$PLIST_FILE"
    chmod 644 "$PLIST_FILE"
    log_info "LaunchDaemon plist created at: $PLIST_FILE"
    
    # Configure log rotation
    log_info "Configuring log rotation..."
    cat > "$NEWSYSLOG_CONF" << EOF
# logfilename                           [owner:group]    mode count size when  flags
${LOG_FILE}      ${IPERF3_USER}:staff   644  7     10000 *     GZ
${ERROR_LOG_FILE} ${IPERF3_USER}:staff  644  7     10000 *     GZ
EOF
    
    log_info "Log rotation configured at: $NEWSYSLOG_CONF"
    
    # Configure firewall
    log_info "Configuring firewall to allow iperf3..."
    /usr/libexec/ApplicationFirewall/socketfilterfw --add "$iperf3_path" 2>/dev/null || true
    /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp "$iperf3_path" 2>/dev/null || true
    log_info "Firewall configured"
    
    log_info ""
    log_info "Installation complete!"
    log_info "To start the service, run: sudo ./manage-iperf3.sh start"
}

################################################################################
# Start: Load and start the service
################################################################################
start_service() {
    check_sudo
    
    log_section "Starting iperf3 service..."
    
    # Check if plist exists
    if [ ! -f "$PLIST_FILE" ]; then
        log_error "LaunchDaemon plist not found. Run 'sudo ./manage-iperf3.sh install' first."
        exit 1
    fi
    
    # Check if already loaded
    if launchctl list | grep -q "$PLIST_LABEL"; then
        log_warn "Service is already loaded. Restarting..."
        launchctl unload "$PLIST_FILE" 2>/dev/null || true
        sleep 1
    fi
    
    # Load the service
    log_info "Loading LaunchDaemon..."
    launchctl load -w "$PLIST_FILE"
    
    # Wait a moment for service to start
    sleep 2
    
    # Verify it's running
    if launchctl list | grep -q "$PLIST_LABEL"; then
        log_info "Service started successfully!"
        
        # Check if process is running and listening
        if lsof -i :${IPERF3_PORT} &> /dev/null; then
            log_info "iperf3 is listening on port ${IPERF3_PORT}"
        else
            log_warn "Service loaded but not listening on port ${IPERF3_PORT} yet"
            log_warn "Check logs: tail -f ${LOG_FILE}"
        fi
    else
        log_error "Failed to start service"
        log_error "Check logs: tail ${ERROR_LOG_FILE}"
        exit 1
    fi
}

################################################################################
# Stop: Unload the service
################################################################################
stop_service() {
    check_sudo
    
    log_section "Stopping iperf3 service..."
    
    # Check if loaded
    if ! launchctl list | grep -q "$PLIST_LABEL"; then
        log_warn "Service is not loaded"
        return
    fi
    
    # Unload the service
    log_info "Unloading LaunchDaemon..."
    launchctl unload "$PLIST_FILE" 2>/dev/null || true
    
    # Wait a moment
    sleep 1
    
    # Verify it's stopped
    if ! launchctl list | grep -q "$PLIST_LABEL"; then
        log_info "Service stopped successfully!"
    else
        log_warn "Service may still be running"
    fi
    
    # Check if port is still in use
    if lsof -i :${IPERF3_PORT} &> /dev/null; then
        log_warn "Port ${IPERF3_PORT} is still in use"
    fi
}

################################################################################
# Restart: Stop then start the service
################################################################################
restart_service() {
    log_section "Restarting iperf3 service..."
    stop_service
    sleep 1
    start_service
}

################################################################################
# Status: Check service status
################################################################################
status() {
    log_section "iperf3 Service Status"
    echo ""
    
    # Check if plist exists
    if [ -f "$PLIST_FILE" ]; then
        echo -e "${GREEN}✓${NC} LaunchDaemon plist exists: $PLIST_FILE"
    else
        echo -e "${RED}✗${NC} LaunchDaemon plist not found: $PLIST_FILE"
        echo ""
        echo "Run 'sudo ./manage-iperf3.sh install' to install the service"
        return
    fi
    
    # Check if service is loaded
    if launchctl list | grep -q "$PLIST_LABEL"; then
        echo -e "${GREEN}✓${NC} LaunchDaemon is loaded"
        
        # Get PID if available
        local pid
        pid=$(launchctl list | grep "$PLIST_LABEL" | awk '{print $1}')
        if [ "$pid" != "-" ]; then
            echo -e "${GREEN}✓${NC} Process running with PID: $pid"
        fi
    else
        echo -e "${RED}✗${NC} LaunchDaemon is not loaded"
        echo ""
        echo "Run 'sudo ./manage-iperf3.sh start' to start the service"
        return
    fi
    
    # Check if iperf3 process is running
    if pgrep -x iperf3 > /dev/null; then
        echo -e "${GREEN}✓${NC} iperf3 process is running"
    else
        echo -e "${RED}✗${NC} iperf3 process is not running"
    fi
    
    # Check if listening on port
    echo ""
    echo "Port status:"
    if lsof -i :${IPERF3_PORT} &> /dev/null; then
        echo -e "${GREEN}✓${NC} Listening on port ${IPERF3_PORT}"
        lsof -i :${IPERF3_PORT}
    else
        echo -e "${RED}✗${NC} Not listening on port ${IPERF3_PORT}"
    fi
    
    # Show log file info
    echo ""
    echo "Log files:"
    if [ -f "$LOG_FILE" ]; then
        local log_size
        log_size=$(du -h "$LOG_FILE" | cut -f1)
        echo "  Main log: $LOG_FILE (${log_size})"
    fi
    if [ -f "$ERROR_LOG_FILE" ]; then
        local error_log_size
        error_log_size=$(du -h "$ERROR_LOG_FILE" | cut -f1)
        echo "  Error log: $ERROR_LOG_FILE (${error_log_size})"
    fi
    
    # Show last few log lines if log exists
    if [ -f "$LOG_FILE" ]; then
        echo ""
        echo "Recent log entries (last 10 lines):"
        echo "----------------------------------------"
        tail -10 "$LOG_FILE" 2>/dev/null || echo "No log entries yet"
    fi
}

################################################################################
# Uninstall: Remove the service
################################################################################
uninstall_service() {
    check_sudo
    
    log_section "Uninstalling iperf3 service..."
    
    # Stop service if running
    if launchctl list | grep -q "$PLIST_LABEL"; then
        log_info "Stopping service..."
        stop_service
    fi
    
    # Remove plist
    if [ -f "$PLIST_FILE" ]; then
        log_info "Removing LaunchDaemon plist..."
        rm "$PLIST_FILE"
        log_info "Plist removed"
    else
        log_warn "Plist not found: $PLIST_FILE"
    fi
    
    # Remove log rotation config
    if [ -f "$NEWSYSLOG_CONF" ]; then
        log_info "Removing log rotation configuration..."
        rm "$NEWSYSLOG_CONF"
        log_info "Log rotation config removed"
    fi
    
    # Ask about removing logs
    echo ""
    read -p "Remove log directory and logs? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -d "$LOG_DIR" ]; then
            log_info "Removing logs..."
            rm -rf "$LOG_DIR"
            log_info "Logs removed"
        fi
    else
        log_info "Keeping logs at: $LOG_DIR"
    fi
    
    log_info ""
    log_info "Uninstallation complete!"
    log_info "Note: iperf3 binary was not removed. Run 'brew uninstall iperf3' if desired."
}

################################################################################
# Logs: Tail the log file
################################################################################
tail_logs() {
    log_section "Tailing iperf3 logs..."
    
    if [ ! -f "$LOG_FILE" ]; then
        log_error "Log file not found: $LOG_FILE"
        exit 1
    fi
    
    log_info "Press Ctrl+C to stop"
    echo ""
    tail -f "$LOG_FILE"
}

################################################################################
# Test: Run a quick client test
################################################################################
test_server() {
    log_section "Testing iperf3 server..."
    
    # Check if iperf3 is installed
    if ! command -v iperf3 &> /dev/null; then
        log_error "iperf3 is not installed. Run './manage-iperf3.sh provision' first."
        exit 1
    fi
    
    # Check if server is listening
    if ! lsof -i :${IPERF3_PORT} &> /dev/null; then
        log_error "iperf3 server is not listening on port ${IPERF3_PORT}"
        log_error "Start the service with: sudo ./manage-iperf3.sh start"
        exit 1
    fi
    
    log_info "Running 5-second test against localhost..."
    echo ""
    iperf3 -c localhost -t 5
    
    echo ""
    log_info "Test complete!"
}

################################################################################
# Usage information
################################################################################
usage() {
    cat << EOF
Usage: $0 <command>

Commands:
    provision   Install or update iperf3 via Homebrew
    install     Install the LaunchDaemon service (requires sudo)
    start       Start the iperf3 service (requires sudo)
    stop        Stop the iperf3 service (requires sudo)
    restart     Restart the iperf3 service (requires sudo)
    status      Check service status
    uninstall   Remove the service (requires sudo)
    logs        Tail the log file
    test        Test the iperf3 server with a local client

Examples:
    $0 provision          # Install iperf3
    sudo $0 install       # Set up the service
    sudo $0 start         # Start the service
    $0 status             # Check if it's running
    $0 test               # Test with local client

EOF
}

################################################################################
# Main
################################################################################
main() {
    if [ $# -eq 0 ]; then
        usage
        exit 1
    fi
    
    case "$1" in
        provision)
            provision
            ;;
        install)
            install_service
            ;;
        start)
            start_service
            ;;
        stop)
            stop_service
            ;;
        restart)
            restart_service
            ;;
        status)
            status
            ;;
        uninstall)
            uninstall_service
            ;;
        logs)
            tail_logs
            ;;
        test)
            test_server
            ;;
        *)
            log_error "Unknown command: $1"
            echo ""
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
