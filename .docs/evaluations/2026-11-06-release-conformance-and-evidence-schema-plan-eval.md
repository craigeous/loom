# Plan Evaluation: release-conformance-and-evidence-schema

Artifact: [release-conformance-and-evidence-schema](../slice-plans/release-conformance-and-evidence-schema.md)
Commit: 0e4a678
Round: 1
Verdict: FAIL
Reviewed against: [ADR 0032](../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md), [ADR 0033](../ADR/0033-narrow-v0.3-scope-and-retire-macos-checkpoint-tooling.md), [spec 10](../spec/10-packaging.md), [spec 07](../spec/07-command-surface.md), and [plan-eval rubric](../../plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md).

## Summary

The revision resolves the schema pair and release bindings and retains Bash 5.x verification. It removes spec edits from implementation but explicitly makes approval dependent on a sibling spec amendment that does not yet exist. The archive now has a location, manifest and hash contract, but the promised verification commands are absent. D-d's local Bash 5.x run and D-e's per-pair upgrade are reasonable subject to the approved amendment.

## Findings

1. **[BLOCKER] The required spec amendment is not approved.** The revised Context says `spec-10-07-release-evidence-amendment` must reach Approved before this slice can move to Approved, and that it has not been written. The existing specs do not define the proposed evidence format. Prepare and obtain cold plan evaluation of the amendment, then reconcile this plan with the approved authority before approval. This resolves the direct-edit portion of Round 0 finding 1 but not its prerequisite.

2. **[MAJOR] Archive verification instructions are missing.** The new archive contract defines a manifest and hash relationships, but Step 5 asks for three archive commands supposedly in Context; Context gives only manifest generation, not commands for verifying extracted files and comparing record log hashes and `ownerAck.evidenceSet` to the manifest. Thus an independent developer cannot implement the promised secret-free verification instructions from the plan. Specify executable verification commands or an equally concrete procedure covering all three comparisons. This leaves Round 0 finding 5 partially unresolved.

## Prior Rounds Summary

Round 0 findings 2 and 3 are resolved by exact cardinality, harness bindings, v0.2.0 constants and negative tests. Finding 4 is resolved by required Bash 3.2 and Bash 5.x runs and record entries. Finding 1's implementation-slice spec edits are removed; its approved amendment prerequisite remains outstanding. Finding 5's archive location, layout and hash input are defined; verification instructions remain incomplete.
