# Evaluation: Coordination State Separation

Verdict: FAIL
Round: 0
Reviewed against: ADR 0020; specs 00, 03 and 04; repository improvement plan M2; plan-eval rubric and severity; loom-coord and loom-land.

## Findings

- [BLOCKER] Steps 4 and 7b retain and explicitly require a tracked `.loom/candidate-manifest.json`. Spec 03, Candidate finalization and integrated evidence, explicitly requires the pre-publication candidate manifest to be local untracked recovery state, not a candidate artifact. The specified successful remote tree therefore violates the target spec.
- [BLOCKER] Step 4 makes finalization optional and supplies no finalizer or orchestrator invocation that produces the required archive, index, progress, handoff and roadmap changes. A normal publication without the option, or with the test's progress-only command, can succeed without those artifacts, contrary to ADR 0020 §1–2 and spec 03. Step 3 also allows an Active index entry on a slice branch, although spec 04 reserves final living-doc/index changes for the candidate.
- [BLOCKER] Step 7d requires a rejected publisher to rebuild and retry, but the existing helper sets `publishAttempt` before push and stops for owner action when the rejected candidate is not contained (loom-land, recovery and push paths). The plan gives no implementation step to resolve a positively established rejection safely; its test cannot pass as specified. Separately, the existing final re-fetch path calls `build` while holding the publish lock, contrary to ADR 0020 §2 and spec 04; the plan leaves that path unchanged.
- [MAJOR] The proposed finalizer has no defined determinism or failure/reuse tests. A changed command is included in the reuse key, but a nondeterministic or failed finalization can produce different candidate SHAs or leave recovery behavior unclear; the required candidate-bound evidence workflow needs a concrete repeatability and failure test.

## Required changes

1. Keep the manifest as untracked recovery state and update the remote-tree test to exclude it, consistent with spec 03.
2. Specify and wire deterministic candidate finalization for all required artifacts, with a fail-closed publication precondition and tests for missing/incomplete finalization; reserve index changes for the candidate.
3. Specify safe recovery from a proven rejected push, preserving uncertain attempts, and move rebuild and gate work outside the publish lock. Test both the rejection/rebuild path and lock scope.
4. Specify and test repeatable finalization, failure preservation, and changed-command candidate invalidation with fresh evidence.

## Notes

The plan has 153 lines, the prescribed sections and size budget, a coherent coordination/publication goal, a scoped threat boundary, named gate and targeted checks. Its non-force, independent verification, receipt and cleanup intentions are consistent with ADR 0020, but the listed gaps prevent approval. The mechanical `rg` check confirmed both named stale local-main instructions exist; no hostile private-directory race defenses are requested.

## Prior Rounds Summary

None; first review.
