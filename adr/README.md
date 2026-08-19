# Architecture Decision Records

Each file records one decision: the context that forced it, the options considered,
what was chosen, and what that choice costs. ADRs are immutable once `Accepted` —
a decision that changes gets a new record that supersedes the old one. Superseded
records stay in place: the reasoning trail is the point.

**Status values:** `Proposed` · `Accepted` · `Superseded by NNNN` · `Rejected`

| # | Title | Status |
|---|---|---|
| [0001](0001-hardware-access-boundary.md) | The hardware access boundary, and why agents run natively | Accepted |
| [0002](0002-single-metrics-contract.md) | One metrics contract shared by all agents | Accepted |
| [0003](0003-frontend-stack.md) | Frontend: React + TypeScript + Vite + Tailwind | Accepted (backend half → 0010) |
| [0004](0004-demo-mode-and-vercel.md) | Demo mode as the deployment strategy | Accepted |
| [0005](0005-docker-scope.md) | Docker is for local development and testing only | Accepted |
| [0006](0006-no-kubernetes-no-terraform.md) | No Kubernetes, no Terraform, no IaC | Accepted |
| [0007](0007-binaries-via-releases.md) | Build artifacts ship as GitHub Releases, not Git objects | Accepted |
| [0008](0008-container-side-collection.md) | Container-side metric collection is retired | Accepted |
| [0009](0009-agents-push-dashboard-receives.md) | Agents push; the dashboard receives | Descoped for v1 |
| [0010](0010-backend-framework-fastapi.md) | Backend framework: FastAPI, retiring Flask | Accepted |
| [0011](0011-agent-implementation-scope.md) | ~~Go primary, Bash reference, PowerShell retired~~ | Superseded by 0013 |
| [0012](0012-tui-and-shared-metrics-client.md) | ~~The TUI stays; `core/` becomes the shared client~~ | Superseded by 0014 |
| [0013](0013-go-is-the-only-agent.md) | **Go is the only agent** — Bash and PowerShell both removed | Accepted |
| [0014](0014-remove-the-tui.md) | **The TUI is removed**; `core/` becomes the backend's metrics layer | Accepted |

## Reading order

**Scope, settled 19 Aug 2026:** SysPlex is a portfolio piece about one systems problem, not
a competitive monitoring tool. 0009 is descoped for v1 on that basis; 0011 and 0012 were
superseded on the engineering merits. The rest are in force.

**0001** is the foundation — it corrects the premise the project was built on, and
everything else follows from it. **0002** and **0009** define the interfaces (the data
shape, and how it moves). **0003**, **0010**, **0013** and **0014** pick the stack for each
layer. **0004**–**0008** cover packaging, deployment and cleanup.

For the narrative version of how these fit together end to end, see
[`../plans/2026-08-19-solution-and-e2e-path.md`](../plans/2026-08-19-solution-and-e2e-path.md).

## Two records worth reading for the reasoning, not the decision

**0001** originally recorded the project's founding premise — *"containers cannot read host
hardware"* — as accepted fact. It was measured and found true only on Docker Desktop, and
false on native Linux. The record was rewritten with the measurement, and the architecture
kept on a corrected justification: portability across virtualization boundaries, rather
than impossibility. The decision did not change; the reason for it did.

**0011 and 0012** were both superseded within a day of being written, by 0013 and 0014
respectively. Both had argued for keeping something — the Bash agent, the terminal
dashboard — on the grounds that it proved the metrics contract was real. Challenged
directly, that justification turned out to be a rationalisation applied to code that
already existed. They are kept because the argument and its rebuttal are more useful
together than the conclusion alone.
