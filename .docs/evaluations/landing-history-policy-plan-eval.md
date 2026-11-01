# Plan evaluation — landing-history-policy

Artifact: .docs/slice-plans/landing-history-policy.md
Reviewed against: plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md
Commit: 3e999e7
Round: 0
Verdict: PASS

## Summary

The revision (911af1b..3e999e7) resolves every Round 0 finding. The BLOCKER (conflict with spec 00's non-goal) is addressed by making the policy a "provisional default to test" and amending spec 00 to say the non-goal permits a provisional default while still prohibiting a frozen choice before benchmark evidence. This is consistent with improvement-plan lines 845-865, which call the choice "a reasonable default to test". Both MAJORs are resolved: file scope is definite, with the ADR target moved to 0028 (0026 and 0027 are noted as taken), and verification now uses named `rg` patterns with a negative diff check. The three MINORs are resolved: sequencing, tree-equivalence without slice-head ancestry, and a per-mode table. The plan is about 120 lines, under the 250 budget. It keeps `Target size:`, an `## Out of Scope & Threat-Model Boundary` section, and an in-place `## Revision Log` row. Per the counting rule this PASS resolves the Round 0 FAIL, so the round stays 0.

Scope: only the plan, its revision diff, the Round 0 eval, the rubric, improvement-plan lines 845-865, spec 00, and spec 04 were read. I did not inspect `scripts/validate-repository.mjs` or `severity.md`. No new issues were introduced beyond the non-blocking notes below.

## Findings

Round 0 resolution check:

1. **[BLOCKER] Spec 00 non-goal conflict — RESOLVED.** Context frames squash as a provisional experiment "subject to benchmark evidence and reassessment". The Files list and step 3 amend spec 00's non-goal wording. A `rg -i 'benchmark evidence'` oracle checks spec 00. Out of Scope states the policy does not freeze history before evidence.
2. **[MAJOR] Conditional file scope — RESOLVED.** All four files are listed unconditionally, each with its specific edit. Both authority lists get the ADR 0028 addition, and the README registration is required.
3. **[MAJOR] Non-mechanical oracles — RESOLVED.** Per-file `rg -i` phrase checks and an added-lines-only negative check for `--force`, `co-authored-by`, and role-attribution prefixes (exit 1 expected) are given. The negative check does not rely on reading alone.
4. **[MINOR] Sequencing — RESOLVED.** Step 2 orders ADR Plan Review, PASS, owner acceptance, then spec amendments as a new Plan Review cycle. Approved specs stay authoritative meanwhile, and the controlled-input path is required rather than bootstrap.
5. **[MINOR] Containment and ancestry — RESOLVED.** Step 3 defines integration and idempotent cleanup through the receipt-bound slice head and checked-tree equivalence instead of ancestry, and it fails closed when proof is unavailable.
6. **[MINOR] Mode coverage — RESOLVED.** Step 4 requires a mode table covering `remote-direct`, `pr-per-slice`, and `merge-queue`, with fail-closed behavior and no mode switching.

Non-blocking notes (not gating; no new findings are raised):

- **[NOTE]** The `validate-repository.mjs` command is carried over unchanged and I did not verify that it exists. The developer should confirm it runs before relying on it. `scripts/check` is the backstop.
- **[NOTE]** The `rg` loop runs sequentially and does not stop on the first failure. The developer should read each exit code, as the plan already says for the negative check.

## Rubric checks

| Check | Result |
|---|---|
| Line budget (`<= 250`) | Pass (about 120) |
| `Target size:` stated | Pass |
| `## Out of Scope & Threat-Model Boundary` present | Pass |
| Threat-model alignment | Pass |
| Revision Log, in-place revision | Pass |
| Single-purpose | Pass |
| Authority and spec consistency | Pass |
| Executable steps | Pass |
| Mechanical invariants / test oracles | Pass |
| Stop rules / out-of-scope creep | Pass |
