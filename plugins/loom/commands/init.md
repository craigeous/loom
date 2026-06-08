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
   **Unaligned:** scaffold per `greenfield.md` **plus** descriptive back-fill of
   `spec/` mapping what the project currently is (no decisions). Unaligned
   back-fill behavior is a forward pointer to the forthcoming M2 slice
   *unaligned-init-behavior*; do not author the back-fill body here.
3. **Initialized:** re-apply the current playbook idempotently — auto-apply clean
   merges, recommend for conflicts and let the owner decide. Never clobber project
   edits.
4. Report what was created/changed and the next step (usually `/loom:run`).
