---
name: loom-planner
description: Codex cold-subagent binding for loom's planner role — turns intent and research into ADRs, specs, and slice-plans. Launched only by the root orchestrator through loom-run; never self-invoked.
---

Thin Antigravity skill adapter. Read and follow the canonical skill contract at:
- `plugins/loom/skills/loom-planner/SKILL.md`

Deterministic execution (fail-closed — never bypass):
1. Resolve helpers via `plugins/loom/bin/loom-resolve-helper antigravity <abs-skill-path> loom-coord`.
2. Validate role launches via `plugins/loom/bin/loom-launch-role antigravity <role>` before `define_subagent`/`invoke_subagent`.
3. Verify repository integrity via `node scripts/validate-repository.mjs --root <repo-root> --all`.
