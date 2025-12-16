# 🖥️ Host System Monitor

Dedicated host monitoring module with TCP API and systemd integration.

## 📋 Overview

This module provides comprehensive system monitoring for Linux/Unix hosts with:
- **Native monitoring scripts** (Bash) for CPU, memory, disk, network, temperature, GPU, fans
- **Enhanced WSL2 support** with PowerShell fallback for hardware sensors
- **TCP Metrics API** (FastAPI on port 9999)
- **Systemd integration** for automated monitoring
- **JSON output** at `Host/output/latest.json`

## 📂 Directory Structure

```
Host/
├── scripts/                    # Monitoring scripts
│   ├── cpu_monitor.sh         # CPU usage, load averages
│   ├── memory_monitor.sh      # Memory statistics
│   ├── disk_monitor.sh        # Disk usage
│   ├── network_monitor.sh     # Network interfaces
│   ├── temperature_monitor.sh # CPU/GPU temperatures (WSL2 enhanced)
│   ├── gpu_monitor.sh         # GPU stats (NEW - NVIDIA/AMD/Intel)
│   ├── fan_monitor.sh         # Fan speeds
│   ├── smart_monitor.sh       # SMART disk health
│   ├── system_monitor.sh      # System information
│   └── main_monitor.sh        # Orchestrator script
│
├── loop/
│   └── host_monitor_loop.sh   # Continuous monitoring (60s interval)
│
├── api/
│   ├── server.py              # FastAPI TCP server (port 9999)
│   └── requirements.txt       # Python dependencies
│
├── output/
│   └── latest.json            # Current metrics output
│
├── service/
│   └── host-monitor.service   # Systemd service unit
│
└── README.md                  # This file
```

## 🚀 Quick Start

### 1. Manual Monitoring (One-Time)

```bash
cd Host/scripts
chmod +x *.sh
./main_monitor.sh
```

Output: `Host/output/latest.json`

### 2. Continuous Monitoring (Loop)

```bash
cd Host/loop
chmod +x host_monitor_loop.sh
./host_monitor_loop.sh
```

Collects metrics every 60 seconds. Press `Ctrl+C` to stop.

### 3. Start TCP API Server

```bash
cd Host/api
pip install -r requirements.txt
python server.py
```

Access API at: `http://localhost:9999`

**Endpoints:**
- `GET /metrics` - Current system metrics
- `GET /health` - Health check
- `GET /` - API information
- `GET /docs` - Swagger UI documentation

### 4. Systemd Service (Linux)

```bash
# 1. Edit service file with correct paths
sudo nano Host/service/host-monitor.service

# 2. Copy to systemd directory
sudo cp Host/service/host-monitor.service /etc/systemd/system/

# 3. Reload systemd
sudo systemctl daemon-reload

# 4. Enable service (start on boot)
sudo systemctl enable host-monitor

# 5. Start service
sudo systemctl start host-monitor

# 6. Check status
sudo systemctl status host-monitor

# 7. View logs
sudo journalctl -u host-monitor -f
```

## 📊 Enhanced Features

### 🔥 WSL2 Temperature Monitoring

The `temperature_monitor.sh` script now includes **WSL2 PowerShell support**:

```bash
# Automatically detects WSL2 and uses:
# 1. PowerShell WMI for CPU temperature
# 2. PowerShell nvidia-smi for GPU temperature
# 3. Falls back to native sensors if available
```

**Methods used (in order):**
1. **WSL2 PowerShell WMI** - Windows hardware access
2. **nvidia-smi** - NVIDIA GPU detection
3. **lm-sensors** - Linux hardware sensors
4. **/sys/class/hwmon** - Kernel hardware monitoring
5. **Thermal zones** - Generic thermal data
6. **macOS detection** - For macOS systems

### 🎮 GPU Monitoring (NEW)

The new `gpu_monitor.sh` script provides comprehensive GPU statistics:

**Supported GPUs:**
- ✅ **NVIDIA** - via nvidia-smi (utilization, memory, temperature)
- ✅ **AMD** - via rocm-smi or lspci
- ✅ **Intel** - via lspci detection
- ✅ **WSL2** - via PowerShell WMI fallback

**Collected metrics:**
- GPU vendor (NVIDIA/AMD/Intel)
- GPU model name
- GPU utilization percentage
- GPU memory (used/total in MB)
- GPU temperature (Celsius)

## 📋 Output Format

### latest.json Structure

```json
{
  "timestamp": "2025-12-11T12:30:00Z",
  "platform": "unix",
  "system": {
    "os": "Ubuntu 24.04.3 LTS",
    "hostname": "DESKTOP-T66SL92",
    "uptime_seconds": 3240,
    "kernel": "5.15.167.4-microsoft-standard-WSL2"
  },
  "cpu": {
    "usage_percent": 15.2,
    "load_1": 0.5,
    "load_5": 0.8,
    "load_15": 1.0,
    "logical_processors": 8,
    "vendor": "Intel",
    "model": "11th Gen Intel(R) Core(TM) i7-11657G @ 2.80GHz",
    "status": "ok"
  },
  "memory": {
    "total_mb": 7620,
    "used_mb": 890,
    "free_mb": 6340,
    "available_mb": 6750,
    "usage_percent": 11.4,
    "status": "ok"
  },
  "disk": [
    {
      "device": "/",
      "filesystem": "/dev/sdc",
      "total_gb": 1007.85,
      "used_gb": 0.77,
      "used_percent": 0.1
    }
  ],
  "network": [
    {
      "iface": "eth0",
      "rx_bytes": 1234567890,
      "tx_bytes": 987654321
    }
  ],
  "temperature": {
    "cpu_celsius": 65.0,
    "cpu_vendor": "Intel",
    "gpu_celsius": 55.0,
    "gpu_vendor": "NVIDIA",
    "status": "ok"
  },
  "gpu": {
    "vendor": "NVIDIA",
    "model": "NVIDIA GeForce GTX 1650",
    "utilization_percent": 25,
    "memory_used_mb": 1024,
    "memory_total_mb": 4096,
    "temperature_celsius": 55,
    "status": "ok"
  },
  "fans": {
    "status": "unavailable"
  },
  "smart": {
    "status": "restricted"
  }
}
```

## 🔌 API Usage Examples

### cURL Examples

```bash
# Get current metrics
curl http://localhost:9999/metrics

# Health check
curl http://localhost:9999/health

# Pretty print with jq
curl -s http://localhost:9999/metrics | jq '.data.cpu'
```

### Python Example

```python
import requests

# Get metrics
response = requests.get("http://localhost:9999/metrics")
data = response.json()

if data["status"] == "ok":
    cpu_usage = data["data"]["cpu"]["usage_percent"]
    print(f"CPU Usage: {cpu_usage}%")
    
    if "gpu" in data["data"]:
        gpu_vendor = data["data"]["gpu"]["vendor"]
        gpu_temp = data["data"]["gpu"]["temperature_celsius"]
        print(f"GPU: {gpu_vendor} @ {gpu_temp}°C")
```

### JavaScript Example

```javascript
// Fetch metrics
fetch('http://localhost:9999/metrics')
  .then(response => response.json())
  .then(data => {
    if (data.status === 'ok') {
      console.log('CPU Usage:', data.data.cpu.usage_percent + '%');
      console.log('Memory Usage:', data.data.memory.usage_percent + '%');
      
      if (data.data.gpu && data.data.gpu.status === 'ok') {
        console.log('GPU:', data.data.gpu.vendor, data.data.gpu.model);
        console.log('GPU Temp:', data.data.gpu.temperature_celsius + '°C');
      }
    }
  });
```

## 🛠️ Configuration

### Monitoring Interval

Edit `Host/loop/host_monitor_loop.sh`:

```bash
INTERVAL=60  # Change to desired seconds (default: 60)
```

### API Port

Edit `Host/api/server.py`:

```python
API_PORT = 9999  # Change to desired port
```

### Environment Variables

```bash
# Set custom paths (optional)
export PROC_PATH=/proc
export SYS_PATH=/sys
export DEV_PATH=/dev
```

## 🔧 Dependencies

### Required (Linux)

```bash
# Ubuntu/Debian
sudo apt-get install bash coreutils procps

# RHEL/CentOS
sudo yum install bash coreutils procps
```

### Optional (Enhanced Features)

```bash
# For CPU/GPU temperatures
sudo apt-get install lm-sensors

# For NVIDIA GPUs
sudo apt-get install nvidia-utils

# For AMD GPUs
sudo apt-get install rocm-smi

# For SMART disk health
sudo apt-get install smartmontools

# For Python API
pip install fastapi uvicorn
```

## 🧪 Testing

### Test Individual Monitor

```bash
cd Host/scripts
./cpu_monitor.sh | jq .
./gpu_monitor.sh | jq .
./temperature_monitor.sh | jq .
```

### Test Full Collection

```bash
cd Host/scripts
./main_monitor.sh
cat ../output/latest.json | jq .
```

### Test API

```bash
# Start API server
cd Host/api
python server.py &

# Test endpoints
curl http://localhost:9999/health
curl http://localhost:9999/metrics | jq .

# Stop server
pkill -f "python server.py"
```

## 🐛 Troubleshooting

### Temperature shows "unavailable"

```bash
# Install lm-sensors
sudo apt-get install lm-sensors
sudo sensors-detect  # Detect sensors

# For WSL2, ensure powershell.exe is available
which powershell.exe
```

### GPU not detected

```bash
# Check if nvidia-smi works
nvidia-smi

# For WSL2, ensure NVIDIA drivers installed on Windows
# See: https://docs.nvidia.com/cuda/wsl-user-guide/
```

### SMART status shows "restricted"

```bash
# Run with sudo for SMART access
sudo ./scripts/main_monitor.sh

# Or add user to disk group
sudo usermod -a -G disk $USER
```

### API server won't start

```bash
# Check if port 9999 is available
sudo netstat -tulpn | grep 9999

# Install dependencies
cd Host/api
pip install -r requirements.txt

# Check for errors
python server.py
```

## 📖 Integration Examples

### Use with Docker Dashboard

```bash
# Start host monitoring (writes to Host/output/latest.json)
cd Host/loop
./host_monitor_loop.sh &

# Docker can read this file via volume mount:
# docker-compose.yml:
#   volumes:
#     - ./Host/output:/app/host_metrics:ro
```

### Use with Prometheus/Grafana

```bash
# Start API server
cd Host/api
python server.py &

# Configure Prometheus to scrape:
# (You'd need to add a /metrics endpoint in Prometheus format)
```

### Use with Custom Application

```bash
# Your app can read JSON directly:
cat Host/output/latest.json | jq '.cpu.usage_percent'

# Or call API:
curl -s http://localhost:9999/metrics | jq '.data.cpu.usage_percent'
```

## 🔐 Security Notes

- **API Server**: Runs on `0.0.0.0` (all interfaces) by default
  - For production, bind to `127.0.0.1` or add authentication
- **SMART monitoring**: May require sudo/root privileges
- **Systemd service**: Runs as specified user (change `User=%i` in service file)

## 📝 License

Part of the System Monitor Project.

## 🤝 Contributing

This module is designed to be extensible:
- Add new monitors in `Host/scripts/`
- Update `main_monitor.sh` to include new monitors
- Follow existing script patterns for consistency

## 📚 References

- [lm-sensors Documentation](https://github.com/lm-sensors/lm-sensors)
- [nvidia-smi Reference](https://developer.nvidia.com/nvidia-system-management-interface)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Systemd Service Files](https://www.freedesktop.org/software/systemd/man/systemd.service.html)

---

**Last Updated:** December 11, 2025
**Version:** 1.0.0
**Status:** Production Ready ✅
