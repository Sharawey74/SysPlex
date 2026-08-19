<div align="center">

# SysPlex

**Cross-platform hardware telemetry, from the one place that can actually read it.**

[![Go](https://img.shields.io/badge/Go-1.21-00ADD8?style=for-the-badge&logo=go&logoColor=white)](agents/go)
[![Python](https://img.shields.io/badge/Python-3.11-3776AB?style=for-the-badge&logo=python&logoColor=white)](server)
[![Bash](https://img.shields.io/badge/Bash-5.x-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)](agents/bash)
[![PowerShell](https://img.shields.io/badge/PowerShell-7-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](agents/powershell)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white)](docker-compose.yml)

[![Linux](https://img.shields.io/badge/Linux-supported-FCC624?style=flat-square&logo=linux&logoColor=black)](#)
[![Windows](https://img.shields.io/badge/Windows-supported-0078D6?style=flat-square&logo=windows&logoColor=white)](#)
[![macOS](https://img.shields.io/badge/macOS-supported-000000?style=flat-square&logo=apple&logoColor=white)](#)
[![WSL2](https://img.shields.io/badge/WSL2-supported-4EAA25?style=flat-square&logo=linux&logoColor=white)](#)
[![Flask](https://img.shields.io/badge/Flask-3.0-000000?style=flat-square&logo=flask&logoColor=white)](#)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.100-009688?style=flat-square&logo=fastapi&logoColor=white)](#)

</div>

---

## The problem it solves

A dashboard running inside a container cannot read your CPU temperature.

Not because containers are sandboxed — on native Linux a container shares the host kernel and reads `coretemp` through sysfs perfectly well. The wall is **Docker Desktop**, which runs containers inside a Linux VM, and the VM has no thermal sensor to expose. Measured on WSL2:

```console
$ uname -r
6.6.87.2-microsoft-standard-WSL2

$ for h in /sys/class/hwmon/hwmon*; do echo "$h : $(cat $h/name)"; done
/sys/class/hwmon/hwmon0 : AC1      # AC adapter
/sys/class/hwmon/hwmon1 : BAT1     # battery
                                   # no coretemp, no thermal zones

$ grep -c coretemp /proc/modules
0
```

Reading CPU temperature requires ring-0 access to the processor's model-specific registers. Each layer between your code and the silicon either passes that through or does not:

| Layer | MSR access | Why |
|:--|:--:|:--|
| Linux userspace + `coretemp` | ✅ | exposed through sysfs |
| Container | ✅ | shares the host kernel |
| Virtual machine | ❌ | no MSR passthrough to the guest |
| Windows userspace | ❌ | needs a signed kernel driver |

**SysPlex solves it by collecting where the hardware is.** Agents run natively on the machine and expose readings over HTTP; the dashboard renders them and touches no hardware at all — which is why its container needs no privileges.

---

## Architecture

```
        ┌──────────────────────────────────────────────┐
        │  HOST  (native — full hardware access)       │
        │                                              │
        │   agents/go          Go binary      :8889    │
        │   agents/bash        Bash + FastAPI :8888    │
        │   agents/powershell  WMI + LHM              │
        └───────────────────┬──────────────────────────┘
                            │  HTTP  ·  data/metrics/*.json
        ┌───────────────────▼──────────────────────────┐
        │  CONTAINER  (unprivileged — renders only)    │
        │                                              │
        │   server/    Flask API + dashboard   :5000   │
        │   server/collector   background sampling     │
        └──────────────────────────────────────────────┘
```

Every collector emits the **same JSON envelope**, whatever language it is written in:

```jsonc
{
  "timestamp": "…", "platform": "linux",
  "system":      { "os", "hostname", "uptime_seconds", "kernel" },
  "cpu":         { "usage_percent", "logical_processors", "load_1/5/15", "vendor", "model" },
  "memory":      { "total_mb", "used_mb", "available_mb", "usage_percent" },
  "disk":     [  { "device", "filesystem", "total_gb", "used_gb", "used_percent" } ],
  "network":  [  { "iface", "rx_bytes", "tx_bytes" } ],
  "temperature": { "cpu_celsius", "gpu_celsius", "status" },
  "gpu":         { "status", "count", "devices": [ … ] },
  "fans":        { "status", "count", "devices": [ … ] },   // optional
  "smart":       { "status", "count", "devices": [ … ] }    // optional
}
```

`fans`, `smart` and a populated `gpu.devices` are optional — absent hardware reports `status: "unavailable"`, never a fabricated zero.

---

## Quick start

**1 — run an agent on the machine you want to measure** *(natively, not in Docker)*

```bash
cd agents/go && ./build.sh && ./bin/host-agent-linux     # Go, no dependencies
```
```bash
bash agents/bash/monitors/main_monitor.sh                # Bash, needs lm-sensors
```
```powershell
pwsh agents/powershell/scripts/main_monitor.ps1          # Windows, admin for temps
```

**2 — start the dashboard**

```bash
docker compose up -d
```

**3 — open** http://localhost:5000

---

## Agents

| | Language | Port | Platforms | Strength |
|:--|:--|:--:|:--|:--|
| **`agents/go`** | Go + gopsutil | 8889 | Linux · Windows · macOS | one static binary, zero runtime dependencies |
| **`agents/bash`** | Bash + FastAPI | 8888 | Linux · macOS · WSL | widest sensor coverage via `lm-sensors`, `smartctl`, `nvidia-smi` |
| **`agents/powershell`** | PowerShell + WMI | — | Windows | LibreHardwareMonitor for real MSR temperature readings |
| **`agents/container`** | Bash | — | inside Docker | namespace-scoped fallback when no host agent is running |

Run one, or run several and compare — the dashboard renders them side by side.

> **Windows temperatures** need Administrator. WMI's `MSAcpi_ThermalZoneTemperature` returns nothing on most consumer hardware, so the PowerShell agent loads LibreHardwareMonitor, which installs a kernel driver to read MSRs directly.

---

## API

| Method | Endpoint | Returns |
|:--|:--|:--|
| `GET` | `/api/metrics` | latest reading, newest source first |
| `GET` | `/api/metrics/dual` | both agents side by side |
| `GET` | `/api/metrics/native` | Go agent only |
| `GET` | `/api/metrics/source` | which sources are reachable |
| `POST` | `/api/refresh` | force an immediate collection |
| `POST` | `/api/reports/generate` | build an HTML + Markdown report |
| `GET` | `/api/health` | liveness |

Agents expose `/metrics`, `/refresh` and `/health` on their own ports.

---

## Layout

```
agents/
  go/            Go agent — main.go, tests, build.sh
  bash/          monitors/ · api/ · loop/ · service/
  powershell/    monitors/ · scripts/ · utils/
  container/     container-side collectors
server/
  app.py         routes
  metrics.py     parsing          alerts.py    thresholds
  reports.py     HTML + Markdown  collector.py background sampling
  static/  templates/
data/            metrics · history · logs · alerts · reports   (runtime, ignored)
fixtures/demo/   recorded payloads for demo mode
tests/           Python · bash/ · powershell/ · docker/
```

---

## Stack

**Collection** Go 1.21 + gopsutil · Bash + lm-sensors/smartctl · PowerShell + WMI/LibreHardwareMonitor
**Backend** Python 3.11 · Flask 3 (dashboard) · FastAPI (Bash agent API)
**Frontend** Chart.js · vanilla JS
**Runtime** Docker Compose — `cap_drop: ALL`, `no-new-privileges`, no `/proc` `/sys` `/dev` mounts

---

## Development

```bash
pip install -r requirements.txt && python -m pytest tests
```
```bash
cd agents/go && go vet ./... && go test ./...
```
```bash
python -m flask --app server.app run --port 5000     # dashboard, no container
```

---

<div align="center">
<sub>Built by <a href="https://github.com/Sharawey74">Abdelrhman Mohamed</a></sub>
</div>
