# 🐳 Docker Deployment Guide - System Monitor

Complete guide for deploying the System Monitor application using Docker containers.

---

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Deployment Methods](#deployment-methods)
- [Usage](#usage)
- [API Endpoints](#api-endpoints)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)

---

## 🔧 Prerequisites

### Required Software

- **Docker Desktop** (Windows/Mac) or **Docker Engine** (Linux)
  - Windows: [Download Docker Desktop](https://www.docker.com/products/docker-desktop)
  - Linux: `sudo apt-get install docker.io docker-compose`
- **Docker Compose** v3.8+

### Verify Installation

```bash
docker --version          # Should show Docker version 20.10+
docker-compose --version  # Should show 1.29.0+
```

---

## 🚀 Quick Start

### Method 2 (Recommended - Bind Mounts)

```bash
# 1. Navigate to project directory
cd "c:\Users\DELL\Desktop\UK MANDEM UK DRILLA\system-monitor-project-Batch"

# 2. Build and start container
docker-compose -f docker-compose.method2.yml up -d

# 3. Access web dashboard
# Open browser: http://localhost:5000

# 4. View logs
docker-compose -f docker-compose.method2.yml logs -f

# 5. Stop when done
docker-compose -f docker-compose.method2.yml down
```

---

## 🎯 Deployment Methods

### **Method 1: Host PID + Privileged Mode**

**Best for:** Direct hardware access, maximum compatibility

**How it works:**
- Container shares host's PID namespace
- Full privileged access to hardware
- Direct access to all host processes

```bash
# Build and start
docker-compose -f docker-compose.method1.yml up -d

# View logs
docker-compose -f docker-compose.method1.yml logs -f

# Stop
docker-compose -f docker-compose.method1.yml down
```

**Pros:**
- ✅ Maximum hardware visibility
- ✅ Easiest configuration
- ✅ Best for development/testing

**Cons:**
- ⚠️ Less secure (full privileged access)
- ⚠️ Container can see all host processes

---

### **Method 2: Bind Mounts (Recommended)**

**Best for:** Production use, better security

**How it works:**
- Mounts specific host directories (`/proc`, `/sys`, `/dev`)
- Read-only access to system information
- More controlled hardware access

```bash
# Build and start
docker-compose -f docker-compose.method2.yml up -d

# View logs
docker-compose -f docker-compose.method2.yml logs -f

# Stop
docker-compose -f docker-compose.method2.yml down
```

**Pros:**
- ✅ Better security (read-only mounts)
- ✅ Controlled access to host resources
- ✅ Recommended for production

**Cons:**
- ⚠️ Slightly more complex configuration
- ⚠️ May need adjustments for different Linux distros

---

## 💻 Usage

### Starting the System

```bash
# Start in background (detached mode)
docker-compose -f docker-compose.method2.yml up -d

# Start with live logs (foreground)
docker-compose -f docker-compose.method2.yml up

# Start and rebuild image
docker-compose -f docker-compose.method2.yml up -d --build
```

### Accessing the Dashboard

Once started, access the web dashboard at:

- **Local Machine:** http://localhost:5000
- **From Network:** http://YOUR_IP_ADDRESS:5000
- **From Phone/Tablet:** http://YOUR_IP_ADDRESS:5000

### Monitoring Logs

```bash
# View all logs
docker-compose -f docker-compose.method2.yml logs

# Follow logs in real-time
docker-compose -f docker-compose.method2.yml logs -f

# View last 100 lines
docker-compose -f docker-compose.method2.yml logs --tail=100

# View logs for specific service
docker-compose -f docker-compose.method2.yml logs system-monitor
```

### Container Management

```bash
# View running containers
docker-compose -f docker-compose.method2.yml ps

# Stop containers
docker-compose -f docker-compose.method2.yml stop

# Start stopped containers
docker-compose -f docker-compose.method2.yml start

# Restart containers
docker-compose -f docker-compose.method2.yml restart

# Stop and remove containers
docker-compose -f docker-compose.method2.yml down

# Stop and remove containers + volumes
docker-compose -f docker-compose.method2.yml down -v
```

### Executing Commands Inside Container

```bash
# Open bash shell
docker-compose -f docker-compose.method2.yml exec system-monitor bash

# Run metrics collection manually
docker-compose -f docker-compose.method2.yml exec system-monitor bash /app/scripts/main_monitor.sh

# Check Python version
docker-compose -f docker-compose.method2.yml exec system-monitor python3 --version

# View current metrics file
docker-compose -f docker-compose.method2.yml exec system-monitor cat /app/data/metrics/current.json

# Check mounted paths
docker-compose -f docker-compose.method2.yml exec system-monitor ls -la /host/proc
```

---

## 🔌 API Endpoints

The system exposes several REST API endpoints:

### Health Check
```bash
GET http://localhost:5000/api/health

# Response:
{
  "status": "healthy",
  "service": "system-monitor-web",
  "timestamp": "2025-12-10T10:30:00Z"
}
```

### Get System Metrics
```bash
GET http://localhost:5000/api/metrics

# Returns: CPU, Memory, Disk, Network, Temperature data
```

### Get Alerts
```bash
GET http://localhost:5000/api/alerts

# Returns: Recent system alerts
```

### Generate Report
```bash
POST http://localhost:5000/api/reports/generate

# Response:
{
  "success": true,
  "message": "Report generated successfully",
  "files": {
    "html": "reports/html/report_20251210_103000.html",
    "markdown": "reports/markdown/report_20251210_103000.md"
  }
}
```

### Test Endpoints with cURL

```bash
# Health check
curl http://localhost:5000/api/health

# Get metrics
curl http://localhost:5000/api/metrics | jq .

# Get alerts
curl http://localhost:5000/api/alerts | jq .

# Generate report
curl -X POST http://localhost:5000/api/reports/generate
```

---

## 🔍 Troubleshooting

### Container Won't Start

```bash
# Check container status
docker-compose -f docker-compose.method2.yml ps

# View detailed logs
docker-compose -f docker-compose.method2.yml logs

# Check Docker daemon
docker info

# Restart Docker Desktop (Windows/Mac)
# Or: sudo systemctl restart docker (Linux)
```

### Port Already in Use

```bash
# Error: "port 5000 is already allocated"

# Option 1: Stop conflicting service
# Windows: netstat -ano | findstr :5000
# Linux: lsof -i :5000

# Option 2: Use different port
# Edit docker-compose file:
ports:
  - "8080:5000"  # Access at http://localhost:8080
```

### No Metrics Showing

```bash
# Check if monitors are running
docker-compose -f docker-compose.method2.yml exec system-monitor bash /app/scripts/main_monitor.sh

# Check host mounts
docker-compose -f docker-compose.method2.yml exec system-monitor ls -la /host/proc

# Check permissions
docker-compose -f docker-compose.method2.yml exec system-monitor ls -la /app/data/metrics/
```

### Container Keeps Restarting

```bash
# View crash logs
docker-compose -f docker-compose.method2.yml logs --tail=100

# Check health status
docker ps -a

# Disable restart policy temporarily
# Edit docker-compose file: restart: "no"
```

### Build Fails

```bash
# Clear Docker cache and rebuild
docker-compose -f docker-compose.method2.yml build --no-cache

# Check disk space
docker system df

# Prune old images/containers
docker system prune -a
```

---

## ⚙️ Advanced Configuration

### Custom Port

Edit `docker-compose.method2.yml`:

```yaml
ports:
  - "8080:5000"  # Change 8080 to your preferred port
```

### Resource Limits

Edit resource limits in `docker-compose.method2.yml`:

```yaml
deploy:
  resources:
    limits:
      cpus: '2.0'      # Max 2 CPU cores
      memory: 1G       # Max 1GB RAM
    reservations:
      cpus: '1.0'      # Guaranteed 1 core
      memory: 512M     # Guaranteed 512MB
```

### Enable Continuous Monitoring

```bash
# Start with continuous monitoring mode
docker-compose -f docker-compose.method2.yml run system-monitor continuous
```

### Environment Variables

Add to `docker-compose.method2.yml`:

```yaml
environment:
  - REFRESH_INTERVAL=10        # Metrics refresh interval (seconds)
  - FLASK_DEBUG=false          # Enable Flask debug mode
  - LOG_LEVEL=INFO             # Logging level
```

### Persistent Data

Data is automatically persisted in:
- `./data/metrics/` - System metrics
- `./data/logs/` - Application logs
- `./data/alerts/` - Alert history
- `./reports/` - Generated reports

These are mounted as volumes and persist across container restarts.

---

## 🗑️ Cleanup

### Remove Containers

```bash
# Stop and remove containers
docker-compose -f docker-compose.method2.yml down

# Remove containers and volumes
docker-compose -f docker-compose.method2.yml down -v
```

### Remove Images

```bash
# List images
docker images | grep system-monitor

# Remove specific image
docker rmi system-monitor:method2

# Remove all unused images
docker image prune -a
```

### Full Cleanup

```bash
# Remove everything (containers, images, volumes, networks)
docker-compose -f docker-compose.method2.yml down -v --rmi all

# Prune Docker system
docker system prune -a --volumes
```

---

## 📊 Performance Tips

1. **Use Method 2** for production (better security)
2. **Enable resource limits** to prevent container from consuming all host resources
3. **Monitor container stats**: `docker stats system-monitor-method2`
4. **Use health checks** to auto-restart on failure
5. **Persistent volumes** for data and logs

---

## 🔐 Security Best Practices

1. ✅ Use Method 2 with read-only mounts
2. ✅ Don't expose dashboard to public internet without authentication
3. ✅ Use firewall rules to restrict access to port 5000
4. ✅ Regularly update base image: `docker-compose build --pull`
5. ✅ Review container logs for suspicious activity

---

## 📞 Support

For issues or questions:
- Check logs: `docker-compose logs -f`
- Review main README.md
- Check Docker documentation: https://docs.docker.com/

---

**🎉 Happy Monitoring!**
