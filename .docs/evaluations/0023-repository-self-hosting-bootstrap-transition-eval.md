# Evaluation: 0023 — Repository Self-Hosting Bootstrap Transition

Verdict: FAIL
Round: 1
bootstrap-ratification: degraded
Evidence mode: `loom-repository-bootstrap/v1`
Conformance: degraded bootstrap; not `loom-local-review/v1`
Isolation: not established under ADR 0022
Reviewed artifact commit: `fc975324aebb756ee60b28755a218322d15b38c1`
Reviewed artifact blob: `8ffa78c4f165329238be8632979a298b8c83288d`
Reviewed against: Accepted ADRs 0020–0022; Approved specs 03–05; repository
improvement plan blob `316ae4bc964fb422134151478b6369e1f9b4cfa5`; plan-evaluation
rubric and severity rules; current tracked helper state at the reviewed artifact
commit.

## Findings

- [BLOCKER] The progressive and full sunset can be reopened by selecting a stale
  `base_sha` — Section 6 retires each exception only for a run whose base contains
  the component result, and forbids bootstrap after the full-sunset SHA only for
  bases at or below that SHA. Once the freshly read configured remote contains a
  verified transition result, a newly started or resumed run may still choose a
  pre-result base and remain eligible for bootstrap. That contradicts the stated
  monotonic retirement, the hard full sunset, and the assertion that ADRs 0021/0022
  apply without exception afterward. The remote observation does not latch the
  transition or make a stale base invalid.
- [BLOCKER] The transition does not bridge the repository's missing remote-landing
  machinery, so it cannot execute the ordering it claims to preserve — ADR 0020 and
  Approved specs 03/04 require the deterministic landing helper to build, check,
  publish, freshly verify, and receipt the candidate. At
  `fc975324aebb756ee60b28755a218322d15b38c1`, no tracked `loom-land` helper exists,
  just as no `loom-review`, evaluation exporter/gate runner/recorder, or initial
  `scripts/check` exists. ADR 0023 expressly leaves the landing-helper requirement
  unsuperseded and defines no temporary repository-only landing procedure. M0 and M1
  can therefore reach at most `Ready to Publish`, while the M2
  `remote-first-integration-candidate` slice cannot use its own not-yet-landed helper
  to satisfy the required M0 → M1 → M2 sequence. Manual root publication would
  silently violate the helper boundary the ADR says remains fully in force.

## Required changes (for FAIL)

1. Make progressive retirement and the full sunset remote-latched and one-way. Once
   a fresh configured-remote verification establishes a transition result, require
   production machinery for every new or resumed run; reject or rebase a run whose
   base does not contain that result instead of permitting bootstrap. Specify the
   exact result-SHA/full-sunset derivation and fail-closed recovery so remote
   unavailability, rewind, stale branches, or deletion of local receipt/state cannot
   reopen an exception.
2. Either define a closed, repository-only bootstrap landing procedure through the
   verified remote landing of `remote-first-integration-candidate`, or identify an
   already tracked mechanism that satisfies ADR 0020/specs 03–04. The temporary path
   must preserve exact candidate inputs, applicable integrated gate/review/evaluation
   reruns, configured-mode non-force publication, fresh remote verification, receipt
   binding, crash recovery, and fail-closed behavior; it must not become managed-project
   or release conformance.

## Notes

The need for a bootstrap exception is established, and the closed M0–M5 slice list,
degraded provenance, exact-commit evidence, complete three-worker review, distinct
evaluator verdict, unconditional gate rerun, no-self-approval rule, and failure
handling otherwise avoid silently claiming production v1 or ADR-0022 isolation.
The two findings above are execution-boundary defects: as written, the bridge is not
both runnable from the current repository state and mechanically irreversible at its
sunset.
