---
name: loom-doctor
description: Run read-only loom foundation diagnostics (host, tools, identity, repo state, init mode, coordination, protocol assets).
---

Thin Antigravity skill adapter. Read and follow the canonical skill contract at:
- `plugins/loom/skills/loom-doctor/SKILL.md`

Deterministic execution (fail-closed — never bypass):
1. Resolve helpers via `plugins/loom/bin/loom-resolve-helper antigravity <abs-skill-path> loom-doctor`.
2. Run the printed `loom-doctor` path (optionally `--json`); unchecked items are not passes.
