# 0020 — Remote Publication Is the Landing Authority

Status: Accepted
Date: 2026-07-21

## Context

ADR [0014](0014-multi-session-worktree-coordination.md), as refined by ADRs 0015
and 0016, coordinates sessions in one clone but makes shared local `main` the
authoritative read and performs merge/finalize there without pushing. That can batch
unrelated completed slices into a later push and cannot establish what collaborators in
other clones have actually received.

The [repository improvement plan](../repository-improvement-plan.md) requires each
slice to publish only its reviewed integration candidate and defines remote state, not
local `main`, as the landing boundary. Git offers no transaction that merges inside a
remote repository; Loom must construct and test the candidate locally, then use the
remote ref update as the publication compare-and-swap.

In scope are landing authority, configured modes, status/recovery semantics, candidate
contents, same-clone versus cross-clone coordination, and the precise supersession of
the local-main model. Provider API details, helper CLI/schema details, and the later
benchmark-driven choice between granular versus squash target history are out of scope.

## Decision

### 1. A configured remote target ref is authoritative

Every managed repository that lands through Loom SHALL configure a remote name and full
target ref, normally `origin` and `refs/heads/main`, plus one landing mode. That remote
target is the sole publication authority. Local `main` is a disposable mirror/cache and
is never part of the landing transaction, dispatch authority, claim transaction, or
success proof.

`Landed` means the configured mode has completed and Loom has independently verified
that the remote target contains the exact published result SHA, then recorded a
publication receipt bound to the slice and candidate. A local merge, green gate,
provider success response, successful `git push` exit, candidate file saying `Landed`,
or updated local mirror is insufficient by itself.

The candidate SHALL contain exactly the slice change plus its final plan/evaluation
evidence, archived/index state, and living-document updates. Those artifacts publish in
one target update. The candidate may carry final `Landed` text, but that text is only a
prospective assertion until remote verification makes it true.

### 2. Candidate construction excludes local `main`

The landing helper SHALL fetch the remote target, resolve its exact base SHA, and create
a disposable integration worktree at that SHA. It integrates only the current slice,
prepares finalization artifacts there, and runs the applicable integrated gate and
review/evaluation checks against the exact candidate. It then re-fetches immediately
before publication. If the target moved, the candidate is rebuilt from the new SHA and
affected checks are rerun; it is never force-pushed and never rebased by trusting an
unverified local mirror.

Build, merge, finalization, and tests occur outside the publish lock. Sessions sharing a
clone hold `refs/loom/lock` only for the short final re-fetch/compare, publication,
remote verification, and receipt update. Publication uses a non-force fast-forward
update or the configured provider's equivalent protected merge operation. Local `main`
may be fast-forwarded after success when clean; failure to update it cannot undo or
invalidate verified remote publication.

The publication receipt SHALL bind at least slice/session IDs, remote and full target
ref, mode, slice head, initial and final remote bases, candidate/result SHA, gate and
review evidence hashes, landing-helper/protocol version, and publication/verification
outcome. Runtime recovery derives truth from the remote plus this receipt, never from a
working-tree status line alone.

### 3. Landing mode is explicit and never silently changed

Loom recognizes these modes:

| Mode | Publication boundary | Success proof | Retry/recovery |
|---|---|---|---|
| `remote-direct` | Non-force fast-forward update of the configured target | Fresh remote read equals candidate SHA | A moved target rebuilds; network or protection failure preserves candidate/claim |
| `pr-per-slice` | Provider-confirmed merge of one candidate PR | Fresh target read contains the provider-reported result SHA and receipt binds the PR | Open/rejected checks remain pending; closed/unmerged is failure; moved target follows provider merge semantics and affected checks |
| `merge-queue` | Provider queue-confirmed merge of one candidate | Fresh target read contains the queue result SHA and receipt binds the queue entry | Queued is pending; ejected/failed preserves recovery state; only confirmed merge succeeds |

`remote-direct` is the first required implementation and is supported without a
provider API on an unprotected target. `pr-per-slice` and `merge-queue` are contract
names, not automatic promises: each becomes supported only when an explicitly
configured provider adapter passes its conformance tests. Selecting an unavailable
adapter is a mode error. Branch protection, network failure, or missing credentials
never causes fallback to a different mode.

Loom never force-pushes the target branch in any mode. Remote publication that cannot
be independently verified remains unsuccessful even if a command or provider reports
success.

### 4. Publication has a durable recoverable state

Add `Ready to Publish` between approved code evaluation and `Landed`. Reaching it means
the reviewed slice is eligible for candidate construction/publication; it does not
release the slice claim. Network failure, remote movement, provider delay, mode error,
or unverifiable publication preserves the candidate evidence and claim in `Ready to
Publish`. A target race rebuilds and reruns checks affected by the new base.

Only verified publication records the receipt, makes `Landed` authoritative, releases
the claim, and begins idempotent local cleanup. If publication succeeded but the local
process crashed before receipt/cleanup, recovery verifies the remote result, reconstructs
the receipt, and completes cleanup without republishing. If containment cannot be
proved, recovery stops for owner action rather than guessing.

Claim acquisition and work start SHALL not write or commit tracked state on local or
remote `main`. Active claims remain in `refs/loom/claims/*` plus validated per-session
state; durable in-progress evidence lives on the slice branch. Final living docs and
indexes change only in the integration candidate.

### 5. Same-clone coordination is not cross-clone exclusion

`refs/loom/*` coordinate worktrees and sessions sharing one common Git directory. They
are invisible to separate clones. The remote fast-forward check is the final publication
CAS and prevents overwrite, but it does not prevent two clones from claiming or doing
the same slice. Loom SHALL state that limitation. Cross-clone claim exclusion exists
only when an explicitly supported remote-claim or provider-queue adapter supplies it;
until then duplicated work is possible even though duplicate overwrite is not.

## Consequences

- **Partially supersedes ADR 0014.** Replaced: fresh local `main` as authoritative
  read/base; no-push operation; claim commits to local `main`; the shared-local-main
  merge/finalize critical section; and claim release at local merge. Preserved:
  session-owned slice worktrees, per-session restart state, lease semantics, the
  same-clone lock/claim coordination model, and the prohibition on holding a lock
  across role work. Those preserved mechanics now coordinate candidate publication,
  not shared-local-main landing.
- ADRs 0015 and 0016 remain in force for lease-freshness and git-ref CAS in one clone.
  `refs/loom/lock` is reused as the short same-clone publish lock. No claim of
  cross-clone locking is added.
- ADR 0008's isolated worktree and disjoint-slice principles stand, but its local-main
  serialization/finalization language must be read through this ADR and later amended
  in specs/guides.
- Specs 03 and 04 need a later planning amendment for `Ready to Publish`, remote-derived
  `Landed`, the mode state machine, and removal of tracked claim/start writes. No spec,
  helper, status doc, or slice plan changes in this decision pass.
- Offline clones can prepare and review work but cannot truthfully land it. Protected
  repositories require an explicitly installed PR/queue adapter; no convenience
  fallback weakens the boundary.
- The target-branch commit shape is deliberately not decided. M8 shall use benchmark
  evidence to choose granular, squash, or retained-audit history without changing the
  remote authority decided here.
