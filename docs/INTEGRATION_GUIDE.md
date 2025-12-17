# 🔗 Integration Guide: Host Module with Existing System

This guide explains how the new **Host/** module integrates with your existing Docker-based monitoring system.

## 📊 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    System Monitor Architecture                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Host Module (NEW)                                        │  │
│  │ Location: Host/                                          │  │
│  │ ┌──────────────────────────────────────────────────────┐│  │
│  │ │ Monitoring Scripts (Bash)                           ││  │
│  │ │  - cpu_monitor.sh                                    ││  │
│  │ │  - memory_monitor.sh                                 ││  │
│  │ │  - temperature_monitor.sh (WSL2 enhanced)           ││  │
│  │ │  - gpu_monitor.sh (NEW)                             ││  │
│  │ │  - ... and 5 more                                    ││  │
│  │ │                                                       ││  │
│  │ │ Output: Host/output/latest.json                     ││  │
│  │ └──────────────────────────────────────────────────────┘│  │
│  │                          ↓                                │  │
│  │ ┌──────────────────────────────────────────────────────┐│  │
│  │ │ TCP API Server (FastAPI - Port 9999)                ││  │
│  │ │  GET /metrics → returns latest.json                 ││  │
│  │ │  GET /health  → health check                        ││  │
│  │ └──────────────────────────────────────────────────────┘│  │
│  └──────────────────────────────────────────────────────────┘  │
│                              ↓                                   │
│                      (3 Integration Options)                    │
│                              ↓                                   │
│  ┌────────────┬───────────────────────┬────────────────────┐   │
│  │ Option 1   │ Option 2              │ Option 3           │   │
│  │ Direct     │ Docker Volume         │ API Call           │   │
│  │ File Read  │ Mount                 │                    │   │
│  └────────────┴───────────────────────┴────────────────────┘   │
│       ↓               ↓                       ↓                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Existing System                                          │  │
│  │                                                          │  │
│  │  ┌────────────────────────────────────────────────────┐│  │
│  │  │ Docker Container (Method 1 or 2)                   ││  │
│  │  │  - Flask Web Dashboard (port 5000/5001)            ││  │
│  │  │  - core/metrics_collector.py                       ││  │
│  │  │  - display/tui_dashboard.py                        ││  │
│  │  └────────────────────────────────────────────────────┘│  │
│  └──────────────────────────────────────────────────────────┘  │
│                              ↓                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ User Interface                                           │  │
│  │  - Web Browser: http://localhost:5000                   │  │
│  │  - Terminal: Rich TUI dashboard                         │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## 🎯 Integration Options

### Option 1: Direct File Read (Simplest)

**Use Case:** Docker reads Host/output/latest.json directly

**Setup:**
```bash
# 1. Start Host monitoring
cd Host/loop
./host_monitor_loop.sh &

# 2. Docker container reads from shared filesystem
# The file is already accessible at:
# /mnt/c/Users/DELL/Desktop/system-monitor-project-Batch/Host/output/latest.json
```

**Update Docker compose:**
```yaml
# docker-compose.method2.yml
volumes:
  - ../Host/output:/app/host_metrics:ro  # Mount Host output as read-only
```

**Update metrics_collector.py:**
```python
# Add fallback to Host/output/latest.json
def load_current_metrics(path: str = DEFAULT_METRICS_PATH) -> Dict[str, Any]:
    # Try default path first
    if Path(path).exists():
        return _load_from_file(path)
    
    # Fallback to Host output
    host_metrics = Path("/app/host_metrics/latest.json")
    if host_metrics.exists():
        return _load_from_file(str(host_metrics))
    
    return _get_empty_metrics()
```

---

### Option 2: Docker Volume Mount (Recommended)

**Use Case:** Clean separation with explicit volume mounting

**Docker Compose Update:**
```yaml
# docker-compose.method1.yml or method2.yml
volumes:
  # Existing volumes
  - ../data:/app/data
  - ../reports:/app/reports
  
  # NEW: Mount Host output
  - ../Host/output:/app/host_metrics:ro
```

**Python Integration:**
```python
# core/metrics_collector.py

HOST_METRICS_PATH = "/app/host_metrics/latest.json"

def load_host_metrics() -> Dict[str, Any]:
    """Load metrics from Host module"""
    host_path = Path(HOST_METRICS_PATH)
    if host_path.exists():
        with host_path.open('r', encoding='utf-8-sig') as f:
            return json.load(f)
    return {}

def load_current_metrics(path: str = DEFAULT_METRICS_PATH) -> Dict[str, Any]:
    """Load metrics with Host fallback"""
    # Try container's own collection first
    if Path(path).exists():
        container_metrics = _load_from_file(path)
        if container_metrics:
            return container_metrics
    
    # Fallback to Host module
    return load_host_metrics()
```

---

### Option 3: API-Based Integration (Most Flexible)

**Use Case:** Microservices architecture with network separation

**Start Host API:**
```bash
cd Host/api
pip install -r requirements.txt
python server.py &
# API running on http://localhost:9999
```

**Python Integration:**
```python
# core/metrics_collector.py
import requests

HOST_API_URL = "http://localhost:9999/metrics"

def load_host_metrics_api() -> Dict[str, Any]:
    """Load metrics from Host API"""
    try:
        response = requests.get(HOST_API_URL, timeout=2)
        response.raise_for_status()
        data = response.json()
        
        if data.get("status") == "ok":
            return data.get("data", {})
    except requests.exceptions.RequestException:
        pass
    
    return {}

def load_current_metrics(path: str = DEFAULT_METRICS_PATH) -> Dict[str, Any]:
    """Load metrics with multiple fallbacks"""
    # 1. Try container's own collection
    if Path(path).exists():
        container_metrics = _load_from_file(path)
        if container_metrics:
            return container_metrics
    
    # 2. Try Host API
    api_metrics = load_host_metrics_api()
    if api_metrics:
        return api_metrics
    
    # 3. Return empty metrics
    return _get_empty_metrics()
```

**Update requirements.txt:**
```python
# Add to project requirements.txt
requests>=2.31.0
```

---

## 🔄 Migration Workflow

### Current State → With Host Module

**Before:**
```bash
# Old workflow
scripts/host_monitor_loop.sh  # Writes to data/metrics/current.json
    ↓
Docker reads data/metrics/current.json
    ↓
Dashboard displays metrics
```

**After (Recommended):**
```bash
# New workflow with Host module
Host/loop/host_monitor_loop.sh  # Writes to Host/output/latest.json
    ↓
Docker volume mounts Host/output (read-only)
    ↓
metrics_collector.py reads from /app/host_metrics/latest.json
    ↓
Dashboard displays metrics (with GPU data!)
```

---

## 🛠️ Step-by-Step Migration

### Step 1: Test Host Module

```bash
# Terminal 1: Run Host monitoring
cd Host
bash quickstart.sh
# Select option 1 to test

# Verify output
cat output/latest.json | jq '.gpu'
```

### Step 2: Update Docker Configuration

```bash
# Edit docker-compose.method2.yml
nano Docker/docker-compose.method2.yml

# Add volume mount:
volumes:
  - ../Host/output:/app/host_metrics:ro
```

### Step 3: Update Metrics Collector

```bash
# Edit core/metrics_collector.py
nano core/metrics_collector.py

# Add at top:
HOST_METRICS_PATH = "/app/host_metrics/latest.json"

# Add function:
def load_host_metrics():
    host_path = Path(HOST_METRICS_PATH)
    if host_path.exists():
        with host_path.open('r', encoding='utf-8-sig') as f:
            return json.load(f)
    return {}

# Update load_current_metrics() to check HOST_METRICS_PATH
```

### Step 4: Restart System

```bash
# Terminal 1: Start Host monitoring
cd Host/loop
./host_monitor_loop.sh &

# Terminal 2: Restart Docker
docker-compose -f Docker/docker-compose.method2.yml down
docker-compose -f Docker/docker-compose.method2.yml up -d

# Terminal 3: Check logs
docker-compose -f Docker/docker-compose.method2.yml logs -f

# Browser: Check dashboard
open http://localhost:5000
```

---

## 📊 Data Flow Comparison

### Original System

```
scripts/main_monitor.sh
    ├─ cpu_monitor.sh
    ├─ memory_monitor.sh
    ├─ disk_monitor.sh
    ├─ network_monitor.sh
    ├─ temperature_monitor.sh  (limited WSL2 support)
    ├─ fan_monitor.sh
    └─ smart_monitor.sh
         ↓
    data/metrics/current.json
         ↓
    Docker reads current.json
         ↓
    Flask Dashboard (port 5000/5001)
```

### With Host Module

```
Host/scripts/main_monitor.sh
    ├─ system_monitor.sh
    ├─ cpu_monitor.sh
    ├─ memory_monitor.sh
    ├─ disk_monitor.sh
    ├─ network_monitor.sh
    ├─ temperature_monitor.sh  (ENHANCED WSL2 PowerShell)
    ├─ gpu_monitor.sh          (NEW - NVIDIA/AMD/Intel)
    ├─ fan_monitor.sh
    └─ smart_monitor.sh
         ↓
    Host/output/latest.json  (includes GPU data!)
         ↓
    ┌──────────────────┬─────────────────┐
    │   Direct Read    │   API Server    │
    │   (File mount)   │   (Port 9999)   │
    └──────────────────┴─────────────────┘
         ↓                      ↓
    Docker volume          HTTP request
         ↓                      ↓
    metrics_collector.py reads either source
         ↓
    Flask Dashboard (port 5000/5001)
         ↓
    GPU metrics now visible! 🎉
```

---

## 🎨 Dashboard Updates for GPU Data

### Update TUI Dashboard

```python
# display/tui_dashboard.py

def generate_gpu_panel(self, metrics: Dict[str, Any]) -> Panel:
    """Generate GPU metrics panel (NEW)"""
    gpu = metrics.get('gpu', {})
    
    if gpu.get('status') == 'unavailable':
        return Panel("GPU: Not detected", style="dim")
    
    vendor = gpu.get('vendor', 'unknown')
    model = gpu.get('model', 'unknown')
    utilization = gpu.get('utilization_percent', 0)
    temp = gpu.get('temperature_celsius', 0)
    memory_used = gpu.get('memory_used_mb', 0)
    memory_total = gpu.get('memory_total_mb', 0)
    
    table = Table(show_header=False, box=None)
    table.add_row("Vendor:", f"[cyan]{vendor}[/cyan]")
    table.add_row("Model:", f"[white]{model}[/white]")
    table.add_row("Utilization:", f"[yellow]{utilization}%[/yellow]")
    table.add_row("Temperature:", f"[red]{temp}°C[/red]")
    table.add_row("Memory:", f"{memory_used}/{memory_total} MB")
    
    return Panel(table, title="🎮 GPU", border_style="green")
```

### Update Web Dashboard

```html
<!-- templates/dashboard.html -->

<!-- Add GPU Panel -->
<div class="panel">
    <div class="panel-header">
        <h2>🎮 GPU</h2>
    </div>
    <div class="panel-body">
        <div class="metric-details">
            <div class="detail-item">
                <span class="detail-label">Vendor:</span>
                <span class="detail-value" id="gpuVendor">-</span>
            </div>
            <div class="detail-item">
                <span class="detail-label">Model:</span>
                <span class="detail-value" id="gpuModel">-</span>
            </div>
            <div class="detail-item">
                <span class="detail-label">Utilization:</span>
                <span class="detail-value" id="gpuUtil">-</span>
            </div>
            <div class="detail-item">
                <span class="detail-label">Temperature:</span>
                <span class="detail-value" id="gpuTemp">-</span>
            </div>
        </div>
    </div>
</div>
```

```javascript
// static/js/dashboard.js

function updateGPU(gpu) {
    if (gpu && gpu.status === 'ok') {
        document.getElementById('gpuVendor').textContent = gpu.vendor || 'N/A';
        document.getElementById('gpuModel').textContent = gpu.model || 'N/A';
        document.getElementById('gpuUtil').textContent = gpu.utilization_percent + '%' || 'N/A';
        document.getElementById('gpuTemp').textContent = gpu.temperature_celsius + '°C' || 'N/A';
    } else {
        document.getElementById('gpuVendor').textContent = 'Not detected';
    }
}
```

---

## 🧪 Testing Integration

### Test 1: Verify Host Output

```bash
cd Host
bash test_host_module.sh

# Check if latest.json contains GPU data
cat output/latest.json | jq '.gpu'
```

### Test 2: Test Docker Volume Mount

```bash
# Start Host monitoring
cd Host/loop
./host_monitor_loop.sh &

# Check if Docker can access the file
docker exec system-monitor-method2 cat /app/host_metrics/latest.json | jq '.gpu'
```

### Test 3: Test API Integration

```bash
# Start Host API
cd Host/api
python server.py &

# Test from Docker container
docker exec system-monitor-method2 curl http://host.docker.internal:9999/metrics | jq '.data.gpu'
```

---

## 🎯 Benefits of Integration

| Feature | Before | After (with Host Module) |
|---------|--------|--------------------------|
| **GPU Monitoring** | ❌ None | ✅ Full metrics |
| **WSL2 Temp Support** | ⚠️ Limited | ✅ PowerShell enhanced |
| **Modular Design** | ❌ Monolithic | ✅ Separated concerns |
| **API Access** | ⚠️ Web only | ✅ TCP API (port 9999) |
| **Systemd Support** | ❌ None | ✅ Service ready |
| **Output Location** | Mixed | ✅ Dedicated Host/output/ |
| **Testing** | Manual | ✅ Automated test suite |

---

## 📝 Configuration Files to Update

### 1. docker-compose.method2.yml
```yaml
volumes:
  - ../Host/output:/app/host_metrics:ro
```

### 2. core/metrics_collector.py
```python
HOST_METRICS_PATH = "/app/host_metrics/latest.json"
# Add load_host_metrics() function
```

### 3. requirements.txt (if using API)
```
requests>=2.31.0
```

---

## 🚀 Recommended Setup

**For Production:**

```bash
# 1. Install systemd service
cd Host
sudo ./quickstart.sh
# Select option 6

# 2. Start service
sudo systemctl start host-monitor

# 3. Configure Docker with volume mount (Option 2)
# 4. Update metrics_collector.py for file read

# Result: Automatic monitoring on boot, Docker reads from shared volume
```

**For Development:**

```bash
# 1. Start Host API manually
cd Host/api
python server.py &

# 2. Use API integration (Option 3)
# 3. Easy debugging with /docs endpoint

# Result: Flexible development with API docs
```

---

## 🎉 Summary

The Host module integrates with your existing system through:
1. ✅ **File-based** (simplest) - Direct volume mount
2. ✅ **API-based** (flexible) - HTTP calls to port 9999
3. ✅ **Hybrid** (best of both) - File with API fallback

Choose the integration method that best fits your deployment:
- **File mount** for simplicity and performance
- **API calls** for microservices and remote monitoring
- **Hybrid** for maximum reliability

**Next:** Follow Step-by-Step Migration above to integrate!
