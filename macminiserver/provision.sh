#!/bin/bash

################################################################################
# Mac Mini Server Provisioning Script
# macOS Sequoia 15.7
# 
# This script is idempotent and can be run multiple times safely.
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

################################################################################
# Install Homebrew
################################################################################
install_homebrew() {
    log_info "Checking for Homebrew installation..."
    
    if command -v brew &> /dev/null; then
        log_info "Homebrew already installed at $(which brew)"
        log_info "Updating Homebrew..."
        brew update
    else
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for Apple Silicon Macs
        if [[ $(uname -m) == "arm64" ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
        
        log_info "Homebrew installed successfully"
    fi
}

################################################################################
# Install Docker
################################################################################
install_docker() {
    log_info "Checking for Docker installation..."
    
    if brew list --cask docker &> /dev/null; then
        log_info "Docker already installed"
    else
        log_info "Installing Docker Desktop via Homebrew Cask..."
        brew install --cask docker
        log_info "Docker installed successfully"
    fi
    
    # Check if Docker is running
    if pgrep -x "Docker" > /dev/null; then
        log_info "Docker is running"
        
        # Pre-pull common Docker images
        log_info "Pre-pulling common Docker images..."
        docker pull nginx:latest 2>/dev/null || log_warn "Failed to pull nginx image"
        docker pull hello-world:latest 2>/dev/null || log_warn "Failed to pull hello-world image"
        log_info "Docker images pre-pulled"
    else
        log_warn "Docker is installed but not running. Please start Docker Desktop from Applications."
        log_warn "You can start it with: open -a Docker"
        log_warn "After starting Docker, run: docker pull nginx && docker pull hello-world"
    fi
}

################################################################################
# Install useful server tools
################################################################################
install_tools() {
    log_info "Installing useful server tools..."
    
    local tools=(
        "git"
        "wget"
        "curl"
        "htop"
        "iperf3"
        "vim"
        "fail2ban"
    )
    
    for tool in "${tools[@]}"; do
        if brew list "$tool" &> /dev/null; then
            log_info "$tool already installed"
        else
            log_info "Installing $tool..."
            brew install "$tool"
        fi
    done
}

################################################################################
# Install GUI applications
################################################################################
install_gui_apps() {
    log_info "Installing GUI applications..."
    
    local casks=(
        "rectangle"
        "sublime-text"
        "iterm2"
    )
    
    for cask in "${casks[@]}"; do
        if brew list --cask "$cask" &> /dev/null; then
            log_info "$cask already installed"
        else
            log_info "Installing $cask..."
            brew install --cask "$cask"
        fi
    done
}

################################################################################
# Install and configure Oh My Zsh and Powerlevel10k
################################################################################
install_oh_my_zsh() {
    log_info "Checking for Oh My Zsh installation..."
    
    if [ -d "$HOME/.oh-my-zsh" ]; then
        log_info "Oh My Zsh already installed"
    else
        log_info "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        log_info "Oh My Zsh installed successfully"
    fi
    
    # Install Powerlevel10k theme
    local P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    if [ -d "$P10K_DIR" ]; then
        log_info "Powerlevel10k already installed"
    else
        log_info "Installing Powerlevel10k..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
        log_info "Powerlevel10k installed successfully"
    fi
    
    # Update .zshrc to use powerlevel10k theme
    if grep -q "ZSH_THEME=\"powerlevel10k/powerlevel10k\"" "$HOME/.zshrc" 2>/dev/null; then
        log_info "Powerlevel10k theme already set in .zshrc"
    else
        log_info "Configuring Powerlevel10k theme in .zshrc..."
        if [ -f "$HOME/.zshrc" ]; then
            sed -i.bak 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$HOME/.zshrc"
        fi
    fi
    
    # Set zsh as default shell if it isn't already
    if [ "$SHELL" != "$(which zsh)" ]; then
        log_info "Setting zsh as default shell..."
        chsh -s "$(which zsh)"
        log_info "Default shell changed to zsh (will take effect on next login)"
    else
        log_info "zsh is already the default shell"
    fi
}

################################################################################
# Configure Git
################################################################################
configure_git() {
    log_info "Configuring Git..."
    
    # Set git user name
    if [ "$(git config --global user.name)" != "Niels Joubert" ]; then
        git config --global user.name "Niels Joubert"
        log_info "Git user.name set to 'Niels Joubert'"
    else
        log_info "Git user.name already configured"
    fi
    
    # Set git user email
    if [ "$(git config --global user.email)" != "njoubert@gmail.com" ]; then
        git config --global user.email "njoubert@gmail.com"
        log_info "Git user.email set to 'njoubert@gmail.com'"
    else
        log_info "Git user.email already configured"
    fi
    
    # Set some useful defaults
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    log_info "Git configuration complete"
}

################################################################################
# Install Monaco Nerd Font
################################################################################
install_fonts() {
    log_info "Installing Menlo for Powerline Font..."
    
    # Get the directory where this script is located
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    FONT_SOURCE="$SCRIPT_DIR/fonts"
    
    if [ -d "$FONT_SOURCE" ]; then
        # Install fonts to user's font directory
        FONT_DEST="$HOME/Library/Fonts"
        mkdir -p "$FONT_DEST"
        
        # Copy .ttf and .otf files
        if ls "$FONT_SOURCE"/*.{ttf,otf} 1> /dev/null 2>&1; then
            cp -f "$FONT_SOURCE"/*.ttf "$FONT_DEST/" 2>/dev/null || true
            cp -f "$FONT_SOURCE"/*.otf "$FONT_DEST/" 2>/dev/null || true
            log_info "Menlo for Powerline Font installed"
        else
            log_warn "No font files found in $FONT_SOURCE"
        fi
    else
        log_warn "Menlo for Powerline Font source not found at $FONT_SOURCE"
    fi
}

################################################################################
# Configure iTerm2
################################################################################
configure_iterm2() {
    log_info "Configuring iTerm2..."
    
    # Get the directory where this script is located
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    ITERM_PROFILE="$SCRIPT_DIR/njoubert-iterm2-profile.json"
    
    # Create iTerm2 preferences directory
    ITERM_PREFS_DIR="$HOME/.config/iterm2"
    mkdir -p "$ITERM_PREFS_DIR"
    
    if [ -f "$ITERM_PROFILE" ]; then
        # Copy the profile to the config directory
        cp "$ITERM_PROFILE" "$ITERM_PREFS_DIR/"
        log_info "Copied iTerm2 profile to $ITERM_PREFS_DIR"
        
        # Set iTerm2 to load preferences from the config directory
        defaults write com.googlecode.iterm2 PrefsCustomFolder "$ITERM_PREFS_DIR"
        defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
        log_info "iTerm2 configured to use custom profile from $ITERM_PREFS_DIR"
    else
        log_warn "iTerm2 profile not found at $ITERM_PROFILE"
    fi
}

################################################################################
# Configure macOS to never sleep
################################################################################
configure_sleep_settings() {
    log_info "Configuring power management settings..."
    
    # Prevent the system from sleeping
    sudo pmset -a sleep 0
    log_info "System sleep disabled"
    
    # Prevent the display from sleeping
    sudo pmset -a displaysleep 0
    log_info "Display sleep disabled"
    
    # Prevent disk sleep
    sudo pmset -a disksleep 0
    log_info "Disk sleep disabled"
    
    # Disable automatic system restart on power loss (optional, comment out if not desired)
    sudo pmset -a autorestart 1
    log_info "Automatic restart on power loss enabled"
    
    # Wake on network access (useful for remote management)
    sudo pmset -a womp 1
    log_info "Wake on network access enabled"
    
    # Show current power settings
    log_info "Current power management settings:"
    pmset -g
}

################################################################################
# Configure system preferences
################################################################################
configure_system_preferences() {
    log_info "Configuring system preferences..."
    
    # Set computer name
    CURRENT_HOSTNAME=$(scutil --get ComputerName 2>/dev/null || echo "")
    if [ "$CURRENT_HOSTNAME" != "macminiserver" ]; then
        log_info "Setting computer name to 'macminiserver'..."
        sudo scutil --set ComputerName "macminiserver"
        sudo scutil --set LocalHostName "macminiserver"
        sudo scutil --set HostName "macminiserver"
        log_info "Computer name set to 'macminiserver'"
    else
        log_info "Computer name already set to 'macminiserver'"
    fi
    
    # Disable screen saver
    defaults -currentHost write com.apple.screensaver idleTime 0
    log_info "Screen saver disabled"
    
    # Enable automatic software updates (security updates)
    sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
    sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool true
    sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate ConfigDataInstall -bool true
    sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -bool true
    log_info "Automatic security updates enabled"
    
    # Enable remote login (SSH)
    if sudo systemsetup -getremotelogin | grep -q "Off"; then
        log_info "Enabling remote login (SSH)..."
        sudo systemsetup -setremotelogin on
    else
        log_info "Remote login (SSH) already enabled"
    fi
    
    # Make the dock only show active apps
    defaults write com.apple.dock static-only -bool true
    killall Dock 2>/dev/null || true
    log_info "Dock configured to show only active apps"
}

################################################################################
# Configure Fail2ban
################################################################################
configure_fail2ban() {
    log_info "Configuring Fail2ban..."
    
    # Check if fail2ban is installed
    if ! command -v fail2ban-client &> /dev/null; then
        log_warn "Fail2ban not installed, skipping configuration"
        return
    fi
    
    # Create fail2ban config directory
    sudo mkdir -p /usr/local/etc/fail2ban
    
    # Create basic jail.local configuration for SSH protection
    if [ ! -f /usr/local/etc/fail2ban/jail.local ]; then
        log_info "Creating Fail2ban configuration..."
        sudo tee /usr/local/etc/fail2ban/jail.local > /dev/null << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 10

[sshd]
enabled = true
port = ssh
logpath = /var/log/system.log
EOF
        log_info "Fail2ban configuration created"
    else
        log_info "Fail2ban configuration already exists"
    fi
    
    # Start fail2ban service
    brew services list | grep -q "fail2ban.*started" && {
        log_info "Fail2ban service already running"
    } || {
        log_info "Starting Fail2ban service..."
        brew services start fail2ban
        log_info "Fail2ban service started"
    }
}

################################################################################
# Configure log rotation
################################################################################
configure_log_rotation() {
    log_info "Configuring log rotation..."
    
    # Create newsyslog.d directory if it doesn't exist
    sudo mkdir -p /etc/newsyslog.d
    
    # Configure log rotation for common server logs
    if [ ! -f /etc/newsyslog.d/server.conf ]; then
        log_info "Creating log rotation configuration..."
        sudo tee /etc/newsyslog.d/server.conf > /dev/null << 'EOF'
# Docker container logs (if logging to file)
/var/log/docker/*.log    644  7     100  *     GZ

# Custom application logs
/var/log/server/*.log    644  7     100  *     GZ
EOF
        log_info "Log rotation configured"
    else
        log_info "Log rotation already configured"
    fi
    
    # macOS uses newsyslog by default, which runs daily
    log_info "System logs will be rotated daily by newsyslog"
}

################################################################################
# Setup Homebrew auto-update
################################################################################
setup_brew_autoupdate() {
    log_info "Setting up Homebrew auto-update..."
    
    # Create launchd plist for homebrew auto-update
    PLIST_FILE="$HOME/Library/LaunchAgents/com.homebrew.autoupdate.plist"
    
    if [ ! -f "$PLIST_FILE" ]; then
        log_info "Creating Homebrew auto-update LaunchAgent..."
        mkdir -p "$HOME/Library/LaunchAgents"
        
        cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.homebrew.autoupdate</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>$(which brew) update && $(which brew) upgrade && $(which brew) cleanup</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/homebrew-autoupdate.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/homebrew-autoupdate.error.log</string>
</dict>
</plist>
EOF
        
        # Load the LaunchAgent
        launchctl load "$PLIST_FILE" 2>/dev/null || true
        log_info "Homebrew auto-update scheduled daily at 3:00 AM"
    else
        log_info "Homebrew auto-update already configured"
    fi
}

################################################################################
# Enable SMB file sharing
################################################################################
enable_smb_sharing() {
    log_info "Configuring SMB file sharing..."
    
    # Enable SMB file sharing
    if sudo launchctl list | grep -q "com.apple.smbd"; then
        log_info "SMB file sharing already enabled"
    else
        log_info "Enabling SMB file sharing..."
        sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.smbd.plist 2>/dev/null || true
        log_info "SMB file sharing enabled"
    fi
    
    # Note about sharing folders
    log_info "To share folders, use System Settings > General > Sharing > File Sharing"
    log_info "Or use: sudo sharing -a /path/to/folder -S 'Share Name' -s 001"
}

################################################################################
# Configure firewall
################################################################################
configure_firewall() {
    log_info "Configuring firewall..."
    
    # Enable firewall
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
    log_info "Firewall enabled"
    
    # Set firewall to block all incoming connections by default
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall off
    log_info "Firewall set to allow signed applications"
    
    # Enable stealth mode (don't respond to ping)
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
    log_info "Stealth mode enabled"
    
    # Enable logging
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setloggingmode on
    log_info "Firewall logging enabled"
    
    # Note: HTTP (80) and HTTPS (443) are typically handled by allowing specific apps
    # For Docker/nginx, the firewall will prompt or you can add rules for specific apps
    log_info "Note: HTTP/HTTPS traffic will be allowed through Docker and signed applications"
    log_info "To allow specific apps: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /path/to/app"
}

################################################################################
# Create tail_logs.sh helper script
################################################################################
create_tail_logs_script() {
    log_info "Creating tail_logs.sh helper script..."
    
    # Get the directory where this script is located
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    TAIL_LOGS_SCRIPT="$SCRIPT_DIR/tail_logs.sh"
    
    cat > "$TAIL_LOGS_SCRIPT" << 'EOF'
#!/bin/bash

################################################################################
# Log Viewing Helper Script for Mac Mini Server
################################################################################

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}================================${NC}"
echo -e "${CYAN}Mac Mini Server - Log Viewer${NC}"
echo -e "${CYAN}================================${NC}"
echo ""
echo "Select which logs you'd like to view:"
echo ""
echo "  1) System Log (general system messages)"
echo "  2) Docker Logs (Docker Desktop logs)"
echo "  3) Apache/Nginx Access Logs (if running locally)"
echo "  4) Apache/Nginx Error Logs (if running locally)"
echo "  5) System Diagnostics (kernel messages)"
echo "  6) Install Logs (software installation)"
echo "  7) Security Logs (auth and security events)"
echo "  8) All Docker Container Logs"
echo "  9) Network Statistics (live)"
echo " 10) Disk Usage and I/O"
echo " 11) Process Monitor (top processes)"
echo " 12) Firewall Logs"
echo ""
echo "  0) Exit"
echo ""
read -p "Enter your choice [0-12]: " choice

case $choice in
    1)
        echo -e "${GREEN}Tailing system log...${NC}"
        echo "Press Ctrl+C to exit"
        log show --predicate 'eventMessage contains "error" OR eventMessage contains "fail"' --style syslog --last 1h | tail -f
        ;;
    2)
        echo -e "${GREEN}Tailing Docker logs...${NC}"
        echo "Press Ctrl+C to exit"
        tail -f ~/Library/Containers/com.docker.docker/Data/log/vm/dockerd.log 2>/dev/null || \
        echo "Docker logs not found. Is Docker Desktop installed and running?"
        ;;
    3)
        echo -e "${GREEN}Checking for Apache/Nginx access logs...${NC}"
        if [ -f /usr/local/var/log/nginx/access.log ]; then
            tail -f /usr/local/var/log/nginx/access.log
        elif docker ps --format '{{.Names}}' | grep -q nginx; then
            NGINX_CONTAINER=$(docker ps --format '{{.Names}}' | grep nginx | head -1)
            echo "Showing logs for container: $NGINX_CONTAINER"
            docker logs -f "$NGINX_CONTAINER"
        else
            echo "No nginx access logs found"
        fi
        ;;
    4)
        echo -e "${GREEN}Checking for Apache/Nginx error logs...${NC}"
        if [ -f /usr/local/var/log/nginx/error.log ]; then
            tail -f /usr/local/var/log/nginx/error.log
        elif docker ps --format '{{.Names}}' | grep -q nginx; then
            NGINX_CONTAINER=$(docker ps --format '{{.Names}}' | grep nginx | head -1)
            echo "Showing logs for container: $NGINX_CONTAINER"
            docker logs -f "$NGINX_CONTAINER" 2>&1 | grep -i error
        else
            echo "No nginx error logs found"
        fi
        ;;
    5)
        echo -e "${GREEN}Showing system diagnostics...${NC}"
        echo "Press Ctrl+C to exit"
        log show --predicate 'processImagePath contains "kernel"' --style syslog --last 30m | tail -f
        ;;
    6)
        echo -e "${GREEN}Showing installation logs...${NC}"
        tail -f /var/log/install.log
        ;;
    7)
        echo -e "${GREEN}Showing security logs...${NC}"
        echo "Press Ctrl+C to exit"
        log show --predicate 'process == "authd" OR process == "SecurityAgent"' --style syslog --last 1h | tail -f
        ;;
    8)
        echo -e "${GREEN}Showing all Docker container logs...${NC}"
        if command -v docker &> /dev/null && docker ps -q | grep -q .; then
            docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
            echo ""
            read -p "Enter container name (or 'all' for all containers): " container_name
            if [ "$container_name" = "all" ]; then
                docker ps -q | xargs -L 1 docker logs --tail 50
            else
                docker logs -f "$container_name"
            fi
        else
            echo "No Docker containers running"
        fi
        ;;
    9)
        echo -e "${GREEN}Showing network statistics...${NC}"
        echo "Press Ctrl+C to exit"
        while true; do
            clear
            echo -e "${CYAN}Network Connections:${NC}"
            netstat -an | grep ESTABLISHED | head -20
            echo ""
            echo -e "${CYAN}Network Interface Stats:${NC}"
            netstat -ib
            sleep 5
        done
        ;;
    10)
        echo -e "${GREEN}Showing disk usage and I/O...${NC}"
        echo ""
        echo -e "${CYAN}Disk Usage:${NC}"
        df -h
        echo ""
        echo -e "${CYAN}Top Disk Space Users:${NC}"
        du -sh /* 2>/dev/null | sort -rh | head -10
        echo ""
        echo -e "${CYAN}Disk I/O Statistics (iostat):${NC}"
        iostat -d 2 5
        ;;
    11)
        echo -e "${GREEN}Showing top processes...${NC}"
        echo "Press Ctrl+C to exit"
        top -o cpu
        ;;
    12)
        echo -e "${GREEN}Showing firewall logs...${NC}"
        echo "Press Ctrl+C to exit"
        log show --predicate 'process == "socketfilterfw"' --style syslog --last 1h | tail -f
        ;;
    0)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo -e "${YELLOW}Invalid choice${NC}"
        ;;
esac
EOF
    
    chmod +x "$TAIL_LOGS_SCRIPT"
    log_info "Created tail_logs.sh at $TAIL_LOGS_SCRIPT"
}

################################################################################
# Main execution
################################################################################
main() {
    log_info "Starting Mac Mini Server provisioning..."
    log_info "Running on: $(sw_vers -productName) $(sw_vers -productVersion)"
    
    # Check if running on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "This script is designed for macOS only"
        exit 1
    fi
    
    # Install Homebrew
    install_homebrew
    
    # Install Docker
    install_docker
    
    # Install useful tools
    install_tools
    
    # Install GUI applications
    install_gui_apps
    
    # Install fonts
    install_fonts
    
    # Install and configure Oh My Zsh and Powerlevel10k
    install_oh_my_zsh
    
    # Configure Git
    configure_git
    
    # Configure iTerm2
    configure_iterm2
    
    # Configure sleep settings
    configure_sleep_settings
    
    # Configure system preferences
    configure_system_preferences
    
    # Configure Fail2ban
    configure_fail2ban
    
    # Configure log rotation
    configure_log_rotation
    
    # Setup Homebrew auto-update
    setup_brew_autoupdate
    
    # Enable SMB file sharing
    enable_smb_sharing
    
    # Configure firewall
    configure_firewall
    
    # Create tail_logs.sh script
    create_tail_logs_script
    
    log_info "Provisioning complete!"
    log_info ""
    log_info "Next steps:"
    log_info "1. Start Docker Desktop if not already running: open -a Docker"
    log_info "2. Test Docker: docker run hello-world"
    log_info "3. Run nginx in Docker: docker run -d -p 80:80 nginx"
    log_info "4. Configure Powerlevel10k: Run 'p10k configure' after opening a new terminal"
    log_info "5. View server logs: ./tail_logs.sh"
    log_info ""
    log_info "You can re-run this script at any time - it's idempotent!"
}

# Run main function
main
