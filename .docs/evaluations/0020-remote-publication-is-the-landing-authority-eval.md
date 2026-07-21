# Evaluation: 0020 — Remote Publication Is the Landing Authority

Verdict: PASS
Round: 0
Reviewed against: repository improvement plan M2; approved dual-platform architecture research M2 impact; ADRs 0008 and 0014–0016; specs 03 and 04; plan-evaluation rubric and severity rules.

## Findings

No BLOCKER, MAJOR, or MINOR findings.

## Required changes (for FAIL)

None.

## Notes

The decision reproduces M2's required authority, candidate, concurrency, mode, and
recovery invariants without choosing the deferred target-history policy. `Landed` is
bound to independently verified remote state plus a receipt; local `main` cannot
contaminate construction or prove success; fast-forward publication is non-force; mode
fallback is prohibited; and the same-clone/cross-clone limitation is explicit.

The supersession audit is precise. ADR 0014's local-main authority, tracked claim/start
writes, local merge/finalize transaction, no-push rule, and local-merge claim release are
replaced. Session worktrees, restart state, leases, same-clone claims, and no-lock-across-
role-work remain. ADRs 0015/0016 continue to govern lease freshness and ref CAS, with
`refs/loom/lock` narrowed to the final same-clone publication critical section. ADR
0008's isolation principle remains while its local-main landing prose is explicitly
subject to later amendment. The resulting model is implementable without conflicting
with the improvement plan's remote-first helper sequence.

