<div align="center">

<h1>SysPlex</h1>

**Cross-platform observability for real hardware**

<p>
<a href="agents/go"><img src="https://img.shields.io/badge/Go-1.21-00ADD8?style=for-the-badge&logo=go&logoColor=white" alt="Go"></a>
<a href="server"><img src="https://img.shields.io/badge/Python-3.11-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python"></a>
<a href="agents/bash"><img src="https://img.shields.io/badge/Bash-5.x-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" alt="Bash"></a>
<a href="agents/powershell"><img src="https://img.shields.io/badge/PowerShell-7-5391FE?style=for-the-badge&logo=powershell&logoColor=white" alt="PowerShell"></a>
<a href="docker-compose.yml"><img src="https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker"></a>
<a href="https://hub.docker.com/r/sharawey74/system-monitor"><img src="https://img.shields.io/badge/Docker_Hub-published-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker Hub"></a>
</p>

<p>
<img src="https://img.shields.io/badge/Linux-supported-FCC624?style=flat-square&logo=linux&logoColor=black" alt="Linux">
<img src="https://img.shields.io/badge/Windows-supported-0078D6?style=flat-square&logo=windows&logoColor=white" alt="Windows">
<img src="https://img.shields.io/badge/macOS-supported-000000?style=flat-square&logo=apple&logoColor=white" alt="macOS">
<img src="https://img.shields.io/badge/WSL2-supported-4EAA25?style=flat-square&logo=linux&logoColor=white" alt="WSL2">
<img src="https://img.shields.io/badge/Flask-3.0-000000?style=flat-square&logo=flask&logoColor=white" alt="Flask">
<img src="https://img.shields.io/badge/FastAPI-0.100-009688?style=flat-square&logo=fastapi&logoColor=white" alt="FastAPI">
<img src="https://img.shields.io/badge/Chart.js-charts-FF6384?style=flat-square&logo=chartdotjs&logoColor=white" alt="Chart.js">
<img src="https://img.shields.io/badge/NVIDIA-nvidia--smi-76B900?style=flat-square&logo=nvidia&logoColor=white" alt="NVIDIA">
</p>

</div>

---

## Overview

A **cross-platform observability platform** engineered for comprehensive system monitoring across **Windows, Linux, macOS and WSL2**, built on a **dual-agent architecture** that trades off breadth of sensor coverage against deployment simplicity:

<table>
<tr>
<td width="50%" valign="top">

### <img src="https://img.shields.io/badge/-Bash_Host_Agent-4EAA25?style=flat-square&logo=gnubash&logoColor=white" alt="Bash">

Universal monitoring through **native OS tooling** — `lm-sensors`, `smartctl`, `nvidia-smi`, `radeontop`, `intel_gpu_top`. Runs on any Unix-like system, and on Windows through WSL or Git Bash.

**Widest sensor coverage.** The only agent reporting fan tachometers and SMART disk health. Paired with a **PowerShell collector** using WMI and LibreHardwareMonitor for native Windows sensor access.

</td>
<td width="50%" valign="top">

### <img src="https://img.shields.io/badge/-Go_Native_Agent-00ADD8?style=flat-square&logo=go&logoColor=white" alt="Go">

High-performance compiled monitoring built on the **`gopsutil`** library. Cross-compiles to native binaries for Windows, Linux and macOS.

**Zero runtime dependencies.** One static file — no interpreter, no packages, no install step on the monitored machine. Ships as a downloadable release artifact.

</td>
</tr>
</table>

Both agents run **natively on the host**, giving them direct access to physical sensors — CPU and GPU temperatures, fan speeds, SMART health, VRAM utilization — that a containerized collector cannot reach. The **web dashboard runs in Docker** for portability and clean deployment, consuming what the agents publish and touching no hardware itself, which is why its container runs unprivileged.

Run either agent alone, or run both and compare their readings side by side.

---

## Architecture

Two tiers, split along the line where hardware access ends.

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  TIER 1 — COLLECTION                                    runs natively on host ║
║                                                          full sensor access   ║
║   ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐    ║
║   │  Go Native Agent   │  │  Bash Host Agent   │  │  PowerShell        │    ║
║   │  ────────────────  │  │  ────────────────  │  │  ────────────────  │    ║
║   │  gopsutil          │  │  lm-sensors        │  │  WMI / CIM         │    ║
║   │  nvidia-smi        │  │  smartctl          │  │  LibreHardware-    │    ║
║   │  WMI (win)         │  │  nvidia-smi        │  │  Monitor (MSR)     │    ║
║   │                    │  │  radeontop         │  │                    │    ║
║   │  static binary     │  │  FastAPI :8888     │  │  admin required    │    ║
║   │  HTTP :8889        │  │                    │  │  for temperatures  │    ║
║   └─────────┬──────────┘  └─────────┬──────────┘  └─────────┬──────────┘    ║
╚═════════════╪═══════════════════════╪═══════════════════════╪════════════════╝
              │                       │                       │
              └───────────────────────┼───────────────────────┘
                                      │
                    unified JSON envelope · HTTP + file
                                      │
                         host.docker.internal
                                      │
╔═════════════════════════════════════▼════════════════════════════════════════╗
║  TIER 2 — PRESENTATION                             runs in Docker, no privs   ║
║                                                     cap_drop: ALL             ║
║   ┌──────────────────────────────────────────────────────────────────────┐  ║
║   │  server/                                                    :5000    │  ║
║   │  ──────────────────────────────────────────────────────────────────  │  ║
║   │   app.py        REST API + dashboard routes         (Flask)          │  ║
║   │   metrics.py    envelope parsing and normalization                   │  ║
║   │   alerts.py     alert store          thresholds.py  evaluation      │  ║
║   │   reports.py    HTML + Markdown report generation                    │  ║
║   │   collector.py  background sampling → data/history/                  │  ║
║   └──────────────────────────────────────────────────────────────────────┘  ║
║                                      │                                        ║
║   ┌──────────────────────────────────▼───────────────────────────────────┐  ║
║   │  Web dashboard — Chart.js, live polling, side-by-side agent view     │  ║
║   └──────────────────────────────────────────────────────────────────────┘  ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

**Why the split.** Physical sensors are reachable only from a process with host-level access — `/sys/class/hwmon` on Linux, model-specific registers via a kernel driver on Windows, the SMC on macOS. Keeping collection on the host and rendering in the container means the dashboard needs no elevated privileges, no `/proc` `/sys` `/dev` mounts, and no per-platform special-casing.

---

## Metrics

| Group | Fields | Sources |
|:--|:--|:--|
| **System** | OS, hostname, kernel, uptime | `uname`, gopsutil, WMI |
| **CPU** | usage %, logical processors, load 1/5/15, vendor, model | `/proc/stat`, gopsutil, WMI |
| **Memory** | total, used, free, available, usage % | `/proc/meminfo`, gopsutil |
| **Disk** | per-mount device, filesystem, total/used GB, used % | `df`, gopsutil |
| **Network** | per-interface rx/tx bytes | `/proc/net/dev`, gopsutil |
| **Temperature** | CPU °C, GPU °C, vendor | `lm-sensors`, hwmon, `nvidia-smi`, LibreHardwareMonitor |
| **GPU** | per-device model, utilization %, VRAM used/total, temperature | `nvidia-smi`, `radeontop`, `intel_gpu_top`, `lspci` |
| **Fans** | per-sensor label and RPM | hwmon `fan*_input`, `lm-sensors` |
| **SMART** | per-disk health verdict, power-on hours | `smartctl` |

Optional groups report `status: "unavailable"` when the hardware or tooling is absent — never a fabricated zero.

---

## Quick start

### 1 · Start an agent on the machine you want to measure

Agents run **natively**, not in a container — that is what gives them sensor access.

<details open>
<summary><b>Go Native Agent</b> — recommended, no dependencies</summary>

```bash
cd agents/go
./build.sh                      # cross-compiles linux / macos / windows
./bin/host-agent-linux          # serves on :8889
```
</details>

<details>
<summary><b>Bash Host Agent</b> — widest sensor coverage</summary>

```bash
sudo apt install lm-sensors smartutils && sudo sensors-detect --auto

bash agents/bash/monitors/main_monitor.sh     # one-shot collection
bash agents/bash/loop/host_monitor_loop.sh    # continuous
python agents/bash/api/server.py              # REST API on :8888
```
</details>

<details>
<summary><b>PowerShell Agent</b> — native Windows sensors</summary>

```powershell
pwsh agents/powershell/scripts/setup_libs.ps1     # fetch LibreHardwareMonitor
pwsh agents/powershell/scripts/run_as_admin.ps1   # elevation for MSR access
pwsh agents/powershell/scripts/main_monitor.ps1
```
</details>

### 2 · Start the dashboard

```bash
docker compose up -d --build
```

### 3 · Open the dashboard

**http://localhost:5000**

---

## Agent comparison

| | <img src="https://img.shields.io/badge/-Go-00ADD8?style=flat-square&logo=go&logoColor=white"> | <img src="https://img.shields.io/badge/-Bash-4EAA25?style=flat-square&logo=gnubash&logoColor=white"> | <img src="https://img.shields.io/badge/-PowerShell-5391FE?style=flat-square&logo=powershell&logoColor=white"> |
|:--|:--:|:--:|:--:|
| **Port** | `8889` | `8888` | file output |
| **Linux** | ✅ | ✅ | — |
| **macOS** | ✅ | ✅ | — |
| **Windows** | ✅ native | via WSL / Git Bash | ✅ native |
| **Runtime dependencies** | none — static binary | bash, Python, lm-sensors | PowerShell 7, .NET |
| **CPU / memory / disk / network** | ✅ | ✅ | ✅ |
| **CPU + GPU temperature** | ✅ | ✅ | ✅ MSR via kernel driver |
| **Fan speeds (RPM)** | ✅ hwmon | ✅ | ✅ |
| **SMART disk health** | ✅ `smartctl` | ✅ | ✅ |
| **Elevation required** | for SMART | for SMART | for temperatures |
| **Startup** | instant | ~1 s per cycle | ~2 s per cycle |

---

## Unified schema

Every collector emits the same envelope regardless of implementation language, so the dashboard treats them interchangeably:

```jsonc
{
  "timestamp":   "2026-08-19T18:04:11Z",
  "platform":    "linux",
  "system":      { "os", "hostname", "uptime_seconds", "kernel" },
  "cpu":         { "usage_percent", "logical_processors",
                   "load_1", "load_5", "load_15", "vendor", "model", "status" },
  "memory":      { "total_mb", "used_mb", "free_mb", "available_mb", "usage_percent" },
  "disk":     [  { "device", "filesystem", "total_gb", "used_gb", "used_percent" } ],
  "network":  [  { "iface", "rx_bytes", "tx_bytes" } ],
  "temperature": { "cpu_celsius", "cpu_vendor", "gpu_celsius", "gpu_vendor", "status" },
  "gpu":         { "status", "count",
                   "devices": [ { "vendor", "model", "utilization_percent",
                                  "memory_used_mb", "memory_total_mb",
                                  "temperature_celsius" } ] },
  "fans":        { "status", "count", "devices": [ { "label", "rpm" } ] },
  "smart":       { "status", "count",
                   "devices": [ { "device", "health", "power_on_hours" } ] }
}
```

---

## API

### Dashboard — `:5000`

| Method | Endpoint | Description |
|:--|:--|:--|
| `GET` | `/` | Web dashboard |
| `GET` | `/api/metrics` | Latest reading from the highest-priority available source |
| `GET` | `/api/metrics/dual` | Both agents, side by side |
| `GET` | `/api/metrics/native` | Go agent only |
| `GET` | `/api/metrics/source` | Which sources are currently reachable |
| `GET` | `/api/alerts` | Active alerts with counts by level and current thresholds |
| `POST` | `/api/alerts/evaluate` | Re-evaluate thresholds against the latest metrics |
| `POST` | `/api/refresh` | Trigger immediate collection on all agents |
| `POST` | `/api/reports/generate` | Generate an HTML + Markdown system report |
| `GET` | `/api/reports/download/html/<file>` | Download a generated report |
| `GET` | `/api/health` | Liveness probe |

### Agents — `:8888` (Bash) · `:8889` (Go)

| Method | Endpoint | Description |
|:--|:--|:--|
| `GET` | `/metrics` | Current reading as the unified envelope |
| `POST` | `/refresh` | Force an immediate collection cycle |
| `GET` | `/health` | Agent liveness and version |

---

## Configuration

| Variable | Default | Purpose |
|:--|:--|:--|
| `HOST_API_URL` | `http://host.docker.internal:8888` | Bash agent endpoint |
| `NATIVE_AGENT_URL` | `http://host.docker.internal:8889` | Go agent endpoint |
| `USE_NATIVE_AGENT` | `false` | Prefer the Go agent as primary source |
| `JSON_LOGGING_ENABLED` | `true` | Persist samples to `data/history/` |
| `JSON_LOG_INTERVAL` | `60` | Sampling interval, seconds |
| `SYSPLEX_BASH_AGENT_HOST` | `127.0.0.1` | Bind address for the Bash agent API |

### Alert thresholds

Every bound is overridable as `SYSPLEX_THRESHOLD_<METRIC>_<LEVEL>`, so a fanless mini PC
and a workstation need not agree on what a hot CPU is. A malformed value is logged and
ignored rather than stopping collection.

| Metric | Warning | Critical | Evaluated |
|:--|:--:|:--:|:--|
| `CPU` | 80% | 90% | usage percent |
| `MEMORY` | 85% | 95% | usage percent |
| `DISK` | 85% | 95% | per mount |
| `TEMPERATURE` | 75 °C | 90 °C | CPU package |
| `GPU` | 85% | 95% | per device, utilization |
| `GPU_TEMP` | 80 °C | 92 °C | per device |

```bash
SYSPLEX_THRESHOLD_CPU_CRITICAL=95 SYSPLEX_THRESHOLD_TEMPERATURE_WARNING=70 docker compose up -d
```

Thresholds are evaluated on **every collection cycle**, so alerts fire whether or not the
dashboard is open. Only the highest breached level is raised per metric — a CPU at 96%
produces one `critical`, not a `critical` and a `warning`. Sensors reporting
`status: "unavailable"` are skipped entirely: a placeholder zero is not a measurement, and
treating it as one would mean a failing sensor looks healthy.

---

## Project structure

```
agents/
  go/               Go native agent — main.go, main_test.go, build.sh, bin/
  bash/             monitors/ · api/ · loop/ · service/ · quickstart.sh
  powershell/       monitors/ · scripts/ · utils/
  container/        namespace-scoped collectors for in-container fallback

server/
  app.py            REST API and dashboard routes
  metrics.py        envelope parsing and normalization
  alerts.py         alert store and queries
  thresholds.py     threshold evaluation
  reports.py        HTML and Markdown report generation
  collector.py      background sampling into data/history/
  static/           dashboard assets — Chart.js, CSS
  templates/        Jinja templates

data/               metrics · history · logs · alerts · reports    (runtime)
fixtures/demo/      recorded agent payloads for offline demo mode
tests/              Python unit tests · bash/ · powershell/ · docker/
```

---

## Technology stack

| Layer | Technologies |
|:--|:--|
| **Collection** | Go 1.21 + gopsutil · Bash + lm-sensors / smartctl / nvidia-smi · PowerShell 7 + WMI / LibreHardwareMonitor |
| **Agent API** | FastAPI + Uvicorn (Bash agent) · Go `net/http` (native agent) |
| **Backend** | Python 3.11 · Flask 3 · Jinja2 |
| **Frontend** | Chart.js · vanilla JavaScript · CSS custom properties |
| **Runtime** | Docker Compose · `cap_drop: ALL` · `no-new-privileges` · healthchecks · resource limits |
| **Testing** | pytest · `go test` · shell and PowerShell test suites |

---

## Development

```bash
# Python — dashboard and backend
pip install -r requirements.txt
python -m pytest tests
python -m flask --app server.app run --port 5000

# Go — native agent
cd agents/go
go vet ./... && go test ./... && go build ./...

# Shell and PowerShell suites
bash tests/bash/run_all_tests.sh
pwsh tests/powershell/Run-AllTests.ps1
```

---

## Docker image

Published on Docker Hub — pull and run without building:

```bash
docker pull sharawey74/system-monitor:latest
```
```bash
docker run -d -p 5000:5000   --add-host=host.docker.internal:host-gateway   -v "$(pwd)/data:/app/data"   --name sysplex-dashboard   sharawey74/system-monitor:latest
```

<div align="center">

[![Docker Hub](https://img.shields.io/badge/hub.docker.com-sharawey74%2Fsystem--monitor-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://hub.docker.com/r/sharawey74/system-monitor)

[![Image Size](https://img.shields.io/docker/image-size/sharawey74/system-monitor/latest?style=flat-square&logo=docker&logoColor=white&label=image%20size)](https://hub.docker.com/r/sharawey74/system-monitor)
[![Pulls](https://img.shields.io/docker/pulls/sharawey74/system-monitor?style=flat-square&logo=docker&logoColor=white&label=pulls)](https://hub.docker.com/r/sharawey74/system-monitor)
[![Version](https://img.shields.io/docker/v/sharawey74/system-monitor?style=flat-square&logo=docker&logoColor=white&label=version&sort=semver)](https://hub.docker.com/r/sharawey74/system-monitor/tags)

</div>

Remember to start an agent on the host first — the dashboard renders what agents publish.

---

<div align="center">

### Support the project

If SysPlex is useful to you, a star helps others find it.

[![Stars](https://img.shields.io/github/stars/Sharawey74/SysPlex?style=for-the-badge&logo=github&logoColor=white&color=FFD43B&label=Star)](https://github.com/Sharawey74/SysPlex/stargazers)
[![Forks](https://img.shields.io/github/forks/Sharawey74/SysPlex?style=for-the-badge&logo=github&logoColor=white&color=5391FE&label=Fork)](https://github.com/Sharawey74/SysPlex/network/members)

[![Issues](https://img.shields.io/github/issues/Sharawey74/SysPlex?style=flat-square&logo=github&logoColor=white)](https://github.com/Sharawey74/SysPlex/issues)
[![Last Commit](https://img.shields.io/github/last-commit/Sharawey74/SysPlex?style=flat-square&logo=github&logoColor=white)](https://github.com/Sharawey74/SysPlex/commits)
[![Repo Size](https://img.shields.io/github/repo-size/Sharawey74/SysPlex?style=flat-square&logo=github&logoColor=white)](https://github.com/Sharawey74/SysPlex)
[![Top Language](https://img.shields.io/github/languages/top/Sharawey74/SysPlex?style=flat-square&logo=github&logoColor=white)](https://github.com/Sharawey74/SysPlex)
[![Languages](https://img.shields.io/github/languages/count/Sharawey74/SysPlex?style=flat-square&logo=github&logoColor=white&label=languages)](https://github.com/Sharawey74/SysPlex)

<br>

**Issues and pull requests welcome** — new agent implementations, additional sensor
sources and platform coverage are all good places to start.

<br>

<sub>Built by <a href="https://github.com/Sharawey74"><b>Abdelrhman Mohamed</b></a></sub>

<sub><a href="https://github.com/Sharawey74/SysPlex">GitHub</a> · <a href="https://hub.docker.com/r/sharawey74/system-monitor">Docker Hub</a> · <a href="https://github.com/Sharawey74/SysPlex/issues">Report an issue</a></sub>

</div>
