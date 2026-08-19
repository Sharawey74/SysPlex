# 0009 — Agents push; the dashboard receives

- **Status:** **Descoped for v1 (19 Aug 2026)** — the analysis stands; the implementation is deferred
- ~~Accepted 19 Aug 2026~~

> **Why descoped:** the project's purpose was settled as *a portfolio piece about one
> systems problem*, not a competitive monitoring product. With one machine and a static
> demo, there is nothing to push to. Making the agent URL configurable instead of hardcoded
> to `host.docker.internal` (task 4.7, ten minutes) captures most of the architectural point
> without building ingest, tokens and rate limiting. This record is kept because the
> diagnosis — one config line is what makes the system undeployable — is correct and worth
> stating in the README.
- **Relates to:** [0001](0001-hardware-access-boundary.md), [0004](0004-demo-mode-and-vercel.md), [0010](0010-backend-framework-fastapi.md)

## Context

One line of configuration makes SysPlex undeployable anywhere:

```
HOST_API_URL=http://host.docker.internal:8888
```

The dashboard **pulls** metrics from an agent it assumes is running on the same physical
machine. `host.docker.internal` is a Docker Desktop convenience that resolves to the
container's own host. Move the dashboard to a server and there is nothing at that address.

This single assumption produces three separate limitations:

1. **No deployment.** The dashboard can only ever run on the machine it monitors.
2. **No multi-machine view.** The original brief called for team collaboration; the code
   has no concept of more than one monitored host, because pulling from
   `host.docker.internal` can only ever mean *this* host.
3. **No NAT traversal.** Even on a LAN, pulling requires the dashboard to reach the
   agent — so agents behind a firewall or on a laptop that moves networks cannot be
   monitored.

Every established tool in this space resolves it the same way. Datadog, Netdata Cloud,
Zabbix and Grafana Agent all have the agent initiate the connection. Prometheus is the
notable exception, and it pays for pull with a service-discovery layer that SysPlex has no
reason to build.

## Decision

**Invert the direction of data flow. Agents push; the dashboard exposes an ingest
endpoint.**

- The agent gains an optional push mode: `--push-url` / `SYSPLEX_PUSH_URL`, plus a token.
  When set, it `POST`s its metrics payload on the same interval it already writes files.
- The backend gains `POST /api/ingest`, which validates the payload against the metrics
  contract ([0002](0002-single-metrics-contract.md)), stamps a receive time, and writes to
  storage keyed by agent identity.
- Agent identity is `{hostname, platform, implementation, agent_id}`, where `agent_id` is
  generated once and persisted next to the binary.
- Pull mode is **kept** for local development, where it is simpler and needs no token.
  The two modes are configuration, not separate code paths — both end at the same
  storage write.

The implementation cost is genuinely small: the Go agent already runs an HTTP server and a
60-second ticker. This is one outbound call inside the existing tick, and one route on the
backend.

## Alternatives considered

**Keep pull, add a host registry.** The dashboard reads a configured list of agent URLs and
polls each. Works on a LAN, fails behind NAT, and requires every agent to be reachable and
addressable — which for laptops it is not.

**WebSocket / streaming.** Lower latency and a persistent connection that solves NAT
equally well. Rejected for now: the agents sample once per minute, so streaming buys
nothing, and it adds connection-state management to both ends. Worth revisiting only if
sub-second updates ever become a requirement.

**Message queue between agent and dashboard.** Correct at fleet scale, and far too much
machinery for a system whose realistic ceiling is a handful of machines.

## Consequences

**Good.** The dashboard becomes deployable anywhere. Multi-machine support falls out
almost for free — the ingest endpoint does not care whether one agent or ten are reporting,
and this is what finally delivers the collaboration requirement the original brief had.
Agents work behind NAT, on laptops, on any network.

It also produces the best demonstration this project can offer: **a visitor downloads the
agent, runs it, and watches their own machine appear on the hosted dashboard.** That is
the real architecture running end to end, not a simulation of it — and it is a materially
stronger demo than any cloud deployment could give, precisely because the hardware
boundary in [0001](0001-hardware-access-boundary.md) makes cloud-side collection
impossible.

**Costs.** An open ingest endpoint needs authentication, or anyone can write arbitrary
metrics into the dashboard. A shared bearer token per agent is sufficient at this scale;
this must not ship without one. Payload validation at ingest becomes mandatory rather than
optional, which makes [0002](0002-single-metrics-contract.md) load-bearing rather than
merely tidy. Storage grows with the number of reporting agents, so the retention window
applies per agent. And the demo's ingest endpoint should be rate-limited and its data
ephemeral, since it is by definition open to the public.
