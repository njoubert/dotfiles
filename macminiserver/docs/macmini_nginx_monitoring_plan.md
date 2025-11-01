# Monitoring Plan: macOS (Intel Mac mini) + NGINX (static sites) — **Metrics & Logs, no containers**

## 0) Scope & Goals
- **Host:** Intel Core i3 Mac mini, 32 GB RAM, 128 GB SSD, macOS.
- **Workloads:** NGINX serving static JS/TS (incl. Lit).
- **Deliverables:** Metrics + Logs only (no traces), fully **native** (no Docker), **small footprint** with rotation/retention.
- **Outcomes:**
  - Host metrics: CPU, memory, disk space/IO, network.
  - NGINX metrics: request rate, statuses, connections (via exporter).
  - NGINX logs: access + error (structured), searchable in Loki.
  - Bounded storage: explicit retention for Prometheus & Loki; log rotation via `newsyslog`.

---

## 1) Components (all native via Homebrew)
- **Prometheus** – metrics collection & TSDB.
- **node_exporter** – host metrics.
- **nginx-prometheus-exporter** – NGINX metrics (scrapes `stub_status`).
- **Loki** – log storage (single binary).
- **Promtail** – log shipper to Loki.
- **Grafana** – dashboards for metrics & logs (optional but recommended).

_All services bind to `127.0.0.1` by default for local-only access._

---

## 2) Install (Homebrew)
```bash
# Metrics
brew install prometheus node_exporter nginx-prometheus-exporter

# Logs
brew install loki promtail

# UI (optional but recommended)
brew install grafana
```

Enable at login:
```bash
brew services start node_exporter
brew services start prometheus
brew services start loki
brew services start promtail
brew services start grafana
```

> Intel macOS uses the `/usr/local` prefix. Config lives under `/usr/local/etc/…`, data under `/usr/local/var/…`.

---

## 3) NGINX: enable metrics & structured logs
### 3.1 `stub_status` (for exporter)
Add to your NGINX site or `nginx.conf`:
```nginx
location /nginx_status {
    stub_status on;
    allow 127.0.0.1;
    deny all;
    access_log off;
}
```

Run the exporter (Homebrew service will use this by default if configured):
```bash
# If running manually:
nginx-prometheus-exporter   -nginx.scrape-uri http://127.0.0.1/nginx_status   -web.listen-address 127.0.0.1:9113
```

### 3.2 JSON access log
```nginx
log_format json_combined escape=json
  '{ "time":"$time_iso8601", "remote_addr":"$remote_addr", "request":"$request", '
  '"status":$status, "body_bytes_sent":$body_bytes_sent, "http_referer":"$http_referer", '
  '"http_user_agent":"$http_user_agent", "request_time":$request_time, '
  '"upstream_response_time":"$upstream_response_time", "host":"$host", "uri":"$uri", "method":"$request_method" }';

access_log /usr/local/var/log/nginx/access.json json_combined;
error_log  /usr/local/var/log/nginx/error.log warn;
```

Reload NGINX:
```bash
sudo nginx -t && sudo nginx -s reload
```

---

## 4) Prometheus configuration
`/usr/local/etc/prometheus.yml`
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    instance: macmini

scrape_configs:
  - job_name: node
    static_configs:
      - targets: ['127.0.0.1:9100']   # node_exporter

  - job_name: nginx
    static_configs:
      - targets: ['127.0.0.1:9113']   # nginx-prometheus-exporter
```

**Retention & binding flags** (edit plist or add to service env):
- Storage path: `/usr/local/var/prometheus`
- Recommended flags:
```text
--web.listen-address=127.0.0.1:9090
--storage.tsdb.path=/usr/local/var/prometheus
--storage.tsdb.retention.time=15d
--storage.tsdb.retention.size=5GB
--storage.tsdb.wal-compression
```
Apply:
1) Start Prometheus once with `brew services start prometheus` to generate the plist.  
2) Edit `~/Library/LaunchAgents/homebrew.mxcl.prometheus.plist` to append the flags, then:
```bash
launchctl unload ~/Library/LaunchAgents/homebrew.mxcl.prometheus.plist
launchctl load   ~/Library/LaunchAgents/homebrew.mxcl.prometheus.plist
```

---

## 5) Loki (single process) configuration
`/usr/local/etc/loki/local-config.yaml`
```yaml
server:
  http_listen_address: 127.0.0.1
  http_listen_port: 3100

common:
  path_prefix: /usr/local/var/loki
  storage:
    filesystem:
      chunks_directory: /usr/local/var/loki/chunks
      rules_directory:  /usr/local/var/loki/rules
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

limits_config:
  retention_period: 168h       # 7 days
  ingestion_rate_mb: 4
  ingestion_burst_size_mb: 8

ruler:
  storage:
    type: local
    local:
      directory: /usr/local/var/loki/rules
```

Run Loki with:
```bash
# Ensure Brew uses this config; edit plist if needed to pass:
#   -config.file=/usr/local/etc/loki/local-config.yaml
brew services restart loki
```

---

## 6) Promtail configuration (log shipper)
`/usr/local/etc/promtail/config.yml`
```yaml
server:
  http_listen_address: 127.0.0.1
  http_listen_port: 9080

clients:
  - url: http://127.0.0.1:3100/loki/api/v1/push

positions:
  filename: /usr/local/var/promtail-positions.yaml

scrape_configs:
  # NGINX JSON access log
  - job_name: nginx-access
    static_configs:
      - targets: [127.0.0.1]
        labels:
          job: nginx
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
      - targets: [127.0.0.1]
        labels:
          job: nginx
          level: error
          __path__: /usr/local/var/log/nginx/error.log
```

Run:
```bash
# Ensure Brew passes: -config.file=/usr/local/etc/promtail/config.yml
brew services restart promtail
```

---

## 7) Grafana (local only)
- Listen on `127.0.0.1:3000`. First-run creds: `admin` / `admin`.
- Add data sources:
  - Prometheus → `http://127.0.0.1:9090`
  - Loki → `http://127.0.0.1:3100`
- Import dashboards:
  - **Node Exporter Full** (host)
  - **NGINX** (works with nginx-prometheus-exporter)

---

## 8) Log rotation & disk hygiene
### 8.1 Rotate NGINX files via `newsyslog`
Create `/etc/newsyslog.d/nginx.conf` (root):
```
/usr/local/var/log/nginx/access.json  _www:wheel  640  7  1000  Z
/usr/local/var/log/nginx/error.log    _www:wheel  640  7  1000  Z
```
- Keeps **7** rotated files, rotates at **~1 MB** (`1000` KB) or daily (default), compresses (**Z**).  
- Adjust sizes upward (e.g. `100000` for ~100 MB) if your traffic is higher.

### 8.2 Bound Prometheus size/time
- Already set `--storage.tsdb.retention.time=15d` and `--storage.tsdb.retention.size=5GB`.

### 8.3 Loki retention
- Set `limits_config.retention_period: 168h` (7d).  
- For stricter budgets, lower to `72h` or `48h`.

### 8.4 SSD budget (example)
- Prometheus: ≤ **5 GB**  
- Loki (chunks + index): ≤ **3 GB** (with 3–7 day retention)  
- NGINX live logs: ≤ **0.5–1 GB** (newsyslog caps)  
- Grafana data: ≤ **0.5 GB**  
> Total steady-state ≤ **9–10 GB** on a 128 GB SSD.

---

## 9) Security & exposure
- Bind all admin UIs to `127.0.0.1` (Prometheus, Loki, Grafana).
- NGINX `/nginx_status` is **localhost-only**.
- If remote viewing is needed, reverse-proxy with auth (Basic/OIDC) or SSH tunnel.

---

## 10) Health checks & verification
**After starting services:**
```bash
# Metrics
curl -s http://127.0.0.1:9100/metrics | head     # node_exporter
curl -s http://127.0.0.1:9113/metrics | head     # nginx exporter
curl -s http://127.0.0.1:9090/-/ready            # prometheus

# Logs
curl -s http://127.0.0.1:3100/ready              # loki
curl -s http://127.0.0.1:9080/ready              # promtail

# NGINX log emission
tail -f /usr/local/var/log/nginx/access.json
```

**Grafana quick queries:**
- **CPU (host):**  
  `avg(rate(node_cpu_seconds_total{mode!="idle"}[2m]))`
- **Free disk space (root):**  
  `node_filesystem_avail_bytes{mountpoint="/"}`
- **NGINX RPS:**  
  `rate(nginx_http_requests_total[1m])`
- **5xx rate:**  
  `rate(nginx_http_requests_total{status=~"5.."}[5m])`

---

## 11) Alerts (minimal, optional)
Create `/usr/local/etc/alert.rules.yml` and reference with `--rule.files=/usr/local/etc/alert.rules.yml`.
```yaml
groups:
- name: basic
  rules:
  - alert: HighCPU
    expr: avg(rate(node_cpu_seconds_total{mode!="idle"}[5m])) > 0.85
    for: 10m
  - alert: LowDiskFree
    expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) < 0.10
    for: 10m
  - alert: Nginx5xxSpike
    expr: rate(nginx_http_requests_total{status=~"5.."}[5m]) > 1
    for: 5m
```
_Add Alertmanager later for email/Slack._

---

## 12) Operations cheat sheet
- Restart all:
  ```bash
  brew services restart node_exporter prometheus loki promtail grafana
  ```
- Update configs, then restart the relevant service.
- Inspect LaunchAgent plists under `~/Library/LaunchAgents/homebrew.mxcl.*.plist` to adjust flags.
- Periodically check disk usage:
  ```bash
  du -sh /usr/local/var/prometheus /usr/local/var/loki /usr/local/var/log/nginx
  ```

---

## 13) Future extensions (when ready)
- Add **cAdvisor** (container metrics) if/when you start Dockerized APIs on this host.
- Add **Tempo** + OpenTelemetry for distributed traces later.
- Replace multiple agents with **Grafana Alloy** (single binary) if you want one config to rule metrics+logs.

---

### Done
This plan gives you a **native, minimal, bounded** monitoring stack for macOS + NGINX: metrics (Prometheus) and logs (Loki), with structured JSON logs, sane retention, and local-only surfaces.
