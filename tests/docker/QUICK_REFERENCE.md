# Docker Tests Quick Reference

## 📁 Test Files

| File | Tests | Container | Purpose |
|------|-------|-----------|---------|
| `test_docker_method1.py` | Method 1 Only | `system-monitor-method1` | Privileged mode tests |
| `test_docker_method2.py` | Method 2 Only | `system-monitor-method2` | Bind mounts tests |
| `test_docker_both_methods.py` | Comparison | Both containers | Side-by-side comparison |

---

## 🚀 Quick Commands

### Test Method 1 Only
```powershell
# Start container
docker-compose -f Docker/docker-compose.method1.yml up -d

# Run tests
pytest tests/docker/test_docker_method1.py -v

# Or use marker
pytest tests/docker/ -v -m method1
```

### Test Method 2 Only
```powershell
# Start container
docker-compose -f Docker/docker-compose.method2.yml up -d

# Run tests
pytest tests/docker/test_docker_method2.py -v

# Or use marker
pytest tests/docker/ -v -m method2
```

### Compare Both Methods
```powershell
# Start BOTH containers
docker-compose -f Docker/docker-compose.method1.yml up -d
docker-compose -f Docker/docker-compose.method2.yml up -d

# Run comparison tests
pytest tests/docker/test_docker_both_methods.py -v -s

# Or use marker
pytest tests/docker/ -v -m comparison -s
```

### Run All Tests
```powershell
# Start both containers
docker-compose -f Docker/docker-compose.method1.yml up -d
docker-compose -f Docker/docker-compose.method2.yml up -d

# Run everything
pytest tests/docker/ -v
```

---

## 🏷️ Pytest Markers

Use markers to filter tests:

```powershell
# Method 1 tests only
pytest tests/docker/ -v -m method1

# Method 2 tests only
pytest tests/docker/ -v -m method2

# Comparison tests only
pytest tests/docker/ -v -m comparison

# All Docker tests
pytest tests/docker/ -v -m docker
```

---

## 📊 Test Coverage

### Method 1 Tests (test_docker_method1.py)
- ✅ Privileged mode verification
- ✅ Host PID namespace access
- ✅ Direct process visibility
- ✅ Full hardware access
- ✅ Metrics collection
- ✅ API endpoints

**Total:** ~30 tests

### Method 2 Tests (test_docker_method2.py)
- ✅ Non-privileged verification
- ✅ Bind mount validation
- ✅ Read-only mount security
- ✅ Environment variables
- ✅ /host/* path accessibility
- ✅ Metrics collection
- ✅ Graceful degradation
- ✅ API endpoints

**Total:** ~35 tests

### Comparison Tests (test_docker_both_methods.py)
- ✅ Side-by-side comparison
- ✅ Security analysis
- ✅ Performance benchmarks
- ✅ Process visibility comparison
- ✅ Feature parity validation
- ✅ Method selection guidance

**Total:** ~15 tests

---

## 🔍 Troubleshooting

### Container Not Found
```powershell
# Check running containers
docker ps | Select-String "system-monitor"

# Start missing container
docker-compose -f Docker/docker-compose.method1.yml up -d
# or
docker-compose -f Docker/docker-compose.method2.yml up -d
```

### All Tests Skipped
```powershell
# Verify Docker is running
docker ps

# Rebuild images if needed
docker-compose -f Docker/docker-compose.method1.yml build
docker-compose -f Docker/docker-compose.method2.yml build
```

### Tests Fail with No Metrics
```powershell
# Manually run monitor in container
docker exec system-monitor-method1 /app/scripts/main_monitor.sh
docker exec system-monitor-method2 /app/scripts/main_monitor.sh

# Check metrics file
docker exec system-monitor-method1 cat /app/data/metrics/current.json
docker exec system-monitor-method2 cat /app/data/metrics/current.json
```

---

## 📈 Expected Results

### Method 1 Success Output
```
tests/docker/test_docker_method1.py::TestMethod1DockerBuild::test_image_exists PASSED
tests/docker/test_docker_method1.py::TestMethod1ContainerStartup::test_container_privileged_mode PASSED
tests/docker/test_docker_method1.py::TestMethod1PrivilegedAccess::test_can_access_host_processes PASSED
...
============================== XX passed in XX.XXs ===============================
```

### Method 2 Success Output
```
tests/docker/test_docker_method2.py::TestMethod2DockerBuild::test_image_exists PASSED
tests/docker/test_docker_method2.py::TestMethod2ContainerStartup::test_container_not_privileged PASSED
tests/docker/test_docker_method2.py::TestMethod2BindMountAccess::test_host_proc_accessible PASSED
...
============================== XX passed in XX.XXs ===============================
```

### Comparison Success Output
```
tests/docker/test_docker_both_methods.py::TestBothMethodsComparison::test_both_containers_running PASSED
tests/docker/test_docker_both_methods.py::TestBothMethodsComparison::test_method1_is_privileged PASSED
tests/docker/test_docker_both_methods.py::TestBothMethodsComparison::test_method2_is_not_privileged PASSED
...
============================== XX passed in XX.XXs ===============================
```

---

## 🎯 Common Test Scenarios

### Scenario 1: Test only what I'm developing
```powershell
# Working on Method 2? Test only Method 2
docker-compose -f Docker/docker-compose.method2.yml up -d
pytest tests/docker/test_docker_method2.py -v
```

### Scenario 2: Validate both methods work
```powershell
# Start both and compare
docker-compose -f Docker/docker-compose.method1.yml up -d
docker-compose -f Docker/docker-compose.method2.yml up -d
pytest tests/docker/test_docker_both_methods.py -v -s
```

### Scenario 3: Full test suite for CI/CD
```powershell
# Complete validation
docker-compose -f Docker/docker-compose.method1.yml up -d
docker-compose -f Docker/docker-compose.method2.yml up -d
pytest tests/docker/ -v --tb=short
```

### Scenario 4: Quick sanity check
```powershell
# Test just the basics
pytest tests/docker/test_docker_method2.py::TestMethod2DockerBuild -v
pytest tests/docker/test_docker_method2.py::TestMethod2MetricsCollection -v
```

---

## 📝 Summary

- **3 test files** covering all scenarios
- **~80 total tests** across all files
- **Independent execution** - test each method separately
- **Comparison suite** - validate both methods side-by-side
- **Pytest markers** - filter tests easily with `-m` flag
- **Comprehensive coverage** - build, startup, metrics, API, security
