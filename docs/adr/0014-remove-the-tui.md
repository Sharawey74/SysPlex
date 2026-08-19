# 0014 — The TUI is removed; `core/` becomes the backend's metrics layer

- **Status:** Accepted (19 Aug 2026)
- **Supersedes:** [0012](0012-tui-and-shared-metrics-client.md) ("the TUI stays")
- **Relates to:** [0008](0008-container-side-collection.md), [0010](0010-backend-framework-fastapi.md), [0013](0013-go-is-the-only-agent.md)

## Context

[ADR-0012](0012-tui-and-shared-metrics-client.md) kept the Rich terminal dashboard on two
arguments: it was the best-tested code in the repository, and a second frontend consuming
the same contract was consumer-side proof that the contract is real.

Both arguments are weaker than they looked.

**The test coverage does not belong to the TUI.** Of the 958 lines of tests, 410
(`test_tui_dashboard.py`) cover the TUI itself. The other 548 and 340 cover
`core/alert_manager.py` and `core/metrics_collector.py` — which survive regardless, because
the backend needs both. Removing the TUI costs 410 lines of tests for 614 lines of
implementation, not the full suite.

**The contract proof is now redundant.** [ADR-0013](0013-go-is-the-only-agent.md) reduces
the system to one agent, so the "many implementations, one contract" story is already
scoped down deliberately. Keeping a second frontend to demonstrate a property the project
is no longer claiming is inconsistent.

And the TUI's cost is not zero. Its data source (`data/metrics/current.json`) disappears
with [ADR-0008](0008-container-side-collection.md), so it needs rework to survive at all —
a network client, a new "agent unreachable" state it does not currently have, and a rename
of `display/` with the `display.*` patch targets that follow. That is real work on a
component with no consumer, in a refactor whose stated goal is a smaller, more coherent
system.

## Decision

**Remove the TUI entirely.** Deleted:

- `display/tui_dashboard.py` (614 lines)
- `display/__init__.py`, `display/conftest.py`
- `dashboard_tui.py` (113 lines, root launcher)
- `tests/python/test_tui_dashboard.py` (410 lines)
- the `dashboard_tui.py` copy and the TUI instructions in the Docker entrypoint

**Kept and promoted:** `core/metrics_collector.py` and `core/alert_manager.py` move into
`server/` as the backend's metrics parsing and alerting layer, typed by the Pydantic models
from [ADR-0002](0002-single-metrics-contract.md). Their 888 lines of tests move with them.

This keeps the genuinely valuable part of ADR-0012 — the backend stops hand-rolling
`json.load()` inside bare `except:` blocks next to a tested parser it never imports — while
dropping the frontend that motivated the ADR.

## Alternatives considered

**Keep the TUI, repointed at the agent API** (ADR-0012's position). Rejected: it is
maintenance on a component with no user, and it needs new work merely to keep functioning.

**Keep the TUI but freeze it.** A component that does not build against the new backend is
worse than no component — it becomes visibly broken code in the repository.

## Consequences

**Good.** About 1,140 lines of implementation and tests leave. The Python surface reduces to
one frontend-facing service. `core/`'s tests stop covering a side path and start covering
shipping code — the coverage gap identified in the audit narrows through consolidation,
not through new tests.

**Costs.** No terminal view when SSH'd into a machine — the only way to see metrics becomes
the web dashboard, or `curl` against the agent directly, which the docs should mention.
`core/`'s function signatures change as Pydantic models replace raw dicts, so its 888 lines
of tests need their assertions updated; the test *cases* survive. Anything in `README.md` or
`docs/` referencing the terminal dashboard must go in the Phase 1 documentation collapse.
