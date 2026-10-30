# Evaluation: coordination-state-separation

Verdict: FAIL
Round: 0
Reviewed against: coordination-state-separation slice plan, ADR 0020, specs 00, 03 and 04, code-eval rubric and severity reference; commit 8c52938.

## Findings

- [BLOCKER] Target movement triggers an immediate rebuild and gate after releasing the lock (`plugins/loom/bin/loom-land:349`–353). The approved plan explicitly requires exit 3 with state kept and the rebuild deferred to the next run. Besides violating the specified transition, a failing rebuild can change the required contention exit into an operational error and alter candidate state.
- [BLOCKER] A successful push followed by a different remote tip containing the candidate is treated as a successful containment recovery (`plugins/loom/bin/loom-land:373`–380). The plan reserves that recovery for a failed push and explicitly requires push-success/remote-differs to remain uncertain with exit 10 and attempt preserved. Restrict immediate containment recovery to rejected pushes.

## Required changes (for FAIL)

1. On a moved target, release the lock and exit 3 without rebuilding; rebuild and gate on the next invocation. Update the contention tests to assert that transition.
2. Require a failed push for immediate containment recovery; preserve the attempt and return 10 when a successful push observes a different tip. Add a test for that case.

## Notes

The manifest is stored in the session directory; finalization checks the archive, active plan removal and four changed status/index paths, and deterministic metadata is derived from the slice head. The mechanical search `rg -n 'Active region on main|from current local .main.' plugins/loom` returned no matches. No review-findings artifact was supplied for adjudication.

`node scripts/validate-repository.mjs --root /Users/craig/git/loom --all`: passed (repository validation; no test count). `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`: passed, including 596 Bats tests (596 passed, 0 failed), formatting, lint, syntax, links, plugin validation and whitespace checks.

## Prior Rounds Summary

None.
