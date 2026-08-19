# SysPlex — Architecture & Engineering Audit

**Date:** 19 Aug 2026
**Scope:** repository structure, code quality, frontend architecture, Docker, CI/CD, infrastructure
**Method:** full static inspection of the working tree at `main` (`0510f5d`), plus running the Python test suite
**Status:** audit complete; target decisions settled (see [Decisions taken](#decisions-taken)). No code changed yet.

> **Read [the solution & end-to-end path](2026-08-19-solution-and-e2e-path.md) first.** It
> reframes the project after the hardware boundary was measured rather than assumed, and it
> changes two recommendations below: the backend becomes **FastAPI, not Flask**
> ([ADR-0010](../adr/0010-backend-framework-fastapi.md)), and agents **push** rather than
> being polled ([ADR-0009](../adr/0009-agents-push-dashboard-receives.md)). Everything else
> in this audit stands as written.

---

## A. Current architecture

SysPlex is a system-monitoring stack built around one genuinely interesting constraint: **a container cannot read host hardware sensors**, so hardware collection is pushed out to agents that run natively on the host, and the container only renders.

There are three tiers and, in practice, four collectors:

| Tier | Component | Runs | Port | Language |
|---|---|---|---|---|
| Collection | Bash monitors (`Host/scripts/*.sh`) driven by `Host/api/server.py` | host, native | 8888 | Bash + FastAPI |
| Collection | Go agent (`Host2/main.go`, gopsutil v3) | host, native | 8889 | Go |
| Collection | PowerShell monitors (`windows/monitors/*.ps1`) | host, native | — | PowerShell |
| Collection | Bash monitors (`scripts/monitors/unix/*.sh`) | **inside the container** | — | Bash |
| Presentation | Flask dashboard (`web/app.py`) | container | 5000 | Python + Jinja |
| Presentation | Rich TUI (`display/tui_dashboard.py`) | host or container | — | Python |

Measured size (tracked files only):

| | Files | Lines |
|---|---|---|
| Markdown | 62 | 19,002 |
| Python | 28 | 6,005 |
| Shell | 47 | 5,189 |
| PowerShell | 30 | 3,880 |
| HTML | 6 | 3,583 |
| CSS | 1 | 986 |
| JavaScript | 1 | 905 |
| Go | 1 | 824 |

Documentation outweighs Python source three to one. That ratio is the audit in one line.

### The data flow, as it actually is

Every collector writes the *same JSON envelope* to a *different file*, and every reader picks a different file:

```
Bash host monitors    ──►  Host/output/latest.json       ──►  Flask "legacy"
Go agent              ──►  Host2/bin/go_latest.json      ──►  Flask "native"
                      └─►  HTTP :8889/metrics            ──►  Flask fallback
PowerShell monitors   ──►  windows/data/metrics/*.json   ──►  (nothing reads this)
Container Bash        ──►  data/metrics/current.json     ──►  Rich TUI only
json_logger.py        ──►  json/<timestamp>.json         ──►  Flask archive fallback
```

Five write locations, three independent readers, and **no shared schema definition anywhere in the repository**.

The important discovery is that the envelope is already effectively standardised. Comparing a live Go payload against a live Bash payload, the shapes match key for key:

```
timestamp, platform, system{os,hostname,uptime_seconds,kernel},
cpu{usage_percent,logical_processors,load_1,load_5,load_15,vendor,model,status},
memory{total_mb,used_mb,free_mb,available_mb,usage_percent,status},
disk[{device,filesystem,total_gb,used_gb,used_percent}],
network[{iface,rx_bytes,tx_bytes}],
temperature{cpu_celsius,cpu_vendor,gpu_celsius,gpu_vendor,status},
gpu{status,count,devices[{vendor,model,utilization_percent,...}]}
```

The Bash agent is a strict superset (it adds `fans` and `smart`); the Go agent adds a `source` discriminator. Two implementations in different languages converged on one contract — that contract simply was never written down or enforced. **Naming and enforcing it is the highest-leverage architectural change available**, and it costs almost nothing because the data already conforms.

### What the dashboard actually is

Worth stating plainly, because it differs from how the README describes it: the single dashboard page is a **symmetric two-column comparison** — Windows host (Go agent) on the left, WSL guest (Bash agent) on the right — with matching CPU / memory / disk / network / GPU / system panels per column, four Chart.js line charts underneath sharing a 60-point rolling window, and a notification drawer. It is a *comparison* tool, not a single-system dashboard. That framing is genuinely distinctive and should survive any redesign.

---

## B. Critical problems

Ordered by severity. Every item below was verified against the tree, not inferred.

### B1 — Path traversal in the report download endpoint 🔴 Critical

[`web/app.py:255`](../web/app.py#L255)

```python
@app.route('/api/reports/download/html/<filename>')
def download_report_html(filename):
    return send_file(REPORTS_DIR / 'html' / filename, as_attachment=True)
```

`filename` reaches the filesystem with no validation or containment check. `GET /api/reports/download/html/..%2f..%2f..%2fetc%2fpasswd` serves arbitrary host files. Textbook CWE-22. This is the only finding that is unambiguously a vulnerability rather than a smell.

### B2 — Unauthenticated command trigger bound to all interfaces 🔴 Critical

[`Host/api/server.py:97`](../Host/api/server.py#L97) exposes `POST /refresh`, which runs `subprocess.run(["bash", str(MONITOR_SCRIPT)])`. The server binds `API_HOST = "0.0.0.0"` with no authentication and no CORS restriction. Any host on the same network can trigger repeated shell execution on the developer's machine. The script path is fixed, so this is not arbitrary RCE — but it is an unauthenticated remote trigger for local process execution, and `0.0.0.0` is the wrong default when the only intended caller is a container on the loopback bridge.

Related, in the same file: the module docstring says `Port: 9999` while the constant is `8888`.

### B3 — 24 MB of build output committed, and `.gitignore` cannot see it 🔴 Critical

```
Host2/bin/host-agent-linux         8,163,151 bytes
Host2/bin/host-agent-windows.exe   8,092,672 bytes
Host2/bin/host-agent-macos         7,932,336 bytes
libs/Newtonsoft.Json.dll             711,952 bytes
libs/LibreHardwareMonitorLib.dll     666,624 bytes
libs/HidSharp.dll                    242,608 bytes
data/logs/system.log                 715,761 bytes
```

`.gitignore` lists `Host2/bin/host2-agent-linux`, `host2-agent-darwin`, `host2-agent.exe`. `Host2/build.sh` produces `host-agent-linux`, `host-agent-macos`, `host-agent-windows.exe`. **The patterns and the filenames have never matched.** Packed history is 21.5 MB for a ~7,000-line project.

`libs/*.dll` also carries a licensing consequence: LibreHardwareMonitor is MPL-2.0, and redistributing the binary attaches attribution obligations that the repo does not currently satisfy. `windows/scripts/setup_libs.ps1` already exists to fetch these — vendoring them was never necessary.

### B4 — Compiled Python bytecode is tracked 🔴 Critical

```
core/__pycache__/{__init__,alert_manager,metrics_collector}.cpython-{310,312}.pyc
display/__pycache__/{__init__,tui_dashboard}.cpython-{310,312}.pyc
```

Ten `.pyc` files, two interpreter versions each, all committed — despite `__pycache__/` and `*.py[cod]` both being in `.gitignore`. Same root cause as B3: the rules were added *after* the files were staged, and `.gitignore` has no effect on already-tracked paths. This one is worse than the binaries in perception terms, because it is the single clearest signal a reviewer has that the repository was never curated.

### B5 — The whole tree is one `git add` away from a 23,000-line diff 🟠 High

`git status` currently reports **78 modified files, 23,037 insertions and 23,037 deletions**. Not one character of content differs. `.gitattributes` was added in commit `748068c` with `* text=auto` and per-type `eol=lf`, but the tree was never renormalised, so every tracked text file is CRLF on disk and LF in the index.

The practical consequence: the next person to `git add -A` produces a commit that touches everything and reviews as nothing. This must be resolved with a single deliberate `git add --renormalize .` commit before any other work starts, or every subsequent diff in this refactor will be unreadable.

### B6 — Dead condition disables a documented feature flag 🟠 High

[`web/app.py:277`](../web/app.py#L277)

```python
if os.getenv('USE_NATIVE_AGENT', 'false').lower() == 'true' or True:  # Try anyway
```

`USE_NATIVE_AGENT` is set in `docker-compose.yml`, reported by `/api/metrics/source`, and reported by nothing that honours it — `or True` makes the branch unconditional. The flag is decorative.

### B7 — Nine bare `except:` blocks, several `except: pass` 🟠 High

Eight in `web/app.py`, one in `web/report_generator.py`. In `get_dual_metrics` and `generate_report` **every** failure path is `except: pass`, so when the dashboard shows no data there is nothing anywhere explaining why. Bare `except:` also swallows `KeyboardInterrupt` and `SystemExit`.

For an observability project this is the most thematically damaging code-quality defect in the repo.

### B8 — Zero test coverage of the code that actually ships 🟠 High

The suite runs clean — `114 passed, 1 skipped in 4.52s`. But it covers `core/metrics_collector.py`, `core/alert_manager.py`, and `display/tui_dashboard.py`: the **TUI** path. There is not one test for `web/app.py`, `web/report_generator.py`, `web/json_logger.py`, or `Host/api/server.py` — the four modules that constitute the deployed application.

So the well-tested component is the one nobody runs, and the untested component is the one that gets demoed. Adding endpoint tests for `web/` is worth more than every other test in the repo combined.

### B9 — `privileged: true` + `pid: host`, by its own admission for nothing 🟠 High

`docker-compose.yml` grants the dashboard container full host privileges and the host PID namespace, alongside `/proc`, `/sys`, and `/dev` mounts. The comment above it reads: *"Note: Dashboard still can't access real GPU/sensors"*.

Maximum privilege, zero benefit — and unnecessary by design, because the host-agent tier already solves hardware access correctly. Dropping it is a pure win, and being able to explain *why* it can be dropped is a better demonstration of understanding the isolation boundary than the flags ever were.

### B10 — No `.dockerignore` at the build context root 🟠 High

`.dockerignore` exists — in `Docker/`, where Docker never looks. The build context root has none, so **every build ships 24 MB of Go binaries, 1.6 MB of DLLs, the 715 KB log, and the entire 22 MB `.git` directory to the daemon**, on top of an `ubuntu:22.04` base with three separate `apt-get update` layers installing `lm-sensors`, `mesa-utils`, `radeontop`, `intel-gpu-tools` and `pciutils` into a container that by design never reads hardware.

### B11 — Flask development server used as the production server 🟠 High

`docker-entrypoint.sh` ends with `exec python3 -m flask --app web.app run`, and the Dockerfile sets `FLASK_ENV=production` while running the single-threaded Werkzeug dev server, which prints a warning on every boot. `dashboard_web.py` additionally exposes `--debug`, which enables the Werkzeug interactive debugger — remote code execution if ever reachable.

### B12 — `docs/` is 51 files including literal `copy 2` duplicates 🟠 High

```
ENHANCEMENT_SUMMARY.md, ENHANCEMENT_SUMMARY copy.md, ENHANCEMENT_SUMMARY copy 2.md
QUICKSTART copy.md, QUICKSTART copy 2.md, QUICKSTART copy 3.md
HTML_INTEGRATION_QUICK_GUIDE.md (+ copy, + copy 2)
```

Plus six overlapping Docker guides, eight further quickstarts (`QUICK_START.md`, `QUICKSTART_GUIDE.md`, `START_MONITORING.md`, `SINGLE_COMMAND_SETUP.md`, `QUICK_COMMANDS.md`, `QUICKSTART_DOCKER.md`, `QUICKSTART_STAGE3.md`, `QUICKSTART_STAGE4.md`), a full set of point-in-time status files (`STAGE3_SUMMARY`, `STAGE4_COMPLETE`, `IMPLEMENTATION_COMPLETE`, `DASHBOARD_FIXES_COMPLETE`, `REFACTORING_SUMMARY`, `REORGANIZATION_SUMMARY`), and two files that are not documents at all — `task.md.resolved` and `test_results.txt`.

Those status files were useful during development. They now work against the project: a visitor who opens `docs/` and reads `QUICKSTART copy 3.md` forms a conclusion about maintenance that carries over to code they never open.

### B13 — Runtime state and backups committed 🟡 Medium

`reports/html/report_2025*.html` ×4, `reports/markdown/*.md` ×4, `data/alerts/alerts.json`, `data/metrics/current.json`, `data/logs/system.log`, `Host/output/latest.json`, `Host2/bin/go_latest.json`, `windows/data/metrics/windows_current.json`, plus `templates/dashboard.html.backup`, `static/css/styles.css.backup`, `Host/scripts/temperature_monitor.sh.backup`. All are matched by existing `.gitignore` rules; all predate them.

Exception: two of these should be *kept and repurposed* as committed demo fixtures — see [F1](#f1--demo-mode).

### B14 — Duplicated and drifted monitor trees 🟡 Medium

`Host/scripts/*.sh` and `scripts/monitors/unix/*.sh` are two copies of the same eight monitors. Verified by diff:

| Monitor | Status |
|---|---|
| `disk_monitor.sh` | byte-identical |
| `fan_monitor.sh` | byte-identical |
| `smart_monitor.sh` | byte-identical |
| `system_monitor.sh` | byte-identical |
| `network_monitor.sh` | 2 lines differ |
| `cpu_monitor.sh` | 18 lines differ |
| `memory_monitor.sh` | 84 lines differ |
| `temperature_monitor.sh` | 240 lines differ |

**Important correction to the attached plan:** it recommends deleting `scripts/monitors/unix/` outright. That would break the container. `scripts/main_monitor.sh` is invoked by `Docker/docker-entrypoint.sh`, is asserted by `tests/docker/test_bash_validation.py`, and branches on `/.dockerenv` to select `temperature_monitor_docker.sh`. The `scripts/` tree is the **container-side** collector; `Host/scripts/` is the **host-side** collector. They are two deployments of one thing, not one thing copied twice.

The correct resolution is therefore not deletion but a decision about whether container-side collection should exist at all — see [Open decisions](#open-decisions) and `adr/0008`.

### B15 — Three parallel launcher/entrypoint sets 🟡 Medium

- Root `docker-entrypoint.sh` (63 lines, the one the Dockerfile copies) **and** `Docker/docker-entrypoint.sh` (120 lines, dead)
- `Docker/README.md`, dead alongside it
- Six root launchers: `start-host-api.sh`, `start-system-monitor.sh`, `start-universal.sh` (**586 lines / 22 KB**), `stop-host-api.sh`, `stop-system-monitor.sh`, plus `Host/quickstart.sh`
- `dashboard_web.py` (92 lines) wrapping `web/app.py`; `dashboard_tui.py` (113 lines) wrapping `display/tui_dashboard.py`

`start-universal.sh` at 586 lines of Bash is the largest shell file in the project and is essentially an installer, a launcher, and a diagnostic tool in one.

### B16 — Frontend: 2 s polling, 20 `innerHTML` sites, unpinned CDNs 🟡 Medium

`static/js/dashboard.js` (905 lines, one flat scope, two separate `DOMContentLoaded` listeners at lines 12 and 419, four module-level chart globals):

- `setInterval(fetchData, 2000)` with no visibility pause, no backoff, no `AbortController`. The Go agent's `UPDATE_INTERVAL` is **60 s**, so roughly 30 of every 31 requests return byte-identical data. An idle tab against an offline agent fires ~43,200 failed requests a day.
- **20** `innerHTML` assignments interpolating hostnames, device names, mount points and interface names. XSS-adjacent, and it destroys and rebuilds DOM subtrees twice a second, which is the flicker source.
- `https://unpkg.com/boxicons@2.1.4/...` is pinned; `https://cdn.jsdelivr.net/npm/chart.js` is **not** — it resolves to whatever is latest, so a Chart.js major release silently breaks the demo. No SRI on either.
- Four `onclick=` attributes in the template; extensive inline `style="..."` in `templates/dashboard.html` alongside a 986-line stylesheet.
- `instantRefresh()` reads the global `event` object rather than taking a parameter.

### B17 — Backend does file I/O on every request 🟡 Medium

`/api/metrics/dual` opens and parses two files per hit; the archive fallback runs `sorted(JSON_DIR.glob('*.json'), key=lambda p: p.stat().st_mtime)` — a full directory listing plus a `stat()` per file, per request. At 2 s polling that is ~43,000 file reads a day for data that changes once a minute. No `ETag`, no `Last-Modified`, no cache.

### B18 — Retention keeps ten minutes of history 🟡 Medium

Credit where due: `web/json_logger.py` prunes correctly and there is no unbounded growth. But `MAX_FILES = 10` at a 60 s interval means the system retains **ten minutes** of history and deletes everything older. That is precisely why the dashboard has no historical view — the data is gone minutes after it is written. `MAX_FILES` is also a hardcoded module constant sitting next to an env-configurable `JSON_LOG_INTERVAL`.

### B19 — Go agent: deprecated stdlib, no configuration, non-atomic writes 🟡 Medium

`Host2/main.go` imports `io/ioutil` (deprecated since Go 1.16) and calls `ioutil.WriteFile`. `UPDATE_INTERVAL` and `PORT` are compile-time constants. There is no `context` cancellation and no signal handling, so `SIGTERM` mid-write leaves a truncated `go_latest.json` — which the Flask side then swallows silently via B7. `go.mod` targets gopsutil **v3**; v4 is current.

### B20 — Dependency hygiene 🟡 Medium

`requirements.txt` is a single 43-line file mixing runtime, test, and lint dependencies: `pytest`, `pytest-cov`, `pytest-mock`, `pytest-asyncio`, `coverage`, `docker`, `black`, `flake8`, `mypy`, `types-requests` all install into the runtime image. `Flask-Cors>=4.0.0` is declared and **never imported anywhere** (verified by grep). `weasyprint>=60.0.0` pulls cairo and pango native libraries for one optional PDF feature. `Host/api/requirements.txt` is a second, partly-overlapping list, and declares `python-json-logger` which is likewise never imported.

### B21 — No CI whatsoever 🟠 High

No `.github/` directory. Twenty-one test files (10 Python, 11 Bash) exist and pass, and nobody browsing the repository can tell.

---

## C. Repository cleanup

### C1 — Remove (verified unreferenced)

| Path | Verification |
|---|---|
| `core/__pycache__/`, `display/__pycache__/` | build output; 10 `.pyc` files |
| `Host2/bin/host-agent-{linux,macos,windows.exe}` | build output of `Host2/build.sh` |
| `libs/*.dll` | fetched by `windows/scripts/setup_libs.ps1`; MPL-2.0 attribution risk |
| `Docker/docker-entrypoint.sh`, `Docker/README.md` | Dockerfile copies the **root** entrypoint; nothing references `Docker/` |
| `templates/dashboard.html.backup`, `static/css/styles.css.backup`, `Host/scripts/temperature_monitor.sh.backup` | `.backup` files |
| `reports/html/*.html`, `reports/markdown/*.md` | runtime output |
| `data/logs/system.log`, `data/alerts/alerts.json`, `windows/data/**` | runtime state |
| `docs/task.md.resolved`, `docs/test_results.txt` | not documents |
| `docs/*STAGE*`, `*_COMPLETE.md`, `*_SUMMARY.md`, `FIXES_IMPLEMENTED.md`, `IMPLEMENTATION_STATUS.md` | point-in-time status files |
| `docs/*copy*.md` (6 files) | literal duplicates |
| `windows/cleanup_and_reorganize.ps1`, `windows/scripts/migrate_powershell_scripts.ps1` | one-off migration scripts, already run |
| `tests/python/verify_stage3.py`, `verify_stage4.py` | file-existence checkers for a completed migration, not tests |

Everything above is removed from tracking; `Host/output/latest.json` and one `data/metrics/*.json` are **retained and relocated** as demo fixtures (see F1).

### C2 — Consolidate

| From | To |
|---|---|
| 51 files in `docs/` | 5: `ARCHITECTURE.md`, `SETUP.md`, `AGENTS.md`, `API.md`, `TROUBLESHOOTING.md` |
| 6 root launchers + `Host/quickstart.sh` | one `Makefile` (or `sysplex.sh {start\|stop\|status}`) |
| `dashboard_web.py`, `dashboard_tui.py` | console entry points, not root wrapper modules |
| `web/app.py` metric-reading logic ×3 | one `collect_metrics()` helper |
| `requirements.txt` (43 lines, mixed) | `requirements.txt` + `requirements-dev.txt` |
| `Host/api/requirements.txt` | folded into the root split |
| `tests/windows/` and `windows/tests/` | one location |

### C3 — Rename

| Current | Proposed | Reason |
|---|---|---|
| `Host/` | `agents/shell/` | "Host" describes where it runs, not what it is; both agents run on the host |
| `Host2/` | `agents/go/` | `Host2` is a sequence number, not a name |
| `windows/` | `agents/powershell/` | same family, same level |
| `scripts/` | *(resolve per ADR-0008)* | currently ambiguous with `Host/scripts/` |
| `web/` | `dashboard/` or `server/` | `web` is vague once a real frontend exists |
| `display/` | `tui/` | `display` is vague; the module is a Rich TUI |
| `json/` | `data/history/` | `json/` names a file format, not a role |
| `system-monitor` (image, container, network names) | `sysplex-*` | the project is called SysPlex; nothing in Docker says so |
| `legacy` / `native` (API keys, JS variables) | `shell` / `go` | "legacy" implies deprecated; both agents are current and interchangeable |
| `win` / `wsl` (frontend state keys) | driven by agent identity | hardcodes one person's machine into the data model |

That last pair matters more than it looks. `previousState = { win: {...}, wsl: {...} }` in `dashboard.js` and the `win-*` / `wsl-*` element IDs across the template bake a specific two-machine setup into the UI. Anyone who runs SysPlex on Linux sees a column labelled "Windows Host".

---

## D. Code quality improvements

Ranked by value, not by size.

1. **Extract one metrics accessor.** `collect_metrics() -> tuple[Metrics | None, Metrics | None, str]` replacing the near-verbatim block repeated in `get_metrics`, `get_dual_metrics` and `generate_report`. Removes ~25% of `web/app.py` and gives the bare-`except` fix a single site.
2. **Define the metrics envelope as a type.** A Pydantic model on the Python side, a Go struct tag audit on the agent side, one JSON Schema as the source of truth, and a generated TypeScript type for the frontend. The data already conforms; this only writes down what is true.
3. **Replace every bare `except:`** with `except (OSError, json.JSONDecodeError, requests.RequestException) as e` + `logger.warning(...)`, and surface the reason in the response payload (`"source": null, "reason": "go agent unreachable"`) so the UI can say something useful instead of rendering dashes.
4. **Split `web/app.py` by responsibility.** Routes, metric access, and report generation are one 306-line module. A `services/` layer holding the agent clients, with routes reduced to request/response handling, is the natural boundary — and it is what makes B8's endpoint tests writable.
5. **Delete `or True`** and honour `USE_NATIVE_AGENT`, or delete the flag entirely. Either is defensible; leaving it is not.
6. **Validate and contain the download path** — `secure_filename()` plus a resolved-path containment check against `REPORTS_DIR`.
7. **Bind `Host/api/server.py` to `127.0.0.1`** by default, with `0.0.0.0` opt-in via env, and document why.
8. **Make retention configurable** and move the time series to SQLite (one table, `(timestamp, source, metric, value)`, rolling window). Smaller on disk than 10 JSON blobs, eliminates the `glob`+`stat` scan in B17, and unlocks the historical view that is currently the dashboard's biggest missing feature.
9. **Modernise the Go agent** — `os.ReadFile`/`os.WriteFile`, write-temp-then-`os.Rename` for atomicity, `signal.NotifyContext`, flags/env for port and interval, gopsutil v4.
10. **Split `requirements.txt`**, drop `Flask-Cors`, make `weasyprint` an optional extra.

---

## E. Frontend / UI architecture

### Current state

One Jinja page, one 905-line script, one 986-line stylesheet, inline styles, inline `onclick`, ID-per-field DOM updates, and a hardcoded two-machine model. There is no build step, no types, no component boundary, and no route other than `/`.

### What the existing functionality actually justifies

The instinct to split a dashboard into many pages should be resisted where the data does not support it. Working from what SysPlex already collects, these views are earned:

| Route | Content | Source data | Justified? |
|---|---|---|---|
| `/` **Overview** | Agent status chips, per-agent CPU/memory/temperature headline, live charts | both agents | Yes — this is the current page, focused |
| `/agents` **Agents** | Agent inventory: which are reachable, last-seen, platform, collector implementation, version, capabilities (does it report `fans`? `smart`?) | `/api/metrics/source` + both agents | **Yes — this is the single most valuable new page.** The whole architectural story is "interchangeable agents"; nothing currently visualises it |
| `/agents/:id` **Agent detail** | One agent's full panel set: CPU, memory, disk table, network interfaces, GPU devices, temperature, fans, SMART | one agent | Yes — replaces the cramped column, and generalises past two machines |
| `/history` **History** | Time-series charts over hours/days, per metric, per agent | SQLite (D8) | Yes, **once D8 lands**. Not before — there is no history to show today |
| `/reports` **Reports** | Generated report list, generate button, download links, preview | `reports/` | Yes — the feature exists and currently has no UI beyond one button |
| `/settings` **Settings** | Agent URLs, poll interval, retention, theme, demo-mode indicator | config | Marginal. Worth one page only once there is more than a theme toggle |

Not justified on current functionality: separate "Infrastructure", "Logs/Events", "Monitoring", and "Configuration" pages. SysPlex collects no logs, has no event stream, and has no configuration beyond a handful of environment variables. Creating those pages would produce empty shells — exactly the "pages for the sake of pages" the brief warns against.

### Recommended structure

```
frontend/
  app/                          # routes
    layout.tsx                  # shell: sidebar nav, header, agent-status chips
    page.tsx                    # /          Overview
    agents/page.tsx             # /agents    inventory
    agents/[id]/page.tsx        # /agents/:id detail
    history/page.tsx            # /history
    reports/page.tsx            # /reports
  components/
    metrics/                    # MetricCard, GaugeRing, UsageBar, TemperatureBadge
    charts/                     # TimeSeriesChart, SparkLine
    agents/                     # AgentCard, AgentStatusChip, AgentCapabilityList
    tables/                     # DiskTable, NetworkTable, GpuTable, SmartTable
    layout/                     # Sidebar, Header, PageHeader, EmptyState
  lib/
    api/                        # typed fetch client, one function per endpoint
    types/                      # generated from the metrics JSON Schema
    hooks/                      # useMetrics (polling + backoff + visibility), useAgents
    format/                     # bytes, percent, duration, temperature
```

The component inventory is small because the panels are genuinely repetitive — `MetricCard` + `UsageBar` + one table component per collection covers most of the current template. That repetition is exactly what the current single-file approach cannot exploit.

### On the polling layer

Whatever the framework, the fetch layer needs three fixes that are independent of it: pause on `document.visibilityState === 'hidden'`, exponential backoff to a 30 s ceiling on consecutive failure with reset on success, and an `AbortController` cancelling the in-flight request before the next starts. Poll at 5 s, not 2 s — the agents only produce data every 60 s.

### On React, TypeScript, and Next.js

React and TypeScript are the right call and the brief settles them. Next.js is a real decision with a real trade-off, and it is **open** — see `adr/0003` and [Open decisions](#open-decisions).

---

## F. Feature recommendations

Only features derivable from what SysPlex already does. Each is scored for whether to build it now, later, or never.

### F1 — Demo mode
- **Purpose:** serve bundled recorded metrics with small deterministic jitter when `DEMO_MODE=true`, so the dashboard is alive with no agent attached.
- **Why relevant:** SysPlex fundamentally cannot read hardware on shared cloud infrastructure. Without this, a deployed demo renders "No metrics available" on every panel and `/api/metrics` returns 503 — a live link to an error page is worse than no link.
- **UI:** a persistent banner: *"Demo mode — replaying recorded metrics. A real deployment reads live hardware through the host agents."* That banner is not an apology; it demonstrates understanding of the architecture's own boundary.
- **Page:** all; global.
- **Backend:** one branch in the metric-source chain, plus two committed fixtures (reuse the existing `Host/output/latest.json` and `Host2/bin/go_latest.json`).
- **Dependencies:** none. **Complexity: Low. Priority: Build now — this is the gate on every deployment item.**

### F2 — Agent inventory & capability view
- **Purpose:** show every configured agent, its reachability, platform, collector implementation, last-seen age, and which metric groups it can report.
- **Why relevant:** the interchangeable-agent design is the project's strongest idea and is currently invisible. It also generalises the UI past the hardcoded two-machine model.
- **UI:** `AgentCard` grid, status chips, capability list, relative last-seen.
- **Page:** `/agents`, `/agents/:id`.
- **Backend:** generalise `/api/metrics/source` into `GET /api/agents` returning a list rather than two booleans.
- **Complexity: Low–Medium. Priority: Build now.**

### F3 — Persistent time series + historical charts
- **Purpose:** SQLite-backed rolling window (7 days), replacing the 10-file/10-minute JSON retention.
- **Why relevant:** the single most valuable thing the dashboard cannot currently do. Also removes the per-request `glob`+`stat` scan (B17) and makes `MAX_FILES` a non-issue.
- **UI:** range selector (1 h / 6 h / 24 h / 7 d), multi-series line charts, per-agent overlay.
- **Page:** `/history`, plus sparklines on `/`.
- **Backend:** one table, one writer in the logger, one range query endpoint.
- **Complexity: Medium. Priority: Build now** — it unblocks `/history` and simplifies two existing problems rather than adding surface.

### F4 — Threshold alerting surfaced in the UI
- **Purpose:** `core/alert_manager.py` already exists, is well tested (548 lines of tests), and is wired only to the TUI. The web dashboard reads `alerts.json` directly and never uses it.
- **Why relevant:** this is consolidation, not a new feature — one alert engine serving both frontends.
- **UI:** the notification drawer already in the template, plus threshold configuration.
- **Page:** `/` drawer; thresholds under `/settings`.
- **Backend:** call the existing module from the Flask layer; add `GET /api/alerts`.
- **Complexity: Low. Priority: Build now** — it deletes a duplication rather than creating one.

### F5 — Agent binaries as GitHub Release assets
- **Purpose:** CI matrix-builds the three Go binaries and publishes them on tag.
- **Why relevant:** closes B3 properly (binaries leave Git and land where reviewers expect them) and enables the best demo this project can have — *"download the agent for your OS, run it, point the hosted dashboard at `localhost:8889`"*. A visitor runs the real stack against the real hardware in under a minute. No cloud deployment can match that.
- **UI:** a Downloads section in the README; optionally a `/settings` panel explaining how to connect a local agent to the hosted demo.
- **Complexity: Low. Priority: Build now.**

### F6 — Agent comparison view
- **Purpose:** formalise what the current two-column layout does — put two agents side by side and show where their readings *disagree*.
- **Why relevant:** two independent implementations reading the same hardware is genuinely interesting, and divergence is a real signal.
- **UI:** agent selector pair, delta column, divergence highlighting.
- **Page:** `/agents/compare`.
- **Complexity: Medium. Priority: Optional** — good, but only after F2 generalises the data model.

### F7 — Report scheduling / email delivery
- **Purpose:** periodic report generation and delivery.
- **Verdict: Do not build.** Requires a scheduler and SMTP configuration, neither of which fits a Vercel demo, and it deepens the `weasyprint` dependency that should instead become optional.

### F8 — Multi-host fleet management, auth, RBAC
- **Verdict: Do not build.** SysPlex is a single-operator tool. User accounts, roles, and a fleet registry would add the largest complexity increase in the entire backlog for a demo nobody logs into.

### F9 — Prometheus `/metrics` exporter
- **Purpose:** expose the agent envelope in Prometheus text format.
- **Verdict: Optional, later.** Cheap to implement (~40 lines) and a credible interoperability signal, but it only pays off alongside a Prometheus/Grafana stack — which [I2](#i2--monitoring--logging-stacks) argues against for this project.

---

## G. Docker review

### What is there

Two services in `docker-compose.yml`, both building the same `ubuntu:22.04` image:
- `dashboard` — Flask on 5000, `privileged: true`, `pid: host`, `/proc` `/sys` `/dev` mounts, 512 MB / 1.0 CPU cap, healthcheck, restart policy, log rotation.
- `json-logger` — the same image running `python3 web/json_logger.py`, mounting `./json` and `./data`, `depends_on: dashboard`.

The compose file is, in isolation, competently written — resource limits, healthcheck, log rotation and a restart policy are all things most hobby compose files omit.

### Keep

- The two-service split. The logger genuinely is a separate long-running concern from the request path.
- Healthcheck, resource limits, log rotation, restart policy.
- `extra_hosts: host.docker.internal:host-gateway` — this is the load-bearing line that makes the whole host-agent architecture work from inside a container, and it is correct.
- `version: '3.8'` can go; Compose v2 ignores it and warns.

### Change

| Item | Now | Target |
|---|---|---|
| Base image | `ubuntu:22.04` + `python3-pip` | `python:3.11-slim` |
| `apt-get` layers | 3 separate `update` layers | 1 layer, `curl` only |
| Hardware packages | `lm-sensors`, `mesa-utils`, `radeontop`, `intel-gpu-tools`, `pciutils` | **none** — the container never reads hardware |
| Layer order | `COPY requirements.txt` then app | correct already; keep, and add `--no-cache-dir` (present) |
| Server | Werkzeug dev server | `gunicorn -w 2 -b 0.0.0.0:5000` |
| User | root | non-root `USER` |
| Privileges | `privileged: true`, `pid: host`, `/proc` `/sys` `/dev` | removed; add `read_only: true`, `cap_drop: [ALL]`, `security_opt: [no-new-privileges:true]` |
| `.dockerignore` | in `Docker/`, never read | at the build context root |
| Image/container/network names | `system-monitor*` | `sysplex*` |
| `weasyprint` | always installed | optional extra |

Expected image size: **~1 GB → ~150 MB**, with a build context measured in KB rather than 48 MB.

### Remove

- The `Docker/` directory entirely (dead entrypoint, dead README, misplaced `.dockerignore`).
- The banner-art `echo` blocks in the Dockerfile — they add layers and noise for no build value.

### Reorganise

Whether `COPY scripts/ ./scripts/` stays depends on whether container-side collection survives — see `adr/0008`. If it does not, that copy, the `chmod` layer, and the whole `scripts/monitors/unix/` tree go with it, and the image loses its last reason to contain Bash monitors at all.

---

## H. CI/CD — recommended quality gates

No production deployment exists, so the pipeline's job is purely **validation**. Proposed `.github/workflows/ci.yml`, five parallel jobs:

| Job | Steps | Gate |
|---|---|---|
| `python` | install `requirements-dev.txt` → `ruff check` → `ruff format --check` → `mypy web/ core/ display/` → `pytest --cov` | lint, format, types, tests |
| `frontend` | `npm ci` → `tsc --noEmit` → `eslint` → `prettier --check` → `npm run build` | types, lint, format, build |
| `shell` | `shellcheck` over `**/*.sh` | shell correctness |
| `go` | `go vet ./...` → `gofmt -l` → `go build ./...` | vet, format, build |
| `docker` | `docker build` → `docker compose config` → boot container → assert `/api/health` responds | image builds and boots |

Plus:
- **`security`** — `pip-audit` and `npm audit --audit-level=high`, non-blocking at first.
- **`release`** (tag-triggered only) — matrix `go build` for linux/darwin/windows, upload as Release assets. This is F5.
- Branch protection on `main` requiring `python`, `frontend`, `shell`, `go`, `docker`.
- Badges in the README, because 21 passing test files that nobody can see are worth nothing.

`shellcheck` deserves particular emphasis: on a project with 47 shell files and 5,189 lines of Bash, it is the highest-signal gate available and it currently does not run at all.

Deliberately **not** included: deployment jobs, container registry pushes, staging environments, or release-please style automation. There is no production target; adding pipeline stages that deploy nowhere is exactly the technology accumulation the brief warns against.

---

## I. Infrastructure evaluation

### I1 — Kubernetes → **No. Not now, not later.**

1. *Problem it would solve:* orchestrating multiple replicas across nodes with rolling updates and service discovery.
2. *Does SysPlex need it?* No. SysPlex is one Flask process and one logger process, and its collection tier is **deliberately outside any orchestrator** — the agents run natively on the host precisely because containers cannot reach the hardware. Kubernetes orchestrates the one tier that needs no orchestration and cannot touch the tier that does the actual work.
3. *Integration:* a Deployment plus Service for the dashboard, and the agents stay exactly where they are — outside the cluster.
4. *Implementation complexity:* Medium. 5. *Design complexity:* High — the host-access boundary would need `hostPath`/DaemonSet contortions that reintroduce the privilege problem B9 removes.
6. *Maintenance:* High. 7. *Benefits:* essentially none at this scale. 8. *Drawbacks:* would make the repository look like it was built to list technologies rather than solve a problem.
9. **Verdict: not at all.** Worth writing down *why* in an ADR — a reasoned "no" reads better than an unused manifest directory.

### I2 — Terraform → **No.**

Terraform provisions cloud resources. The deployment target is a Vercel demo with a Git integration and no infrastructure to declare. There is nothing to provision, so a Terraform module would describe an empty state. **Verdict: not at all.**

### I3 — Docker → **Keep, slimmed.**
Solves the reproducible local dev/test environment, which is a real need already met. Complexity Low, maintenance Low, benefits clear. **Verdict: keep; apply section G.**

### I4 — Docker Compose → **Keep.**
Two services with a dependency and shared config is exactly the shape Compose exists for. **Verdict: keep, cleaned.**

### I5 — CI/CD (GitHub Actions) → **Add now.**
The largest quality gap in the repository. Complexity Low, maintenance Low, benefit high and immediately visible. **Verdict: implement now** — see section H.

### I6 — Infrastructure-as-Code generally → **No.** Same reasoning as I2.

### I7 — Container orchestration (Swarm, Nomad) → **No.** Same reasoning as I1, with less ecosystem.

### I8 — Monitoring & logging stacks (Prometheus, Grafana, Loki, ELK) → **No, with one caveat.**

The irony is real: SysPlex *is* a monitoring tool. Bolting Prometheus and Grafana onto it means running a better monitoring stack next to the one being demonstrated, and immediately raises the question of why the project exists. Structured logging inside the Flask app (which B7's fix introduces anyway) is the appropriate depth here.

*Caveat:* exposing a Prometheus-format `/metrics` endpoint **from** SysPlex (F9) is a different proposition — interoperability rather than dependency, ~40 lines. Optional, later.

### I9 — Object storage / managed database → **No.** SQLite (F3) is correct for a rolling 7-day window on a single node, and it is a file the demo can ship with.

### I10 — Vercel → **Yes, as the demo target.** Zero infrastructure, Git-integrated, free, and the reviewer's click always works. Constraints and consequences in `adr/0004`.

**Summary:** add exactly one technology — GitHub Actions. Keep two — Docker and Compose. Decline five, with recorded reasoning.

---

## J. Target architecture

```
sysplex/
├── agents/                       # collection tier — runs natively on the host
│   ├── shell/                    # was Host/
│   │   ├── monitors/             #   cpu, memory, disk, network, gpu,
│   │   │                         #   temperature, fan, smart, system
│   │   ├── api/                  #   FastAPI server (:8888)
│   │   └── loop/
│   ├── go/                       # was Host2/
│   │   ├── cmd/agent/
│   │   ├── internal/collect/
│   │   └── build.sh              #   → GitHub Release assets, never Git
│   └── powershell/               # was windows/
│       ├── monitors/
│       └── utils/
│
├── contracts/
│   └── metrics.schema.json       # ← the single source of truth
│                                 #   generates: Python (Pydantic),
│                                 #   TypeScript (frontend), Go (verified in CI)
│
├── server/                       # was web/ — presentation backend
│   ├── app.py                    #   routes only
│   ├── services/                 #   agent clients, metric access, cache
│   ├── storage/                  #   SQLite time series
│   ├── reports/                  #   report generation
│   └── models/                   #   Pydantic models from contracts/
│
├── frontend/                     # React + TypeScript
│   ├── app/                      #   / /agents /agents/:id /history /reports
│   ├── components/
│   └── lib/                      #   api client, generated types, hooks
│
├── tui/                          # was display/ + core/ — Rich terminal dashboard
│
├── fixtures/
│   └── demo/                     #   committed recorded metrics for DEMO_MODE
│
├── tests/
│   ├── python/                   #   + endpoint tests for server/ (the B8 gap)
│   ├── shell/
│   └── docker/
│
├── docs/                         # exactly 5 documents
├── plans/                        # this audit and successors
├── adr/                          # architecture decision records
│
├── .github/workflows/ci.yml
├── .dockerignore                 # ← at the root, where Docker looks
├── Dockerfile                    # python:3.11-slim, non-root, gunicorn
├── docker-compose.yml
├── Makefile                      # replaces 6 launcher scripts
├── requirements.txt              # runtime only
├── requirements-dev.txt
└── README.md                     # with a screenshot
```

The load-bearing idea is `contracts/metrics.schema.json`. Today four collectors in three languages independently produce a matching envelope by coincidence and convention. Naming it converts an accident into a designed interface: agents validate against it, the server parses into it, the frontend generates types from it, and CI verifies all three still agree. Nothing else in this plan improves as many things at once.

---

## K. Implementation roadmap

Ordered by impact per unit of effort. Each phase ends in a green build.

### Phase 0 — Stop the bleeding *(half a day, Low)*
1. `git add --renormalize .` as one isolated commit, so every later diff is readable *(B5)*.
2. Fix the `.gitignore` patterns to match the actual filenames *(B3)*.
3. `git rm -r --cached` the binaries, DLLs, `__pycache__`, `.backup` files, generated reports, and runtime state *(B3, B4, B13)*.
4. Add a root `.dockerignore` *(B10)*.

**Note:** steps 2–3 stop *tracking* these files; the 21.5 MB stays in history. Erasing it needs a `git filter-repo` rewrite and a force-push — a destructive, irreversible operation requiring explicit approval. See [Open decisions](#open-decisions).

### Phase 1 — Documentation collapse *(half a day, Low)*
51 files → 5, merging the content worth keeping. The highest perception-change-per-hour in the entire plan *(B12)*.

### Phase 2 — Security & correctness *(1 day, Low)*
Path traversal *(B1)*; bind the host API to loopback *(B2)*; delete `or True` *(B6)*; replace all nine bare excepts with typed handlers and logging *(B7)*; gunicorn and gate `--debug` *(B11)*; drop `privileged`/`pid: host` *(B9)*. Small diffs, each with a clear commit message — this is the phase that reads best in a history.

### Phase 3 — The contract *(1–2 days, Medium)*
Write `contracts/metrics.schema.json` from the two live payloads. Pydantic models in `server/`. Verify both agents against it in CI. This is the foundation the frontend needs.

### Phase 4 — Backend restructure *(2 days, Medium)*
Extract `collect_metrics()` *(D1)*; split routes from services *(D4)*; mtime-keyed cache and `ETag` *(B17)*; SQLite time series with configurable retention *(F3)*; wire `alert_manager` into the web path *(F4)*; **write the missing endpoint tests** *(B8)*.

### Phase 5 — Demo mode *(half a day, Low)*
`DEMO_MODE=true` branch, committed fixtures, banner *(F1)*. Gates everything deployment-related.

### Phase 6 — CI *(1 day, Low)*
The five gates from section H, plus the release matrix *(B21, F5)*. Do this before the frontend work, so the frontend lands under a working gate.

### Phase 7 — Frontend *(4–6 days, High)*
React + TypeScript, the route structure from section E, generated types from Phase 3, and a polling layer with visibility-pause, backoff and abort. Largest single item in the plan, and the one most dependent on the open decisions below.

### Phase 8 — Docker slim *(half a day, Low)*
`python:3.11-slim`, single apt layer, non-root, `sysplex-*` naming, `Docker/` deleted *(section G)*.

### Phase 9 — Agent cleanup *(1–2 days, Medium)*
Directory renames with reference updates *(C3)*; resolve the duplicated monitor trees per `adr/0008` *(B14)*; Go modernisation *(B19)*; collapse the six launchers into a Makefile *(B15)*.

### Phase 10 — Deploy & document *(1 day, Low)*
Vercel demo, README with a screenshot and CI badges, final review pass.

### Complexity summary

| Phase | Complexity | Risk to existing functionality |
|---|---|---|
| 0 Repo hygiene | Low | None |
| 1 Docs | Low | None |
| 2 Security & correctness | Low | Low |
| 3 Contract | Medium | None (additive) |
| 4 Backend restructure | Medium | Medium — mitigated by writing the tests first |
| 5 Demo mode | Low | None (additive) |
| 6 CI | Low | None |
| 7 Frontend | **High** | **High — this is a replacement, not a refactor** |
| 8 Docker | Low | Low |
| 9 Agent cleanup | Medium | Medium — renames touch many references |
| 10 Deploy & docs | Low | None |

---

## Decisions taken

Four decisions were settled on 19 Aug 2026 and are recorded as Accepted ADRs.

1. **Frontend: React + TypeScript + Vite, styled with Tailwind CSS. Flask stays.**
   ([`adr/0003`](../adr/0003-frontend-stack.md)) The demo deploys to Vercel as a static
   bundle; Flask remains the single backend for real use. Rejected Next.js because its
   API routes would mean a second implementation of the same endpoints — exactly the
   duplication this refactor exists to remove. Tailwind replaces the 986-line stylesheet
   and the inline `style` attributes.

2. **Git history is not rewritten.** ([`adr/0007`](../adr/0007-binaries-via-releases.md))
   Build output is untracked going forward; the existing 21.5 MB stays in history so no
   clone, hash or reference breaks. Binaries move to GitHub Release assets.

3. **Container-side metric collection is retired.**
   ([`adr/0008`](../adr/0008-container-side-collection.md)) `scripts/monitors/unix/`,
   `scripts/main_monitor.sh` and `tests/docker/test_bash_validation.py` go;
   `Host/scripts/` becomes the single canonical Bash monitor source; the TUI repoints at
   the shell agent's API. This removes ~700 lines of drifted duplicate Bash and makes
   the architecture consistent with its own claim.

4. **No implementation until the plan is reviewed.** Nothing in the repository has been
   modified. The only additions are this document and the eight ADRs.

### Still open

Two smaller scope questions, neither blocking:

- **Does the Rich TUI stay in scope?** 614 lines of implementation against 958 lines of
  tests, currently the best-tested component in the project and the one with no
  connection to the web path. ADR-0008 repoints its data source, which keeps it viable —
  but whether it earns continued maintenance alongside a real React frontend is worth
  deciding before Phase 9.
- **Does the PowerShell agent stay a third collector,** or become documented as
  Windows-specific support for the shell agent? It writes to
  `windows/data/metrics/windows_current.json`, which nothing currently reads.

### Effect of the decisions on the roadmap

Phase 7 is now scoped as Vite + Tailwind rather than a framework evaluation, which
removes roughly a day. Phase 0 drops the `filter-repo` step. Phase 9's monitor-tree
work is settled in advance rather than needing a decision mid-phase.
