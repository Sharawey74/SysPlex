# Quick Start Guide

## 🚀 Universal Launcher (Recommended)

### Run Monitoring + Dashboard (All Platforms)
```bash
python universal.py --dashboard
```

### Run Monitoring Only
```bash
python universal.py
```

### Continuous Monitoring (Watch Mode)
```bash
python universal.py --watch --interval 30
```

### View Live Dashboard
```bash
python dashboard_tui.py
```

## 📊 Stage 3: Terminal Dashboard

The dashboard provides real-time visualization of:
- **CPU**: Usage, load average, cores, model
- **Memory**: Used/total, usage %, free memory
- **Temperature**: CPU & GPU temps with vendor info
- **Disk**: All drives with usage bars (C:, D:, E:)
- **Network**: Total RX/TX + top 3 active interfaces
- **Alerts**: System notifications at bottom

### Install Python Dependencies
```bash
pip install -r requirements.txt
```

## 🔧 Manual Platform-Specific Execution

### Windows

#### Run Monitoring
```powershell
cd c:\Users\DELL\Desktop\system-monitor-project
.\scripts\main_monitor.ps1
```

#### View Results
```powershell
Get-Content data\metrics\current.json
```

#### Run Tests
```powershell
.\tests\windows\Run-AllTests.ps1
```

### Unix/Linux/macOS

#### Install
```bash
cd /path/to/system-monitor-project
bash scripts/install.sh
```

#### Run Monitoring
```bash
bash scripts/main_monitor.sh
```

#### View Results
```bash
cat data/metrics/current.json | jq .
```

#### Run Tests
```bash
bash tests/unix/run_all_tests.sh
```

## Output Location

- **JSON Output:** `data/metrics/current.json`
- **Logs:** `data/logs/system.log`

## Collectors Included

1. **CPU** - Usage percentage and load averages
2. **Memory** - Total, used, free, available
3. **Disk** - Usage for all drives
4. **Network** - RX/TX bytes for all interfaces
5. **System** - OS, hostname, uptime, kernel
6. **Temperature** - CPU/GPU temps (if available)
7. **Fans** - Fan speeds (if available)
8. **SMART** - Disk health (if available)

## 🧪 Testing

### Run Python Dashboard Tests
```bash
pytest tests/python/ -v
```

### Run All Tests
```bash
python tests/python/run_tests.py
```

### Test Coverage
- 75 Python unit tests (74 passed, 1 skipped)
- test_metrics_collector.py: 20 tests
- test_alert_manager.py: 22 tests  
- test_tui_dashboard.py: 33 tests

## Status Fields

- `"status": "unavailable"` - Tool/sensor not available
- `"status": "restricted"` - Requires elevated privileges
- `"status": "error"` - Execution error
