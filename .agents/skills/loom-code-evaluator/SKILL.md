---
name: loom-code-evaluator
description: Codex cold-subagent binding for loom's code-evaluator role — blind, critical review of implemented code against its plan, with a mandatory gate rerun. Launched only by the root orchestrator through loom-run; never self-invoked.
---

Thin Antigravity skill adapter. Read and follow the canonical skill contract at:
- `plugins/loom/skills/loom-code-evaluator/SKILL.md`

Deterministic execution (fail-closed — never bypass):
1. Resolve helpers via `plugins/loom/bin/loom-resolve-helper antigravity <abs-skill-path> loom-coord`.
2. Validate role launches via `plugins/loom/bin/loom-launch-role antigravity <role>` before `define_subagent`/`invoke_subagent`.
3. Verify repository integrity via `node scripts/validate-repository.mjs --root <repo-root> --all`.
