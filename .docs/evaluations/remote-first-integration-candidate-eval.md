# Evaluation: remote-first-integration-candidate

Verdict: FAIL
Round: 2
Reviewed against: Round 1 findings, slice plan, ADR 0020, code-eval rubric and severity; diff a7c5d86..2ae737a.

## Findings

- [MAJOR] The Round 1 requirement for competing `loom-land` publishers in separate clones remains unmet. The new separate-clone race in `plugins/loom/bin/loom-land.bats` uses a plain `git push` from the other clone, so it does not exercise two Loom publication processes, their independent session state and competing publication behavior. Add a regression exercising competing `loom-land` publishers in separate clones, checking the winning remote result and the loser's preserved claim and state.

## Required changes

Complete the separate-clone competing Loom publisher regression required in Round 1.

## Prior Rounds Summary

Round 0 failed on recovery, uncertain publication, verification, failure coverage, and operational exit mapping. Round 1 retained three blockers and two majors. This revision verifies recovery against the push destination, validates the listed receipt bindings, preserves `publishAttempt` after failed pushes, adds receipt-write and push-destination recovery coverage, and maps session-directory creation failures to exit 10. The separate-clone test covers an external Git publisher but does not resolve the prior requirement for competing Loom publishers.

## Notes

Gate rerun: `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check` exited 0; 582/582 Bats tests passed and all checks passed.
