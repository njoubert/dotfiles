#!/bin/bash

################################################################################
# LGTM Stack Management Script
# Manages: Prometheus, node_exporter, Loki, Promtail, Grafana
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Services managed by this script
SERVICES=("prometheus" "prometheus-node-exporter" "loki" "promtail" "grafana-server")

# Service display names
declare -A SERVICE_NAMES=(
    ["prometheus"]="Prometheus"
    ["prometheus-node-exporter"]="node_exporter"
    ["loki"]="Loki"
    ["promtail"]="Promtail"
    ["grafana-server"]="Grafana"
)

# Service ports
declare -A SERVICE_PORTS=(
    ["prometheus"]="9090"
    ["prometheus-node-exporter"]="9100"
    ["loki"]="3100"
    ["promtail"]="9080"
    ["grafana-server"]="3000"
)

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
    echo -e "${BLUE}==>${NC} $1"
}

################################################################################
# Check if running with sudo when needed
################################################################################
check_sudo() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "This command must be run with sudo"
        exit 1
    fi
}

################################################################################
# Status: Show status of all services
################################################################################
status() {
    log_section "LGTM Stack Status"
    echo ""
    
    # Check each service
    for service in "${SERVICES[@]}"; do
        local name="${SERVICE_NAMES[$service]}"
        local port="${SERVICE_PORTS[$service]}"
        
        # Check if installed
        if ! systemctl list-unit-files "$service.service" &>/dev/null; then
            echo -e "${RED}✗${NC} $name - not installed"
            continue
        fi
        
        # Check if enabled
        local enabled=""
        if systemctl is-enabled --quiet "$service" 2>/dev/null; then
            enabled="enabled"
        else
            enabled="disabled"
        fi
        
        # Check if running
        if systemctl is-active --quiet "$service"; then
            echo -e "${GREEN}✓${NC} $name (port $port) - running, $enabled"
        else
            echo -e "${RED}✗${NC} $name (port $port) - stopped, $enabled"
        fi
    done
    
    # Disk usage
    echo ""
    log_section "Data Directory Sizes"
    du -sh /var/lib/prometheus 2>/dev/null || echo "  Prometheus: (not found)"
    du -sh /var/lib/loki 2>/dev/null || echo "  Loki: (not found)"
    du -sh /var/lib/grafana 2>/dev/null || echo "  Grafana: (not found)"
    
    # Quick health checks
    echo ""
    log_section "Health Checks"
    
    # Prometheus
    if curl -s --max-time 2 http://localhost:9090/-/healthy 2>/dev/null | grep -q "Healthy"; then
        echo -e "${GREEN}✓${NC} Prometheus API responding"
    else
        echo -e "${RED}✗${NC} Prometheus API not responding"
    fi
    
    # node_exporter
    if curl -s --max-time 2 http://localhost:9100/metrics 2>/dev/null | head -1 | grep -q "HELP"; then
        echo -e "${GREEN}✓${NC} node_exporter metrics available"
    else
        echo -e "${RED}✗${NC} node_exporter not responding"
    fi
    
    # Loki
    if curl -s --max-time 2 http://localhost:3100/ready 2>/dev/null | grep -q "ready"; then
        echo -e "${GREEN}✓${NC} Loki ready"
    else
        echo -e "${RED}✗${NC} Loki not ready"
    fi
    
    # Grafana
    if curl -s --max-time 2 http://localhost:3000/api/health 2>/dev/null | grep -q "ok"; then
        echo -e "${GREEN}✓${NC} Grafana healthy"
    else
        echo -e "${RED}✗${NC} Grafana not responding"
    fi
}

################################################################################
# Start: Start all services
################################################################################
start_services() {
    check_sudo
    log_section "Starting LGTM services..."
    
    for service in "${SERVICES[@]}"; do
        local name="${SERVICE_NAMES[$service]}"
        if systemctl is-active --quiet "$service"; then
            log_info "$name is already running"
        else
            log_info "Starting $name..."
            systemctl start "$service"
        fi
    done
    
    sleep 2
    log_info "All services started"
}

################################################################################
# Stop: Stop all services
################################################################################
stop_services() {
    check_sudo
    log_section "Stopping LGTM services..."
    
    # Stop in reverse order (Grafana first, then data stores)
    for service in $(echo "${SERVICES[@]}" | tac -s ' '); do
        local name="${SERVICE_NAMES[$service]}"
        if systemctl is-active --quiet "$service"; then
            log_info "Stopping $name..."
            systemctl stop "$service"
        else
            log_info "$name is already stopped"
        fi
    done
    
    log_info "All services stopped"
}

################################################################################
# Restart: Restart all services
################################################################################
restart_services() {
    check_sudo
    log_section "Restarting LGTM services..."
    
    for service in "${SERVICES[@]}"; do
        local name="${SERVICE_NAMES[$service]}"
        log_info "Restarting $name..."
        systemctl restart "$service"
    done
    
    sleep 2
    log_info "All services restarted"
}

################################################################################
# Logs: Tail logs for a service or all services
################################################################################
show_logs() {
    local target="$1"
    local lines="${2:-100}"
    
    if [ -z "$target" ] || [ "$target" = "all" ]; then
        # Show logs for all services
        log_section "Tailing logs for all LGTM services..."
        journalctl -u prometheus -u prometheus-node-exporter -u loki -u promtail -u grafana-server -f
    else
        # Map friendly names to service names
        case "$target" in
            prometheus|prom)
                target="prometheus"
                ;;
            node_exporter|node|exporter)
                target="prometheus-node-exporter"
                ;;
            loki)
                target="loki"
                ;;
            promtail)
                target="promtail"
                ;;
            grafana|graf)
                target="grafana-server"
                ;;
            *)
                log_error "Unknown service: $target"
                echo "Available: prometheus, node_exporter, loki, promtail, grafana"
                exit 1
                ;;
        esac
        
        log_section "Tailing logs for $target..."
        journalctl -u "$target" -f
    fi
}

################################################################################
# Test: Run health and connectivity tests
################################################################################
run_tests() {
    log_section "Running LGTM Stack Tests"
    echo ""
    
    local all_ok=true
    
    # Test 1: Prometheus health
    echo "1. Prometheus health check..."
    local prom_health
    prom_health=$(curl -s --max-time 5 http://localhost:9090/-/healthy 2>/dev/null)
    if echo "$prom_health" | grep -q "Healthy"; then
        echo -e "   ${GREEN}✓${NC} Prometheus is healthy"
    else
        echo -e "   ${RED}✗${NC} Prometheus health check failed"
        all_ok=false
    fi
    
    # Test 2: Prometheus can scrape node_exporter
    echo "2. Prometheus targets..."
    local targets
    targets=$(curl -s --max-time 5 'http://localhost:9090/api/v1/targets' 2>/dev/null)
    if echo "$targets" | grep -q '"health":"up"'; then
        local up_count
        up_count=$(echo "$targets" | grep -o '"health":"up"' | wc -l)
        echo -e "   ${GREEN}✓${NC} $up_count target(s) are UP"
    else
        echo -e "   ${RED}✗${NC} No healthy targets found"
        all_ok=false
    fi
    
    # Test 3: node_exporter metrics
    echo "3. node_exporter metrics..."
    local metrics
    metrics=$(curl -s --max-time 5 http://localhost:9100/metrics 2>/dev/null | head -20)
    if echo "$metrics" | grep -q "node_"; then
        echo -e "   ${GREEN}✓${NC} node_exporter serving metrics"
        
        # Check for hardware monitoring
        if curl -s --max-time 5 http://localhost:9100/metrics 2>/dev/null | grep -q "node_hwmon"; then
            echo -e "   ${GREEN}✓${NC} Hardware sensors (hwmon) available"
        else
            echo -e "   ${YELLOW}○${NC} Hardware sensors (hwmon) not available"
        fi
    else
        echo -e "   ${RED}✗${NC} node_exporter not responding"
        all_ok=false
    fi
    
    # Test 4: Loki ready
    echo "4. Loki readiness..."
    local loki_ready
    loki_ready=$(curl -s --max-time 5 http://localhost:3100/ready 2>/dev/null)
    if echo "$loki_ready" | grep -q "ready"; then
        echo -e "   ${GREEN}✓${NC} Loki is ready"
    else
        echo -e "   ${RED}✗${NC} Loki is not ready"
        all_ok=false
    fi
    
    # Test 5: Promtail pushing to Loki
    echo "5. Promtail status..."
    if systemctl is-active --quiet promtail; then
        echo -e "   ${GREEN}✓${NC} Promtail is running"
        
        # Check Promtail targets
        local promtail_targets
        promtail_targets=$(curl -s --max-time 5 http://localhost:9080/targets 2>/dev/null)
        if [ -n "$promtail_targets" ]; then
            echo -e "   ${GREEN}✓${NC} Promtail targets endpoint accessible"
        fi
    else
        echo -e "   ${RED}✗${NC} Promtail is not running"
        all_ok=false
    fi
    
    # Test 6: Grafana health
    echo "6. Grafana health..."
    local grafana_health
    grafana_health=$(curl -s --max-time 5 http://localhost:3000/api/health 2>/dev/null)
    if echo "$grafana_health" | grep -q '"database":"ok"'; then
        echo -e "   ${GREEN}✓${NC} Grafana is healthy"
    else
        echo -e "   ${RED}✗${NC} Grafana health check failed"
        all_ok=false
    fi
    
    # Test 7: Grafana datasources
    echo "7. Grafana datasources..."
    # Note: This requires auth, so we just check if provisioning file exists
    if [ -f /etc/grafana/provisioning/datasources/lgtm.yml ]; then
        echo -e "   ${GREEN}✓${NC} Datasources provisioning file exists"
    else
        echo -e "   ${YELLOW}○${NC} Datasources not provisioned via file"
    fi
    
    # Summary
    echo ""
    if [ "$all_ok" = true ]; then
        echo -e "${GREEN}All tests passed!${NC}"
    else
        echo -e "${YELLOW}Some tests failed - check output above${NC}"
    fi
    
    # URLs
    echo ""
    log_section "Service URLs"
    echo "  Prometheus:  http://localhost:9090"
    echo "  Grafana:     http://localhost:3000  (admin/admin)"
    echo "  Loki:        http://localhost:3100"
}

################################################################################
# Usage information
################################################################################
usage() {
    cat << EOF
Usage: $0 <command> [options]

Commands:
    status              Show status of all services
    start               Start all services (requires sudo)
    stop                Stop all services (requires sudo)
    restart             Restart all services (requires sudo)
    logs [service]      Tail logs (all services or specific one)
    test                Run health and connectivity tests

Log targets:
    all, prometheus, node_exporter, loki, promtail, grafana

Examples:
    $0 status                    # Check all services
    $0 logs                      # Tail all service logs
    $0 logs prometheus           # Tail only Prometheus logs
    $0 logs grafana              # Tail only Grafana logs
    sudo $0 restart              # Restart everything
    $0 test                      # Run health checks

Service Ports:
    Prometheus:     9090
    node_exporter:  9100
    Loki:           3100
    Promtail:       9080
    Grafana:        3000

EOF
}

################################################################################
# Main
################################################################################
main() {
    if [ $# -eq 0 ]; then
        usage
        exit 1
    fi
    
    case "$1" in
        status)
            status
            ;;
        start)
            start_services
            ;;
        stop)
            stop_services
            ;;
        restart)
            restart_services
            ;;
        logs)
            show_logs "$2" "$3"
            ;;
        test)
            run_tests
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            log_error "Unknown command: $1"
            echo ""
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
