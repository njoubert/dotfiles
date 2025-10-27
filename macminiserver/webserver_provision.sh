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
# Main execution
#==============================================================================

main() {
    phase_1_1_install_caddy
    
    log "========================================="
    log "Provisioning complete!"
    log "========================================="
    echo ""
    log "Next steps:"
    log "  - Continue with Phase 1.2 in the implementation guide"
    log "  - Add additional phases to this script as you progress"
    echo ""
}

# Run main function
main
