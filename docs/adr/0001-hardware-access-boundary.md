# 0001 — The hardware access boundary, and why agents run natively

- **Status:** Accepted (19 Aug 2026)
- **Supersedes:** the original, unwritten premise that *"containers cannot read host hardware"*
- **Relates to:** [0002](0002-single-metrics-contract.md), [0008](0008-container-side-collection.md), [0011](0011-agent-implementation-scope.md)

## Context

SysPlex reports hardware telemetry — CPU temperature above all. The project was built on
the belief that a container cannot read host sensors, and that belief drove the entire
architecture.

**That belief is half wrong, and the wrong half is the important one.**

### What was measured

Run on the development machine (Windows 11 + WSL2 — the same kernel Docker Desktop
containers execute on):

```
$ uname -r
6.6.87.2-microsoft-standard-WSL2

$ for h in /sys/class/hwmon/hwmon*; do echo "$h : $(cat $h/name)"; done
/sys/class/hwmon/hwmon0 : AC1      ← AC adapter
/sys/class/hwmon/hwmon1 : BAT1     ← battery

$ ls /sys/class/thermal/
cooling_device0 … cooling_device7   ← no thermal_zone* with a temp file

$ grep -c coretemp /proc/modules
0
```

No `coretemp`, no `k10temp`, no thermal zone. `scripts/monitors/unix/temperature_monitor_docker.sh`
tries four methods — `nvidia-smi`, `sensors`, `/sys/class/hwmon`, `/sys/class/thermal`.
**All four are correct Linux code. All four find nothing**, because there is nothing there
to find.

### What that actually proves

Not that containers are blind. That *virtual machines* are.

| Environment | CPU temperature from a container | Why |
|---|---|---|
| Linux host, native Docker | **Yes** | The container shares the host kernel. `/sys/class/hwmon` shows the host's real `coretemp`/`k10temp`. Netdata and Glances read temperatures this way routinely. |
| Docker Desktop on Windows (WSL2) | **No** | The container runs inside a Linux VM with no CPU thermal access. There is nothing to mount, and no capability that helps. |
| Docker Desktop on macOS | **No** | Same virtualization boundary. |

Windows-native is not simple either, and the codebase already shows why.
`Host2/main.go` queries WMI `MSAcpi_ThermalZoneTemperature`, which returns nothing on most
consumer hardware — it is an ACPI thermal zone that vendors frequently leave unimplemented
or populate with throttle points rather than core temperature. That is precisely why
`libs/LibreHardwareMonitorLib.dll` and `windows/scripts/run_as_admin.ps1` exist:
LibreHardwareMonitor loads a **kernel-mode driver** to read model-specific registers
directly, which requires Administrator.

### The actual rule

Reading CPU temperature requires ring-0 access to model-specific registers. Every
abstraction layer between the code and the silicon either passes that access through or
does not:

| Layer | Passes MSR access through? |
|---|---|
| Container (namespaces + cgroups) | **Yes** — shares the host kernel |
| Virtual machine (WSL2, HyperKit) | **No** — no MSR passthrough to the guest |
| Windows userspace | **No** — needs a signed kernel driver |
| Linux userspace + loaded `coretemp` | **Yes** — via sysfs |

This is a sharper and more useful finding than "Docker can't see hardware", and it is
verifiable in a single terminal session.

## Decision

Keep the host-native agent tier — **but on the correct justification.**

Not *"containers cannot read hardware"*, which is false on Linux. Instead:

> **A natively-running agent is the only component guaranteed to sit on the
> host side of every virtualization boundary, on every supported platform.**

Container-side collection would need a different technique per platform — sysfs mounts on
Linux, and nothing that works at all on Windows or macOS. The agent needs one technique
everywhere. This is a decision for **portability**, not a workaround for an impossibility.

Consequently:

- Agents run natively on the machine being measured, with whatever privilege that
  machine's OS requires (Administrator on Windows for MSR access; a loaded `coretemp`
  module on Linux).
- The dashboard container is granted **no** hardware access, no privileges, and no
  `/proc` `/sys` `/dev` mounts. It renders; it does not measure.
- The boundary is documented as a feature of the system, not apologised for.

## Consequences

**Good.** The container runs unprivileged and read-only, which is only possible because
the boundary was drawn here. One collection technique per platform instead of two. And
the project gains an accurate, demonstrable technical claim in place of an inaccurate one —
the measurement above is a better artifact than the assumption it replaces.

**Costs.** Nothing works until an agent is running, which is a real onboarding cost and
the reason the six launcher scripts should collapse into one command. On Windows, CPU
temperature requires an elevated agent, which must be stated plainly in setup docs rather
than discovered. And because agents run outside any orchestrator, they are distributed as
artifacts rather than deployed — see [0007](0007-binaries-via-releases.md).
