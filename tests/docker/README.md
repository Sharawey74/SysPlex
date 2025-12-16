# Docker Tests - System Monitor

This directory contains Docker integration tests for the System Monitor project.

## Architecture

The System Monitor uses a **Two-Tier Architecture**:

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

**Why Two-Tier?**
- Native scripts access real hardware (CPU/GPU temps, sensors)
- Docker provides isolated, portable dashboard
- Host API bridges the gap via HTTP

## Test Files

### Current Tests

| File | Description | Status |
|------|-------------|--------|
| `test_docker_metrics.py` | Tests Docker container metrics collection | ✅ Active |

### Test Strategy

Tests verify:
1. **Container Health**: Dashboard container starts and responds
2. **Host API Integration**: Dashboard can reach Host API at `host.docker.internal:8888`
3. **Metrics Flow**: Data flows from Host → API → Dashboard → Web UI
4. **Resource Limits**: Container respects CPU/memory limits
5. **Volume Mounts**: Data persistence in `/app/data` and `/app/reports`

## Running Tests

### Prerequisites

```bash
# Start the system first
bash start-system-monitor.sh

# Verify both components running
curl http://localhost:8888/health  # Host API
curl http://localhost:5000/api/health  # Dashboard
```

### Run All Tests

```bash
# From project root
pytest tests/docker/ -v

# With coverage
pytest tests/docker/ -v --cov=web --cov=core

# Specific test
pytest tests/docker/test_docker_metrics.py::test_container_health -v
```

### Quick Manual Test

```bash
# 1. Check Dashboard container
docker ps | grep system-monitor-dashboard

# 2. Test Dashboard health
curl http://localhost:5000/api/health

# 3. Test Host API connection from container
docker exec system-monitor-dashboard curl http://host.docker.internal:8888/health

# 4. Check logs
docker-compose logs dashboard
```

## Docker Configuration

### docker-compose.yml

Current deployment configuration:
- **Port**: 5000 (dashboard)
- **Privileged**: Yes (for host process visibility)
- **PID Namespace**: Host (to see host processes)
- **Host API URL**: `http://host.docker.internal:8888`
- **Resource Limits**: 512MB RAM, 1.0 CPU

### Dockerfile

Main dashboard container:
- **Base**: Ubuntu 22.04
- **Python**: 3.x
- **Dependencies**: Flask, Rich, psutil
- **Workdir**: `/app`
- **Entrypoint**: Flask web server

## Testing Best Practices

### 1. Test Isolation
Each test should:
- Start with known container state
- Clean up after completion
- Not depend on other tests

### 2. Integration Testing
Tests validate:
- Dashboard ↔ Host API communication
- HTTP endpoints return valid JSON
- Container networking works correctly

### 3. Performance Testing
Monitor:
- Container startup time (< 30s expected)
- Health check response time (< 2s expected)
- Memory usage stays within limits

### 4. Error Handling
Test scenarios:
- Host API unavailable (dashboard should fallback)
- Network issues (retries, timeouts)
- Resource exhaustion (OOM handling)

## Common Issues

### Issue: Dashboard can't reach Host API

**Symptoms:**
```bash
curl http://localhost:5000/api/metrics
# Returns container metrics only, not real hardware
```

**Fix:**
```bash
# 1. Check Host API is running
curl http://localhost:8888/health

# 2. Test from inside container
docker exec system-monitor-dashboard curl http://host.docker.internal:8888/health

# 3. Restart both components
bash stop-system-monitor.sh
bash start-system-monitor.sh
```

### Issue: Container won't start

**Symptoms:**
```bash
docker-compose up -d
# ERROR: Container exits immediately
```

**Debug:**
```bash
# Check logs
docker-compose logs dashboard

# Check container status
docker ps -a | grep system-monitor

# Rebuild
docker-compose down
docker-compose up --build -d
```

### Issue: Tests fail on CI/CD

**Common causes:**
- Docker not available
- Ports already in use (5000, 8888)
- Insufficient permissions for privileged containers

**Solutions:**
```bash
# Check Docker service
docker info

# Check port availability
netstat -tuln | grep -E '5000|8888'

# Run Docker daemon with privileged support
# (varies by CI platform)
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Docker Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10'
      
      - name: Install dependencies
        run: |
          pip install pytest pytest-docker fastapi uvicorn
      
      - name: Start Host API
        run: |
          cd Host/scripts && bash main_monitor.sh
          cd ../api && python3 server.py &
          sleep 5
      
      - name: Start Dashboard
        run: |
          docker-compose up -d
          sleep 10
      
      - name: Run tests
        run: pytest tests/docker/ -v
      
      - name: Cleanup
        if: always()
        run: |
          docker-compose down
          pkill -f "python3 server.py"
```

## Troubleshooting Test Failures

### Test: `test_container_health`

**Failure**: Container not responding

**Checks**:
```bash
docker ps  # Is container running?
docker logs system-monitor-dashboard  # Any errors?
docker inspect system-monitor-dashboard  # Check config
```

### Test: `test_host_api_connection`

**Failure**: Can't reach `host.docker.internal:8888`

**Checks**:
```bash
# From host
curl http://localhost:8888/health

# From container
docker exec system-monitor-dashboard curl http://host.docker.internal:8888/health

# Check networking
docker network inspect system-monitor-network
```

### Test: `test_metrics_endpoint`

**Failure**: Invalid JSON or missing fields

**Checks**:
```bash
# Test endpoint directly
curl http://localhost:5000/api/metrics | jq

# Check data directory
ls -la data/metrics/

# Validate JSON format
cat data/metrics/current.json | jq
```

## Adding New Tests

### Template for Docker Test

```python
import pytest
import requests
import time

def test_new_feature():
    """Test description."""
    # Arrange
    url = "http://localhost:5000/api/endpoint"
    
    # Act
    response = requests.get(url, timeout=5)
    
    # Assert
    assert response.status_code == 200
    data = response.json()
    assert "expected_field" in data
```

### Test Naming Convention

- `test_container_*`: Container lifecycle tests
- `test_api_*`: API endpoint tests
- `test_integration_*`: Multi-component tests
- `test_performance_*`: Load/stress tests

## References

- [Main README](../../README.md)
- [Quick Start Guide](../../QUICKSTART.md)
- [Dockerfile](../../Dockerfile)
- [docker-compose.yml](../../docker-compose.yml)

---

**Last Updated**: December 2025  
**Architecture**: Two-Tier (Host API + Docker Dashboard)
