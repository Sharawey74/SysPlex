#!/usr/bin/env bash
# Main Monitor - Orchestrator for Host monitoring
# Refactored from scripts/main_monitor.sh with enhanced GPU support

set -euo pipefail

# Get script directory and Host root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${HOST_ROOT}/output"
TEMP_DIR="${OUTPUT_DIR}/temp"

# Use host paths if in Docker, fallback to normal paths
export PROC_PATH="${HOST_PROC:-/proc}"
export SYS_PATH="${HOST_SYS:-/sys}"
export DEV_PATH="${HOST_DEV:-/dev}"

# Create output directories
mkdir -p "${OUTPUT_DIR}"
mkdir -p "${TEMP_DIR}"

# Log function (simple)
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

# Start monitoring
log_info "Starting Host monitoring collection"
if [ "$PROC_PATH" != "/proc" ]; then
    log_info "Docker mode: Using PROC_PATH=$PROC_PATH"
fi

# Array to store temp file paths
declare -a temp_files=()

# List of monitors to run (INCLUDING new gpu_monitor.sh)
monitors=(
    "system_monitor.sh"
    "cpu_monitor.sh"
    "memory_monitor.sh"
    "disk_monitor.sh"
    "network_monitor.sh"
    "temperature_monitor.sh"
    "gpu_monitor.sh"
    "fan_monitor.sh"
    "smart_monitor.sh"
)

# Run each monitor
for monitor in "${monitors[@]}"; do
    monitor_path="${SCRIPT_DIR}/${monitor}"
    monitor_name="${monitor%.sh}"
    temp_file="${TEMP_DIR}/${monitor_name}.json"
    
    if [ -f "${monitor_path}" ]; then
        log_info "Running ${monitor}"
        
        # Make script executable
        chmod +x "${monitor_path}" 2>/dev/null || true
        
        # Run monitor and save output
        if bash "${monitor_path}" > "${temp_file}" 2>/dev/null; then
            temp_files+=("${temp_file}")
            log_info "${monitor} completed successfully"
        else
            log_error "${monitor} failed with exit code $?"
            # Create error JSON
            echo "{\"status\": \"error\"}" > "${temp_file}"
            temp_files+=("${temp_file}")
        fi
    else
        log_error "${monitor} not found at ${monitor_path}"
    fi
done

# Merge all JSON files
log_info "Merging JSON outputs"

LATEST_OUTPUT="${OUTPUT_DIR}/latest.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")

# Build merged JSON with metadata and proper structure
sections_added=0

{
    echo "{"
    echo "  \"timestamp\": \"${TIMESTAMP}\","
    echo "  \"platform\": \"unix\","
    if [ "$PROC_PATH" != "/proc" ]; then
        echo "  \"docker\": true,"
    fi
    echo ""
    
    # Process each monitor
    for file in "${temp_files[@]}"; do
        if [ -f "${file}" ]; then
            monitor_name=$(basename "${file}" .json)
            
            if content=$(cat "${file}" 2>/dev/null); then
                # Skip empty content
                if [ -z "${content}" ]; then
                    continue
                fi
                
                # Add comma and spacing after previous section
                if [ ${sections_added} -gt 0 ]; then
                    echo ","
                    echo ""
                fi
                
                # Determine content type and format accordingly
                case "${monitor_name}" in
                    system_monitor|cpu_monitor|memory_monitor|temperature_monitor|gpu_monitor|fan_monitor)
                        # Object types - extract inner content without leading/trailing braces
                        inner=$(echo "${content}" | sed '1s/^{//; $s/}$//')
                        
                        # Determine key name
                        key_name="${monitor_name%_monitor}"
                        [ "${key_name}" = "fan" ] && key_name="fans"
                        
                        echo "  \"${key_name}\": {"
                        echo "${inner}" | sed 's/^/    /'
                        echo "  }"
                        ;;
                    disk_monitor|network_monitor|smart_monitor)
                        # Array types - use content as-is
                        key_name="${monitor_name%_monitor}"
                        echo "  \"${key_name}\": ${content}"
                        ;;
                    *)
                        # Unknown type - wrap as object
                        inner=$(echo "${content}" | sed '1s/^{//; $s/}$//')
                        echo "  \"${monitor_name}\": {"
                        echo "${inner}" | sed 's/^/    /'
                        echo "  }"
                        ;;
                esac
                
                sections_added=$((sections_added + 1))
            fi
        fi
    done
    
    echo ""
    echo "}"
} > "${LATEST_OUTPUT}"

# Log merge status AFTER JSON generation
for file in "${temp_files[@]}"; do
    if [ -f "${file}" ]; then
        log_info "Successfully merged: $(basename "${file}")"
    fi
done

log_info "Monitoring data written to: ${LATEST_OUTPUT}"

# Clean up temp files
rm -rf "${TEMP_DIR}"

log_info "Monitoring collection completed"

echo ""
echo "✅ Monitoring data written to: ${LATEST_OUTPUT}"
echo ""

exit 0
