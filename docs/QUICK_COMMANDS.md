# 🚀 Quick Start Commands

## Essential Commands You Need

### 1. Start Everything
```powershell
# Navigate to project folder
cd c:\Users\DELL\Desktop\system-monitor-project-Batch

# Start containers
docker-compose up -d
```

### 2. View Dashboard
```powershell
# Open in browser
start http://localhost:5000
```

### 3. Check Status
```powershell
# See if containers are running
docker ps --filter "name=system-monitor"
```

### 4. View Logs
```powershell
# Dashboard logs
docker logs system-monitor-dashboard --tail 20

# JSON Logger logs
docker logs system-monitor-json-logger --tail 20
```

### 5. Stop Everything
```powershell
# Stop all containers
docker-compose down
```

### 6. Restart (After Issues)
```powershell
# Full restart with rebuild
docker-compose down
docker-compose up --build -d
```

---

## What You See in Dashboard

### ✅ **Every 30 seconds:**
- Charts update with new data
- CPU, Memory, Disk, Network, Temperature values refresh
- Status indicator blinks during update

### ✅ **Every 60 seconds:**
- Toast notification appears at bottom-right:
  - "📊 Metrics saved at 7:29:21 PM (20251214_172921.json)"
- Disappears after 4 seconds automatically

### ✅ **Status Indicators:**
- 🟢 **Green "Live"** = Connected to Host API (best - real hardware)
- 🟡 **Yellow "Connected"** = Reading from Host file (good - recent data)
- ⚪ **Gray "Container"** = Container metrics (limited - container only)
- 🔴 **Red "Error"** = No data available (check containers)

---

## Troubleshooting

### Dashboard shows error popup?
```powershell
# Restart containers
docker-compose restart

# If still fails, full rebuild
docker-compose down
docker-compose up --build -d
```

### Charts not appearing?
- **Refresh page:** Press F5 or Ctrl+R
- **Clear cache:** Ctrl+Shift+R (hard refresh)
- **Check console:** F12 → Console tab for JavaScript errors

### No log notifications?
- **Wait:** First notification appears after first log save (60 seconds after start)
- **Check logs:** `docker logs system-monitor-json-logger`
- **Verify files:** `ls json\` to see if files are being created

---

## Key File Locations

- **Dashboard:** http://localhost:5000
- **JSON Logs:** `c:\Users\DELL\Desktop\system-monitor-project-Batch\json\`
- **Host Data:** `c:\Users\DELL\Desktop\system-monitor-project-Batch\Host\output\latest.json`
- **Reports:** `c:\Users\DELL\Desktop\system-monitor-project-Batch\reports\`

---

## Current Settings

- ⏱️ **Dashboard Refresh:** 30 seconds
- 💾 **Log Save Interval:** 60 seconds  
- 🔔 **Notification Check:** 5 seconds
- 📊 **Max Log Files:** 1000 (auto-cleanup)
- 🎨 **Charts:** 5 (CPU, Memory, Disk, Network, Temperature)

---

**Need detailed help?** See [USER_GUIDE.md](USER_GUIDE.md) for complete documentation.
