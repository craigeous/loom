# Evaluation: 0015 — Lease-Renewal Heartbeat as the Liveness Signal

Verdict: PASS
Round: 2
Reviewed against: ADR 0014 (Accepted/immutable, liveness §3), ADR 0012/0013 (single-threaded thin orchestrator, long blocking sub-agent calls, cold-restart + escalate-and-stop), spec 04 §"Multi-session coordination" (frozen, ADR 0005), ADR 0001/0003, ADR/README.md, and `.docs/evaluations/multi-session-lock-helper-review-findings.md` (T2/T4/T6). Re-review of the revision at `09ae440` (diff vs `aff34fd`).

## Round-2 finding — disposition (verified mechanically against the diff)

- **(prior BLOCKER) pid-reuse re-regresses T2 — CLOSED.** The revision adopts a reuse-robust process identity `{session-pid, session-pid-start-time}` and applies the AND-gate `alive(pid) && starttime(pid)==recorded` at **every** point the pid is used as a liveness signal — verified, not by eye:
  - **Renewer loop gate** (§2, line 133): `while session_alive "$SESSION_PID" "$SESSION_PID_STARTTIME"`, with the loop-condition semantics spelled out at lines 117–125 and 161–171 (a recycled pid's start-time cannot match → gate reports dead → renewer self-terminates).
  - **Duplicate-suppression / relaunch check** (§2, lines 144–150): reads `{renewer-pid, renewer-pid-start-time}` and relaunches unless alive **under the same reuse-robust check**; the diff explicitly calls out that a bare `kill -0` here would suppress a needed relaunch and reap-the-living, and the start-time pairing forecloses it.
  - **Cold-restart re-adoption** (lines 152–156) and **clean-shutdown kill** (line 158, "only after confirming its start-time still matches") both use the reuse-robust check. `grep` confirms every remaining bare `kill -0` in the file is either Context describing the prior defect (lines 14, 23, 103) or prose warning *against* a bare `kill -0` (122, 148, 187) — none is a live gate.
- **Closure claims softened correctly.** The "a dead session cannot keep its own lease alive" (line 167) and "closes T2/T6" (line 286) statements are now scoped **"Under this/that reuse-robust identity gate"**; line 289 adds the explicit converse — a **bare-pid** gate would leave T2 open. §3 (186–189) and the §3/Consequences standing obligation (295–296) are likewise re-scoped to the pid+start-time gate. No unconditional overclaim remains (the §4 line-218 "closes the T2 permanent-wedge" is the membership→lease-staleness axis, sound and consistent with §2's now-reuse-robust gate).
- **Portability carried forward.** A new mechanical carry-forward bullet (lines 317–324) requires the OS-specific start-time read to be captured/compared **portably** and the **gate and tests to exercise the non-local OS path** — same GNU/Linux-`dash` vs BSD/macOS matrix as T1, not masked by local runs.

## Findings

- None blocking. (No BLOCKER/MAJOR/MINOR.)

## What is sound (verified)

- **Residual TOCTOU is self-guarded, not a gap.** If the pid is recycled between the `kill -0` read and the start-time read, the start-time read returns the *new* process's start-time ≠ recorded → AND fails → gate reports **dead** (the safe direction: renewer exits, lease reclaimable). The only unsafe outcome would require an exact start-time collision on the reused pid — negligible. No finding.
- **Round-1 closures intact:** out-of-band renewer decouples the heartbeat from the blocked driver loop; cross-session purity clean (§4 — peers consult lease freshness only, pid probed only locally/intra-session); `grep F5` → none; T4 still an explicit carry-forward bullet (line 328), alongside T1/T3/T5/T7.
- **Supersession scope precise and liveness-only** (§5); ADR 0014 body **untouched** (empty diff `a67933c..HEAD` on `0014-…md`) and spec 04 **not edited** (latest ADR commit `09ae440` touches only `0015-…md`).
- **ADR 0001/0003 preserved** (session-id stays out-of-band, never author/commit metadata; membership/pid demoted for peers).

## Notes

The revision resolves the Round-2 pid-reuse BLOCKER at the principle/mechanism level exactly as required: option (a) — pid paired with process start-time — applied uniformly to the renewer loop, the duplicate-suppression check, cold-restart re-adoption, and clean-shutdown kill, with the closure claims re-scoped to hold only under that gate and the OS-specific start-time read added to the mechanical carry-forward list so the re-implementation slice handles it cross-platform. The decided principle (liveness = lease-freshness heartbeat, kept beating out-of-band) and its self-termination guarantee are now internally consistent and accurate against the authority.
