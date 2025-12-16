#!/bin/bash
# Diagnostic script to troubleshoot Native Go Agent startup issues
# Run this when start-universal.sh gets stuck on "Waiting for Native Agent..."

echo "============================================"
echo "  Native Go Agent Diagnostic Tool"
echo "============================================"
echo ""

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST2_DIR="$PROJECT_ROOT/Host2"

# Detect platform
if grep -qi microsoft /proc/version 2>/dev/null; then
    PLATFORM="WSL2"
    NATIVE_BINARY="$HOST2_DIR/bin/host-agent-windows.exe"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    PLATFORM="Windows"
    NATIVE_BINARY="$HOST2_DIR/bin/host-agent-windows.exe"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macOS"
    NATIVE_BINARY="$HOST2_DIR/bin/host-agent-macos"
else
    PLATFORM="Linux"
    NATIVE_BINARY="$HOST2_DIR/bin/host-agent-linux"
fi

echo "Detected Platform: $PLATFORM"
echo "Expected Binary: $NATIVE_BINARY"
echo ""

# Check 1: Binary exists
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[CHECK 1] Binary File Existence"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -f "$NATIVE_BINARY" ]; then
    echo "✓ Binary found: $NATIVE_BINARY"
    ls -lh "$NATIVE_BINARY"
    echo ""
else
    echo "✗ FAILED: Binary not found at $NATIVE_BINARY"
    echo ""
    echo "SOLUTION: Run this command to build it:"
    echo "  cd Host2 && bash build.sh"
    echo ""
    exit 1
fi

# Check 2: Binary permissions (Linux/macOS)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[CHECK 2] Binary Permissions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ "$PLATFORM" != "Windows" ]] && [[ "$PLATFORM" != "WSL2" ]]; then
    if [ -x "$NATIVE_BINARY" ]; then
        echo "✓ Binary is executable"
    else
        echo "⚠ WARNING: Binary not executable"
        echo "SOLUTION: Run this command:"
        echo "  chmod +x $NATIVE_BINARY"
        chmod +x "$NATIVE_BINARY"
        echo "✓ Fixed! Permissions set"
    fi
else
    echo "⚠ Skipped (Windows platform)"
fi
echo ""

# Check 3: Windows Security Block (WSL2 or Windows)
if [[ "$PLATFORM" == "Windows" ]] || [[ "$PLATFORM" == "WSL2" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "[CHECK 3] Windows Security Block"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚠ Windows may have blocked this file!"
    echo ""
    echo "SOLUTION: Right-click the file → Properties → Unblock"
    echo "File location:"
    if [[ "$PLATFORM" == "WSL2" ]]; then
        echo "  $(wslpath -w "$NATIVE_BINARY")"
    else
        echo "  $NATIVE_BINARY"
    fi
    echo ""
    echo "OR run this PowerShell command (as Administrator):"
    if [[ "$PLATFORM" == "WSL2" ]]; then
        echo "  Unblock-File -Path '$(wslpath -w "$NATIVE_BINARY")'"
    else
        echo "  Unblock-File -Path '$NATIVE_BINARY'"
    fi
    echo ""
fi

# Check 4: Port availability
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[CHECK 4] Port 8889 Availability"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if command -v netstat &> /dev/null; then
    if netstat -an | grep -q ":8889.*LISTEN"; then
        echo "⚠ WARNING: Port 8889 already in use!"
        echo ""
        echo "Process using port 8889:"
        netstat -ano | grep ":8889.*LISTEN" || true
        echo ""
        echo "SOLUTION: Kill the process or use a different port"
    else
        echo "✓ Port 8889 is available"
    fi
elif command -v ss &> /dev/null; then
    if ss -tuln | grep -q ":8889"; then
        echo "⚠ WARNING: Port 8889 already in use!"
        ss -tuln | grep ":8889"
    else
        echo "✓ Port 8889 is available"
    fi
else
    echo "⚠ Skipped (netstat/ss not available)"
fi
echo ""

# Check 5: Test run the binary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[CHECK 5] Test Binary Execution"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Attempting to start the Native Agent..."
echo ""

# Kill any existing instance first
pkill -f "host-agent" 2>/dev/null || true
sleep 1

if [[ "$PLATFORM" == "WSL2" ]]; then
    # WSL2: Start Windows binary
    echo "Starting via Windows (WSL2)..."
    powershell.exe -Command "Start-Process '$(wslpath -w "$NATIVE_BINARY")'" &
    sleep 5
else
    # Native execution
    echo "Starting natively..."
    "$NATIVE_BINARY" > /tmp/native-agent-test.log 2>&1 &
    AGENT_PID=$!
    sleep 5
fi

# Test health endpoint
echo "Testing health endpoint (http://localhost:8889/health)..."
echo ""

if curl -s http://localhost:8889/health > /dev/null 2>&1; then
    echo "✓ SUCCESS! Native Agent is running properly!"
    echo ""
    curl -s http://localhost:8889/health | head -10
    echo ""
elif [[ "$PLATFORM" == "WSL2" ]] && curl.exe -s http://localhost:8889/health > /dev/null 2>&1; then
    echo "✓ SUCCESS! Native Agent is running (via Windows network)!"
    echo ""
    curl.exe -s http://localhost:8889/health | head -10
    echo ""
else
    echo "✗ FAILED: Native Agent did not start!"
    echo ""
    echo "Checking logs..."
    if [ -f "/tmp/native-agent-test.log" ]; then
        echo "━━━━ Error Log ━━━━"
        cat /tmp/native-agent-test.log
        echo "━━━━━━━━━━━━━━━━━━━"
    fi
    echo ""
    echo "POSSIBLE CAUSES:"
    echo "  1. Antivirus blocking execution"
    echo "  2. Windows Security blocked the file (needs Unblock)"
    echo "  3. Missing dependencies (unlikely for Go binaries)"
    echo "  4. Firewall blocking port 8889"
    echo "  5. Binary corruption (try rebuilding)"
    echo ""
    echo "SOLUTIONS:"
    echo "  1. Add exception to antivirus"
    echo "  2. Right-click binary → Properties → Unblock"
    echo "  3. Run as Administrator"
    echo "  4. Check Windows Firewall settings"
    echo "  5. Rebuild: cd Host2 && bash build.sh"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Diagnostic Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "All checks passed! The Native Agent should work."
echo ""
echo "If start-universal.sh still hangs, try running the binary manually:"
if [[ "$PLATFORM" == "WSL2" ]]; then
    echo "  powershell.exe -Command \"Start-Process '$(wslpath -w "$NATIVE_BINARY")'\""
else
    echo "  $NATIVE_BINARY"
fi
echo ""
