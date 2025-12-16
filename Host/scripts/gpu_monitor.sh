#!/usr/bin/env bash
# GPU Monitor - Collects GPU statistics (utilization, memory, temperature)
# Supports: NVIDIA (nvidia-smi), AMD (rocm-smi), Intel (intel_gpu_top), WSL2 PowerShell
# Now detects MULTIPLE GPUs and returns JSON array

set -euo pipefail

# Array to store detected GPUs
declare -a detected_gpus

# Detect if running in WSL2
is_wsl2() {
    if grep -qi "microsoft" /proc/version 2>/dev/null; then
        return 0
    fi
    return 1
}

get_nvidia_gpu() {
    local gpu_name="unknown"
    local gpu_vendor="NVIDIA"
    local gpu_utilization=0
    local gpu_memory_used=0
    local gpu_memory_total=0
    local gpu_temp=0
    local status="ok"
    
    if command -v nvidia-smi &> /dev/null; then
        # Get GPU name
        gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 | xargs)
        
        # Get utilization
        gpu_utilization=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | xargs)
        
        # Get memory
        gpu_memory_used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null | head -1 | xargs)
        gpu_memory_total=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | xargs)
        
        # Get temperature
        gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | xargs)
        
        # Validate data
        gpu_utilization=${gpu_utilization:-0}
        gpu_memory_used=${gpu_memory_used:-0}
        gpu_memory_total=${gpu_memory_total:-0}
        gpu_temp=${gpu_temp:-0}
        
        echo "$gpu_vendor|$gpu_name|$gpu_utilization|$gpu_memory_used|$gpu_memory_total|$gpu_temp|$status"
        return 0
    fi
    
    return 1
}

get_amd_gpu() {
    local gpu_name="unknown"
    local gpu_vendor="AMD"
    local gpu_utilization=0
    local gpu_memory_used=0
    local gpu_memory_total=0
    local gpu_temp=0
    local status="ok"
    
    # Try rocm-smi for AMD GPUs
    if command -v rocm-smi &> /dev/null; then
        gpu_name=$(rocm-smi --showproductname 2>/dev/null | grep -i "gpu" | head -1 | awk '{$1=""; print $0}' | xargs)
        gpu_utilization=$(rocm-smi --showuse 2>/dev/null | grep -oP 'GPU use:\s+\K[0-9]+' | head -1)
        gpu_temp=$(rocm-smi --showtemp 2>/dev/null | grep -oP 'Temperature:\s+\K[0-9.]+' | head -1)
        
        gpu_utilization=${gpu_utilization:-0}
        gpu_temp=${gpu_temp:-0}
        
        echo "$gpu_vendor|$gpu_name|$gpu_utilization|$gpu_memory_used|$gpu_memory_total|$gpu_temp|$status"
        return 0
    fi
    
    # Try lspci for AMD detection
    if command -v lspci &> /dev/null; then
        local amd_gpu=$(lspci 2>/dev/null | grep -i "vga\|3d\|display" | grep -i "amd\|radeon")
        if [ -n "$amd_gpu" ]; then
            gpu_name=$(echo "$amd_gpu" | sed 's/.*: //' | xargs)
            echo "$gpu_vendor|$gpu_name|$gpu_utilization|$gpu_memory_used|$gpu_memory_total|$gpu_temp|$status"
            return 0
        fi
    fi
    
    return 1
}

get_intel_gpu() {
    local gpu_name="unknown"
    local gpu_vendor="Intel"
    local gpu_utilization=0
    local gpu_memory_used=0
    local gpu_memory_total=0
    local gpu_temp=0
    local status="ok"
    
    # Try intel_gpu_top
    if command -v intel_gpu_top &> /dev/null; then
        gpu_name=$(lscpu 2>/dev/null | grep "Model name" | sed 's/Model name: *//' | xargs)
        # intel_gpu_top requires root and continuous monitoring, so we'll skip utilization
    fi
    
    # Try lspci for Intel detection
    if command -v lspci &> /dev/null; then
        local intel_gpu=$(lspci 2>/dev/null | grep -i "vga\|3d\|display" | grep -i "intel")
        if [ -n "$intel_gpu" ]; then
            gpu_name=$(echo "$intel_gpu" | sed 's/.*: //' | xargs)
            echo "Intel|$gpu_name|$gpu_utilization|$gpu_memory_used|$gpu_memory_total|$gpu_temp|$status"
            return 0
        fi
    fi
    
    return 1
}

get_wsl2_gpu() {
    local gpu_name="unknown"
    local gpu_vendor="unknown"
    local gpu_utilization=0
    local gpu_memory_used=0
    local gpu_memory_total=0
    local gpu_temp=0
    local status="ok"
    
    if command -v powershell.exe &> /dev/null; then
        # Try to get GPU info via PowerShell WMI
        local ps_gpu_name=$(powershell.exe -Command "Get-WmiObject Win32_VideoController | Select-Object -First 1 -ExpandProperty Name" 2>/dev/null | tr -d '\r\n' | xargs)
        
        if [ -n "$ps_gpu_name" ]; then
            gpu_name="$ps_gpu_name"
            
            # Determine vendor from name
            if echo "$gpu_name" | grep -qi "nvidia"; then
                gpu_vendor="NVIDIA"
                # Try nvidia-smi via PowerShell
                local ps_temp=$(powershell.exe -Command "nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits" 2>/dev/null | tr -d '\r\n' | xargs)
                local ps_util=$(powershell.exe -Command "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits" 2>/dev/null | tr -d '\r\n' | xargs)
                
                [ -n "$ps_temp" ] && gpu_temp=$ps_temp
                [ -n "$ps_util" ] && gpu_utilization=$ps_util
            elif echo "$gpu_name" | grep -qi "amd\|radeon"; then
                gpu_vendor="AMD"
            elif echo "$gpu_name" | grep -qi "intel"; then
                gpu_vendor="Intel"
            fi
            
            echo "$gpu_vendor|$gpu_name|$gpu_utilization|$gpu_memory_used|$gpu_memory_total|$gpu_temp|$status"
            return 0
        fi
    fi
    
    return 1
}

# Main detection logic - detect ALL GPUs
detected_gpus=()

# Always check for NVIDIA GPU (discrete)
if is_wsl2; then
    # WSL2: Try nvidia-smi first (discrete GPU)
    gpu_output=$(get_nvidia_gpu 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$gpu_output" ]; then
        detected_gpus+=("$gpu_output")
    fi
    
    # Then try WSL2 PowerShell for integrated GPU
    gpu_output=$(get_wsl2_gpu 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$gpu_output" ]; then
        # Check if it's different from NVIDIA (avoid duplicates)
        if [[ ! "$gpu_output" =~ ^NVIDIA ]]; then
            detected_gpus+=("$gpu_output")
        fi
    fi
else
    # Native Linux: Try all GPU types
    gpu_output=$(get_nvidia_gpu 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$gpu_output" ]; then
        detected_gpus+=("$gpu_output")
    fi
    
    gpu_output=$(get_amd_gpu 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$gpu_output" ]; then
        detected_gpus+=("$gpu_output")
    fi
    
    gpu_output=$(get_intel_gpu 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$gpu_output" ]; then
        detected_gpus+=("$gpu_output")
    fi
fi

# If no GPUs detected, try generic lspci
if [ ${#detected_gpus[@]} -eq 0 ]; then
    if command -v lspci &> /dev/null; then
        # Try to detect all GPUs via lspci
        while IFS= read -r gpu_line; do
            if [ -n "$gpu_line" ]; then
                gpu_name=$(echo "$gpu_line" | sed 's/.*: //' | xargs)
                gpu_vendor=$(echo "$gpu_line" | grep -oiE "nvidia|amd|intel|radeon" | head -1 | tr '[:lower:]' '[:upper:]')
                gpu_vendor=${gpu_vendor:-"Unknown"}
                detected_gpus+=("$gpu_vendor|$gpu_name|0|0|0|0|ok")
            fi
        done < <(lspci 2>/dev/null | grep -i "vga\|3d\|display")
    fi
fi

# Output JSON
if [ ${#detected_gpus[@]} -eq 0 ]; then
    # No GPUs detected
    cat <<EOF
{
  "status": "unavailable",
  "count": 0,
  "devices": []
}
EOF
else
    # Output array of GPUs
    echo "{"
    echo "  \"status\": \"ok\","
    echo "  \"count\": ${#detected_gpus[@]},"
    echo "  \"devices\": ["
    
    for i in "${!detected_gpus[@]}"; do
        IFS='|' read gpu_vendor gpu_name gpu_utilization gpu_memory_used gpu_memory_total gpu_temp status <<< "${detected_gpus[$i]}"
        
        # Add comma if not last item
        if [ $i -gt 0 ]; then
            echo "    ,"
        fi
        
        cat <<EOF
    {
      "vendor": "${gpu_vendor}",
      "model": "${gpu_name}",
      "utilization_percent": ${gpu_utilization:-0},
      "memory_used_mb": ${gpu_memory_used:-0},
      "memory_total_mb": ${gpu_memory_total:-0},
      "temperature_celsius": ${gpu_temp:-0},
      "status": "${status}"
    }
EOF
    done
    
    echo "  ]"
    echo "}"
fi

exit 0
