# System Monitor Docker Refactoring - Validation Checklist

This checklist validates the complete refactoring of the system monitor project with Docker support, PowerShell script migration, and comprehensive testing.

---

## ✅ Pre-Flight Checks

### Docker Environment
- [ ] Docker Desktop is installed and running
  ```powershell
  docker --version
  docker ps
  ```
  
- [ ] Docker Compose is available
  ```powershell
  docker-compose --version
  ```

### Python Environment
- [ ] Python 3.8+ installed
  ```powershell
  python --version
  ```
  
- [ ] All dependencies installed
  ```powershell
  pip install -r requirements.txt
  ```

- [ ] Verify new Docker dependencies
  ```powershell
  pip list | Select-String "docker|pytest"
  ```
  Expected: `docker>=6.0.0`, `pytest>=7.0.0`, `pytest-timeout>=2.1.0`

---

## ✅ Directory Structure Validation

### Windows Scripts Directory
- [ ] `/windows` directory exists at project root
- [ ] `/windows/scripts` contains main_monitor.ps1
- [ ] `/windows/monitors` contains 8 monitor scripts:
  ```powershell
  Get-ChildItem -Path .\windows\monitors -Filter *.ps1 | Measure-Object | Select-Object -ExpandProperty Count
  ```
  Expected: **8 files**

- [ ] `/windows/utils` contains 3 utility scripts
- [ ] `/windows/tests` contains 12 test scripts
  ```powershell
  Get-ChildItem -Path .\windows\tests -Filter *.ps1 | Measure-Object | Select-Object -ExpandProperty Count
  ```
  Expected: **12 files**

### Docker Test Directory
- [ ] `/tests/docker` directory exists
- [ ] `test_docker_metrics.py` present (500+ lines)
- [ ] `test_bash_validation.py` present (500+ lines)
- [ ] `conftest.py` present
- [ ] `README.md` documentation present

### Bash Scripts (Unchanged)
- [ ] `/scripts/main_monitor.sh` still exists
- [ ] `/scripts/monitors/unix/` contains 8 bash monitors
- [ ] `/scripts/install.sh` present

---

## ✅ Code Path Validation

### Universal.py Path Updates
- [ ] Open `universal.py` and verify line ~37:
  ```python
  WINDOWS_MONITOR = PROJECT_ROOT / "windows" / "scripts" / "main_monitor.ps1"
  ```
  
- [ ] Verify UNIX path unchanged:
  ```python
  UNIX_MONITOR = PROJECT_ROOT / "scripts" / "main_monitor.sh"
  ```

### Execute Universal Launcher
- [ ] Run universal launcher (Windows):
  ```powershell
  python universal.py
  ```
  Expected: Executes PowerShell script from `windows/scripts/main_monitor.ps1`

- [ ] Verify JSON created:
  ```powershell
  Test-Path .\data\metrics\current.json
  ```

- [ ] Validate JSON format:
  ```powershell
  Get-Content .\data\metrics\current.json | ConvertFrom-Json | Select-Object -Property timestamp, platform
  ```

---

## ✅ Docker Build Validation

### Build Docker Image
- [ ] Build Method 2 Docker image:
  ```powershell
  docker-compose -f docker-compose.method2.yml build
  ```
  
- [ ] Verify image created:
  ```powershell
  docker images | Select-String "system-monitor"
  ```
  Expected: `system-monitor:method2`

- [ ] Check image size (should be <500MB):
  ```powershell
  docker images system-monitor --format "{{.Size}}"
  ```

---

## ✅ Docker Container Validation

### Start Container
- [ ] Start container with Method 2:
  ```powershell
  docker-compose -f docker-compose.method2.yml up -d
  ```
  
- [ ] Verify container running:
  ```powershell
  docker ps | Select-String "system-monitor-method2"
  ```

### Volume Mounts
- [ ] Verify /host/proc mounted (read-only):
  ```powershell
  docker inspect system-monitor-method2 | Select-String "/host/proc"
  ```
  
- [ ] Verify /host/sys mounted (read-only):
  ```powershell
  docker inspect system-monitor-method2 | Select-String "/host/sys"
  ```

- [ ] Verify /host/dev mounted (read-only):
  ```powershell
  docker inspect system-monitor-method2 | Select-String "/host/dev"
  ```

---

## ✅ Metrics Collection Validation

### Execute Bash Monitor in Container
- [ ] Run main monitor inside container:
  ```powershell
  docker exec system-monitor-method2 bash /app/scripts/main_monitor.sh
  ```
  
- [ ] Verify JSON created:
  ```powershell
  docker exec system-monitor-method2 test -f /app/data/metrics/current.json
  echo $LASTEXITCODE  # Should be 0
  ```

- [ ] Extract and validate JSON:
  ```powershell
  docker exec system-monitor-method2 cat /app/data/metrics/current.json | ConvertFrom-Json
  ```
  
  Expected fields:
  - `timestamp`
  - `platform` (should be "Linux")
  - `system`
  - `cpu`
  - `memory`
  - `disk`
  - `network`
  - `is_docker` (should be `true`)

### Test Individual Monitors
- [ ] CPU Monitor:
  ```powershell
  docker exec system-monitor-method2 bash /app/scripts/monitors/unix/cpu_monitor.sh
  ```
  
- [ ] Memory Monitor:
  ```powershell
  docker exec system-monitor-method2 bash /app/scripts/monitors/unix/memory_monitor.sh
  ```

- [ ] Disk Monitor:
  ```powershell
  docker exec system-monitor-method2 bash /app/scripts/monitors/unix/disk_monitor.sh
  ```

All should output valid JSON.

---

## ✅ Web Dashboard Validation

### Start Web Dashboard
- [ ] Start web dashboard:
  ```powershell
  docker exec system-monitor-method2 python dashboard_web.py
  ```
  Or run locally:
  ```powershell
  python dashboard_web.py
  ```

### API Endpoints
- [ ] Health check:
  ```powershell
  curl http://localhost:5000/api/health
  ```
  Expected: `{"status": "healthy"}`

- [ ] Metrics endpoint:
  ```powershell
  curl http://localhost:5000/api/metrics
  ```
  Expected: Full JSON metrics

- [ ] Alerts endpoint:
  ```powershell
  curl http://localhost:5000/api/alerts
  ```

### Web UI
- [ ] Open browser: `http://localhost:5000`
- [ ] Verify all panels display correctly:
  - System Info
  - CPU Metrics
  - Memory Metrics
  - Disk Usage
  - Network Stats
  - Recent Alerts

- [ ] Test auto-refresh (wait 3 seconds, verify values update)

---

## ✅ Docker Test Suite Execution

### Install Test Dependencies
- [ ] Install pytest and docker-py:
  ```powershell
  pip install pytest docker pytest-timeout
  ```

### Run All Docker Tests
- [ ] Execute full Docker test suite:
  ```powershell
  pytest tests/docker/ -v --tb=short
  ```
  
  Expected: **All tests pass** (50+ tests)

- [ ] Check for specific test classes:
  ```powershell
  pytest tests/docker/test_docker_metrics.py -v
  ```
  
  Should execute:
  - TestDockerBuild
  - TestContainerStartup
  - TestBashScripts
  - TestMetricsCollection
  - TestSystemMetrics
  - TestToolAvailability
  - TestEnvironmentVariables
  - TestWebAPI
  - TestGracefulDegradation

### Run Bash Validation Tests
- [ ] Execute bash script tests:
  ```powershell
  pytest tests/docker/test_bash_validation.py -v
  ```
  
  Should test all 8 Unix monitors individually:
  - cpu_monitor.sh
  - memory_monitor.sh
  - disk_monitor.sh
  - network_monitor.sh
  - process_monitor.sh
  - temperature_monitor.sh
  - gpu_monitor.sh
  - smart_monitor.sh

### Test Coverage (Optional)
- [ ] Run with coverage:
  ```powershell
  pytest tests/docker/ -v --cov=scripts --cov-report=html
  ```
  
- [ ] Open `htmlcov/index.html` to view coverage report

---

## ✅ Error Handling Validation

### Graceful Degradation
- [ ] Test missing sensors:
  ```powershell
  docker exec system-monitor-method2 bash /app/scripts/monitors/unix/temperature_monitor.sh
  ```
  Expected: Empty array `[]` or minimal data (no crash)

- [ ] Test missing nvidia-smi:
  ```powershell
  docker exec system-monitor-method2 bash /app/scripts/monitors/unix/gpu_monitor.sh
  ```
  Expected: Empty array `[]` (no crash)

- [ ] Test missing smartctl:
  ```powershell
  docker exec system-monitor-method2 bash /app/scripts/monitors/unix/smart_monitor.sh
  ```
  Expected: Empty array `[]` (no crash)

### Invalid Environment Variables
- [ ] Test with invalid HOST_PROC:
  ```powershell
  docker exec -e HOST_PROC=/nonexistent system-monitor-method2 bash /app/scripts/monitors/unix/cpu_monitor.sh
  ```
  Expected: Script completes without error (may return default values)

---

## ✅ Documentation Validation

### README Files
- [ ] Main `README.md` updated with:
  - Windows directory structure
  - Docker test section
  - Updated directory tree

- [ ] `windows/README.md` exists with full documentation

- [ ] `tests/docker/README.md` exists with test instructions

### Docker Documentation
- [ ] `DOCKER_README.md` mentions new PowerShell paths

- [ ] Migration summary documented (28 files migrated)

---

## ✅ Cleanup Validation (After Full Validation)

### Old PowerShell Files
- [ ] **DO NOT REMOVE YET** - Only after all tests pass

Once validated:
- [ ] Remove `scripts/main_monitor.ps1` (old location)
- [ ] Remove `scripts/monitors/windows/` directory
- [ ] Remove `scripts/utils/*.ps1` files (Windows utils)
- [ ] Remove `tests/windows/` directory

Keep only:
- [ ] `scripts/main_monitor.sh` (Unix)
- [ ] `scripts/monitors/unix/` (Bash monitors)
- [ ] `scripts/install.sh`

---

## ✅ Final Integration Test

### End-to-End Workflow
- [ ] **Test 1: Windows Native**
  ```powershell
  python universal.py --dashboard
  ```
  Expected: Launches PowerShell monitors + terminal dashboard

- [ ] **Test 2: Docker Container**
  ```powershell
  docker-compose -f docker-compose.method2.yml up
  ```
  Expected: Container starts, metrics collected, web dashboard accessible

- [ ] **Test 3: Web Dashboard**
  ```powershell
  # In container or locally
  python dashboard_web.py
  # Open http://localhost:5000
  ```
  Expected: Web UI shows real-time metrics

- [ ] **Test 4: Report Generation**
  - Click "Generate Report" in web UI
  - Verify reports created in `reports/html/` and `reports/markdown/`

---

## 🎯 Success Criteria

### Must Pass (Critical)
- ✅ All 28 PowerShell files migrated to `/windows`
- ✅ `universal.py` uses new PowerShell path
- ✅ Docker image builds successfully
- ✅ Docker container starts and collects metrics
- ✅ All 50+ Docker tests pass
- ✅ Web dashboard displays metrics correctly
- ✅ No breaking changes to existing functionality

### Should Pass (Important)
- ✅ Documentation complete and accurate
- ✅ All bash scripts validated in Docker
- ✅ Graceful degradation for missing tools
- ✅ Error handling tests pass

### Nice to Have (Optional)
- ✅ Test coverage >80%
- ✅ Performance benchmarks documented
- ✅ CI/CD pipeline configured

---

## 📊 Test Results Summary

### Migration Results
- **Files Migrated**: 28/28 ✅
- **Errors**: 0 ✅
- **Path Updates**: 1 (universal.py) ✅

### Docker Test Results
```
tests/docker/test_docker_metrics.py::
  - TestDockerBuild: [ ] PASSED / [ ] FAILED
  - TestContainerStartup: [ ] PASSED / [ ] FAILED
  - TestBashScripts: [ ] PASSED / [ ] FAILED
  - TestMetricsCollection: [ ] PASSED / [ ] FAILED
  - TestSystemMetrics: [ ] PASSED / [ ] FAILED
  - TestToolAvailability: [ ] PASSED / [ ] FAILED
  - TestEnvironmentVariables: [ ] PASSED / [ ] FAILED
  - TestWebAPI: [ ] PASSED / [ ] FAILED
  - TestGracefulDegradation: [ ] PASSED / [ ] FAILED

tests/docker/test_bash_validation.py::
  - TestMainMonitor: [ ] PASSED / [ ] FAILED
  - TestCPUMonitor: [ ] PASSED / [ ] FAILED
  - TestMemoryMonitor: [ ] PASSED / [ ] FAILED
  - TestDiskMonitor: [ ] PASSED / [ ] FAILED
  - TestNetworkMonitor: [ ] PASSED / [ ] FAILED
  - TestProcessMonitor: [ ] PASSED / [ ] FAILED
  - TestTemperatureMonitor: [ ] PASSED / [ ] FAILED
  - TestGPUMonitor: [ ] PASSED / [ ] FAILED
  - TestSmartMonitor: [ ] PASSED / [ ] FAILED
  - TestEnvironmentVariables: [ ] PASSED / [ ] FAILED
  - TestErrorHandling: [ ] PASSED / [ ] FAILED
  - TestScriptPermissions: [ ] PASSED / [ ] FAILED
```

### Integration Test Results
- Windows Native: [ ] PASSED / [ ] FAILED
- Docker Container: [ ] PASSED / [ ] FAILED
- Web Dashboard: [ ] PASSED / [ ] FAILED
- Report Generation: [ ] PASSED / [ ] FAILED

---

## 🔧 Troubleshooting

### Docker Not Available
```powershell
# Check Docker service
Get-Service docker

# Restart Docker Desktop
Restart-Service docker
```

### Container Won't Start
```powershell
# Check logs
docker logs system-monitor-method2

# Rebuild image
docker-compose -f docker-compose.method2.yml build --no-cache
```

### Tests Fail with "Container Not Found"
```powershell
# Start container first
docker-compose -f docker-compose.method2.yml up -d

# Wait for container to be ready
Start-Sleep -Seconds 5
```

### PowerShell Scripts Not Found
```powershell
# Verify migration completed
Get-ChildItem -Path .\windows -Recurse -Filter *.ps1

# Re-run migration if needed
.\migrate_powershell_scripts.ps1
```

---

## 📝 Notes

- Complete this checklist **IN ORDER** - some tests depend on previous steps
- Mark each checkbox as you complete the validation
- Document any failures in the "Test Results Summary" section
- Keep this checklist for future reference and CI/CD integration

**Date Completed**: ________________  
**Validated By**: ________________  
**Total Tests Passed**: _____ / _____  
**Status**: [ ] PASS [ ] FAIL (with documented issues)
