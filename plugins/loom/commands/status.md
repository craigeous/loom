---
description: Print a summary of loom's .docs/ state for this repo
argument-hint:
---

# /loom:status

Scan and report — no agents, no writes. Read
`${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/references/status-machine.md` for the
statuses.

1. Determine init mode (is there a loom-shaped `.docs/`?).
2. Scan `.docs/` for gated artifacts and their `Status:` lines (research, ADR, spec,
   slice-plans, evaluations), plus `git status`/`git log`.
3. Print a summary: init mode; roadmap target (from `.docs/status/roadmap.md`);
   in-flight artifacts by status; what the dispatch table says the next action is;
   any blockers or round-limit escalations; working-tree cleanliness.
4. Stop. Do not change anything.
