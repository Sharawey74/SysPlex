#!/usr/bin/env pwsh
# Comprehensive Windows Temperature Detection
# Tries ALL available methods and outputs diagnostic information

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Windows CPU Temperature Detection" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$Results = @()
$BestTemp = 0

# Method 1: WMI - MSAcpi_ThermalZoneTemperature
Write-Host "[Method 1] WMI - MSAcpi_ThermalZoneTemperature" -ForegroundColor Yellow
try {
    $ThermalZones = Get-WmiObject -Namespace "root/wmi" -Class MSAcpi_ThermalZoneTemperature -ErrorAction Stop
    foreach ($Zone in $ThermalZones) {
        $TempKelvin = $Zone.CurrentTemperature
        $TempCelsius = [math]::Round(($TempKelvin / 10) - 273.15, 1)
        Write-Host "  Zone: $($Zone.InstanceName)" -ForegroundColor White
        Write-Host "  Temperature: $TempCelsius°C" -ForegroundColor Green
        $Results += @{Method = "WMI MSAcpi"; Temp = $TempCelsius}
        if ($TempCelsius -gt $BestTemp -and $TempCelsius -lt 120) {
            $BestTemp = $TempCelsius
        }
    }
} catch {
    Write-Host "  ✗ Not available: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Method 2: WMI - Win32_TemperatureProbe
Write-Host "[Method 2] WMI - Win32_TemperatureProbe" -ForegroundColor Yellow
try {
    $TempProbes = Get-WmiObject -Class Win32_TemperatureProbe -ErrorAction Stop
    if ($TempProbes) {
        foreach ($Probe in $TempProbes) {
            if ($Probe.CurrentReading) {
                $TempKelvin = $Probe.CurrentReading
                $TempCelsius = [math]::Round(($TempKelvin / 10) - 273.15, 1)
                Write-Host "  Probe: $($Probe.Description)" -ForegroundColor White
                Write-Host "  Temperature: $TempCelsius°C" -ForegroundColor Green
                $Results += @{Method = "WMI TemperatureProbe"; Temp = $TempCelsius}
                if ($TempCelsius -gt $BestTemp -and $TempCelsius -lt 120) {
                    $BestTemp = $TempCelsius
                }
            }
        }
    } else {
        Write-Host "  ✗ No temperature probes found" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Not available: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Method 3: WMI - Win32_PerfFormattedData_Counters_ThermalZoneInformation
Write-Host "[Method 3] WMI - ThermalZoneInformation" -ForegroundColor Yellow
try {
    $ThermalInfo = Get-WmiObject -Class Win32_PerfFormattedData_Counters_ThermalZoneInformation -ErrorAction Stop
    if ($ThermalInfo) {
        foreach ($Zone in $ThermalInfo) {
            $TempKelvin = $Zone.Temperature
            if ($TempKelvin -and $TempKelvin -gt 0) {
                $TempCelsius = [math]::Round($TempKelvin - 273.15, 1)
                Write-Host "  Zone: $($Zone.Name)" -ForegroundColor White
                Write-Host "  Temperature: $TempCelsius°C" -ForegroundColor Green
                $Results += @{Method = "WMI ThermalZoneInfo"; Temp = $TempCelsius}
                if ($TempCelsius -gt $BestTemp -and $TempCelsius -lt 120) {
                    $BestTemp = $TempCelsius
                }
            }
        }
    } else {
        Write-Host "  ✗ No thermal zones found" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Not available: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Method 4: CIM - CIM_NumericSensor
Write-Host "[Method 4] CIM - CIM_NumericSensor" -ForegroundColor Yellow
try {
    $Sensors = Get-CimInstance -ClassName CIM_NumericSensor -ErrorAction Stop
    foreach ($Sensor in $Sensors) {
        if ($Sensor.CurrentReading) {
            Write-Host "  Sensor: $($Sensor.Name)" -ForegroundColor White
            Write-Host "  Reading: $($Sensor.CurrentReading)" -ForegroundColor Green
            $Results += @{Method = "CIM NumericSensor"; Temp = $Sensor.CurrentReading}
        }
    }
} catch {
    Write-Host "  ✗ Not available: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Method 5: CIM - CIM_TemperatureSensor
Write-Host "[Method 5] CIM - CIM_TemperatureSensor" -ForegroundColor Yellow
try {
    $TempSensors = Get-CimInstance -ClassName CIM_TemperatureSensor -ErrorAction Stop
    foreach ($Sensor in $TempSensors) {
        if ($Sensor.CurrentReading) {
            Write-Host "  Sensor: $($Sensor.Name)" -ForegroundColor White
            Write-Host "  Temperature: $($Sensor.CurrentReading)°C" -ForegroundColor Green
            $Results += @{Method = "CIM TemperatureSensor"; Temp = $Sensor.CurrentReading}
            if ($Sensor.CurrentReading -gt $BestTemp -and $Sensor.CurrentReading -lt 120) {
                $BestTemp = $Sensor.CurrentReading
            }
        }
    }
} catch {
    Write-Host "  ✗ Not available: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Method 6: LibreHardwareMonitor API (if running)
Write-Host "[Method 6] LibreHardwareMonitor/OpenHardwareMonitor" -ForegroundColor Yellow
try {
    $Process = Get-Process -Name "LibreHardwareMonitor","OpenHardwareMonitor" -ErrorAction SilentlyContinue
    if ($Process) {
        Write-Host "  ✓ Hardware Monitor detected (running)" -ForegroundColor Green
        Write-Host "  Note: Requires API or CLI integration" -ForegroundColor Yellow
    } else {
        Write-Host "  ✗ Hardware monitor not running" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Not available" -ForegroundColor Red
}
Write-Host ""

# Method 7: CoreTemp (if installed and running)
Write-Host "[Method 7] Core Temp API" -ForegroundColor Yellow
$CoreTempPath = "C:\Program Files\Core Temp\Core Temp.exe"
if (Test-Path $CoreTempPath) {
    Write-Host "  ✓ Core Temp installed: $CoreTempPath" -ForegroundColor Green
    Write-Host "  Note: Requires API integration" -ForegroundColor Yellow
} else {
    Write-Host "  ✗ Core Temp not installed" -ForegroundColor Red
}
Write-Host ""

# Method 8: WMIC CPU temperature (alternative syntax)
Write-Host "[Method 8] WMIC CPU ThermalZone (Alternative)" -ForegroundColor Yellow
try {
    $WmicOutput = wmic /namespace:\\root\wmi PATH MSAcpi_ThermalZoneTemperature get CurrentTemperature 2>$null
    if ($LASTEXITCODE -eq 0) {
        $Lines = $WmicOutput -split "`n" | Where-Object { $_ -match '^\s*\d+\s*$' }
        foreach ($Line in $Lines) {
            $TempKelvin = [int]($Line.Trim())
            $TempCelsius = [math]::Round(($TempKelvin / 10) - 273.15, 1)
            Write-Host "  Temperature: $TempCelsius°C" -ForegroundColor Green
            $Results += @{Method = "WMIC Alternative"; Temp = $TempCelsius}
            if ($TempCelsius -gt $BestTemp -and $TempCelsius -lt 120) {
                $BestTemp = $TempCelsius
            }
        }
    } else {
        Write-Host "  ✗ WMIC command failed" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Not available: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Method 9: Check if running on a laptop with battery temperature as proxy
Write-Host "[Method 9] Battery Temperature (Proxy for Laptops)" -ForegroundColor Yellow
try {
    $Battery = Get-WmiObject -Class Win32_Battery -ErrorAction Stop
    if ($Battery) {
        Write-Host "  ✓ Battery detected (laptop)" -ForegroundColor Green
        # Some laptops expose temperature via battery sensors
        if ($Battery.EstimatedChargeRemaining) {
            Write-Host "  Charge: $($Battery.EstimatedChargeRemaining)%" -ForegroundColor White
        }
    } else {
        Write-Host "  ✗ No battery detected (desktop)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ✗ Not available" -ForegroundColor Red
}
Write-Host ""

# Summary
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Detection Summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if ($Results.Count -gt 0) {
    Write-Host "✓ Found $($Results.Count) temperature reading(s)" -ForegroundColor Green
    Write-Host ""
    Write-Host "All readings:" -ForegroundColor White
    foreach ($Result in $Results) {
        Write-Host "  - $($Result.Method): $($Result.Temp)°C" -ForegroundColor Cyan
    }
    Write-Host ""
    if ($BestTemp -gt 0) {
        Write-Host "RECOMMENDED VALUE: $BestTemp°C" -ForegroundColor Green
    }
} else {
    Write-Host "✗ No temperature sensors found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "POSSIBLE REASONS:" -ForegroundColor Yellow
    Write-Host "  1. Your CPU/motherboard doesn't expose temperature via WMI" -ForegroundColor White
    Write-Host "  2. ACPI thermal zones are disabled in BIOS" -ForegroundColor White
    Write-Host "  3. Need third-party tools (Core Temp, HWiNFO, OpenHardwareMonitor)" -ForegroundColor White
    Write-Host ""
    Write-Host "SOLUTIONS:" -ForegroundColor Yellow
    Write-Host "  1. Install LibreHardwareMonitor: https://github.com/LibreHardwareMonitor/LibreHardwareMonitor" -ForegroundColor White
    Write-Host "  2. Install Core Temp: https://www.alcpu.com/CoreTemp/" -ForegroundColor White
    Write-Host "  3. Enable ACPI in BIOS settings" -ForegroundColor White
    Write-Host "  4. Use nvidia-smi for GPU temperature (if NVIDIA GPU)" -ForegroundColor White
}

Write-Host ""
Write-Host "JSON Output (for integration):" -ForegroundColor Cyan
$JsonOutput = @{
    cpu_celsius = $BestTemp
    methods_tried = $Results.Count
    status = if ($BestTemp -gt 0) { "ok" } else { "unavailable" }
    all_readings = $Results
}
$JsonOutput | ConvertTo-Json -Depth 3
Write-Host ""
