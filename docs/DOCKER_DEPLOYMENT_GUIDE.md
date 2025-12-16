# 🐳 Docker Deployment Guide - With Host Module Integration

## ✅ Changes Applied

All required changes have been implemented:

1. ✅ **docker-compose.yml files** - Added port 9999 and `extra_hosts`
2. ✅ **Dockerfiles** - Added `requests` package
3. ✅ **web/app.py** - Added TCP API fallback
4. ✅ **Host module** - Already created with API server

---

## 🚀 Quick Start: Deploy with Docker

### Option A: Quick Deploy (Recommended for Testing)

```powershell
# Step 1: Start Host monitoring API
cd Host/api
python server.py &   # Runs on port 9999

# Step 2: Build and run Docker (Method 2)
cd ../Docker
docker-compose -f docker-compose.method2.yml up --build -d

# Step 3: Access dashboard
# Browser: http://localhost:5000
```

### Option B: Full Production Setup

```powershell
# Step 1: Install Host module as systemd service (Linux)
cd Host
sudo bash quickstart.sh
# Select option 6 (Install systemd service)
# Select option 5 (Install dependencies)

# Step 2: Start Host monitoring
sudo systemctl start host-monitor

# Step 3: Build Docker images
cd ../Docker
docker-compose -f docker-compose.method2.yml build

# Step 4: Start containers
docker-compose -f docker-compose.method2.yml up -d

# Step 5: Verify
docker-compose -f docker-compose.method2.yml logs -f
```

---

## 🔄 Do You Need to Rebuild?

### YES - You MUST rebuild if:
- ✅ **This is your first time** running with these changes
- ✅ **You changed Dockerfile** (we added `requests`)
- ✅ **You changed docker-compose.yml** (we added ports/extra_hosts)

### Use this command:
```powershell
docker-compose -f docker-compose.method2.yml up --build -d
```

The `--build` flag forces rebuilding the image with new dependencies.

---

## 📋 Complete Deployment Workflow

### Step-by-Step Instructions

#### 1️⃣ Prepare Host Monitoring

```powershell
# Navigate to Host directory
cd c:\Users\DELL\Desktop\system-monitor-project-Batch\Host

# Test Host module (verify all monitors work)
bash test_host_module.sh

# Should see:
# ✓ System monitor
# ✓ CPU monitor
# ✓ Memory monitor
# ✓ GPU monitor (if available)
# ... etc
```

#### 2️⃣ Start Host API Server

**Option A: Manual Start (for testing)**
```powershell
cd Host/api
pip install -r requirements.txt  # If not already installed
python server.py

# Should see:
# INFO:     Started server process
# INFO:     Uvicorn running on http://0.0.0.0:9999
```

**Option B: Background Start**
```powershell
cd Host/api
python server.py &

# Or use PowerShell job:
Start-Job -ScriptBlock { cd Host/api; python server.py }
```

**Option C: Systemd Service (Linux/WSL2 - Recommended)**
```bash
cd Host
sudo bash quickstart.sh
# Select: 6) Install systemd service
# Then: sudo systemctl start host-monitor
```

#### 3️⃣ Verify Host API is Running

```powershell
# Test from PowerShell
Invoke-WebRequest -Uri http://localhost:9999/health | Select-Object -Expand Content

# Or using curl (if installed)
curl http://localhost:9999/health

# Expected output:
# {"status":"ok","timestamp":"2025-12-11T12:34:56Z"}
```

#### 4️⃣ Build Docker Image

Choose your preferred method:

**Method 1: Privileged Mode (port 5001)**
```powershell
cd Docker
docker-compose -f docker-compose.method1.yml build
```

**Method 2: Bind Mounts - RECOMMENDED (port 5000)**
```powershell
cd Docker
docker-compose -f docker-compose.method2.yml build
```

**Build Output:**
```
[+] Building 45.2s (12/12) FINISHED
 => [1/8] FROM ubuntu:22.04
 => [2/8] RUN apt-get update && apt-get install -y ...
 => [3/8] COPY requirements.txt .
 => [4/8] RUN pip3 install --no-cache-dir -r requirements.txt
 => [5/8] RUN pip3 install --no-cache-dir requests   ← NEW!
 => ...
 => exporting to image
```

#### 5️⃣ Start Docker Container

**Method 1:**
```powershell
docker-compose -f docker-compose.method1.yml up -d
```

**Method 2:**
```powershell
docker-compose -f docker-compose.method2.yml up -d
```

**Expected Output:**
```
[+] Running 1/1
 ✔ Container system-monitor-method2  Started
```

#### 6️⃣ Verify Container is Running

```powershell
# Check status
docker-compose -f docker-compose.method2.yml ps

# Should show:
# NAME                      STATUS        PORTS
# system-monitor-method2    Up 10s        0.0.0.0:5000->5000/tcp
#                                        0.0.0.0:9999->9999/tcp

# Check logs
docker-compose -f docker-compose.method2.yml logs -f
```

#### 7️⃣ Test Integration

**Test 1: Host API from Host**
```powershell
curl http://localhost:9999/metrics
# Should return JSON with GPU data
```

**Test 2: Container can reach Host API**
```powershell
docker exec system-monitor-method2 curl http://host.docker.internal:9999/health
# Should return: {"status":"ok",...}
```

**Test 3: Dashboard API**
```powershell
curl http://localhost:5000/api/metrics
# Should return metrics (from file or Host API)
```

**Test 4: Web Dashboard**
```
Open browser: http://localhost:5000
# Should load dashboard with metrics
```

---

## 🔍 Architecture: How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                    Your Windows/WSL2 Host                    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Host/api/server.py (FastAPI)                       │    │
│  │ Port: 9999                                         │    │
│  │ Reads: Host/output/latest.json                     │    │
│  │ Provides: GPU, real temps, full metrics          │    │
│  └────────────────────────────────────────────────────┘    │
│                          ↑                                   │
│                          │ (reads every 60s)                │
│                          ↓                                   │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Host/loop/host_monitor_loop.sh                     │    │
│  │ Runs: main_monitor.sh every 60 seconds            │    │
│  │ Outputs: Host/output/latest.json                   │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  ════════════════════════════════════════════════════════  │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Docker Container: system-monitor-method2           │    │
│  │                                                     │    │
│  │  ┌────────────────────────────────────────────┐  │    │
│  │  │ Flask Web App (web/app.py)                 │  │    │
│  │  │ Port: 5000                                 │  │    │
│  │  │                                            │  │    │
│  │  │ Step 1: Try local current.json            │  │    │
│  │  │           ↓ (if fails)                     │  │    │
│  │  │ Step 2: Call http://host.docker.internal:9999/metrics │
│  │  │           ↓                                 │  │    │
│  │  │ Step 3: Return metrics or error            │  │    │
│  │  └────────────────────────────────────────────┘  │    │
│  │                                                     │    │
│  │  extra_hosts: host.docker.internal → Host IP      │    │
│  │  ports: 5000:5000, 9999:9999                      │    │
│  └────────────────────────────────────────────────────┘    │
│                          ↓                                   │
└─────────────────────────────────────────────────────────────┘
                           ↓
                  🌐 Browser: localhost:5000
                     📊 Dashboard displays metrics
```

### Data Flow Explanation

1. **Host Monitoring Loop** (`Host/loop/host_monitor_loop.sh`):
   - Runs `main_monitor.sh` every 60 seconds
   - Collects: CPU, Memory, GPU, Temp (real hardware via PowerShell)
   - Writes: `Host/output/latest.json`

2. **Host API Server** (`Host/api/server.py` on port 9999):
   - Reads: `Host/output/latest.json`
   - Exposes: HTTP REST API with `/metrics`, `/health`, `/docs`
   - Accessible to Docker via `host.docker.internal:9999`

3. **Docker Container** (Flask web app):
   - **Primary**: Tries to read from `/app/data/metrics/current.json` (local file)
   - **Fallback**: If file missing/stale, calls Host API at `http://host.docker.internal:9999/metrics`
   - **Result**: Always provides metrics (GPU included!)

4. **Web Dashboard** (Browser → localhost:5000):
   - Displays metrics from Flask API
   - Auto-refreshes every few seconds
   - Shows GPU, real temps, all hardware data

---

## 🎛️ Configuration Options

### Port Configuration

| Service | Default Port | Customization |
|---------|-------------|---------------|
| Host API | 9999 | Edit `Host/api/server.py` line 73 |
| Dashboard (Method 1) | 5001 | Edit `docker-compose.method1.yml` |
| Dashboard (Method 2) | 5000 | Edit `docker-compose.method2.yml` |

**To change Host API port:**
```python
# Host/api/server.py
if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8888)  # Change 9999 → 8888
```

**Then update docker-compose.yml:**
```yaml
ports:
  - "8888:8888"  # Match new port

# And update web/app.py fallback URL:
# http://host.docker.internal:8888/metrics
```

### Monitoring Interval

```bash
# Edit Host/loop/host_monitor_loop.sh
INTERVAL=30  # Change from 60 to 30 seconds
```

### Docker Resource Limits

```yaml
# docker-compose.method2.yml
deploy:
  resources:
    limits:
      cpus: '2.0'
      memory: 2G
    reservations:
      cpus: '0.5'
      memory: 512M
```

---

## 🧪 Testing & Verification

### Test 1: Host Module

```powershell
cd Host
bash test_host_module.sh
```

**Expected:**
```
🧪 Testing Host Module
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1️⃣ Testing system_monitor.sh...
✓ System monitor passed

2️⃣ Testing cpu_monitor.sh...
✓ CPU monitor passed

3️⃣ Testing gpu_monitor.sh...
✓ GPU monitor passed

...

✅ All tests passed!
```

### Test 2: Host API

```powershell
# Test health endpoint
curl http://localhost:9999/health

# Test metrics endpoint
curl http://localhost:9999/metrics | jq '.data.gpu'

# Test docs (open in browser)
start http://localhost:9999/docs
```

### Test 3: Docker Container

```powershell
# Check container can reach Host API
docker exec system-monitor-method2 curl http://host.docker.internal:9999/health

# Check Flask API
curl http://localhost:5000/api/health

# Check metrics endpoint
curl http://localhost:5000/api/metrics | jq '.data.gpu'
```

### Test 4: Full Integration

```powershell
# 1. Start Host monitoring
cd Host/loop
bash host_monitor_loop.sh &

# 2. Start Host API
cd ../api
python server.py &

# 3. Wait 5 seconds for first metrics collection
Start-Sleep -Seconds 5

# 4. Verify Host API has data
curl http://localhost:9999/metrics | jq '.data.timestamp'

# 5. Start Docker
cd ../../Docker
docker-compose -f docker-compose.method2.yml up -d

# 6. Wait for container startup
Start-Sleep -Seconds 10

# 7. Test Dashboard API
curl http://localhost:5000/api/metrics | jq '.success'

# 8. Open browser
start http://localhost:5000
```

---

## 🐛 Troubleshooting

### Issue 1: "Connection refused" to port 9999

**Cause:** Host API not running

**Solution:**
```powershell
# Check if API is running
netstat -ano | findstr :9999

# Start API
cd Host/api
python server.py

# Or check if another process is using port
Get-Process -Id (Get-NetTCPConnection -LocalPort 9999).OwningProcess
```

### Issue 2: "No metrics available from file or Host API"

**Cause:** Both local file AND Host API are unavailable

**Debug:**
```powershell
# Check local file in container
docker exec system-monitor-method2 cat /app/data/metrics/current.json

# Check Host API from container
docker exec system-monitor-method2 curl http://host.docker.internal:9999/health

# Check Host monitoring is running
ps aux | grep host_monitor_loop
```

**Solution:**
```powershell
# Start Host monitoring
cd Host/loop
bash host_monitor_loop.sh &

# Start Host API
cd ../api
python server.py &
```

### Issue 3: Port 9999 already in use

**Cause:** Another process using port 9999

**Solution:**
```powershell
# Find process using port
Get-NetTCPConnection -LocalPort 9999 | Select-Object LocalPort, OwningProcess
Get-Process -Id <OwningProcess>

# Kill process
Stop-Process -Id <OwningProcess> -Force

# Or use different port (edit Host/api/server.py and docker-compose.yml)
```

### Issue 4: Docker build fails

**Cause:** Network issues or missing dependencies

**Solution:**
```powershell
# Clear Docker cache and rebuild
docker-compose -f docker-compose.method2.yml down
docker system prune -a -f
docker-compose -f docker-compose.method2.yml build --no-cache
```

### Issue 5: GPU metrics showing "unavailable"

**Cause:** GPU drivers not installed or not accessible

**Debug:**
```powershell
# Test GPU detection on host
cd Host/scripts
bash gpu_monitor.sh

# Check NVIDIA drivers
nvidia-smi

# Check AMD drivers
rocm-smi

# For WSL2, check Windows GPU
powershell.exe -Command "Get-WmiObject Win32_VideoController"
```

### Issue 6: Container can't reach host.docker.internal

**Cause:** Missing `extra_hosts` configuration

**Verify:**
```powershell
# Check docker-compose.yml contains:
extra_hosts:
  - "host.docker.internal:host-gateway"

# Test from inside container
docker exec system-monitor-method2 ping -c 2 host.docker.internal
docker exec system-monitor-method2 curl http://host.docker.internal:9999/health
```

---

## 📊 Monitoring & Logs

### View Docker Logs

```powershell
# Follow logs in real-time
docker-compose -f docker-compose.method2.yml logs -f

# Last 100 lines
docker-compose -f docker-compose.method2.yml logs --tail=100

# Filter for errors only
docker-compose -f docker-compose.method2.yml logs | Select-String "ERROR"
```

### View Host API Logs

```powershell
# If running manually, logs are in terminal

# If using systemd
sudo journalctl -u host-monitor -f

# Check Host monitoring output
cat Host/output/latest.json | jq '.timestamp'
```

### Check Metrics File

```powershell
# View full metrics
cat Host/output/latest.json | jq '.'

# Check GPU section
cat Host/output/latest.json | jq '.gpu'

# Check timestamp
cat Host/output/latest.json | jq '.timestamp'
```

---

## 🔄 Updating the System

### Update Code Only (No Docker Rebuild)

```powershell
# If you only changed:
# - Host scripts
# - web/app.py (non-dependency changes)
# - templates/static files

# Just restart container
docker-compose -f docker-compose.method2.yml restart
```

### Update with Docker Rebuild

```powershell
# If you changed:
# - Dockerfile
# - requirements.txt
# - docker-compose.yml

# Rebuild and restart
docker-compose -f docker-compose.method2.yml up --build -d
```

### Full Clean Rebuild

```powershell
# Stop and remove everything
docker-compose -f docker-compose.method2.yml down

# Remove images
docker rmi system-monitor:method2

# Clear cache
docker system prune -f

# Rebuild from scratch
docker-compose -f docker-compose.method2.yml build --no-cache
docker-compose -f docker-compose.method2.yml up -d
```

---

## 🎯 Production Deployment Checklist

- [ ] Host monitoring loop running (systemd service or background job)
- [ ] Host API server running on port 9999
- [ ] Docker image built with `--build` flag
- [ ] Docker container running (`docker ps` shows container)
- [ ] Port 5000 accessible (`curl http://localhost:5000/api/health`)
- [ ] Port 9999 accessible (`curl http://localhost:9999/health`)
- [ ] Container can reach Host API (`docker exec ... curl http://host.docker.internal:9999/health`)
- [ ] Dashboard shows metrics (browser: http://localhost:5000)
- [ ] GPU metrics visible (if GPU available)
- [ ] Logs show no errors (`docker-compose logs`)
- [ ] Auto-restart enabled (`restart: unless-stopped` in compose file)

---

## 🚀 Performance Optimization

### Reduce Monitoring Interval

```bash
# Edit Host/loop/host_monitor_loop.sh
INTERVAL=30  # Faster updates (default: 60)
```

### Increase Docker Resources

```yaml
# docker-compose.method2.yml
deploy:
  resources:
    limits:
      cpus: '4.0'    # More CPU
      memory: 4G     # More RAM
```

### Enable Gzip Compression

```python
# web/app.py
from flask_compress import Compress

app = Flask(__name__)
Compress(app)  # Add gzip compression
```

---

## 📚 Quick Reference

### Common Commands

```powershell
# Start everything
cd Host/api; python server.py &
cd ../loop; bash host_monitor_loop.sh &
cd ../../Docker; docker-compose -f docker-compose.method2.yml up -d

# Stop everything
docker-compose -f docker-compose.method2.yml down
pkill -f "python server.py"
pkill -f "host_monitor_loop.sh"

# Restart Docker only
docker-compose -f docker-compose.method2.yml restart

# View logs
docker-compose -f docker-compose.method2.yml logs -f

# Test endpoints
curl http://localhost:9999/health        # Host API
curl http://localhost:5000/api/health    # Dashboard API
curl http://localhost:5000/api/metrics   # Metrics
```

### File Locations

```
Host/output/latest.json          → Latest metrics from Host
Host/api/server.py               → Host API server (port 9999)
Host/loop/host_monitor_loop.sh   → Continuous monitoring
Docker/docker-compose.method2.yml → Docker config
web/app.py                        → Flask dashboard
data/metrics/current.json        → Container's local metrics (fallback)
```

---

## ✅ Summary: What Changed & Why

| File | Change | Why |
|------|--------|-----|
| `docker-compose.yml` | Added `9999:9999` port | Expose Host API to host machine |
| `docker-compose.yml` | Added `extra_hosts` | Allow container to reach `host.docker.internal` |
| `Dockerfile` | Added `pip install requests` | Enable HTTP calls to Host API |
| `web/app.py` | Added fallback to TCP API | Get metrics from Host API if local file missing |
| `Host/*` | New module | Real hardware monitoring with GPU support |

**Result:** Docker container can now get **real GPU metrics** and **accurate temperatures** from the Host API! 🎉

---

## 🎉 You're All Set!

Your system now has:
✅ Real GPU monitoring (NVIDIA/AMD/Intel)  
✅ Accurate WSL2 temperature readings (PowerShell WMI)  
✅ TCP API for flexible integration (port 9999)  
✅ Docker dashboard with full metrics (port 5000/5001)  
✅ Automatic fallback (file → API → error)  
✅ Production-ready systemd service  

**Next:** Follow the "Quick Start" section above to deploy! 🚀
