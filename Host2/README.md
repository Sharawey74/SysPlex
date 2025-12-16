# Native Go Host Agent

## Overview
Cross-platform native host monitoring agent written in Go. Provides **real** system metrics on Windows (bypassing WSL2 virtualization), Linux, and macOS.

## Features
- ✅ **True Windows Metrics** - Direct Windows API access (not WSL2)
- ✅ **Cross-Platform** - Single codebase for Windows/Linux/macOS
- ✅ **No PowerShell** - Pure Go implementation
- ✅ **HTTP API** - Compatible with existing dashboard
- ✅ **Lightweight** - Minimal dependencies

## Quick Start

### Prerequisites
- Go 1.21 or higher
- (Optional) NVIDIA drivers for GPU metrics

### Installation

1. **Install Dependencies**
   ```bash
   cd Host2
   go mod download
   ```

2. **Build for Your Platform**
   ```bash
   # Build all platforms
   bash build.sh
   
   # Or build for current platform only
   go build -o host-agent main.go
   ```

3. **Run the Agent**
   ```bash
   # Windows
   bin/host-agent-windows.exe
   
   # Linux
   ./bin/host-agent-linux
   
   # macOS
   ./bin/host-agent-macos
   ```

4. **Verify**
   ```bash
   curl http://localhost:8889/health
   curl http://localhost:8889/metrics
   ```

## API Endpoints

- `GET /` - API information
- `GET /health` - Health check
- `GET /metrics` - System metrics (JSON)

## Metrics Collected

- **System**: OS, hostname, uptime, kernel version
- **CPU**: Usage %, core count, vendor, model
- **Memory**: Total, used, free, available (MB)
- **Disk**: All partitions with usage stats
- **Network**: Interface statistics (RX/TX bytes)
- **GPU**: NVIDIA GPU stats (if available)

## Integration with Dashboard

The agent runs on port **8889** (separate from the legacy Bash system on 8888).

To integrate:
1. Start the agent
2. Update dashboard to fetch from `http://host.docker.internal:8889/metrics`
3. Toggle between legacy (8888) and native (8889) modes

## Validation (Windows)

Compare agent output with Windows Task Manager:
```powershell
# Get metrics
curl http://localhost:8889/metrics | jq .

# Compare with Task Manager:
# - Memory: Should match "In use" value
# - CPU: Should match overall CPU %
# - Disk: Should match C: drive usage
```

## Architecture

```
┌─────────────────────────────────────┐
│   Windows/Linux/macOS Host          │
│                                     │
│  ┌──────────────────────────────┐  │
│  │  Go Agent (Port 8889)        │  │
│  │  - gopsutil library          │  │
│  │  - Native OS APIs            │  │
│  │  - HTTP JSON Server          │  │
│  └──────────────────────────────┘  │
│              │                      │
└──────────────┼──────────────────────┘
               │ HTTP
               ▼
      ┌─────────────────┐
      │ Docker Container│
      │   Dashboard     │
      └─────────────────┘
```

## Troubleshooting

### Port 8889 Already in Use
```bash
# Find process using port
netstat -ano | findstr :8889  # Windows
lsof -i :8889                 # Linux/macOS

# Kill the process or change PORT in main.go
```

### GPU Not Detected
- Ensure `nvidia-smi` is in PATH
- Install NVIDIA drivers
- GPU metrics are optional

### Build Errors
```bash
# Clean and rebuild
go clean
go mod tidy
go build -v main.go
```
