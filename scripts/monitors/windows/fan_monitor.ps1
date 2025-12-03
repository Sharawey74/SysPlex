# Fan Monitor for Windows
# Collects fan speed information using bundled hardware library

$ErrorActionPreference = "Stop"

# Import hardware sensor utility
$utilsPath = Join-Path (Split-Path -Parent $PSScriptRoot) "utils\hardware_sensor.ps1"
if (Test-Path $utilsPath) {
    . $utilsPath
}

function Get-FanMetrics {
    try {
        $fans = $null
        $detectionMethod = "none"
        $fanCount = 0
        
        # Method 1: Try bundled LibreHardwareMonitor library
        $hardwareLibraryAttempted = $false
        if (Get-Command Get-HardwareSensors -ErrorAction SilentlyContinue) {
            try {
                $sensorData = Get-HardwareSensors -SensorType "Fan"
                $hardwareLibraryAttempted = $true
                
                if ($sensorData.success -and $sensorData.sensors.Count -gt 0) {
                    $fans = @()
                    foreach ($sensor in $sensorData.sensors) {
                        $fans += @{
                            name = $sensor.name
                            rpm = [int]$sensor.value
                            hardware = $sensor.hardware
                        }
                    }
                    $detectionMethod = "$($sensorData.method) (Hardware Access)"
                    $fanCount = $fans.Count
                }
            } catch {}
        }
        
        # Method 2: Try CIM Win32_Fan (fallback - most compatible)
        if (-not $fans) {
            try {
                $cimFans = Get-CimInstance -Namespace "root/cimv2" -ClassName Win32_Fan -ErrorAction SilentlyContinue
                if ($cimFans) {
                    $fans = @()
                    foreach ($fan in $cimFans) {
                        $fanInfo = @{
                            name = if ($fan.Name) { $fan.Name } else { "Cooling Device" }
                            status = if ($fan.Status) { $fan.Status } else { "OK" }
                        }
                        # Add RPM if available (rarely provided by Windows)
                        if ($fan.DesiredSpeed -and $fan.DesiredSpeed -gt 0) {
                            $fanInfo.rpm = [int]$fan.DesiredSpeed
                        } else {
                            $fanInfo.rpm = "unavailable"
                        }
                        $fans += $fanInfo
                    }
                    $detectionMethod = "CIM"
                    $fanCount = $fans.Count
                }
            } catch {}
        }
        
        # Method 2: Try vendor-specific WMI (Lenovo, Dell, HP, etc.)
        if (-not $fans) {
            try {
                # Try Lenovo
                $lenovoFans = Get-WmiObject -Namespace "root\WMI" -Class "Lenovo_FanTable" -ErrorAction SilentlyContinue
                if ($lenovoFans) {
                    $fans = @()
                    foreach ($fan in $lenovoFans) {
                        $fans += @{
                            name = "Lenovo Fan"
                            rpm = if ($fan.CurrentFanSpeed) { [int]$fan.CurrentFanSpeed } else { "unavailable" }
                            status = "OK"
                        }
                    }
                    $detectionMethod = "Lenovo WMI"
                    $fanCount = $fans.Count
                }
            } catch {}
        }
        
        # Method 3: Infer fan count from system configuration
        if (-not $fans -or $fans.Count -eq 1) {
            try {
                # Check if system has discrete GPU (likely has 2 fans: CPU + GPU)
                $gpuInfo = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | 
                           Where-Object { $_.Name -notlike "*Intel*" -and $_.Name -notlike "*Microsoft*" }
                
                # Check processor type (HX/H series gaming laptops typically have 2 fans)
                $cpuInfo = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
                $isHighPerformance = $cpuInfo.Name -match "HX|H\b" -or $cpuInfo.MaxClockSpeed -gt 3500
                
                # If we detected a discrete GPU or high-performance CPU, likely 2 fans
                if ($gpuInfo -or $isHighPerformance) {
                    if (-not $fans -or $fans.Count -lt 2) {
                        $fans = @(
                            @{
                                name = "CPU Fan"
                                status = "OK"
                                rpm = "unavailable"
                                location = "Processor cooling"
                            },
                            @{
                                name = "GPU Fan" 
                                status = "OK"
                                rpm = "unavailable"
                                location = "Graphics cooling"
                            }
                        )
                        $detectionMethod = "Inferred (Gaming/High-Performance Laptop)"
                        $fanCount = 2
                    }
                }
            } catch {}
        }
        
        # Method 4: Count thermal zones as fallback
        if (-not $fans) {
            try {
                $thermalZones = Get-WmiObject -Namespace "root\wmi" -Class MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
                if ($thermalZones -and $thermalZones.Count -gt 0) {
                    # Most systems have 1 fan per thermal zone
                    $fanCount = $thermalZones.Count
                    $fans = @()
                    for ($i = 0; $i -lt $fanCount; $i++) {
                        $fans += @{
                            name = "Cooling Device"
                            status = "OK"
                            rpm = "unavailable"
                        }
                    }
                    $detectionMethod = "ThermalZone"
                }
            } catch {}
        }
        
        # Method 5: Check cooling device via Win32_Fan alternative classes
        if (-not $fans) {
            try {
                # Some systems expose cooling devices via different class
                $coolingDevices = Get-CimInstance -ClassName Win32_CoolingDevice -ErrorAction SilentlyContinue
                if ($coolingDevices) {
                    $fans = @()
                    foreach ($device in $coolingDevices) {
                        $fans += @{
                            name = if ($device.Name) { $device.Name } else { "Cooling Device" }
                            status = if ($device.Status) { $device.Status } else { "OK" }
                            rpm = "unavailable"
                        }
                    }
                    $detectionMethod = "CoolingDevice"
                    $fanCount = $fans.Count
                }
            } catch {}
        }
        
        # Create final output
        if ($fans -and $fans.Count -gt 0) {
            # If only one fan object, return it directly (not as array)
            if ($fans.Count -eq 1) {
                $fanData = @{
                    fans = $fans[0]
                    detection_method = $detectionMethod
                    fan_count = $fanCount
                    status = "available"
                }
            } else {
                $fanData = @{
                    fans = $fans
                    detection_method = $detectionMethod
                    fan_count = $fanCount
                    status = "available"
                }
            }
        } else {
            # No fans detected - provide minimal info with context
            $fanData = @{
                fans = @{
                    status = "unavailable"
                }
            }
            
            # Add note if hardware library was used but found no sensors
            if ($hardwareLibraryAttempted) {
                $fanData.note = "Hardware library loaded but no fan sensors exposed by manufacturer"
                $fanData.hardware_access = "enabled"
            }
        }

        return $fanData | ConvertTo-Json -Compress -Depth 4

    } catch {
        # Error handling - return unavailable
        $errorData = @{
            fans = @{
                status = "unavailable"
            }
        }
        
        return $errorData | ConvertTo-Json -Compress
    }
}

Get-FanMetrics
exit 0
