# 0002 — One metrics contract shared by all agents

- **Status:** Accepted (19 Aug 2026)
- **Relates to:** [0001](0001-hardware-access-boundary.md)

## Context

Four collectors currently write metrics: Bash monitors on the host, a Go agent, a
PowerShell monitor set, and a second Bash monitor set inside the container. They write
to five different files, read by three independent consumers, and **no schema is
defined anywhere in the repository**.

The remarkable part is that they already agree. Comparing a live Go payload against a
live Bash payload key by key, the envelope matches exactly:

    timestamp, platform, system{os,hostname,uptime_seconds,kernel},
    cpu{usage_percent,logical_processors,load_1,load_5,load_15,vendor,model,status},
    memory{total_mb,used_mb,free_mb,available_mb,usage_percent,status},
    disk[{device,filesystem,total_gb,used_gb,used_percent}],
    network[{iface,rx_bytes,tx_bytes}],
    temperature{cpu_celsius,cpu_vendor,gpu_celsius,gpu_vendor,status},
    gpu{status,count,devices[...]}

The shell agent adds `fans` and `smart`; the Go agent adds a `source` discriminator.
Two implementations in different languages converged on one interface by convention.
Nothing enforces it, so nothing stops it from drifting — and the eight duplicated
monitor scripts have already drifted by up to 240 lines.

## Decision

Declare `contracts/metrics.schema.json` the single source of truth for the metrics
envelope, and derive everything else from it:

- **Python** — Pydantic models generated for `server/`, replacing untyped `dict` access
- **TypeScript** — types generated for the frontend, replacing hand-written interfaces
- **Go** — struct tags verified against the schema in CI
- **Agents** — payloads validated against the schema in CI, so drift fails the build

Optional groups (`fans`, `smart`, `gpu.devices`) are modelled as such, and the agent
capability list in the `/agents` view is derived from which groups an agent populates.

## Alternatives considered

**Leave it implicit.** Zero cost today, and it is why the monitors already diverged.

**OpenAPI on the agent APIs instead.** Describes the HTTP surface, not the file
outputs — and three of the five write paths are files, not endpoints.

**Protobuf.** Genuinely stronger typing and codegen for all three languages, but it
replaces a human-readable JSON file the whole project is built around with an opaque
binary, for a payload measured in kilobytes. Not worth it here.

## Consequences

**Good.** One definition instead of four implicit ones. Agent drift becomes a CI
failure instead of a silent UI bug. The frontend gets real types for free. Adding a
fifth agent becomes a matter of conforming to a published contract.

**Costs.** A codegen step in the build, and a discipline requirement: schema changes
must land before the code that depends on them. The Go agent's structs will need a
small alignment pass, since `load_1`/`load_5`/`load_15` are integers there and floats
in the Bash output — a real divergence the schema will surface immediately.
