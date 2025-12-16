<#
.SYNOPSIS
    Forensic Report - Reading Test - NVAPI + LibreHardwareMonitor Implementation
    
.DESCRIPTION
    Tests two proven methods for reading actual temperature values:
    1. NVIDIA GPU via NVAPI (native C# P/Invoke)
    2. CPU/GPU via LibreHardwareMonitor (if available)
    
    This script will output ACTUAL temperature values, not just sensor metadata.
    
.NOTES
    File Name  : Test-TemperatureReading-Fixed.ps1
    Author     : System Monitor Project
    Version    : 1.0.1
    Requires   : Run as Administrator
    
.REQUIREMENTS
    For Method 2 (LibreHardwareMonitor):
    Install-Package LibreHardwareMonitorLib -Source nuget.org
    Or download from: https://github.com/LibreHardwareMonitor/LibreHardwareMonitor
#>

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# --- Helper Functions ---

function Write-Banner {
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "   Forensic Report - Reading Test" -ForegroundColor Cyan
    Write-Host "   NVAPI + LibreHardwareMonitor Implementation" -ForegroundColor Cyan
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Log {
    param([string]$Message, [string]$Type="INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $color = switch ($Type) {
        "INFO"    { "White" }
        "SUCCESS" { "Green" }
        "WARN"    { "Yellow" }
        "FAIL"    { "Red" }
        "TEMP"    { "Cyan" }
        default   { "Gray" }
    }
    Write-Host "[$timestamp] [$Type] $Message" -ForegroundColor $color
}

function Test-Admin {
    $currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# --- NVIDIA NVAPI Method ---

$nvApiCode = @"
using System;
using System.Runtime.InteropServices;

public class NvidiaGPU
{
    private const int NVAPI_MAX_PHYSICAL_GPUS = 64;
    private const int NVAPI_MAX_THERMAL_SENSORS_PER_GPU = 3;
    
    [StructLayout(LayoutKind.Sequential)]
    public struct NV_GPU_THERMAL_SETTINGS
    {
        public uint Version;
        public uint Count;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = NVAPI_MAX_THERMAL_SENSORS_PER_GPU)]
        public NV_GPU_THERMAL_SENSOR[] Sensor;
    }
    
    [StructLayout(LayoutKind.Sequential)]
    public struct NV_GPU_THERMAL_SENSOR
    {
        public int Controller;
        public int DefaultMinTemp;
        public int DefaultMaxTemp;
        public int CurrentTemp;
        public int Target;
    }
    
    [DllImport("nvapi64.dll", EntryPoint = "nvapi_QueryInterface", CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr NvAPI_QueryInterface(uint id);
    
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate int NvAPI_InitializeDelegate();
    
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate int NvAPI_EnumPhysicalGPUsDelegate(
        [Out] IntPtr[] gpuHandles,
        out int gpuCount);
    
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate int NvAPI_GPU_GetThermalSettingsDelegate(
        IntPtr gpuHandle,
        int sensorIndex,
        ref NV_GPU_THERMAL_SETTINGS thermalSettings);
    
    private static NvAPI_InitializeDelegate NvAPI_Initialize;
    private static NvAPI_EnumPhysicalGPUsDelegate NvAPI_EnumPhysicalGPUs;
    private static NvAPI_GPU_GetThermalSettingsDelegate NvAPI_GPU_GetThermalSettings;
    
    private const uint NVAPI_ID_INITIALIZE = 0x0150E828;
    private const uint NVAPI_ID_ENUM_PHYSICAL_GPUS = 0xE5AC921F;
    private const uint NVAPI_ID_GPU_GET_THERMAL_SETTINGS = 0xE3640A56;
    
    public static bool Initialize()
    {
        try
        {
            IntPtr ptrInit = NvAPI_QueryInterface(NVAPI_ID_INITIALIZE);
            if (ptrInit == IntPtr.Zero) return false;
            NvAPI_Initialize = Marshal.GetDelegateForFunctionPointer<NvAPI_InitializeDelegate>(ptrInit);
            
            IntPtr ptrEnum = NvAPI_QueryInterface(NVAPI_ID_ENUM_PHYSICAL_GPUS);
            if (ptrEnum == IntPtr.Zero) return false;
            NvAPI_EnumPhysicalGPUs = Marshal.GetDelegateForFunctionPointer<NvAPI_EnumPhysicalGPUsDelegate>(ptrEnum);
            
            IntPtr ptrThermal = NvAPI_QueryInterface(NVAPI_ID_GPU_GET_THERMAL_SETTINGS);
            if (ptrThermal == IntPtr.Zero) return false;
            NvAPI_GPU_GetThermalSettings = Marshal.GetDelegateForFunctionPointer<NvAPI_GPU_GetThermalSettingsDelegate>(ptrThermal);
            
            int result = NvAPI_Initialize();
            return result == 0;
        }
        catch
        {
            return false;
        }
    }
    
    public static int[] GetGPUTemperatures()
    {
        try
        {
            IntPtr[] gpuHandles = new IntPtr[NVAPI_MAX_PHYSICAL_GPUS];
            int gpuCount;
            
            int result = NvAPI_EnumPhysicalGPUs(gpuHandles, out gpuCount);
            if (result != 0 || gpuCount == 0) return new int[0];
            
            int[] temperatures = new int[gpuCount];
            
            for (int i = 0; i < gpuCount; i++)
            {
                NV_GPU_THERMAL_SETTINGS thermalSettings = new NV_GPU_THERMAL_SETTINGS();
                thermalSettings.Version = (uint)(Marshal.SizeOf(typeof(NV_GPU_THERMAL_SETTINGS)) | (2 << 16));
                thermalSettings.Sensor = new NV_GPU_THERMAL_SENSOR[NVAPI_MAX_THERMAL_SENSORS_PER_GPU];
                
                result = NvAPI_GPU_GetThermalSettings(gpuHandles[i], 0, ref thermalSettings);
                
                if (result == 0 && thermalSettings.Count > 0)
                {
                    temperatures[i] = thermalSettings.Sensor[0].CurrentTemp;
                }
                else
                {
                    temperatures[i] = -1;
                }
            }
            
            return temperatures;
        }
        catch
        {
            return new int[0];
        }
    }
}
"@

# --- Main Execution ---

Clear-Host
Write-Banner

$startTime = Get-Date
Write-Log "Temperature reading test started" "INFO"

# Privilege Check
if (-not (Test-Admin)) {
    Write-Log "WARNING: Not running as Administrator. Some methods may fail." "WARN"
} else {
    Write-Log "Running with Administrator privileges" "SUCCESS"
}

$results = @{
    NVAPI = @{ Status = "Not Tested"; Temperatures = @() }
    LibreHardwareMonitor = @{ Status = "Not Tested"; Temperatures = @() }
}

# =============================================================================
# METHOD 1: NVIDIA NVAPI
# =============================================================================

Write-Host ""
Write-Log "Testing Method 1: NVIDIA NVAPI" "INFO"

try {
    # Check if nvapi64.dll exists
    $nvApiPath = Join-Path $env:SystemRoot "System32\nvapi64.dll"
    if (-not (Test-Path $nvApiPath)) {
        Write-Log "nvapi64.dll not found - NVIDIA GPU not present or drivers not installed" "WARN"
        $results.NVAPI.Status = "Not Available"
    } else {
        Write-Log "Found nvapi64.dll - Attempting to initialize NVAPI" "SUCCESS"
        
        # Give GPU a moment to wake up if in low-power state
        Write-Log "Waiting for GPU to be ready..." "INFO"
        Start-Sleep -Milliseconds 200
        
        # Compile and load C# code
        Add-Type -TypeDefinition $nvApiCode -Language CSharp -ErrorAction Stop
        
        # Initialize NVAPI
        $initialized = [NvidiaGPU]::Initialize()
        
        if ($initialized) {
            Write-Log "NVAPI initialized successfully" "SUCCESS"
            
            # Get temperatures
            $temps = [NvidiaGPU]::GetGPUTemperatures()
            
            if ($temps.Length -gt 0) {
                $results.NVAPI.Status = "Success"
                $results.NVAPI.Temperatures = $temps
                
                for ($i = 0; $i -lt $temps.Length; $i++) {
                    if ($temps[$i] -gt 0) {
                        Write-Log "GPU $i Temperature: $($temps[$i])°C" "TEMP"
                    } else {
                        Write-Log "GPU ${i}: Failed to read temperature" "WARN"
                    }
                }
            } else {
                Write-Log "No NVIDIA GPUs detected" "WARN"
                $results.NVAPI.Status = "No GPUs Found"
            }
        } else {
            Write-Log "Failed to initialize NVAPI" "FAIL"
            $results.NVAPI.Status = "Initialization Failed"
        }
    }
} catch {
    Write-Log "NVAPI Method Failed: $($_.Exception.Message)" "FAIL"
    $results.NVAPI.Status = "Error"
    $results.NVAPI.Error = $_.Exception.Message
}

# =============================================================================
# METHOD 2: LibreHardwareMonitor
# =============================================================================

Write-Host ""
Write-Log "Testing Method 2: LibreHardwareMonitor" "INFO"

try {
    # Try to find LibreHardwareMonitorLib.dll
    # FIXED: Using explicit path and better path resolution
    $possiblePaths = @(
        "C:\Users\DELL\Desktop\system-monitor-project\libs\LibreHardwareMonitorLib.dll",
        "$PSScriptRoot\LibreHardwareMonitorLib.dll",
        "$PSScriptRoot\libs\LibreHardwareMonitorLib.dll",
        ".\LibreHardwareMonitorLib.dll",
        ".\libs\LibreHardwareMonitorLib.dll",
        "${env:ProgramFiles}\LibreHardwareMonitor\LibreHardwareMonitorLib.dll",
        "${env:ProgramFiles(x86)}\LibreHardwareMonitor\LibreHardwareMonitorLib.dll"
    )
    
    Write-Log "Searching for LibreHardwareMonitorLib.dll in the following locations:" "INFO"
    
    $dllPath = $null
    foreach ($path in $possiblePaths) {
        Write-Log "  Checking: $path" "INFO"
        if (Test-Path $path) {
            $dllPath = $path
            Write-Log "  ✓ FOUND!" "SUCCESS"
            break
        } else {
            Write-Log "  ✗ Not found" "WARN"
        }
    }
    
    if (-not $dllPath) {
        Write-Log "LibreHardwareMonitorLib.dll not found in any location" "WARN"
        Write-Log "Download from: https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/releases" "INFO"
        Write-Log "Place LibreHardwareMonitorLib.dll in: C:\Users\DELL\Desktop\system-monitor-project\libs\" "INFO"
        $results.LibreHardwareMonitor.Status = "Not Available"
    } else {
        Write-Log "Found LibreHardwareMonitorLib.dll at: $dllPath" "SUCCESS"
        
        # Resolve to absolute path
        $dllPath = Resolve-Path $dllPath
        Write-Log "Resolved absolute path: $dllPath" "INFO"
        
        # Load the assembly
        Write-Log "Loading assembly..." "INFO"
        Add-Type -Path $dllPath -ErrorAction Stop
        Write-Log "Assembly loaded successfully" "SUCCESS"
        
        # Create Computer object and enable hardware monitoring
        Write-Log "Initializing hardware monitoring..." "INFO"
        $computer = New-Object LibreHardwareMonitor.Hardware.Computer
        $computer.IsCpuEnabled = $true
        $computer.IsGpuEnabled = $true
        $computer.IsMemoryEnabled = $true
        $computer.IsMotherboardEnabled = $true
        $computer.IsStorageEnabled = $true
        
        $computer.Open()
        Write-Log "LibreHardwareMonitor initialized successfully" "SUCCESS"
        
        $tempList = @()
        
        # Read all hardware
        foreach ($hardware in $computer.Hardware) {
            $hardware.Update()
            
            Write-Log "Hardware: $($hardware.Name) ($($hardware.HardwareType))" "INFO"
            
            foreach ($sensor in $hardware.Sensors) {
                if ($sensor.SensorType -eq [LibreHardwareMonitor.Hardware.SensorType]::Temperature) {
                    $tempValue = $sensor.Value
                    if ($tempValue) {
                        $tempObj = @{
                            Hardware = $hardware.Name
                            HardwareType = $hardware.HardwareType.ToString()
                            Sensor = $sensor.Name
                            Temperature = [math]::Round($tempValue, 1)
                            Unit = "°C"
                        }
                        $tempList += $tempObj
                        Write-Log "  └─ $($sensor.Name): $([math]::Round($tempValue, 1))°C" "TEMP"
                    }
                }
            }
            
            # Check sub-hardware (like individual CPU cores)
            foreach ($subhardware in $hardware.SubHardware) {
                $subhardware.Update()
                foreach ($sensor in $subhardware.Sensors) {
                    if ($sensor.SensorType -eq [LibreHardwareMonitor.Hardware.SensorType]::Temperature) {
                        $tempValue = $sensor.Value
                        if ($tempValue) {
                            $tempObj = @{
                                Hardware = "$($hardware.Name) - $($subhardware.Name)"
                                HardwareType = $subhardware.HardwareType.ToString()
                                Sensor = $sensor.Name
                                Temperature = [math]::Round($tempValue, 1)
                                Unit = "°C"
                            }
                            $tempList += $tempObj
                            Write-Log "    └─ $($sensor.Name): $([math]::Round($tempValue, 1))°C" "TEMP"
                        }
                    }
                }
            }
        }
        
        $computer.Close()
        
        if ($tempList.Count -gt 0) {
            $results.LibreHardwareMonitor.Status = "Success"
            $results.LibreHardwareMonitor.Temperatures = $tempList
            Write-Log "Successfully read $($tempList.Count) temperature sensor(s)" "SUCCESS"
        } else {
            Write-Log "No temperature sensors found" "WARN"
            $results.LibreHardwareMonitor.Status = "No Sensors Found"
        }
    }
} catch {
    Write-Log "LibreHardwareMonitor Method Failed: $($_.Exception.Message)" "FAIL"
    Write-Log "Stack Trace: $($_.Exception.StackTrace)" "FAIL"
    $results.LibreHardwareMonitor.Status = "Error"
    $results.LibreHardwareMonitor.Error = $_.Exception.Message
}

# =============================================================================
# FINAL REPORT
# =============================================================================

$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "   FINAL TEMPERATURE READING REPORT" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

$finalReport = @{
    Timestamp = $endTime.ToString("yyyy-MM-dd HH:mm:ss")
    Duration_Seconds = [math]::Round($duration, 2)
    Methods_Tested = @("NVAPI", "LibreHardwareMonitor")
    Results = $results
}

$jsonReport = $finalReport | ConvertTo-Json -Depth 6
Write-Host $jsonReport

# Summary
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "   SUMMARY" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

if ($results.NVAPI.Status -eq "Success") {
    Write-Host "[✓] NVAPI Method: WORKING - Found $($results.NVAPI.Temperatures.Length) GPU(s)" -ForegroundColor Green
} else {
    Write-Host "[✗] NVAPI Method: $($results.NVAPI.Status)" -ForegroundColor Yellow
}

if ($results.LibreHardwareMonitor.Status -eq "Success") {
    Write-Host "[✓] LibreHardwareMonitor: WORKING - Found $($results.LibreHardwareMonitor.Temperatures.Count) sensor(s)" -ForegroundColor Green
} else {
    Write-Host "[✗] LibreHardwareMonitor: $($results.LibreHardwareMonitor.Status)" -ForegroundColor Yellow
}

Write-Host ""
Write-Log "Test completed in $([math]::Round($duration, 2)) seconds" "INFO"

# Save to file
$reportPath = "temperature_reading_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
$jsonReport | Set-Content $reportPath
Write-Log "Report saved to: $reportPath" "SUCCESS"

exit 0