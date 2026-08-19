# 0005 — Docker is for local development and testing only

- **Status:** Accepted (19 Aug 2026)
- **Relates to:** [0004](0004-demo-mode-and-vercel.md), [0006](0006-no-kubernetes-no-terraform.md)

## Context

The current Docker setup carries production framing that no longer matches reality:
`FLASK_ENV=production`, `restart: unless-stopped`, and a `privileged: true` /
`pid: host` combination whose own inline comment concedes it does not achieve anything
(*"Note: Dashboard still can't access real GPU/sensors"*).

Meanwhile the image is built `FROM ubuntu:22.04` with three separate `apt-get update`
layers installing `lm-sensors`, `mesa-utils`, `radeontop`, `intel-gpu-tools` and
`pciutils` — hardware tooling, into the one component that by design never reads
hardware. There is no `.dockerignore` at the build context root, so 24 MB of committed
Go binaries, 1.6 MB of DLLs and the 22 MB `.git` directory are shipped to the daemon on
every build.

ADR-0004 settles that the deployed demo is a Vercel build. Docker is therefore not a
deployment mechanism for this project at all.

One nuance worth stating, since [0001](0001-hardware-access-boundary.md) corrects the
record: on a **native Linux host**, mounting `/sys` and installing `lm-sensors` in the
container genuinely would let it read CPU temperature. Those packages are still removed —
not because they cannot work, but because they work on exactly one of the three supported
platforms, and the agent tier already covers all three uniformly. Keeping a
Linux-only collection path inside the container buys a second code path for a subset of
users.

## Decision

Docker's scope is **a reproducible local development and testing environment**, and the
configuration should say so:

- Base `python:3.11-slim`; one `apt-get` layer for `curl` only; no hardware packages.
- `uvicorn --workers 2` instead of the Werkzeug development server ([0010](0010-backend-framework-fastapi.md)); non-root `USER`.
- Remove `privileged: true`, `pid: host`, and the `/proc` `/sys` `/dev` mounts.
  Add `read_only: true`, `cap_drop: [ALL]`, `security_opt: [no-new-privileges:true]`.
- `.dockerignore` at the build context root.
- Rename image, container and network from `system-monitor*` to `sysplex*`.
- Keep `extra_hosts: host.docker.internal:host-gateway` — this single line is what makes
  ADR-0001's architecture work from inside a container.
- Keep the two-service split, the healthcheck, the resource limits and the log rotation.
  These are correct and unusual enough to be worth keeping.
- Delete the `Docker/` directory: its entrypoint is dead (the Dockerfile copies the root
  one), its README duplicates other docs, and its `.dockerignore` sits where Docker will
  never look for it.

Expected result: roughly 1 GB down to ~150 MB, with a build context in kilobytes.

## Consequences

**Good.** Faster builds, dramatically better layer caching, and a container that runs
unprivileged and read-only. The privilege removal is possible *only because* ADR-0001's
boundary was designed correctly — being able to explain that is worth more than the
flags ever were.

**Costs.** Dropping `lm-sensors` and the GPU tools means container-side collection loses
what little it could read, which forces the question ADR-0008 asks. The entrypoint's
GPU-detection banner becomes meaningless and should go with them.
