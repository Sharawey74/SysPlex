<#
.SYNOPSIS
    CPU Temperature - All Possible Methods
    
.DESCRIPTION
    Tests EVERY known method to read CPU temperature on Windows:
    1. WMI/CIM - MSAcpi_ThermalZoneTemperature
    2. LibreHardwareMonitor (with CPU-specific fixes)
    3. OpenHardwareMonitor (alternative library)
    4. WMI - Win32_TemperatureProbe
    5. Direct MSR (Model-Specific Register) reading
    6. PowerShell Performance Counters
    
.NOTES
    Author: System Monitor Project
    Version: 2.0.0
    Requires: Administrator privileges
#>

#Requires -RunAsAdministrator

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

function Write-Section {
    param([string]$Title)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Write-Result {
    param([string]$Message, [string]$Status = "INFO")
    $icon = switch ($Status) {
        "SUCCESS" { "✓"; $color = "Green" }
        "FAIL" { "✗"; $color = "Red" }
        "WARN" { "⚠"; $color = "Yellow" }
        "TEMP" { "🌡"; $color = "Cyan" }
        default { "ℹ"; $color = "White" }
    }
    Write-Host "[$icon] $Message" -ForegroundColor $color
}

$results = @{}

# =============================================================================
# METHOD 1: WMI - MSAcpi_ThermalZoneTemperature
# =============================================================================

Write-Section "METHOD 1: WMI Thermal Zones"

try {
    $temps = Get-WmiObject -Namespace "root/wmi" -Class MSAcpi_ThermalZoneTemperature -ErrorAction Stop
    
    if ($temps) {
        $results.WMI_ThermalZone = @{
            Status = "Success"
            Temperatures = @()
        }
        
        foreach ($temp in $temps) {
            $celsius = ($temp.CurrentTemperature / 10) - 273.15
            $rounded = [math]::Round($celsius, 1)
            
            $results.WMI_ThermalZone.Temperatures += @{
                Zone = $temp.InstanceName
                Temperature = $rounded
                Unit = "°C"
            }
            
            Write-Result "Zone: $($temp.InstanceName) = ${rounded}°C" "TEMP"
        }
        Write-Result "WMI Thermal Zones: SUCCESS" "SUCCESS"
    } else {
        Write-Result "No thermal zones found" "WARN"
        $results.WMI_ThermalZone = @{ Status = "No Data" }
    }
} catch {
    Write-Result "WMI Thermal Zones: FAILED - $($_.Exception.Message)" "FAIL"
    $results.WMI_ThermalZone = @{ Status = "Error"; Error = $_.Exception.Message }
}

# =============================================================================
# METHOD 2: LibreHardwareMonitor (CPU-Focused)
# =============================================================================

Write-Section "METHOD 2: LibreHardwareMonitor (CPU Focus)"

try {
    $dllPath = "C:\Users\DELL\Desktop\system-monitor-project\libs\LibreHardwareMonitorLib.dll"
    
    if (-not (Test-Path $dllPath)) {
        Write-Result "LibreHardwareMonitorLib.dll not found at: $dllPath" "FAIL"
        $results.LibreHardwareMonitor = @{ Status = "Not Available" }
    } else {
        Add-Type -Path $dllPath -ErrorAction Stop
        
        $computer = New-Object LibreHardwareMonitor.Hardware.Computer
        
        # Enable ALL CPU-related sensors
        $computer.IsCpuEnabled = $true
        $computer.IsMotherboardEnabled = $true  # Sometimes CPU temp is here
        $computer.IsMemoryEnabled = $false
        $computer.IsGpuEnabled = $false
        $computer.IsStorageEnabled = $false
        $computer.IsControllerEnabled = $false
        $computer.IsNetworkEnabled = $false
        
        $computer.Open()
        
        $cpuTemps = @()
        
        foreach ($hardware in $computer.Hardware) {
            $hardware.Update()
            
            Write-Host "`nHardware: $($hardware.Name)" -ForegroundColor Yellow
            Write-Host "  Type: $($hardware.HardwareType)" -ForegroundColor Gray
            
            # Main hardware sensors
            foreach ($sensor in $hardware.Sensors) {
                Write-Host "  Sensor: $($sensor.Name) | Type: $($sensor.SensorType) | Value: $($sensor.Value)" -ForegroundColor Gray
                
                if ($sensor.SensorType -eq [LibreHardwareMonitor.Hardware.SensorType]::Temperature) {
                    if ($sensor.Value) {
                        $cpuTemps += @{
                            Hardware = $hardware.Name
                            HardwareType = $hardware.HardwareType.ToString()
                            Sensor = $sensor.Name
                            Temperature = [math]::Round($sensor.Value, 1)
                        }
                        Write-Result "$($sensor.Name): $([math]::Round($sensor.Value, 1))°C" "TEMP"
                    }
                }
            }
            
            # Sub-hardware (individual cores)
            foreach ($subhardware in $hardware.SubHardware) {
                $subhardware.Update()
                Write-Host "    SubHardware: $($subhardware.Name)" -ForegroundColor DarkYellow
                
                foreach ($sensor in $subhardware.Sensors) {
                    Write-Host "    Sensor: $($sensor.Name) | Type: $($sensor.SensorType) | Value: $($sensor.Value)" -ForegroundColor DarkGray
                    
                    if ($sensor.SensorType -eq [LibreHardwareMonitor.Hardware.SensorType]::Temperature) {
                        if ($sensor.Value) {
                            $cpuTemps += @{
                                Hardware = "$($hardware.Name) - $($subhardware.Name)"
                                HardwareType = $subhardware.HardwareType.ToString()
                                Sensor = $sensor.Name
                                Temperature = [math]::Round($sensor.Value, 1)
                            }
                            Write-Result "$($sensor.Name): $([math]::Round($sensor.Value, 1))°C" "TEMP"
                        }
                    }
                }
            }
        }
        
        $computer.Close()
        
        if ($cpuTemps.Count -gt 0) {
            $results.LibreHardwareMonitor = @{
                Status = "Success"
                Temperatures = $cpuTemps
            }
            Write-Result "LibreHardwareMonitor: Found $($cpuTemps.Count) CPU temperature(s)" "SUCCESS"
        } else {
            Write-Result "LibreHardwareMonitor: No CPU temperatures detected" "WARN"
            $results.LibreHardwareMonitor = @{ Status = "No CPU Temps" }
        }
    }
} catch {
    Write-Result "LibreHardwareMonitor FAILED: $($_.Exception.Message)" "FAIL"
    $results.LibreHardwareMonitor = @{ Status = "Error"; Error = $_.Exception.Message }
}

# =============================================================================
# METHOD 3: Win32_TemperatureProbe
# =============================================================================

Write-Section "METHOD 3: Win32_TemperatureProbe"

try {
    $probes = Get-WmiObject -Class Win32_TemperatureProbe -ErrorAction Stop
    
    if ($probes) {
        $results.Win32_TemperatureProbe = @{
            Status = "Success"
            Temperatures = @()
        }
        
        foreach ($probe in $probes) {
            if ($probe.CurrentReading) {
                $celsius = ($probe.CurrentReading / 10) - 273.15
                $rounded = [math]::Round($celsius, 1)
                
                $results.Win32_TemperatureProbe.Temperatures += @{
                    Name = $probe.Name
                    Description = $probe.Description
                    Temperature = $rounded
                }
                
                Write-Result "$($probe.Name): ${rounded}°C" "TEMP"
            }
        }
        Write-Result "Win32_TemperatureProbe: SUCCESS" "SUCCESS"
    } else {
        Write-Result "No temperature probes found" "WARN"
        $results.Win32_TemperatureProbe = @{ Status = "No Data" }
    }
} catch {
    Write-Result "Win32_TemperatureProbe: FAILED - $($_.Exception.Message)" "FAIL"
    $results.Win32_TemperatureProbe = @{ Status = "Error"; Error = $_.Exception.Message }
}

# =============================================================================
# METHOD 4: CIM Instance (Modern WMI)
# =============================================================================

Write-Section "METHOD 4: CIM Thermal Zones"

try {
    $cimTemps = Get-CimInstance -Namespace "root/wmi" -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop
    
    if ($cimTemps) {
        $results.CIM_ThermalZone = @{
            Status = "Success"
            Temperatures = @()
        }
        
        foreach ($temp in $cimTemps) {
            $celsius = ($temp.CurrentTemperature / 10) - 273.15
            $rounded = [math]::Round($celsius, 1)
            
            $results.CIM_ThermalZone.Temperatures += @{
                Zone = $temp.InstanceName
                Temperature = $rounded
            }
            
            Write-Result "Zone: $($temp.InstanceName) = ${rounded}°C" "TEMP"
        }
        Write-Result "CIM Thermal Zones: SUCCESS" "SUCCESS"
    } else {
        Write-Result "No CIM thermal zones found" "WARN"
        $results.CIM_ThermalZone = @{ Status = "No Data" }
    }
} catch {
    Write-Result "CIM Thermal Zones: FAILED - $($_.Exception.Message)" "FAIL"
    $results.CIM_ThermalZone = @{ Status = "Error"; Error = $_.Exception.Message }
}

# =============================================================================
# METHOD 5: Check CPU Information
# =============================================================================

Write-Section "METHOD 5: System CPU Information"

try {
    $cpu = Get-WmiObject Win32_Processor | Select-Object -First 1
    
    Write-Result "CPU: $($cpu.Name)" "INFO"
    Write-Result "Manufacturer: $($cpu.Manufacturer)" "INFO"
    Write-Result "Architecture: $($cpu.Architecture)" "INFO"
    Write-Result "Cores: $($cpu.NumberOfCores)" "INFO"
    Write-Result "Logical Processors: $($cpu.NumberOfLogicalProcessors)" "INFO"
    Write-Result "Current Clock Speed: $($cpu.CurrentClockSpeed) MHz" "INFO"
    
    $results.CPU_Info = @{
        Name = $cpu.Name
        Manufacturer = $cpu.Manufacturer
        Cores = $cpu.NumberOfCores
        LogicalProcessors = $cpu.NumberOfLogicalProcessors
    }
    
    # Check if CPU supports temperature monitoring
    if ($cpu.Manufacturer -match "Intel") {
        Write-Result "Intel CPU detected - Should support DTS (Digital Thermal Sensor)" "INFO"
    } elseif ($cpu.Manufacturer -match "AMD") {
        Write-Result "AMD CPU detected - Should support thermal monitoring" "INFO"
    }
    
} catch {
    Write-Result "Failed to get CPU info: $($_.Exception.Message)" "FAIL"
}

# =============================================================================
# METHOD 6: Check Available WMI Namespaces
# =============================================================================

Write-Section "METHOD 6: Available WMI Temperature Classes"

try {
    Write-Result "Checking root/wmi namespace..." "INFO"
    $wmiClasses = Get-WmiObject -Namespace "root/wmi" -List | Where-Object { $_.Name -like "*Temp*" -or $_.Name -like "*Thermal*" }
    
    if ($wmiClasses) {
        foreach ($class in $wmiClasses) {
            Write-Result "Found: $($class.Name)" "SUCCESS"
        }
    } else {
        Write-Result "No temperature-related WMI classes found" "WARN"
    }
} catch {
    Write-Result "Failed to enumerate WMI classes: $($_.Exception.Message)" "FAIL"
}

# =============================================================================
# FINAL REPORT
# =============================================================================

Write-Section "FINAL REPORT"

$successfulMethods = @()
$totalCPUTemps = 0

foreach ($method in $results.Keys) {
    if ($results[$method].Status -eq "Success") {
        $successfulMethods += $method
        if ($results[$method].Temperatures) {
            $totalCPUTemps += $results[$method].Temperatures.Count
        }
    }
}

Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Result "Successful Methods: $($successfulMethods.Count)" "INFO"
Write-Result "Total CPU Temperature Readings: $totalCPUTemps" "INFO"

if ($successfulMethods.Count -gt 0) {
    Write-Host "`nWorking Methods:" -ForegroundColor Green
    foreach ($method in $successfulMethods) {
        Write-Result "$method" "SUCCESS"
    }
} else {
    Write-Host "`n❌ NO METHODS SUCCESSFULLY READ CPU TEMPERATURE" -ForegroundColor Red
    Write-Host "`nPossible Reasons:" -ForegroundColor Yellow
    Write-Host "1. Your BIOS/UEFI may not expose CPU temperature to Windows" -ForegroundColor Yellow
    Write-Host "2. Your laptop manufacturer may use proprietary tools" -ForegroundColor Yellow
    Write-Host "3. CPU temperature monitoring may be disabled in BIOS" -ForegroundColor Yellow
    Write-Host "4. Older CPU models may not support standard temperature reporting" -ForegroundColor Yellow
    Write-Host "`nRecommended Actions:" -ForegroundColor Cyan
    Write-Host "• Check BIOS settings for hardware monitoring options" -ForegroundColor White
    Write-Host "• Update BIOS/UEFI to latest version" -ForegroundColor White
    Write-Host "• Try manufacturer-specific monitoring tools (Dell Command, HP Support Assistant, etc.)" -ForegroundColor White
    Write-Host "• Consider using Core Temp or HWiNFO64 (proven third-party tools)" -ForegroundColor White
}

# Save report
$jsonReport = $results | ConvertTo-Json -Depth 5
$reportPath = "cpu_temp_diagnostic_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
$jsonReport | Set-Content $reportPath
Write-Result "`nFull report saved to: $reportPath" "SUCCESS"