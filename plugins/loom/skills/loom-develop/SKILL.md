---
name: loom-develop
description: One-off development pass — implement an approved slice-plan.
---

# loom-develop

Run a single **developer** pass, then stop.

**Installed-root bootstrap.** Resolve your installed plugin root through your
client's adapter contract (spec 10 → *Installed-root and helper binding*) before
reading `skills/loom-playbook/references/orchestration.md`; references below are
root-relative to that resolved root.

Target: the workflow argument (if empty, the next `Approved` slice-plan).

1. Launch the **developer** role (Standard profile). Run
   `bin/loom-launch-role <your-client> developer` — the sole client role
   launcher (spec 10 → *Versioned compatibility and capability mapping*) — to
   derive/validate the exact tier from the tracked compatibility matrix and
   enforce a fresh, one-level, non-delegating cold child (Codex: this performs
   the cold launch itself; Claude: launch natively per `roles/developer.md` /
   `agents/developer.md` using its printed configuration). Give it the
   slice-plan path and target specs.
2. The role sets `In Progress`, implements exactly the plan's scope, iterates with
   fast targeted checks (`shfmt`, `shellcheck`, `bats --filter` on the touched suite
   with `TMPDIR=/private/tmp` on macOS) before running the full gate once on the
   candidate (`TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`), records evidence,
   sets `Implemented`, and commits author-neutral (a clean single-slice commit — the
   code evaluator reads its diff). On Round >= 1 remediation, the developer fixes
   **only** the `Must Fix (Round-0 Blocking Checklist)` items from the evaluation and
   adds at most 1 regression test per blocker — never expanding state machines or test
   matrices beyond the plan. If the plan is wrong/ambiguous it stops, leaves a
   `## Notes` question, sets `Needs Clarification` — it never edits specs/ADRs.
3. Verify the commit and resulting status; report readiness for `loom-eval-code`.
