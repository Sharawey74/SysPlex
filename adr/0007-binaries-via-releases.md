# 0007 — Build artifacts ship as GitHub Releases, not Git objects

- **Status:** Accepted (19 Aug 2026)
- **Relates to:** [0001](0001-hardware-access-boundary.md), [0004](0004-demo-mode-and-vercel.md)

## Context

The repository tracks 24 MB of compiled Go binaries, 1.6 MB of third-party .NET DLLs,
ten `.pyc` files across two interpreter versions, a 715 KB log file, eight generated
reports, and assorted runtime JSON state. Packed history is 21.5 MB for a project of
roughly 7,000 lines.

`.gitignore` was written to prevent most of this and prevents none of it, for two
distinct reasons worth separating:

1. **Pattern mismatch.** The ignore rules list `Host2/bin/host2-agent-linux`,
   `host2-agent-darwin` and `host2-agent.exe`. `Host2/build.sh` produces
   `host-agent-linux`, `host-agent-macos` and `host-agent-windows.exe`. The patterns
   have never matched the filenames.
2. **Ordering.** `__pycache__/`, `*.py[cod]`, `*.backup`, `reports/html/*.html` and the
   `data/` rules are all correct — but the files were staged before the rules existed,
   and `.gitignore` has no effect on already-tracked paths.

The DLLs carry a further consequence: LibreHardwareMonitor is MPL-2.0, and
redistributing the binary attaches attribution obligations the repository does not
currently meet. `windows/scripts/setup_libs.ps1` already exists to fetch them, so
vendoring was never necessary.

## Decision

**No build output, dependency artifact, or runtime state is tracked in Git.**

- Fix the `.gitignore` patterns to match reality: `Host2/bin/host-agent-*`.
- `git rm -r --cached` every already-tracked violation.
- Go binaries are matrix-built in CI and published as **GitHub Release assets** on tag.
  This is where reviewers expect them, it gives the project a Downloads section, and it
  makes ADR-0004's "run the real agent on your own machine" path a single click.
- .NET DLLs are downloaded by `setup_libs.ps1`, which resolves the licensing question
  as a side effect.
- Two runtime JSON files are **kept and relocated** to `fixtures/demo/` — they are real
  recorded hardware output, which is exactly what a demo fixture should be. Everything
  else generated goes.

## On rewriting history

Untracking stops the growth; it does not shrink the 21.5 MB already in history. Erasing
that requires `git filter-repo` and a force-push, which rewrites every commit hash and
breaks every existing clone and reference. It would take the repository under 2 MB.

**Decision: history is not rewritten.** Untracking stops the growth; the existing
21.5 MB stays. Every clone, commit hash and reference remains valid, and the operation
carries no risk of breaking anything that already points at this repository.

The trade is accepted knowingly: `git clone` stays around 22 MB rather than dropping
under 2 MB. Since the binaries will no longer appear in the working tree, nobody
browsing the project encounters them unless they go looking through history — which is
where superseded artifacts legitimately belong.

If this is ever revisited, `git filter-repo --path Host2/bin --path libs --invert-paths`
is the operation, and it must be coordinated with every existing clone.

## Consequences

**Good.** Clone time and repository size drop for every future contributor. Binaries
land where they belong. The licensing exposure closes.

**Costs.** A tagged release becomes a required step before binaries are available —
which is more process than committing them, and better. Anyone with an existing clone
must re-fetch if history is rewritten.
