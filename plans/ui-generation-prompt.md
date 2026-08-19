# UI generation prompt

Copy everything inside the fence into a fresh session with a tool that renders React —
v0, Claude, Cursor, Bolt, Lovable. It is long on purpose: generation quality tracks the
specificity of the brief, and vague prompts produce the same four purple gradient cards
every time.

It carries exact hex values, timing curves, the real data contract, and a list of things
**not** to do. Generate, look at it, iterate on the parts that miss, then bring the good
parts into Phase 7.

**Scope note:** three pages — `/`, `/system`, `/architecture`. `/history` and `/agents` are
descoped for v1 (see TASKS.md). If you want to *see* them before deciding, there's an
add-on paragraph after the fence.

---

```
Build the frontend for SysPlex — a hardware telemetry dashboard. React 18 + TypeScript +
Vite + Tailwind CSS + Recharts + Framer Motion. No backend: mock all data so every page
renders standalone.

I care a great deal about visual craft. Treat this as a product with a design team, not a
CRUD admin panel. Density, precision and motion matter. Read the whole brief before
writing code.

═══════════════════════════════════════════════════════════════════
1. WHAT IT IS
═══════════════════════════════════════════════════════════════════

An agent runs natively on a machine and samples its hardware every 60 seconds — CPU,
memory, disk, network, GPU, temperature, fans, SMART. This dashboard displays that.

The interesting part: a dashboard running inside a container cannot read the host's CPU
temperature, because Docker Desktop runs containers inside a VM and the VM has no thermal
sensor. That constraint is why the agent exists, and one page is dedicated to explaining it.

═══════════════════════════════════════════════════════════════════
2. DESIGN DIRECTION
═══════════════════════════════════════════════════════════════════

Aim at the intersection of three references:

  • An automotive instrument cluster — radial gauges, precision, at-a-glance hierarchy
  • Mission control — dense, monospace, status-driven, nothing decorative
  • A phosphor oscilloscope — traces that glow faintly, fine grid lines, dark ground

Adjacent products worth the flavour: Vercel's dashboard, Linear, Railway, Grafana.
Restrained, technical, confident. Not playful, not corporate-SaaS, not neon-cyberpunk.

The feel to hit: an instrument you trust. Every number looks measured, not styled.

═══════════════════════════════════════════════════════════════════
3. DESIGN SYSTEM — use these exact values
═══════════════════════════════════════════════════════════════════

Define as CSS custom properties on :root, extend tailwind.config.ts from them.
Dark is the primary theme. Light is a full, real theme — not an afterthought.

COLOR — dark
  --bg              #07090d   near-black, faint blue cast
  --bg-elevated     #0d1117
  --surface         #131920   cards
  --surface-hover   #1a222c
  --border          #1f2933   hairlines, 1px
  --border-strong   #2d3a47
  --text            #e6edf3
  --text-muted      #8b949e
  --text-dim        #56606b
  --accent          #22d3ee   cyan — the single accent, use sparingly
  --accent-dim      #0e7490
  --accent-glow     rgba(34,211,238,0.35)

COLOR — light (mirror the roles, do not just invert)
  --bg #fafbfc · --surface #ffffff · --border #e4e8ed · --text #0d1117
  --text-muted #57606a · --accent #0891b2

STATUS
  --ok   #34d399    --warn #fbbf24    --crit #f87171    --idle #64748b

THERMAL SCALE — the signature of this product. Map temperature onto it and
INTERPOLATE between stops rather than stepping:
  <35°C #38bdf8 · 35–50 #34d399 · 50–65 #fbbf24 · 65–80 #fb923c · >80 #ef4444
Use the same scale for CPU %, memory % and disk % so the whole UI reads consistently:
low is cool blue-green, high is hot orange-red. This one decision does most of the
visual work — commit to it everywhere.

TYPOGRAPHY
  UI/display:  Inter (or system-ui stack), 400/500/600
  Numerics:    JetBrains Mono — EVERY number, without exception
  Critical:    font-variant-numeric: tabular-nums on all live values, so digits do not
               shift width as they change. Nothing looks cheaper than jittering numbers.
  Scale: 11 / 12 / 13 / 14 / 16 / 20 / 28 / 40 / 56px
  Big readouts (CPU %, temperature): 40–56px, weight 600, tight tracking (-0.02em)
  Labels: 11px, uppercase, letter-spacing 0.08em, --text-dim

SPACE            4px base scale: 4 8 12 16 24 32 48 64
RADIUS           6px controls · 10px cards · 999px pills
ELEVATION        Do not use heavy drop shadows. Depth comes from surface color +
                 a 1px border. At most: 0 1px 2px rgba(0,0,0,0.4), plus an
                 accent glow on interactive/critical states.

MOTION
  fast 120ms · base 200ms · slow 400ms · value interpolation 600ms
  entrance easing  cubic-bezier(0.16, 1, 0.3, 1)     (expo-out)
  state easing     cubic-bezier(0.4, 0, 0.2, 1)
  gauges           spring, stiffness 120, damping 20

═══════════════════════════════════════════════════════════════════
4. DATA CONTRACT — match exactly
═══════════════════════════════════════════════════════════════════

type Metrics = {
  timestamp: string
  platform: "linux" | "windows" | "darwin"
  system:   { os: string; hostname: string; uptime_seconds: number; kernel: string }
  cpu:      { usage_percent: number; logical_processors: number
              load_1: number; load_5: number; load_15: number
              vendor: string; model: string; status: string }
  memory:   { total_mb: number; used_mb: number; free_mb: number
              available_mb: number; usage_percent: number; status: string }
  disk:     Array<{ device: string; filesystem: string
                    total_gb: number; used_gb: number; used_percent: number }>
  network:  Array<{ iface: string; rx_bytes: number; tx_bytes: number }>
  temperature: { cpu_celsius: number; cpu_vendor: string
                 gpu_celsius: number; gpu_vendor: string; status: string }
  gpu:      { status: string; count: number
              devices: Array<{ vendor: string; model: string
                               utilization_percent: number
                               memory_used_mb: number; memory_total_mb: number
                               temperature_celsius: number; status: string }> }
  fans?:    { status: string }
  smart?:   Array<{ device: string; health: string; power_on_hours: number }>
}

`fans`, `smart` and a non-empty `gpu.devices` are OPTIONAL and frequently absent. That is
the normal state on most machines, not an edge case. Temperature is often genuinely
unreadable on Windows — show "N/A" with a tooltip explaining that reading CPU temperature
needs kernel-level access. Never invent a number, never render 0 for missing data.

═══════════════════════════════════════════════════════════════════
5. MOCK DATA — make it behave like a real machine
═══════════════════════════════════════════════════════════════════

Generate 6 hours at 30-second resolution. Do NOT use plain random noise. Model it:

  • CPU: mostly 8–20%, with occasional spikes to 70–95% lasting 30–90s (a build running).
    Spiky, high-frequency.
  • Memory: smooth, slow drift 45–65%, tiny sawtooth. Almost no high-frequency movement.
  • Temperature: LAGS CPU by roughly 45 seconds and smooths it — thermal mass. Idle 42°C,
    peaks near 78°C after a sustained CPU spike, decays slowly. This lag is the single
    most convincing detail in the whole mock; get it right.
  • Network: bursty. Long quiet stretches, then sharp transfer spikes.
  • GPU: 2 NVIDIA devices, one near-idle, one at 60–90%.
  • Disk: static, 4 mounts at different fill levels including one at 91% so the critical
    state is visible.

Drive a live tick every 5 seconds that appends a point and shifts the window, so the UI
is actually moving when it loads.

═══════════════════════════════════════════════════════════════════
6. LAYOUT
═══════════════════════════════════════════════════════════════════

SIDEBAR, 240px, fixed, --bg-elevated, 1px right border
  • SysPlex wordmark — geometric, not a stock icon
  • Nav: Overview / System / Architecture. Active item: 2px accent left rail, subtle
    accent-tinted background, text at full --text. Inactive: --text-muted, hover lifts
    to --text with a 120ms transition.
  • Pinned at the bottom: agent status block — hostname, platform, a pulsing StatusDot,
    "last update 3s ago" ticking live.
  • Collapses to a 64px icon rail below 1024px.

TOP BAR, 56px, sticky, backdrop-blur, translucent --bg
  • Page title left · right: live-updating clock, manual refresh (icon rotates 360° on
    click), theme toggle (icon cross-fades and rotates, never pops)

CONTENT  max-width 1440px, 24px padding, 12-column grid, 16px gutter

═══════════════════════════════════════════════════════════════════
7. PAGES
═══════════════════════════════════════════════════════════════════

──── / OVERVIEW ────
The at-a-glance page. Should be readable from across a room.

Row 1 — four hero tiles, equal width:
  CPU · MEMORY · TEMPERATURE · GPU
  Each: 11px uppercase label; a 40–56px mono value that ANIMATES between readings;
  a secondary line (model, "12.4 / 32 GB", "peak 78°C", device count); and a 60-point
  sparkline bleeding to the bottom edge of the card with an area gradient fading to
  transparent. Card border tints toward the thermal color as the value rises.

Row 2 — the primary chart, full width, 320px tall:
  CPU % and temperature on a dual axis, sharing a crosshair. Temperature visibly
  trailing CPU is the point of this chart — it makes the thermal lag legible.
  Animated draw-in on mount. Threshold band above 80% shaded --crit at 6% opacity.

Row 3 — two-thirds / one-third split:
  Left:  memory over time, area chart, stacked used vs cached
  Right: alerts list. Empty state is a real design, not grey text: a centred
         check glyph, "All systems nominal", muted.

Row 4 — a compact strip: uptime, kernel, load averages, process count — small mono
values in a horizontal rule-separated row.

──── /system SYSTEM DETAIL ────
The dense page. Reward scrolling with information, not whitespace.

  • Header: hostname as a 28px display value, then OS · kernel · uptime as pills
  • CPU block: a large GaugeRing (see §8) beside a spec table — model, vendor, logical
    processors, load 1/5/15 as three mini bars scaled against core count
  • Memory: horizontal segmented bar — used / cached / free — with a legend, plus GB
    readouts. Segments animate width on change.
  • Disk: a table, one row per mount. Device (mono) · filesystem · a UsageBar inline in
    the row · used/total · percentage. Row at 91% renders in the critical thermal color,
    and its bar has a faint glow.
  • Network: per interface, a MIRRORED area chart — rx above the axis, tx below,
    different hues. Show RATES (MB/s), computed as a delta between samples. Never print
    the raw cumulative rx_bytes counter; it only ever goes up and means nothing.
  • GPU: one card per device — model, a utilisation ring, VRAM as a stacked bar with the
    used portion in accent, temperature badge. If devices is empty, one EmptyState card
    reading "No GPU detected".
  • SMART: table with a health pill; power-on hours converted to "2.4 years". Hide the
    entire section if absent — do not render an empty table.
  • Fans: hide entirely if absent.

──── /architecture THE FINDING ────
This is the page the audience is actually here for. Give it real design effort.

An interactive vertical stack diagram, centred, ~600px tall. Six layers, top to bottom:

    your code
    Windows userspace       ✗  blocked — needs a signed kernel driver
    Linux userspace         ✓  passes through, via sysfs
    Container               ✓  passes through, shares the host kernel
    Virtual machine         ✗  blocked — no MSR passthrough to the guest
    CPU model-specific registers

  • Each layer is a horizontal slab with a 1px border. Passing layers glow faint green
    at the edge; blocking layers glow faint red and render a subtle diagonal hatch.
  • An animated particle or pulse travels down from "your code" toward the registers,
    passing through green layers and visibly stopping dead at the first red one.
    Loop it every ~4 seconds. This animation IS the explanation — make it legible.
  • Clicking a layer expands it to reveal a paragraph plus a terminal-styled code block.
  • Below the diagram, a "measured evidence" panel styled as a terminal: monospace,
    green prompt characters, showing:

        $ uname -r
        6.6.87.2-microsoft-standard-WSL2
        $ for h in /sys/class/hwmon/hwmon*; do echo "$h : $(cat $h/name)"; done
        /sys/class/hwmon/hwmon0 : AC1      ← AC adapter
        /sys/class/hwmon/hwmon1 : BAT1     ← battery
        $ grep -c coretemp /proc/modules
        0

    Type it out character by character on scroll-into-view, with a blinking cursor.
    Respect prefers-reduced-motion by rendering it complete and static.

═══════════════════════════════════════════════════════════════════
8. COMPONENT SPECS — the ones that carry the design
═══════════════════════════════════════════════════════════════════

GaugeRing
  SVG, conic-gradient sweep along the thermal scale, 10px stroke, round caps, 270° arc
  starting at 135°. Track at --border. Value arc animates with a spring. Centre: mono
  value + unit, unit at 40% size and --text-muted. Above threshold, add a soft outer
  glow (feGaussianBlur or a duplicated blurred stroke) whose opacity scales with how
  far over it is.

MetricCard
  --surface, 1px --border, 10px radius. Hover: border → --border-strong, translateY(-1px),
  and a 0 0 0 1px --accent-glow ring — all in 200ms. Optional top-right live pulse dot.
  Never a drop shadow on rest state.

SparkLine
  SVG polyline, 2px stroke in accent or thermal color, plus an area path filled with a
  vertical gradient from 22% to 0% opacity. Final data point gets a 3px dot with a glow.
  On new data, animate the path with a stroke transition — do not snap.

TimeSeriesChart (Recharts)
  Grid lines --border at 40% opacity, horizontal only. Axis labels 11px --text-dim.
  Area gradients under every line. On mount, animate the stroke in via stroke-dasharray
  over 800ms. Custom tooltip: --bg-elevated, 1px border, mono values, a color swatch per
  series, follows the cursor with a vertical crosshair line. Legend items toggle their
  series with a fade.

UsageBar
  6px track --bg-elevated, inset. Fill uses the thermal scale for its own value, animates
  width in 600ms. Faint tick marks at 25/50/75%. Above 85%, the fill gets a slow pulse.

AnimatedNumber  ← do not skip this, it is what makes the UI feel alive
  A hook that interpolates from the previous value to the new one over 600ms using
  requestAnimationFrame with an ease-out curve, rather than replacing the text. Always
  tabular-nums. Only animate when the value actually changed — do not re-run on every
  poll that returns identical data.

StatusDot
  6px dot plus an expanding ring that fades out, on a loop matching the poll interval,
  so the pulse and the data arrival feel connected. Green online, amber stale, grey
  offline.

TemperatureBadge · DiskTable · NetworkChart · GpuCard · SmartTable · EmptyState ·
PageHeader · Sidebar · Pill · Tooltip

═══════════════════════════════════════════════════════════════════
9. MOTION & INTERACTION
═══════════════════════════════════════════════════════════════════

  • Page enter: content fades up 8px, 400ms, children staggered 40ms apart
  • Cards mount staggered — never all at once
  • Values interpolate, never snap (see AnimatedNumber)
  • Threshold color changes interpolate through the thermal scale, never jump
  • Charts draw in on first paint; on update they shift smoothly, no flash
  • Hover on any chart: crosshair + tooltip, synchronized across charts in the same row
  • Loading: skeleton shimmer in --surface, a 1.4s sweep — never a spinner
  • Refresh button: icon rotates 360° over 600ms while in flight
  • Theme toggle: cross-fade both themes over 300ms, no white flash
  • prefers-reduced-motion: reduce → disable ALL of the above. Values update instantly,
    charts render complete, the architecture pulse and terminal typing do not run.
    This is a hard requirement, not a nice-to-have.

═══════════════════════════════════════════════════════════════════
10. RULES
═══════════════════════════════════════════════════════════════════

DO
  • TypeScript strict, no `any`, everything typed from §4
  • All data behind one mock module, so swapping in a real fetch is a one-file change
  • Every data surface handles three states: loading, empty, error. All three are real
    here — the agent goes offline, machines have no GPU, temperature is unreadable.
  • Semantic HTML, keyboard-navigable, visible focus rings in accent
  • aria-live="polite" on live values; aria-label on every icon-only control
  • Responsive: 3 breakpoints. Below 768px cards stack single-column and the sidebar
    becomes a bottom bar.

DO NOT
  • No purple→pink gradients. No glassmorphism on everything. No neumorphism.
  • No emoji as icons — use a real icon set (lucide-react)
  • No heavy drop shadows; depth is surface + border
  • No layout shift when values change — reserve width with tabular-nums
  • No dangerouslySetInnerHTML — hostnames and device names come from untrusted machines
  • No login, settings page, or user management. There are no users.
  • No random-walk mock data. Model the behaviour described in §5.
  • Do not animate on every poll. Only when a value actually changed.

DELIVER
  A working Vite project. Components in their own files, not one giant page. A README
  with how to run it, and a short note on which design tokens to change first.
```

---

## Add-on, if you want to see the descoped pages too

Append this to the prompt only if you want to *look* at `/history` and `/agents` before
confirming they stay out of scope:

> Also build `/history` — a range selector (1h / 6h / 24h / 7d) as a segmented control,
> a metric selector, and a large multi-series chart with brush-to-zoom. And `/agents` —
> a card grid of monitored machines with status, platform, last-seen as relative time,
> and capability pills. Mock three agents: a full Linux workstation, a Windows laptop
> with no GPU and unreadable temperature, and an offline build box last seen 40 minutes
> ago.

## Check these four things before adopting anything

1. **Does temperature visibly lag CPU on the Overview chart?** If the two lines move
   together, the mock is a random walk and the most convincing detail was skipped.
2. **Do the numbers jitter as they change?** If digits shift width, `tabular-nums` was
   ignored — and that single miss makes the whole thing look amateur.
3. **Does `/system` survive a machine with nothing?** No GPU, no fans, no SMART,
   temperature `N/A`. Most real machines look like that. If any of it renders as `0`
   or an empty box, the component tree is wrong in a way that will bite on real data.
4. **Is network shown as a rate?** The agent reports cumulative byte counters. A UI
   printing `rx_bytes` raw is showing a number that only ever goes up.

## Then

Bring it into `frontend/` and **replace the mock module with the real client from task 7.5**.
Whatever it generates will poll naively. The visibility pause, the exponential backoff and
the `AbortController` are what stop an idle tab firing 43,200 failed requests a day, and no
generator adds them unprompted.
