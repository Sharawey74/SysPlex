#!/bin/bash
# stop-system-monitor.sh
# ALL-IN-ONE: Stops entire System Monitor cleanly

set -e

echo "=================================================="
echo "  System Monitor - Shutdown"
echo "=================================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get project root
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"

echo -e "${BLUE}[1/2]${NC} Stopping Dashboard container..."
cd "$PROJECT_ROOT"
if docker-compose down 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Dashboard stopped"
else
    echo -e "${YELLOW}⚠${NC} Dashboard may not have been running"
fi

echo ""
echo -e "${BLUE}[2/3]${NC} Stopping Host Monitor Loop..."

MONITOR_PID_FILE="/tmp/host-monitor-loop.pid"

if [ -f "$MONITOR_PID_FILE" ]; then
    MONITOR_PID=$(cat "$MONITOR_PID_FILE")
    if kill -0 "$MONITOR_PID" 2>/dev/null; then
        echo -e "${YELLOW}►${NC} Stopping Monitor Loop (PID: $MONITOR_PID)..."
        kill "$MONITOR_PID" 2>/dev/null || true
        sleep 2
        
        # Force kill if still running
        if kill -0 "$MONITOR_PID" 2>/dev/null; then
            echo -e "${YELLOW}►${NC} Force stopping Monitor Loop..."
            kill -9 "$MONITOR_PID" 2>/dev/null || true
        fi
        
        rm -f "$MONITOR_PID_FILE"
        echo -e "${GREEN}✓${NC} Monitor Loop stopped"
    else
        echo -e "${YELLOW}⚠${NC} Monitor Loop was not running"
        rm -f "$MONITOR_PID_FILE"
    fi
else
    echo -e "${YELLOW}⚠${NC} Monitor Loop PID file not found"
fi

echo ""
echo -e "${BLUE}[3/3]${NC} Stopping Host API..."

PID_FILE="/tmp/host-api.pid"

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo -e "${YELLOW}►${NC} Stopping Host API (PID: $PID)..."
        kill "$PID" 2>/dev/null || true
        sleep 2
        
        # Force kill if still running
        if kill -0 "$PID" 2>/dev/null; then
            echo -e "${YELLOW}►${NC} Force stopping Host API..."
            kill -9 "$PID" 2>/dev/null || true
        fi
        
        rm -f "$PID_FILE"
        echo -e "${GREEN}✓${NC} Host API stopped"
    else
        echo -e "${YELLOW}⚠${NC} Host API not running (PID $PID not found)"
        rm -f "$PID_FILE"
    fi
else
    echo -e "${YELLOW}►${NC} No PID file found, checking by port..."
    
    # Try to find and kill by port
    if command -v lsof > /dev/null 2>&1; then
        if lsof -ti:8888 > /dev/null 2>&1; then
            PID=$(lsof -ti:8888)
            echo -e "${YELLOW}►${NC} Found process on port 8888 (PID: $PID)"
            kill "$PID" 2>/dev/null || kill -9 "$PID" 2>/dev/null || true
            echo -e "${GREEN}✓${NC} Host API stopped"
        else
            echo -e "${YELLOW}⚠${NC} No process found on port 8888"
        fi
    else
        # Try pgrep as fallback
        if pgrep -f "python3.*server.py" > /dev/null; then
            echo -e "${YELLOW}►${NC} Found Host API process..."
            pkill -f "python3.*server.py" || pkill -9 -f "python3.*server.py" || true
            echo -e "${GREEN}✓${NC} Host API stopped"
        else
            echo -e "${YELLOW}⚠${NC} Host API not running"
        fi
    fi
fi

# Clean up stale files
rm -f /tmp/host-api.pid 2>/dev/null || true

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✓ SYSTEM MONITOR STOPPED${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To restart:"
echo "  bash start-system-monitor.sh"
echo ""
