# 🚀 UPDATED - How Everything Works Now

## ✅ ONE COMMAND DOES EVERYTHING!

### **Single Command to Start:**

```bash
bash start-universal.sh
```

**This ONE command now:**
1. ✅ Downloads Host API scripts (if missing)
2. ✅ **Starts Monitor Loop** → Collects data every 60 seconds → Writes to `Host/output/latest.json`
3. ✅ **Starts API Server** → Serves data from `latest.json` on port 8888
4. ✅ **Starts Docker Containers** → Dashboard + JSON Logger
5. ✅ Verifies everything is running

---

## 🔄 Data Flow (Now Complete!)

```
┌─────────────────────────────────────────────┐
│    MONITOR LOOP (Background Process)        │
│    Runs: Host/loop/host_monitor_loop.sh     │
│    PID: /tmp/host-monitor-loop.pid          │
│    Logs: /tmp/host-monitor-loop.log         │
│                                             │
│    Every 60 seconds:                        │
│    1. Collect metrics (CPU, Memory, etc)    │
│    2. Write to Host/output/latest.json      │
│    3. Repeat forever                        │
└──────────────┬──────────────────────────────┘
               │
               │ Writes data
               ↓
┌─────────────────────────────────────────────┐
│    HOST/OUTPUT/LATEST.JSON                  │
│    Updated every 60 seconds                 │
│    Contains fresh hardware metrics          │
└──────────────┬──────────────────────────────┘
               │
               │ Reads from
               ↓
┌─────────────────────────────────────────────┐
│    API SERVER (Port 8888)                   │
│    Runs: Host/api/server.py                 │
│    PID: /tmp/host-api.pid                   │
│    Logs: /tmp/host-api.log                  │
│                                             │
│    Serves data via:                         │
│    GET http://localhost:8888/metrics        │
└──────────────┬──────────────────────────────┘
               │
               │ Docker container fetches
               ↓
┌─────────────────────────────────────────────┐
│    DASHBOARD CONTAINER                      │
│    Port 5000                                │
│    Displays data in browser                 │
└─────────────────────────────────────────────┘
```

---

## 📋 What You See When You Run start-universal.sh

```bash
$ bash start-universal.sh

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🚀 System Monitor - Universal Startup
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[0/3] Checking Host API scripts...
✓ Host API scripts found

[1/3] Starting Host API...
==================================================
  Starting Host API (Native OS)
==================================================
► Checking Python dependencies...
► Generating initial metrics...
► Starting Host Monitoring Loop (collects data every 60s)...
✓ Host Monitor Loop started (PID: 12345)
   Logs: tail -f /tmp/host-monitor-loop.log

► Starting Host API Server...
✓ Host API Server started (PID: 12346)
   Logs: tail -f /tmp/host-api.log
► Waiting for API to be ready...
.✓ Host API is ready!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Host Monitor Loop: Running (PID in /tmp/host-monitor-loop.pid)
  Data Collection:   Every 60 seconds
  Output File:       Host/output/latest.json
  Monitor Logs:      /tmp/host-monitor-loop.log

  Host API Server:   http://localhost:8888
  Health:            http://localhost:8888/health
  Metrics:           http://localhost:8888/metrics
  API Logs:          /tmp/host-api.log
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[2/3] Starting Dashboard...
► Stopping old containers...
► Building and starting Dashboard container...
✓ Dashboard container started

[3/3] Verifying system...
► Waiting for Dashboard...
.✓ Dashboard is ready!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ SYSTEM MONITOR IS RUNNING!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ● Web Dashboard:     http://localhost:5000
  ● Host API:          http://localhost:8888
  ● API Metrics:       http://localhost:5000/api/metrics

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Status:
  Monitor Loop: ✓ Collecting data every 60s
  Host API:     ✓ Running
  Dashboard:    ✓ Running

Logs:
  Monitor Loop: tail -f /tmp/host-monitor-loop.log
  Host API:     tail -f /tmp/host-api.log
  Dashboard:    docker logs -f system-monitor-dashboard

Data File:
  watch -n 5 stat Host/output/latest.json  # Watch file being updated

To stop:
  bash stop-system-monitor.sh

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## ✅ Verification Commands

### **1. Check if Monitor Loop is collecting data:**

```bash
# Watch the log file - should show "Iteration #1, #2, #3..." every 60s
tail -f /tmp/host-monitor-loop.log

# OR check if data file is updating
watch -n 5 'stat Host/output/latest.json | grep Modify'

# OR run test script
bash test-data-collection.sh
```

**Expected output in monitor log:**
```
[2025-12-14 19:35:00] Iteration #1
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[2025-12-14 19:35:00] ✅ Collection successful
... waits 60 seconds ...
[2025-12-14 19:36:00] Iteration #2
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[2025-12-14 19:36:00] ✅ Collection successful
```

### **2. Check if API Server is running:**

```bash
# Health check
curl http://localhost:8888/health

# Get metrics
curl http://localhost:8888/metrics
```

### **3. Check if Dashboard is working:**

```bash
# Open in browser
start http://localhost:5000

# Or check API
curl http://localhost:5000/api/metrics
```

### **4. Check all processes:**

```bash
# Monitor Loop
ps aux | grep host_monitor_loop
cat /tmp/host-monitor-loop.pid

# API Server
ps aux | grep server.py
cat /tmp/host-api.pid

# Docker containers
docker ps --filter "name=system-monitor"
```

---

## 🛑 How to Stop Everything

```bash
bash stop-system-monitor.sh
```

**This stops:**
1. ✅ Dashboard containers
2. ✅ Monitor Loop (data collector)
3. ✅ API Server

---

## 🔍 Troubleshooting

### **Dashboard shows old data?**

```bash
# Check if monitor loop is running
tail -f /tmp/host-monitor-loop.log

# If not running, restart everything
bash stop-system-monitor.sh
bash start-universal.sh
```

### **Monitor loop logs show errors?**

```bash
# Check the logs
cat /tmp/host-monitor-loop.log

# Common issues:
# 1. Missing scripts - run: bash start-universal.sh (auto-downloads)
# 2. Python dependencies - run: pip3 install psutil
# 3. Permissions - run with proper user permissions
```

### **Data file not updating?**

```bash
# Test data collection
bash test-data-collection.sh

# This will:
# 1. Show current file timestamp
# 2. Wait 65 seconds
# 3. Check if file was updated
# 4. Report success or failure
```

---

## 📊 What You Should See in Dashboard

After running `start-universal.sh` and opening http://localhost:5000:

1. **Header:**
   - Hostname: DESKTOP-T6GSL92
   - OS: Ubuntu 24.04.3 LTS
   - Status: 🟢 Live (host-api)
   - Last update: [current time] - **UPDATES EVERY 30 SECONDS**

2. **Charts (5 total):**
   - CPU Usage (line chart) - **UPDATING**
   - Memory (doughnut chart) - **UPDATING**
   - Disk Usage (bar chart) - **UPDATING**
   - Network Traffic (line chart) - **UPDATING**
   - Temperature (line chart) - **UPDATING**

3. **Notifications:**
   - Every 60 seconds: "📊 Metrics saved at [time] ([filename])"

4. **All values should change when you refresh!**

---

## 🎯 Key Differences Now

### **BEFORE (Broken):**
- ❌ Only API server started
- ❌ Data file never updated
- ❌ Dashboard showed old data from hours ago
- ❌ Charts showed flat lines (no new data)

### **AFTER (Fixed):**
- ✅ Monitor loop + API server + Dashboard
- ✅ Data file updates every 60 seconds
- ✅ Dashboard shows fresh data
- ✅ Charts update in real-time
- ✅ ONE command does everything!

---

## 📁 Important Files

- **Start:** `start-universal.sh`
- **Stop:** `stop-system-monitor.sh`
- **Test:** `test-data-collection.sh`
- **Data:** `Host/output/latest.json` (updated every 60s)
- **Monitor Loop:** `Host/loop/host_monitor_loop.sh`
- **API Server:** `Host/api/server.py`

---

## 🚀 Quick Start (TL;DR)

```bash
# 1. Start everything
bash start-universal.sh

# 2. Open dashboard
start http://localhost:5000

# 3. Watch data being collected (optional)
tail -f /tmp/host-monitor-loop.log

# 4. Stop everything when done
bash stop-system-monitor.sh
```

**That's it! Everything is automated now!** 🎉
