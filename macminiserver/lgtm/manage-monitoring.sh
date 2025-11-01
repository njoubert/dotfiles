#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }

SERVICES=(
    "com.prometheus.node_exporter"
    "com.prometheus.nginx_exporter"
    "com.prometheus.prometheus"
    "com.grafana.loki"
    "com.grafana.promtail"
    "com.grafana.grafana"
)

start() {
    echo "Starting monitoring stack..."
    for service in "${SERVICES[@]}"; do
        sudo launchctl load -w "/Library/LaunchDaemons/${service}.plist" 2>/dev/null || true
        success "Started $service"
    done
}

stop() {
    echo "Stopping monitoring stack..."
    for service in "${SERVICES[@]}"; do
        sudo launchctl unload "/Library/LaunchDaemons/${service}.plist" 2>/dev/null || true
        success "Stopped $service"
    done
}

restart() {
    stop
    sleep 2
    start
}

status() {
    echo "Monitoring Stack Status:"
    echo ""
    for service in "${SERVICES[@]}"; do
        if sudo launchctl list | grep -q "$service"; then
            success "$service is running"
        else
            error "$service is NOT running"
        fi
    done
    
    echo ""
    echo "Health Checks:"
    curl -s http://127.0.0.1:9090/-/healthy && success "Prometheus: healthy" || error "Prometheus: not responding"
    curl -s http://127.0.0.1:3100/ready && success "Loki: ready" || error "Loki: not responding"
    curl -s http://127.0.0.1:3000/api/health && success "Grafana: healthy" || error "Grafana: not responding"
}

logs() {
    local service="$1"
    
    if [ -z "$service" ]; then
        echo "Available services: node_exporter, nginx_exporter, prometheus, loki, promtail, grafana"
        return
    fi
    
    case "$service" in
        node_exporter|nginx_exporter|prometheus|loki|promtail)
            tail -f "/usr/local/var/log/monitoring/${service}.log"
            ;;
        grafana)
            tail -f "/usr/local/var/log/grafana/grafana.log"
            ;;
        *)
            error "Unknown service: $service"
            ;;
    esac
}

case "$1" in
    start)   start ;;
    stop)    stop ;;
    restart) restart ;;
    status)  status ;;
    logs)    logs "$2" ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs <service>}"
        exit 1
        ;;
esac