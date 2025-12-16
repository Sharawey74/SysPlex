#!/usr/bin/env bash
# Quick Start Script for Host Module
# Provides easy access to all Host monitoring functions

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_ROOT="${SCRIPT_DIR}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_banner() {
    echo ""
    echo "=================================================="
    echo "  🖥️  Host System Monitor - Quick Start"
    echo "=================================================="
    echo ""
}

show_menu() {
    echo "Select an option:"
    echo ""
    echo "  ${GREEN}1${NC}) Run monitoring once (single collection)"
    echo "  ${GREEN}2${NC}) Start continuous monitoring (60s loop)"
    echo "  ${GREEN}3${NC}) Start TCP API server (port 9999)"
    echo "  ${GREEN}4${NC}) View latest metrics (JSON)"
    echo "  ${GREEN}5${NC}) Test all monitors"
    echo "  ${GREEN}6${NC}) Install systemd service"
    echo "  ${GREEN}7${NC}) Install Python API dependencies"
    echo "  ${YELLOW}0${NC}) Exit"
    echo ""
    echo -n "Enter choice [0-7]: "
}

run_once() {
    echo ""
    echo "${BLUE}Running single metrics collection...${NC}"
    echo ""
    chmod +x "${HOST_ROOT}/scripts/main_monitor.sh"
    bash "${HOST_ROOT}/scripts/main_monitor.sh"
    echo ""
    echo "${GREEN}✅ Done! Output at: Host/output/latest.json${NC}"
}

run_loop() {
    echo ""
    echo "${BLUE}Starting continuous monitoring (Ctrl+C to stop)...${NC}"
    echo ""
    chmod +x "${HOST_ROOT}/loop/host_monitor_loop.sh"
    bash "${HOST_ROOT}/loop/host_monitor_loop.sh"
}

start_api() {
    echo ""
    echo "${BLUE}Starting TCP API server on port 9999...${NC}"
    echo ""
    
    # Check if dependencies installed
    if ! python3 -c "import fastapi" 2>/dev/null; then
        echo "${YELLOW}⚠️  FastAPI not installed. Install with option 7 first.${NC}"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi
    
    cd "${HOST_ROOT}/api"
    python3 server.py
}

view_metrics() {
    echo ""
    if [ ! -f "${HOST_ROOT}/output/latest.json" ]; then
        echo "${YELLOW}⚠️  No metrics file found. Run option 1 or 2 first.${NC}"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi
    
    if command -v jq >/dev/null 2>&1; then
        jq -C . "${HOST_ROOT}/output/latest.json" | less -R
    else
        cat "${HOST_ROOT}/output/latest.json" | less
    fi
}

test_monitors() {
    echo ""
    chmod +x "${HOST_ROOT}/test_host_module.sh"
    bash "${HOST_ROOT}/test_host_module.sh"
    echo ""
    read -p "Press Enter to continue..."
}

install_systemd() {
    echo ""
    echo "${BLUE}Installing systemd service...${NC}"
    echo ""
    
    local service_file="${HOST_ROOT}/service/host-monitor.service"
    local install_path="/etc/systemd/system/host-monitor.service"
    
    # Get current user
    local current_user=$(whoami)
    
    # Get absolute path
    local host_abs_path=$(cd "${HOST_ROOT}" && pwd)
    
    echo "Service will be installed for user: ${current_user}"
    echo "Host path: ${host_abs_path}"
    echo ""
    
    # Create temporary service file with correct paths
    local temp_service="/tmp/host-monitor.service"
    sed "s|/path/to/system-monitor-project-Batch/Host|${host_abs_path}|g" "${service_file}" > "${temp_service}"
    sed -i "s|User=%i|User=${current_user}|g" "${temp_service}"
    sed -i "s|Group=%i|Group=${current_user}|g" "${temp_service}"
    
    echo "Generated service file:"
    cat "${temp_service}"
    echo ""
    
    read -p "Install service? (requires sudo) [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        sudo cp "${temp_service}" "${install_path}"
        sudo systemctl daemon-reload
        echo ""
        echo "${GREEN}✅ Service installed!${NC}"
        echo ""
        echo "To enable and start:"
        echo "  sudo systemctl enable host-monitor"
        echo "  sudo systemctl start host-monitor"
        echo ""
        echo "To check status:"
        echo "  sudo systemctl status host-monitor"
    fi
    
    rm -f "${temp_service}"
    echo ""
    read -p "Press Enter to continue..."
}

install_dependencies() {
    echo ""
    echo "${BLUE}Installing Python API dependencies...${NC}"
    echo ""
    
    cd "${HOST_ROOT}/api"
    
    if command -v pip3 >/dev/null 2>&1; then
        pip3 install -r requirements.txt
        echo ""
        echo "${GREEN}✅ Dependencies installed!${NC}"
    else
        echo "${YELLOW}⚠️  pip3 not found. Please install Python 3 and pip.${NC}"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Main loop
while true; do
    clear
    show_banner
    show_menu
    read choice
    
    case $choice in
        1) run_once ;;
        2) run_loop ;;
        3) start_api ;;
        4) view_metrics ;;
        5) test_monitors ;;
        6) install_systemd ;;
        7) install_dependencies ;;
        0) echo ""; echo "Goodbye!"; exit 0 ;;
        *) echo "Invalid choice"; sleep 1 ;;
    esac
done
