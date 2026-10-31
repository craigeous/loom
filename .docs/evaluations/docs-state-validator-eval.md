# Docs State Validator Code Evaluation

Artifact: [Docs State Validator](../slice-plans/docs-state-validator.md)
Reviewed against: [slice plan](../slice-plans/docs-state-validator.md) and [code evaluation rubric](../../plugins/loom/skills/loom-playbook/references/code-eval-rubric.md)
Commit: e0fb6c78
Round: 1
Verdict: FAIL

## Summary

The revision validates reset fields on singleton and multi-event groups and improves phase and ancestry checks for FAIL returns. Two blockers remain in transition evidence and authority validation.

## Findings

- [BLOCKER] FAIL evidence is not bounded by the return transition. `failEvidence()` accepts any matching reviewed commit descended from the rejected status and reachable from HEAD (scripts/validate-repository.mjs:1072-1084), including a commit after the return to Draft or In Progress, or a later review cycle. Such a future FAIL can justify an earlier return. Require the reviewed commit to be ordered within the specific rejected-status interval, or report ambiguity.
- [BLOCKER] Authority identification still accepts references that do not resolve to applicable targets. `checkEvaluationIdentification()` treats bare `spec 99`, `research notes`, `rubric`, or `slice plan` as sufficient without resolving them (scripts/validate-repository.mjs:924-931), and accepts any resolved file under broad roots such as `scripts/` or `.docs/status/` as authority. ADR grounding likewise accepts any approved or accepted top-level `.docs/*.md` as a problem document (line 877), regardless of its actual purpose. Require a resolvable applicable authority and a problem document or approved research as specified.

## Re-review of Round 0

Reset validation now applies to every event, requires Round 0, an owner decision, the artifact identity, materially new direction and reset language. FAIL evidence now checks phase and ancestry, but lacks an upper bound tying it to the particular transition. Authority checks reject several previously accepted mismatches, but the remaining broad and unresolved cases above leave that finding open.

## Gate

`TMPDIR=/private/tmp LOOM_BATS_JOBS=4 perl -e '$SIG{INT}="DEFAULT"; exec @ARGV' scripts/check` passed (exit 0), including all 863 Bats cases, relative links, strict plugin validation and diff whitespace. An earlier run exited 1 at Bats case 488 while this evaluation was edited; the clean rerun restored the reviewed evaluation and passed that case. The passing gate does not cover the defects above.
