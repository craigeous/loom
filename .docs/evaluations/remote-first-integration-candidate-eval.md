# Evaluation: remote-first-integration-candidate

Verdict: FAIL
Round: 1
Reviewed against: Round 0 findings, slice plan, ADR 0020, code-eval rubric and severity; diff 7fab97f..a7c5d86.

## Findings

- [BLOCKER] Recovery still verifies the fetch destination rather than the push destination. `loom-land:169-171,252-272` fetches `$REMOTE` even when `remote.<name>.pushurl` differs; a candidate present in the fetch repository but absent from the push repository can be receipted as landed and its claim released. Conversely an actual successful push to the push destination cannot be recovered if absent from the fetch destination. Verify recovery against the actual publication destination or reject differing destinations.
- [BLOCKER] Recovery accepts a receipt based only on slice, session and candidate (`loom-land:260`), without validating the other publication bindings or receipt schema. A same-candidate receipt for another target, evidence, or malformed receipt can authorize claim release. Validate the receipt against the current publication and its required bindings before using it.
- [BLOCKER] A failed push is treated as a clean rejection whenever the observed target differs from the base (`loom-land:306-308`). A push can succeed remotely but return failure due to lost acknowledgement, and the target can subsequently advance; clearing `publishAttempt` then permits the prior candidate and evidence to be overwritten on retry. Preserve the attempt unless rejection is positively established.
- [MAJOR] The required failure coverage remains incomplete: the revision adds several focused cases, but no receipt-write failure or competing loom-land publishers in separate clones. Add these regression cases, including recovery against the actual push destination.
- [MAJOR] Operational failures are still not consistently mapped to exit 10: `mkdir -p "$SDIR"` in main and `write_state` remains unguarded under `set -e` (`loom-land:177,247`), returning exit 1 on failure. Map these failures to operational failure while retaining claim and evidence.

## Required changes

Resolve the remaining recovery destination and receipt binding errors, preserve uncertain push attempts, complete the required failure coverage, and map remaining operational errors to exit 10.

## Prior Rounds Summary

Round 0 failed on unrelated receipts, unlocked recovery and stale result SHA, lost uncertain-push evidence, verification against the fetch URL, missing failure coverage, and operational exit codes. This revision adds recovery locking and refreshed result SHA, several regression tests, and explicit error mapping for candidate construction; the findings above identify what remains unresolved.

## Notes

No review-findings artifact was supplied in Round 0. Gate rerun result follows.

Gate rerun: `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check` exited 0; 576/576 Bats tests passed and all checks passed.
