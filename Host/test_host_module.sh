#!/usr/bin/env bash
# Quick Test Script for Host Module
# Tests all monitors and API functionality

set -e

echo "=================================================="
echo "  Host Module Verification Test"
echo "=================================================="
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_ROOT="${SCRIPT_DIR}"
SCRIPTS_DIR="${HOST_ROOT}/scripts"
OUTPUT_DIR="${HOST_ROOT}/output"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
test_script() {
    local script_name="$1"
    local script_path="${SCRIPTS_DIR}/${script_name}"
    
    echo -n "Testing ${script_name}... "
    
    if [ ! -f "${script_path}" ]; then
        echo -e "${RED}FAIL${NC} (not found)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    # Make executable
    chmod +x "${script_path}" 2>/dev/null || true
    
    # Run script
    if output=$(bash "${script_path}" 2>&1); then
        # Check if output is valid JSON
        if echo "$output" | python3 -m json.tool >/dev/null 2>&1; then
            echo -e "${GREEN}PASS${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        else
            echo -e "${YELLOW}WARN${NC} (not JSON)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    else
        echo -e "${RED}FAIL${NC} (execution error)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

echo "1️⃣  Testing Individual Monitors"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

test_script "system_monitor.sh"
test_script "cpu_monitor.sh"
test_script "memory_monitor.sh"
test_script "disk_monitor.sh"
test_script "network_monitor.sh"
test_script "temperature_monitor.sh"
test_script "gpu_monitor.sh"
test_script "fan_monitor.sh"
test_script "smart_monitor.sh"

echo ""
echo "2️⃣  Testing Main Orchestrator"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -n "Testing main_monitor.sh... "
if bash "${SCRIPTS_DIR}/main_monitor.sh" >/dev/null 2>&1; then
    if [ -f "${OUTPUT_DIR}/latest.json" ]; then
        if python3 -m json.tool "${OUTPUT_DIR}/latest.json" >/dev/null 2>&1; then
            echo -e "${GREEN}PASS${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}FAIL${NC} (invalid JSON)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo -e "${RED}FAIL${NC} (no output file)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    echo -e "${RED}FAIL${NC} (execution error)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "3️⃣  Checking Output File"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "${OUTPUT_DIR}/latest.json" ]; then
    echo -e "${GREEN}✓${NC} Output file exists: ${OUTPUT_DIR}/latest.json"
    
    # Show summary
    echo ""
    echo "Sample output:"
    if command -v jq >/dev/null 2>&1; then
        jq -C '. | {timestamp, platform, cpu: .cpu.usage_percent, memory: .memory.usage_percent, gpu: .gpu.vendor}' "${OUTPUT_DIR}/latest.json" 2>/dev/null || cat "${OUTPUT_DIR}/latest.json" | head -20
    else
        cat "${OUTPUT_DIR}/latest.json" | head -20
    fi
else
    echo -e "${RED}✗${NC} Output file not found"
fi

echo ""
echo "4️⃣  Checking API Dependencies"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if python3 -c "import fastapi" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} FastAPI installed"
else
    echo -e "${YELLOW}⚠${NC} FastAPI not installed (run: pip install -r Host/api/requirements.txt)"
fi

if python3 -c "import uvicorn" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Uvicorn installed"
else
    echo -e "${YELLOW}⚠${NC} Uvicorn not installed (run: pip install -r Host/api/requirements.txt)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Failed: ${RED}${TESTS_FAILED}${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Run continuous monitoring: bash Host/loop/host_monitor_loop.sh"
    echo "  2. Start API server: python3 Host/api/server.py"
    echo "  3. Access metrics: curl http://localhost:9999/metrics"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi
