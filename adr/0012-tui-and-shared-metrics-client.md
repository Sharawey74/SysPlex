# 0012 — The TUI stays, and `core/` becomes the shared metrics client

- **Status:** **Superseded by [0014](0014-remove-the-tui.md)** — kept for the reasoning trail
- ~~Accepted 19 Aug 2026~~
- **Closes:** the last open scope question from [the audit](../plans/2026-08-19-architecture-audit.md)
- **Relates to:** [0002](0002-single-metrics-contract.md), [0008](0008-container-side-collection.md), [0010](0010-backend-framework-fastapi.md)

## Context

The Rich terminal dashboard (`display/tui_dashboard.py`, 614 lines) and its supporting
modules (`core/metrics_collector.py`, `core/alert_manager.py`, 731 lines) are the
**best-tested code in the repository** — 958 lines of tests, all passing. They are also
completely disconnected from the web dashboard, which re-implements metric reading and
alert handling itself rather than using them.

Two facts force a decision now:

1. [ADR-0008](0008-container-side-collection.md) retires container-side collection, which
   deletes `data/metrics/current.json` — **the TUI's only data source.** It cannot be left
   alone; it either changes or it dies.
2. [ADR-0010](0010-backend-framework-fastapi.md) rewrites the backend. That rewrite is the
   one moment where choosing a shared data-access layer costs nothing extra.

The current duplication is concrete: `core/metrics_collector.py` parses the metrics
envelope with typed extractors and 340 lines of tests behind it, while `web/app.py` opens
the same JSON with `json.load()` and reaches into raw dicts inside bare `except:` blocks.
One path is careful and tested; the other ships.

## Decision

**Keep the TUI, and promote `core/` into the shared Python metrics client used by both
the backend and the TUI.**

```
                    contracts/metrics.schema.json
                                │
                       core/  (typed client)
                    ┌──────────┴──────────┐
              server/ (FastAPI)      tui/ (Rich)
```

Concretely:

- `core/` is renamed to reflect its new role and typed by the Pydantic models generated
  from [ADR-0002](0002-single-metrics-contract.md)'s schema. Its existing extractor
  functions become the parsing layer for both consumers.
- `core/alert_manager.py` becomes the single alert engine. The web dashboard stops reading
  `alerts.json` directly and calls it — which is consolidation, not new work.
- The TUI reads from the agent HTTP API, the same source the backend uses, instead of a
  file that will no longer exist.
- `display/` is renamed `tui/`, since "display" describes nothing.

## Why keep the TUI at all

**It is a third independent proof that the contract is real.** [ADR-0011](0011-agent-implementation-scope.md)
keeps the Bash agent to show two languages can *produce* the envelope. The TUI shows two
independent frontends can *consume* it. A contract honoured by four programs in three
languages is demonstrably an interface; one honoured by a single program is just that
program's output format.

Secondary, and genuinely practical: a terminal dashboard is the right tool when you are
SSH'd into a machine, which is exactly the situation a hardware monitor is for. It needs no
browser, no build step, and no port forwarding.

## Alternatives considered

**Retire the TUI.** Removes 614 lines plus 958 lines of tests. Rejected because it deletes
the repository's most thoroughly tested component to solve a problem — a dead data source —
that a one-line source change fixes, and because it discards the consumer-side proof of the
contract.

**Keep the TUI but leave `core/` TUI-only.** Preserves the status quo where the backend
hand-rolls untested JSON parsing next to a tested parser it refuses to import. This is the
duplication the refactor exists to remove.

**Keep the TUI reading files rather than the API.** Simpler, and it re-creates the
"multiple readers, multiple file paths, no shared contract" problem documented in the audit.

## Consequences

**Good.** The backend inherits 731 lines of tested, typed parsing instead of writing new
untested parsing. The alert engine stops existing twice. `core/`'s test suite becomes
coverage of shipping code rather than coverage of a side path — which is a large part of
[the audit's B8 gap](../plans/2026-08-19-architecture-audit.md) closed by consolidation
rather than by writing new tests. Four consumers, one contract.

**Costs.** `core/`'s function signatures change as Pydantic models replace raw dicts, so its
340 lines of tests need updating — real work, though the test *cases* survive and only the
assertions move. The TUI gains a network dependency and therefore needs a
"cannot reach agent" state it does not currently have. `display/conftest.py` and the
`display.*` patch targets across `tests/python/test_tui_dashboard.py` must follow the
rename.
