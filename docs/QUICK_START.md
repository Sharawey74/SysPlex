# 🎯 Quick Deploy - TL;DR

## ⚡ Fastest Path to Running System

### 1️⃣ Start Host Monitoring (Terminal 1)

```powershell
cd c:\Users\DELL\Desktop\system-monitor-project-Batch\Host\api
pip install fastapi uvicorn
python server.py
```

**Wait for:** `Uvicorn running on http://0.0.0.0:9999` ✅

---

### 2️⃣ Start Metrics Collection (Terminal 2)

```powershell
cd c:\Users\DELL\Desktop\system-monitor-project-Batch\Host\loop
bash host_monitor_loop.sh
```

**Wait for:** `✅ Metrics updated: Host/output/latest.json` ✅

---

### 3️⃣ Build & Run Docker (Terminal 3)

```powershell
cd c:\Users\DELL\Desktop\system-monitor-project-Batch\Docker
docker-compose -f docker-compose.method2.yml up --build -d
```

**Wait for:** `✔ Container system-monitor-method2 Started` ✅

---

### 4️⃣ Open Dashboard

```
🌐 Browser: http://localhost:5000
```

**You should see:** Dashboard with GPU metrics! 🎉

---

## 🧪 Quick Test

```powershell
# Test Host API
curl http://localhost:9999/health

# Test Dashboard API
curl http://localhost:5000/api/metrics

# Test Docker can reach Host
docker exec system-monitor-method2 curl http://host.docker.internal:9999/health
```

---

## ❓ Do I Need to Rebuild?

### YES ✅ - Run with `--build`
```powershell
docker-compose -f docker-compose.method2.yml up --build -d
```

**Rebuild if:**
- First time running with new changes
- Changed Dockerfile (added `requests`)
- Changed docker-compose.yml (added ports/extra_hosts)

### NO ❌ - Just restart
```powershell
docker-compose -f docker-compose.method2.yml restart
```

**Restart only if:**
- Only changed Python code (web/app.py)
- Only changed templates/static files
- Only changed Host scripts

---

## 🔄 Update Workflow

### Already Running? Update Like This:

```powershell
# 1. Stop Docker
docker-compose -f docker-compose.method2.yml down

# 2. Rebuild with new changes
docker-compose -f docker-compose.method2.yml build

# 3. Start again
docker-compose -f docker-compose.method2.yml up -d

# 4. Check logs
docker-compose -f docker-compose.method2.yml logs -f
```

---

## 📊 What Changed?

| Component | Status | Purpose |
|-----------|--------|---------|
| `docker-compose.yml` | ✅ Modified | Expose port 9999, add extra_hosts |
| `Dockerfile` | ✅ Modified | Install requests package |
| `web/app.py` | ✅ Modified | Fallback to Host API |
| `Host/` module | ✅ New | Real GPU & temp monitoring |

---

## 🎯 Architecture (Simple View)

```
Host Machine
├─ Host API (port 9999)          ← Provides real metrics
│  └─ Reads: Host/output/latest.json
│
└─ Docker Container (port 5000)  ← Web dashboard
   └─ Flask app tries:
      1. Local file (/app/data/metrics/current.json)
      2. Host API (http://host.docker.internal:9999/metrics) ← NEW!
      3. Return error if both fail
```

---

## 🐛 Quick Troubleshooting

### Problem: "Connection refused" on port 9999
```powershell
# Check if API running
netstat -ano | findstr :9999

# Start API
cd Host/api
python server.py
```

### Problem: "No metrics available"
```powershell
# Start Host monitoring
cd Host/loop
bash host_monitor_loop.sh &

# Wait 5 seconds, then check
cat ../output/latest.json
```

### Problem: Dashboard shows no GPU
```powershell
# Test GPU detection
cd Host/scripts
bash gpu_monitor.sh

# Check output has GPU data
cat ../output/latest.json | jq '.gpu'
```

---

## 🚀 Production Deploy (One-Time Setup)

```powershell
# Install systemd service (Linux/WSL2)
cd Host
sudo bash quickstart.sh
# Select: 6) Install systemd service
# Select: 5) Install dependencies

# Start service
sudo systemctl start host-monitor
sudo systemctl enable host-monitor  # Auto-start on boot

# Then run Docker as usual
cd ../Docker
docker-compose -f docker-compose.method2.yml up -d
```

---

## 📝 Key Points

1. **Host API must run FIRST** (port 9999)
2. **Docker needs `--build`** flag on first run with changes
3. **Two methods available**: Method 1 (port 5001) or Method 2 (port 5000)
4. **GPU metrics require Host API** running
5. **Container reaches host** via `host.docker.internal:9999`

---

## 🎉 Final Checklist

- [ ] Host API running on port 9999
- [ ] Host monitoring loop running
- [ ] Docker built with `--build` flag
- [ ] Container started successfully
- [ ] Dashboard accessible at http://localhost:5000
- [ ] GPU metrics visible in dashboard

**All checked?** You're done! 🚀

---

## 📚 Full Documentation

For complete details, see:
- [DOCKER_DEPLOYMENT_GUIDE.md](DOCKER_DEPLOYMENT_GUIDE.md) - Full deployment guide
- [Host/INTEGRATION_GUIDE.md](Host/INTEGRATION_GUIDE.md) - Integration options
- [Host/README.md](Host/README.md) - Host module documentation
- [Host/IMPLEMENTATION_SUMMARY.md](Host/IMPLEMENTATION_SUMMARY.md) - Technical details
