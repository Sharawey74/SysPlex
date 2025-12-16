#!/usr/bin/env bash
# docker-entrypoint.sh
# Entrypoint script for System Monitor container

set -e

echo "=================================================="
echo "  System Monitor - Docker Container Starting"
echo "=================================================="
echo ""

# Display environment info
echo "📊 Environment Information:"
echo "  - Container Hostname: $(hostname)"
echo "  - Python Version: $(python3 --version)"
echo "  - Working Directory: $(pwd)"
echo ""

# Check if host paths are mounted
echo "🔍 Checking Host Mounts:"
if [ -d "$HOST_PROC" ] && [ "$(ls -A $HOST_PROC 2>/dev/null)" ]; then
    echo "  ✅ Host /proc mounted at: $HOST_PROC"
    echo "     Sample: $(ls $HOST_PROC | head -n 3 | tr '\n' ' ')"
else
    echo "  ⚠️  Host /proc not accessible at: $HOST_PROC"
fi

if [ -d "$HOST_SYS" ] && [ "$(ls -A $HOST_SYS 2>/dev/null)" ]; then
    echo "  ✅ Host /sys mounted at: $HOST_SYS"
else
    echo "  ⚠️  Host /sys not accessible at: $HOST_SYS"
fi

if [ -d "$HOST_DEV" ] && [ "$(ls -A $HOST_DEV 2>/dev/null)" ]; then
    echo "  ✅ Host /dev mounted at: $HOST_DEV"
else
    echo "  ⚠️  Host /dev not accessible at: $HOST_DEV"
fi
echo ""

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p /app/data/metrics/temp
mkdir -p /app/data/logs
mkdir -p /app/data/alerts
mkdir -p /app/reports/html
mkdir -p /app/reports/markdown
echo "  ✅ Directories created"
echo ""

# Initialize alerts file if it doesn't exist
if [ ! -f /app/data/alerts/alerts.json ]; then
    echo '{"alerts": []}' > /app/data/alerts/alerts.json
    echo "  ✅ Initialized alerts.json"
fi

# Export environment variables for child scripts
export PROC_PATH="${HOST_PROC:-/proc}"
export SYS_PATH="${HOST_SYS:-/sys}"
export DEV_PATH="${HOST_DEV:-/dev}"

# Run based on command argument
case "${1:-web}" in
    web)
        echo "🌐 Starting System Monitor Web Dashboard..."
        echo "=================================================="
        echo ""
        
        # Run metrics collection once on startup
        echo "📊 Collecting initial metrics..."
        bash /app/scripts/main_monitor.sh || echo "⚠️  Initial metrics collection failed (will use host data)"
        echo ""
        
        # Important note about host monitoring
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "ℹ️  Docker Hardware Access Limitation"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Docker cannot access hardware sensors (temp, fans)."
        echo "For FULL metrics including temperature/GPU data:"
        echo ""
        echo "  Run on host (WSL2):"
        echo "  $ cd /mnt/c/Users/DELL/Desktop/system-monitor-project-Batch/scripts"
        echo "  $ bash host_monitor_loop.sh"
        echo ""
        echo "Docker will automatically read the shared data file."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        # Start web dashboard (display only, no background monitoring)
        echo "🚀 Starting Flask web server on 0.0.0.0:5000"
        echo "   Access at: http://localhost:5000"
        echo ""
        exec python3 /app/dashboard_web.py --host 0.0.0.0 --port 5000
        ;;
    
    monitor)
        echo "📊 Running metrics collection only (no web dashboard)..."
        exec bash /app/scripts/main_monitor.sh
        ;;
    
    continuous)
        echo "♻️  Running continuous metrics collection..."
        while true; do
            bash /app/scripts/main_monitor.sh
            sleep 5
        done
        ;;
    
    bash)
        echo "🐚 Starting interactive bash shell..."
        exec /bin/bash
        ;;
    
    *)
        echo "❌ Unknown command: $1"
        echo "Available commands: web, monitor, continuous, bash"
        exit 1
        ;;
esac
