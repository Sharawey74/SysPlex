#!/usr/bin/env bash
# Host Monitoring Loop - Runs on WSL2 with full hardware access
# This script collects metrics every 60 seconds and writes to shared volume

echo "=========================================="
echo "  System Monitor - Host Collector"
echo "=========================================="
echo ""
echo "Running on: $(hostname)"
echo "Kernel: $(uname -r)"
echo "Platform: $(uname -s)"
echo ""
echo "This script collects system metrics with full hardware access."
echo "Data is written to: data/metrics/current.json"
echo "Docker dashboard reads from this file."
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_ROOT}/scripts"

# Counter for logging
ITERATION=0

while true; do
    ITERATION=$((ITERATION + 1))
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$TIMESTAMP] Iteration #$ITERATION - Collecting metrics..."
    
    # Run monitoring
    if ./main_monitor.sh 2>&1 | head -5; then
        echo "[$TIMESTAMP] ✅ Collection successful"
    else
        echo "[$TIMESTAMP] ⚠️  Collection completed with warnings"
    fi
    
    echo "[$TIMESTAMP] Waiting 60 seconds..."
    echo ""
    
    sleep 60
done
