#!/bin/bash
#
# Static Site Provisioning Script
# 
# This script deploys a static website with HTTPS via Caddy + Cloudflare DNS
#
# Usage: bash provision_static_site.sh <domain> [email] [public_dir]
#
# Example: bash provision_static_site.sh nimbus.wtf njoubert@gmail.com
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

# Check arguments
if [[ $# -lt 1 ]]; then
    error "Usage: $0 <domain> [email] [public_dir]"
    echo ""
    echo "Arguments:"
    echo "  domain      - Domain name (e.g., nimbus.wtf)"
    echo "  email       - Email for Let's Encrypt (default: njoubert@gmail.com)"
    echo "  public_dir  - Path to static files (optional, creates placeholder if not provided)"
    echo ""
    echo "Example:"
    echo "  $0 nimbus.wtf"
    echo "  $0 nimbus.wtf njoubert@gmail.com /path/to/site"
    exit 1
fi

DOMAIN="$1"
EMAIL="${2:-njoubert@gmail.com}"
SOURCE_DIR="${3:-}"
USERNAME=$(whoami)
SITE_DIR="$HOME/webserver/sites/$DOMAIN"
PUBLIC_DIR="$SITE_DIR/public"
CADDYFILE="/usr/local/etc/Caddyfile"

log "========================================="
log "Static Site Provisioning"
log "========================================="
echo ""
log "Domain: $DOMAIN"
log "Email: $EMAIL"
log "Site directory: $SITE_DIR"
if [[ -n "$SOURCE_DIR" ]]; then
    log "Source files: $SOURCE_DIR"
else
    log "Source files: Creating placeholder"
fi
echo ""

#==============================================================================
# Step 1: Create Site Directory
#==============================================================================

log "Step 1: Create site directory structure"
echo ""

if [[ -d "$PUBLIC_DIR" ]]; then
    warning "Directory $PUBLIC_DIR already exists"
    
    if [[ -n "$(ls -A $PUBLIC_DIR)" ]]; then
        warning "Directory is not empty. Files will not be overwritten."
    fi
else
    mkdir -p "$PUBLIC_DIR"
    success "Created $PUBLIC_DIR"
fi

#==============================================================================
# Step 2: Install Static Files
#==============================================================================

log "Step 2: Install static files"
echo ""

if [[ -n "$SOURCE_DIR" ]]; then
    # Copy files from source directory
    if [[ ! -d "$SOURCE_DIR" ]]; then
        error "Source directory does not exist: $SOURCE_DIR"
        exit 1
    fi
    
    log "Copying files from $SOURCE_DIR..."
    cp -r "$SOURCE_DIR/"* "$PUBLIC_DIR/"
    success "Copied static files to $PUBLIC_DIR"
    
else
    # Create placeholder index.html
    INDEX_FILE="$PUBLIC_DIR/index.html"
    
    if [[ -f "$INDEX_FILE" ]]; then
        warning "index.html already exists, skipping placeholder creation"
    else
        log "Creating placeholder index.html..."
        
        cat > "$INDEX_FILE" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Welcome</title>
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
    <h1>🚀 Site Coming Soon</h1>
    <p>This site is under construction.</p>
    <p><small>Served securely with Caddy + Let's Encrypt</small></p>
</body>
</html>
EOF
        
        success "Created placeholder index.html"
        log "Replace this with your actual site content at: $PUBLIC_DIR"
    fi
fi

# Show what's in the public directory
log "Public directory contents:"
ls -lh "$PUBLIC_DIR" | tail -n +2 || echo "Empty directory"
echo ""

#==============================================================================
# Step 3: Update Caddyfile
#==============================================================================

log "Step 3: Update Caddyfile"
echo ""

# Backup existing Caddyfile
BACKUP_FILE="$CADDYFILE.backup.$(date +%Y%m%d_%H%M%S)"
log "Creating backup: $BACKUP_FILE"
sudo cp "$CADDYFILE" "$BACKUP_FILE"
success "Backup created"

# Check if domain already exists in Caddyfile
if sudo grep -q "^$DOMAIN" "$CADDYFILE" 2>/dev/null || sudo grep -q "^$DOMAIN," "$CADDYFILE" 2>/dev/null; then
    error "Domain $DOMAIN already exists in Caddyfile!"
    log "Check $CADDYFILE and remove the existing entry if you want to update it."
    exit 1
fi

# Generate new Caddyfile with the additional site
TEMP_CADDYFILE=$(mktemp)

log "Generating updated Caddyfile..."

cat > "$TEMP_CADDYFILE" << EOF
{
    email $EMAIL
    # Cloudflare DNS challenge for automatic certs
    acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}
}

# Production site - $DOMAIN
$DOMAIN, www.$DOMAIN {
    root * $PUBLIC_DIR
    file_server
    encode gzip
    
    # Rate limiting
    rate_limit {
        zone static {
            key {remote_host}
            events 100
            window 1m
        }
    }
    
    # Security headers
    header {
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
    
    # Cache static assets
    @static {
        path *.css *.js *.jpg *.jpeg *.png *.gif *.ico *.svg *.woff *.woff2
    }
    header @static Cache-Control "public, max-age=31536000, immutable"
    
    log {
        output file /usr/local/var/log/caddy/$DOMAIN.log
    }
}

EOF

# Append any other sites from the existing Caddyfile (except the global block and :80 catch-all)
log "Preserving other site configurations..."

# Extract other site blocks (skip global block and :80 block)
sudo awk '
    /^{/ { in_global=1; next }
    in_global && /^}/ { in_global=0; next }
    in_global { next }
    /^:80/ { in_catchall=1 }
    in_catchall && /^}/ { in_catchall=0; next }
    in_catchall { next }
    { print }
' "$CADDYFILE" >> "$TEMP_CADDYFILE"

# Add catch-all :80 block at the end
cat >> "$TEMP_CADDYFILE" << 'EOF'

# Catch-all for testing (responds to direct IP access)
:80 {
    root * /Users/njoubert/webserver/sites/hello/public
    file_server
    
    log {
        output file /usr/local/var/log/caddy/access.log
    }
}
EOF

# Install new Caddyfile
sudo cp "$TEMP_CADDYFILE" "$CADDYFILE"
rm "$TEMP_CADDYFILE"
success "Updated Caddyfile"

# Show the new site block
log "New site configuration:"
echo ""
sudo sed -n "/^$DOMAIN/,/^}/p" "$CADDYFILE"
echo ""

#==============================================================================
# Step 4: Validate and Reload Caddy
#==============================================================================

log "Step 4: Validate and reload Caddy"
echo ""

# Validate Caddyfile syntax
log "Validating Caddyfile syntax..."
VALIDATION_OUTPUT=$(caddy validate --config "$CADDYFILE" 2>&1)
if echo "$VALIDATION_OUTPUT" | grep -q "Valid configuration"; then
    success "✅ Caddyfile syntax is valid"
else
    error "Caddyfile syntax validation failed!"
    log "Restoring backup..."
    sudo cp "$BACKUP_FILE" "$CADDYFILE"
    log "Validation output:"
    echo "$VALIDATION_OUTPUT"
    exit 1
fi

# Reload Caddy
log "Reloading Caddy configuration..."
if ~/webserver/scripts/manage-caddy.sh reload > /dev/null 2>&1; then
    success "✅ Caddy reloaded successfully"
else
    error "Caddy reload failed!"
    log "Restoring backup..."
    sudo cp "$BACKUP_FILE" "$CADDYFILE"
    ~/webserver/scripts/manage-caddy.sh reload
    exit 1
fi

echo ""
log "Waiting for Caddy to initialize the site..."
sleep 3

#==============================================================================
# Step 5: Test the Site
#==============================================================================

log "Step 5: Test the site"
echo ""

# Test HTTP redirect
log "Testing HTTP redirect..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -L http://$DOMAIN 2>/dev/null || echo "000")
if [[ "$HTTP_STATUS" == "308" ]] || [[ "$HTTP_STATUS" == "301" ]] || [[ "$HTTP_STATUS" == "200" ]]; then
    success "✅ HTTP redirect working (status: $HTTP_STATUS)"
else
    warning "HTTP test returned status: $HTTP_STATUS (may need DNS propagation)"
fi

# Test HTTPS
log "Testing HTTPS access..."
log "Note: Certificate provisioning may take 10-30 seconds on first access..."
sleep 5

HTTPS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN 2>/dev/null || echo "000")
if [[ "$HTTPS_STATUS" == "200" ]]; then
    success "✅ HTTPS working (status: 200)"
    
    # Show content preview
    log "Content preview:"
    curl -s https://$DOMAIN | head -5
    echo ""
    
else
    warning "HTTPS test returned status: $HTTPS_STATUS"
    log "This may be normal if:"
    log "  - DNS hasn't propagated yet"
    log "  - Certificate is still being provisioned"
    log "  - Domain doesn't resolve to this server"
    echo ""
    log "Check Caddy logs: tail -f /usr/local/var/log/caddy/$DOMAIN.log"
fi

# Check for certificate
log "Checking for SSL certificate..."
sleep 2
CERT_DIR="$HOME/Library/Application Support/Caddy/certificates/acme-v02.api.letsencrypt.org-directory"
if [[ -d "$CERT_DIR" ]] && find "$CERT_DIR" -name "*$DOMAIN*" 2>/dev/null | grep -q .; then
    success "✅ SSL certificate provisioned"
    
    # Show certificate details
    log "Certificate files:"
    find "$CERT_DIR" -name "*$DOMAIN*" 2>/dev/null
else
    warning "SSL certificate not yet found"
    log "Certificate will be provisioned on first HTTPS request"
    log "Check logs: ~/webserver/scripts/manage-caddy.sh logs error"
fi

echo ""

#==============================================================================
# Summary
#==============================================================================

log "========================================="
log "Static Site Deployment Complete!"
log "========================================="
echo ""
success "Domain: $DOMAIN"
success "Public directory: $PUBLIC_DIR"
success "Log file: /usr/local/var/log/caddy/$DOMAIN.log"
echo ""
log "Next steps:"
log "  1. Verify DNS points to this server:"
log "     dig $DOMAIN +short"
log ""
log "  2. Test in browser:"
log "     https://$DOMAIN"
log "     https://www.$DOMAIN"
log ""
log "  3. Upload your site content to:"
log "     $PUBLIC_DIR"
log ""
log "  4. Monitor logs:"
log "     tail -f /usr/local/var/log/caddy/$DOMAIN.log"
log "     ~/webserver/scripts/manage-caddy.sh logs error"
echo ""
log "Backups:"
log "  Caddyfile backup: $BACKUP_FILE"
echo ""
