---
description: One-off research pass — gather cited context into .docs/research/
argument-hint: <topic>
---

# /loom:research

Run a single **researcher** pass, then stop (no chaining). Read
`${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/references/orchestration.md` for the
core rules.

Topic: `$ARGUMENTS` (if empty, infer the open need from `.docs/status/handoff.md`).

1. Spawn `loom:researcher` (Task tool) with the topic and where to look.
2. The agent writes a **cited** note to `.docs/research/<date>-<slug>.md`
   (`Status: Research Review`) and commits author-neutral.
3. Verify the commit landed and is author-neutral; report the note path and that
   it's ready for `/loom:eval-plan`.
