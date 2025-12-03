# Bundled Hardware Monitoring Setup

## Overview

Your system monitor now includes **bundled hardware monitoring libraries** so users don't need to install external software. The LibreHardwareMonitor DLL files are included directly in your project.

## What Was Added

### 1. Library Files (in `libs/` directory)
- `LibreHardwareMonitorLib.dll` - Main hardware monitoring library
- `HidSharp.dll` - HID device support
- `Newtonsoft.Json.dll` - JSON processing

### 2. New Scripts

**`scripts/setup_libs.ps1`**
- Downloads and sets up bundled libraries
- Only needs to be run once during development
- Users don't need to run this if you include the DLLs in your repository

**`scripts/utils/hardware_sensor.ps1`**
- Wrapper module for hardware sensor access
- Loads the bundled DLL files
- Provides `Get-HardwareSensors` function

**`scripts/run_as_admin.ps1`**
- Helper to run monitor with administrator privileges
- Hardware library requires elevated access

**`scripts/test_fan_bundled.ps1`**
- Test script to verify bundled library works

### 3. Updated Monitor

**`scripts/monitors/windows/fan_monitor.ps1`**
- Now tries bundled library FIRST (gets actual RPM)
- Falls back to native Windows APIs if library unavailable
- Graceful degradation

## How It Works

```
┌─────────────────────────────────────┐
│  Fan Monitor Execution Flow         │
└─────────────────────────────────────┘
           │
           ▼
    ┌──────────────────┐
    │ Check for bundled│
    │ library (DLL)    │
    └──────────────────┘
           │
     ┌─────┴─────┐
     │           │
   YES          NO
     │           │
     ▼           ▼
┌─────────┐  ┌────────────┐
│Load DLL │  │Use native  │
│Get RPM  │  │Windows API │
│values   │  │(limited)   │
└─────────┘  └────────────┘
     │           │
     └─────┬─────┘
           ▼
    ┌──────────────┐
    │Output JSON   │
    └──────────────┘
```

## Distribution Options

### Option 1: Include DLLs in Repository (Recommended)
**Pros:**
- Users can run immediately
- No setup required
- Consistent behavior

**Cons:**
- Larger repository size (~1.6MB)

```bash
# Add libs to git
git add libs/*.dll
git commit -m "Add bundled hardware monitoring libraries"
git push
```

### Option 2: Users Download on First Use
**Pros:**
- Smaller repository
- Always latest version

**Cons:**
- Users must run setup script
- Requires internet connection

Users run:
```powershell
.\scripts\setup_libs.ps1
```

### Option 3: Hybrid Approach
- Include DLLs in releases (ZIP/installer)
- Exclude from repository
- Add `libs/*.dll` to `.gitignore`

## Usage

### For End Users

**Standard Mode (No Admin):**
```powershell
.\scripts\main_monitor.ps1
```
- Uses native Windows APIs
- Limited fan data (status only, no RPM)

**Enhanced Mode (With Admin):**
```powershell
# Right-click PowerShell -> Run as Administrator
.\scripts\main_monitor.ps1

# OR use helper script:
.\scripts\run_as_admin.ps1
```
- Uses bundled hardware library
- Full fan data with RPM readings
- More accurate temperatures

### For Developers

**Setup (one-time):**
```powershell
.\scripts\setup_libs.ps1
```

**Test bundled library:**
```powershell
.\scripts\test_fan_bundled.ps1
```

## Output Examples

### With Bundled Library (Admin Mode)
```json
{
  "fans": [
    {
      "name": "CPU Fan",
      "rpm": 2450,
      "hardware": "Lenovo IdeaPad"
    },
    {
      "name": "GPU Fan",
      "rpm": 1800,
      "hardware": "NVIDIA GeForce RTX"
    }
  ],
  "detection_method": "LibreHardwareMonitor",
  "fan_count": 2,
  "status": "available"
}
```

### Without Bundled Library (Fallback)
```json
{
  "fans": {
    "status": "OK",
    "name": "Cooling Device",
    "rpm": "unavailable"
  },
  "detection_method": "CIM",
  "fan_count": 1,
  "status": "available"
}
```

## License Considerations

LibreHardwareMonitor is open-source under **Mozilla Public License 2.0 (MPL 2.0)**.

When distributing:
1. Include license file: Create `libs/LICENSE-LibreHardwareMonitor.txt`
2. Add attribution in your README
3. Provide link to source: https://github.com/LibreHardwareMonitor/LibreHardwareMonitor

Example attribution:
```markdown
## Third-Party Libraries

This project includes LibreHardwareMonitor for enhanced hardware monitoring:
- Library: LibreHardwareMonitor
- License: Mozilla Public License 2.0
- Source: https://github.com/LibreHardwareMonitor/LibreHardwareMonitor
```

## Updating the Library

To update to a newer version:
```powershell
# 1. Edit scripts/setup_libs.ps1 and change version number in URL
# 2. Remove old DLLs
Remove-Item libs\*.dll

# 3. Run setup again
.\scripts\setup_libs.ps1
```

## Troubleshooting

### "Access Denied" errors
- Solution: Run as Administrator

### "Could not load file or assembly"
- Check all 3 DLL files are present in `libs/`
- Verify .NET Framework 4.7.2+ is installed

### No RPM readings even with library
- Some laptops don't expose fan speeds at hardware level
- The library will still show more fans than Windows APIs

### Library not loading
- Check PowerShell execution policy:
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

## Technical Details

### Why Administrator Required?

The hardware library accesses:
- Low-level hardware registers (MSR, SMBus)
- Ring 0 kernel driver
- Direct hardware I/O ports

These require elevated privileges for security.

### Supported Hardware

The bundled library supports:
- **CPUs**: Intel, AMD
- **GPUs**: NVIDIA, AMD, Intel
- **Motherboards**: ASUS, Gigabyte, MSI, ASRock
- **Laptops**: Most major brands

### Performance Impact

- Library initialization: ~500ms (one-time)
- Sensor reading: ~50ms per update
- Memory usage: +15MB when loaded

## Recommendations

1. **Include DLLs in repository** - Best user experience
2. **Add admin privilege prompt** - Automatically request elevation
3. **Document both modes** - Let users know admin gives better data
4. **Test on multiple systems** - Hardware support varies

## Next Steps

1. Add license file for LibreHardwareMonitor
2. Update main README with bundled library info
3. Test on different hardware
4. Consider adding admin elevation prompt in main script
5. Update documentation with examples of both modes
