---
name: loom-run
description: Run the loom dev loop — detect state, take scope/gates, drive the roles through the full research→plan→eval→develop→eval→land loop.
---

Thin Antigravity skill adapter. Read and follow the canonical skill contract at:
- `plugins/loom/skills/loom-run/SKILL.md`

Deterministic execution (fail-closed — never bypass):
1. Resolve helpers via `plugins/loom/bin/loom-resolve-helper antigravity <abs-skill-path> loom-coord`.
2. Validate role launches via `plugins/loom/bin/loom-launch-role antigravity <role>` before `define_subagent`/`invoke_subagent`.
3. Verify repository integrity via `node scripts/validate-repository.mjs --root <repo-root> --all`.
