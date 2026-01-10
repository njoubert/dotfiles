#!/bin/bash

################################################################################
# iPerf3 Server Management Script for Ubuntu/Linux
# Manages the iPerf3 server systemd service on Ubuntu 22.04
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVICE_NAME="iperf3"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
JOURNALD_CONF_DIR="/etc/systemd/journald.conf.d"
JOURNALD_CONF_FILE="${JOURNALD_CONF_DIR}/iperf3.conf"
IPERF3_PORT="5201"
IPERF3_BIN="/usr/bin/iperf3"

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
    check_sudo
    
    log_section "Provisioning iperf3..."
    
    # Update package list
    log_info "Updating package list..."
    apt update
    
    # Check if iperf3 is installed
    if dpkg -l | grep -q "^ii.*iperf3"; then
        log_info "iperf3 is already installed"
        log_info "Checking for updates..."
        apt install -y --only-upgrade iperf3 || log_info "iperf3 is already up to date"
    else
        log_info "Installing iperf3..."
        apt install -y iperf3
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
# Install: Set up the systemd service
################################################################################
install_service() {
    check_sudo
    
    log_section "Installing iperf3 systemd service..."
    
    # Check if iperf3 is installed
    if ! command -v iperf3 &> /dev/null; then
        log_error "iperf3 is not installed. Run 'sudo ./manage-iperf3.sh provision' first."
        exit 1
    fi
    
    local iperf3_path
    iperf3_path=$(which iperf3)
    log_info "Using iperf3 at: $iperf3_path"
    
    # Create systemd service file
    log_info "Creating systemd service file..."
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=iperf3 server
After=network.target

[Service]
Type=simple
ExecStart=${iperf3_path} -s
Restart=on-failure
RestartSec=5s

# Security: Use dynamic user instead of nobody (avoids systemd warning)
DynamicUser=yes

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=iperf3

[Install]
WantedBy=multi-user.target
EOF
    
    # Set service file permissions
    chmod 644 "$SERVICE_FILE"
    log_info "Systemd service file created at: $SERVICE_FILE"
    
    # Configure journald for log rotation
    log_info "Configuring journald log rotation..."
    if [ ! -d "$JOURNALD_CONF_DIR" ]; then
        mkdir -p "$JOURNALD_CONF_DIR"
    fi
    
    cat > "$JOURNALD_CONF_FILE" << EOF
[Journal]
# Store logs persistently
Storage=persistent

# Keep logs from the last 30 days
MaxRetentionSec=30d

# Limit total journal size to 500MB
SystemMaxUse=500M

# Keep at least 100MB free
SystemKeepFree=100M

# Individual log file size limit
SystemMaxFileSize=50M
EOF
    
    log_info "Journald configuration created at: $JOURNALD_CONF_FILE"
    
    # Restart journald to apply configuration
    log_info "Restarting systemd-journald to apply configuration..."
    systemctl restart systemd-journald
    
    # Reload systemd daemon
    log_info "Reloading systemd daemon..."
    systemctl daemon-reload
    
    # Enable service (but don't start yet)
    log_info "Enabling service to start on boot..."
    systemctl enable "$SERVICE_NAME"
    
    # Configure firewall if ufw is active
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            log_info "Configuring UFW firewall..."
            ufw allow ${IPERF3_PORT}/tcp comment "iperf3 TCP" || true
            ufw allow ${IPERF3_PORT}/udp comment "iperf3 UDP" || true
            log_info "Firewall rules added for port ${IPERF3_PORT}"
        else
            log_info "UFW is installed but not active, skipping firewall configuration"
        fi
    else
        log_info "UFW not installed, skipping firewall configuration"
    fi
    
    log_info ""
    log_info "Installation complete!"
    log_info "To start the service, run: sudo ./manage-iperf3.sh start"
}

################################################################################
# Start: Start the service
################################################################################
start_service() {
    check_sudo
    
    log_section "Starting iperf3 service..."
    
    # Check if service file exists
    if [ ! -f "$SERVICE_FILE" ]; then
        log_error "Systemd service file not found. Run 'sudo ./manage-iperf3.sh install' first."
        exit 1
    fi
    
    # Start the service
    log_info "Starting systemd service..."
    systemctl start "$SERVICE_NAME"
    
    # Wait a moment for service to start
    sleep 2
    
    # Verify it's running
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_info "Service started successfully!"
        
        # Check if process is listening
        if ss -tlnp | grep -q ":${IPERF3_PORT}"; then
            log_info "iperf3 is listening on port ${IPERF3_PORT}"
        else
            log_warn "Service started but not listening on port ${IPERF3_PORT} yet"
            log_warn "Check logs: sudo journalctl -u iperf3 -f"
        fi
    else
        log_error "Failed to start service"
        log_error "Check logs: sudo journalctl -u iperf3 -e"
        exit 1
    fi
}

################################################################################
# Stop: Stop the service
################################################################################
stop_service() {
    check_sudo
    
    log_section "Stopping iperf3 service..."
    
    # Check if service is running
    if ! systemctl is-active --quiet "$SERVICE_NAME"; then
        log_warn "Service is not running"
        return
    fi
    
    # Stop the service
    log_info "Stopping systemd service..."
    systemctl stop "$SERVICE_NAME"
    
    # Wait a moment
    sleep 1
    
    # Verify it's stopped
    if ! systemctl is-active --quiet "$SERVICE_NAME"; then
        log_info "Service stopped successfully!"
    else
        log_warn "Service may still be running"
    fi
    
    # Check if port is still in use
    if ss -tlnp | grep -q ":${IPERF3_PORT}"; then
        log_warn "Port ${IPERF3_PORT} is still in use"
    fi
}

################################################################################
# Restart: Stop then start the service
################################################################################
restart_service() {
    check_sudo
    
    log_section "Restarting iperf3 service..."
    
    # Check if service file exists
    if [ ! -f "$SERVICE_FILE" ]; then
        log_error "Systemd service file not found. Run 'sudo ./manage-iperf3.sh install' first."
        exit 1
    fi
    
    systemctl restart "$SERVICE_NAME"
    
    # Wait a moment
    sleep 2
    
    # Verify it's running
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_info "Service restarted successfully!"
    else
        log_error "Failed to restart service"
        log_error "Check logs: sudo journalctl -u iperf3 -e"
        exit 1
    fi
}

################################################################################
# Status: Check service status
################################################################################
status() {
    log_section "iperf3 Service Status"
    echo ""
    
    # Check if iperf3 is installed
    if command -v iperf3 &> /dev/null; then
        local version
        version=$(iperf3 --version | head -n 1)
        echo -e "${GREEN}✓${NC} iperf3 is installed: $version"
    else
        echo -e "${RED}✗${NC} iperf3 is not installed"
        echo ""
        echo "Run 'sudo ./manage-iperf3.sh provision' to install iperf3"
        return
    fi
    
    # Check if service file exists
    if [ -f "$SERVICE_FILE" ]; then
        echo -e "${GREEN}✓${NC} Systemd service file exists: $SERVICE_FILE"
    else
        echo -e "${RED}✗${NC} Systemd service file not found: $SERVICE_FILE"
        echo ""
        echo "Run 'sudo ./manage-iperf3.sh install' to install the service"
        return
    fi
    
    # Check if service is enabled
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Service is enabled (starts on boot)"
    else
        echo -e "${YELLOW}○${NC} Service is not enabled (won't start on boot)"
    fi
    
    # Check if service is active
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "${GREEN}✓${NC} Service is running"
        
        # Get PID
        local pid
        pid=$(systemctl show -p MainPID --value "$SERVICE_NAME")
        if [ "$pid" != "0" ]; then
            echo -e "${GREEN}✓${NC} Process running with PID: $pid"
        fi
    else
        echo -e "${RED}✗${NC} Service is not running"
    fi
    
    # Check if listening on port
    echo ""
    echo "Port status:"
    if ss -tlnp | grep -q ":${IPERF3_PORT}"; then
        echo -e "${GREEN}✓${NC} Listening on port ${IPERF3_PORT}"
        ss -tlnp | grep ":${IPERF3_PORT}" | head -5
    else
        echo -e "${RED}✗${NC} Not listening on port ${IPERF3_PORT}"
    fi
    
    # Check firewall status
    echo ""
    echo "Firewall status:"
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            if ufw status | grep -q "${IPERF3_PORT}"; then
                echo -e "${GREEN}✓${NC} UFW rule exists for port ${IPERF3_PORT}"
            else
                echo -e "${YELLOW}○${NC} UFW is active but no rule for port ${IPERF3_PORT}"
            fi
        else
            echo -e "${YELLOW}○${NC} UFW is not active"
        fi
    else
        echo -e "${YELLOW}○${NC} UFW is not installed"
    fi
    
    # Show journal disk usage
    echo ""
    echo "Journal disk usage:"
    journalctl --disk-usage 2>/dev/null || echo "Unable to check journal disk usage"
    
    # Show last few log lines
    echo ""
    echo "Recent log entries (last 10 lines):"
    echo "----------------------------------------"
    journalctl -u "$SERVICE_NAME" -n 10 --no-pager 2>/dev/null || echo "No log entries yet"
}

################################################################################
# Uninstall: Remove the service
################################################################################
uninstall_service() {
    check_sudo
    
    log_section "Uninstalling iperf3 service..."
    
    # Stop service if running
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_info "Stopping service..."
        systemctl stop "$SERVICE_NAME"
    fi
    
    # Disable service
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        log_info "Disabling service..."
        systemctl disable "$SERVICE_NAME"
    fi
    
    # Remove service file
    if [ -f "$SERVICE_FILE" ]; then
        log_info "Removing systemd service file..."
        rm "$SERVICE_FILE"
        log_info "Service file removed"
    else
        log_warn "Service file not found: $SERVICE_FILE"
    fi
    
    # Remove journald configuration
    if [ -f "$JOURNALD_CONF_FILE" ]; then
        log_info "Removing journald configuration..."
        rm "$JOURNALD_CONF_FILE"
        log_info "Journald configuration removed"
    fi
    
    # Reload systemd daemon
    log_info "Reloading systemd daemon..."
    systemctl daemon-reload
    
    # Remove firewall rules if ufw is active
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            log_info "Removing UFW firewall rules..."
            ufw delete allow ${IPERF3_PORT}/tcp 2>/dev/null || true
            ufw delete allow ${IPERF3_PORT}/udp 2>/dev/null || true
            log_info "Firewall rules removed"
        fi
    fi
    
    # Ask about removing iperf3 package
    echo ""
    read -p "Remove iperf3 package? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Removing iperf3 package..."
        apt remove -y iperf3
        log_info "iperf3 package removed"
    else
        log_info "Keeping iperf3 package installed"
    fi
    
    # Ask about clearing logs
    echo ""
    read -p "Clear iperf3 journal logs? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Clearing iperf3 journal logs..."
        journalctl --rotate 2>/dev/null || true
        journalctl --vacuum-time=1s -u "$SERVICE_NAME" 2>/dev/null || true
        log_info "Journal logs cleared"
    else
        log_info "Keeping journal logs"
    fi
    
    log_info ""
    log_info "Uninstallation complete!"
}

################################################################################
# Logs: Tail the journal logs
################################################################################
tail_logs() {
    journalctl -u "$SERVICE_NAME" -f
}

################################################################################
# Show logs: Show recent logs
################################################################################
show_logs() {
    local lines="${1:-1000}"
    journalctl -u "$SERVICE_NAME" -n "$lines" --no-pager
}

################################################################################
# Test: Run a quick client test
################################################################################
test_server() {
    log_section "Testing iperf3 server..."
    
    # Check if iperf3 is installed
    if ! command -v iperf3 &> /dev/null; then
        log_error "iperf3 is not installed. Run 'sudo ./manage-iperf3.sh provision' first."
        exit 1
    fi
    
    # Check if server is listening
    if ! ss -tlnp | grep -q ":${IPERF3_PORT}"; then
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
# Full setup: Provision, install, and start in one command
################################################################################
setup() {
    check_sudo
    
    log_section "Running full iperf3 setup..."
    echo ""
    
    provision
    echo ""
    
    install_service
    echo ""
    
    start_service
    echo ""
    
    log_info "Full setup complete!"
    log_info ""
    log_info "You can now test from another machine with:"
    log_info "  iperf3 -c $(hostname -I | awk '{print $1}')"
}

################################################################################
# Usage information
################################################################################
usage() {
    cat << EOF
Usage: $0 <command>

Commands:
    setup       Run full setup (provision + install + start)
    provision   Install or update iperf3 via apt (requires sudo)
    install     Install the systemd service (requires sudo)
    start       Start the iperf3 service (requires sudo)
    stop        Stop the iperf3 service (requires sudo)
    restart     Restart the iperf3 service (requires sudo)
    status      Check service status
    uninstall   Remove the service (requires sudo)
    logs        Tail the journal logs (follow mode)
    show-logs   Show recent logs (default: last 100 lines)
    test        Test the iperf3 server with a local client

Examples:
    sudo $0 setup             # Full setup in one command
    sudo $0 provision         # Install iperf3
    sudo $0 install           # Set up the service
    sudo $0 start             # Start the service
    $0 status                 # Check if it's running
    $0 test                   # Test with local client
    $0 logs                   # Follow logs in real-time
    $0 show-logs 50           # Show last 50 log entries

Log Management:
    View real-time logs:      sudo journalctl -u iperf3 -f
    View last 100 lines:      sudo journalctl -u iperf3 -n 100
    View logs since boot:     sudo journalctl -u iperf3 -b
    Check disk usage:         sudo journalctl --disk-usage
    Vacuum old logs:          sudo journalctl --vacuum-time=7d

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
        setup)
            setup
            ;;
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
        show-logs)
            show_logs "${2:-100}"
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
