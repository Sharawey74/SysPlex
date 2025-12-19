#!/usr/bin/env bash
# Host Monitoring Loop - Continuous metrics collection
# Refactored from scripts/host_monitor_loop.sh
# Runs on WSL2/Host with full hardware access

set -euo pipefail

echo "=================================================="
echo "  Host System Monitor - Continuous Collection"
echo "=================================================="
echo ""
echo "Running on: $(hostname)"
echo "Kernel: $(uname -r)"
echo "Platform: $(uname -s)"
echo ""
echo "This script collects system metrics with full hardware access."
echo "Data is written to: Host/output/latest.json"
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MAIN_MONITOR="${HOST_ROOT}/scripts/main_monitor.sh"

# Make main monitor executable
chmod +x "${MAIN_MONITOR}" 2>/dev/null || true

# Counter for logging
ITERATION=0
INTERVAL=2  # seconds (matches dashboard refresh rate)

# Trap Ctrl+C for clean exit
trap 'echo ""; echo "Monitoring stopped by user"; exit 0' SIGINT SIGTERM

while true; do
    ITERATION=$((ITERATION + 1))
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "[$TIMESTAMP] Iteration #$ITERATION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Run monitoring
    if bash "${MAIN_MONITOR}"; then
        echo "[$TIMESTAMP] ✅ Collection successful"
    else
        echo "[$TIMESTAMP] ⚠️  Collection completed with warnings"
    fi
    
    echo ""
    echo "[$TIMESTAMP] Waiting ${INTERVAL} seconds until next collection..."
    echo ""
    
    sleep ${INTERVAL}
done
