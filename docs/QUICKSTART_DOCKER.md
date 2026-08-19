# Quick Start Guide - Docker Refactoring

This guide will get you up and running with the newly refactored system monitor project in under 5 minutes.

---

## Prerequisites Check

Before starting, ensure you have:
- ✅ Docker Desktop installed and running
- ✅ Python 3.8 or higher
- ✅ PowerShell 5.1+ (Windows) or Bash (Linux/macOS)

---

## Step 1: Install Dependencies (2 minutes)

```powershell
# Navigate to project directory
cd "c:\Users\DELL\Desktop\UK MANDEM UK DRILLA\system-monitor-project-Batch"

# Install all Python dependencies including Docker SDK
pip install -r requirements.txt

# Verify installation
pip list | Select-String "docker|pytest|Flask"
```

**Expected output:**
```
docker          6.0.0 (or higher)
Flask           3.0.0 (or higher)
pytest          7.0.0 (or higher)
pytest-timeout  2.1.0 (or higher)
```

---

## Step 2: Verify Migration (30 seconds)

```powershell
# Check PowerShell files migrated
Get-ChildItem -Path .\windows -Recurse -Filter *.ps1 | Measure-Object

# Expected output: Count : 28

# Verify universal.py updated
Select-String -Path .\universal.py -Pattern "windows/scripts"

# Expected output: Line 37 with path to windows/scripts/main_monitor.ps1
```

---

## Step 3: Build Docker Image (1 minute)

```powershell
# Build the Docker image
docker-compose -f docker-compose.method2.yml build

# Verify image created
docker images system-monitor

# Expected output:
# REPOSITORY        TAG       IMAGE ID       SIZE
# system-monitor    method2   <image-id>     ~400MB
```

---

## Step 4: Start Container (30 seconds)

```powershell
# Start the container
docker-compose -f docker-compose.method2.yml up -d

# Verify container running
docker ps | Select-String "system-monitor"

# Check container health
docker logs system-monitor-method2 --tail 20
```

---

## Step 5: Run Docker Tests (1 minute)

```powershell
# Run all Docker tests
pytest tests/docker/ -v --tb=short

# Or run specific test suites
pytest tests/docker/test_docker_metrics.py -v        # Container & metrics tests
pytest tests/docker/test_bash_validation.py -v       # Bash script tests
```

**Expected output:**
```
tests/docker/test_docker_metrics.py::TestDockerBuild::test_image_exists PASSED
tests/docker/test_docker_metrics.py::TestContainerStartup::test_container_running PASSED
...
==================== XX passed in X.XXs ====================
```

---

## Step 6: Test Metrics Collection (30 seconds)

```powershell
# Execute monitoring inside container
docker exec system-monitor-method2 bash /app/scripts/main_monitor.sh

# Verify JSON created
docker exec system-monitor-method2 cat /app/data/metrics/current.json

# Should output valid JSON with system metrics
```

---

## Step 7: Start Web Dashboard (30 seconds)

```powershell
# Start web dashboard (in container or locally)
python dashboard_web.py

# Or if running in container:
docker exec -d system-monitor-method2 python dashboard_web.py
```

**Open browser**: http://localhost:5000

You should see:
- System information panel
- CPU metrics with usage graphs
- Memory usage
- Disk usage
- Network statistics
- Recent alerts

---

## Alternative: Native Windows Execution

If you want to run natively on Windows instead of Docker:

```powershell
# Run Windows PowerShell monitors
python universal.py

# View metrics in terminal dashboard
python dashboard_tui.py

# Or start web dashboard
python dashboard_web.py
```

---

## Troubleshooting

### Issue: "Docker is not running"
```powershell
# Start Docker Desktop
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"

# Wait 30 seconds, then verify
docker ps
```

### Issue: "Import docker could not be resolved"
```powershell
# Install docker SDK
pip install docker>=6.0.0

# Verify installation
python -c "import docker; print(docker.__version__)"
```

### Issue: "Container not found"
```powershell
# Check if container exists but stopped
docker ps -a | Select-String "system-monitor"

# Start it
docker start system-monitor-method2

# Or recreate it
docker-compose -f docker-compose.method2.yml up -d
```

### Issue: "Tests fail with connection error"
```powershell
# Check Docker socket accessible
docker info

# Restart Docker service (Windows)
Restart-Service docker

# Or restart Docker Desktop
```

### Issue: "Port 5000 already in use"
```powershell
# Use different port
python dashboard_web.py --port 8080

# Or find what's using port 5000
Get-NetTCPConnection -LocalPort 5000
```

---

## Verification Checklist

Quick validation to ensure everything works:

- [ ] `pip list` shows docker>=6.0.0
- [ ] `docker images` shows system-monitor:method2
- [ ] `docker ps` shows system-monitor-method2 running
- [ ] `pytest tests/docker/ -v` all tests pass
- [ ] `docker exec system-monitor-method2 bash /app/scripts/main_monitor.sh` creates JSON
- [ ] `http://localhost:5000` shows web dashboard
- [ ] Web dashboard auto-refreshes every 3 seconds
- [ ] `python universal.py` runs Windows monitors natively

---

## What's New After Refactoring?

### Directory Changes
- ✅ All PowerShell scripts moved to `/windows` directory
- ✅ Clear separation of Windows (PowerShell) and Unix (Bash) code
- ✅ Organized structure: scripts/, monitors/, utils/, tests/

### Testing Improvements
- ✅ 79 new Docker-specific tests
- ✅ Comprehensive bash script validation
- ✅ Container health and metrics tests
- ✅ API endpoint testing
- ✅ Graceful degradation tests

### Documentation
- ✅ 6 new/updated documentation files
- ✅ Validation checklist with 50+ checks
- ✅ Comprehensive refactoring summary
- ✅ Test documentation with examples

---

## Next Steps

### Immediate
1. ✅ Complete this quick start guide
2. ⏳ Run full validation checklist (see `VALIDATION_CHECKLIST.md`)
3. ⏳ Review test results and fix any failures
4. ⏳ Clean up old PowerShell files after validation

### Later
1. Set up CI/CD pipeline for automated testing
2. Add more integration tests
3. Implement alerting in Docker environment
4. Create Kubernetes deployment configs

---

## Getting Help

If you encounter issues:

1. **Check documentation**:
   - `VALIDATION_CHECKLIST.md` - Comprehensive validation steps
   - `REFACTORING_SUMMARY.md` - Detailed refactoring overview
   - `tests/docker/README.md` - Docker testing guide
   - `windows/README.md` - Windows scripts documentation

2. **Check logs**:
   ```powershell
   # Container logs
   docker logs system-monitor-method2
   
   # Application logs
   Get-Content .\data\logs\system.log -Tail 50
   ```

3. **Verify environment**:
   ```powershell
   # Check Docker
   docker version
   docker ps
   
   # Check Python
   python --version
   pip list
   
   # Check PowerShell
   $PSVersionTable.PSVersion
   ```

---

## Summary

You've successfully set up the refactored system monitor project with:
- ✅ Docker containerization
- ✅ Comprehensive testing (79 tests)
- ✅ Organized directory structure
- ✅ Cross-platform support
- ✅ Web dashboard with API

**Total setup time**: ~5 minutes  
**What's running**: Docker container with system monitoring and web dashboard  
**What's tested**: 79 Docker tests validating all functionality  
**What's documented**: 6 comprehensive documentation files  

🎉 **Congratulations! You're ready to monitor your system.**

---

**Quick Reference**:
- Web UI: http://localhost:5000
- API Health: http://localhost:5000/api/health
- API Metrics: http://localhost:5000/api/metrics
- Container: `docker exec -it system-monitor-method2 bash`
- Tests: `pytest tests/docker/ -v`
