---
description: Run read-only loom foundation diagnostics for this environment and repo
argument-hint: "[--json]"
---

# /loom:doctor

Load and follow the `loom-doctor` skill at
`${CLAUDE_PLUGIN_ROOT}/skills/loom-doctor/SKILL.md` exactly, treating its
root-relative references as relative to `${CLAUDE_PLUGIN_ROOT}`. Read-only — no
agents, no writes.
