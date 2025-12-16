# 🚀 System Monitor - Quick Start Guide

Complete guide for running System Monitor on any machine.

---

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Option 1: Full Repository Setup (Developers)](#option-1-full-repository-setup-developers)
- [Option 2: Docker Image Only (End Users)](#option-2-docker-image-only-end-users)
- [What Happens When You Run](#what-happens-when-you-run)
- [Accessing the Dashboard](#accessing-the-dashboard)
- [Troubleshooting](#troubleshooting)
- [Stopping the System](#stopping-the-system)

---

## 🔧 Prerequisites

### Required Software

| Software | Check Command | Installation |
|----------|--------------|--------------|
| **Docker** | `docker --version` | [Install Docker](https://docs.docker.com/get-docker/) |
| **Git** | `git --version` | `sudo apt-get install git` (Linux)<br>`brew install git` (Mac) |
| **Python 3** | `python3 --version` | Pre-installed on most systems |
| **curl** | `curl --version` | Pre-installed on most systems |

### Verify Installation

```bash
# Check all prerequisites at once
docker --version && git --version && python3 --version && curl --version
```

Expected output:
```
Docker version 24.0.x
git version 2.x.x
Python 3.8.x or higher
curl 7.x.x
```

---

## 🎯 Option 1: Full Repository Setup (Developers)

**Use this if:** You want to modify code, build from source, or have the complete project.

### Step 1: Clone Repository

```bash
git clone https://github.com/Sharawey74/system-monitor-project.git
cd system-monitor-project
```

### Step 2: Run Universal Startup Script

```bash
chmod +x start-universal.sh
./start-universal.sh
```

### What Happens

```
1. Checks Host API scripts ✓
2. Starts Host API on native OS (port 8888) ✓
   - Installs Python dependencies
   - Generates hardware metrics
   - Starts FastAPI server
3. Builds Docker container ✓
4. Starts Dashboard (port 5000) ✓
5. Verifies both services ✓
```

### Expected Output

```
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
[2025-12-14 16:46:21] INFO: Starting Host monitoring collection
[2025-12-14 16:46:21] INFO: Running system_monitor.sh
[2025-12-14 16:46:21] INFO: system_monitor.sh completed successfully
[2025-12-14 16:46:21] INFO: Running cpu_monitor.sh
[2025-12-14 16:46:24] INFO: cpu_monitor.sh completed successfully
[2025-12-14 16:46:24] INFO: Running memory_monitor.sh
[2025-12-14 16:46:24] INFO: memory_monitor.sh completed successfully
[2025-12-14 16:46:24] INFO: Running disk_monitor.sh
[2025-12-14 16:46:25] INFO: disk_monitor.sh completed successfully
[2025-12-14 16:46:25] INFO: Running network_monitor.sh
[2025-12-14 16:46:25] INFO: network_monitor.sh completed successfully
[2025-12-14 16:46:25] INFO: Running temperature_monitor.sh
[2025-12-14 16:46:29] INFO: temperature_monitor.sh completed successfully
[2025-12-14 16:46:29] INFO: Running gpu_monitor.sh
[2025-12-14 16:46:31] INFO: gpu_monitor.sh completed successfully
[2025-12-14 16:46:31] INFO: Running fan_monitor.sh
[2025-12-14 16:46:31] INFO: fan_monitor.sh completed successfully
[2025-12-14 16:46:31] INFO: Running smart_monitor.sh
[2025-12-14 16:46:31] INFO: smart_monitor.sh completed successfully
[2025-12-14 16:46:31] INFO: Monitoring data written to: Host/output/latest.json
✅ Monitoring data written successfully

► Starting Host API...
✓ Host API started (PID: 3951)
► Waiting for API to be ready...
.✓ Host API is ready!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Host API:    http://localhost:8888
  Health:      http://localhost:8888/health
  Metrics:     http://localhost:8888/metrics
  PID File:    /tmp/host-api.pid
  Logs:        /tmp/host-api.log
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
  Host API:    ✓ Running
  Dashboard:   ✓ Running

Terminal Dashboard:
  docker exec -it system-monitor-dashboard python3 dashboard_tui.py

Logs:
  Host API:    tail -f /tmp/host-api.log
  Dashboard:   docker logs -f system-monitor-dashboard

To stop:
  bash stop-system-monitor.sh

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### ✅ Done!

Open browser: **http://localhost:5000**

---

## 🐳 Option 2: Docker Image Only (End Users)

**Use this if:** You just want to run the system without the full source code.

### Visual Workflow

```
┌─────────────────────────────────────────────────────────┐
│  Step 1: Pull Docker Image                              │
│  docker pull sharawey74/system-monitor:latest           │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│  Step 2: Download Universal Startup Script              │
│  curl -O https://raw.githubusercontent.com/.../start... │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│  Step 3: Make Script Executable                         │
│  chmod +x start-universal.sh                            │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│  Step 4: Run Script                                     │
│  ./start-universal.sh                                   │
│  (Auto-downloads Host API scripts from GitHub)          │
└─────────────────────────────────────────────────────────┘
                        ↓
                  ✓ Running!
```

### Step-by-Step Commands

#### **Step 1: Pull Docker Image**

```bash
docker pull sharawey74/system-monitor:latest
```

**Expected output:**
```
latest: Pulling from sharawey74/system-monitor
Digest: sha256:xxxxxxxxxxxxx
Status: Downloaded newer image for sharawey74/system-monitor:latest
docker.io/sharawey74/system-monitor:latest
```

**✅ Image pulled successfully!**

**Next Steps:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📝 To complete setup, run these 3 commands:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Download startup script:
   curl -O https://raw.githubusercontent.com/Sharawey74/system-monitor-project/main/start-universal.sh

2. Make it executable:
   chmod +x start-universal.sh

3. Run the script:
   ./start-universal.sh

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
The script will automatically:
  ✓ Download Host API scripts from GitHub
  ✓ Start Host API on your native OS
  ✓ Run the Docker container
  ✓ Verify everything is working
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

#### **Step 2: Download Startup Script**

```bash
curl -O https://raw.githubusercontent.com/Sharawey74/system-monitor-project/main/start-universal.sh
```

**Expected output:**
```
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  8234  100  8234    0     0  41234      0 --:--:-- --:--:-- --:--:-- 41234
```

**✅ Script downloaded successfully!**

---

#### **Step 3: Make Script Executable**

```bash
chmod +x start-universal.sh
```

**No output means success!**

---

#### **Step 4: Run the Script**

```bash
./start-universal.sh
```

**What the script does:**

1. **Auto-downloads Host API scripts** from GitHub if missing
2. **Installs Python dependencies** (fastapi, uvicorn)
3. **Generates hardware metrics** (CPU, GPU, RAM, Disk, Network, Temperature, Fans, S.M.A.R.T)
4. **Starts Host API** on port 8888 (native OS for real hardware access)
5. **Starts Dashboard container** on port 5000
6. **Verifies both services** are running

**Expected output:** Same as Option 1 (see above)

---

## 🎛️ What Happens When You Run

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│  Your Computer (Windows/Linux/Mac)                      │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │  Native OS (Real Hardware Access)              │    │
│  │                                                 │    │
│  │  ┌─────────────────────────────────────────┐  │    │
│  │  │  Host API (Port 8888)                   │  │    │
│  │  │  - Collects CPU, GPU, RAM metrics       │  │    │
│  │  │  - Reads temperature sensors            │  │    │
│  │  │  - Gets S.M.A.R.T disk data             │  │    │
│  │  │  - Monitors fans, network               │  │    │
│  │  └─────────────────────────────────────────┘  │    │
│  │                     ↓ HTTP API                 │    │
│  └────────────────────────────────────────────────┘    │
│                        │                                │
│  ┌────────────────────────────────────────────────┐    │
│  │  Docker Container (Isolated Environment)       │    │
│  │                                                 │    │
│  │  ┌─────────────────────────────────────────┐  │    │
│  │  │  Dashboard (Port 5000)                  │  │    │
│  │  │  - Beautiful web interface              │  │    │
│  │  │  - Fetches data from Host API           │  │    │
│  │  │  - Displays charts & graphs             │  │    │
│  │  │  - Terminal dashboard (TUI)             │  │    │
│  │  └─────────────────────────────────────────┘  │    │
│  └────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
         ↓                              ↓
   Port 8888                        Port 5000
   (Host API)                    (Web Dashboard)
```

### Two-Tier Architecture Explained

**Why two parts?**

| Component | Where It Runs | Purpose | Why? |
|-----------|--------------|---------|------|
| **Host API** | Native OS | Real hardware access | Docker containers can't access hardware sensors directly |
| **Dashboard** | Docker | Beautiful UI | Easy deployment, works anywhere, no dependencies |

**The Dashboard is USELESS without the Host API!**

- ❌ Without Host API → Dashboard shows container metrics (fake data)
- ✅ With Host API → Dashboard shows real Windows/Linux/Mac hardware metrics

---

## 🌐 Accessing the Dashboard

### Web Dashboard

Open your browser:

```
http://localhost:5000
```

**Features:**
- 📊 Real-time CPU, Memory, Disk, Network usage
- 🌡️ Temperature monitoring (CPU & GPU)
- 🎮 GPU information
- 💾 Disk S.M.A.R.T status
- 💨 Fan speeds
- 🎯 RAM module details
- 📈 Historical graphs (Chart.js)
- 📄 Generate PDF reports

### Terminal Dashboard (TUI)

For terminal-based monitoring:

```bash
docker exec -it system-monitor-dashboard python3 dashboard_tui.py
```

**Features:**
- Real-time updating terminal UI
- Color-coded status indicators
- Keyboard shortcuts
- Works over SSH

### API Endpoints

Direct API access:

```bash
# Health check
curl http://localhost:8888/health

# Get all metrics
curl http://localhost:8888/metrics

# Dashboard API
curl http://localhost:5000/api/metrics

# Historical data
curl http://localhost:5000/api/history?limit=10
```

---

## 🔍 Troubleshooting

### Issue: "Host API failed to start"

**Symptoms:**
```
✗ Host API failed to start
Check logs: tail -f /tmp/host-api.log
```

**Solutions:**

1. **Check Python dependencies:**
   ```bash
   python3 -c "import fastapi, uvicorn"
   ```
   If error: `pip3 install fastapi uvicorn`

2. **Check if port 8888 is already in use:**
   ```bash
   sudo lsof -i :8888
   # or
   netstat -tuln | grep 8888
   ```

3. **View Host API logs:**
   ```bash
   tail -f /tmp/host-api.log
   ```

4. **Restart Host API manually:**
   ```bash
   cd Host/api
   python3 server.py
   ```

---

### Issue: "Dashboard shows container metrics instead of host metrics"

**Symptoms:**
- Hostname shows container ID (e.g., `1bb95129af86`)
- OS shows `Ubuntu 22.04` (container OS)
- Temperature shows `N/A`
- GPU shows "unavailable"

**Solution:**

**The Host API is NOT running!** Start it:

```bash
# Check if Host API is running
curl http://localhost:8888/health

# If not running, start it
cd Host/scripts
bash main_monitor.sh
cd ../api
python3 server.py &
```

Then refresh the dashboard.

---

### Issue: "docker pull failed"

**Symptoms:**
```
Error response from daemon: manifest for sharawey74/system-monitor:latest not found
```

**Solutions:**

1. **Image not published yet:**
   Build locally instead:
   ```bash
   git clone https://github.com/Sharawey74/system-monitor-project.git
   cd system-monitor-project
   docker-compose up --build -d
   ```

2. **Docker Hub login required:**
   ```bash
   docker login
   ```

---

### Issue: "Permission denied" when running script

**Symptoms:**
```
bash: ./start-universal.sh: Permission denied
```

**Solution:**
```bash
chmod +x start-universal.sh
./start-universal.sh
```

---

### Issue: "Git not found"

**Symptoms:**
```
✗ Failed to download from GitHub
Please ensure you have: Git installed
```

**Solution:**

**Linux:**
```bash
sudo apt-get update
sudo apt-get install git
```

**Mac:**
```bash
brew install git
```

**Windows (WSL2):**
```bash
sudo apt-get install git
```

---

### Issue: "Docker not running"

**Symptoms:**
```
Cannot connect to the Docker daemon
```

**Solution:**

1. **Start Docker Desktop** (Windows/Mac)
2. **Start Docker daemon** (Linux):
   ```bash
   sudo systemctl start docker
   sudo systemctl enable docker
   ```

---

## 🛑 Stopping the System

### Stop Everything

```bash
bash stop-system-monitor.sh
```

**Or manually:**

```bash
# Stop dashboard
docker-compose down
# or
docker stop system-monitor-dashboard
docker rm system-monitor-dashboard

# Stop Host API
kill $(cat /tmp/host-api.pid)
```

### Stop Only Dashboard

```bash
docker stop system-monitor-dashboard
```

(Host API keeps running)

### Stop Only Host API

```bash
kill $(cat /tmp/host-api.pid)
```

(Dashboard keeps running but shows no data)

---

## 📊 Logs and Debugging

### View Logs

```bash
# Host API logs
tail -f /tmp/host-api.log

# Dashboard logs
docker logs -f system-monitor-dashboard

# Both at once (Linux/Mac)
tail -f /tmp/host-api.log & docker logs -f system-monitor-dashboard
```

### Check Status

```bash
# Host API health
curl http://localhost:8888/health

# Dashboard health
curl http://localhost:5000/api/health

# Both
curl http://localhost:8888/health && curl http://localhost:5000/api/health
```

### Debug Mode

```bash
# Run Host API in foreground (see all output)
cd Host/api
python3 server.py

# Run dashboard in foreground
docker-compose up
```

---

## 🎯 Quick Reference

### Essential Commands

```bash
# Start everything
./start-universal.sh

# Stop everything
bash stop-system-monitor.sh

# View web dashboard
open http://localhost:5000

# View terminal dashboard
docker exec -it system-monitor-dashboard python3 dashboard_tui.py

# Check status
curl http://localhost:8888/health && curl http://localhost:5000/api/health

# View logs
tail -f /tmp/host-api.log
docker logs -f system-monitor-dashboard

# Restart just dashboard
docker restart system-monitor-dashboard

# Restart just Host API
kill $(cat /tmp/host-api.pid)
cd Host/api && nohup python3 server.py > /tmp/host-api.log 2>&1 &
```

---

## 📚 Additional Resources

- **GitHub Repository:** https://github.com/Sharawey74/system-monitor-project
- **Docker Hub Image:** https://hub.docker.com/r/sharawey74/system-monitor
- **Issues/Support:** https://github.com/Sharawey74/system-monitor-project/issues

---

## 💡 Tips

1. **First time setup takes longer** (~2-5 minutes) because it installs dependencies and generates initial metrics
2. **Subsequent starts are faster** (~30 seconds) because everything is already set up
3. **Host API must always run first** before starting the dashboard
4. **Use docker-compose if you have the repository**, use `docker run` if you only pulled the image
5. **Check logs if something fails** - they contain detailed error messages
6. **Port 8888 and 5000 must be free** - stop any services using these ports

---

## 🚀 Summary

| Scenario | Commands | Time |
|----------|----------|------|
| **Full Repository** | `git clone ... && cd ... && ./start-universal.sh` | ~3 min |
| **Docker Image Only** | `docker pull ... && curl ... && chmod +x ... && ./start-universal.sh` | ~2 min |
| **Restart After Stop** | `./start-universal.sh` | ~30 sec |

**Both options give you the same result:** A fully functional system monitor with real hardware metrics! 🎉

---

**Need help?** Open an issue on GitHub: https://github.com/Sharawey74/system-monitor-project/issues
