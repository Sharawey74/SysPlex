#!/usr/bin/env bash
# Temperature Monitor - Collects temperature data with multi-method detection
# ENHANCED: WSL2 PowerShell support added
# Docker-compatible: Uses PROC_PATH and SYS_PATH environment variables

set -euo pipefail

# Use environment variables for paths (Docker support)
PROC_PATH="${PROC_PATH:-/proc}"
SYS_PATH="${SYS_PATH:-/sys}"

# Detect if running in WSL2
is_wsl2() {
    if grep -qi "microsoft" /proc/version 2>/dev/null; then
        return 0
    fi
    return 1
}

get_cpu_vendor() {
    local vendor="unknown"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        vendor=$(sysctl -n machdep.cpu.brand_string 2>/dev/null | awk '{print $1}')
    elif [ -f "$PROC_PATH/cpuinfo" ]; then
        local vendor_id=$(grep -m1 "vendor_id" "$PROC_PATH/cpuinfo" | cut -d: -f2 | xargs)
        case "$vendor_id" in
            GenuineIntel) vendor="Intel" ;;
            AuthenticAMD) vendor="AMD" ;;
            *) vendor="${vendor_id:-unknown}" ;;
        esac
    fi
    
    echo "${vendor}"
}

get_gpu_vendor() {
    local vendor="unknown"
    
    # Try nvidia-smi first
    if command -v nvidia-smi &> /dev/null; then
        if nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | grep -qi "nvidia"; then
            vendor="NVIDIA"
        fi
    fi
    
    # Try lspci for GPU detection
    if [ "$vendor" = "unknown" ] && command -v lspci &> /dev/null; then
        if lspci 2>/dev/null | grep -i "vga\|3d\|display" | grep -qi "nvidia"; then
            vendor="NVIDIA"
        elif lspci 2>/dev/null | grep -i "vga\|3d\|display" | grep -qi "amd\|radeon"; then
            vendor="AMD"
        elif lspci 2>/dev/null | grep -i "vga\|3d\|display" | grep -qi "intel"; then
            vendor="Intel"
        fi
    fi
    
    echo "${vendor}"
}

get_temperature_stats() {
    local cpu_temp=0
    local gpu_temp=0
    local status="ok"
    
    # ========================================
    # WSL2 PowerShell Temperature Support
    # ========================================
    if is_wsl2; then
        # Try PowerShell WMI for CPU temperature
        if command -v powershell.exe &> /dev/null; then
            local wmi_temp=$(powershell.exe -Command "(Get-WmiObject MSAcpi_ThermalZoneTemperature -Namespace root/wmi | Select-Object -First 1).CurrentTemperature" 2>/dev/null | tr -d '\r\n' | xargs)
            
            if [ -n "$wmi_temp" ] && [[ "$wmi_temp" =~ ^[0-9]+$ ]]; then
                # Convert from tenths of Kelvin to Celsius
                cpu_temp=$(awk "BEGIN {printf \"%.1f\", ($wmi_temp / 10) - 273.15}")
            fi
        fi
        
        # Try PowerShell for GPU temperature (NVIDIA)
        if [ "$gpu_temp" = "0" ] && command -v powershell.exe &> /dev/null; then
            local gpu_wmi=$(powershell.exe -Command "nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits" 2>/dev/null | tr -d '\r\n' | xargs)
            if [ -n "$gpu_wmi" ] && [[ "$gpu_wmi" =~ ^[0-9]+$ ]]; then
                gpu_temp=$gpu_wmi
            fi
        fi
    fi
    
    # ========================================
    # GPU TEMPERATURE - PRIORITY ORDER
    # ========================================
    
    # PRIORITY 1: NVIDIA GPU (nvidia-smi)
    if [ "$gpu_temp" = "0" ] && command -v nvidia-smi &> /dev/null; then
        gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)
        gpu_temp=${gpu_temp:-0}
    fi
    
    # PRIORITY 2: AMD GPU (rocm-smi)
    if [ "$gpu_temp" = "0" ] && command -v rocm-smi &> /dev/null; then
        gpu_temp=$(rocm-smi --showtemp 2>/dev/null | grep -oP 'Temperature: \K[0-9.]+' | head -1)
        gpu_temp=${gpu_temp:-0}
    fi
    
    # PRIORITY 3: AMD GPU (radeontop)
    if [ "$gpu_temp" = "0" ] && command -v radeontop &> /dev/null; then
        gpu_temp=$(timeout 2s radeontop -d - -l 1 2>/dev/null | grep -oP 'gpu \K[0-9.]+' | head -1)
        gpu_temp=${gpu_temp:-0}
    fi
    
    # PRIORITY 4: Intel GPU (intel_gpu_top)
    if [ "$gpu_temp" = "0" ] && command -v intel_gpu_top &> /dev/null; then
        gpu_temp=$(timeout 2s intel_gpu_top -l -o - 2>/dev/null | grep -oP 'temperature: \K[0-9.]+' | head -1)
        gpu_temp=${gpu_temp:-0}
    fi
    
    # PRIORITY 5: DRM subsystem for GPU
    if [ "$gpu_temp" = "0" ]; then
        for drm_temp in "$SYS_PATH"/class/drm/card*/device/hwmon/hwmon*/temp*_input; do
            if [ -f "$drm_temp" ]; then
                local temp_millidegrees=$(cat "$drm_temp" 2>/dev/null || echo "0")
                if [ "$temp_millidegrees" != "0" ]; then
                    gpu_temp=$(awk "BEGIN {printf \"%.1f\", $temp_millidegrees / 1000}")
                    break
                fi
            fi
        done
    fi
    
    # ========================================
    # CPU TEMPERATURE METHODS
    # ========================================
    
    # METHOD 1: ACPI command
    if [ "$cpu_temp" = "0" ] && command -v acpi &> /dev/null; then
        cpu_temp=$(acpi -t 2>/dev/null | grep -oP 'Thermal \d+: ok, \K[0-9.]+' | head -1)
        cpu_temp=${cpu_temp:-0}
    fi
    
    # METHOD 2: lm-sensors (enhanced patterns)
    if [ "$cpu_temp" = "0" ] && command -v sensors &> /dev/null; then
        local sensors_output=$(sensors 2>/dev/null)
        # Try multiple patterns: Core 0, CPU, Tctl (AMD), Tdie (AMD Ryzen), Package id (Intel)
        cpu_temp=$(echo "$sensors_output" | grep -i "core 0\|^cpu\|tctl\|tdie\|package id" | grep -oP '\+\K[0-9.]+' | head -1)
        cpu_temp=${cpu_temp:-0}
        
        # Try to find GPU temperature from sensors (fallback)
        if [ "$gpu_temp" = "0" ]; then
            gpu_temp=$(echo "$sensors_output" | grep -i "gpu\|radeon\|nvidia\|edge" | grep -oP '\+\K[0-9.]+' | head -1)
            gpu_temp=${gpu_temp:-0}
        fi
    fi
    
    # METHOD 3: /sys/class/hwmon detection
    if [ "$cpu_temp" = "0" ] || [ "$gpu_temp" = "0" ]; then
        for hwmon in "$SYS_PATH"/class/hwmon/hwmon*/temp*_input; do
            if [ -f "$hwmon" ]; then
                local temp_millidegrees=$(cat "$hwmon" 2>/dev/null || echo "0")
                if [ "$temp_millidegrees" != "0" ]; then
                    local temp=$(awk "BEGIN {printf \"%.1f\", $temp_millidegrees / 1000}")
                    
                    # Try to determine if CPU or GPU based on hwmon name
                    local hwmon_name=$(cat "$(dirname "$hwmon")/name" 2>/dev/null || echo "")
                    
                    if [[ "$hwmon_name" =~ coretemp|k10temp|cpu|zenpower ]] && [ "$cpu_temp" = "0" ]; then
                        cpu_temp=$temp
                    elif [[ "$hwmon_name" =~ amdgpu|radeon|nouveau|nvidia ]] && [ "$gpu_temp" = "0" ]; then
                        gpu_temp=$temp
                    elif [ "$cpu_temp" = "0" ]; then
                        # If we can't determine type, assume first temp is CPU
                        cpu_temp=$temp
                    fi
                fi
            fi
        done
    fi
    
    # METHOD 4: Thermal zones (expanded to check multiple zones)
    if [ -d "$SYS_PATH/class/thermal" ] && [ "$cpu_temp" = "0" ]; then
        for zone in "$SYS_PATH"/class/thermal/thermal_zone*/temp; do
            if [ -f "$zone" ]; then
                local temp_millidegrees=$(cat "$zone" 2>/dev/null || echo "0")
                if [ "$temp_millidegrees" != "0" ]; then
                    cpu_temp=$(awk "BEGIN {printf \"%.1f\", $temp_millidegrees / 1000}")
                    break
                fi
            fi
        done
    fi
    
    # ========================================
    # macOS TEMPERATURE SUPPORT
    # ========================================
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # METHOD 1: osx-cpu-temp utility
        if [ "$cpu_temp" = "0" ] && command -v osx-cpu-temp &> /dev/null; then
            cpu_temp=$(osx-cpu-temp -c 2>/dev/null | grep -oP '[0-9.]+' | head -1)
            cpu_temp=${cpu_temp:-0}
        fi
        
        # METHOD 2: sysctl temperature sensors
        if [ "$cpu_temp" = "0" ]; then
            cpu_temp=$(sysctl -a 2>/dev/null | grep -i "temperature" | grep -oP '[0-9.]+' | head -1)
            cpu_temp=${cpu_temp:-0}
        fi
        
        # METHOD 3: ioreg I/O Registry
        if [ "$cpu_temp" = "0" ] && command -v ioreg &> /dev/null; then
            cpu_temp=$(ioreg -l 2>/dev/null | grep -i "temperature" | grep -oP '[0-9.]+' | head -1)
            cpu_temp=${cpu_temp:-0}
        fi
        
        # Mark unavailable if no methods worked
        if [ "$cpu_temp" = "0" ]; then
            status="unavailable"
        fi
    fi
    
    # If no temperature data found for BOTH CPU and GPU, mark as unavailable
    if (( $(echo "$cpu_temp == 0" | bc -l 2>/dev/null || echo "1") )) && (( $(echo "$gpu_temp == 0" | bc -l 2>/dev/null || echo "1") )) && [ "$status" != "unavailable" ]; then
        status="unavailable"
    fi
    
    echo "$cpu_temp" "$gpu_temp" "$status"
}

# Get temperature statistics and vendor info
read cpu_temp gpu_temp status <<< $(get_temperature_stats)
cpu_vendor=$(get_cpu_vendor)
gpu_vendor=$(get_gpu_vendor)

# Output JSON
if [ "$status" = "unavailable" ]; then
    cat <<EOF
{
  "status": "unavailable"
}
EOF
else
    cat <<EOF
{
  "cpu_celsius": ${cpu_temp},
  "cpu_vendor": "${cpu_vendor}",
  "gpu_celsius": ${gpu_temp},
  "gpu_vendor": "${gpu_vendor}",
  "status": "ok"
}
EOF
fi

exit 0
