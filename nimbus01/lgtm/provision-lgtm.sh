#!/bin/bash

################################################################################
# LGTM Stack Provisioning Script for Ubuntu/Linux
# Installs: Prometheus, node_exporter, Loki, Promtail, Grafana
# Idempotent - safe to run multiple times
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_section() {
    echo ""
    echo -e "${BLUE}==> $1${NC}"
}

################################################################################
# Write file with diff check and user confirmation
# Usage: check_and_write_file <file_path> <new_content> [sudo_required]
################################################################################
check_and_write_file() {
    local file_path="$1"
    local new_content="$2"
    local sudo_required="${3:-false}"
    
    if [ -f "$file_path" ]; then
        echo "$new_content" > /tmp/provision_new_file
        
        # Check if files are identical
        if diff -q "$file_path" /tmp/provision_new_file > /dev/null 2>&1; then
            log_info "File already exists and is up-to-date: $file_path"
            rm -f /tmp/provision_new_file
            return 0
        fi
        
        # Files differ, show diff and prompt
        log_warn "File already exists: $file_path"
        log_info "Showing diff (existing vs new):"
        echo "----------------------------------------"
        diff -u "$file_path" /tmp/provision_new_file || true
        echo "----------------------------------------"
        
        read -r -p "$(echo -e "${YELLOW}Overwrite this file? [y/N]: ${NC}")" response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            if [ "$sudo_required" = "true" ]; then
                echo "$new_content" | sudo tee "$file_path" > /dev/null
            else
                echo "$new_content" > "$file_path"
            fi
            log_info "File updated: $file_path"
        else
            log_info "Skipped: $file_path"
        fi
        rm -f /tmp/provision_new_file
    else
        # Create parent directory if needed
        local parent_dir
        parent_dir=$(dirname "$file_path")
        if [ ! -d "$parent_dir" ]; then
            if [ "$sudo_required" = "true" ]; then
                sudo mkdir -p "$parent_dir"
            else
                mkdir -p "$parent_dir"
            fi
        fi
        
        if [ "$sudo_required" = "true" ]; then
            echo "$new_content" | sudo tee "$file_path" > /dev/null
        else
            echo "$new_content" > "$file_path"
        fi
        log_info "File created: $file_path"
    fi
}

################################################################################
# Check if running with sudo
################################################################################
check_sudo() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "This script must be run with sudo"
        exit 1
    fi
}

################################################################################
# Add Grafana APT repository
################################################################################
add_grafana_repo() {
    log_section "Adding Grafana APT repository..."
    
    local gpg_key="/usr/share/keyrings/grafana.gpg"
    local repo_file="/etc/apt/sources.list.d/grafana.list"
    
    # Check if already configured
    if [ -f "$repo_file" ] && [ -f "$gpg_key" ]; then
        log_info "Grafana repository already configured"
        return
    fi
    
    # Install prerequisites
    apt-get install -y apt-transport-https software-properties-common wget
    
    # Add GPG key
    log_info "Adding Grafana GPG key..."
    wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor > "$gpg_key"
    
    # Add repository
    log_info "Adding Grafana repository..."
    echo "deb [signed-by=$gpg_key] https://apt.grafana.com stable main" > "$repo_file"
    
    log_info "Grafana repository added"
}

################################################################################
# Install packages
################################################################################
install_packages() {
    log_section "Installing packages..."
    
    apt-get update
    
    # Ubuntu repo packages
    log_info "Installing Prometheus and node_exporter..."
    apt-get install -y prometheus prometheus-node-exporter
    
    log_info "Installing lm-sensors..."
    apt-get install -y lm-sensors
    
    # Grafana repo packages
    log_info "Installing Loki, Promtail, and Grafana..."
    apt-get install -y loki promtail grafana
    
    log_info "All packages installed"
}

################################################################################
# Configure Prometheus
################################################################################
configure_prometheus() {
    log_section "Configuring Prometheus..."
    
    local config_file="/etc/prometheus/prometheus.yml"
    local defaults_file="/etc/default/prometheus"
    
    # APT package already includes node_exporter scrape target, no need to add
    if grep -q "job_name.*node" "$config_file" 2>/dev/null; then
        log_info "node_exporter scrape target already configured (APT default)"
    else
        log_info "Adding node_exporter scrape target..."
        cat >> "$config_file" << 'EOF'

  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
EOF
        log_info "Added node_exporter scrape target"
    fi
    
    # Configure retention via defaults file
    local retention_content='ARGS="--storage.tsdb.retention.time=90d --storage.tsdb.retention.size=5GB"'
    
    check_and_write_file "$defaults_file" "$retention_content" true
}

################################################################################
# Configure node_exporter
################################################################################
configure_node_exporter() {
    log_section "Configuring node_exporter..."
    
    local defaults_file="/etc/default/prometheus-node-exporter"
    local node_exporter_content='ARGS="--collector.nvme"'
    
    check_and_write_file "$defaults_file" "$node_exporter_content" true
    
    # Run sensors-detect (non-interactive)
    log_info "Detecting hardware sensors..."
    if command -v sensors-detect &> /dev/null; then
        # Run in auto mode, accepting defaults
        yes "" | sensors-detect --auto 2>/dev/null || true
        log_info "Hardware sensors detected"
    else
        log_warn "sensors-detect not available"
    fi
}

################################################################################
# Configure Loki
################################################################################
configure_loki() {
    log_section "Configuring Loki..."
    
    local config_file="/etc/loki/config.yml"
    
    # Check if retention_period is already set in limits_config
    if grep -q "retention_period:" "$config_file" 2>/dev/null; then
        log_info "Loki retention already configured"
    else
        log_info "Enabling Loki retention (90d = 2160h)..."
        # Add retention_period to existing limits_config section
        sed -i '/^limits_config:$/a\  retention_period: 2160h' "$config_file"
        log_info "Added retention_period to limits_config"
    fi
    
    # Check if compactor with retention is configured
    if grep -q "retention_enabled.*true" "$config_file" 2>/dev/null; then
        log_info "Loki compactor retention already enabled"
    else
        log_info "Adding compactor config for retention..."
        cat >> "$config_file" << 'EOF'

compactor:
  working_directory: /tmp/loki/compactor
  delete_request_store: filesystem
  retention_enabled: true
EOF
        log_info "Compactor retention configured"
    fi
}

################################################################################
# Configure Promtail
################################################################################
configure_promtail() {
    log_section "Configuring Promtail..."
    
    local config_file="/etc/promtail/config.yml"
    
    # Add promtail user to required groups for journal and log access
    log_info "Adding promtail user to systemd-journal and adm groups..."
    usermod -aG systemd-journal,adm promtail 2>/dev/null || true
    
    # Write Promtail config with journald scraping
    local promtail_content
    read -r -d '' promtail_content << 'EOF' || true
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push

scrape_configs:
  # Scrape journald logs
  - job_name: journal
    journal:
      max_age: 12h
      labels:
        job: systemd-journal
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        target_label: 'unit'
      - source_labels: ['__journal__hostname']
        target_label: 'hostname'
      - source_labels: ['__journal_syslog_identifier']
        target_label: 'syslog_identifier'
      - source_labels: ['__journal_priority_keyword']
        target_label: 'level'

  # Also scrape traditional log files
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*.log
EOF
    
    check_and_write_file "$config_file" "$promtail_content" true
}

################################################################################
# Configure Grafana datasources
################################################################################
configure_grafana() {
    log_section "Configuring Grafana..."
    
    local datasources_dir="/etc/grafana/provisioning/datasources"
    local datasources_file="$datasources_dir/lgtm.yml"
    
    # Ensure directory exists
    mkdir -p "$datasources_dir"
    
    local datasources_content
    read -r -d '' datasources_content << 'EOF' || true
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    url: http://localhost:9090
    isDefault: true
    editable: false
    
  - name: Loki
    type: loki
    url: http://localhost:3100
    editable: false
EOF
    
    check_and_write_file "$datasources_file" "$datasources_content" true
    
    # Set permissions
    chown grafana:grafana "$datasources_file" 2>/dev/null || true
    chmod 640 "$datasources_file" 2>/dev/null || true
}

################################################################################
# Enable and start services
################################################################################
start_services() {
    log_section "Enabling and starting services..."
    
    local services=("prometheus" "prometheus-node-exporter" "loki" "promtail" "grafana-server")
    
    systemctl daemon-reload
    
    for service in "${services[@]}"; do
        log_info "Enabling $service..."
        systemctl enable "$service"
        
        log_info "Starting $service..."
        systemctl restart "$service"
        
        # Wait briefly for service to start
        sleep 1
        
        if systemctl is-active --quiet "$service"; then
            log_info "$service is running"
        else
            log_warn "$service may not have started correctly"
        fi
    done
}

################################################################################
# Verify installation
################################################################################
verify_installation() {
    log_section "Verifying installation..."
    
    local all_ok=true
    
    # Check Prometheus
    if curl -s http://localhost:9090/-/healthy | grep -q "Healthy"; then
        echo -e "${GREEN}✓${NC} Prometheus is healthy"
    else
        echo -e "${RED}✗${NC} Prometheus is not responding"
        all_ok=false
    fi
    
    # Check node_exporter
    if curl -s http://localhost:9100/metrics | head -1 | grep -q "HELP"; then
        echo -e "${GREEN}✓${NC} node_exporter is serving metrics"
    else
        echo -e "${RED}✗${NC} node_exporter is not responding"
        all_ok=false
    fi
    
    # Check Loki
    if curl -s http://localhost:3100/ready | grep -q "ready"; then
        echo -e "${GREEN}✓${NC} Loki is ready"
    else
        echo -e "${RED}✗${NC} Loki is not responding"
        all_ok=false
    fi
    
    # Check Grafana
    if curl -s http://localhost:3000/api/health | grep -q "ok"; then
        echo -e "${GREEN}✓${NC} Grafana is healthy"
    else
        echo -e "${RED}✗${NC} Grafana is not responding"
        all_ok=false
    fi
    
    echo ""
    if [ "$all_ok" = true ]; then
        log_info "All services are running correctly!"
    else
        log_warn "Some services may need attention"
    fi
}

################################################################################
# Print summary
################################################################################
print_summary() {
    log_section "Installation Complete!"
    
    echo ""
    echo "Services:"
    echo "  Prometheus:     http://localhost:9090"
    echo "  node_exporter:  http://localhost:9100/metrics"
    echo "  Loki:           http://localhost:3100"
    echo "  Grafana:        http://localhost:3000"
    echo ""
    echo "Grafana default login: admin / admin"
    echo ""
    echo "Useful commands:"
    echo "  ./manage-lgtm.sh status    # Check all services"
    echo "  ./manage-lgtm.sh logs      # View logs"
    echo ""
}

################################################################################
# Main
################################################################################
main() {
    echo "========================================"
    echo "  LGTM Stack Provisioning"
    echo "  Prometheus + Loki + Grafana"
    echo "========================================"
    
    check_sudo
    
    add_grafana_repo
    install_packages
    configure_prometheus
    configure_node_exporter
    configure_loki
    configure_promtail
    configure_grafana
    start_services
    
    # Wait for services to fully start
    log_info "Waiting for services to initialize..."
    sleep 5
    
    verify_installation
    print_summary
}

# Run main
main "$@"
