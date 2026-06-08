---
description: Initialize or align this repo to loom's conventions
argument-hint:
---

# /loom:init

Set up (or re-align) this repo for loom, then stop. Read
`${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/references/orchestration.md` (Init-mode
detection) and `docs-layout.md`.

1. Detect init mode by running the classifier in
   `${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/references/init-detection.md`
   (Greenfield / Unaligned / Initialized).
2. **Greenfield:** run the scaffold/seed/gate body in
   `${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/references/greenfield.md`. Commit
   author-neutral.
   **Unaligned:** run the alignment body in
   `${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/references/unaligned.md` — study
   the repo, scaffold + gate (per `greenfield.md`), descriptively back-fill
   `spec/` (no decisions), seed `status/`; leaves the repo ready to resume as
   Initialized. Commit author-neutral.
3. **Initialized:** resume per
   `${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/references/initialized.md` —
   present the state-derived menu, then re-apply the current playbook
   idempotently (auto-apply clean merges, recommend for conflicts, never
   clobber). Commit author-neutral if re-application writes anything.
4. Report what was created/changed and the next step (usually `/loom:run`).
