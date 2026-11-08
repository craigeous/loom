# Evaluation: orca-host-adapter

Verdict: FAIL
Round: 0
Commit: 36de18ba351a19b238bc6dd377a5210ce23b15b0
Reviewed against: ADR 0032 §6, ADR 0034 §1, §2, §5, specs 07 and 10, and the plan-evaluation rubric.

## Summary

FAIL (round 0; BLOCKER: 1, MAJOR: 2, MINOR: 1). The plan provides observation and cleanup only without an explicit follow-on disposition for create/send/worktree isolation; the review authority omitted verified CLI evidence; error handling for stale vs non-stale CLI failures was ambiguous; and descriptor-fixture equality was phrased as byte-equal while validator checks deep equality.

## Findings

- [BLOCKER] ADR 0032 §6 and ADR 0034 §1 and §5 call for Orca terminal lifecycle integration, including create, send, and worktree isolation. The plan provides observation and cleanup only, with no concrete follow-on disposition for the missing primitives. Its unconditional launch refusal preserves the requested no-role-launch boundary, but leaves the required integration unfinished.
- [MAJOR] The supplied authority does not establish the proposed Orca 1.4.250 flags, JSON shapes, exit codes, or `operator_close` behavior. The plan cites runtime research, but that file is outside the permitted review inputs. The sketches and stub assertions therefore cannot be verified against the real CLI in this review.
- [MAJOR] Error handling is ambiguous or can misreport failure: `status` treats every exit 1 as a stale handle, `end` accepts exit 1 as proof of cleanup, and `read`/`events` specify exit 0 without defining how CLI or JSON parsing failures are handled.
- [MINOR] The plan requires the Orca fixture to be byte-equal to its descriptor, but the validator checks deep equality, which does not establish byte equality.

## Required Changes

1. Specify a concrete, file-scoped disposition for create, send, and worktree isolation consistent with the no-role-launch boundary, or identify an authoritative follow-on slice that delivers them before conformance.
2. Supply verifiable Orca 1.4.250 command and response evidence within the permitted review inputs; align the commands and stub assertions with it.
3. Define and test fail-closed behavior for non-stale CLI failures and malformed responses, including cleanup verification and read failures.
4. Mechanically check the stated byte-equality invariant, or change the invariant to deep equality if that is the intended contract.

## Notes

The plan is within 250 lines and states a target of at most 380 added LOC. Its proposed unconditional launch refusal prevents role launch, while its stated evaluator boundary keeps evaluation outside Orca terminals.
