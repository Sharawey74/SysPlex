#!/bin/bash
# start-host-api.sh
# Starts Host API on native OS for real hardware monitoring
# Run this BEFORE starting Docker containers

set -e

echo "=================================================="
echo "  Starting Host API (Native OS)"
echo "=================================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check if already running
if curl -s http://localhost:8888/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Host API already running on port 8888"
    exit 0
fi

echo -e "${YELLOW}►${NC} Checking Python dependencies..."
if ! python3 -c "import fastapi, uvicorn" 2>/dev/null; then
    echo -e "${YELLOW}►${NC} Installing fastapi and uvicorn..."
    pip3 install --break-system-packages fastapi uvicorn 2>/dev/null || \
    pip3 install --user fastapi uvicorn || {
        echo -e "${RED}✗${NC} Failed to install dependencies"
        echo "Please install manually: pip3 install fastapi uvicorn"
        exit 1
    }
fi

echo -e "${YELLOW}►${NC} Generating initial metrics..."
cd "$SCRIPT_DIR/Host/scripts"
bash main_monitor.sh

echo -e "${YELLOW}►${NC} Starting Host API..."
cd "$SCRIPT_DIR/Host/api"
nohup python3 server.py > /tmp/host-api.log 2>&1 &
HOST_PID=$!
echo $HOST_PID > /tmp/host-api.pid

echo -e "${GREEN}✓${NC} Host API started (PID: $HOST_PID)"

# Wait for API to be ready
echo -e "${YELLOW}►${NC} Waiting for API to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:8888/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Host API is ready!"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Host API:    http://localhost:8888"
        echo "  Health:      http://localhost:8888/health"
        echo "  Metrics:     http://localhost:8888/metrics"
        echo "  PID File:    /tmp/host-api.pid"
        echo "  Logs:        /tmp/host-api.log"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        exit 0
    fi
    sleep 1
    echo -n "."
done

echo -e "\n${RED}✗${NC} Host API failed to start"
echo "Check logs: tail -f /tmp/host-api.log"
exit 1
