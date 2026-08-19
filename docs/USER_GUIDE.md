# 📘 System Monitor Dashboard - Complete User Guide

**Date:** December 14, 2025  
**Version:** 4.0 - Chart.js Enhanced

---

## 🎯 How Everything Works - Complete Workflow

### **Architecture Overview**

```
┌─────────────────────────────────────────────────────────────────┐
│                    SYSTEM MONITOR DASHBOARD                      │
│                     (Your Browser at :5000)                      │
└──────────────────┬──────────────────────────────────────────────┘
                   │
                   │ HTTP Requests every 30 seconds
                   ↓
┌─────────────────────────────────────────────────────────────────┐
│              DASHBOARD CONTAINER (Flask Web Server)              │
│                      Port 5000                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  /api/metrics endpoint (3-tier fallback)                 │  │
│  │  1. Try Host API TCP → 2. Try File → 3. Container       │  │
│  └──────────────────────────────────────────────────────────┘  │
└──────────────────┬──────────────────────────────────────────────┘
                   │
                   │ Reads from
                   ↓
┌─────────────────────────────────────────────────────────────────┐
│                 HOST API (Native WSL2/Windows)                   │
│                      Port 8888                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • Collects REAL hardware metrics every 60 seconds      │  │
│  │  • Writes to: Host/output/latest.json                   │  │
│  │  • Serves via TCP: http://host.docker.internal:8888     │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│           JSON LOGGER CONTAINER (Background Service)             │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • Fetches metrics every 60 seconds                      │  │
│  │  │  • Saves to: json/YYYYMMDD_HHMMSS.json                 │  │
│  │  • Keeps max 1000 files (auto-cleanup)                  │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔄 What Happens When You Refresh (Detailed Workflow)

### **1. Automatic Refresh (Every 30 seconds)**

```javascript
Timeline:
00:00 → Dashboard loads in browser
00:00 → Chart.js initializes 5 charts (CPU, Memory, Disk, Network, Temperature)
00:00 → First API call to /api/metrics
00:30 → Auto-refresh triggers
01:00 → Auto-refresh triggers
... continues every 30 seconds
```

### **2. What Happens in Each Refresh Cycle**

#### **Step 1: Frontend Request**
```
Your Browser (dashboard-enhanced.js)
  ↓
  Sends: GET http://localhost:5000/api/metrics
```

#### **Step 2: Flask Backend Processing**
```
Flask App (web/app.py) receives request
  ↓
  Attempts 3-tier data source fallback:
  
  PRIMARY: Try Host API (TCP)
    → GET http://host.docker.internal:8888/metrics
    → Timeout: 2 seconds
    → If SUCCESS: Return data with source='host-api'
    
  FALLBACK 1: Try Host File (Direct)
    → Read: Host/output/latest.json
    → If file exists: Return data with source='host-file'
    
  FALLBACK 2: Container Metrics (Last Resort)
    → Use psutil inside container
    → Return data with source='container-local'
```

#### **Step 3: Data Structure Returned**
```json
{
  "success": true,
  "timestamp": "2025-12-14T19:27:30Z",
  "source": "host-api",
  "data": {
    "system": {
      "hostname": "DESKTOP-T6GSL92",
      "os": "Ubuntu 24.04.3 LTS",
      "uptime_seconds": 10602,
      "platform": "unix"
    },
    "cpu": {
      "usage_percent": 0.0,
      "model": "11th Gen Intel(R) Core(TM) i7-1165G7",
      "vendor": "Intel",
      "logical_processors": 8
    },
    "memory": {
      "total_mb": 7804,
      "used_mb": 955,
      "available_mb": 6849,
      "usage_percent": 12.2
    },
    "disk": [...],
    "network": {...},
    "temperature": {
      "cpu_celsius": 0,
      "gpu_celsius": 53
    },
    "gpu": [...]
  }
}
```

#### **Step 4: Frontend Update**
```
dashboard-enhanced.js processes response
  ↓
  Updates 5 Chart.js charts:
    • cpuChart.update() → Adds new data point (keeps last 20)
    • memoryChart.update() → Updates doughnut percentages
    • diskChart.update() → Updates bar heights
    • networkChart.update() → Adds RX/TX data points
    • tempChart.update() → Adds CPU/GPU temperature points
  ↓
  Updates text displays:
    • Hostname, OS, Uptime in header
    • CPU percentage, model, vendor, cores
    • Memory used/total/free/available
    • Disk partitions with usage
    • Network sent/received statistics
    • Temperature values
    • GPU information
  ↓
  Updates status indicator:
    • Green dot = "Live" (connected to host-api)
    • Yellow dot = "Connected" (using host-file)
    • Gray dot = "Container" (container-local fallback)
    • Red dot = "Error" (no data available)
```

---

## 📊 Where Dashboard Data Comes From

### **Data Source Priority (3-Tier Fallback)**

#### **Tier 1: Host API (TCP Connection)** ✅ PREFERRED
- **Location:** `http://host.docker.internal:8888`
- **What it does:** Direct TCP connection to Host API server running on native OS
- **Data freshness:** Real-time (Host API collects every 60s)
- **Advantages:** 
  - Real Windows/WSL2 hardware metrics
  - Accurate GPU temperatures
  - True hostname and OS information
  - Network interface details from host
- **When it's used:** When Host API is running and reachable
- **How to verify:** Status shows "Live (host-api)"

#### **Tier 2: Host File (Direct Read)** ⚡ FALLBACK 1
- **Location:** `Host/output/latest.json`
- **What it does:** Reads the last saved JSON file from Host API
- **Data freshness:** Up to 60 seconds old (Host API save interval)
- **Advantages:**
  - Works even if TCP connection fails
  - Same real hardware data as Tier 1
  - No network dependency
- **When it's used:** When TCP connection times out but file exists
- **How to verify:** Status shows "Connected (host-file)"

#### **Tier 3: Container Metrics (psutil)** ⚠️ FALLBACK 2
- **Location:** Inside Docker container using Python psutil
- **What it does:** Collects metrics from container's view of system
- **Data freshness:** Real-time but limited scope
- **Limitations:**
  - Shows container hostname (not Windows)
  - Limited GPU access
  - Network shows container interfaces
  - No real hardware temperature sensors
- **When it's used:** When both Tier 1 and Tier 2 fail
- **How to verify:** Status shows "Container (container-local)"

---

## 💾 JSON Logging System

### **How Logging Works**

```
JSON Logger Container (Background Service)
  ↓
  Every 60 seconds:
    1. Fetch metrics from /api/metrics
    2. Add timestamp fields
    3. Save to: json/YYYYMMDD_HHMMSS.json
    4. Check file count
    5. If > 1000 files, delete oldest
```

### **Log File Structure**

**Filename Format:** `20251214_192730.json` (YYYYMMDD_HHMMSS)

**File Content:**
```json
{
  "timestamp": "2025-12-14T19:27:30Z",
  "saved_at": "2025-12-14T19:27:30Z",
  "log_timestamp": "2025-12-14 19:27:30 UTC",
  "system": { ... },
  "cpu": { ... },
  "memory": { ... },
  "disk": [ ... ],
  "network": { ... },
  "temperature": { ... },
  "gpu": [ ... ]
}
```

### **Dashboard Notification System**

```
Dashboard Frontend (every 5 seconds):
  ↓
  GET /api/last-log-save
  ↓
  Receives: {
    "success": true,
    "last_save": "2025-12-14T19:27:30",
    "filename": "20251214_192730.json",
    "age_seconds": 2.5
  }
  ↓
  If last_save timestamp changed since last check:
    → Show toast notification:
       "📊 Metrics saved at 7:27:30 PM (20251214_192730.json)"
    → Display for 4 seconds
    → Auto-fade out
```

---

## 🚀 User Commands - Complete Reference

### **Starting the System**

#### **Option 1: Start Everything (Recommended)**
```powershell
# Navigate to project
cd c:\Users\DELL\Desktop\system-monitor-project-Batch

# Start Host API (native monitoring)
bash start-host-api.sh

# Start Dashboard + JSON Logger (Docker)
docker-compose up -d

# Verify everything is running
docker ps --filter "name=system-monitor"
```

#### **Option 2: Docker Only (Limited Mode)**
```powershell
# Only start Dashboard and Logger (uses container metrics)
docker-compose up -d

# Dashboard will work but show container data, not real hardware
```

#### **Option 3: Use Universal Script**
```bash
# Automatically handles everything
bash start-universal.sh
```

---

### **Monitoring Commands**

#### **View Dashboard**
```powershell
# Open in default browser
start http://localhost:5000

# Or use VS Code simple browser
# Already open at localhost:5000
```

#### **Check Container Logs**
```powershell
# Dashboard logs (Flask app)
docker logs system-monitor-dashboard --tail 50

# JSON Logger logs (background service)
docker logs system-monitor-json-logger --tail 50

# Follow logs in real-time
docker logs -f system-monitor-dashboard
```

#### **Check JSON Log Files**
```powershell
# List recent log files
Get-ChildItem json\ | Sort-Object LastWriteTime -Descending | Select-Object -First 10

# View latest log file
Get-Content (Get-ChildItem json\ | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName | ConvertFrom-Json | ConvertTo-Json -Depth 5

# Count total log files
(Get-ChildItem json\).Count
```

#### **Test API Endpoints**
```powershell
# Get current metrics
Invoke-RestMethod http://localhost:5000/api/metrics

# Get last log save info
Invoke-RestMethod http://localhost:5000/api/last-log-save

# Get historical data (last 20 logs)
Invoke-RestMethod "http://localhost:5000/api/history?limit=20"

# Health check
Invoke-RestMethod http://localhost:5000/api/health
```

---

### **Stopping the System**

```powershell
# Stop Docker containers
docker-compose down

# Stop Host API (if running in background)
# Find process
Get-Process -Name python | Where-Object {$_.MainWindowTitle -match "Host API"}

# Kill by PID
Stop-Process -Id <PID>
```

---

### **Restarting After Changes**

```powershell
# Full rebuild (after code changes)
docker-compose down
docker-compose up --build -d

# Restart without rebuild (after config changes)
docker-compose restart

# Restart single service
docker-compose restart dashboard
docker-compose restart json-logger
```

---

### **Troubleshooting Commands**

#### **Dashboard Not Loading**
```powershell
# Check if containers are running
docker ps

# Check dashboard logs for errors
docker logs system-monitor-dashboard --tail 100

# Check if port 5000 is available
netstat -ano | findstr :5000

# Restart dashboard
docker-compose restart dashboard
```

#### **No Data / Error Message**
```powershell
# Check Host API is running
curl http://host.docker.internal:8888/health

# Check Host API file exists
Test-Path "Host\output\latest.json"

# Check Host API file age
(Get-Item "Host\output\latest.json").LastWriteTime

# View Host API file content
Get-Content "Host\output\latest.json" | ConvertFrom-Json
```

#### **JSON Logging Not Working**
```powershell
# Check json-logger container is running
docker ps --filter "name=json-logger"

# Check json-logger logs
docker logs system-monitor-json-logger --tail 50

# Check json directory exists and has files
ls json\ | Measure-Object

# Manually trigger a save (inside container)
docker exec -it system-monitor-json-logger python3 web/json_logger.py
```

---

### **Advanced Commands**

#### **Run Validation**
```powershell
# Complete system validation (10 tests)
.\validate-fixes.ps1
```

#### **Access Container Shell**
```powershell
# Dashboard container
docker exec -it system-monitor-dashboard bash

# JSON Logger container
docker exec -it system-monitor-json-logger bash

# Inside container, you can:
# - Check files: ls -la
# - View logs: cat /app/data/logs/*.log
# - Test Python: python3 -c "import psutil; print(psutil.cpu_percent())"
```

#### **View Resource Usage**
```powershell
# Container stats (live)
docker stats

# Specific containers
docker stats system-monitor-dashboard system-monitor-json-logger
```

#### **Generate Report**
```powershell
# Via API
Invoke-RestMethod -Method POST http://localhost:5000/api/reports/generate

# Via Dashboard UI
# Click "Generate Report" button in dashboard header
```

---

## ⚙️ Configuration

### **Change Refresh Intervals**

#### **Dashboard Refresh (Frontend)**
**File:** `static/js/dashboard-enhanced.js`
```javascript
const REFRESH_INTERVAL = 30000; // 30 seconds (30000 ms)
```

#### **JSON Logging Interval**
**File:** `docker-compose.yml`
```yaml
environment:
  - JSON_LOG_INTERVAL=60  # 60 seconds
```

**File:** `web/json_logger.py`
```python
INTERVAL = 60  # seconds
```

#### **Host API Collection Interval**
**File:** `Host/api/config.py` (if exists)
```python
COLLECTION_INTERVAL = 60  # seconds
```

### **Change Log Notification Check Interval**
**File:** `static/js/dashboard-enhanced.js`
```javascript
const LOG_CHECK_INTERVAL = 5000; // Check every 5 seconds (5000 ms)
```

---

## 📋 Quick Reference

### **Current Configuration**
- ✅ Dashboard Refresh: **30 seconds**
- ✅ JSON Logging: **60 seconds**
- ✅ Log Notification Check: **5 seconds**
- ✅ Max Log Files: **1000** (auto-cleanup)
- ✅ API Timeout: **2 seconds**
- ✅ Toast Display: **4 seconds**

### **Ports**
- **5000** - Dashboard Web UI
- **8888** - Host API (if running)

### **Important Directories**
- `json/` - JSON log files (YYYYMMDD_HHMMSS.json)
- `reports/` - Generated reports (HTML + Markdown)
- `data/metrics/` - Current metrics cache
- `data/alerts/` - Alert logs
- `Host/output/` - Host API output files

### **Container Names**
- `system-monitor-dashboard` - Main dashboard
- `system-monitor-json-logger` - Background logger

---

## ✅ Expected Behavior

### **When Everything Works Correctly:**

1. **Dashboard shows:**
   - ✅ Hostname: "DESKTOP-T6GSL92"
   - ✅ OS: "Ubuntu 24.04.3 LTS" (WSL2 is correct)
   - ✅ Status: Green dot "Live (host-api)"
   - ✅ CPU, Memory, Disk, Network, Temperature charts updating
   - ✅ All 5 Chart.js visualizations rendering

2. **Every 30 seconds:**
   - ✅ Charts update with new data points
   - ✅ Text values refresh
   - ✅ Last update time shows current time

3. **Every 60 seconds:**
   - ✅ New JSON file created in `json/` directory
   - ✅ Toast notification appears: "📊 Metrics saved at [time] ([filename])"
   - ✅ Notification auto-fades after 4 seconds

4. **Logs show:**
   - ✅ Dashboard: Flask running, no errors
   - ✅ JSON Logger: "[HH:MM:SS] Saved: YYYYMMDD_HHMMSS.json"

---

**Last Updated:** December 14, 2025  
**Status:** ✅ All systems operational
