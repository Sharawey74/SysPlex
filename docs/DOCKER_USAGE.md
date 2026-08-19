# System Monitor - Quick Start & Usage Guide

## 🚀 Running the System

### Option 1: Docker (Recommended)
```powershell
# Start Method 1 container
docker-compose -f Docker/docker-compose.method1.yml up -d

# Access dashboard
start http://localhost:5001

# View logs
docker logs -f system-monitor-method1

# Stop
docker-compose -f Docker/docker-compose.method1.yml down
```

### Option 2: Hybrid (Best Hardware Detection)
For full temperature/GPU monitoring, run collection on WSL2 and view in Docker:

**Terminal 1 (WSL2):**
```bash
cd /mnt/c/Users/DELL/Desktop/system-monitor-project-Batch/scripts
watch -n 60 ./main_monitor.sh  # Runs every 60 seconds
```

**Terminal 2 (PowerShell):**
```powershell
# Start Docker dashboard (reads data collected by WSL2)
docker-compose -f Docker/docker-compose.method1.yml up -d
start http://localhost:5001
```

This gives you:
- ✅ Full hardware sensor access (WSL2)
- ✅ Beautiful web dashboard (Docker)
- ✅ Auto-updating metrics (background loop)

## 📊 Accessing the Dashboard

- **Main Dashboard**: http://localhost:5001
- **Metrics API**: http://localhost:5001/api/metrics
- **Generate Report**: http://localhost:5001/api/reports/generate (POST)
- **Health Check**: http://localhost:5001/api/health

## 🔍 Current Limitations in Docker

Docker containers (even privileged) on WSL2 have limited hardware access:
- ❌ Cannot read CPU/GPU temperatures directly
- ❌ Limited SMART disk data
- ❌ Cannot access all host disks
- ✅ CAN monitor: CPU usage, memory, network, container disks

## 💡 Workaround

The `/app/data` volume is shared between Docker and host, so:
1. Run `main_monitor.sh` on WSL2 (full hardware access)
2. Docker reads the shared `current.json` file
3. Dashboard displays complete data including temperatures!

## 📦 What's Working

- ✅ Background monitoring loop (every 60 seconds)
- ✅ Modern teal/dark theme dashboard
- ✅ Report generation (HTML + Markdown)
- ✅ All metrics displayed properly
- ✅ Auto-refresh (5 seconds)
- ✅ Responsive design

## 🎨 New Design Features

- BlurAdmin-inspired teal theme
- Card-based layout with hover effects
- Glassmorphic panels
- Color-coded progress indicators
- Circular progress (ready for implementation)
- Responsive grid system
