# 0003 — Frontend stack: React + TypeScript, and the Next.js question

- **Status:** Accepted (19 Aug 2026)
- **Decision:** Option B — React + TypeScript + Vite + Tailwind CSS
- **Partly superseded by [0010](0010-backend-framework-fastapi.md):** the backend is FastAPI, not Flask. Everything this record says about the *frontend* stands; every reference to "Flask" below should be read as "the Python backend"
- **Relates to:** [0002](0002-single-metrics-contract.md), [0004](0004-demo-mode-and-vercel.md)

## Context

The current frontend is a single Jinja template (435 lines, four inline `onclick`
handlers, extensive inline styles), one 905-line script in a flat global scope with two
separate `DOMContentLoaded` listeners, and a 986-line stylesheet. There is no build
step, no type checking, and no component boundary. Twenty `innerHTML` assignments
interpolate hostnames and device names directly into markup.

It also hardcodes one person's machine into the data model: `previousState` is keyed
`{ win, wsl }`, and element IDs are `win-cpu-val`, `wsl-mem-detail` and so on. Running
SysPlex on two Linux boxes produces a column labelled "Windows Host".

The requirement is React + TypeScript, with Vue explicitly excluded. That part is
settled. What is not settled is **whether Next.js or a plain React + Vite SPA**, and
that choice is entangled with what happens to the Flask backend.

## Options

### Option A — Next.js on Vercel, replacing Flask for the demo

The demo deploys as a Next.js app; API routes under `app/api/` serve the demo fixtures,
so the hosted demo has a real, clickable API surface and needs no Python at all. Flask
survives as the local/Docker backend that talks to real agents.

- **For:** Vercel is Next.js's native target — zero deployment configuration. The demo
  gets working endpoints, not just bundled JSON. Server components can render the shell
  before data arrives. File-based routing matches the route structure cleanly.
- **Against:** two backends implementing the same endpoints — TypeScript for the demo,
  Python for real use — which is a duplication ADR-0002 would then have to police
  across a third language. Next.js is substantial machinery for six routes.

### Option B — React + Vite SPA, static, Flask unchanged

Vite builds a static bundle. Vercel serves it. In demo mode the bundle imports the
fixtures directly; against a real backend, `VITE_API_URL` points at Flask.

- **For:** the smallest honest architecture. One backend (Flask), one frontend, no
  duplicated API layer. Faster builds, simpler mental model, and a static bundle
  loads instantly with no cold start. Deploys to Vercel just as well as Next.js does.
- **Against:** no server-side rendering. The demo has no real API surface — a reviewer
  who opens devtools sees a static import, not a fetch. Routing, data fetching and
  layouts are assembled from libraries rather than given.

### Option C — Next.js replacing Flask entirely

One TypeScript backend everywhere; the Python web tier is deleted; agents unchanged.

- **For:** one language for the whole presentation tier. No duplication at all.
- **Against:** discards working, tested Python for no functional gain, and Node then
  has to do the report generation that `weasyprint` currently handles. Loses the
  polyglot character (Bash + Go + Python + PowerShell) that is part of what makes
  the project interesting.

## Decision

**Option B — React + TypeScript + Vite, styled with Tailwind CSS. Flask remains the
single backend.**

The reasoning is that Option A's cost is a second implementation of the same endpoints,
which is precisely the class of duplication this whole refactor exists to remove. The
demo's job is to prove the UI works and look alive when clicked; a static bundle does
that perfectly, loads faster, and never cold-starts. Option C trades working code for
uniformity and loses the multi-language story.

Option A would have been the better answer if the hosted demo needed to be *pokeable* —
`curl`-able endpoints a reviewer can hit — rather than merely viewable. That is not a
requirement here, so the cost of a second API implementation buys nothing.

## Styling: Tailwind CSS

Tailwind replaces the 986-line hand-written stylesheet and the inline `style="..."`
attributes scattered through the template. It fits this codebase for three specific
reasons:

- **The current CSS has no system.** Colours, spacing and typography are repeated
  literals across 986 lines and inline attributes. Tailwind's scale imposes one by
  construction, and the existing dark cyber palette maps cleanly onto theme tokens in
  `tailwind.config.ts`.
- **The panels are highly repetitive.** CPU / memory / disk / network / GPU cards share
  a structure. Utilities on a small set of extracted components (`MetricCard`,
  `UsageBar`, `GaugeRing`) is a better fit than growing a bespoke class taxonomy.
- **Dark/light and responsive come with it.** `dark:` and the breakpoint prefixes solve
  two of the audit's open UI gaps without a separate theming layer. A `data-theme`
  attribute plus Tailwind's `darkMode: 'class'` gives the theme toggle directly.

The one discipline this requires: extract a component as soon as a utility string is
repeated, rather than copying it. Tailwind punishes copy-paste more visibly than CSS
does, which in this repository is a feature.

## Consequences either way

The route structure (`/`, `/agents`, `/agents/:id`, `/history`, `/reports`), the
component inventory, the generated types from ADR-0002, and the polling layer
(visibility pause, exponential backoff to 30 s, `AbortController`, 5 s interval rather
than 2 s) are identical under all three options. Only the shell around them changes,
so most of Phase 7 is not blocked by this decision — but the scaffolding is.

The hardcoded `win`/`wsl` model is replaced by agent identity in every option. This is
the one behavioural change to the existing UI, and it is required for `/agents` to work.
