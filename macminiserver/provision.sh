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
# Install Xcode Command Line Tools
################################################################################
install_xcode_tools() {
    log_info "Checking for Xcode Command Line Tools..."
    
    # Check if command line tools are already installed
    if xcode-select -p &> /dev/null; then
        log_info "Xcode Command Line Tools already installed at $(xcode-select -p)"
    else
        log_info "Installing Xcode Command Line Tools..."
        # This will prompt the user with a GUI dialog
        xcode-select --install
        log_info "Xcode Command Line Tools installation initiated"
        log_warn "Please complete the installation in the dialog box"
        log_warn "The script will continue once installation is complete..."
        
        # Wait for installation to complete
        until xcode-select -p &> /dev/null; do
            sleep 5
        done
        
        log_info "Xcode Command Line Tools installed successfully"
    fi
    
    # Accept the license if needed
    if ! sudo xcodebuild -license check &> /dev/null; then
        log_info "Accepting Xcode license..."
        sudo xcodebuild -license accept 2>/dev/null || {
            log_warn "Could not auto-accept Xcode license"
            log_warn "You may need to run: sudo xcodebuild -license accept"
        }
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
        "fzf"
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
        "visual-studio-code"
        "betterdisplay"
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
# Configure Zsh
################################################################################
configure_zsh() {
    log_info "Configuring Zsh..."
    
    # Get the directory where this script is located
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    ZSHRC_SOURCE="$SCRIPT_DIR/dotfiles/zshrc"
    
    if [ -f "$ZSHRC_SOURCE" ]; then
        # Backup existing .zshrc if it exists and is different
        if [ -f "$HOME/.zshrc" ]; then
            if ! cmp -s "$ZSHRC_SOURCE" "$HOME/.zshrc"; then
                cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
                log_info "Backed up existing .zshrc"
            fi
        fi
        
        # Copy zshrc to home directory
        cp "$ZSHRC_SOURCE" "$HOME/.zshrc"
        log_info "Zsh configuration installed to ~/.zshrc"
    else
        log_warn "zshrc not found at $ZSHRC_SOURCE"
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
    
    # Set vim as the default editor
    git config --global core.editor "vim"
    log_info "Git editor set to vim"
    
    # Set some useful defaults
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    log_info "Git configuration complete"
}

################################################################################
# Setup SSH keys
################################################################################
setup_ssh_keys() {
    log_info "Setting up SSH keys..."
    
    SSH_DIR="$HOME/.ssh"
    SSH_KEY="$SSH_DIR/id_ed25519"
    
    # Create .ssh directory if it doesn't exist
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    
    # Generate SSH key if it doesn't exist
    if [ ! -f "$SSH_KEY" ]; then
        log_info "Generating new SSH key..."
        ssh-keygen -t ed25519 -C "njoubert@macminiserver" -f "$SSH_KEY" -N ""
        log_info "SSH key generated at $SSH_KEY"
    else
        log_info "SSH key already exists at $SSH_KEY"
    fi
    
    # Ensure proper permissions
    chmod 600 "$SSH_KEY"
    chmod 644 "$SSH_KEY.pub"
    
    # Display the public key
    log_info ""
    log_info "=========================================="
    log_info "Your SSH Public Key:"
    log_info "=========================================="
    cat "$SSH_KEY.pub"
    log_info "=========================================="
    log_info ""
    log_info "To use this key on other servers:"
    log_info "1. Copy the public key above"
    log_info "2. On the remote server, add it to ~/.ssh/authorized_keys"
    log_info "3. Or use: ssh-copy-id -i $SSH_KEY.pub user@remote-host"
    log_info ""
    log_info "If you get 'Too many authentication failures' when connecting:"
    log_info "  ssh -o IdentitiesOnly=yes -i $SSH_KEY user@host"
    log_info "  or add to ~/.ssh/config on your client:"
    log_info "    Host macminiserver.local"
    log_info "      IdentitiesOnly yes"
    log_info "      IdentityFile ~/.ssh/id_ed25519"
    log_info ""
    
    # Prompt user to add their own key for logging into this server
    log_info "=========================================="
    log_warn "IMPORTANT: Add your own SSH key to login to this server"
    log_info "=========================================="
    log_info ""
    log_info "To allow SSH login from your other machines:"
    log_info "1. On your LOCAL machine, display your public key:"
    log_info "   cat ~/.ssh/id_ed25519.pub  (or id_rsa.pub)"
    log_info "2. Copy that public key"
    log_info "3. Paste it here when prompted (or press Enter to skip)"
    log_info ""
    
    read -p "Paste your SSH public key (or press Enter to skip): " user_pubkey
    
    if [ -n "$user_pubkey" ]; then
        AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"
        
        # Check if key already exists
        if grep -Fxq "$user_pubkey" "$AUTHORIZED_KEYS" 2>/dev/null; then
            log_info "Key already exists in authorized_keys"
        else
            echo "$user_pubkey" >> "$AUTHORIZED_KEYS"
            chmod 600 "$AUTHORIZED_KEYS"
            log_info "SSH key added to $AUTHORIZED_KEYS"
            log_info "You should now be able to SSH into this server!"
        fi
    else
        log_warn "No key provided. You can add it later with:"
        log_warn "  echo 'YOUR_PUBLIC_KEY' >> ~/.ssh/authorized_keys"
        log_warn "  chmod 600 ~/.ssh/authorized_keys"
    fi
    
    log_info ""
}

################################################################################
# Configure Vim
################################################################################
configure_vim() {
    log_info "Configuring Vim..."
    
    # Get the directory where this script is located
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    VIMRC_SOURCE="$SCRIPT_DIR/dotfiles/vimrc"
    
    if [ -f "$VIMRC_SOURCE" ]; then
        # Copy vimrc to home directory
        cp "$VIMRC_SOURCE" "$HOME/.vimrc"
        log_info "Vim configuration installed to ~/.vimrc"
    else
        log_warn "vimrc not found at $VIMRC_SOURCE"
    fi
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
        
        # Copy font files
        local font_count=0
        if ls "$FONT_SOURCE"/*.ttf 1> /dev/null 2>&1; then
            cp -f "$FONT_SOURCE"/*.ttf "$FONT_DEST/" 2>/dev/null && ((font_count++)) || true
        fi
        if ls "$FONT_SOURCE"/*.otf 1> /dev/null 2>&1; then
            cp -f "$FONT_SOURCE"/*.otf "$FONT_DEST/" 2>/dev/null && ((font_count++)) || true
        fi
        
        if [ $font_count -gt 0 ]; then
            log_info "Menlo for Powerline Font installed to $FONT_DEST"
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
    
    if [ -f "$ITERM_PROFILE" ]; then
        # iTerm2 stores preferences as plist in ~/Library/Preferences
        # We need to import the JSON profile manually or convert it
        log_info "iTerm2 profile found at $ITERM_PROFILE"
        log_info "To import the profile:"
        log_info "  1. Open iTerm2"
        log_info "  2. Go to Settings > Profiles"
        log_info "  3. Click 'Other Actions...' > 'Import JSON Profiles...'"
        log_info "  4. Select: $ITERM_PROFILE"
        log_info ""
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
    
    # Configure SSH to allow more authentication attempts
    # This prevents "Too many authentication failures" when you have multiple SSH keys
    SSHD_CONFIG="/etc/ssh/sshd_config"
    SSH_NEEDS_RESTART=false
    
    if ! sudo grep -q "^MaxAuthTries" "$SSHD_CONFIG"; then
        log_info "Configuring SSH MaxAuthTries..."
        echo "MaxAuthTries 20" | sudo tee -a "$SSHD_CONFIG" > /dev/null
        log_info "SSH MaxAuthTries set to 20 (prevents 'Too many authentication failures' error)"
        SSH_NEEDS_RESTART=true
    else
        log_info "SSH MaxAuthTries already configured"
    fi
    
    # Prompt user about disabling password authentication
    log_info ""
    log_info "=========================================="
    log_info "SSH Security Configuration"
    log_info "=========================================="
    log_info "For enhanced security, password-based SSH authentication should be disabled."
    log_info "Only SSH key-based authentication will be allowed."
    log_warn "IMPORTANT: Make sure you have added your SSH public key to ~/.ssh/authorized_keys!"
    log_info ""
    
    # Check current state
    if sudo grep -q "^PasswordAuthentication no" "$SSHD_CONFIG" && \
       sudo grep -q "^ChallengeResponseAuthentication no" "$SSHD_CONFIG" && \
       sudo grep -q "^PubkeyAuthentication yes" "$SSHD_CONFIG"; then
        log_info "Password authentication is already disabled - SSH is configured for key-based auth only"
    else
        # Prompt user
        read -p "Do you want to disable password-based SSH logins? (y/n) [y]: " -n 1 -r
        echo
        REPLY=${REPLY:-y}  # Default to 'y' if user just presses Enter
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Disabling password-based SSH authentication..."
            
            # Disable password authentication
            if ! sudo grep -q "^PasswordAuthentication no" "$SSHD_CONFIG"; then
                # Remove any existing PasswordAuthentication lines (commented or not)
                sudo sed -i '' '/^#*PasswordAuthentication/d' "$SSHD_CONFIG"
                echo "PasswordAuthentication no" | sudo tee -a "$SSHD_CONFIG" > /dev/null
                log_info "✓ PasswordAuthentication disabled"
                SSH_NEEDS_RESTART=true
            else
                log_info "✓ PasswordAuthentication already disabled"
            fi
            
            # Disable challenge-response authentication
            if ! sudo grep -q "^ChallengeResponseAuthentication no" "$SSHD_CONFIG"; then
                sudo sed -i '' '/^#*ChallengeResponseAuthentication/d' "$SSHD_CONFIG"
                echo "ChallengeResponseAuthentication no" | sudo tee -a "$SSHD_CONFIG" > /dev/null
                log_info "✓ ChallengeResponseAuthentication disabled"
                SSH_NEEDS_RESTART=true
            else
                log_info "✓ ChallengeResponseAuthentication already disabled"
            fi
            
            # Ensure public key authentication is enabled
            if ! sudo grep -q "^PubkeyAuthentication yes" "$SSHD_CONFIG"; then
                sudo sed -i '' '/^#*PubkeyAuthentication/d' "$SSHD_CONFIG"
                echo "PubkeyAuthentication yes" | sudo tee -a "$SSHD_CONFIG" > /dev/null
                log_info "✓ PubkeyAuthentication enabled"
                SSH_NEEDS_RESTART=true
            else
                log_info "✓ PubkeyAuthentication already enabled"
            fi
            
            # Disable root login
            if ! sudo grep -q "^PermitRootLogin no" "$SSHD_CONFIG"; then
                sudo sed -i '' '/^#*PermitRootLogin/d' "$SSHD_CONFIG"
                echo "PermitRootLogin no" | sudo tee -a "$SSHD_CONFIG" > /dev/null
                log_info "✓ Root login disabled"
                SSH_NEEDS_RESTART=true
            else
                log_info "✓ Root login already disabled"
            fi
            
            log_info "SSH configured for key-based authentication only"
            log_warn "Password-based SSH login is now DISABLED"
        else
            log_warn "Skipping SSH password authentication disabling"
            log_warn "Your server will still accept password-based SSH logins"
        fi
    fi
    
    # Restart SSH daemon if configuration changed
    if [ "$SSH_NEEDS_RESTART" = true ]; then
        log_info "Restarting SSH daemon to apply changes..."
        sudo launchctl kickstart -k system/com.openssh.sshd
        log_info "SSH daemon restarted"
    fi
    
    # Make the dock only show active apps
    defaults write com.apple.dock static-only -bool true
    killall Dock 2>/dev/null || true
    log_info "Dock configured to show only active apps"
    
    # Set keyboard repeat rate to maximum (fastest)
    # KeyRepeat: 2 is the fastest (15ms between repeats)
    # InitialKeyRepeat: 15 is the shortest delay before repeat starts (225ms)
    defaults write -g KeyRepeat -int 2
    defaults write -g InitialKeyRepeat -int 15
    
    # Also set in NSGlobalDomain to be sure
    defaults write NSGlobalDomain KeyRepeat -int 2
    defaults write NSGlobalDomain InitialKeyRepeat -int 15
    
    # Try to restart the relevant system service
    killall -u "$USER" cfprefsd 2>/dev/null || true
    
    log_info "Keyboard repeat rate set to maximum speed"
    log_warn "Note: Keyboard settings will fully apply after logout/login or restart"
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
bantime = 1800
findtime = 600
maxretry = 20

[sshd]
enabled = true
port = ssh
logpath = /var/log/system.log
EOF
        log_info "Fail2ban configuration created"
        log_info "Fail2ban: 20 failed attempts in 10 minutes = 30 minute ban"
    else
        log_info "Fail2ban configuration already exists"
    fi
    
    # Try to start fail2ban service if brew services is available
    if brew services list &> /dev/null; then
        brew services list | grep -q "fail2ban.*started" && {
            log_info "Fail2ban service already running"
        } || {
            log_info "Starting Fail2ban service (requires root)..."
            sudo brew services start fail2ban 2>/dev/null || {
                log_warn "Could not start fail2ban as a service"
                log_warn "You can start it manually with: sudo fail2ban-client start"
            }
        }
    else
        log_warn "brew services not available"
        log_info "To start fail2ban manually: sudo fail2ban-client start"
    fi
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
# Configure DNS resolver for local domain
################################################################################
configure_dns_resolver() {
    log_info "Configuring DNS resolver for cloudsrest domain..."
    
    # Create resolver directory if it doesn't exist
    sudo mkdir -p /etc/resolver
    
    # Configure resolver for cloudsrest domain
    if [ ! -f /etc/resolver/cloudsrest ]; then
        log_info "Creating DNS resolver configuration for cloudsrest..."
        echo "nameserver 10.0.0.1" | sudo tee /etc/resolver/cloudsrest > /dev/null
        log_info "DNS resolver configured to use 10.0.0.1 for *.cloudsrest"
    else
        log_info "DNS resolver for cloudsrest already configured"
    fi
    
    # Flush DNS cache
    log_info "Flushing DNS cache..."
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder 2>/dev/null || true
    log_info "DNS cache flushed"
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
    
    # disable stealth mode (respond to ping)
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode off
    log_info "Stealth mode disabled - respond to ping please"
    
    # Note: HTTP (80) and HTTPS (443) are typically handled by allowing specific apps
    # For Docker/nginx, the firewall will prompt or you can add rules for specific apps
    log_info "Note: HTTP/HTTPS traffic will be allowed through Docker and signed applications"
    log_info "To allow specific apps: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /path/to/app"
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
    
    # Install Xcode Command Line Tools
    install_xcode_tools
    
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
    
    # Configure Zsh
    configure_zsh
    
    # Configure Git
    configure_git
    
    # Setup SSH keys
    setup_ssh_keys
    
    # Configure Vim
    configure_vim
    
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
    
    # Configure DNS resolver
    configure_dns_resolver
    
    # Configure firewall
    configure_firewall
        
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
