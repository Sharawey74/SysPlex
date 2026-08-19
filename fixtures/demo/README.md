# Demo fixtures

Real recorded output from the two agents, captured on `DESKTOP-T6GSL92` before
the refactor. Used by `DEMO_MODE=true` to serve a live-looking dashboard with no
agent attached — see [ADR-0004](../../adr/0004-demo-mode-and-vercel.md).

| File | Agent | Platform |
|---|---|---|
| `linux-wsl.json` | Bash monitors | Ubuntu 24.04 under WSL2 |
| `windows.json` | Go agent | Windows |

These are recordings, not synthetic data. That is deliberate: a fixture built by
hand drifts from what the agents actually emit, and the point of demo mode is to
show the real shape.

## Note on temperature

Both fixtures report `temperature.cpu_celsius: 0`. That is not a capture error —
it is the finding this project is about, recorded in situ:

- the **Linux payload** came from WSL2, whose kernel exposes only `AC1` and
  `BAT1` under `/sys/class/hwmon` and never loads `coretemp`
- the **Windows payload** came from the Go agent, where WMI
  `MSAcpi_ThermalZoneTemperature` returns nothing on this hardware

Reading CPU temperature needs ring-0 access to model-specific registers.
See [ADR-0001](../../adr/0001-hardware-access-boundary.md).

**The two disagree about how to say so**, and that is a bug the fixtures now
document:

| Fixture | `cpu_celsius` | `status` |
|---|---|---|
| `windows.json` (Go) | `0` | `"unavailable"` ✅ correct |
| `linux-wsl.json` (Bash) | `0` | `"ok"` ❌ wrong |

The Bash agent reports success while returning no reading, so a consumer that
trusts `status` renders `0 °C` as a real measurement — a CPU at absolute zero.
The metrics contract must forbid this: `status: "ok"` requires a value, and an
absent reading must be `null` with `status: "unavailable"`, never `0`. Tracked
as task 3.7.

Phase 5 adds a third fixture with temperature populated, so the thermal UI can
be demonstrated. It must be labelled as synthetic where these two are not.
