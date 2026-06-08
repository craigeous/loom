---
description: One-off blind review of a research note or planning artifact
argument-hint: [artifact path]
---

# /loom:eval-plan

Run a single **plan-evaluator** pass (blind), then stop. Read
`${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/references/orchestration.md` first.

Target: `$ARGUMENTS` (if empty, the next artifact at `Plan Review` or
`Research Review`).

1. Gather the **blind inputs only**: the artifact and its authority (slice-plan →
   spec(s)+ADRs; spec → ADRs; ADR → research/problem; research note → its cited
   sources). **Do not pass any author/identity hint.**
2. Spawn `loom:plan-evaluator` (Task tool) with those inputs.
3. The agent writes `.docs/evaluations/<name>-eval.md` (PASS/FAIL + severity
   findings), sets the artifact status (`Approved` on PASS, `Draft` on FAIL —
   status line only), and commits author-neutral.
4. Verify the commit; report the verdict and resulting status.
