#!/bin/bash
# stop-host-api.sh
# Stops Host API running on native OS

set -e

echo "=================================================="
echo "  Stopping Host API"
echo "=================================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PID_FILE="/tmp/host-api.pid"

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "Stopping Host API (PID: $PID)..."
        kill "$PID"
        sleep 2
        
        # Force kill if still running
        if kill -0 "$PID" 2>/dev/null; then
            echo "Force killing Host API..."
            kill -9 "$PID"
        fi
        
        rm -f "$PID_FILE"
        echo -e "${GREEN}✓${NC} Host API stopped"
    else
        echo "Host API not running (PID $PID not found)"
        rm -f "$PID_FILE"
    fi
else
    echo "No PID file found at $PID_FILE"
    
    # Try to find and kill by process name
    if pgrep -f "python3.*server.py" > /dev/null; then
        echo "Found running Host API process, stopping..."
        pkill -f "python3.*server.py"
        echo -e "${GREEN}✓${NC} Host API stopped"
    else
        echo "Host API not running"
    fi
fi

# Clean up log file (optional)
# rm -f /tmp/host-api.log

echo "Done"
