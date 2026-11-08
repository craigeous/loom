# Evaluation: orca-host-adapter

Verdict: FAIL
Round: 1
Commit: 0d87c1f17edb4d83a967ad941a53213be1b114e2
Reviewed against: ADR 0032 §6, ADR 0034 §1, §2, §5, specs 07 and 10, research reference, and the plan-evaluation rubric.

## Summary

FAIL (round 1; BLOCKER: 0, MAJOR: 2, MINOR: 0). The revision addressed the follow-on disposition and fixture-equality findings, but the CLI evidence in the research authority needed alignment on `--limit` and command schemas, and `end` cleanup error handling needed strict fail-closed definitions for malformed JSON and unexpected show states.

## Findings

- [MAJOR] The supplied research says `terminal read` accepts `--lines`, while the plan uses `--limit`. It does not substantiate the plan’s `show` command, `--tab` flag, JSON shapes, stale-handle exit codes, or `operator_close` behavior. Embedding those claims in the plan does not independently verify them, so the Round 0 CLI-evidence finding remains open.
- [MAJOR] `end` does not explicitly fail closed on malformed JSON or define how to handle a successful `show` response that is neither connected nor marked `operator_close`. It also accepts a stale error without specifying the required exit code. Its tests omit malformed cleanup responses. The Round 0 error-handling finding therefore remains partly open.

## Required Changes

1. Supply reviewable Orca 1.4.250 evidence for the commands, flags, response shapes, and exit codes used by the plan. Resolve the `--lines` versus `--limit` discrepancy and align the implementation and stub tests with the verified interface.
2. Define and test `end` to accept only the verified cleanup confirmations and to exit 2 for malformed JSON, unexpected exit-code/error combinations, and every unrecognized cleanup state.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 0 | plan | FAIL | Initial plan lacked follow-on disposition for create/send/worktree, omitted research authority, had ambiguous exit 1 error handling, and phrased fixture equality as byte-equal. Resolved in Round 1 revision by scheduling `orca-live-probe`, defining fail-closed errors, aligning to deep-equal, and adding research note. |

## Notes

The plan explicitly schedules `orca-live-probe` before E4, and its fixture contract now consistently uses deep equality. `status` and `read`/`events` define fail-closed handling for non-stale CLI errors and JSON parse failures.
