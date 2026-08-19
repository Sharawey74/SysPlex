# 0011 — Agent implementation scope: Go primary, Bash reference, PowerShell retired

- **Status:** **Superseded by [0013](0013-go-is-the-only-agent.md)** — kept for the reasoning trail
- ~~Accepted 19 Aug 2026~~
- **Relates to:** [0001](0001-hardware-access-boundary.md), [0002](0002-single-metrics-contract.md), [0008](0008-container-side-collection.md)

## Context

Four collectors exist. They were not designed as a set — they accumulated, partly because
the original academic brief required shell scripting.

| Implementation | Lines | Platforms | Output consumed by |
|---|---|---|---|
| Go agent (`Host2/`) | 824 | Linux, Windows, macOS | Flask dashboard |
| Bash agent (`Host/scripts/` + FastAPI) | ~1,300 | Linux, macOS, WSL | Flask dashboard |
| PowerShell (`windows/`) | ~3,880 | Windows only | **nothing** |
| Container Bash (`scripts/monitors/unix/`) | ~700 | container only | Rich TUI only |

The fourth is already retired by [0008](0008-container-side-collection.md). The
PowerShell set writes `windows/data/metrics/windows_current.json`, which no reader in the
repository opens — verified by grep. It is the largest body of code in the project and it
is disconnected.

There is also real redundancy between the first two: the Go agent covers every platform
the Bash agent covers, plus Windows, from a single binary with no runtime dependency.

## Decision

### Go is the product agent

It is the only implementation that is genuinely cross-platform, ships as one static binary
with no interpreter or package requirements, and can therefore be handed to someone as a
download. [0009](0009-agents-push-dashboard-receives.md)'s push mode and
[0007](0007-binaries-via-releases.md)'s Release artifacts both assume it. Everything about
the distribution story depends on this being one file.

Work required: `os.ReadFile`/`os.WriteFile` instead of the deprecated `io/ioutil`,
write-temp-then-`os.Rename` so readers never see a truncated file, `signal.NotifyContext`
for clean shutdown, configurable port and interval, and gopsutil v3 → v4.

### Bash is kept as a reference implementation

Not as a fallback, and not as a second product — as **proof that the metrics contract is
language-agnostic**. Two independent implementations in different languages producing the
same validated envelope is the clearest possible demonstration that
[0002](0002-single-metrics-contract.md) describes a real interface rather than one
program's output format.

This is worth keeping because it already exists, it already passes, and CI validating both
against the same schema turns it from duplication into evidence. It also retains the
broadest sensor coverage — it is the only implementation reporting `fans` and `smart`.

It is documented as the reference implementation, not offered as the default install.

### PowerShell is retired as a collector

Its output is read by nothing, the Go agent already covers Windows, and it is 3,880 lines
to maintain for zero consumers.

**What is extracted before it goes:** `windows/utils/hardware_sensor.ps1` contains the only
working technique in the repository for reading real CPU temperature on Windows — loading
LibreHardwareMonitor to reach model-specific registers through a kernel driver. That is
precisely the mechanism [0001](0001-hardware-access-boundary.md) is about. It is preserved
as a documented appendix in `docs/ARCHITECTURE.md`, and the technique is folded into the Go
agent's Windows temperature path where WMI `MSAcpi_ThermalZoneTemperature` returns nothing.

`windows/cleanup_and_reorganize.ps1` and `windows/scripts/migrate_powershell_scripts.ps1`
are one-off migration scripts that have already run, and go regardless.

## Alternatives considered

**Keep all three as equal implementations.** Honest to the academic origin, and the reason
the monitors have already drifted by up to 240 lines. Three implementations means three
places to fix every bug, for a system with one maintainer.

**Retire Bash too, keeping only Go.** Cleanest possible answer, and it discards the single
most interesting property of the design. The contract's credibility rests on more than one
implementation honouring it.

**Keep PowerShell, wire it to the dashboard.** Would require giving it push support,
schema validation, and a place in the agent inventory — substantial work to add a
Windows-only collector that duplicates what the Go agent already does on Windows better.

## Consequences

**Good.** Roughly 3,900 lines leave the repository while the technique inside them is kept
as documentation and folded into the agent that will actually run. Two implementations
instead of four means CI can realistically validate both against the contract on every
commit. The distribution story becomes a single sentence: download one binary for your OS.

**Costs.** Windows users lose the LibreHardwareMonitor path until it is ported into the Go
agent, so CPU temperature on Windows may regress temporarily — this must be sequenced so
the port lands before the PowerShell tree is removed. The `libs/*.dll` dependency and its
MPL-2.0 attribution obligation follow the technique rather than disappearing, so
[0007](0007-binaries-via-releases.md)'s download-at-setup approach still applies. And
`windows/tests/` (12 PowerShell test files) goes with the implementation it covers, which
reduces the raw test count even though it improves the ratio of tested shipping code.
