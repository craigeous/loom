---
description: One-off blind review of an implemented slice's code
argument-hint: [slice]
---

# /loom:eval-code

Run a single **code-evaluator** pass (blind), then stop. Read
`${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/references/orchestration.md` first.

Target: `$ARGUMENTS` (if empty, the next `Implemented` slice).

1. Gather the **blind inputs only**: the slice's commit diff, the slice-plan it was
   meant to satisfy, and the target spec(s). **No author/identity hint.**
2. Spawn `loom:code-evaluator` (Task tool) with those inputs.
3. The agent **re-runs the gate** (doesn't trust the claim), writes
   `.docs/evaluations/<slice>-eval.md` (PASS/FAIL + severity), sets status
   (`Landed` on PASS, `In Progress` on FAIL — status line only), and commits
   author-neutral.
4. Verify the commit; report the verdict. On PASS, the next step is the developer's
   finalize pass (update `status/`, archive the plan) — run `/loom:develop` in
   finalize mode or let `/loom:run` handle it.
