# Windows Scripts Directory

This directory contains all PowerShell scripts for Windows system monitoring.

## Directory Structure

```
windows/
├── scripts/
│   ├── main_monitor.ps1                 # Main orchestrator
│   ├── run_as_admin.ps1                 # Admin elevation helper
│   ├── setup_libs.ps1                   # Library setup
│   ├── start_continuous_monitoring.ps1  # Continuous monitoring
│   └── test_fan_bundled.ps1             # Fan testing utility
├── monitors/
│   ├── cpu_monitor.ps1                  # CPU metrics
│   ├── memory_monitor.ps1               # Memory metrics
│   ├── disk_monitor.ps1                 # Disk metrics
│   ├── network_monitor.ps1              # Network metrics
│   ├── temperature_monitor.ps1          # Temperature metrics
│   ├── fan_monitor.ps1                  # Fan speed metrics
│   ├── smart_monitor.ps1                # SMART disk health
│   └── system_monitor.ps1               # System information
├── utils/
│   ├── json_writer.ps1                  # JSON utilities
│   ├── os_detector.ps1                  # OS detection
│   └── hardware_sensor.ps1              # Hardware sensor access
└── tests/
    ├── Run-AllTests.ps1                 # Test runner
    ├── Test-MainMonitor.ps1             # Main monitor tests
    ├── Test-CpuMonitor.ps1              # CPU monitor tests
    ├── Test-MemoryMonitor.ps1           # Memory monitor tests
    ├── Test-DiskMonitor.ps1             # Disk monitor tests
    ├── Test-NetworkMonitor.ps1          # Network monitor tests
    ├── Test-TemperatureMonitor.ps1      # Temperature monitor tests
    ├── Test-FanMonitor.ps1              # Fan monitor tests
    ├── Test-SmartMonitor.ps1            # SMART monitor tests
    ├── Debug-Temperature.ps1            # Temperature debugging
    ├── debug_cpu_temp.ps1               # CPU temp debugging
    └── CPU_ALL_METHODS.ps1              # CPU testing all methods
```

## Usage

### Run Main Monitor
```powershell
.\windows\scripts\main_monitor.ps1
```

### Run All Tests
```powershell
.\windows\tests\Run-AllTests.ps1
```

### Individual Monitor
```powershell
.\windows\monitors\cpu_monitor.ps1
```

## Notes

- All PowerShell scripts require PowerShell 5.1 or later
- Some monitors require administrator privileges
- Temperature and fan monitoring may require specific hardware sensors
