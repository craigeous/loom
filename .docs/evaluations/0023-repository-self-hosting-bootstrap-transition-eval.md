# Evaluation: 0023 — Repository Self-Hosting Bootstrap Transition

Verdict: PASS
Round: 1
bootstrap-ratification: degraded
Evidence mode: `loom-repository-bootstrap/v1`
Conformance: degraded bootstrap; not `loom-local-review/v1`
Isolation: not established under ADR 0022
Reviewed artifact commit: `827b621dffe1575de12e2b6f75fb7d2006678952`
Reviewed artifact blob: `6285dcd9576e7a94863bc3c59d07cc93f283589d`
Reviewed against: Accepted ADRs 0020–0022; Approved specs 03–05; repository
improvement plan blob `316ae4bc964fb422134151478b6369e1f9b4cfa5`; plan-evaluation
rubric and severity rules; current tracked helper state at the reviewed artifact
commit.

## Findings

No blocking or major findings.

## Notes

The `a479901..827b621` revision resolves both Round-1 blockers.

Section 6 replaces base-relative retirement with a protected, append-only configured-
remote transition ref. Its cumulative state, exact predecessor/sequence validation,
publication-intent serialization, target-result containment checks, mandatory stale-
base rebuild, and terminal full-sunset successor make every retirement apply to new
and resumed runs. Missing or unavailable state, target rewind, divergent history, and
local receipt/checkpoint deletion block recovery rather than restoring an exception.
The full-sunset SHA is freshly derived from a target containing all three production
transition results; terminal state retires every component and empties the allowlist.

Section 7 supplies the previously missing pre-`loom-land` bridge for the exact M0–M2
slice set. It builds from a freshly fetched remote base, integrates only the reviewed
slice, reruns the gate and bootstrap review/evaluation on the integrated input, gates
the exact publish candidate, rechecks the target, records a hash-bound transition
intent, publishes an explicit exact-SHA refspec without force, freshly verifies the
remote result/tree, writes the bound receipt, settles remote state, and only then
releases the claim. The intent/target/settlement ordering handles the two-ref race
without assuming atomicity; losing writers restart from fresh state, and crash states
recover only the recorded candidate or fail closed. Settlement of
`remote-first-integration-candidate` permanently removes this path.

The procedure remains limited to this repository, program, remote-direct mode, and
closed slice list. Its evidence retains degraded-bootstrap labels and expressly makes
no `loom-land/v1`, `loom-local-review/v1`, ADR-0022 isolation, managed-project,
provider-adapter, or release-conformance claim.
