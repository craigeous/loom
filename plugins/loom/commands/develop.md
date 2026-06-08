---
description: One-off development pass — implement an approved slice-plan
argument-hint: [slice]
---

# /loom:develop

Run a single **developer** pass, then stop. Read
`${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/references/orchestration.md` first.

Target: `$ARGUMENTS` (if empty, the next `Approved` slice-plan).

1. Spawn `loom:developer` (Task tool) with the slice-plan path and target specs.
2. The agent sets `In Progress`, implements exactly the plan's scope, runs the full
   gate (format → lint → test), records evidence, sets `Implemented`, and commits
   author-neutral (a clean single-slice commit — the code evaluator reads its diff).
   If the plan is wrong/ambiguous it stops, leaves a `## Notes` question, sets
   `Needs Clarification` — it never edits specs/ADRs.
3. Verify the commit and resulting status; report readiness for `/loom:eval-code`.
