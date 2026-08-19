# 0008 — The future of container-side metric collection

- **Status:** Accepted (19 Aug 2026)
- **Decision:** Option A — retire container-side collection
- **Relates to:** [0001](0001-hardware-access-boundary.md), [0005](0005-docker-scope.md)

## Context

There are two complete copies of the Unix monitor set:

| Monitor | `Host/scripts/` vs `scripts/monitors/unix/` |
|---|---|
| `disk_monitor.sh` | byte-identical |
| `fan_monitor.sh` | byte-identical |
| `smart_monitor.sh` | byte-identical |
| `system_monitor.sh` | byte-identical |
| `network_monitor.sh` | 2 lines differ |
| `cpu_monitor.sh` | 18 lines differ |
| `memory_monitor.sh` | 84 lines differ |
| `temperature_monitor.sh` | **240 lines differ** |

They are not, however, an accident. `scripts/main_monitor.sh` is invoked by
`Docker/docker-entrypoint.sh`, asserted by `tests/docker/test_bash_validation.py`, and
branches on `/.dockerenv` to select a `temperature_monitor_docker.sh` variant. The
`scripts/` tree is the **container-side** collector — it reads `HOST_PROC`, `HOST_SYS`
and `HOST_DEV` from the bind mounts. `Host/scripts/` is the **host-side** collector,
reading real sensors directly.

So this is one component deployed into two environments, not one component copied
twice — and any recommendation to simply delete `scripts/monitors/unix/` (as the
original refactor plan proposed) would break the container and its tests.

Its output also goes nowhere useful: `data/metrics/current.json` is read only by the
Rich TUI. The Flask dashboard never reads it.

## The question

ADR-0001, as corrected, states that a container's hardware visibility depends on the
virtualization boundary beneath it — full on native Linux, none on Docker Desktop for
Windows or macOS. ADR-0005 removes
`privileged`, `pid: host`, the `/proc` `/sys` `/dev` mounts, and the `lm-sensors` and
GPU packages from the image. After that, container-side collection can read essentially
nothing beyond the container's own namespace — which is not what SysPlex claims to report.

## Options

### Option A — Retire container-side collection

Delete `scripts/monitors/unix/`, `scripts/main_monitor.sh`,
`temperature_monitor_docker.sh`, the `COPY scripts/` and `chmod` layers in the
Dockerfile, and `tests/docker/test_bash_validation.py`. `Host/scripts/` becomes the
single canonical Bash monitor source.

- **For:** removes ~700 lines of drifted duplicate Bash and an entire test file. Makes
  the architecture's own claim consistent — if containers cannot see hardware, the
  container should not pretend to collect it. Ends the drift permanently.
- **Against:** `docker compose up` alone then shows nothing until an agent is started
  on the host. The TUI's data source disappears unless it is repointed at an agent.

### Option B — Keep it, narrowed and honest

Keep container-side collection but scope it explicitly to what a container *can* truly
read — CPU, memory, disk, network from the container namespace — and delete the
temperature, fan, GPU and SMART variants that cannot work. Label the output clearly as
container-scoped rather than host-scoped.

- **For:** `docker compose up` gives something immediately. Useful as a fallback and as
  a live illustration of the isolation boundary the project is built around.
- **Against:** keeps a second Bash tree to maintain, and the drift risk with it.
  Requires ADR-0002's contract to model partial payloads properly.

## Decision

**Option A — retire container-side collection**, with the TUI repointed at the
shell agent's API.

The duplication is already causing measurable drift, the output feeds only one consumer
that has a better source available, and keeping it contradicts the architecture's own
central claim. Option B's benefit — something on screen after `docker compose up` — is
better served by ADR-0004's demo mode, which shows real recorded hardware data instead
of a container's view of itself.

## Consequences of Option A

The Dockerfile loses its `scripts/` copy and `chmod` layer entirely, which combines with
ADR-0005 to leave a genuinely minimal Python image. `tests/docker/` shrinks to metric
and health assertions. `data/metrics/current.json` stops being written, so the TUI must
read from the agent API — a change that also fixes the TUI and the web dashboard reading
two different files today, and brings both onto ADR-0002's contract.
