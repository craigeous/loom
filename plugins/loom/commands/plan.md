---
description: One-off planning pass — advance an ADR, spec, or slice-plan
argument-hint: [what to plan]
---

# /loom:plan

Run a single **planner** pass, then stop. Read
`${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/references/orchestration.md` first.

Focus: `$ARGUMENTS` (if empty, advance the next thing per
`.docs/status/handoff.md` and `roadmap.md`).

1. Spawn `loom:planner` (Task tool) with the focus and current `.docs/` context
   (research, approved specs/ADRs, status).
2. The agent authors/revises an ADR, spec, or slice-plan from the playbook
   templates, sets `Status: Plan Review` (or `Draft` while working), and commits
   author-neutral. The planner is the sole writer of `spec/` and `ADR/`.
3. Verify the commit; report the artifact path and that it's ready for
   `/loom:eval-plan`.
