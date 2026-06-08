---
description: Initialize or align this repo to loom's conventions
argument-hint:
---

# /loom:init

Set up (or re-align) this repo for loom, then stop. Read
`${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/references/orchestration.md` (Init-mode
detection) and `docs-layout.md`.

1. Detect init mode: Greenfield / Unaligned / Initialized.
2. **Greenfield/Unaligned:** scaffold `.docs/` per `docs-layout.md`, apply the
   playbook (seed `CLAUDE.md`, establish the gate — Rust verified; for another
   stack identify the tooling, propose commands, confirm with the owner, and record
   a new `gates/<stack>.md`). For Unaligned, also descriptively back-fill `spec/`
   mapping what the project currently is (no decisions). Seed `status/`. Commit
   author-neutral.
3. **Initialized:** re-apply the current playbook idempotently — auto-apply clean
   merges, recommend for conflicts and let the owner decide. Never clobber project
   edits.
4. Report what was created/changed and the next step (usually `/loom:run`).
