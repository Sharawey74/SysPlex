# 0006 — No Kubernetes, no Terraform, no infrastructure-as-code

- **Status:** Accepted (19 Aug 2026)
- **Relates to:** [0004](0004-demo-mode-and-vercel.md), [0005](0005-docker-scope.md)

## Context

Kubernetes and Terraform are the two technologies most often added to a portfolio
project for the sake of appearing on it. Both were evaluated seriously against what
SysPlex actually is.

## Decision

Add **neither**, and record why.

### Kubernetes — not now, not later

Kubernetes orchestrates multiple replicas across nodes with rolling updates and service
discovery. SysPlex's presentation tier is one Flask process and one logger process —
nothing to orchestrate. Its collection tier is *deliberately outside any orchestrator*,
because ADR-0001 established that hardware access requires running natively on the host.

So Kubernetes would orchestrate the one tier that needs no orchestration, and cannot
reach the tier that does the actual work. Making it reach that tier means `hostPath`
mounts and privileged DaemonSets — reintroducing exactly the privilege problem ADR-0005
removes.

| | |
|---|---|
| Implementation complexity | Medium |
| Design complexity | High — the host-access boundary fights the model |
| Maintenance overhead | High |
| Benefit at this scale | None |

### Terraform — not at all

Terraform provisions cloud resources. The deployment target is a Vercel demo with a Git
integration and no infrastructure to declare. A Terraform module here would describe an
empty state. The same reasoning rules out infrastructure-as-code generally.

### Container orchestration (Swarm, Nomad) — not at all

Same reasoning as Kubernetes, with a smaller ecosystem.

### Monitoring and logging stacks (Prometheus, Grafana, Loki, ELK) — no

The irony is the argument. SysPlex *is* a monitoring tool; running Prometheus and
Grafana beside it means operating a better monitoring stack next to the one being
demonstrated, and immediately raises the question of why SysPlex exists. Structured
logging inside the application — which replacing the nine bare `except:` blocks
introduces anyway — is the right depth.

*One exception:* exposing a Prometheus-format `/metrics` endpoint **from** SysPlex is a
different proposition. That is interoperability, not dependency, it costs about forty
lines, and it is a credible signal. Optional, later.

### Object storage, managed databases — no

SQLite is correct for a rolling seven-day window on a single node, and it is a file the
demo can ship with.

## What is added instead

Exactly one technology: **GitHub Actions**, for validation gates (see the audit,
section H). It is the largest quality gap in the repository, costs almost nothing to
maintain, and its benefit is immediately visible to anyone browsing the project.

## Consequences

**Good.** The architecture stays proportionate to the problem. A reasoned, written
"no" to Kubernetes demonstrates more engineering judgement than an unused `k8s/`
directory demonstrates skill — and this ADR is that argument in writing.

**Costs.** The repository will not contain manifests that some readers scan for. That
is the correct trade: the brief's own instruction is to prioritise practical
applicability over technology accumulation, and this is what that looks like in practice.
