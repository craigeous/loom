---
name: loom-playbook
description: loom's canonical conventions — the .docs/ layout, artifact templates, evaluation rubrics, status machine, commit convention, and gate definitions. Use when an agent or the orchestrator needs the standard template, rubric, or convention to apply to a managed project, or when aligning/initializing a project to loom's patterns.
---

Thin Antigravity skill adapter. Read and follow the canonical skill contract at:
- `plugins/loom/skills/loom-playbook/SKILL.md`

Deterministic execution (fail-closed — never bypass):
1. Resolve helpers via `plugins/loom/bin/loom-resolve-helper antigravity <abs-skill-path> loom-coord`.
2. Validate role launches via `plugins/loom/bin/loom-launch-role antigravity <role>` before `define_subagent`/`invoke_subagent`.
3. Verify repository integrity via `node scripts/validate-repository.mjs --root <repo-root> --all`.
