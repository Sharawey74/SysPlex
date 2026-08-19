# 🚀 System Monitor - Single Command Startup

## ✅ The Architecture

```
┌────────────────────────────────────────────────────┐
│ Your Actual Machine (WSL2/Linux/Mac)              │
│                                                    │
│  ┌──────────────────────────────────────────────┐ │
│  │ Host API (Native Process)                    │ │
│  │ - Runs directly on your OS                   │ │
│  │ - Access to REAL hardware                    │ │
│  │ - GPU, sensors, WMI                          │ │
│  │ - Port: 8888                                 │ │
│  └──────────────────────────────────────────────┘ │
│                                                    │
│  ┌──────────────────────────────────────────────┐ │
│  │ Docker Container                             │ │
│  │ - Dashboard only                             │ │
│  │ - Calls Host API for metrics                │ │
│  │ - Port: 5000                                 │ │
│  └──────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────┘
```

---

## 🎯 ONE Command to Start Everything

### Linux/Mac/WSL2:

```bash
bash start-system-monitor.sh
```

**That's it!** The script will:
1. ✅ Check if Host API is running
2. ✅ Start Host API on your native OS (if not running)
3. ✅ Install Python dependencies (if needed)
4. ✅ Start Dashboard Docker container
5. ✅ Wait for everything to be ready
6. ✅ Show you the URL

---

## 🛑 Stop Everything

```bash
bash stop-system-monitor.sh
```

Stops both Host API and Docker container cleanly.

---

## 📋 What the Script Does

### Start Script (`start-system-monitor.sh`):

```
1. Check if Host API is already running on port 8888
   ├─ If YES: Skip, it's already running
   └─ If NO:
      ├─ Install fastapi & uvicorn (if needed)
      ├─ Start Host API as background process
      ├─ Save PID to /tmp/host-api.pid
      └─ Wait until healthy (checks /health endpoint)

2. Navigate to Docker directory

3. Stop any existing Dashboard container

4. Start Dashboard container with docker-compose

5. Show success message with URLs
```

---

## 🧪 Verify It's Working

```bash
# Check Host API
curl http://localhost:8888/health
# Should return: {"status":"ok"}

# Check Dashboard
curl http://localhost:5000/api/health
# Should return: {"status":"healthy"}

# Check GPU metrics
curl http://localhost:5000/api/metrics | jq '.data.gpu'
# Should show both GPUs
```

---

## 📊 Process Overview

```bash
# See what's running
ps aux | grep "python.*server.py"  # Host API process
docker ps                           # Dashboard container
```

**Expected output:**
```
CONTAINER ID   IMAGE                      STATUS         PORTS
abc123def456   system-monitor:method2     Up 2 minutes   0.0.0.0:5000->5000/tcp
```

---

## 🔍 Logs

### Host API Logs:
```bash
tail -f /tmp/host-api.log
```

### Dashboard Logs:
```bash
cd Docker
docker-compose -f docker-compose.method2.yml logs -f
```

---

## 🎉 Benefits

| Feature | Status |
|---------|--------|
| **Single command** | ✅ One bash script |
| **No manual steps** | ✅ Automated |
| **Host API on native OS** | ✅ Real hardware access |
| **Dashboard in Docker** | ✅ Portable |
| **No PowerShell** | ✅ Pure bash |
| **Cross-platform** | ✅ Linux/Mac/WSL2 |
| **Background process** | ✅ No terminal needed |
| **Auto-restart Host API** | ✅ If not running |
| **Clean shutdown** | ✅ Stop script provided |

---

## ⚙️ Advanced Usage

### Restart Everything:
```bash
bash stop-system-monitor.sh
bash start-system-monitor.sh
```

### Restart Just Dashboard:
```bash
cd Docker
docker-compose -f docker-compose.method2.yml restart
```

### Restart Just Host API:
```bash
# Kill existing
kill $(cat /tmp/host-api.pid)

# Start new
cd Host/api
nohup python3 server.py > /tmp/host-api.log 2>&1 &
echo $! > /tmp/host-api.pid
```

---

## 🚀 For Distribution

Users just need to:

```bash
# 1. Clone repository
git clone https://github.com/Sharawey74/system-monitor-project
cd system-monitor-project

# 2. Run ONE command
bash start-system-monitor.sh

# 3. Open browser
http://localhost:5000
```

**No Docker knowledge needed!**  
**No Python installation steps!**  
**Just works!** ✅

---

## ✅ This Is The Correct Architecture

**Why Host API can't be in container:**
- ❌ Containers can't access real GPU
- ❌ Containers can't read hardware sensors
- ❌ Containers can't call Windows WMI
- ❌ Containers are isolated from hardware

**Why this solution works:**
- ✅ Host API runs on your actual OS (has hardware access)
- ✅ Dashboard runs in container (portable, easy)
- ✅ Single command startup (automated)
- ✅ Clean shutdown (no orphaned processes)

---

## 🎯 Summary

**Old way:** Open 3 terminals manually ❌  
**New way:** One command, everything automated ✅

```bash
bash start-system-monitor.sh  # Start
bash stop-system-monitor.sh   # Stop
```

That's it! 🎊
