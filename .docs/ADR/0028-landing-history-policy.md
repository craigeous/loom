# 0028 — Landing History Policy

Status: Accepted
Extends: ADR 0020
Date: 2026-11-01

## Context

ADR [0020](0020-remote-publication-is-the-landing-authority.md) makes remote
publication the landing authority but does not say what history shape a landed slice
takes on the target. M8's workflow-benchmark delivered a harness and a paired
measurement protocol, not benchmark evidence establishing a permanently preferred
shape. Related slice-branch and worktree background is in
[git-worktree-parallel-slices](../research/2026-06-08-git-worktree-parallel-slices.md).
Three shapes are candidates:

- **Granular target commits.** Every handoff commit lands on the target. This keeps
  every intermediate Git object and the full audit trail, at the cost of target noise
  (plan, evaluation, and review churn interleaved with product changes), harder
  bisection, and more author-visible intermediate states.
- **Squash.** The slice branch keeps its granular handoff commits; the target receives
  one author-neutral commit. History is compact and bisectable. Tracked evidence
  (plan, evaluation, and review files under `.docs/`) preserves the review trail but
  cannot reproduce every intermediate Git object. Slice-head ancestry no longer holds.
- **Retained refs.** Granular commits are preserved through audit refs or retained
  branches. This keeps objects and a compact target, at added operational cost,
  provider-specific retention behavior, and cleanup complexity.

## Decision

1. **Squash is a provisional default to test**, adopted following the M8 harness. It
   is not a settled benchmark conclusion and not a frozen target-history choice; it
   is subject to reassessment on benchmark evidence.
2. A landing produces one candidate commit whose sole parent is the freshly fetched
   target base. It contains the integrated slice, deterministic finalization
   artifacts, and tracked evidence. The commit message is author-neutral.
3. The gate and every affected review check the exact candidate tree and the
   candidate/result SHA. Target movement rebuilds the candidate from the new base and
   reruns affected checks.
4. Non-force publication, fresh independent remote verification, receipt binding
   (slice head, bases, candidate and result), claim recovery, configured identity,
   and the `Landed` rule are unchanged from ADR 0020.
5. Because the slice head is not an ancestor of the result, integration and
   idempotent cleanup are defined by the receipt-bound slice head and verified
   checked-tree equivalence, never by slice-head ancestry. When that proof is
   unavailable, cleanup fails closed.
6. `pr-per-slice` and `merge-queue` conform only if the actual provider result proves
   the same sole-parent commit and checked tree, with receipt binding. A
   provider-created squash with a different SHA or base requires a rebuilt and
   rechecked candidate; otherwise the mode fails closed without switching modes.
7. Retained audit refs are optional and not required.

## Consequences

- Specs 00 and 04 are amended to cite this ADR; spec 04 carries the contract.
- `loom-land` and orchestration need a separately planned implementation covering all
  modes, moved-target rebuilds, containment replacement, checked-tree and receipt
  binding, incompatibility, migration, and recovery. Existing receipts stay valid.
- Tracked evidence cannot reproduce every intermediate commit; optional retention may
  be added later at operational cost.
- No history rewriting, force-push, or erasure of existing history is introduced.
- The policy is reassessed when benchmark evidence exists; a change supersedes this
  ADR.
