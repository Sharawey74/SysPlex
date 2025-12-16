#!/bin/bash
# start-system-monitor.sh
# ALL-IN-ONE: Starts entire System Monitor
# 1. Host API on native OS (real hardware access)
# 2. Dashboard in Docker container (web interface)

set -e

echo "=================================================="
echo "  System Monitor - All-in-One Startup"
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

echo -e "${BLUE}[1/3]${NC} Checking Host API..."

# Check if Host API is already running
if curl -s http://localhost:8888/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Host API already running on port 8888"
else
    echo -e "${YELLOW}►${NC} Starting Host API on native OS..."
    
    # Check Python dependencies
    if ! python3 -c "import fastapi, uvicorn" 2>/dev/null; then
        echo -e "${YELLOW}►${NC} Installing Python dependencies (fastapi, uvicorn)..."
        pip3 install --break-system-packages fastapi uvicorn 2>/dev/null || \
        pip3 install --user fastapi uvicorn || {
            echo -e "${RED}✗${NC} Failed to install dependencies"
            echo "Please install manually: pip3 install fastapi uvicorn"
            exit 1
        }
        echo -e "${GREEN}✓${NC} Dependencies installed"
    fi
    
    # Generate initial metrics
    echo -e "${YELLOW}►${NC} Generating initial metrics..."
    cd "$PROJECT_ROOT/Host/scripts"
    if bash main_monitor.sh > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Metrics generated"
    else
        echo -e "${YELLOW}⚠${NC} Metrics generation had issues (will retry)"
    fi
    
    # Start Host API in background
    echo -e "${YELLOW}►${NC} Starting Host API server..."
    cd "$PROJECT_ROOT/Host/api"
    nohup python3 server.py > /tmp/host-api.log 2>&1 &
    HOST_API_PID=$!
    echo $HOST_API_PID > /tmp/host-api.pid
    
    echo -e "${GREEN}✓${NC} Host API started (PID: $HOST_API_PID)"
    
    # Wait for Host API to be ready
    echo -e "${YELLOW}►${NC} Waiting for Host API to be ready..."
    for i in {1..30}; do
        if curl -s http://localhost:8888/health > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} Host API is ready!"
            break
        fi
        sleep 1
        if [ $((i % 5)) -eq 0 ]; then
            echo -n " $i"
        else
            echo -n "."
        fi
    done
    echo ""
    
    # Final health check
    if ! curl -s http://localhost:8888/health > /dev/null 2>&1; then
        echo -e "${RED}✗${NC} Host API failed to start"
        echo "Check logs: tail -f /tmp/host-api.log"
        exit 1
    fi
fi

echo ""
echo -e "${BLUE}[2/3]${NC} Building Dashboard..."

# Start Dashboard container
cd "$PROJECT_ROOT"

# Stop existing container if running
echo -e "${YELLOW}►${NC} Stopping old containers..."
docker-compose down 2>/dev/null || true

# Build and start Dashboard
echo -e "${YELLOW}►${NC} Building and starting Dashboard container..."
if docker-compose up --build -d; then
    echo -e "${GREEN}✓${NC} Dashboard container started"
else
    echo -e "${RED}✗${NC} Dashboard failed to start"
    echo "Check logs: docker-compose logs"
    exit 1
fi

echo ""
echo -e "${BLUE}[3/3]${NC} Verifying system..."

# Wait for dashboard to be ready
echo -e "${YELLOW}►${NC} Waiting for Dashboard..."
for i in {1..20}; do
    if curl -s http://localhost:5000/api/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Dashboard is ready!"
        break
    fi
    sleep 1
    echo -n "."
done
echo ""

# Final verification
HOST_STATUS=$(curl -s http://localhost:8888/health 2>/dev/null || echo "failed")
DASH_STATUS=$(curl -s http://localhost:5000/api/health 2>/dev/null || echo "failed")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✓ SYSTEM MONITOR IS RUNNING!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "  ${GREEN}●${NC} Web Dashboard:     http://localhost:5000"
echo -e "  ${GREEN}●${NC} Host API:          http://localhost:8888"
echo -e "  ${GREEN}●${NC} API Metrics:       http://localhost:5000/api/metrics"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Status:"
echo -e "  Host API:    $(if [[ "$HOST_STATUS" != "failed" ]]; then echo -e "${GREEN}✓ Running${NC}"; else echo -e "${RED}✗ Failed${NC}"; fi)"
echo -e "  Dashboard:   $(if [[ "$DASH_STATUS" != "failed" ]]; then echo -e "${GREEN}✓ Running${NC}"; else echo -e "${RED}✗ Failed${NC}"; fi)"
echo ""
echo "Terminal Dashboard:"
echo -e "  ${BLUE}python3 dashboard_tui.py${NC}"
echo ""
echo "Logs:"
echo "  Host API:    tail -f /tmp/host-api.log"
echo "  Dashboard:   docker-compose logs -f"
echo ""
echo "To stop:"
echo "  bash stop-system-monitor.sh"
echo ""
