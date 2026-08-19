# Bundled Libraries Directory

This directory contains third-party libraries bundled with the system monitor project to provide enhanced hardware monitoring capabilities without requiring users to install external software.

## Contents

- **LibreHardwareMonitorLib.dll** - Hardware sensor monitoring library
- **HidSharp.dll** - HID device support (dependency)
- **Newtonsoft.Json.dll** - JSON processing (dependency)

## Setup

To download and set up the bundled libraries, run:

```powershell
.\scripts\setup_libs.ps1
```

This script will:
1. Download LibreHardwareMonitor from the official GitHub repository
2. Extract the necessary DLL files
3. Place them in this `libs` directory
4. Clean up temporary files

## License

LibreHardwareMonitor is licensed under the Mozilla Public License 2.0 (MPL 2.0).
Source: https://github.com/LibreHardwareMonitor/LibreHardwareMonitor

## Usage

The monitoring scripts automatically detect and use these bundled libraries if present. If the libraries are not available, the scripts fall back to native Windows APIs (with limited functionality).

### Fan Monitoring
- **With bundled library**: Provides actual RPM readings from fans
- **Without bundled library**: Only shows fan status (OK/unavailable) without RPM values

### Temperature Monitoring
- **With bundled library**: Provides accurate CPU/GPU temperatures
- **Without bundled library**: Uses Windows WMI (limited accuracy)

## Updating Libraries

To update to a newer version:
1. Delete the contents of this directory (except README.md)
2. Update the download URL in `scripts/setup_libs.ps1`
3. Run `.\scripts\setup_libs.ps1`

## Distribution

When distributing this project:
- **Option 1**: Include the `libs` folder with DLL files (users can run immediately)
- **Option 2**: Exclude the `libs` folder, users run `setup_libs.ps1` on first use
- **Option 3**: Provide both options (include DLLs but also setup script for updates)

## Technical Details

The hardware sensor library provides access to:
- Fan speeds (RPM)
- CPU temperatures (per core)
- GPU temperatures
- Voltage readings
- Power consumption
- Clock speeds

All through direct hardware access, bypassing Windows API limitations.
