# Evaluation: remote-first-integration-candidate

Verdict: FAIL
Round: 0
Reviewed against: slice plan, ADR 0020, repository improvement plan, code-eval rubric and severity; diff 68a63a5..7fab97f.

## Findings

- [BLOCKER] Recovery can release a claim using an unrelated receipt. `loom-land:117-118,241-250` treats any existing session receipt as sufficient, without checking its candidate or bindings, and skips writing a new one. Reusing a session for another slice after the new candidate reaches the remote can therefore report success and release its claim while only the old slice's receipt exists. Validate the existing receipt against the current publication or replace it with a verified current receipt.
- [BLOCKER] Recovery writes the receipt without acquiring or verifying the publish lock (`loom-land:241-250`); concurrent same-clone publishers can therefore mutate protected receipt state without ownership. When the remote has advanced beyond the candidate, it also records the candidate as `resultSha` instead of the actual fetched target, misrepresenting remote truth. Acquire and verify the lock, refresh remote truth and record the observed target before writing the receipt.
- [BLOCKER] An uncertain prior push is not preserved for recovery when the target does not contain the recorded candidate: `loom-land:239-254` proceeds to build, and `build` overwrites the candidate ref and state at lines 199-201. For example, a push that succeeded but whose verification failed, followed by a remote reset, loses the original recovery evidence and can lead to a new publication rather than stopping for owner action. Distinguish an outstanding publication attempt and fail closed when containment cannot be established, preserving its evidence.
- [BLOCKER] Verification reads the fetch URL, not necessarily the push destination. Git permits a configured `remote.<name>.pushurl` distinct from the fetch URL; `push` at line 276 and `ls-remote` at line 277 then address different repositories. A rejected push can nevertheless be reported as verified if the fetch repository already contains the candidate, or a successful push can be reported unverified. Validate that publication and independent verification address the same target, or verify the actual push destination.
- [MAJOR] Required failure coverage is incomplete: the tests do not exercise stale receipts across slices, remote advancement during recovery, uncertain-push state preservation, distinct push URLs, receipt write failure, or separate-clone racing publishers. These are material to the specified recovery and remote authority guarantees.
- [MAJOR] Unhandled operational failures under `set -e` (for example failed worktree creation, `update-ref`, or manifest commit at lines 184-200) propagate Git's usual exit 1, which is documented as a usage error rather than operational failure 10. Map these failures to the documented codes while retaining the claim and state.

## Required changes

1. Bind and validate receipts for the current candidate and inputs; protect recovery receipt writes with the verified lock and record fresh remote truth.
2. Preserve unresolved publication attempts and stop for owner action when containment cannot be proved.
3. Verify the actual push destination and map operational failures to exit 10; add focused regression tests for these paths and separate-clone contention.

## Notes

The candidate-only path, evidence syntax checks, ordinary non-force push and initial independent ref read were reviewed. No review-findings artifact was supplied at the conventional path, so no finder findings were adjudicated. The gate rerun result is recorded below.

Gate rerun: `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check` exited 0; 568/568 Bats tests passed and all checks passed.
