#!/bin/bash

################################################################################
# Log Viewing Helper Script for Mac Mini Server
################################################################################

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}================================${NC}"
echo -e "${CYAN}Mac Mini Server - Log Viewer${NC}"
echo -e "${CYAN}================================${NC}"
echo ""
echo "Select which logs you'd like to view:"
echo ""
echo "  1) System Log (general system messages)"
echo "  2) Docker Logs (Docker Desktop logs)"
echo "  3) Apache/Nginx Access Logs (if running locally)"
echo "  4) Apache/Nginx Error Logs (if running locally)"
echo "  5) System Diagnostics (kernel messages)"
echo "  6) Install Logs (software installation)"
echo "  7) Security Logs (auth and security events)"
echo "  8) All Docker Container Logs"
echo "  9) Network Statistics (live)"
echo " 10) Disk Usage and I/O"
echo " 11) Process Monitor (top processes)"
echo " 12) Firewall Logs"
echo ""
echo "  0) Exit"
echo ""
read -p "Enter your choice [0-12]: " choice

case $choice in
    1)
        echo -e "${GREEN}Streaming system log (errors and failures)...${NC}"
        echo "Press Ctrl+C to exit"
        log stream --predicate 'eventMessage contains "error" OR eventMessage contains "fail"' --style syslog
        ;;
    2)
        echo -e "${GREEN}Tailing Docker logs...${NC}"
        echo "Press Ctrl+C to exit"
        tail -f ~/Library/Containers/com.docker.docker/Data/log/vm/dockerd.log 2>/dev/null || \
        echo "Docker logs not found. Is Docker Desktop installed and running?"
        ;;
    3)
        echo -e "${GREEN}Checking for Apache/Nginx access logs...${NC}"
        if [ -f /usr/local/var/log/nginx/access.log ]; then
            tail -f /usr/local/var/log/nginx/access.log
        elif docker ps --format '{{.Names}}' | grep -q nginx; then
            NGINX_CONTAINER=$(docker ps --format '{{.Names}}' | grep nginx | head -1)
            echo "Showing logs for container: $NGINX_CONTAINER"
            docker logs -f "$NGINX_CONTAINER"
        else
            echo "No nginx access logs found"
        fi
        ;;
    4)
        echo -e "${GREEN}Checking for Apache/Nginx error logs...${NC}"
        if [ -f /usr/local/var/log/nginx/error.log ]; then
            tail -f /usr/local/var/log/nginx/error.log
        elif docker ps --format '{{.Names}}' | grep -q nginx; then
            NGINX_CONTAINER=$(docker ps --format '{{.Names}}' | grep nginx | head -1)
            echo "Showing logs for container: $NGINX_CONTAINER"
            docker logs -f "$NGINX_CONTAINER" 2>&1 | grep -i error
        else
            echo "No nginx error logs found"
        fi
        ;;
    5)
        echo -e "${GREEN}Streaming system diagnostics (kernel messages)...${NC}"
        echo "Press Ctrl+C to exit"
        log stream --predicate 'processImagePath contains "kernel"' --style syslog
        ;;
    6)
        echo -e "${GREEN}Showing installation logs...${NC}"
        tail -f /var/log/install.log
        ;;
    7)
        echo -e "${GREEN}Streaming security logs...${NC}"
        echo "Press Ctrl+C to exit"
        log stream --predicate 'process == "authd" OR process == "SecurityAgent"' --style syslog
        ;;
    8)
        echo -e "${GREEN}Showing all Docker container logs...${NC}"
        if command -v docker &> /dev/null && docker ps -q | grep -q .; then
            docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
            echo ""
            read -p "Enter container name (or 'all' for all containers): " container_name
            if [ "$container_name" = "all" ]; then
                docker ps -q | xargs -L 1 docker logs --tail 50
            else
                docker logs -f "$container_name"
            fi
        else
            echo "No Docker containers running"
        fi
        ;;
    9)
        echo -e "${GREEN}Showing network statistics...${NC}"
        echo "Press Ctrl+C to exit"
        while true; do
            clear
            echo -e "${CYAN}Network Connections:${NC}"
            netstat -an | grep ESTABLISHED | head -20
            echo ""
            echo -e "${CYAN}Network Interface Stats:${NC}"
            netstat -ib
            sleep 5
        done
        ;;
    10)
        echo -e "${GREEN}Showing disk usage and I/O...${NC}"
        echo ""
        echo -e "${CYAN}Disk Usage:${NC}"
        df -h
        echo ""
        echo -e "${CYAN}Top Disk Space Users:${NC}"
        du -sh /* 2>/dev/null | sort -rh | head -10
        echo ""
        echo -e "${CYAN}Disk I/O Statistics (iostat):${NC}"
        iostat -d 2 5
        ;;
    11)
        echo -e "${GREEN}Showing top processes...${NC}"
        echo "Press Ctrl+C to exit"
        top -o cpu
        ;;
    12)
        echo -e "${GREEN}Streaming firewall logs...${NC}"
        echo "Press Ctrl+C to exit"
        log stream --predicate 'process == "socketfilterfw"' --style syslog
        ;;
    0)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo -e "${YELLOW}Invalid choice${NC}"
        ;;
esac
