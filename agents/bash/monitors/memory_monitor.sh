#!/usr/bin/env bash
# Memory Monitor - Collects memory statistics
# Docker-compatible: Uses PROC_PATH environment variable

set -euo pipefail

# Use environment variable for /proc path (Docker support)
PROC_PATH="${PROC_PATH:-/proc}"

get_memory_stats() {
    local total_mb=0
    local used_mb=0
    local free_mb=0
    local available_mb=0
    
    if command -v free &> /dev/null; then
        # Linux with 'free' command
        local mem_line=$(free -m | grep "^Mem:")
        total_mb=$(echo "$mem_line" | awk '{print $2}')
        used_mb=$(echo "$mem_line" | awk '{print $3}')
        free_mb=$(echo "$mem_line" | awk '{print $4}')
        available_mb=$(echo "$mem_line" | awk '{print $7}')
        available_mb=${available_mb:-$free_mb}
    elif [ -f "$PROC_PATH/meminfo" ]; then
        # Linux via /proc/meminfo
        total_kb=$(grep "^MemTotal:" "$PROC_PATH/meminfo" | awk '{print $2}')
        free_kb=$(grep "^MemFree:" "$PROC_PATH/meminfo" | awk '{print $2}')
        available_kb=$(grep "^MemAvailable:" "$PROC_PATH/meminfo" | awk '{print $2}')
        available_kb=${available_kb:-$free_kb}
        
        total_mb=$((total_kb / 1024))
        free_mb=$((free_kb / 1024))
        available_mb=$((available_kb / 1024))
        used_mb=$((total_mb - available_mb))
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        total_bytes=$(sysctl -n hw.memsize)
        total_mb=$((total_bytes / 1024 / 1024))
        
        # Get page statistics
        vm_stat_output=$(vm_stat)
        pages_free=$(echo "$vm_stat_output" | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
        pages_active=$(echo "$vm_stat_output" | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
        pages_wired=$(echo "$vm_stat_output" | grep "Pages wired down" | awk '{print $4}' | sed 's/\.//')
        
        page_size=4096
        free_mb=$(((pages_free * page_size) / 1024 / 1024))
        used_mb=$(((pages_active + pages_wired) * page_size / 1024 / 1024))
        available_mb=$free_mb
    fi
    
    # Calculate usage percentage
    local usage_percent=0
    if [ "$total_mb" -gt 0 ]; then
        usage_percent=$(awk "BEGIN {printf \"%.1f\", ($used_mb / $total_mb) * 100}")
    fi
    
    echo "$total_mb" "$used_mb" "$free_mb" "$available_mb" "$usage_percent"
}

# Get memory statistics
read total_mb used_mb free_mb available_mb usage_percent <<< $(get_memory_stats)

# Output JSON
cat <<EOF
{
  "total_mb": ${total_mb},
  "used_mb": ${used_mb},
  "free_mb": ${free_mb},
  "available_mb": ${available_mb},
  "usage_percent": ${usage_percent},
  "status": "ok"
}
EOF

exit 0
