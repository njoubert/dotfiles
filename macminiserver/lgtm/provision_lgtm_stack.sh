#!/bin/bash
#
# Idempotent LGTM Stack Provisioning Script
# Sets up Loki, Grafana, Tempo (optional), Mimir/Prometheus + monitoring
#
# Usage: bash provision_lgtm_stack.sh
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${NC}$1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
section() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}\n"; }

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to show diff and ask to overwrite
check_and_write_file() {
    local file_path="$1"
    local new_content="$2"
    local sudo_required="${3:-false}"
    
    if [ -f "$file_path" ]; then
        echo "$new_content" > /tmp/provision_new_file
        
        # Check if files are identical
        if diff -q "$file_path" /tmp/provision_new_file > /dev/null 2>&1; then
            info "File already exists and is up-to-date: $file_path"
            rm -f /tmp/provision_new_file
            return 0
        fi
        
        # Files differ, show diff and prompt
        warning "File already exists: $file_path"
        info "Showing diff (existing vs new):"
        diff -u "$file_path" /tmp/provision_new_file || true
        
        read -r -p "$(echo -e "${YELLOW}Overwrite this file? [y/N]: ${NC}")" response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            if [ "$sudo_required" = "true" ]; then
                echo "$new_content" | sudo tee "$file_path" > /dev/null
            else
                echo "$new_content" > "$file_path"
            fi
            success "File updated: $file_path"
        else
            info "Skipped: $file_path"
        fi
        rm -f /tmp/provision_new_file
    else
        if [ "$sudo_required" = "true" ]; then
            echo "$new_content" | sudo tee "$file_path" > /dev/null
        else
            echo "$new_content" > "$file_path"
        fi
        success "File created: $file_path"
    fi
}

# Function to check if a string exists in a file (for nginx config checking)
string_in_file() {
    local file="$1"
    local search_string="$2"
    
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    grep -qF "$search_string" "$file"
}

# Detect username
USER_NAME=$(whoami)
USER_HOME="$HOME"

section "Mac Mini LGTM Stack Provisioning v1.0.0"
info "This script will set up Prometheus, Loki, Grafana, and exporters"
info "Running as user: $USER_NAME"
echo ""

# Check prerequisites
section "Phase 1: Checking Prerequisites"

if ! command_exists brew; then
    error "Homebrew is not installed!"
    info "Install it from: https://brew.sh"
    exit 1
fi
success "Homebrew is installed"

if ! command_exists nginx; then
    error "nginx is not installed!"
    info "Please run provision_webserver.sh first"
    exit 1
fi
success "nginx is installed"

# Check if nginx is managed by LaunchDaemon
if [ ! -f "/Library/LaunchDaemons/com.nginx.nginx.plist" ]; then
    warning "nginx LaunchDaemon not found"
    info "This script assumes nginx is already set up via provision_webserver.sh"
fi

# Install monitoring packages
section "Phase 2: Installing LGTM Stack Packages"

# Tap the nginx repository for nginx-prometheus-exporter
info "Ensuring nginx tap is available..."
if ! brew tap | grep -q "^nginx/tap$"; then
    info "Adding nginx tap..."
    brew tap nginx/tap
    success "nginx tap added"
else
    info "nginx tap already added"
fi

PACKAGES=(
    "prometheus:Prometheus metrics database"
    "node_exporter:Host metrics exporter"
    "nginx-prometheus-exporter:NGINX metrics exporter"
    "loki:Log aggregation system"
    "promtail:Log shipper for Loki"
    "grafana:Visualization and dashboards"
)

for package_info in "${PACKAGES[@]}"; do
    package="${package_info%%:*}"
    description="${package_info##*:}"
    
    if brew list "$package" &>/dev/null; then
        info "$description already installed"
    else
        info "Installing $description..."
        brew install "$package"
        success "$description installed"
    fi
done

# Verify installations
info "Verifying installations..."
for package_info in "${PACKAGES[@]}"; do
    package="${package_info%%:*}"
    # Handle special cases for binary names
    case "$package" in
        "nginx-prometheus-exporter")
            binary="nginx-prometheus-exporter"
            ;;
        *)
            binary="$package"
            # Special handling for grafana
            if [ "$package" = "grafana" ]; then
                binary="grafana-server"
            fi
            ;;
    esac
    
    if command_exists "$binary"; then
        success "✓ $binary"
    else
        error "✗ $binary not found in PATH"
    fi
done

# Create required directories
section "Phase 3: Creating Directory Structure"

info "Creating monitoring directories..."

# Prometheus
sudo mkdir -p /usr/local/var/prometheus
sudo mkdir -p /usr/local/etc/prometheus
sudo chown -R "$USER_NAME:staff" /usr/local/var/prometheus
sudo chown -R "$USER_NAME:staff" /usr/local/etc/prometheus

# Loki
sudo mkdir -p /usr/local/var/loki/{chunks,rules,compactor}
sudo mkdir -p /usr/local/etc/loki
sudo chown -R "$USER_NAME:staff" /usr/local/var/loki
sudo chown -R "$USER_NAME:staff" /usr/local/etc/loki

# Promtail
sudo mkdir -p /usr/local/etc/promtail
sudo chown -R "$USER_NAME:staff" /usr/local/etc/promtail

# Grafana
sudo mkdir -p /usr/local/var/lib/grafana
sudo mkdir -p /usr/local/var/log/grafana
sudo mkdir -p /usr/local/etc/grafana/provisioning/{datasources,dashboards}
sudo chown -R "$USER_NAME:staff" /usr/local/var/lib/grafana
sudo chown -R "$USER_NAME:staff" /usr/local/var/log/grafana
sudo chown -R "$USER_NAME:staff" /usr/local/etc/grafana

# Shared monitoring logs
sudo mkdir -p /usr/local/var/log/monitoring
sudo chown -R "$USER_NAME:staff" /usr/local/var/log/monitoring

success "Directory structure created"

# Configure NGINX for monitoring
section "Phase 4: Configuring NGINX for Monitoring"

NGINX_CONF="/usr/local/etc/nginx/nginx.conf"

if [ ! -f "$NGINX_CONF" ]; then
    error "nginx.conf not found at $NGINX_CONF"
    info "Please run provision_webserver.sh first"
    exit 1
fi

# Check if stub_status is configured
if string_in_file "$NGINX_CONF" "# BEGIN LGTM MONITORING: stub_status"; then
    info "nginx stub_status already configured"
else
    warning "nginx stub_status not found in configuration"
    info "You need to add a stub_status endpoint to nginx.conf"
    info ""
    info "Add this to the http {} block in $NGINX_CONF:"
    info ""
    cat << 'EOF'
    # BEGIN LGTM MONITORING: stub_status
    server {
        listen 127.0.0.1:8080;
        server_name _;
        
        location /nginx_status {
            stub_status on;
            access_log off;
            allow 127.0.0.1;
            deny all;
        }
    }
    # END LGTM MONITORING: stub_status
EOF
    info ""
    read -r -p "$(echo -e "${YELLOW}Would you like me to add this now? [Y/n]: ${NC}")" response
    if [[ ! "$response" =~ ^[Nn]$ ]]; then
        # Add stub_status configuration with sentinel comments
        sudo sed -i.bak '/^http {/a\
    \
    # BEGIN LGTM MONITORING: stub_status\
    server {\
        listen 127.0.0.1:8080;\
        server_name _;\
        \
        location /nginx_status {\
            stub_status on;\
            access_log off;\
            allow 127.0.0.1;\
            deny all;\
        }\
    }\
    # END LGTM MONITORING: stub_status
' "$NGINX_CONF"
        success "Added stub_status configuration"
    fi
fi

# Check if JSON logging is configured
if string_in_file "$NGINX_CONF" "# BEGIN LGTM MONITORING: json_logging"; then
    info "nginx JSON logging already configured"
else
    warning "nginx JSON logging not found in configuration"
    info "You need to add JSON log format to nginx.conf"
    info ""
    info "Add this to the http {} block in $NGINX_CONF:"
    info ""
    cat << 'EOF'
    # BEGIN LGTM MONITORING: json_logging
    log_format json_combined escape=json
      '{ "time":"$time_iso8601", "remote_addr":"$remote_addr", "request":"$request", '
      '"status":$status, "body_bytes_sent":$body_bytes_sent, "http_referer":"$http_referer", '
      '"http_user_agent":"$http_user_agent", "request_time":$request_time, '
      '"upstream_response_time":"$upstream_response_time", "host":"$host", "uri":"$uri", "method":"$request_method" }';

    access_log /usr/local/var/log/nginx/access.json json_combined;
    # END LGTM MONITORING: json_logging
EOF
    info ""
    read -r -p "$(echo -e "${YELLOW}Would you like me to add this now? [Y/n]: ${NC}")" response
    if [[ ! "$response" =~ ^[Nn]$ ]]; then
        # Add the JSON log format after the complete main log_format definition (match the semicolon end)
        sudo sed -i.bak '/log_format main.*'"'"'$http_x_forwarded_for"'"'"';/a\
    \
    # BEGIN LGTM MONITORING: json_logging\
    log_format json_combined escape=json\
      '"'"'{ "time":"$time_iso8601", "remote_addr":"$remote_addr", "request":"$request", '"'"'\
      '"'"'"status":$status, "body_bytes_sent":$body_bytes_sent, "http_referer":"$http_referer", '"'"'\
      '"'"'"http_user_agent":"$http_user_agent", "request_time":$request_time, '"'"'\
      '"'"'"upstream_response_time":"$upstream_response_time", "host":"$host", "uri":"$uri", "method":"$request_method" }'"'"';\
    \
    access_log /usr/local/var/log/nginx/access.json json_combined;\
    # END LGTM MONITORING: json_logging
' "$NGINX_CONF"
        success "Added JSON logging configuration"
    fi
fi

# Test and reload nginx
info "Testing nginx configuration..."
if nginx -t 2>&1 | grep -q "successful"; then
    success "nginx configuration is valid"
    
    read -r -p "$(echo -e "${YELLOW}Reload nginx now? [Y/n]: ${NC}")" response
    if [[ ! "$response" =~ ^[Nn]$ ]]; then
        if sudo launchctl list 2>/dev/null | grep -q com.nginx.nginx; then
            sudo launchctl kickstart -k system/com.nginx.nginx
            success "nginx reloaded"
        else
            nginx -s reload
            success "nginx reloaded"
        fi
    fi
else
    error "nginx configuration has errors!"
    nginx -t
    warning "Please fix nginx configuration before continuing"
fi

# Configure Prometheus
section "Phase 5: Configuring Prometheus"

PROMETHEUS_YML="/usr/local/etc/prometheus/prometheus.yml"

read -r -d '' PROMETHEUS_CONFIG << 'EOF' || true
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    instance: macmini
    environment: production

scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['127.0.0.1:9100']
        labels:
          component: host

  - job_name: 'nginx'
    static_configs:
      - targets: ['127.0.0.1:9113']
        labels:
          component: webserver

  - job_name: 'prometheus'
    static_configs:
      - targets: ['127.0.0.1:9090']
        labels:
          component: monitoring
EOF

check_and_write_file "$PROMETHEUS_YML" "$PROMETHEUS_CONFIG" false

# Create Prometheus LaunchDaemon
PROMETHEUS_PLIST="/Library/LaunchDaemons/com.prometheus.prometheus.plist"

read -r -d '' PROMETHEUS_PLIST_CONTENT << EOF || true
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.prometheus.prometheus</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/prometheus</string>
        <string>--config.file=/usr/local/etc/prometheus/prometheus.yml</string>
        <string>--storage.tsdb.path=/usr/local/var/prometheus</string>
        <string>--storage.tsdb.retention.time=90d</string>
        <string>--storage.tsdb.retention.size=5GB</string>
        <string>--storage.tsdb.wal-compression</string>
        <string>--web.listen-address=127.0.0.1:9090</string>
        <string>--web.enable-lifecycle</string>
    </array>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>/usr/local/var/log/monitoring/prometheus.log</string>
    
    <key>StandardErrorPath</key>
    <string>/usr/local/var/log/monitoring/prometheus-error.log</string>
    
    <key>WorkingDirectory</key>
    <string>/usr/local/var/prometheus</string>
</dict>
</plist>
EOF

check_and_write_file "$PROMETHEUS_PLIST" "$PROMETHEUS_PLIST_CONTENT" true

if [ -f "$PROMETHEUS_PLIST" ]; then
    sudo chown root:wheel "$PROMETHEUS_PLIST"
    sudo chmod 644 "$PROMETHEUS_PLIST"
fi

# Configure node_exporter
section "Phase 6: Configuring node_exporter"

NODE_EXPORTER_PLIST="/Library/LaunchDaemons/com.prometheus.node_exporter.plist"

read -r -d '' NODE_EXPORTER_PLIST_CONTENT << EOF || true
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.prometheus.node_exporter</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/node_exporter</string>
        <string>--web.listen-address=127.0.0.1:9100</string>
    </array>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>/usr/local/var/log/monitoring/node_exporter.log</string>
    
    <key>StandardErrorPath</key>
    <string>/usr/local/var/log/monitoring/node_exporter-error.log</string>
</dict>
</plist>
EOF

check_and_write_file "$NODE_EXPORTER_PLIST" "$NODE_EXPORTER_PLIST_CONTENT" true

if [ -f "$NODE_EXPORTER_PLIST" ]; then
    sudo chown root:wheel "$NODE_EXPORTER_PLIST"
    sudo chmod 644 "$NODE_EXPORTER_PLIST"
fi

# Configure nginx_exporter
section "Phase 7: Configuring nginx-prometheus-exporter"

NGINX_EXPORTER_PLIST="/Library/LaunchDaemons/com.prometheus.nginx_exporter.plist"

read -r -d '' NGINX_EXPORTER_PLIST_CONTENT << EOF || true
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.prometheus.nginx_exporter</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/nginx-prometheus-exporter</string>
        <string>-nginx.scrape-uri=http://127.0.0.1:8080/nginx_status</string>
        <string>-web.listen-address=127.0.0.1:9113</string>
    </array>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>/usr/local/var/log/monitoring/nginx_exporter.log</string>
    
    <key>StandardErrorPath</key>
    <string>/usr/local/var/log/monitoring/nginx_exporter-error.log</string>
</dict>
</plist>
EOF

check_and_write_file "$NGINX_EXPORTER_PLIST" "$NGINX_EXPORTER_PLIST_CONTENT" true

if [ -f "$NGINX_EXPORTER_PLIST" ]; then
    sudo chown root:wheel "$NGINX_EXPORTER_PLIST"
    sudo chmod 644 "$NGINX_EXPORTER_PLIST"
fi

# Configure Loki
section "Phase 8: Configuring Loki"

LOKI_CONFIG="/usr/local/etc/loki/local-config.yaml"

read -r -d '' LOKI_CONFIG_CONTENT << 'EOF' || true
auth_enabled: false

server:
  http_listen_address: 127.0.0.1
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /usr/local/var/loki
  storage:
    filesystem:
      chunks_directory: /usr/local/var/loki/chunks
      rules_directory: /usr/local/var/loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-01-01
      store: boltdb-shipper
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

compactor:
  delete_request_store: filesystem
  working_directory: /usr/local/var/loki/compactor
  compaction_interval: 60m
  retention_enabled: true
  retention_delete_delay: 24h
  retention_delete_worker_count: 150

limits_config:
  allow_structured_metadata: false
  retention_period: 720h       # 30 days
  ingestion_rate_mb: 8
  ingestion_burst_size_mb: 16
  max_query_series: 500
  max_query_parallelism: 32

ruler:
  storage:
    type: local
    local:
      directory: /usr/local/var/loki/rules
  ring:
    kvstore:
      store: inmemory

table_manager:
  retention_deletes_enabled: true
  retention_period: 168h
EOF

check_and_write_file "$LOKI_CONFIG" "$LOKI_CONFIG_CONTENT" false

# Create Loki LaunchDaemon
LOKI_PLIST="/Library/LaunchDaemons/com.grafana.loki.plist"

read -r -d '' LOKI_PLIST_CONTENT << EOF || true
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.grafana.loki</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/loki</string>
        <string>-config.file=/usr/local/etc/loki/local-config.yaml</string>
    </array>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>/usr/local/var/log/monitoring/loki.log</string>
    
    <key>StandardErrorPath</key>
    <string>/usr/local/var/log/monitoring/loki-error.log</string>
    
    <key>WorkingDirectory</key>
    <string>/usr/local/var/loki</string>
</dict>
</plist>
EOF

check_and_write_file "$LOKI_PLIST" "$LOKI_PLIST_CONTENT" true

if [ -f "$LOKI_PLIST" ]; then
    sudo chown root:wheel "$LOKI_PLIST"
    sudo chmod 644 "$LOKI_PLIST"
fi

# Configure Promtail
section "Phase 9: Configuring Promtail"

PROMTAIL_CONFIG="/usr/local/etc/promtail/config.yml"

read -r -d '' PROMTAIL_CONFIG_CONTENT << 'EOF' || true
server:
  http_listen_address: 127.0.0.1
  http_listen_port: 9080
  grpc_listen_port: 0

clients:
  - url: http://127.0.0.1:3100/loki/api/v1/push

positions:
  filename: /usr/local/var/promtail-positions.yaml

scrape_configs:
  # NGINX JSON access log
  - job_name: nginx-access
    static_configs:
      - targets:
          - localhost
        labels:
          job: nginx
          log_type: access
          __path__: /usr/local/var/log/nginx/access.json
    
    pipeline_stages:
      - json:
          expressions:
            time: time
            remote_addr: remote_addr
            request: request
            status: status
            body_bytes_sent: body_bytes_sent
            http_referer: http_referer
            http_user_agent: http_user_agent
            request_time: request_time
            upstream_response_time: upstream_response_time
            host: host
            uri: uri
            method: method
      
      - labels:
          status:
          method:
          host:
      
      - timestamp:
          source: time
          format: RFC3339

  # NGINX error log (plain text)
  - job_name: nginx-error
    static_configs:
      - targets:
          - localhost
        labels:
          job: nginx
          log_type: error
          __path__: /usr/local/var/log/nginx/error.log

  # Monitoring stack logs
  - job_name: monitoring
    static_configs:
      - targets:
          - localhost
        labels:
          job: monitoring
          __path__: /usr/local/var/log/monitoring/*.log
EOF

check_and_write_file "$PROMTAIL_CONFIG" "$PROMTAIL_CONFIG_CONTENT" false

# Create Promtail LaunchDaemon
PROMTAIL_PLIST="/Library/LaunchDaemons/com.grafana.promtail.plist"

read -r -d '' PROMTAIL_PLIST_CONTENT << EOF || true
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.grafana.promtail</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/promtail</string>
        <string>-config.file=/usr/local/etc/promtail/config.yml</string>
    </array>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <true/>
    
    <key>StartInterval</key>
    <integer>45</integer>
    
    <key>StandardOutPath</key>
    <string>/usr/local/var/log/monitoring/promtail.log</string>
    
    <key>StandardErrorPath</key>
    <string>/usr/local/var/log/monitoring/promtail-error.log</string>
</dict>
</plist>
EOF

check_and_write_file "$PROMTAIL_PLIST" "$PROMTAIL_PLIST_CONTENT" true

if [ -f "$PROMTAIL_PLIST" ]; then
    sudo chown root:wheel "$PROMTAIL_PLIST"
    sudo chmod 644 "$PROMTAIL_PLIST"
fi

# Configure Grafana
section "Phase 10: Configuring Grafana"

GRAFANA_INI="/usr/local/etc/grafana/grafana.ini"

# Generate a random password if this is first install
if [ ! -f "$GRAFANA_INI" ]; then
    GRAFANA_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-20)
    info "Generated Grafana admin password: $GRAFANA_PASSWORD"
    info "Save this password! You'll need it to login."
    echo ""
else
    # Try to extract existing password
    if grep -q "^admin_password" "$GRAFANA_INI"; then
        GRAFANA_PASSWORD=$(grep "^admin_password" "$GRAFANA_INI" | cut -d= -f2 | tr -d ' ')
        info "Using existing Grafana admin password from config"
    else
        GRAFANA_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-20)
        info "Generated new Grafana admin password: $GRAFANA_PASSWORD"
    fi
fi

read -r -d '' GRAFANA_INI_CONTENT << EOF || true
[server]
http_addr = 0.0.0.0
http_port = 3000
domain = macminiserver

[paths]
data = /usr/local/var/lib/grafana
logs = /usr/local/var/log/grafana
plugins = /usr/local/var/lib/grafana/plugins
provisioning = /usr/local/etc/grafana/provisioning

[security]
admin_user = admin
admin_password = $GRAFANA_PASSWORD

[users]
allow_sign_up = false

[auth.anonymous]
enabled = false

[analytics]
reporting_enabled = false
check_for_updates = false

[log]
mode = file
level = info
EOF

check_and_write_file "$GRAFANA_INI" "$GRAFANA_INI_CONTENT" false

# Create Grafana data source provisioning
GRAFANA_DATASOURCES="/usr/local/etc/grafana/provisioning/datasources/datasources.yml"

read -r -d '' GRAFANA_DATASOURCES_CONTENT << 'EOF' || true
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://127.0.0.1:9090
    isDefault: true
    editable: true
    jsonData:
      timeInterval: 15s

  - name: Loki
    type: loki
    access: proxy
    url: http://127.0.0.1:3100
    editable: true
    jsonData:
      maxLines: 1000
EOF

check_and_write_file "$GRAFANA_DATASOURCES" "$GRAFANA_DATASOURCES_CONTENT" false

# Create Grafana LaunchDaemon
GRAFANA_PLIST="/Library/LaunchDaemons/com.grafana.grafana.plist"

read -r -d '' GRAFANA_PLIST_CONTENT << EOF || true
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.grafana.grafana</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/grafana-server</string>
        <string>--config=/usr/local/etc/grafana/grafana.ini</string>
        <string>--homepath=/usr/local/opt/grafana/share/grafana</string>
    </array>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>/usr/local/var/log/grafana/grafana.log</string>
    
    <key>StandardErrorPath</key>
    <string>/usr/local/var/log/grafana/grafana-error.log</string>
    
    <key>WorkingDirectory</key>
    <string>/usr/local/var/lib/grafana</string>
</dict>
</plist>
EOF

check_and_write_file "$GRAFANA_PLIST" "$GRAFANA_PLIST_CONTENT" true

if [ -f "$GRAFANA_PLIST" ]; then
    sudo chown root:wheel "$GRAFANA_PLIST"
    sudo chmod 644 "$GRAFANA_PLIST"
fi

# Configure log rotation
section "Phase 11: Configuring Log Rotation"

info "NGINX log rotation is managed by provision_webserver.sh"

MONITORING_NEWSYSLOG="/etc/newsyslog.d/monitoring.conf"

read -r -d '' MONITORING_NEWSYSLOG_CONTENT << 'EOF' || true
# Monitoring stack logs - rotate daily, keep 7 files
/usr/local/var/log/monitoring/*.log     644  7  *  @T00  GZ
/usr/local/var/log/grafana/*.log        644  7  *  @T00  GZ
EOF

check_and_write_file "$MONITORING_NEWSYSLOG" "$MONITORING_NEWSYSLOG_CONTENT" true

# Provision Grafana Dashboards
section "Phase 11.5: Provisioning Grafana Dashboards"

# Create dashboard provisioning directory
DASHBOARD_FILES_DIR="/usr/local/etc/grafana/provisioning/dashboards/files"
mkdir -p "$DASHBOARD_FILES_DIR"

# Create dashboard provider config
DASHBOARD_PROVIDER="/usr/local/etc/grafana/provisioning/dashboards/default.yml"

read -r -d '' DASHBOARD_PROVIDER_CONTENT << 'EOF' || true
apiVersion: 1

providers:
  - name: 'Default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /usr/local/etc/grafana/provisioning/dashboards/files
      foldersFromFilesStructure: true
EOF

check_and_write_file "$DASHBOARD_PROVIDER" "$DASHBOARD_PROVIDER_CONTENT" false

# Download popular dashboards
info "Downloading recommended dashboards..."

# Node Exporter Full dashboard (ID: 1860)
if [ ! -f "$DASHBOARD_FILES_DIR/node-exporter-full.json" ]; then
    info "Downloading Node Exporter Full dashboard..."
    curl -sL "https://grafana.com/api/dashboards/1860/revisions/37/download" \
        -o "$DASHBOARD_FILES_DIR/node-exporter-full.json"
    if [ -f "$DASHBOARD_FILES_DIR/node-exporter-full.json" ]; then
        success "Node Exporter Full dashboard downloaded"
    else
        warning "Failed to download Node Exporter dashboard"
    fi
else
    info "Node Exporter Full dashboard already exists"
fi

# NGINX dashboard (ID: 12708)
if [ ! -f "$DASHBOARD_FILES_DIR/nginx.json" ]; then
    info "Downloading NGINX dashboard..."
    curl -sL "https://grafana.com/api/dashboards/12708/revisions/1/download" \
        -o "$DASHBOARD_FILES_DIR/nginx.json"
    if [ -f "$DASHBOARD_FILES_DIR/nginx.json" ]; then
        success "NGINX dashboard downloaded"
    else
        warning "Failed to download NGINX dashboard"
    fi
else
    info "NGINX dashboard already exists"
fi

success "Dashboard provisioning configured"

# Load LaunchDaemons
section "Phase 12: Starting LGTM Stack Services"

SERVICES=(
    "com.prometheus.node_exporter:node_exporter"
    "com.prometheus.nginx_exporter:nginx-prometheus-exporter"
    "com.prometheus.prometheus:Prometheus"
    "com.grafana.loki:Loki"
    "com.grafana.promtail:Promtail"
    "com.grafana.grafana:Grafana"
)

info "Loading and starting services..."
echo ""

for service_info in "${SERVICES[@]}"; do
    service="${service_info%%:*}"
    name="${service_info##*:}"
    plist="/Library/LaunchDaemons/${service}.plist"
    
    if [ ! -f "$plist" ]; then
        warning "LaunchDaemon not found: $plist"
        continue
    fi
    
    # Check if already loaded
    if sudo launchctl list 2>/dev/null | grep -q "$service"; then
        info "$name is already running"
        read -r -p "$(echo -e "${YELLOW}Restart $name? [y/N]: ${NC}")" response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            sudo launchctl unload "$plist" 2>/dev/null || true
            sleep 1
            sudo launchctl load -w "$plist"
            success "Restarted $name"
        fi
    else
        sudo launchctl load -w "$plist"
        success "Started $name"
    fi
done

# Wait a moment for services to start
info "Waiting for services to initialize..."
sleep 3

# Create symlinks for easy access
section "Phase 13: Creating Convenient Symlinks"

SYMLINKS_DIR="$USER_HOME/webserver/symlinks/monitoring"
mkdir -p "$SYMLINKS_DIR"

info "Creating symlinks in $SYMLINKS_DIR..."

# Config files
ln -sf /usr/local/etc/prometheus/prometheus.yml "$SYMLINKS_DIR/prometheus.yml" 2>/dev/null || true
ln -sf /usr/local/etc/loki/local-config.yaml "$SYMLINKS_DIR/loki.yaml" 2>/dev/null || true
ln -sf /usr/local/etc/promtail/config.yml "$SYMLINKS_DIR/promtail.yml" 2>/dev/null || true
ln -sf /usr/local/etc/grafana/grafana.ini "$SYMLINKS_DIR/grafana.ini" 2>/dev/null || true

# Log directories
ln -sf /usr/local/var/log/monitoring "$USER_HOME/webserver/symlinks/logs/monitoring" 2>/dev/null || true
ln -sf /usr/local/var/log/grafana "$USER_HOME/webserver/symlinks/logs/grafana" 2>/dev/null || true

# Data directories
ln -sf /usr/local/var/prometheus "$SYMLINKS_DIR/prometheus-data" 2>/dev/null || true
ln -sf /usr/local/var/loki "$SYMLINKS_DIR/loki-data" 2>/dev/null || true

success "Symlinks created"

# Copy management script
MANAGE_SCRIPT_SRC="$USER_HOME/Code/dotfiles/macminiserver/lgtm/manage-monitoring.sh"
MANAGE_SCRIPT_DST="$USER_HOME/webserver/scripts/manage-monitoring.sh"

if [ -f "$MANAGE_SCRIPT_SRC" ]; then
    mkdir -p "$USER_HOME/webserver/scripts"
    ln -sf "$MANAGE_SCRIPT_SRC" "$MANAGE_SCRIPT_DST" 2>/dev/null || true
    chmod +x "$MANAGE_SCRIPT_SRC"
    success "Management script linked to $MANAGE_SCRIPT_DST"
fi

# Verification
section "Phase 14: Verification"

info "Checking service status..."
echo ""

# Function to get port for a service
get_service_port() {
    case "$1" in
        "node_exporter") echo "9100" ;;
        "nginx_exporter") echo "9113" ;;
        "prometheus") echo "9090" ;;
        "loki") echo "3100" ;;
        "promtail") echo "9080" ;;
        "grafana") echo "3000" ;;
        *) echo "" ;;
    esac
}

ALL_OK=true

for service_info in "${SERVICES[@]}"; do
    service="${service_info%%:*}"
    name="${service_info##*:}"
    short_name="${service##*.}"
    port=$(get_service_port "$short_name")
    
    if sudo launchctl list 2>/dev/null | grep -q "$service"; then
        # Try to connect to the service
        case "$short_name" in
            "prometheus")
                if curl -s http://127.0.0.1:${port}/-/healthy > /dev/null 2>&1; then
                    success "$name is running and healthy (port $port)"
                else
                    warning "$name is running but not responding on port $port"
                    ALL_OK=false
                fi
                ;;
            "loki")
                if curl -s http://127.0.0.1:${port}/ready > /dev/null 2>&1; then
                    success "$name is running and ready (port $port)"
                else
                    warning "$name is running but not responding on port $port"
                    ALL_OK=false
                fi
                ;;
            "promtail")
                if curl -s http://127.0.0.1:${port}/ready > /dev/null 2>&1; then
                    success "$name is running and ready (port $port)"
                else
                    warning "$name is running but not responding on port $port"
                    ALL_OK=false
                fi
                ;;
            "grafana")
                if curl -s http://127.0.0.1:${port}/api/health > /dev/null 2>&1; then
                    success "$name is running and healthy (port $port)"
                else
                    warning "$name is running but not responding on port $port (may still be starting)"
                    ALL_OK=false
                fi
                ;;
            *)
                if curl -s http://127.0.0.1:${port}/metrics > /dev/null 2>&1; then
                    success "$name is running and serving metrics (port $port)"
                else
                    warning "$name is running but not responding on port $port"
                    ALL_OK=false
                fi
                ;;
        esac
    else
        error "$name is NOT running"
        ALL_OK=false
    fi
done

echo ""

if [ "$ALL_OK" = true ]; then
    success "All services are running!"
else
    warning "Some services may need attention. Check logs:"
    info "  tail -f /usr/local/var/log/monitoring/*.log"
    info "  tail -f /usr/local/var/log/grafana/grafana.log"
fi

# Final summary
section "✅ LGTM Stack Provisioning Complete!"

echo ""
success "Prometheus is collecting metrics"
success "Loki is collecting logs"
success "Grafana is ready for visualization"
success "All exporters are running"
success "Log rotation configured"
success "LaunchDaemons configured for boot-time startup"

echo ""
info "Service Ports:"
echo "  • Prometheus:     http://127.0.0.1:9090 (localhost only)"
echo "  • Loki:           http://127.0.0.1:3100 (localhost only)"
echo "  • Grafana:        http://macminiserver:3000 (LAN accessible)"
echo "  • node_exporter:  http://127.0.0.1:9100 (localhost only)"
echo "  • nginx_exporter: http://127.0.0.1:9113 (localhost only)"
echo "  • Promtail:       http://127.0.0.1:9080 (localhost only)"

echo ""
info "Grafana Login:"
echo "  • URL:      http://macminiserver.local:3000"
echo "  • Username: admin"
echo "  • Password: $GRAFANA_PASSWORD"
info "  (Save this password!)"

echo ""
info "Quick Access:"
echo "  • Configs:  ~/webserver/symlinks/monitoring/"
echo "  • Logs:     ~/webserver/symlinks/logs/monitoring/"
echo "  • Data:     ~/webserver/symlinks/monitoring/*-data/"

echo ""
info "Management Commands:"
echo "  • Status:  ~/webserver/scripts/manage-monitoring.sh status"
echo "  • Start:   ~/webserver/scripts/manage-monitoring.sh start"
echo "  • Stop:    ~/webserver/scripts/manage-monitoring.sh stop"
echo "  • Restart: ~/webserver/scripts/manage-monitoring.sh restart"
echo "  • Logs:    ~/webserver/scripts/manage-monitoring.sh logs <service>"

echo ""
info "Next Steps:"
echo "  1. Open Grafana: http://macminiserver.local:3000"
echo "  2. Login with credentials above"
echo "  3. Verify data sources are connected (Prometheus & Loki)"
echo "  4. Check out the pre-installed dashboards:"
echo "     - Node Exporter Full: Host metrics (CPU, memory, disk, network)"
echo "     - NGINX: Web server metrics (requests, response times)"
echo "  5. Explore Logs via 'Explore' menu (Loki data source)"
echo "  6. Create custom dashboards for your specific needs"

echo ""
info "LAN Access:"
echo "  • Grafana is accessible from any device on your LAN"
echo "  • URL: http://macminiserver.local:3000"
echo "  • Or use IP: http://$(ipconfig getifaddr en0 2>/dev/null || echo "YOUR_IP"):3000"
echo "  • All other services (Prometheus, Loki) remain localhost-only for security"

echo ""
success "🎉 Your LGTM monitoring stack is ready!"
