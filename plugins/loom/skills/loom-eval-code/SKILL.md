---
name: loom-eval-code
description: One-off blind review of an implemented slice's code.
---

# loom-eval-code

Run a single **code-evaluator** pass (blind), then stop.

**Installed-root bootstrap.** Resolve your installed plugin root through your
client's adapter contract (spec 10 → *Installed-root and helper binding*) before
reading `skills/loom-playbook/references/orchestration.md`; references below are
root-relative to that resolved root.

Target: the workflow argument (if empty, the next `Implemented` slice).

1. Gather the **blind inputs only**: the slice's commit diff, the slice-plan it was
   meant to satisfy, and the target spec(s). **No author/identity hint.**
2. Launch the **code-evaluator** role (Deep review profile). Run
   `bin/loom-launch-role <your-client> code-evaluator` — the sole client role
   launcher (spec 10 → *Versioned compatibility and capability mapping*) — to
   derive/validate the exact tier from the tracked compatibility matrix and
   enforce a fresh, one-level, non-delegating cold child (Codex: this performs
   the cold launch itself; Claude: launch natively per
   `roles/code-evaluator.md` / `agents/code-evaluator.md` using its printed
   configuration). Give it those blind inputs only.
3. The role **re-runs the gate** (doesn't trust the claim; when full `scripts/check`
   evidence is already bound to the exact reviewed commit, it runs fast static checks
   plus the slice's target `.bats` suite(s) with `TMPDIR=/private/tmp`, or
   `LOOM_BATS_JOBS=4 scripts/check` when a full rerun is required) and produces its
   verdict (PASS/FAIL + severity) to its confined scratch/output workspace, then
   returns — it does not write into `.docs/evaluations/`, set the status line, or
   commit. On Round >= 1, the evaluator verifies **only** that prior `Must Fix` items
   were resolved without regressions and must not invent new `blocking`/`high`
   findings on unchanged code. The recorder/root installs the verdict under
   `.docs/evaluations/<slice>-eval.md`, makes the status transition (**`Ready to
   Publish`** on PASS — a code-eval PASS does not by itself reach `Landed`;
   `In Progress` on FAIL), and commits author-neutral.
4. Verify the recorder's commit and the new status; report the verdict. On PASS
   (status now `Ready to Publish`), the next step is the developer's finalize pass
   (update `status/`, archive the plan) — run `loom-develop` in finalize mode or
   let `loom-run` handle it.
