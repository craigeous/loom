# Evaluation: 04 — Orchestrator

Verdict: FAIL
Round: 1
Reviewed against: accepted ADR 0023; retained production authority in accepted ADRs
0020–0022; sibling specs 03 and 05; exact amendment diff `80499f1^..80499f1`;
plan-evaluation rubric and severity rules.

## Findings

- [BLOCKER] The bootstrap plan-evaluation route is declared eligible but is not
  executable. Lines 99–101 admit ADR 0023 ratification and a plan solely authorizing
  one listed slice, but lines 103–153 define only a code-bearing package and flow:
  `base_sha`/`head_sha`, an approved plan, developer gate evidence, three code-review
  workers, a code evaluator, and code-verdict bindings. The later production route at
  lines 267–288 still requires the not-yet-built deterministic exporter and recorder.
  ADR 0023 sections 2 and 4 instead require the degraded planning branch to bind the
  exact artifact commit, authority/rubric blobs and needed `evidence_sha`, launch a
  cold plan evaluator distinct from the planner, and validate/root-record its scratch
  verdict without changing its merits. Without that branch, the closed slices cannot
  obtain the Approved plans that authorize their implementation.

## Required changes (for FAIL)

1. Add an explicit bootstrap plan-evaluation branch for exactly ADR 0023's historical
   ratification and a plan solely authorizing one listed slice. Specify its exact
   artifact/authority/rubric/current-tree bindings, cold planner/evaluator separation,
   scratch verdict, root validation/copy under the temporary recorder exception,
   degraded provenance labels, and fail-closed handling. Scope the developer gate,
   three auxiliary workers, and code-evaluator requirements to code-bearing slices.

## Notes

The code-bearing transition otherwise matches ADR 0023 and retained ADRs 0020–0022:
the slice allowlist is closed; exact revisions, developer gate evidence, three cold
workers, independent evaluator rerun, and degraded labels are preserved; the protected
append-only state branch serializes intent/publication/settlement and recovery; the
remote-direct bridge is closed and non-force; stale bases, rewinds, and unavailability
fail closed; retirement and full sunset are one-way; and no managed-project, adapter,
or release conformance is claimed.
