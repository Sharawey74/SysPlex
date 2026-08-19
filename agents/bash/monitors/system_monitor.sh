#!/usr/bin/env bash
# System Monitor - Collects system information
# Docker-compatible: Uses PROC_PATH environment variable

set -euo pipefail

# Use environment variable for /proc path (Docker support)
PROC_PATH="${PROC_PATH:-/proc}"

# Get OS name
get_os_name() {
    if [ -f "${HOST_ROOT:-}/etc/os-release" ]; then
        grep "^PRETTY_NAME=" "${HOST_ROOT:-}/etc/os-release" | cut -d'"' -f2
    elif [ -f /etc/os-release ]; then
        grep "^PRETTY_NAME=" /etc/os-release | cut -d'"' -f2
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macOS $(sw_vers -productVersion 2>/dev/null || echo 'Unknown')"
    else
        uname -s 2>/dev/null || echo "Unknown"
    fi
}

# Get hostname
get_hostname() {
    hostname 2>/dev/null || echo "unknown"
}

# Get uptime in seconds
get_uptime_seconds() {
    if [ -f "$PROC_PATH/uptime" ]; then
        # Linux
        awk '{print int($1)}' "$PROC_PATH/uptime"
    elif command -v sysctl &> /dev/null; then
        # macOS
        local boot_time=$(sysctl -n kern.boottime | awk '{print $4}' | sed 's/,//')
        local current_time=$(date +%s)
        echo $((current_time - boot_time))
    elif command -v uptime &> /dev/null; then
        # Fallback - parse uptime command
        local uptime_str=$(uptime | awk '{print $3}')
        echo $((uptime_str * 60))
    else
        echo "0"
    fi
}

# Get kernel version
get_kernel() {
    uname -r 2>/dev/null || echo "unknown"
}

# Get system information
os_name=$(get_os_name)
hostname=$(get_hostname)
uptime_seconds=$(get_uptime_seconds)
kernel=$(get_kernel)

# Output JSON
cat <<EOF
{
  "os": "$os_name",
  "hostname": "$hostname",
  "uptime_seconds": $uptime_seconds,
  "kernel": "$kernel"
}
EOF

exit 0
