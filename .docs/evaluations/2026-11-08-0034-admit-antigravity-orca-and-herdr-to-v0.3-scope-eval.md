# Plan Evaluation: 0034-admit-antigravity-orca-and-herdr-to-v0.3-scope

Artifact: [0034-admit-antigravity-orca-and-herdr-to-v0.3-scope](../ADR/0034-admit-antigravity-orca-and-herdr-to-v0.3-scope.md)
Commit: 745a8a2
Round: 2
Verdict: FAIL
Reviewed against: [ADR 0031](../ADR/0031-herdr-as-an-hc-driven-client.md), [ADR 0032](../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md), [ADR 0033](../ADR/0033-narrow-v0.3-scope-and-retire-macos-checkpoint-tooling.md), [hc runtime reference](../research/2026-11-01-hc-agent-runtime-reference.md), [Orca and Antigravity runtime reference](../research/2026-11-08-orca-and-antigravity-runtime-reference.md), and [plan-eval rubric](../../plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md).

## Summary

The revised dispositions add the identified harness work, and E3 now names parity, guards, and refusal coverage. The explicit host-only supersession provides a path for Herdr and Orca while retaining the hc evaluator prohibition and live-probe gate. Both model families must resolve deterministically, with fail-closed handling for either unknown family or equal families. However, the release evidence plan still conflicts with the required post-tag, commit-bound record.

## Findings

- [MAJOR] Release evidence still lacks the required post-tag commit binding: The revised E5 adds owner sign-off but requires all E1–E5 before the tag and says the record is published atomically with it. ADR 0032 §3 instead requires E4–E5 in an immutable record written after the candidate is tagged, naming the full tagged commit hash and each pair's runs and owner acknowledgement, in a descendant commit on main. The revision neither specifies that binding and ordering nor supersedes them; its pre-tag requirement conflicts with them. E4 also omits the required per-pair run records with results and log or journal references, and the full loop's blind-review and committed-handoff criteria. Thus the first Round 1 finding remains unresolved.

## Required changes

1. Restore ADR 0032 §3's per-pair E4 recording and blind full-loop requirements and its post-tag, immutable, commit-bound E4–E5 evidence record, including the owner acknowledgement and publication verification; reconcile the pre-tag and atomic-publication wording with that sequence.

## Notes

- The revised dispositions add the identified harness work, and E3 now names parity, guards, and refusal coverage.
- The explicit host-only supersession provides a path for Herdr and Orca while retaining the hc evaluator prohibition and live-probe gate.
- Both model families must resolve deterministically, with fail-closed handling for either unknown family or equal families.
