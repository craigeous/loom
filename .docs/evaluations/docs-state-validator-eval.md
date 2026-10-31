# Docs State Validator Code Evaluation

Artifact: [Docs State Validator](../slice-plans/docs-state-validator.md)
Reviewed against: [slice plan](../slice-plans/docs-state-validator.md) and [code evaluation rubric](../../plugins/loom/skills/loom-playbook/references/code-eval-rubric.md)
Commit: b0ffbae
Round: 0
Verdict: FAIL

## Summary

The implementation adds documentation-state validation, but does not enforce several required lifecycle, round, and authority invariants. The ADR 0016 change is limited to the authorized link.

## Findings

- [BLOCKER] `reachable()` (scripts/validate-repository.mjs:781) traverses any number of arrows, so a baseline Draft can jump directly to Approved or Implemented without evidence of intermediate transitions; it also lets Needs Clarification restore any nonterminal status instead of its prior status. `validateBaseline()` does not inspect FAIL evidence and accepts Ready to Publish directly into the archive. Enforce the prescribed transitions and restoration with sufficient history, and report ambiguity when it cannot be established.
- [BLOCKER] Evaluation sequencing (scripts/validate-repository.mjs:904-922) skips singleton groups entirely, never requires the first round to be 0, accepts arbitrary increases because it only rejects rounds below the expected value, and accepts any `Owner-Reset:` value as a reset. It also treats every FAIL as a merits failure and falls back to file-addition history when reviewed commit evidence is absent or invalid. Enforce exact round progression, classify supported non-merits events and validate reset evidence; report missing or ambiguous ordering rather than inventing it.
- [BLOCKER] Authority checks (scripts/validate-repository.mjs:849-899) accept any existing `.docs/` link for an ADR, do not require both applicable research/problem and accepted prior authority, and accept merely existing rather than approved/accepted plan targets. Evaluations need only an `Artifact:` or `Reviewed against:` field, even if empty or unrelated, and body identification is not supported. Validate the required applicable references and their statuses, including evaluation artifact and authority identification.
- [BLOCKER] Historical link allowlist stale checking (scripts/validate-repository.mjs:610) skips records whose source is no longer scanned, so deleted or renamed sources leave unused entries undetected under `--all`. Report every unused historical record in `--all`, while retaining `--links` behavior.
- [BLOCKER] Plan identity validation (scripts/validate-repository.mjs:832-839) rejects one active plan whenever an archived plan shares its normalized identity, although the plan requires only one active plan per slice. Count active plans only, preserving archived historical evidence.

## Gate

`TMPDIR=/private/tmp LOOM_BATS_JOBS=4 perl -e '$SIG{INT}="DEFAULT"; exec @ARGV' scripts/check` passed, including all 848 Bats cases. This matches the recorded gate evidence; the gate does not cover the defects above.
