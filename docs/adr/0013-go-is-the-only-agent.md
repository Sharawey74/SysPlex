# 0013 — Go is the only agent

- **Status:** Accepted (19 Aug 2026)
- **Supersedes:** [0011](0011-agent-implementation-scope.md) ("Go primary, Bash reference, PowerShell retired")
- **Relates to:** [0001](0001-hardware-access-boundary.md), [0002](0002-single-metrics-contract.md)

## Context

[ADR-0011](0011-agent-implementation-scope.md) kept the Bash agent as a "reference
implementation" proving the metrics contract is language-agnostic. Challenged directly —
*what is the actual purpose of each agent?* — that reasoning does not hold up.

Comparing the two honestly:

| | Go agent | Bash agent |
|---|---|---|
| Ships as | one static binary, ~8 MB | ~1,300 lines of shell + a FastAPI server |
| Needs on the monitored machine | **nothing** | bash, coreutils, Python 3, FastAPI, uvicorn |
| Linux | yes | yes |
| macOS | yes | yes |
| **Windows** | **yes** | **no** — WSL only, which reads the VM, not the hardware |
| `fans`, `smart` | not implemented | implemented |
| Drift already measured | — | up to 240 lines between its own two copies |

The only genuine capability gap is `fans` and `smart`. That is not architectural: the Bash
agent gets them by shelling out to `sensors` and `smartctl`, and Go can shell out to
exactly the same tools in roughly fifty lines.

So the Bash agent's real purpose was **historical** — it came first, and the academic brief
required shell scripting. "Reference implementation" was a justification applied afterwards
to code that already existed.

## Decision

**The Go agent is the only agent. The Bash and PowerShell trees are both removed.**

One binary, three platforms, no runtime dependencies. The install instruction becomes a
single sentence, which is what [0009](0009-agents-push-dashboard-receives.md)'s
distribution model needs.

Before deletion, two things are extracted:

1. **`fans` and `smart` collection** is ported into the Go agent — shell out to `sensors`
   and `smartctl` on Linux/macOS, same as the Bash monitors do today. Low complexity.
2. **A worked example of the contract implemented in shell** — roughly 100 lines, drawn
   from the existing monitors — goes into `docs/AGENTS.md` as documentation showing how to
   write a conforming agent in any language. This preserves the point ADR-0011 was reaching
   for, as a document rather than as a second running system nobody installs.

The Windows temperature question is handled separately and is **not** as simple as
ADR-0011 implied — see below.

## The Windows CPU temperature problem, stated accurately

ADR-0011 said to "port the LibreHardwareMonitor technique into the Go agent." That
understated the difficulty and should be corrected.

LibreHardwareMonitor is a **.NET library** that reads model-specific registers by installing
a kernel driver (WinRing0). Go cannot load a .NET assembly, so "porting the technique"
means one of:

| Option | What it takes | Complexity |
|---|---|---|
| **A** — WMI only, document the limitation | already implemented; `MSAcpi_ThermalZoneTemperature` returns nothing on most consumer hardware, so temperature shows `N/A` for many Windows users | **Low** |
| **B** — bundle a small .NET helper the agent invokes | a self-contained .NET publish is ~15 MB and breaks the "one small static binary" story | Medium |
| **C** — Go talks to the WinRing0 driver directly | driver signing, kernel interaction, elevation handling — a project in its own right | **High** |

**Decision: option A for v1.** Windows CPU temperature reports `N/A` where WMI has nothing,
and `docs/TROUBLESHOOTING.md` explains exactly why — that ring-0 MSR access needs a signed
kernel driver, which is the same boundary [0001](0001-hardware-access-boundary.md) is about.
Option B is revisited after v1 if it matters.

This is a real, honest functional regression on some Windows machines relative to the
PowerShell path, and it is accepted deliberately rather than discovered later. Everything
else the Windows agent reports — CPU, memory, disk, network, GPU, uptime — is unaffected.

## Alternatives considered

**Keep Bash as a second installable agent.** Two implementations, one maintainer, already
drifting. Nothing it does that Go does not, and it cannot cover Windows.

**Keep Bash, drop Go.** Would abandon Windows entirely and require Python on every monitored
machine. The binary is what makes the distribution story work.

**Rewrite the agent in Rust or Zig for a smaller binary.** No problem being solved; gopsutil
is mature and already handles all three platforms.

## Consequences

**Good.** Roughly 5,200 lines leave the repository (~1,300 Bash + ~3,880 PowerShell), along
with the FastAPI host server, the duplicated monitor trees and their drift. One agent means
one place to fix a bug and one artifact to build in CI. The setup documentation collapses to
"download this file and run it."

**Costs.** Windows CPU temperature regresses to `N/A` on hardware where WMI reports nothing —
stated in the docs, not hidden. `fans` and `smart` must be implemented in Go *before* the
Bash tree is deleted, or those fields silently disappear. `Host/api/server.py`,
`Host/scripts/`, `Host/loop/`, `windows/`, `tests/unix/` (11 files) and `windows/tests/`
(12 files) all go, which removes real test files — though they covered code that is also
being removed, so shipping-code coverage improves rather than falls.

The `shellcheck` CI gate loses most of its scope. It stays, covering what shell remains
(the Makefile helpers and any install script), but it is no longer the high-signal gate the
audit described.
