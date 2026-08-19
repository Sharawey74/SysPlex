# 🐳 Docker Deployment Options

This directory contains Docker configurations for system monitoring deployment.

## Available Deployment Methods

### 1️⃣ Two-Tier Architecture (Production) ✅

**Location**: Root directory  
**Files**: `docker-compose.yml`, `Dockerfile`

```bash
# Start from project root
bash start-system-monitor.sh
```

- **Architecture**: Host API (native) + Dashboard (container)
- **Security**: ✅ High - No privileged containers
- **Hardware Access**: ✅ Full - Native host monitoring
- **Production**: ✅ Ready
- **Port**: 5000

**Use this for**: Production deployments, real hardware monitoring

📖 **Guide**: [../QUICKSTART.md](../QUICKSTART.md)

---

### 2️⃣ Fully Contained (FC) Mode 🧪

**Location**: This directory  
**Files**: `docker-compose.fc.yml`, `Dockerfile.fc`

```bash
# Start FC mode
docker-compose -f docker-compose.fc.yml up --build -d
```

- **Architecture**: Single privileged container
- **Security**: ⚠️ Low - Uses privileged mode
- **Hardware Access**: ⚠️ Limited - VM dependent
- **Production**: ❌ Not suitable
- **Port**: 5100

**Use this for**: Development, testing, academic demos

📖 **Guide**: [FC_DEPLOYMENT_GUIDE.md](FC_DEPLOYMENT_GUIDE.md)

---

## 🔍 Quick Comparison

| Feature | Two-Tier ✅ | FC Mode 🧪 |
|---------|------------|-----------|
| **Security** | High (unprivileged) | Low (privileged) |
| **Temperature Sensors** | ✅ Full access | ❌ VM limited |
| **GPU Monitoring** | ✅ Native support | ⚠️ Toolkit needed |
| **Setup Complexity** | Medium (2 components) | Low (1 container) |
| **Production Ready** | ✅ Yes | ❌ No |
| **VM Friendly** | ⚠️ Limited in container | ⚠️ Limited |
| **Bare Metal** | ✅ Excellent | ⚠️ Good |

## 🎯 Which Method Should I Use?

### Use Two-Tier if:
- ✅ You need production deployment
- ✅ You want full hardware monitoring (temp, GPU, fans)
- ✅ Security and compliance matter
- ✅ Running on bare metal or WSL2

### Use FC if:
- ✅ Quick testing or demo
- ✅ Learning Docker concepts
- ✅ Academic project submission
- ✅ Isolated lab environment
- ❌ Don't need hardware sensors

## 📂 Directory Structure

```
Docker/
├── Dockerfile.fc                 # FC container definition
├── docker-compose.fc.yml         # FC deployment config
├── docker-entrypoint.fc.sh       # FC startup script
├── FC_DEPLOYMENT_GUIDE.md        # FC documentation
├── SMART_COMPOSE_QUICKSTART.md   # Legacy guide (archived)
└── README.md                     # This file
```

## 🚀 Quick Start Commands

### Start Two-Tier (from project root)
```bash
# Start both Host API and Dashboard
bash start-system-monitor.sh

# Access at http://localhost:5000
```

### Start FC Mode (from Docker directory)
```bash
# Build and run
docker-compose -f docker-compose.fc.yml up --build -d

# View logs
docker-compose -f docker-compose.fc.yml logs -f

# Stop
docker-compose -f docker-compose.fc.yml down

# Access at http://localhost:5100
```

## 🔧 Advanced Usage

### FC Mode with GPU Support
```bash
docker run -d \
  --name monitor-fc-gpu \
  --privileged \
  --pid=host \
  --runtime=nvidia \
  -p 5100:5000 \
  system-monitor:fc
```

### FC Mode - Interactive Shell
```bash
docker-compose -f docker-compose.fc.yml run --rm monitor-fc bash
```

### FC Mode - Manual Metrics Collection
```bash
docker exec system-monitor-fc bash /app/scripts/main_monitor.sh
```

## 🐛 Troubleshooting

### FC Container Won't Start
```bash
# Check Docker is running
docker ps

# Rebuild without cache
docker-compose -f docker-compose.fc.yml build --no-cache

# Check logs
docker-compose -f docker-compose.fc.yml logs
```

### FC Shows No Metrics
```bash
# Verify privileged mode
docker inspect system-monitor-fc | grep Privileged

# Check metrics file
docker exec system-monitor-fc cat /app/data/metrics/current.json

# Run collection manually
docker exec -it system-monitor-fc bash /app/scripts/main_monitor.sh
```

## 📖 Documentation

- **FC Guide**: [FC_DEPLOYMENT_GUIDE.md](FC_DEPLOYMENT_GUIDE.md) - Complete FC documentation
- **Two-Tier Guide**: [../QUICKSTART.md](../QUICKSTART.md) - Production deployment
- **Main README**: [../README.md](../README.md) - Project overview
- **Host API**: [../Host/README.md](../Host/README.md) - Native monitoring

## ⚠️ Important Notes

### Security Warning for FC Mode
FC mode uses Docker's **privileged mode**, which grants the container:
- Root-level access to the host system
- Ability to view all host processes
- Access to all devices and kernel capabilities

**Never use FC mode for**:
- Production servers
- Shared hosting environments
- Systems with sensitive data
- Compliance-required infrastructure

### VM Limitations
Both deployment methods face limitations in virtual machines:
- **Temperature sensors**: Not exposed by hypervisors
- **Hardware details**: Virtualized or hidden
- **GPU access**: Requires passthrough configuration

**Solution**: Use Two-Tier on **bare metal** or **WSL2** for full hardware access.

## 🏆 Best Practices

### For Learning/Development
1. Start with FC mode for quick testing
2. Use isolated VM or local machine
3. Don't expose ports to network
4. Destroy after use

### For Production
1. Use Two-Tier architecture
2. Deploy Host API natively
3. Run Dashboard in container (unprivileged)
4. Enable monitoring and logging
5. Use firewall rules
6. Regular security audits

## 📦 Cleanup

### Remove FC Deployment
```bash
# Stop and remove containers
docker-compose -f docker-compose.fc.yml down

# Remove images
docker rmi system-monitor:fc

# Clean build cache
docker builder prune -a
```

### Remove All System Monitor Containers
```bash
# Stop all
docker stop system-monitor-fc system-monitor-dashboard

# Remove all
docker rm system-monitor-fc system-monitor-dashboard

# Remove images
docker images | grep system-monitor | awk '{print $3}' | xargs docker rmi
```

## 🤝 Contributing

When adding new Docker configurations:
1. Follow naming convention: `Dockerfile.<name>` and `docker-compose.<name>.yml`
2. Add comprehensive comments
3. Update this README
4. Create deployment guide in `<NAME>_DEPLOYMENT_GUIDE.md`
5. Test on both bare metal and VM environments

## 📄 License

MIT License - See [../LICENSE](../LICENSE)

---

**Need Help?**
- 📖 Read the full guides linked above
- 🐛 Check troubleshooting sections
- 💬 Open an issue on GitHub
- 📧 Contact: project maintainers

**Quick Links**:
- [Two-Tier Quickstart](../QUICKSTART.md)
- [FC Deployment Guide](FC_DEPLOYMENT_GUIDE.md)
- [Main Documentation](../README.md)
