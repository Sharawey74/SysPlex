#!/usr/bin/env bash
# Temperature Monitor - Docker-optimized version
# Attempts to read from host if possible, falls back to container sensors

set -euo pipefail

# Use environment variables for paths (Docker support)
PROC_PATH="${PROC_PATH:-/proc}"
SYS_PATH="${SYS_PATH:-/sys}"

get_cpu_vendor() {
    local vendor="unknown"
    
    if [ -f "$PROC_PATH/cpuinfo" ]; then
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
    
    # METHOD 1: Try nvidia-smi for GPU
    if command -v nvidia-smi &> /dev/null; then
        gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "0")
        gpu_temp=${gpu_temp:-0}
    fi
    
    # METHOD 2: Try sensors command
    if command -v sensors &> /dev/null; then
        local sensors_output=$(sensors 2>/dev/null || echo "")
        
        if [ -n "$sensors_output" ]; then
            # Try to find CPU temperature
            if [ "$cpu_temp" = "0" ]; then
                cpu_temp=$(echo "$sensors_output" | grep -i "core 0\|cpu\|package" | grep -oP '\+\K[0-9.]+' | head -1 || echo "0")
                cpu_temp=${cpu_temp:-0}
            fi
            
            # Try to find GPU temperature
            if [ "$gpu_temp" = "0" ]; then
                gpu_temp=$(echo "$sensors_output" | grep -i "gpu\|radeon\|nvidia" | grep -oP '\+\K[0-9.]+' | head -1 || echo "0")
                gpu_temp=${gpu_temp:-0}
            fi
        fi
    fi
    
    # METHOD 3: Try /sys/class/hwmon
    if [ "$cpu_temp" = "0" ] || [ "$gpu_temp" = "0" ]; then
        if [ -d "$SYS_PATH/class/hwmon" ]; then
            for hwmon in "$SYS_PATH/class/hwmon"/hwmon*; do
                if [ -f "$hwmon/name" ]; then
                    local name=$(cat "$hwmon/name" 2>/dev/null)
                    
                    # Look for CPU temperature
                    if [ "$cpu_temp" = "0" ] && echo "$name" | grep -qi "coretemp\|k10temp\|cpu"; then
                        for temp_file in "$hwmon"/temp*_input; do
                            if [ -f "$temp_file" ]; then
                                local temp=$(cat "$temp_file" 2>/dev/null)
                                if [ -n "$temp" ] && [ "$temp" -gt 0 ]; then
                                    cpu_temp=$(echo "scale=1; $temp / 1000" | bc 2>/dev/null || echo "$temp")
                                    break
                                fi
                            fi
                        done
                    fi
                    
                    # Look for GPU temperature
                    if [ "$gpu_temp" = "0" ] && echo "$name" | grep -qi "amdgpu\|radeon\|nvidia"; then
                        for temp_file in "$hwmon"/temp*_input; do
                            if [ -f "$temp_file" ]; then
                                local temp=$(cat "$temp_file" 2>/dev/null)
                                if [ -n "$temp" ] && [ "$temp" -gt 0 ]; then
                                    gpu_temp=$(echo "scale=1; $temp / 1000" | bc 2>/dev/null || echo "$temp")
                                    break
                                fi
                            fi
                        done
                    fi
                fi
            done
        fi
    fi
    
    # METHOD 4: Try /sys/class/thermal
    if [ "$cpu_temp" = "0" ]; then
        for thermal_zone in "$SYS_PATH/class/thermal"/thermal_zone*; do
            if [ -d "$thermal_zone" ] && [ -f "$thermal_zone/temp" ]; then
                local temp=$(cat "$thermal_zone/temp" 2>/dev/null)
                if [ -n "$temp" ] && [ "$temp" -gt 0 ]; then
                    cpu_temp=$(echo "scale=1; $temp / 1000" | bc 2>/dev/null || echo "$temp")
                    break
                fi
            fi
        done
    fi
    
    # Round to whole numbers
    cpu_temp=$(printf "%.0f" "$cpu_temp" 2>/dev/null || echo "0")
    gpu_temp=$(printf "%.0f" "$gpu_temp" 2>/dev/null || echo "0")
    
    # If still no data, mark as unavailable
    if [ "$cpu_temp" = "0" ] && [ "$gpu_temp" = "0" ]; then
        status="unavailable"
    fi
    
    # Get vendors
    local cpu_vendor=$(get_cpu_vendor)
    local gpu_vendor=$(get_gpu_vendor)
    
    # Output JSON
    cat <<EOF
{
    "cpu_celsius": $cpu_temp,
    "cpu_vendor": "$cpu_vendor",
    "gpu_celsius": $gpu_temp,
    "gpu_vendor": "$gpu_vendor",
    "status": "$status"
}
EOF
}

# Run and output
get_temperature_stats
