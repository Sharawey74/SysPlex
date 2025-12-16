# System Monitor - Complete Setup Guide

## 🚀 Quick Start (Recommended Hybrid Mode)

This setup gives you **full hardware monitoring** with a **beautiful dashboard**.

### Prerequisites
- Docker Desktop running
- WSL2 enabled
- PowerShell terminal

### Setup Steps

**Step 1: Start Docker Dashboard**
```powershell
cd C:\Users\DELL\Desktop\system-monitor-project-Batch
docker-compose -f Docker/docker-compose.method1.yml up -d
```

**Step 2: Start Host Monitoring (WSL2)**

Open a new terminal and run:
```powershell
wsl bash /mnt/c/Users/DELL/Desktop/system-monitor-project-Batch/scripts/host_monitor_loop.sh
```

Or from within WSL2:
```bash
cd /mnt/c/Users/DELL/Desktop/system-monitor-project-Batch/scripts
bash host_monitor_loop.sh
```

**Step 3: Access Dashboard**
```powershell
start http://localhost:5001
```

### What You Get

✅ **Full Metrics Collection:**
- CPU usage, cores, model
- Memory usage breakdown
- All disk partitions
- Network interfaces
- **CPU Temperature** (from host)
- **GPU Temperature** (from host)
- Fan speeds (if available)
- SMART disk health

✅ **Beautiful Dashboard:**
- Modern teal/dark theme
- Real-time updates (5 seconds)
- Responsive design
- Card-based layout

---

## 📋 Alternative: Docker Only Mode

If you don't need temperature/GPU data:

```powershell
docker-compose -f Docker/docker-compose.method1.yml up -d
start http://localhost:5001
```

**Limitations:**
- ❌ No temperature data
- ❌ No fan speed data
- ❌ Limited SMART data
- ✅ CPU, memory, disk, network work fine

---

## 🔍 Verification

### Check if monitoring is running:
```powershell
# Check Docker
docker ps --filter "name=system-monitor-method1"

# Check metrics file timestamp (should update every 60 seconds)
Get-Content "data\metrics\current.json" | Select-String "timestamp"
```

### Check metrics are complete:
```powershell
# Should show temperature data if host monitoring is running
Get-Content "data\metrics\current.json" | Select-String "temperature" -Context 3
```

---

## 🛑 Stop Services

### Stop Docker:
```powershell
docker-compose -f Docker/docker-compose.method1.yml down
```

### Stop Host Monitoring:
Press `Ctrl+C` in the WSL2 terminal running `host_monitor_loop.sh`

---

## 🔧 Troubleshooting

### Dashboard not loading?
```powershell
# Check if container is running
docker ps

# Check logs
docker logs system-monitor-method1

# Restart
docker restart system-monitor-method1
```

### No temperature data?
- Verify host monitoring is running in WSL2
- Check the metrics file: `cat data/metrics/current.json | grep temperature`
- Make sure WSL2 has access to hardware sensors

### Metrics not updating?
- Check host monitoring loop is running
- Verify file permissions: `ls -la data/metrics/`
- Check Docker volume mount: `docker inspect system-monitor-method1`

---

## 📊 API Endpoints

Access metrics via API:

- **Health Check:** `http://localhost:5001/api/health`
- **Current Metrics:** `http://localhost:5001/api/metrics`
- **Alerts:** `http://localhost:5001/api/alerts`
- **Generate Report:** `POST http://localhost:5001/api/reports/generate`
- **List Reports:** `http://localhost:5001/api/reports`

Example:
```powershell
Invoke-WebRequest -Uri "http://localhost:5001/api/metrics" | Select-Object -ExpandProperty Content | ConvertFrom-Json
```

---

## 🎨 Dashboard Features

- **Auto-refresh:** Every 5 seconds
- **Responsive:** Works on desktop, tablet, mobile
- **Modern Theme:** Teal/dark BlurAdmin-inspired design
- **Report Generation:** HTML and Markdown reports
- **Real-time Updates:** Live metric updates

---

## 💡 Why Hybrid Mode?

Docker containers (even privileged) on WSL2 **cannot** access hardware sensors directly due to:
- Container isolation
- WSL2 kernel limitations
- Missing `/sys/class/hwmon` exposure

**Solution:** Run data collection on host (WSL2) with full hardware access, and use Docker only for the web dashboard. The shared volume (`/app/data`) acts as a bridge.

---

## 📦 Project Structure

```
system-monitor-project-Batch/
├── scripts/
│   ├── host_monitor_loop.sh      ← Run this on WSL2
│   └── main_monitor.sh            ← Collects metrics
├── data/
│   └── metrics/
│       └── current.json           ← Shared between host & Docker
├── Docker/
│   ├── docker-compose.method1.yml ← Start with this
│   └── Dockerfile.method1
├── web/
│   └── app.py                     ← Flask dashboard
├── templates/
│   └── dashboard.html             ← UI template
└── static/
    ├── css/styles.css             ← New theme
    └── js/dashboard.js            ← Frontend logic
```

---

## 🎯 Best Practices

1. **Always run host monitoring** for complete data
2. **Check logs** if something doesn't work
3. **Use API endpoints** for programmatic access
4. **Generate reports** periodically for history
5. **Monitor the monitoring** - check that data updates

---

Need help? Check container logs: `docker logs -f system-monitor-method1`
