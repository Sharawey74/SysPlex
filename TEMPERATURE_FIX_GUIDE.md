# CPU Temperature Shows 0°C - Complete Fix Guide

## Problem

Both you and your friend see **0°C** for CPU temperature on the dashboard.

## Root Cause

Your motherboard/CPU **doesn't expose temperature sensors** via standard Windows WMI (Windows Management Instrumentation). This is common on:
- Older motherboards
- Some AMD systems
- Desktop systems without ACPI thermal zones enabled in BIOS
- Certain OEM systems (Dell, HP) with restricted sensor access

## Solution: Use ALL Available Detection Methods

I've enhanced BOTH agents with comprehensive temperature detection. Follow these steps:

---

## Step 1: Test Which Methods Work on Your System

### For Windows/WSL2 Users:

**Run the PowerShell diagnostic:**
```powershell
# Run as Administrator
cd C:\path\to\system-monitor-project-Batch
.\test_temperature_windows.ps1
```

This tests **9 different Windows temperature detection methods** and tells you which ones work.

**Expected output:**
```
[Method 1] WMI - MSAcpi_ThermalZoneTemperature
  Zone: ACPI\ThermalZone\TZ00
  Temperature: 45.2°C

RECOMMENDED VALUE: 45°C
```

**If all methods fail:**
- Your motherboard doesn't expose temperature via WMI
- **Solution**: Install third-party tools (see Step 3)

### For Linux Users:

**Run the bash diagnostic:**
```bash
cd /path/to/system-monitor-project-Batch
bash test_temperature.sh
```

This tests:
- lm-sensors
- /sys/class/thermal
- /sys/class/hwmon
- acpi command
- Direct kernel interfaces

---

## Step 2: Rebuild Go Agent with Enhanced Detection

The enhanced [Host2/main.go](c:\Users\DELL\Desktop\system-monitor-project-Batch\Host2\main.go) now includes:

**Windows (5 methods):**
1. WMI MSAcpi_ThermalZoneTemperature (most common)
2. WMI Win32_TemperatureProbe
3. WMI Win32_PerfFormattedData_Counters_ThermalZoneInformation
4. PowerShell WMI query (more reliable on some systems)
5. CIM TemperatureSensor (newer Windows 10/11)

**Linux (5 methods):**
1. lm-sensors command
2. /sys/class/hwmon/* (direct kernel interface)
3. /sys/class/thermal/thermal_zone*
4. acpi command
5. Direct CPU package temperature files

**Rebuild the binary:**
```bash
cd Host2
bash build.sh
```

**Or rebuild just for your platform:**
```bash
# Windows
cd Host2
GOOS=windows GOARCH=amd64 go build -o bin/host-agent-windows.exe main.go

# Linux
cd Host2
GOOS=linux GOARCH=amd64 go build -o bin/host-agent-linux main.go
```

---

## Step 3: Install Third-Party Tools (If WMI Fails)

If ALL detection methods return 0°C, your hardware requires third-party software:

### Option A: LibreHardwareMonitor (Recommended)
**Free, open-source, works on all systems**

1. Download: https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/releases
2. Extract and run `LibreHardwareMonitor.exe`
3. Check if temperature shows in the application
4. Keep it running in background (system tray)

**Integration (future enhancement):**
LibreHardwareMonitor can expose temps via WMI or API that our agent can read.

### Option B: Core Temp
**Lightweight, CPU-focused**

1. Download: https://www.alcpu.com/CoreTemp/
2. Install and run
3. Enable "System Tray" and "Start with Windows"

### Option C: HWiNFO
**Most comprehensive**

1. Download: https://www.hwinfo.com/
2. Run in "Sensors-only" mode
3. Enable shared memory (for other apps to read)

---

## Step 4: Verify Fixes

**After rebuilding:**

1. Stop existing agent:
```bash
pkill -f host-agent
# Or on Windows:
taskkill /F /IM host-agent-windows.exe
```

2. Start new binary:
```bash
# WSL2
./Host2/bin/host-agent-windows.exe

# Linux
./Host2/bin/host-agent-linux

# macOS
./Host2/bin/host-agent-macos
```

3. Check metrics:
```bash
curl http://localhost:8889/metrics | grep -A 5 temperature
```

**Expected:**
```json
"temperature": {
  "cpu_celsius": 45,
  "cpu_vendor": "Intel",
  "status": "ok"
}
```

4. Restart full system:
```bash
bash start-universal.sh
```

5. Open dashboard: http://localhost:5000
6. CPU temperature should now display

---

## Step 5: Enable BIOS/Sensors (Linux Only)

**If Linux shows 0°C:**

```bash
# Install sensor tools
sudo apt-get update
sudo apt-get install lm-sensors acpi

# Run sensor detection (answer YES to all prompts)
sudo sensors-detect

# Test
sensors
```

**Expected output:**
```
coretemp-isa-0000
Adapter: ISA adapter
Package id 0:  +45.0°C
Core 0:        +42.0°C
Core 1:        +44.0°C
```

**If still empty:**
- Load kernel modules: `sudo modprobe coretemp` (Intel) or `sudo modprobe k10temp` (AMD)
- Check BIOS: Enable "ACPI", "Hardware Monitoring", "Temperature Monitoring"

---

## Diagnostic Files Created

| File | Purpose |
|------|---------|
| [test_temperature_windows.ps1](c:\Users\DELL\Desktop\system-monitor-project-Batch\test_temperature_windows.ps1) | Tests all 9 Windows temperature detection methods |
| [test_temperature.sh](c:\Users\DELL\Desktop\system-monitor-project-Batch\test_temperature.sh) | Tests both Host API and Go Agent, shows all methods |
| [Host2/main.go](c:\Users\DELL\Desktop\system-monitor-project-Batch\Host2\main.go) | Enhanced with 5 Windows + 5 Linux methods |

---

## For Your Friend

**Send these instructions:**

1. **Test temperature detection:**
   ```powershell
   cd system-monitor-project-Batch
   .\test_temperature_windows.ps1
   ```

2. **If shows temperature:**
   - Rebuild Go agent: `cd Host2; bash build.sh`
   - Restart system: `bash start-universal.sh`
   - Should work now!

3. **If shows 0°C:**
   - Install LibreHardwareMonitor: https://github.com/LibreHardwareMonitor/LibreHardwareMonitor
   - Run it in background
   - Some motherboards don't expose temps to Windows WMI

---

## Why This Happens

**Hardware limitations:**
- Not all motherboards implement ACPI thermal zones
- Some OEMs (Dell, HP) restrict sensor access
- AMD systems often need specialized drivers
- Older hardware lacks WMI sensor support

**The fix:**
- Our enhanced code tries 10+ methods instead of 2
- If hardware supports ANY method, we'll find it
- If hardware doesn't support ANY method, third-party tools are required

---

## Testing Checklist

- [ ] Run `test_temperature_windows.ps1` (Windows) or `test_temperature.sh` (Linux)
- [ ] At least ONE method returns temperature > 0
- [ ] Rebuild Go agent: `cd Host2 && bash build.sh`
- [ ] Stop old agent: `pkill -f host-agent`
- [ ] Start new agent: `./Host2/bin/host-agent-*`
- [ ] Test endpoint: `curl http://localhost:8889/metrics`
- [ ] Restart system: `bash start-universal.sh`
- [ ] Open dashboard: http://localhost:5000
- [ ] Verify temperature displays

**If still 0°C after all this:**
- Your hardware genuinely doesn't expose temperature sensors
- Install LibreHardwareMonitor as workaround
- Consider future integration with third-party tools' APIs
