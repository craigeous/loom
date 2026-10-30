# Evaluation: Coordination State Separation

Verdict: FAIL
Round: 1
Reviewed against: ADR 0020; specs 00, 03 and 04; plan-eval rubric and severity; loom-coord and loom-land; revision eceb427..0bbc366.

## Findings

- [BLOCKER] Step 7's positive-rejection predicate includes a remote descendant of the candidate: such a remote is not contained in the candidate and descends from the base. A push can report failure after the server accepted it and another publisher advanced the target. Resetting `publishAttempt` in that case permits rebuilding and republishing a slice already contained in the target. Preserve the attempt and use the existing containment recovery when the candidate is an ancestor of the observed remote; fail closed if ancestry cannot be established.
- [BLOCKER] Step 5 checks `.docs/roadmap.md`, but the required living roadmap is `.docs/status/roadmap.md`. The test finalizer follows the same wrong path, so publication can leave the actual roadmap unchanged while satisfying the check. Check and update the actual path.
- [MAJOR] Step 5 fixes only the finalization commit's metadata; the existing `build()` creates the preceding merge commit with current commit metadata. Deleting state and rebuilding at a later time therefore produces a different merge parent and candidate SHA, contradicting test 8e and the repeatability requirement. Specify deterministic metadata for the merge commit too.

## Required changes

1. Exclude candidate-contained remote results from rejection recovery, preserve uncertain attempts, and test a failed push followed by a remote descendant containing the candidate.
2. Use `.docs/status/roadmap.md` in the completeness check and test finalizer.
3. Make the merge commit deterministic as well as the finalization commit, and test rebuilding across different times.

## Notes

The diff moves the manifest out of the candidate tree, reserves living-doc changes for the candidate, requires and checks finalization, moves rebuild and gate outside the lock, and adds failure, reuse and contention tests. Those resolve the manifest and lock-scope portions of the prior findings; finalization completeness, deterministic rebuilding, and safe rejected-push recovery remain deficient as described above. No new goalposts outside the revision diff are raised.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 0 | plan | FAIL | Manifest fixed by step 4; finalization and index addressed by steps 3 and 5 but roadmap path remains wrong; lock scope fixed by step 6 but rejection recovery remains unsafe; repeatability/failure/reuse tests added in step 8 but merge metadata remains nondeterministic. |
