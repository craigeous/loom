# Evaluation: 0014 — Multi-Session Worktree Coordination

Verdict: PASS
Round: 1
Reviewed against: ADR 0008 (extended), ADR 0001 / 0003 / 0012 / 0013 (preserved),
spec 04 (frozen), research `2026-06-08-git-worktree-parallel-slices.md`, ADR/README.md.

This is a re-review of the Round-1 FAIL. All three prior findings are resolved by the
revision (diff `0cbcdf9`); the re-scan for new holes surfaces only MINOR wording items.

## Prior findings — verified closed

- **(was BLOCKER) Unguarded `main` write / "exactly two moments" untrue.** Closed.
  §1 relocates the machine cold-restart anchor **off** `main` into per-session
  `.git/loom-session-<session-id>/` state (session-id + write-ahead checkpoint +
  held-claims). Because it is under `.git/`, untracked, and **session-id-keyed**, it is
  not a shared single-instance `main` doc, needs no lock, and a restarting session reads
  **only its own** anchor — closing the prior correctness break (session A resuming B's
  checkpoint) and ADR 0013 rule 3's mis-fire. The human-facing `handoff.md` now stays on
  `main` and is written **only at land, under the §2 lock**, at milestone cadence; the
  per-op write-ahead cadence is absorbed off-`main`. Enumerating shared-`main` writes:
  claim, lease-renew, land — **every one is inside the §2 lock**. The safety property
  ("no unguarded `main` write, all four races closed") is now mechanically true.
- **(was MAJOR) Cold-restart lease recovery.** Closed. §3 adds an explicit re-adopt/renew
  bullet: `session-id` is **allocated once, stable across restart, never `pid`-derived**,
  persisted in the per-session `.git/` state and re-read on bootstrap; the session
  re-adopts its held-claims set and **renews each lease under the lock** (refresh
  `lease-timestamp` *and* overwrite `pid`). Restart safety is defended in depth: (a) the
  liveness gate keys **primarily on `session-id`-in-`git worktree list`** (worktrees
  persist a context-only restart, so the session never looks dead), and (b) reclaim is
  gated on **TTL-expired AND dead** — a fast restart + prompt renew never crosses the
  slice-lease TTL, so the lease is never even a reclaim candidate in the restart window.
  A still-live session's slice cannot be stolen across its own restart.
- **(was MINOR) Authoritative read.** Closed. §1/§3 pin the authoritative "what landed /
  what is claimed" read — and the check-then-act re-read under the lock — to the shared
  **local** `main` (loom's no-push model); `origin/main` is explicitly demoted to an
  unlocked optimization/pre-filter, never authoritative.

## Findings

- [MINOR] §1's "a session mutates the shared `main` checkout at exactly **two** moments"
  undercounts: **lease-renewal** (§3 cold-restart + stale-claim renew) is a third kind of
  `main` write to `slice-plans/README.md`. It is correctly **under the §2 lock**, so the
  safety claim is unaffected — but the enumeration would read truer as "claim (incl.
  renew) and land," or by noting renewal as a refresh of the existing claim.
- [MINOR] The reclaim conditions in §2/§3 phrase the dead-holder test as "`session-id`
  absent from `git worktree list` **and/or** `pid` not alive," while §3's cold-restart
  bullet states the gate keys **primarily on `session-id`**, `pid` secondary. Read
  literally, the "or `pid` not alive" branch could fire on a restarting session's stale
  `pid`; the governing safety property (session-id-primary) and the TTL gate prevent harm,
  but an implementer would benefit from the boolean being reconciled to "session-id-present
  ⇒ alive; `pid` consulted only when worktree-list is inconclusive." The Notes already
  defer "the exact liveness probe" as a parameter, so this is precision, not a hole.
- [MINOR] No session-end cleanup is specified for `.git/loom-session-<id>/` (it survives
  `git worktree remove`/`prune`, which only touch `.git/worktrees/<name>/`). Orphaned
  per-session dirs are harmless (small, untracked, read only by their own session) and
  reclaim handles the leases, but a housekeeping note in the build item would be tidy.

## What is sound (verified, not at issue)

- ADR 0008 **extended, not rewritten**: "supersedes nothing," ADR 0008 stays Accepted/
  immutable, the lock applies **only** to the irreducibly-shared `main` critical section,
  disjoint slice files stay conflict-free-by-construction and lock-free. Confirmed against
  ADR 0008 §1–§4.
- ADR 0013 rule 1's write-ahead **invariant** is preserved while only its **medium** moves
  off-`main` — consistent with ADR 0013 §5's "persist the marker outside the tracked
  worktree (under `.git/`)." Rule 3's forward-progress guard now reads per-session state.
- Crash-while-holding-lock: §2 `lock-TTL` + holder stamp, force-clear gated on a positive
  **dead-holder** check, never clearing a live-but-slow holder — sound; distinct from the
  §3 slice-lease TTL.
- Claim TOCTOU: §3 check-then-act re-read **under** the lock with abort+reselect — sound.
- ADR 0003 untouched: `session-id`/`pid` are out-of-band liveness only, never commit/author
  metadata; blind-eval safety preserved. ADR 0001 (only the session spawns) preserved.
- Shared-`.git/` / object-store / `index.lock`-backoff claims match the research note;
  per-repository `mkdir` lock under `.git/` is consistent with the prior art.
- Scope hygiene: spec-04 Parallelism amendment deferred to a later planning pass (ADR 0005);
  the POSIX-sh lock/lease helper deferred as a build item (mirroring ADR 0008's deferral).
  Placement/naming conform: `Status: Plan Review`, ADR/README lists 0014 accurately.

## Notes

The focused revision the Round-1 eval asked for landed cleanly: the un-modeled
ADR 0013/0012 interaction is now reconciled by relocating the per-op cold-restart anchor
to off-`main`, session-id-keyed state, and the lease-recovery story is concrete and
safe under defense-in-depth (TTL gate + session-id-primary liveness). The three remaining
items are wording precision the slice-plan/spec-04 pass can absorb; none block approval.
