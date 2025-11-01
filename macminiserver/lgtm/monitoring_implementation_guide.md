# Mac Mini Server Monitoring Implementation Guide

**Target System:** Intel Mac mini (macOS Sequoia 15.7)  
**Installation Prefix:** `/usr/local` (Intel Homebrew)  
**Existing Setup:** NGINX webserver managed via LaunchDaemon  
**Goal:** Add LGTM stack (Loki, Grafana, Tempo optional, Mimir/Prometheus) with boot-time startup

---

## Overview

This guide implements the monitoring plan defined in `macmini_nginx_monitoring_plan.md` with these key adjustments:

1. ✅ **LaunchDaemons instead of brew services** - All monitoring components start at boot (before user login)
2. ✅ **No changes to existing nginx** - We only add configuration, not reinstall
3. ✅ **Intel Mac paths** - Everything under `/usr/local`
4. ✅ **Bounded storage** - Explicit retention policies and log rotation

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Mac Mini Server                       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  NGINX (existing)                                        │
│    ├─ /nginx_status → nginx-prometheus-exporter         │
│    ├─ access.json → Promtail → Loki                     │
│    └─ error.log → Promtail → Loki                       │
│                                                          │
│  node_exporter → Prometheus ← nginx-prometheus-exporter │
│                       ↓                                  │
│                   Grafana ← Loki                         │
│                                                          │
│  All components managed by LaunchDaemons                 │
│  All bind to 127.0.0.1 (localhost only)                 │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## Phase 1: Install Monitoring Components

### 1.1 Install via Homebrew

```bash
# Install all monitoring stack components
brew install prometheus node_exporter nginx-prometheus-exporter
brew install loki promtail
brew install grafana
```

**Verification:**
```bash
which prometheus node_exporter nginx-prometheus-exporter
which loki promtail grafana-server
# All should show paths under /usr/local/bin/
```

### 1.2 Create Required Directories

```bash
# Prometheus data & config
sudo mkdir -p /usr/local/var/prometheus
sudo mkdir -p /usr/local/etc/prometheus
sudo chown -R $(whoami):staff /usr/local/var/prometheus
sudo chown -R $(whoami):staff /usr/local/etc/prometheus

# Loki data & config
sudo mkdir -p /usr/local/var/loki/{chunks,rules,compactor}
sudo mkdir -p /usr/local/etc/loki
sudo chown -R $(whoami):staff /usr/local/var/loki
sudo chown -R $(whoami):staff /usr/local/etc/loki

# Promtail config
sudo mkdir -p /usr/local/etc/promtail
sudo chown -R $(whoami):staff /usr/local/etc/promtail

# Grafana
sudo mkdir -p /usr/local/var/lib/grafana
sudo mkdir -p /usr/local/var/log/grafana
sudo chown -R $(whoami):staff /usr/local/var/lib/grafana
sudo chown -R $(whoami):staff /usr/local/var/log/grafana

# Shared log directory for all monitoring components
sudo mkdir -p /usr/local/var/log/monitoring
sudo chown -R $(whoami):staff /usr/local/var/log/monitoring
```

---

## Phase 2: Configure NGINX (Non-Destructive)

Your existing nginx is at `/usr/local/etc/nginx/nginx.conf` managed by LaunchDaemon. We'll only **add** configuration.

### 2.1 Add stub_status endpoint for metrics

Edit `/usr/local/etc/nginx/nginx.conf` and add this location block inside the `http` section (but outside any `server` blocks):

```nginx
http {
    # ... existing config ...
    
    # Monitoring: stub_status for Prometheus exporter
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
    
    # ... rest of config ...
}
```

### 2.2 Add JSON logging format

Edit `/usr/local/etc/nginx/nginx.conf` and add this inside the `http` section (near the existing `log_format main`):

```nginx
http {
    # Existing log format
    log_format main '[$time_local] $remote_addr -> $server_name "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    # ADD THIS: JSON format for Loki/Promtail
    log_format json_combined escape=json
      '{ "time":"$time_iso8601", "remote_addr":"$remote_addr", "request":"$request", '
      '"status":$status, "body_bytes_sent":$body_bytes_sent, "http_referer":"$http_referer", '
      '"http_user_agent":"$http_user_agent", "request_time":$request_time, '
      '"upstream_response_time":"$upstream_response_time", "host":"$host", "uri":"$uri", "method":"$request_method" }';

    # Keep existing access log, add JSON access log
    access_log /usr/local/var/log/nginx/access.log main;
    access_log /usr/local/var/log/nginx/access.json json_combined;
    
    # ... rest of config ...
}
```

### 2.3 Test and Reload NGINX

```bash
# Test configuration
nginx -t

# If successful, reload
nginx -s reload
# OR if using LaunchDaemon:
sudo launchctl kickstart -k system/com.nginx.nginx
```

**Verification:**
```bash
# Should see stub_status metrics
curl http://127.0.0.1:8080/nginx_status
# OR if you added to hello.conf:
curl http://localhost/nginx_status

# Should see JSON logs being created
tail -f /usr/local/var/log/nginx/access.json
```

---

## Phase 3: Configure Prometheus

### 3.1 Create Prometheus Configuration

Create `/usr/local/etc/prometheus/prometheus.yml`:

```yaml
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
```

### 3.2 Create Prometheus LaunchDaemon

Create `/Library/LaunchDaemons/com.prometheus.prometheus.plist`:

```xml
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
```

**Install and start:**
```bash
sudo chown root:wheel /Library/LaunchDaemons/com.prometheus.prometheus.plist
sudo chmod 644 /Library/LaunchDaemons/com.prometheus.prometheus.plist
sudo launchctl load -w /Library/LaunchDaemons/com.prometheus.prometheus.plist
```

**Verification:**
```bash
sudo launchctl list | grep prometheus
curl http://127.0.0.1:9090/-/healthy
```

---

## Phase 4: Configure node_exporter

### 4.1 Create node_exporter LaunchDaemon

Create `/Library/LaunchDaemons/com.prometheus.node_exporter.plist`:

```xml
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
```

**Install and start:**
```bash
sudo chown root:wheel /Library/LaunchDaemons/com.prometheus.node_exporter.plist
sudo chmod 644 /Library/LaunchDaemons/com.prometheus.node_exporter.plist
sudo launchctl load -w /Library/LaunchDaemons/com.prometheus.node_exporter.plist
```

**Verification:**
```bash
sudo launchctl list | grep node_exporter
curl -s http://127.0.0.1:9100/metrics | head -20
```

---

## Phase 5: Configure nginx-prometheus-exporter

### 5.1 Create nginx-prometheus-exporter LaunchDaemon

Create `/Library/LaunchDaemons/com.prometheus.nginx_exporter.plist`:

```xml
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
```

**NOTE:** Adjust `-nginx.scrape-uri` to match your nginx_status location:
- If using separate server on 8080: `http://127.0.0.1:8080/nginx_status`
- If added to hello.conf: `http://127.0.0.1/nginx_status`

**Install and start:**
```bash
sudo chown root:wheel /Library/LaunchDaemons/com.prometheus.nginx_exporter.plist
sudo chmod 644 /Library/LaunchDaemons/com.prometheus.nginx_exporter.plist
sudo launchctl load -w /Library/LaunchDaemons/com.prometheus.nginx_exporter.plist
```

**Verification:**
```bash
sudo launchctl list | grep nginx_exporter
curl -s http://127.0.0.1:9113/metrics | grep nginx
```

---

## Phase 6: Configure Loki

### 6.1 Create Loki Configuration

Create `/usr/local/etc/loki/local-config.yaml`:

```yaml
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
  working_directory: /usr/local/var/loki/compactor
  shared_store: filesystem
  compaction_interval: 60m
  retention_enabled: true
  retention_delete_delay: 24h
  retention_delete_worker_count: 150

limits_config:
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
```

### 6.2 Create Loki LaunchDaemon

Create `/Library/LaunchDaemons/com.grafana.loki.plist`:

```xml
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
```

**Install and start:**
```bash
sudo chown root:wheel /Library/LaunchDaemons/com.grafana.loki.plist
sudo chmod 644 /Library/LaunchDaemons/com.grafana.loki.plist
sudo launchctl load -w /Library/LaunchDaemons/com.grafana.loki.plist
```

**Verification:**
```bash
sudo launchctl list | grep loki
curl http://127.0.0.1:3100/ready
curl http://127.0.0.1:3100/metrics | head
```

---

## Phase 7: Configure Promtail

### 7.1 Create Promtail Configuration

Create `/usr/local/etc/promtail/config.yml`:

```yaml
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
```

### 7.2 Create Promtail LaunchDaemon

Create `/Library/LaunchDaemons/com.grafana.promtail.plist`:

```xml
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
    
    <key>StandardOutPath</key>
    <string>/usr/local/var/log/monitoring/promtail.log</string>
    
    <key>StandardErrorPath</key>
    <string>/usr/local/var/log/monitoring/promtail-error.log</string>
</dict>
</plist>
```

**Install and start:**
```bash
sudo chown root:wheel /Library/LaunchDaemons/com.grafana.promtail.plist
sudo chmod 644 /Library/LaunchDaemons/com.grafana.promtail.plist
sudo launchctl load -w /Library/LaunchDaemons/com.grafana.promtail.plist
```

**Verification:**
```bash
sudo launchctl list | grep promtail
curl http://127.0.0.1:9080/ready
tail -f /usr/local/var/log/monitoring/promtail.log
```

---

## Phase 8: Configure Grafana

### 8.1 Create Grafana Configuration

Create `/usr/local/etc/grafana/grafana.ini`:

```ini
[server]
http_addr = 127.0.0.1
http_port = 3000
domain = localhost

[paths]
data = /usr/local/var/lib/grafana
logs = /usr/local/var/log/grafana
plugins = /usr/local/var/lib/grafana/plugins
provisioning = /usr/local/etc/grafana/provisioning

[security]
admin_user = admin
admin_password = 8qHemwAoAaLA7x3exH6P

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
```

### 8.2 Create Grafana Data Source Provisioning

Create `/usr/local/etc/grafana/provisioning/datasources/datasources.yml`:

```yaml
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
```

**Create provisioning directory:**
```bash
sudo mkdir -p /usr/local/etc/grafana/provisioning/datasources
sudo mkdir -p /usr/local/etc/grafana/provisioning/dashboards
sudo chown -R $(whoami):staff /usr/local/etc/grafana
```

### 8.3 Create Grafana LaunchDaemon

Create `/Library/LaunchDaemons/com.grafana.grafana.plist`:

```xml
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
```

**Install and start:**
```bash
sudo chown root:wheel /Library/LaunchDaemons/com.grafana.grafana.plist
sudo chmod 644 /Library/LaunchDaemons/com.grafana.grafana.plist
sudo launchctl load -w /Library/LaunchDaemons/com.grafana.grafana.plist
```

**Verification:**
```bash
sudo launchctl list | grep grafana
sleep 5  # Give it time to start
curl http://127.0.0.1:3000/api/health
```

---

## Phase 9: Configure Log Rotation

### 9.1 Create newsyslog Configuration for NGINX

Create `/etc/newsyslog.d/nginx.conf` (requires sudo):

```
# NGINX logs - rotate when 10MB, keep 7 files, compress
/usr/local/var/log/nginx/access.log     _www:wheel  644  7  10000  *  GZ
/usr/local/var/log/nginx/access.json    _www:wheel  644  7  10000  *  GZ
/usr/local/var/log/nginx/error.log      _www:wheel  644  7  10000  *  GZ
```

### 9.2 Create newsyslog Configuration for Monitoring

Create `/etc/newsyslog.d/monitoring.conf` (requires sudo):

```
# Monitoring stack logs - rotate daily, keep 7 files
/usr/local/var/log/monitoring/*.log     644  7  *  @T00  GZ
/usr/local/var/log/grafana/*.log        644  7  *  @T00  GZ
```

**Apply:**
```bash
sudo newsyslog -v
```

---

## Phase 10: Verification & Testing

### 10.1 Check All Services

```bash
~/webserver/scripts/manage-monitoring.sh status
```

### 10.2 Access Grafana

1. Open browser to: http://localhost:3000
2. Login with: admin / admin
3. Change password when prompted
4. Verify data sources are connected (Configuration → Data Sources)

### 10.3 Test Metrics

```bash
# Check Prometheus targets
curl http://127.0.0.1:9090/api/v1/targets | jq '.data.activeTargets[] | {job, health}'

# Sample metric queries
curl -s 'http://127.0.0.1:9090/api/v1/query?query=up' | jq .

# Check node_exporter metrics
curl -s 'http://127.0.0.1:9090/api/v1/query?query=node_memory_MemAvailable_bytes' | jq .

# Check nginx metrics
curl -s 'http://127.0.0.1:9090/api/v1/query?query=nginx_up' | jq .
```

### 10.4 Test Log Ingestion

```bash
# Generate some nginx traffic
for i in {1..10}; do curl http://localhost/ > /dev/null 2>&1; done

# Check Loki has logs
curl -s 'http://127.0.0.1:3100/loki/api/v1/query?query={job="nginx"}' | jq .

# Or in Grafana: Explore → Loki → {job="nginx"}
```

---

## Phase 12: Create Grafana Dashboards

### 12.1 Import Pre-built Dashboards

In Grafana UI:

1. **Node Exporter Full** (Dashboard ID: 1860)
   - Dashboards → Import → 1860 → Load
   - Select Prometheus data source
   
2. **NGINX** (Dashboard ID: 12708)
   - Dashboards → Import → 12708 → Load
   - Select Prometheus data source

3. **Loki Logs** (create custom)
   - Dashboards → New Dashboard → Add Panel
   - Query: `{job="nginx"}`
   - Visualization: Logs

### 12.2 Sample Custom Dashboard Panels

**CPU Usage:**
```promql
100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

**Memory Usage:**
```promql
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
```

**Disk Free (Root):**
```promql
node_filesystem_avail_bytes{mountpoint="/"}
```

**NGINX Requests/sec:**
```promql
rate(nginx_http_requests_total[1m])
```

**NGINX 5xx Errors:**
```promql
sum(rate(nginx_http_requests_total{status=~"5.."}[5m]))
```

---

## Troubleshooting

### Services Won't Start

```bash
# Check LaunchDaemon status
sudo launchctl list | grep -E "prometheus|grafana|loki"

# Check logs
tail -f /usr/local/var/log/monitoring/*.log
tail -f /usr/local/var/log/grafana/*.log

# Manually test binaries
/usr/local/bin/prometheus --version
/usr/local/bin/loki --version
/usr/local/bin/grafana-server --version
```

### Prometheus Can't Scrape Targets

```bash
# Check targets in Prometheus UI
open http://127.0.0.1:9090/targets

# Test endpoints manually
curl http://127.0.0.1:9100/metrics  # node_exporter
curl http://127.0.0.1:9113/metrics  # nginx_exporter
curl http://127.0.0.1:8080/nginx_status  # nginx stub_status
```

### Loki Not Receiving Logs

```bash
# Check Promtail is running
sudo launchctl list | grep promtail

# Check Promtail logs
tail -f /usr/local/var/log/monitoring/promtail.log

# Check positions file
cat /usr/local/var/promtail-positions.yaml

# Manually test log shipping
curl -s 'http://127.0.0.1:3100/loki/api/v1/query?query={job="nginx"}' | jq .
```

### Grafana Can't Connect to Data Sources

```bash
# Check Grafana logs
tail -f /usr/local/var/log/grafana/grafana.log

# Test data sources from command line
curl http://127.0.0.1:9090/api/v1/query?query=up
curl http://127.0.0.1:3100/ready

# Check Grafana provisioning
ls -la /usr/local/etc/grafana/provisioning/datasources/
```

### High Disk Usage

```bash
# Check Prometheus retention
curl http://127.0.0.1:9090/api/v1/status/runtimeinfo | jq .

# Manually compact Loki
# (automatic via config, but can force)

# Check log rotation is working
sudo newsyslog -nvv
```

---

## Maintenance

### Daily
- Monitor Grafana dashboards for anomalies
- Check disk usage if < 20GB free

### Weekly
```bash
# Check all services healthy
~/webserver/scripts/manage-monitoring.sh status

# Review Grafana for any alerts or issues
open http://127.0.0.1:3000
```

### Monthly
```bash
# Check Homebrew for updates
brew update && brew upgrade

# Restart monitoring stack to pick up updates
~/webserver/scripts/manage-monitoring.sh restart

# Verify log rotation is working
ls -lh /usr/local/var/log/nginx/
ls -lh /usr/local/var/log/monitoring/
```

---

## Security Notes

1. **All services bind to 127.0.0.1** - Accessible only from localhost
2. **To access Grafana remotely**, use SSH tunnel:
   ```bash
   ssh -L 3000:localhost:3000 macminiserver.local
   # Then browse to http://localhost:3000 on your local machine
   ```
3. **Change Grafana admin password** after first login
4. **NGINX stub_status** is localhost-only (already configured)

---

## Quick Reference

### Service Ports
- Prometheus: 9090
- node_exporter: 9100
- nginx_exporter: 9113
- Loki: 3100
- Promtail: 9080
- Grafana: 3000
- NGINX stub_status: 8080 (or 80 if added to hello.conf)

### Management Commands
```bash
# Monitoring stack
~/webserver/scripts/manage-monitoring.sh {start|stop|restart|status}
~/webserver/scripts/manage-monitoring.sh logs {service}

# NGINX
~/webserver/scripts/manage-nginx.sh {start|stop|reload|status}

# View logs
tail -f ~/webserver/symlinks/logs/monitoring/*.log
tail -f ~/webserver/symlinks/logs/nginx/access.json
```

### Configuration Files
```bash
ls -la ~/webserver/symlinks/monitoring/
ls -la ~/webserver/symlinks/nginx-sites/
```

---

## Success Criteria

✅ All LaunchDaemons load at boot (before user login)  
✅ Prometheus scrapes all targets (node, nginx, self)  
✅ Loki receives nginx access + error logs  
✅ Grafana displays metrics and logs  
✅ Storage stays under 10GB  
✅ Log rotation works automatically  
✅ No changes to existing nginx installation  

---

## Next Steps

1. **Set up Alerting** - Add Alertmanager and alert rules
2. **Add more dashboards** - Create custom panels for your specific needs
3. **Remote access** - Configure reverse proxy with auth for remote Grafana access
4. **Backups** - Add Grafana dashboard/config backups to your existing backup strategy

---

**End of Implementation Guide**

This guide provides a complete, step-by-step implementation that:
- Uses LaunchDaemons instead of brew services for boot-time startup
- Doesn't modify your existing nginx installation
- Works correctly with Intel Mac `/usr/local` paths
- Provides bounded storage and proper log rotation
- Includes management scripts and troubleshooting guides
