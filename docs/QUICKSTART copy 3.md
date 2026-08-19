# 🚀 System Monitor - Two-Tier Architecture

**Real-time hardware monitoring with Docker deployment**

[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Windows%20%7C%20Mac-green.svg)](https://github.com/Sharawey74/system-monitor-project)

---

## ⚡ Quick Start (One Command)

```bash
bash start-system-monitor.sh
```

**That's it!** Opens http://localhost:5000 automatically.

---

## 🎯 What This Monitors

- ✅ **CPU** - Usage, temperature, cores
- ✅ **GPU** - NVIDIA + Intel detection, temps, memory  
- ✅ **RAM** - Total, used, available
- ✅ **Disk** - Space, I/O operations
- ✅ **Network** - Traffic, connections
- ✅ **Sensors** - All hardware temperatures

---

## 📋 Prerequisites

| Requirement | Version | Notes |
|------------|---------|-------|
| Docker | Latest | + Docker Compose |
| Python | 3.8+ | For Host API |
| Bash | Any | WSL2 on Windows |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────┐
│ Your Machine                                │
│                                             │
│  ┌────────────────────────────────────────┐│
│  │ Host API (Native) - Port 8888         ││
│  │ Real hardware access                   ││
│  └────────────────────────────────────────┘│
│                    ↕ HTTP                   │
│  ┌────────────────────────────────────────┐│
│  │ Dashboard (Docker) - Port 5000        ││
│  │ Web interface                          ││
│  └────────────────────────────────────────┘│
└─────────────────────────────────────────────┘
```

---

## 🚀 Usage

```bash
# Start everything
bash start-system-monitor.sh

# Stop everything
bash stop-system-monitor.sh

# View logs
tail -f /tmp/host-api.log       # Host API
docker-compose logs -f          # Dashboard
```

---

## 🔧 Verify Installation

```bash
# Check Host API
curl http://localhost:8888/health

# Check Dashboard
curl http://localhost:5000/api/health

# View metrics
curl http://localhost:5000/api/metrics | jq
```

---

## 📖 Documentation

- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Full deployment guide
- [SINGLE_COMMAND_SETUP.md](SINGLE_COMMAND_SETUP.md) - Setup instructions

---

## 🐛 Troubleshooting

### Host API won't start
```bash
tail -f /tmp/host-api.log
pip3 install fastapi uvicorn
```

### Dashboard can't connect
```bash
curl http://localhost:8888/health
docker exec system-monitor-dashboard curl http://host.docker.internal:8888/health
```

---

## 📄 License

MIT License

---

**Access Dashboard:** http://localhost:5000 🎉
