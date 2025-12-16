# 🚀 System Monitor - Two-Tier Architecture

**Real hardware monitoring with Docker deployment**

## 📋 Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Your Machine (Windows/Linux/Mac)                        │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │ Host API (Native Process)                          │ │
│  │ • Runs directly on your OS                         │ │
│  │ • Real GPU/CPU/sensor access                       │ │
│  │ • Port: 8888                                       │ │
│  └────────────────────────────────────────────────────┘ │
│                          ▲                               │
│                          │ HTTP                          │
│                          ▼                               │
│  ┌────────────────────────────────────────────────────┐ │
│  │ Dashboard (Docker Container)                       │ │
│  │ • Web interface                                    │ │
│  │ • Fetches metrics from Host API                   │ │
│  │ • Port: 5000                                       │ │
│  │ • Privileged mode (Method 1)                      │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

---

## ✅ Prerequisites

### All Platforms:
- **Docker** and **Docker Compose** installed
- **Python 3.8+** (for Host API)
- **Bash** shell (Linux/Mac native, Windows via WSL2/Git Bash)

### Windows:
- **WSL2** (Ubuntu recommended)
- Docker Desktop with WSL2 backend

### Linux/Mac:
- Docker installed natively
- Bash shell (already included)

---

## 🎯 Quick Start

### Option 1: One Command (Recommended)

```bash
bash start-system-monitor.sh
```

This automatically:
1. ✅ Starts Host API on your native OS
2. ✅ Builds Docker image
3. ✅ Starts Dashboard container
4. ✅ Opens http://localhost:5000 in browser

### Option 2: Manual Steps

```bash
# 1. Start Host API
bash start-host-api.sh

# 2. Start Dashboard
docker-compose up --build -d

# 3. Open browser
http://localhost:5000
```

---

## 🛑 Stop Everything

```bash
bash stop-system-monitor.sh
```

Or manually:

```bash
# Stop Dashboard
docker-compose down

# Stop Host API
bash stop-host-api.sh
```

---

## 📦 For Distribution (Docker Hub)

### Build and Push Image

```bash
# Build dashboard image
docker build -t yourusername/system-monitor:latest .

# Push to Docker Hub
docker push yourusername/system-monitor:latest
```

### Users Pull and Run

```bash
# Clone repository (for Host module)
git clone https://github.com/yourusername/system-monitor
cd system-monitor

# Start Host API on native OS
bash start-host-api.sh

# Pull and run Dashboard image
docker pull yourusername/system-monitor:latest
docker run -d \
  --name system-monitor-dashboard \
  --pid host \
  --privileged \
  -p 5000:5000 \
  --add-host host.docker.internal:host-gateway \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/reports:/app/reports \
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  -v /dev:/host/dev:ro \
  yourusername/system-monitor:latest
```

**OR use the simplified script:**

```bash
# Pull image and use docker-compose
docker-compose pull
bash start-system-monitor.sh
```

---

## 📁 Project Structure

```
system-monitor-project/
├── Dockerfile                 # Dashboard container image
├── docker-compose.yml         # One-command deployment
├── start-system-monitor.sh    # All-in-one startup script
├── stop-system-monitor.sh     # All-in-one shutdown script
├── start-host-api.sh          # Start Host API only
├── stop-host-api.sh           # Stop Host API only
├── requirements.txt           # Python dependencies
├── Host/                      # Host monitoring module
│   ├── api/
│   │   └── server.py         # FastAPI TCP server (port 8888)
│   ├── scripts/
│   │   └── main_monitor.sh   # Collects real hardware metrics
│   └── output/
│       └── latest.json       # Current metrics
├── web/
│   └── app.py                # Flask dashboard
├── static/                    # CSS/JS/images
├── templates/                 # HTML templates
├── data/                      # Metrics storage
└── reports/                   # Generated reports
```

---

## 🔧 Configuration

### Change Ports

Edit `docker-compose.yml`:

```yaml
ports:
  - "5000:5000"    # Change first 5000 to desired port
```

Edit `Host/api/server.py`:

```python
API_PORT = 8888  # Change to desired port
```

### Resource Limits

Edit `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      cpus: '1.0'      # Max CPU cores
      memory: 512M     # Max RAM
```

---

## 🧪 Verify Installation

```bash
# Check Host API
curl http://localhost:8888/health
# Should return: {"status":"ok"}

# Check Dashboard
curl http://localhost:5000/api/health
# Should return: {"status":"healthy"}

# Check GPU metrics
curl http://localhost:5000/api/metrics | jq '.data.gpu'
```

---

## 🐛 Troubleshooting

### Host API won't start

```bash
# Check logs
tail -f /tmp/host-api.log

# Check Python dependencies
python3 -c "import fastapi, uvicorn"

# Install manually
pip3 install fastapi uvicorn
```

### Dashboard can't connect to Host API

```bash
# Check Host API is running
curl http://localhost:8888/health

# Check Docker network
docker exec system-monitor-dashboard curl http://host.docker.internal:8888/health

# Check firewall (Windows)
netsh advfirewall firewall add rule name="System Monitor Host API" dir=in action=allow protocol=TCP localport=8888
```

### Port already in use

```bash
# Find process using port 8888
lsof -ti:8888

# Kill process
kill $(lsof -ti:8888)

# Or change port in Host/api/server.py
```

---

## 🎓 Understanding the Architecture

### Why Two-Tier?

| Component | Where | Why |
|-----------|-------|-----|
| **Host API** | Native OS | Needs real GPU/sensor access |
| **Dashboard** | Docker | Portable, isolated, easy deployment |

### Why Host API Can't Be in Docker?

- ❌ Docker containers are **virtualized**
- ❌ Can't access real GPU drivers
- ❌ Can't read hardware sensors
- ❌ Can't call Windows WMI
- ✅ **Solution:** Run Host API natively, Dashboard in Docker

### Method 1 vs Method 2?

This project uses **Method 1 (Privileged)** for maximum compatibility:

| Feature | Method 1 | Method 2 |
|---------|----------|----------|
| **Mode** | `privileged: true` | Read-only bind mounts |
| **Security** | Lower | Higher |
| **Hardware Access** | Full (container can see host processes) | Limited (only mounted paths) |
| **Compatibility** | Works everywhere | May need adjustments |
| **Production** | ⚠️ Use with caution | ✅ Recommended |

---

## 📊 What Metrics Are Monitored?

### Real Hardware (via Host API):
- ✅ **CPU**: Usage, temperature, cores
- ✅ **GPU**: NVIDIA + Intel detection, temperature, memory
- ✅ **RAM**: Total, used, available
- ✅ **Disk**: Space, I/O
- ✅ **Network**: Traffic, connections
- ✅ **Sensors**: All hardware temperatures

### Container Metrics (via Dashboard):
- ⚠️ **Limited**: Shows container's virtualized view
- ℹ️ **Dashboard prioritizes Host API data**

---

## 🌍 Cross-Platform Support

| OS | Host API | Dashboard | Notes |
|----|----------|-----------|-------|
| **Linux** | ✅ Native bash | ✅ Docker | Best compatibility |
| **macOS** | ✅ Native bash | ✅ Docker | Full support |
| **Windows** | ✅ WSL2 bash | ✅ Docker Desktop | Use WSL2 Ubuntu |

---

## 🤝 Contributing

This project is open-source. To contribute:

1. Fork repository
2. Create feature branch
3. Test on Linux/Mac/Windows
4. Submit pull request

---

## 📄 License

MIT License - See LICENSE file

---

## 🎉 Success Indicators

When everything works correctly, you'll see:

```
✓ Host API running on port 8888
✓ Dashboard running on port 5000
✓ Real hostname displayed (not container ID)
✓ Both GPUs detected (NVIDIA + Intel)
✓ Real temperature readings
✓ Source: host-api (not local-file)
```

**Access your dashboard at:** http://localhost:5000 🎊
