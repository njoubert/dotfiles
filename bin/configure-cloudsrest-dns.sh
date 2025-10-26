#!/bin/bash

################################################################################
# Configure DNS Resolver for cloudsrest domain
# 
# This script configures macOS to use a custom DNS server (10.0.0.1)
# for resolving *.cloudsrest domains.
#
# Usage: ./configure-cloudsrest-dns.sh
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
# Main execution
################################################################################

log_info "Configuring DNS resolver for cloudsrest domain..."

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    log_error "This script is designed for macOS only"
    exit 1
fi

# Create resolver directory if it doesn't exist
log_info "Creating /etc/resolver directory..."
sudo mkdir -p /etc/resolver

# Configure resolver for cloudsrest domain
if [ -f /etc/resolver/cloudsrest ]; then
    EXISTING_NS=$(cat /etc/resolver/cloudsrest 2>/dev/null | grep nameserver | awk '{print $2}')
    if [ "$EXISTING_NS" = "10.0.0.1" ]; then
        log_info "DNS resolver for cloudsrest already configured correctly"
    else
        log_warn "DNS resolver for cloudsrest exists but with different nameserver: $EXISTING_NS"
        log_info "Updating to use 10.0.0.1..."
        echo "nameserver 10.0.0.1" | sudo tee /etc/resolver/cloudsrest > /dev/null
        log_info "DNS resolver updated"
    fi
else
    log_info "Creating DNS resolver configuration for cloudsrest..."
    echo "nameserver 10.0.0.1" | sudo tee /etc/resolver/cloudsrest > /dev/null
    log_info "DNS resolver configured to use 10.0.0.1 for *.cloudsrest"
fi

# Display current configuration
log_info ""
log_info "Current configuration:"
cat /etc/resolver/cloudsrest

# Flush DNS cache
log_info ""
log_info "Flushing DNS cache..."
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder 2>/dev/null || true
log_info "DNS cache flushed"

log_info ""
log_info "✓ Configuration complete!"
log_info ""
log_info "All *.cloudsrest domains will now be resolved using DNS server at 10.0.0.1"
log_info ""
log_info "To test: ping test.cloudsrest"
