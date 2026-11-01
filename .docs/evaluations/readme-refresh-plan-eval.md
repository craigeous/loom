# Plan Evaluation: readme-refresh

Artifact: .docs/slice-plans/readme-refresh.md
Reviewed against: plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md
Commit: 215455a
Round: 0
Verdict: PASS

## Summary

The plan is a single-purpose, README-only documentation slice. It targets specs 00 and 10, declares `Target size: <= 120 LOC net change` and is 86 lines (limit 200). All six required sections are present in canonical order, and the Revision Log is a compact table. Its four steps cover every required README area: status/milestone, environments/prerequisites, install and upgrade for the three clients, the example, managed-repo files including transient `<git-common-dir>/loom/`, tier cost/time expectations, and the 833 → 886 update. Verification names the gate (`scripts/check`), a fast check (`node scripts/validate-repository.mjs --root . --all`, `git diff --check`), and an `rg` invariant check. No BLOCKER or MAJOR findings; three MINOR items are below.

Checks performed:
- Size: 86 lines (<= 200); net-LOC target 120 stated.
- Sections present: Context, Out of Scope & Threat-Model Boundary, Steps, Verification, Notes, Revision Log.
- `scripts/validate-repository.mjs` exists; README currently has `Current milestone: M7` (line 35) and 833 at lines 107 and 175, matching Step 4 ("both 833-test references").
- Tier mapping in Step 4 (Economy→researcher, Standard→developer/orchestrator, Deep review→planner and evaluators) matches spec 02 lines 50-55.
- Threat-model boundary honors spec 00 non-goals; the plan does not overclaim private dogfood or Antigravity.

## Findings

1. **[MINOR] Antigravity has no authority in specs 00/10.** Step 2 asks for Antigravity install/refresh instructions via `.agents/skills/`, but neither spec 00 nor spec 10 mentions Antigravity (it appears only in README and ADR 0027). The plan hedges ("label unverified if release evidence is absent") and the improvement plan requires the instructions, so this is not blocking. A developer should anchor the wording to ADR 0027 and the existing README text rather than invent claims.

2. **[MINOR] Verification is partly eyeball-based.** The `rg` command only lists matches. The invariant "no stale 833" is not asserted mechanically. Suggest `! rg -n '833' README.md` and `rg -c '886' README.md` (expect 2), plus an `rg` for the three tier names, so the check can fail. Link resolution is stated as "check README links resolve" without a tool, although the repository validator may already cover it. Also, the 886 figure is not tied to a command, e.g. a `bats --count` run to confirm it at implementation time.

3. **[MINOR] Step 4's time/cost clause is conditional.** "Only if supported by reproducible evidence; otherwise say no reliable estimate is established" is acceptable and honest, but the developer must choose a branch. The plan could state the default branch (no estimate, list factors) to avoid ambiguity. Step 2 similarly says to "derive" command syntax from fixtures and the dogfood harness without naming the files, so a cold reader must search for them (`plugins/loom/adapters/fixtures`, `scripts/macos-dual-client-dogfood`).
