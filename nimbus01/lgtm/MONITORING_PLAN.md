# miniserver01 Monitoring Stack Plan

## Overview

Deploy a local monitoring stack on miniserver01 using:
- **Prometheus** – metrics collection & time-series database
- **node_exporter** – host/system metrics exporter
- **Loki** – log aggregation (single binary mode)
- **Promtail** – log shipper to Loki
- **Grafana** – unified dashboards for metrics & logs

All services bind to `0.0.0.0` (all interfaces) by default. Use firewall rules to restrict access if needed.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        miniserver01                              │
│                                                                  │
│  ┌──────────────┐     scrapes     ┌─────────────────┐           │
│  │  Prometheus  │◄────────────────│  node_exporter  │           │
│  │  :9090       │                 │  :9100          │           │
│  └──────┬───────┘                 └─────────────────┘           │
│         │                                                        │
│         │ datasource                                             │
│         ▼                                                        │
│  ┌──────────────┐                 ┌─────────────────┐           │
│  │   Grafana    │◄────────────────│     Loki        │           │
│  │   :3000      │   datasource    │     :3100       │           │
│  └──────────────┘                 └────────▲────────┘           │
│                                            │                     │
│                                     pushes │                     │
│                                   ┌────────┴────────┐           │
│                                   │    Promtail     │           │
│                                   │    (agent)      │           │
│                                   └─────────────────┘           │
│                                            │                     │
│                                     reads  │                     │
│                                   ┌────────┴────────┐           │
│                                   │  /var/log/*     │           │
│                                   │  journald       │           │
│                                   └─────────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Installation Strategy

### Package Sources

All components installed via APT for simplicity and automatic security updates.

| Component     | Source                    | Package Name                 |
|---------------|---------------------------|------------------------------|
| Prometheus    | Ubuntu repos              | `prometheus`                 |
| node_exporter | Ubuntu repos              | `prometheus-node-exporter`   |
| lm-sensors    | Ubuntu repos              | `lm-sensors`                 |
| Loki          | Grafana APT repo          | `loki`                       |
| Promtail      | Grafana APT repo          | `promtail`                   |
| Grafana       | Grafana APT repo          | `grafana`                    |


### Directory Structure (APT-managed)

```
/etc/prometheus/
├── prometheus.yml              # main config
└── ...                         # alert rules, etc.

/etc/loki/
└── config.yml                  # Loki config

/etc/promtail/
└── config.yml                  # Promtail config

/etc/grafana/
├── grafana.ini                 # main config
└── provisioning/
    ├── datasources/            # auto-provisioned datasources
    └── dashboards/             # auto-provisioned dashboards

/var/lib/prometheus/            # Prometheus TSDB data
/var/lib/loki/                  # Loki chunks & index
/var/lib/grafana/               # Grafana database & plugins
```

---

## Configuration (Customizations Only)

APT packages provide sensible defaults. We only customize:

### 1. Prometheus

**Add scrape target for node_exporter** — append to `/etc/prometheus/prometheus.yml`:
```yaml
scrape_configs:
  # ... existing prometheus job ...
  
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
```

**Set retention** — `/etc/default/prometheus`:
```bash
ARGS="--storage.tsdb.retention.time=90d --storage.tsdb.retention.size=5GB"
```

### 2. node_exporter

**Enable NVMe collector** — `/etc/default/prometheus-node-exporter`:
```bash
ARGS="--collector.nvme"
```

**Install lm-sensors for hardware monitoring:**
```bash
sudo apt install lm-sensors
sudo sensors-detect --auto
```

### 3. Loki

**Enable retention** — patch `/etc/loki/config.yml`:
```yaml
limits_config:
  retention_period: 90d

compactor:
  retention_enabled: true
```

### 4. Promtail

**Use APT default config** — no changes needed. Ships with journald scraping.

### 5. Grafana

**Provision datasources** — create `/etc/grafana/provisioning/datasources/lgtm.yml`:
```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    url: http://localhost:9090
    isDefault: true
  - name: Loki
    type: loki
    url: http://localhost:3100
```

---

## Systemd Services

APT packages provide pre-configured systemd units. No overrides needed — using default configuration.

---

## Data Retention

| Component  | Retention | Max Size | Config Location                      |
|------------|-----------|----------|--------------------------------------|
| Prometheus | 90 days   | 5GB      | `/etc/default/prometheus`            |
| Loki       | 90 days   | —        | `/etc/loki/config.yml`               |

Prometheus deletes old data when either limit is reached. Loki is time-only.

---

## Scripts to Create

### 1. `provision-lgtm.sh`

Idempotent setup script:
- Add Grafana APT repo
- Install packages
- Apply config customizations (above)
- Enable and start services

### 2. `manage-lgtm.sh`

Commands: `status`, `start`, `stop`, `restart`, `logs [service]`, `test`

---

## Testing Checklist

After provisioning:
```bash
curl -s http://localhost:9090/-/healthy  # Prometheus
curl -s http://localhost:9100/metrics | head  # node_exporter
curl -s http://localhost:3100/ready  # Loki
curl -s http://localhost:3000/api/health  # Grafana
```

---

## Security

All services bind to `0.0.0.0` with no auth. For LAN-only access:
```bash
sudo ufw allow from 192.168.0.0/16 to any port 3000,9090,9100,3100 proto tcp
```

---

## References

- [Prometheus](https://prometheus.io/docs/)
- [Loki](https://grafana.com/docs/loki/latest/)
- [Grafana](https://grafana.com/docs/grafana/latest/)
- [node_exporter](https://github.com/prometheus/node_exporter)
