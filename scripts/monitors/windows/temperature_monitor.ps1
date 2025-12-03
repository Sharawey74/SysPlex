# Temperature Monitor - PowerShell version
# Attempts to collect temperature data with multi-vendor GPU support

$ErrorActionPreference = "Stop"

function Get-TemperatureMetrics {
    try {
        $cpuTemp = 0
        $gpuTemp = 0
        $gpuVendor = "unknown"
        
        # Try to get CPU temperature from WMI (not commonly available on standard Windows)
        $temps = Get-CimInstance -Namespace "root/wmi" -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
        
        if ($temps) {
            $tempSum = 0
            $count = 0
            
            foreach ($temp in $temps) {
                # Convert from tenths of Kelvin to Celsius
                $celsius = ($temp.CurrentTemperature / 10) - 273.15
                $tempSum += $celsius
                $count++
            }
            
            if ($count -gt 0) {
                $cpuTemp = [math]::Round($tempSum / $count, 1)
            }
        }
        
        # GPU Temperature - Multi-vendor detection
        
        # 1. Try NVIDIA (nvidia-smi)
        try {
            $nvidiaSmi = & nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>$null
            if ($LASTEXITCODE -eq 0 -and $nvidiaSmi) {
                $gpuTemp = [int]$nvidiaSmi.Trim()
                $gpuVendor = "NVIDIA"
            }
        } catch {
            # NVIDIA not available
        }
        
        # 2. Try AMD if NVIDIA not found
        if ($gpuVendor -eq "unknown") {
            try {
                # AMD Radeon Software creates WMI entries
                $amdTemp = Get-CimInstance -Namespace root/AMD/AMDPM -ClassName Temperature -ErrorAction SilentlyContinue
                if ($amdTemp) {
                    $gpuTemp = [int]$amdTemp.CurrentTemperature
                    $gpuVendor = "AMD"
                }
            } catch {
                # AMD WMI not available
            }
        }
        
        # 3. Try Intel if others not found
        if ($gpuVendor -eq "unknown") {
            try {
                # Intel Graphics WMI (newer drivers)
                $intelTemp = Get-CimInstance -Namespace root/Intel -ClassName GraphicsTemperature -ErrorAction SilentlyContinue
                if ($intelTemp) {
                    $gpuTemp = [int]$intelTemp.CurrentTemperature
                    $gpuVendor = "Intel"
                }
            } catch {
                # Intel WMI not available
            }
        }
        
        # 4. Fallback: Try generic ACPI/WMI thermal zones for discrete GPUs
        if ($gpuVendor -eq "unknown" -and $gpuTemp -eq 0) {
            try {
                $thermalZones = Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
                foreach ($zone in $thermalZones) {
                    # Some systems label GPU zones as TZ02, TZ03, etc.
                    if ($zone.InstanceName -like "*GPU*" -or $zone.InstanceName -like "*VGA*" -or $zone.InstanceName -like "*Video*") {
                        $gpuTemp = [math]::Round(($zone.CurrentTemperature / 10) - 273.15, 1)
                        $gpuVendor = "Generic"
                        break
                    }
                }
            } catch {
                # No thermal zones found
            }
        }
        
        # 5. Detect GPU vendor even if temp unavailable
        if ($gpuVendor -eq "unknown") {
            $gpuInfo = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($gpuInfo) {
                if ($gpuInfo.Name -like "*NVIDIA*" -or $gpuInfo.AdapterCompatibility -like "*NVIDIA*") {
                    $gpuVendor = "NVIDIA"
                } elseif ($gpuInfo.Name -like "*AMD*" -or $gpuInfo.Name -like "*Radeon*" -or $gpuInfo.AdapterCompatibility -like "*AMD*") {
                    $gpuVendor = "AMD"
                } elseif ($gpuInfo.Name -like "*Intel*" -or $gpuInfo.AdapterCompatibility -like "*Intel*") {
                    $gpuVendor = "Intel"
                }
            }
        }
        
        # Return result with vendor information
        $result = @{
            temperature = @{
                cpu_celsius = $cpuTemp
                gpu_celsius = $gpuTemp
                gpu_vendor = $gpuVendor
            }
        }
        
        return $result | ConvertTo-Json -Compress
    }
    catch {
        $result = @{
            temperature = @{
                status = "error"
                error = $_.Exception.Message
            }
        }
        return $result | ConvertTo-Json -Compress
    }
}

Get-TemperatureMetrics
exit 0
