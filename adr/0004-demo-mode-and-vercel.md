# 0004 — Demo mode as the deployment strategy

- **Status:** Accepted (19 Aug 2026)
- **Relates to:** [0001](0001-hardware-access-boundary.md), [0003](0003-frontend-stack.md)

## Context

ADR-0001's boundary has a direct consequence for hosting: **SysPlex cannot do its real
job on any shared cloud platform.** Sensor access, GPU nodes and a real `/proc` do not
exist there, and there is no host agent to attach to. Deployed unchanged, every panel
renders "No metrics available" and `/api/metrics` returns 503.

A live link to an empty error page is worse than no link.

There will be no production deployment. The only target is a demo on Vercel.

## Decision

1. **Add `DEMO_MODE`.** When set, the metric-source chain serves committed fixtures
   from `fixtures/demo/` with small deterministic per-request jitter, so charts move
   and the page feels live. The existing `Host/output/latest.json` and
   `Host2/bin/go_latest.json` become those fixtures rather than being deleted — they
   are real recorded output from real hardware, which is exactly what a fixture should be.

2. **Show a persistent banner.** *"Demo mode — replaying recorded metrics. A real
   deployment reads live hardware through the host agents."* This is not an apology.
   It states the architecture's boundary plainly, which reads better than a dashboard
   pretending to measure a machine it cannot see.

3. **Publish the agents as GitHub Release binaries** (ADR-0007) and document the path:
   download the agent for your OS, run it, point a local dashboard at `localhost:8889`.
   A visitor runs the genuine stack against their own hardware in under a minute. No
   cloud deployment can match that, and it turns the architecture's biggest constraint
   into its most memorable feature.

## Alternatives considered

**Deploy the Flask app to Render or Fly.io in demo mode.** Gives a real API surface,
but adds a cold-start (Render spins down after 15 minutes idle), a second platform to
maintain, and — critically — the 2 s polling loop from a single open tab would saturate
a 0.1 CPU free instance. Not worth it for a demo.

**Serverless Flask on Vercel.** Wrong shape: no persistent process for background
collection, a cold start per invocation, and no writable filesystem for `json/` or
`reports/`. Fine for the frontend, wrong for the app.

**No demo at all; screenshots only.** Cheaper, and strictly worse — a static image
cannot show the polling, the charts, or the responsiveness.

## Consequences

**Good.** The project becomes permanently linkable and screenshot-able. Demo mode is
also a genuinely useful development affordance: the frontend can be built with no agent
running, and endpoint tests get a deterministic data source for free.

**Costs.** Fixtures must be regenerated when the metrics contract changes, so ADR-0002's
CI validation should cover them too. The jitter must stay small and deterministic —
plausible movement, not a random-number generator pretending to be a computer.
