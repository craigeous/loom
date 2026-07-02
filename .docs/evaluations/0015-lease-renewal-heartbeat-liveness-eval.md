# Evaluation: 0015 — Lease-Renewal Heartbeat as the Liveness Signal

Verdict: FAIL
Round: 2
Reviewed against: ADR 0014 (Accepted/immutable, liveness §3), ADR 0012/0013 (single-threaded thin orchestrator, long blocking sub-agent calls, cold-restart + escalate-and-stop), spec 04 §"Multi-session coordination" (frozen, ADR 0005), ADR 0001/0003, ADR/README.md, and `.docs/evaluations/multi-session-lock-helper-review-findings.md` (T2/T4/T6). Re-review of the revision at `aff34fd` (diff vs `a67933c`).

## Round-1 findings — disposition (verified against the diff)

- **(prior BLOCKER) renewal during long blocking ops — CLOSED.** The revision replaces the driver-loop cadence with a **detached, out-of-band background renewer** (§2, lines 97–138): a separate process running `while kill -0 "$SESSION_PID"; do renew; sleep ~TTL/3; done &`. Because it is a distinct process from the blocked main thread, it genuinely heartbeats *through* a 20–40+ min suspended sub-agent Task call — the exact gap round-1 raised. Confirmed closed at the level it was raised.
- **(prior BLOCKER) cross-session purity — CLOSED.** §4 (lines 184–194) draws the line cleanly: **no peer probes any pid**; peers decide liveness by **lease freshness only** (§1). The one pid probed is the stable session pid, probed **only locally by the session's own renewer** — an intra-session gate, never cross-session. This does not re-introduce the round-2 cross-session-pid defect.
- **(prior MINOR) `§F5` cross-reference — CLOSED.** `grep F5` on 0015 → none; all sites now read §3.
- **(prior MINOR) T4 carry-forward — CLOSED.** T4 is now an explicit bullet in the Consequences carry-forward list (line 275), alongside T1/T3/T5/T7.

## Findings

- [BLOCKER] **PID-reuse re-regresses T2 (permanent wedge): the crash-path self-termination guarantee the ADR asserts is not delivered by the specified mechanism.** §2 (lines 133–138) and §3 (lines 151–160) state as a *guarantee* that "a dead session therefore cannot keep its own lease alive" — the renewer's `kill -0 "$SESSION_PID"` "fails on the next beat," the loop exits, the lease goes stale. Consequences (line 246) affirmatively claims this "directly closes findings T2." But the detached renewer is a bare-pid poll (line 113), and after the session process dies the OS is free to **recycle `$SESSION_PID`** to an unrelated process. Because up to ~TTL/3 elapses between beats, an unrelated process can acquire that pid in the window; on the next beat `kill -0 "$SESSION_PID"` **succeeds**, the orphaned renewer keeps refreshing the dead session's lease, the lease never goes stale, and the slice is **permanently wedged until an operator intervenes** — i.e. exactly the T2 permanent-wedge failure class this ADR exists to eliminate, reintroduced through the mechanism it decides. The ADR contains **no** treatment of pid reuse (verified: no mention of pid-reuse / process-start-time / process-group / true-child / bounded-lifetime anywhere). The hazard has a second face: the duplicate-suppression check (lines 122–129) is also a bare-pid `kill -0` on the recorded `renewer-pid`; a reused renewer-pid reads "alive," suppresses a real relaunch, and the session's **own** lease then goes stale while it is live → a reap-the-living re-regression. This is a soundness defect in the core decided mechanism, and the ADR asserts the opposite invariant — an internal-consistency/accuracy failure, not a deferrable numeric parameter. The principle (liveness = lease-freshness heartbeat) survives; the renewer's liveness/self-termination gate does not, as specified.

## What is sound (verified, not blocking)

- The out-of-band renewer correctly decouples the heartbeat from the blocked driver loop (round-1 BLOCKER closed).
- Cross-session purity is clean: peers consult lease freshness only; the pid is a local, intra-session gate (§4).
- Supersession scope remains precise and liveness-only (§5); ADR 0014 body untouched and spec 04 not edited (diff `aff34fd` touches only `0015-…md` and the eval — verify: ADR 0014 unchanged).
- Membership + ephemeral-CLI-pid demotion (§4) and the orphan-cleanup-off-stale-lease path (T6 reachable, T2 wedge closed) hold **given** a correct self-terminating renewer — which the BLOCKER puts in question.
- ADR 0001/0003 preserved (session-id out-of-band, never author/commit metadata).
- Both round-1 MINORs (F5, T4) genuinely closed.

## Required changes (for FAIL)

1. Close the pid-reuse hazard at the **principle/mechanism** level (numeric params may stay deferred). Pick and state one: (a) gate the renewer on **pid + process-start-time** (identity that a recycled pid cannot forge), not a bare pid; or (b) make the renewer a **true child coupled to parent death** (process-group / parent-death signal / `wait`-on-parent) so it cannot outlive the session and cannot be fooled by pid reuse; or (c) bound the renewer's **total lifetime** so an orphaned renewer cannot extend a lease indefinitely. Apply the same fix to the duplicate-suppression check (recorded `renewer-pid`), which has the identical bare-`kill -0` hazard. Then soften §2/§3/Consequences from asserting "a dead session cannot keep its own lease alive" / "closes T2" to hold **only under** the chosen reuse-robust gate — the closure claim must not outrun the mechanism.

## Notes

The revision resolves the round-1 blocked-orchestrator gap well: a detached process is the right shape, and the cross-session/local pid distinction in §4 is the correct line that keeps the renewer sound on the peer-facing side. The remaining hole is entirely on the **self-side**: a bare-pid `kill -0` poll is a textbook pid-reuse trap for precisely the "is my owner still alive" question, and here its failure mode is the same permanent-wedge (T2) class the ADR is chartered to remove. Establishing a reuse-robust identity for the session process (start-time pairing or parent-death coupling) restores the "dead ⇒ falls silent ⇒ reclaimable" guarantee the decision rests on.
