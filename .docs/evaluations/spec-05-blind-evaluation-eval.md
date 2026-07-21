# Evaluation: 05 — Controlled-Input Independent Evaluation

Verdict: FAIL
Round: 1
Reviewed against: accepted ADR 0023; retained production authority in accepted ADRs
0020–0022; sibling specs 03 and 04; exact amendment diff `80499f1^..80499f1`;
plan-evaluation rubric and severity rules.

## Findings

- [BLOCKER] The exception names ADR 0023 ratification and one-listed-slice plan
  evaluation as its only planning uses (lines 98–103), but every bootstrap package,
  worker, evaluator, and recording rule that follows is code-specific (lines 105–140):
  it requires `base_sha`/`head_sha`, an approved plan, developer gate, three
  diff-intersecting code workers, a code evaluator, and gate-rerun verdict fields.
  The spec never supplies ADR 0023 sections 2 and 4's analogous planning package—exact
  artifact commit, authority/rubric blobs and required `evidence_sha`—or its distinct
  cold plan-evaluator scratch verdict and root-copy validation. Falling through to the
  production plan path would require the exporter and deterministic recorder this
  transition exists to build, so the authorized planning exception is unusable.

## Required changes (for FAIL)

1. Separate bootstrap plan evaluation from the code path. Define the exact planning
   allowlist/package, distinct cold plan evaluator, scratch-only verdict, root
   validation/copy without merits changes, required degraded labels (including
   `bootstrap-ratification: degraded` for ADR 0023), and invalid-output handling.
   Explicitly scope the developer gate, three auxiliary workers, code adjudication,
   and gate-rerun fields to eligible code-bearing slices.

## Notes

The code path's trust claim and labels are accurate: bootstrap evidence is expressly
degraded, non-v1, and non-isolated; exact committed inputs, all three cold workers, the
independent evaluator and fresh gate rerun are mandatory; malformed or unavailable
evidence fails closed; protected remote state makes retirement and full sunset
one-way; and the exception cannot become managed-project, adapter, or release
conformance.
