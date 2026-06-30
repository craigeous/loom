# Evaluation: 0014 — Multi-Session Worktree Coordination

Verdict: FAIL
Round: 1
Reviewed against: ADR 0008 (extended), ADR 0001 / 0003 / 0012 / 0013 (preserved),
spec 04 (frozen), research `2026-06-08-git-worktree-parallel-slices.md`, ADR/README.md.

## Findings

- [BLOCKER] The critical section `{claim, merge+finalize}` does **not** cover every
  main-mutating write the problem implies — the per-session **write-ahead `handoff.md`
  checkpoint** is an unguarded main write. §1 asserts "the shared `main` checkout is
  touched at exactly **two** moments, both inside the lock." That is false under the
  authority this ADR builds on: ADR 0013 rule 1 (and spec 04 *Thin-orchestrator
  invariant* / ADR 0012 §4) **requires** each thin, cold-restarting session to commit
  its *next intended action* to `handoff.md` **before** every large/in-window op and
  before a restart. `handoff.md` is one of ADR 0008's three living docs (main-only,
  single-instance). So each of the N sessions writes the same shared `main`
  `handoff.md` **frequently and outside** the `{claim, land}` lock — a third, recurring
  main-write the ADR never accounts for. This is exactly race point 3 (living-doc
  writes), left open for `handoff.md`. It cannot simply be folded under the §2 lock:
  the checkpoint *precedes* a role spawn/restart, and §2 mandates the lock is held only
  for a short op and **never across role spawns**. Worse, it is a *correctness* break,
  not only a write race: `handoff.md` is THE cold-restart anchor (ADR 0012/0013), so
  with N sessions sharing one, a restarting session A can re-bootstrap from session B's
  checkpoint and resume B's action (and ADR 0013's forward-progress guard misfires).
  The ADR must resolve how N sessions' write-ahead checkpoint/handoff state coexists on
  `main` — e.g. partition it per session (a change to ADR 0008's single-`handoff.md`
  living-doc model that must be stated and reconciled) or otherwise serialize it
  without holding the main lock across a spawn. As written, the "all four races closed"
  / "exactly two moments" claim is mechanically untrue.

- [MAJOR] Cold-restart **lease recovery** is unspecified — the model handles a *crashed*
  claimant but not a session's *own* cold restart. A lease spans a whole slice (§3) and
  therefore will routinely straddle a ~60% lossless cold-restart (ADR 0012/0013), which
  clears the window of the **same** OS process. The lease is keyed by `session-id`
  ("e.g. a uuid"), but the ADR never says where `session-id` is persisted/derived. If it
  lives only in the cleared context, after restart the session (a) cannot recognize its
  own outstanding lease to **renew** it, and (b) since its `pid`/worktrees are still
  live, no peer may reclaim it (correctly), so the slice's lease is stranded until — but
  it never expires under a live `pid`. The ADR must state that `session-id` and the set
  of held claims survive a cold restart (e.g. derived from a stable source / recovered
  from `handoff.md` or a `.git/` marker) so a restarted session renews rather than
  orphans its leases. The task's cold-restart invariant ("a restarting session must
  recover or release its claim, not deadlock") is not demonstrably met for the lease.

- [MINOR] The authoritative read is described as "fresh `origin/main` (`git fetch`) **or**
  the shared `main` checkout under the lock" as if interchangeable. In a single-machine
  multi-worktree repo (shared `.git/`), the truth is the shared **local** `main`; claims
  committed locally but not yet pushed are invisible to a peer reading `origin/main`. For
  the **check-then-act re-read under the lock** (where correctness depends on it), pin the
  authoritative read to the shared local `main`, not `origin/main` (which would also force
  a fetch/push round-trip inside the held lock). The unlocked dispatch scan may use
  `origin/main` as an optimization. Recommend tightening the wording.

## What is sound (verified, not at issue)

- ADR 0008 is **extended, not rewritten**: "supersedes nothing," ADR 0008 stays Accepted/
  immutable, the lock applies **only** to the irreducibly-shared `main` critical section,
  and disjoint slice files stay conflict-free-by-construction and lock-free. The
  authority's guarantee is preserved.
- Crash-while-holding-lock liveness: §2's `lock-TTL` + holder stamp, force-clear gated on
  a positive **dead-holder** check (`git worktree list` / `kill -0`), never clearing a
  live-but-slow holder — sound.
- Claim TOCTOU: §3's check-then-act re-read **under** the lock with abort+reselect — sound.
- Stale-lease reclaim is liveness-gated (not TTL-alone) with renew-for-long-running — sound.
- ADR 0003 untouched: `session-id`/`pid` are out-of-band liveness only, never commit/author
  metadata; blind-eval safety preserved. ADR 0001 (only the session spawns) preserved.
- Spec 04 not silently contradicted: the Parallelism amendment is explicitly deferred to a
  later planning pass (ADR 0005). Mechanism (POSIX-sh helper) deferred as a build item,
  mirroring ADR 0008's deferral — scope hygiene is good.
- Git claims (mkdir-atomicity, shared `.git/`, `index.lock` backoff reuse, `worktree
  prune`/`remove -f`) are consistent with the research note and ADR 0008 §3.
- Placement/naming: ADR/README lists 0014 under *In Review* with an accurate description;
  filename, `Status: Plan Review`, and Context/Decision/Consequences structure conform.

## Required changes (for FAIL)

1. Close the unguarded-`handoff.md` hole (BLOCKER): account for each session's
   ADR-0013 write-ahead checkpoint as a recurring `main` living-doc write that is **not**
   inside `{claim, land}`. Either partition per-session checkpoint/handoff state on `main`
   (and state this as an extension of ADR 0008's single-`handoff.md` model), or define
   another serialization that does not require holding the main lock across a role
   spawn/restart. Correct the "exactly two moments touch main" / "all four races closed"
   claim accordingly, and ensure a cold-restarting session never resumes from another
   session's checkpoint.
2. Specify cold-restart lease recovery (MAJOR): state where `session-id` and held claims
   are persisted so a session that cold-restarts (same process, fresh window) recognizes
   and **renews** its own leases instead of orphaning them, and so its live `pid` does not
   indefinitely block reclaim of a lease it no longer tracks.
3. (MINOR, recommended) Pin the under-lock authoritative read to the shared **local**
   `main`, distinguishing it from the `origin/main` fetch used by the unlocked scan.

## Notes

The well-scrutinized races (shared tree, duplicate dispatch, TOCTOU claim, concurrent
merge+finalize, crashed lock-holder, crashed claimant) are handled carefully and
correctly. The gap is specifically the **interaction with ADR 0013/0012**: the multi-
session model inherits a single shared `handoff.md` and a per-session cold-restart
discipline without reconciling them. Both findings are facets of that one un-modeled
interaction; closing it should be a focused revision, not a redesign.
