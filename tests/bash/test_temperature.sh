#!/bin/bash
# Comprehensive Temperature Detection Test
# Tests BOTH Host API (bash) and Native Go Agent (Host2)
# Run this to diagnose why temperature shows 0°C

echo "============================================"
echo "  Temperature Detection Diagnostic"
echo "============================================"
echo ""

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test 1: Check Host API temperature script
echo -e "${BLUE}[TEST 1]${NC} Host API Temperature Detection (Bash)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "$PROJECT_ROOT/Host/scripts/temperature_monitor.sh" ]; then
    echo -e "${GREEN}✓${NC} Script found: Host/scripts/temperature_monitor.sh"
    echo ""
    echo "Running bash temperature script..."
    bash "$PROJECT_ROOT/Host/scripts/temperature_monitor.sh"
    echo ""
else
    echo -e "${RED}✗${NC} Script not found!"
fi

# Test 2: Check Native Go Agent
echo ""
echo -e "${BLUE}[TEST 2]${NC} Native Go Agent Temperature Detection"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Detect platform
if grep -qi microsoft /proc/version 2>/dev/null; then
    PLATFORM="WSL2"
    GO_BINARY="$PROJECT_ROOT/Host2/bin/host-agent-windows.exe"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macOS"
    GO_BINARY="$PROJECT_ROOT/Host2/bin/host-agent-macos"
else
    PLATFORM="Linux"
    GO_BINARY="$PROJECT_ROOT/Host2/bin/host-agent-linux"
fi

echo "Platform: $PLATFORM"
echo "Binary: $GO_BINARY"
echo ""

if [ -f "$GO_BINARY" ]; then
    echo -e "${GREEN}✓${NC} Go binary found"
    
    # Check if already running
    if curl -s http://localhost:8889/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Native Agent already running on port 8889"
        echo ""
        echo "Fetching metrics..."
        curl -s http://localhost:8889/metrics | python3 -m json.tool | grep -A 5 "temperature"
    else
        echo -e "${YELLOW}⚠${NC}  Native Agent not running. Start it first:"
        echo "  $GO_BINARY"
    fi
else
    echo -e "${RED}✗${NC} Go binary not found! Build it first:"
    echo "  cd Host2 && bash build.sh"
fi

# Test 3: Direct method testing
echo ""
echo -e "${BLUE}[TEST 3]${NC} Direct Method Testing"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Method 1: WMI (Windows/WSL2)
echo ""
echo -e "${YELLOW}Method 1:${NC} WMI (Windows)"
if grep -qi microsoft /proc/version 2>/dev/null || [[ "$OSTYPE" == "msys" ]]; then
    if command -v powershell.exe &> /dev/null; then
        echo "Testing WMI via PowerShell..."
        powershell.exe -Command "(Get-WmiObject -Namespace root/wmi -Class MSAcpi_ThermalZoneTemperature | Select-Object -First 1).CurrentTemperature" 2>/dev/null | head -1
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓${NC} WMI temperature available"
        else
            echo -e "${RED}✗${NC} WMI temperature NOT available"
            echo "   Reason: ACPI thermal zones might not be exposed by your motherboard"
        fi
    else
        echo -e "${YELLOW}⚠${NC}  PowerShell not available"
    fi
else
    echo -e "${YELLOW}⚠${NC}  Skipped (not Windows)"
fi

# Method 2: lm-sensors (Linux)
echo ""
echo -e "${YELLOW}Method 2:${NC} lm-sensors (Linux)"
if command -v sensors &> /dev/null; then
    echo "Testing lm-sensors..."
    sensors | grep -i "core\|cpu\|package" | head -5
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} lm-sensors temperature available"
    else
        echo -e "${YELLOW}⚠${NC}  lm-sensors installed but no CPU sensors detected"
    fi
else
    echo -e "${YELLOW}⚠${NC}  lm-sensors not installed"
    echo "   Install: sudo apt-get install lm-sensors && sudo sensors-detect"
fi

# Method 3: /sys/class/thermal (Linux)
echo ""
echo -e "${YELLOW}Method 3:${NC} /sys/class/thermal (Linux)"
if [ -d "/sys/class/thermal" ]; then
    echo "Thermal zones found:"
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        if [ -f "$zone" ]; then
            zone_name=$(basename $(dirname "$zone"))
            temp=$(cat "$zone" 2>/dev/null || echo "0")
            temp_celsius=$((temp / 1000))
            echo "  $zone_name: ${temp_celsius}°C"
        fi
    done
else
    echo -e "${YELLOW}⚠${NC}  /sys/class/thermal not available"
fi

# Method 4: /sys/class/hwmon (Linux)
echo ""
echo -e "${YELLOW}Method 4:${NC} /sys/class/hwmon (Linux)"
if [ -d "/sys/class/hwmon" ]; then
    echo "Hardware monitors found:"
    for hwmon in /sys/class/hwmon/hwmon*/name; do
        if [ -f "$hwmon" ]; then
            hwmon_name=$(cat "$hwmon" 2>/dev/null)
            hwmon_dir=$(dirname "$hwmon")
            echo "  $hwmon_name:"
            
            # Find temperature files
            for temp_input in "$hwmon_dir"/temp*_input; do
                if [ -f "$temp_input" ]; then
                    temp_label_file="${temp_input%_input}_label"
                    if [ -f "$temp_label_file" ]; then
                        label=$(cat "$temp_label_file" 2>/dev/null)
                    else
                        label=$(basename "$temp_input")
                    fi
                    
                    temp=$(cat "$temp_input" 2>/dev/null || echo "0")
                    temp_celsius=$((temp / 1000))
                    echo "    $label: ${temp_celsius}°C"
                fi
            done
        fi
    done
else
    echo -e "${YELLOW}⚠${NC}  /sys/class/hwmon not available"
fi

# Method 5: acpi (Linux)
echo ""
echo -e "${YELLOW}Method 5:${NC} acpi command (Linux)"
if command -v acpi &> /dev/null; then
    echo "Testing acpi..."
    acpi -t 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} acpi temperature available"
    else
        echo -e "${YELLOW}⚠${NC}  acpi command failed"
    fi
else
    echo -e "${YELLOW}⚠${NC}  acpi not installed"
    echo "   Install: sudo apt-get install acpi"
fi

# Test 4: Recommendations
echo ""
echo -e "${BLUE}[TEST 4]${NC} Recommendations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if grep -qi microsoft /proc/version 2>/dev/null; then
    # WSL2 recommendations
    echo -e "${CYAN}WSL2 Detected${NC}"
    echo ""
    echo "Best options for WSL2:"
    echo "  1. Run PowerShell script (most reliable):"
    echo "     pwsh test_temperature_windows.ps1"
    echo ""
    echo "  2. Enable WMI access in WSL2:"
    echo "     powershell.exe -Command 'Get-WmiObject -Namespace root/wmi -Class MSAcpi_ThermalZoneTemperature'"
    echo ""
    echo "  3. Install third-party tools on Windows:"
    echo "     - LibreHardwareMonitor"
    echo "     - Core Temp"
    echo "     - HWiNFO"
    echo ""
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux recommendations
    echo -e "${CYAN}Linux Detected${NC}"
    echo ""
    echo "Install temperature monitoring tools:"
    echo "  sudo apt-get update"
    echo "  sudo apt-get install lm-sensors acpi"
    echo "  sudo sensors-detect  # Answer YES to all"
    echo "  sensors  # Test"
    echo ""
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS recommendations
    echo -e "${CYAN}macOS Detected${NC}"
    echo ""
    echo "Install temperature monitoring tools:"
    echo "  brew install osx-cpu-temp"
    echo "  osx-cpu-temp  # Test"
    echo ""
fi

echo ""
echo "Common issues:"
echo "  1. ${RED}WMI returns 0:${NC} Your motherboard doesn't expose temperature via ACPI"
echo "  2. ${RED}No sensors found:${NC} Need to install and configure lm-sensors"
echo "  3. ${RED}Permission denied:${NC} Some methods require root/admin access"
echo ""
echo "If temperature still shows 0°C after trying all methods:"
echo "  - Your hardware may not expose temperature sensors to the OS"
echo "  - Use third-party monitoring software (Core Temp, HWiNFO, LibreHardwareMonitor)"
echo "  - Check BIOS settings for ACPI/sensor options"
echo ""
