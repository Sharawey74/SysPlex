# 🚀 START HERE - Quick Start Guide

## ✅ Docker Dashboard is Running!

Your Docker container is **healthy and running** on `http://localhost:5001`

**Current Status:**
- ✅ Container: `system-monitor-method1` (healthy)
- ✅ Port: 5001
- ✅ Dashboard: Serving with BlurAdmin theme
- ✅ API: Responding to requests

---

## 🎯 To Get FULL Hardware Metrics

The Docker dashboard is displaying data, but **temperature and GPU metrics** require host monitoring.

### Option 1: Quick WSL2 Command (Recommended)

Open a **new PowerShell terminal** and run:

```powershell
wsl bash /mnt/c/Users/DELL/Desktop/system-monitor-project-Batch/scripts/host_monitor_loop.sh
```

**What this does:**
- Collects ALL metrics including temperature/GPU
- Updates `data/metrics/current.json` every 60 seconds
- Docker automatically reads this file
- Leave it running in the background

### Option 2: From WSL2 Terminal

If you prefer to work inside WSL2:

```bash
cd /mnt/c/Users/DELL/Desktop/system-monitor-project-Batch/scripts
bash host_monitor_loop.sh
```

---

## 🌐 Access Dashboard

```powershell
start http://localhost:5001
```

Or open your browser to: **http://localhost:5001**

---

## 📊 What You'll See

**With Host Monitoring (Recommended):**
- ✅ CPU Temperature (real-time)
- ✅ GPU Temperature (NVIDIA detected)
- ✅ All 18 disk partitions
- ✅ SMART disk health data
- ✅ Fan speeds
- ✅ Full system metrics

**Without Host Monitoring (Docker Only):**
- ✅ CPU usage and cores
- ✅ Memory usage
- ✅ Network interfaces
- ✅ Basic disk info (limited)
- ❌ Temperature shows "unavailable"
- ❌ GPU shows "unknown"
- ❌ Limited SMART data

---

## 🔍 Verify It's Working

### Check if metrics are updating:

```powershell
# Should show timestamp updating every 60 seconds
Get-Content "data\metrics\current.json" | Select-String "timestamp"
```

### Check if temperature is available:

```powershell
# Should show actual temperatures if host monitoring is running
Get-Content "data\metrics\current.json" | Select-String "temperature" -Context 3
```

---

## 🛑 Stop Everything

### Stop Docker:
```powershell
docker-compose -f Docker/docker-compose.method1.yml down
```

### Stop Host Monitoring:
Press `Ctrl+C` in the terminal running `host_monitor_loop.sh`

---

## 📖 Full Documentation

- **Complete Setup Guide:** `COMPLETE_SETUP_GUIDE.md`
- **Docker Usage:** `DOCKER_USAGE.md`
- **Dashboard Guide:** `docs/DASHBOARD_README.md`

---

## ❓ Troubleshooting

### Dashboard not loading?
```powershell
docker restart system-monitor-method1
start http://localhost:5001
```

### No temperature data?
Start host monitoring (see Option 1 above)

### Metrics not updating?
Check if host monitoring loop is running in WSL2

---

## 💡 Why Two Components?

**Docker Container:**
- Beautiful web dashboard
- REST API
- Report generation
- Auto-refresh UI

**WSL2 Host Monitoring:**
- Hardware sensor access
- Temperature/GPU data
- Full disk information
- SMART health monitoring

They work together via a shared volume (`data/metrics/current.json`)

---

**Ready to start?** Run the WSL2 command above and open http://localhost:5001 🎉
