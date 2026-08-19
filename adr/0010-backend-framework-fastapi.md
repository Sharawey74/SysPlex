# 0010 — Backend framework: FastAPI, retiring Flask

- **Status:** Accepted (19 Aug 2026)
- **Supersedes:** the "Flask remains the single backend" half of [0003](0003-frontend-stack.md). The frontend half of 0003 — React + TypeScript + Vite + Tailwind — stands unchanged.
- **Relates to:** [0002](0002-single-metrics-contract.md), [0009](0009-agents-push-dashboard-receives.md)

## Context

The project runs **two Python web frameworks at once**:

| Component | Framework | Role |
|---|---|---|
| `web/app.py` | Flask 3 | dashboard, 306 lines, 7 routes |
| `Host/api/server.py` | FastAPI | shell agent API, 194 lines, 4 routes |

Nothing forced this. The agent API was written with FastAPI because it fit; the dashboard
was written with Flask earlier and never revisited. The result is two dependency sets, two
routing idioms, two error-handling models and two server runtimes for one small system.

ADR-0003 recorded "Flask stays" on the grounds of avoiding a rewrite. That reasoning was
sound in isolation and does not survive contact with two later decisions:

- [0002](0002-single-metrics-contract.md) makes a validated metrics schema central. On
  Flask, schema validation is a bolt-on. On FastAPI it is the framework's core premise.
- [0009](0009-agents-push-dashboard-receives.md) adds an ingest endpoint that **must**
  validate untrusted payloads from agents on other machines. Hand-rolling that validation
  in Flask, when FastAPI does it declaratively, is work with no upside.

## Decision

**FastAPI is the single backend framework. Flask is retired.**

`web/app.py` is rewritten as a FastAPI application. `Host/api/server.py` stays FastAPI and
is aligned with it — same Pydantic models, same error shape, same conventions.

What this gives concretely:

- **Pydantic models generated from the metrics contract**, used for both response
  serialisation and ingest validation. The contract stops being a document and becomes
  executable.
- **Automatic OpenAPI documentation** at `/docs`. For a system that publishes an ingest
  contract other machines must conform to, generated API docs are the interface
  specification, not a convenience.
- **Async request handling**, which suits fanning out to multiple agents. Flask's
  synchronous model blocks a worker per outbound agent call.
- **One dependency set, one server runtime** — `uvicorn` everywhere, replacing the
  Werkzeug development server that is currently running as if it were production.
- **Typed request/response signatures**, which makes the missing endpoint tests
  straightforward to write.

Templates go with Flask. Jinja server-side rendering is replaced by the React frontend from
[0003](0003-frontend-stack.md), so the backend serves JSON only. Report generation moves
behind a service interface and keeps working unchanged.

## Alternatives considered

**Keep Flask, add `pydantic` and `flask-openapi3`.** Reaches roughly the same place by
assembling three libraries that FastAPI ships as one, and leaves the project still running
two frameworks.

**Keep both, drawing a boundary — Flask for the dashboard, FastAPI for agents.** Defensible
if the two were large and independently owned. They are 306 and 194 lines in one
repository maintained by one person. The boundary costs more than it protects.

**Move the backend to Node/TypeScript for language uniformity with the frontend.**
Rejected in [0003](0003-frontend-stack.md) and still rejected: it discards working, tested
Python, forces a reimplementation of report generation currently handled by `weasyprint`,
and erases the multi-language character that is part of what makes the project
interesting.

## Consequences

**Good.** One framework, one validation model, one server. The metrics contract becomes
enforced code rather than a JSON file nobody reads. `/docs` documents the ingest API for
free, which matters as soon as agents run on machines the author does not control.

**Costs.** Roughly 306 lines of routes must be rewritten — small, and largely work that was
already required to fix the triplicated metric-reading logic and the nine bare `except:`
blocks. The Jinja template and the Flask-specific `send_file` download path are replaced
rather than ported. `Flask`, `Flask-Cors` and `Werkzeug` leave `requirements.txt`;
`gunicorn` is no longer needed, since `uvicorn` is the correct ASGI server.

This does mean the container's process manager changes from `gunicorn -w 2` (as
[0005](0005-docker-scope.md) specified) to `uvicorn --workers 2`. ADR-0005 is otherwise
unaffected.
