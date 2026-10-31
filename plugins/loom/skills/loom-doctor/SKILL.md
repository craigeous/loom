---
name: loom-doctor
description: Run read-only loom foundation diagnostics (host, tools, identity, repo state, init mode, coordination, protocol assets) — human or --json output.
---

# loom-doctor

Read-only diagnostics — no agents, no writes, no repair.

**Installed-root bootstrap.** Resolve the `loom-doctor` helper through your client's
installed-root binding (spec 10 → *Installed-root and helper binding*):
`loom-resolve-helper claude loom-doctor` (Claude), or
`loom-resolve-helper codex <abs-path-to-this-SKILL.md> loom-doctor` (Codex). The
resolver prints the absolute helper path; invoke that path yourself.

1. Run the resolved `loom-doctor` from the repository being diagnosed, with no
   argument for the human report or `--json` for the machine report
   (`schemas/loom-doctor-report-v1.schema.json`).
2. Relay the output and exit status (0 pass or warning, 1 error, 2 invalid use).
3. Items marked `unchecked` (client adapter, hook trust, egress sandbox) were not
   evaluated. Never describe them as passing, and never state a client-support or
   release-conformance conclusion from this report.
