# Hardware Sensor Reader - Embedded Library Approach
# This module provides hardware sensor access without external installations

$ErrorActionPreference = "Stop"

# Function to read hardware sensors using embedded approach
function Get-HardwareSensors {
    param(
        [string]$SensorType  # "Fan", "Temperature", etc.
    )
    
    $result = @{
        sensors = @()
        method = "none"
        success = $false
    }
    
    # Check if bundled LibreHardwareMonitor DLL exists
    $scriptDir = Split-Path -Parent $PSScriptRoot
    $projectRoot = Split-Path -Parent $scriptDir
    $dllPath = Join-Path $projectRoot "libs\LibreHardwareMonitorLib.dll"
    
    if (Test-Path $dllPath) {
        try {
            # Load the bundled DLL
            Add-Type -Path $dllPath -ErrorAction Stop
            
            # Create computer object
            $computer = New-Object LibreHardwareMonitor.Hardware.Computer
            
            # Enable all hardware monitoring
            $computer.IsCpuEnabled = $true
            $computer.IsGpuEnabled = $true
            $computer.IsMemoryEnabled = $true
            $computer.IsMotherboardEnabled = $true
            $computer.IsControllerEnabled = $true
            $computer.IsNetworkEnabled = $true
            $computer.IsStorageEnabled = $true
            
            $computer.Open()
            
            # Collect sensors
            foreach ($hardware in $computer.Hardware) {
                $hardware.Update()
                
                foreach ($sensor in $hardware.Sensors) {
                    if ($SensorType -eq "All" -or $sensor.SensorType.ToString() -eq $SensorType) {
                        $result.sensors += @{
                            name = $sensor.Name
                            value = [math]::Round($sensor.Value, 2)
                            type = $sensor.SensorType.ToString()
                            hardware = $hardware.Name
                            identifier = $sensor.Identifier.ToString()
                        }
                    }
                }
                
                # Check sub-hardware (like GPU sub-sensors)
                foreach ($subHardware in $hardware.SubHardware) {
                    $subHardware.Update()
                    foreach ($sensor in $subHardware.Sensors) {
                        if ($SensorType -eq "All" -or $sensor.SensorType.ToString() -eq $SensorType) {
                            $result.sensors += @{
                                name = $sensor.Name
                                value = [math]::Round($sensor.Value, 2)
                                type = $sensor.SensorType.ToString()
                                hardware = "$($hardware.Name) - $($subHardware.Name)"
                                identifier = $sensor.Identifier.ToString()
                            }
                        }
                    }
                }
            }
            
            $computer.Close()
            
            $result.method = "LibreHardwareMonitor"
            $result.success = $true
            
        } catch {
            # DLL exists but failed to load
            $result.error = "Failed to load bundled library: $($_.Exception.Message)"
        }
    }
    
    return $result
}
