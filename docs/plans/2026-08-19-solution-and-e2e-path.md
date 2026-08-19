# SysPlex — The solution, explained end to end

**Date:** 19 Aug 2026
**Purpose:** what SysPlex is, the two problems it ran into, and how one number gets from
the silicon to a chart in a browser.
**Companion documents:** [the audit](2026-08-19-architecture-audit.md) · [the ADRs](../adr/)

---

## Part 1 — What went wrong, in plain terms

SysPlex started as an academic project: a task-manager-style dashboard, built with shell
scripts and Docker, for team collaboration, demonstrating the problem of reading hardware
metrics through Docker. It ran locally only.

Four goals. They don't fit together, and that mismatch is the root of everything else.

| Original goal | What it actually was | What happened |
|---|---|---|
| "Task manager look-alike" | a **UI** goal, not a product goal | the UI got built; the product never got defined |
| "Using scripts" | an academic **constraint** | produced four collectors in three languages |
| "Docker for team collab" | a **requirement** | never materialised — nothing in the code is collaborative |
| "Show the Docker hardware problem" | **the actual subject** | left implicit, never stated |

The fourth one is the project. Everything else is scaffolding around it. It was never
named, so the scaffolding grew without anything to hold it in shape.

### The honest one-line description

> **SysPlex is a cross-platform hardware telemetry agent with an aggregating dashboard,
> built around the problem of hardware access across virtualization boundaries.**

Not a task manager. Naming it correctly resolves most of the architectural confusion by
itself: the dashboard exists to show what agents can see, multiple agent implementations
prove the contract is language-agnostic, and Docker exists to demonstrate the boundary.

---

## Part 2 — Problem one: why CPU temperature doesn't work through Docker

### The short answer

**It's not a container problem. It's a virtual machine problem.**

Containers share the host's kernel — they can see the host's sensors. Virtual machines
don't — they can't. Docker Desktop on Windows and macOS runs your containers **inside a
Linux VM**. So the sensors were never missing because of Docker. They were missing because
of the VM underneath Docker.

### The proof, from this machine

```
$ uname -r
6.6.87.2-microsoft-standard-WSL2

$ for h in /sys/class/hwmon/hwmon*; do echo "$h : $(cat $h/name)"; done
/sys/class/hwmon/hwmon0 : AC1      ← AC adapter
/sys/class/hwmon/hwmon1 : BAT1     ← battery

$ grep -c coretemp /proc/modules
0
```

`scripts/monitors/unix/temperature_monitor_docker.sh` tries four methods — `nvidia-smi`,
`sensors`, `/sys/class/hwmon`, `/sys/class/thermal`. **Every one of them is correct Linux
code.** They all return nothing, because the VM has no CPU temperature sensor to expose.
The battery and the AC adapter are there. The CPU is not.

### The rule

| Where you run | CPU temp readable? | Why |
|---|---|---|
| Linux host → native Docker | **Yes** | container shares the host kernel; `/sys/class/hwmon` shows the real `coretemp` |
| Windows → Docker Desktop | **No** | container is inside a VM with no thermal access |
| macOS → Docker Desktop | **No** | same VM boundary |

### Why Windows is hard even without Docker

Reading CPU temperature means reading **model-specific registers** on the processor, which
requires ring-0 (kernel) privilege. Every layer between your code and the silicon either
passes that through or doesn't:

```
   your code
      │
   ┌──┴───────────────────────────────────────────┐
   │ Windows userspace    ✗  needs a kernel driver │
   │ Linux userspace      ✓  via sysfs             │
   │ Container            ✓  shares the kernel     │
   │ Virtual machine      ✗  no MSR passthrough    │
   └──┬───────────────────────────────────────────┘
      │
   the CPU's model-specific registers
```

Your own code already demonstrates this. `Host2/main.go` asks WMI for
`MSAcpi_ThermalZoneTemperature` — which returns nothing on most consumer hardware, because
it's an ACPI thermal zone that vendors often leave unimplemented. That is exactly why
`libs/LibreHardwareMonitorLib.dll` and `run_as_admin.ps1` exist: LibreHardwareMonitor
installs a **kernel-mode driver** to read those registers directly, and it needs
Administrator to do it.

### What this means for the design

The host-agent architecture **stays** — but for a better reason.

- ~~"Containers can't read hardware"~~ — false on Linux
- **"A native agent is the only thing guaranteed to be on the host side of every
  virtualization boundary, on every platform"** — true everywhere

It's a decision for **portability**, not a workaround for an impossibility. One technique
that works on Linux, Windows and macOS, instead of three techniques where two of them are
"you can't."

Recorded as [ADR-0001](../adr/0001-hardware-access-boundary.md).

---

## Part 3 — Problem two: why it can't be deployed

### The short answer

One line:

```
HOST_API_URL=http://host.docker.internal:8888
```

The dashboard **asks** an agent for data, and assumes that agent is on the same physical
machine. `host.docker.internal` is a Docker Desktop shortcut meaning "the computer this
container is running on." Put the dashboard on a server, and there's nothing at that
address.

### What that one assumption costs

1. **No deployment** — the dashboard can only run on the machine it measures
2. **No multiple machines** — pulling from "this host" can only ever mean one host, which
   is why the collaboration requirement never got built
3. **No laptops or firewalls** — even on a LAN, the dashboard has to be able to reach the
   agent

### The fix: turn the arrow around

```
NOW      dashboard  ──asks for data──►  agent          only works on one machine
FIXED    agent      ──sends data──►     dashboard      works from anywhere
```

Every real tool in this space does it this way — Datadog, Netdata, Zabbix, Grafana Agent.
The agent starts the connection, so it doesn't matter where it is: behind a firewall, on a
laptop, on a different continent.

And it's small. The Go agent already runs an HTTP server and already ticks every 60
seconds. This is **one outbound call inside the tick it already has**, and **one new route**
on the backend.

### What it unlocks

- The dashboard deploys anywhere
- Many machines report to one dashboard — the collaboration requirement, finally delivered
- **The best demo this project can have:** someone downloads your agent, runs it, and
  watches *their own machine* appear on *your hosted dashboard*. That's the real system
  running end to end — not a simulation. And no cloud provider can offer it, precisely
  because Part 2 makes cloud-side collection impossible.

One thing this must not ship without: **a token on the ingest endpoint.** An open endpoint
means anyone can write fake metrics into your dashboard.

Recorded as [ADR-0009](../adr/0009-agents-push-dashboard-receives.md).

---

## Part 4 — The right stack for each layer

| Layer | Today | Target | Why |
|---|---|---|---|
| **Collection** | Bash+FastAPI, Go, PowerShell, container Bash | **Go, one binary** | only genuinely cross-platform option with zero runtime deps — and a single file you can hand someone |
| **Contract** | nothing | **JSON Schema** | it already exists by accident; write it down and enforce it |
| **Transport** | pull from `host.docker.internal` | **agent pushes to `/api/ingest`** | works from anywhere |
| **Backend** | Flask **and** FastAPI | **FastAPI only** | one framework; Pydantic validates the contract; `/docs` for free |
| **Storage** | JSON files, 10 min retention | **SQLite**, 7-day window | one file, real history, removes a per-request directory scan |
| **Frontend** | Jinja + 905-line vanilla JS | **React + TS + Vite + Tailwind** | types, components, a design system instead of 986 lines of ad-hoc CSS |
| **Local env** | Compose (privileged, ~1 GB) | **Compose**, unprivileged, ~150 MB | correct idea, wrong configuration |
| **Distribution** | binaries committed to Git | **GitHub Releases** | where reviewers expect them |
| **Demo** | none | **Vercel static + fixtures** | the link always works |

### Two things changed from what I told you earlier

**Flask → FastAPI.** I originally said keep Flask to avoid a rewrite. Under the
"correct stack per layer" lens, that was wrong: the project *already runs FastAPI* in
`Host/api/server.py`, so keeping Flask means two Python web frameworks for one small
system. FastAPI also brings Pydantic, which is exactly what validating agent payloads at
the ingest endpoint requires. Cost: ~306 lines of routes that need rewriting anyway.
([ADR-0010](../adr/0010-backend-framework-fastapi.md))

**Four collectors → two.** Go becomes the product agent. Bash is kept deliberately as a
**reference implementation** — two independent languages producing the same validated
payload is the clearest possible proof that the contract is real. PowerShell is retired:
3,880 lines that nothing reads. Its LibreHardwareMonitor technique is the one genuinely
valuable thing in it, and that gets folded into the Go agent's Windows path before the tree
is removed. ([ADR-0011](../adr/0011-agent-implementation-scope.md))

---

## Part 5 — End to end: how one number reaches the screen

Following **CPU temperature = 54 °C** from the silicon to a chart.

```
┌─────────────────────────────────────────────────────────────────────────┐
│  1. SILICON                                                             │
│     The CPU's thermal sensor, readable only via model-specific          │
│     registers, which need ring-0 privilege.                             │
└────────────────────────────┬────────────────────────────────────────────┘
                             │
┌────────────────────────────┴────────────────────────────────────────────┐
│  2. OPERATING SYSTEM              ← the boundary from Part 2            │
│     Linux    →  coretemp driver publishes /sys/class/hwmon/…/temp1_input│
│     Windows  →  LibreHardwareMonitor kernel driver (needs Admin)        │
│     macOS    →  SMC via IOKit                                           │
└────────────────────────────┬────────────────────────────────────────────┘
                             │
┌────────────────────────────┴────────────────────────────────────────────┐
│  3. AGENT — runs NATIVELY on the machine, never in a container          │
│     Go binary, one file, no dependencies. Samples every 60 s.           │
│     Produces the envelope defined in contracts/metrics.schema.json:     │
│         { "temperature": { "cpu_celsius": 54, … },  "agent": {…} }      │
└────────────────────────────┬────────────────────────────────────────────┘
                             │  HTTPS POST + bearer token
                             │  (or local pull, in dev)
┌────────────────────────────┴────────────────────────────────────────────┐
│  4. INGEST — POST /api/ingest                                           │
│     FastAPI validates the body against the Pydantic model generated     │
│     from the schema. Invalid payload → 422, and it never reaches        │
│     storage. Stamps a receive time, keyed by agent identity.            │
└────────────────────────────┬────────────────────────────────────────────┘
                             │
┌────────────────────────────┴────────────────────────────────────────────┐
│  5. STORAGE — SQLite                                                    │
│     One row per (agent_id, timestamp, metric, value).                   │
│     Rolling 7-day window, pruned on write.                              │
└────────────────────────────┬────────────────────────────────────────────┘
                             │
┌────────────────────────────┴────────────────────────────────────────────┐
│  6. READ API                                                            │
│     GET /api/agents              → who is reporting, and what they can  │
│                                    measure                              │
│     GET /api/agents/{id}/metrics → that agent's latest envelope         │
│     GET /api/history?range=24h   → time series for the charts           │
│     Responses are typed by the same models. /docs is generated.         │
└────────────────────────────┬────────────────────────────────────────────┘
                             │
┌────────────────────────────┴────────────────────────────────────────────┐
│  7. FRONTEND — React + TypeScript + Vite + Tailwind                     │
│     TS types generated from the SAME schema, so a contract change       │
│     breaks the build instead of the dashboard.                          │
│     useMetrics() polls every 5 s — pauses on hidden tab, backs off to   │
│     30 s on failure, aborts the in-flight request before the next.      │
└────────────────────────────┬────────────────────────────────────────────┘
                             │
┌────────────────────────────┴────────────────────────────────────────────┐
│  8. BROWSER                                                             │
│     <TemperatureBadge value={54} />  →  "54 °C"                         │
└─────────────────────────────────────────────────────────────────────────┘
```

**The thread running through all of it:** `contracts/metrics.schema.json` appears at steps
3, 4, 6 and 7. One definition — the agent produces it, ingest validates it, the API returns
it, the frontend is typed by it. Change it in one place and CI tells you every place that
must follow. Today the same envelope exists four times, implicitly, and has already drifted
by 240 lines in one script.

---

## Part 6 — The same system, three ways to run it

The point of this design is that **only the configuration changes**. Steps 3–8 above are
identical in all three.

### A. Local development — pull mode

```
your machine
├── agent (native, port 8889)  ←── the container asks it for data
└── docker compose up
    ├── backend  :8000   FastAPI
    └── frontend :5173   Vite dev server
```

Simplest path, no token, no network. `docker compose up` plus one agent process. This is
what the project does today, minus the privileged container.

### B. Demo on Vercel — no agent at all

```
Vercel  →  static React bundle + committed fixtures  →  DEMO_MODE banner
```

No backend, no cold start, no agent. The bundle imports recorded real hardware data from
`fixtures/demo/`, with small deterministic jitter so charts move. The banner says plainly:
*"Demo mode — replaying recorded metrics. A real deployment reads live hardware through the
host agents."*

That banner isn't an apology. It states the boundary from Part 2, which is the whole
subject of the project.

### C. Hosted dashboard + your own agent — the real demonstration

```
someone's laptop                          your hosted dashboard
├── downloads sysplex-agent-windows.exe
├── runs it with a demo token       ──push──►  POST /api/ingest
└──                                            their machine appears live
```

This is the full architecture running for real, and it's the strongest thing this project
can show. It only works because of the push inversion in Part 3 — and it's only *necessary*
because of the hardware boundary in Part 2. **The two problems that looked like the
project's biggest weaknesses turn out to be what makes its best demo possible.**

---

## Part 7 — Order of work

Sequenced so nothing breaks and every step ends green. Full detail in
[the audit](2026-08-19-architecture-audit.md), section K.

| # | Step | Effort | Why here |
|---|---|---|---|
| 0 | Git hygiene — renormalise line endings, fix ignore patterns, untrack build output, add `.dockerignore` | ½ day | until this lands, every diff is unreadable |
| 1 | Docs: 51 files → 5 | ½ day | highest perception change per hour |
| 2 | Security & correctness — path traversal, loopback bind, `or True`, nine bare `except:` | 1 day | small diffs, clear commits |
| 3 | **Write `contracts/metrics.schema.json`** | 1 day | everything below depends on it |
| 4 | Backend → FastAPI, with the endpoint tests that don't exist yet | 2–3 days | the contract makes this straightforward |
| 5 | SQLite storage + `/api/history` | 1 day | unlocks real charts |
| 6 | Agent: push mode, atomic writes, Go modernisation | 1–2 days | makes deployment possible |
| 7 | Demo mode + fixtures | ½ day | gates every deployment step |
| 8 | CI: lint, types, tests, shellcheck, go vet, docker build | 1 day | do it **before** the frontend, so the frontend lands under a gate |
| 9 | Frontend: React + TS + Vite + Tailwind | 4–6 days | largest item; types come free from step 3 |
| 10 | Docker slim, agent cleanup, PowerShell retirement | 1–2 days | after the Windows temp technique is ported |
| 11 | Deploy demo, README with screenshot and badges | 1 day | — |

**Step 3 is the hinge.** The schema is a day of work that makes steps 4, 6 and 9 easier
than they would otherwise be, because each one stops guessing at the data's shape.

---

## The one-paragraph version

SysPlex tried to read CPU temperature from inside Docker and couldn't — not because
containers are blind, but because Docker Desktop runs them inside a VM that has no
thermal sensor. The fix is an agent running natively on each machine, which is what the
project already built. Separately, the dashboard can't be deployed anywhere because it
pulls from `host.docker.internal`, meaning "this same computer." The fix is to turn the
arrow around and have agents push instead. Those two changes — a correct explanation of
the boundary, and an inverted data flow — turn a local-only academic project into a
system that runs on any machine, reports to a dashboard hosted anywhere, and can
demonstrate itself on a stranger's laptop in under a minute.
