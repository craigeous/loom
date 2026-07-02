# 0015 — Lease-Renewal Heartbeat as the Liveness Signal

Status: Plan Review
Date: 2026-07-02

## Context

[ADR 0014](0014-multi-session-worktree-coordination.md) (Accepted, immutable) makes N
independent `/loom:run` sessions coordinate on the one shared `main` through a
cross-session lock and a slice-lease protocol. Both of its force-clear paths — the §2
stale-**lock** reclaim and the §3 stale-**lease** reclaim — are gated on a positive
**"holder is dead" liveness check**, not on a TTL alone. ADR 0014 §3 chose that
liveness check to key **primarily on `session-id` presence in `git worktree list`**,
with the process `pid` (`kill -0`) only a secondary probe, so a session's own cold
restart (which clears context but not its on-disk worktree) never looks dead to a peer.

Implementation of that helper (`plugins/loom/lib/loom-coord.sh`) went three rounds and
the liveness signal oscillated between **too aggressive** and **too lenient** — the
signal itself, not incidental bugs, was the root cause:

- **Round 2 (too aggressive) — pid-primary.** The liveness probe leaned on the process
  `pid`. But loom's helper is an **ephemeral per-invocation CLI process**: by the time a
  peer probes it, that pid has already exited, so `kill -0` reports **dead**. The result
  was that **live** sessions were reaped mid-slice — the lease of a perfectly healthy
  session was force-reclaimed because its last helper invocation's pid was gone.
- **Round 3 (too lenient) — membership-only.** The fix removed the pid override and made
  **presence of the session's `wt-<sid>` directory in `git worktree list`** the *sole*
  liveness signal. But a **crashed** session leaves its `wt-<sid>` worktree on disk, and
  `git worktree prune` will **not** remove a directory that is still present. So the
  crashed session is classified **alive forever** (review findings T2): `reclaim` returns
  "holder still alive," the slice is **permanently wedged** until an operator manually
  runs `git worktree remove`, and — the flip side — the orphan-worktree removal path is
  **unreachable dead code** (T6), because it is reached only when membership already reads
  empty. Membership answers "does a worktree directory exist," which is **not** the same
  question as "is a session still making progress."

The evidence is `.docs/evaluations/multi-session-lock-helper-review-findings.md`
(round-3 re-review). The two candidate signals ADR 0014 named — worktree-list membership
and the process pid — are **each** wrong in a different direction: pid is always-dead
(reaps the living), membership is never-dead-while-the-dir-exists (protects the crashed).
The missing signal is a **positive, self-maintained proof of ongoing progress**: a live
session should have to *keep saying it is alive*, and a crashed one should fall silent.
That is a heartbeat.

The owner has **decided the direction: liveness is a lease-renewal heartbeat.** This ADR
records that decision and scopes the supersession of ADR 0014 precisely. It does **not**
re-open the choice.

**In scope:** the liveness signal for both force-clear gates (lease freshness / heartbeat
recency); the session's renew obligation and its cadence relative to the TTL; the
stale→reclaim rule expressed in terms of lease freshness; and the explicit demotion of
worktree-list membership and the ephemeral pid from being liveness signals.

**Out of scope (called out as follow-on items in Consequences, not done here):** the
spec-04 amendment (a deliberate frozen-spec planning pass — [ADR 0005](0005-specs-frozen-after-approval.md));
the helper re-implementation (a developer slice through the normal loop); and the concrete
TTL *values* already parameterized by ADR 0014 (not re-decided here — only the renew
cadence's relationship to the TTL is fixed).

## Decision

**Liveness is determined by LEASE FRESHNESS (a renewal heartbeat), not by worktree-list
membership and not by the process pid.** This supersedes ADR 0014 **only on the
liveness-signal point** (its §3 "session-id-in-`git worktree list`, pid secondary"
choice). Every other ADR 0014 decision stands unchanged (see §5).

### 1. Lease freshness is the primary — and sufficient — liveness signal

Each claim/lock holder carries a **lease timestamp** that its owning session **renews**
while it is live. A holder or claim is **live iff its lease timestamp is within the TTL**;
a lease whose timestamp is **older than the TTL is stale → reclaimable**. This is the sole
positive liveness signal that gates both force-clear paths ADR 0014 defined:

- the **§2 stale-lock** force-clear (a crashed lock-holder), and
- the **§3 stale-lease** force-reclaim (a crashed slice-claimant) + its orphan-worktree
  cleanup (`git worktree prune` / `git worktree remove -f`).

ADR 0014's **"force-clear is gated on a positive holder-is-dead check, not the TTL alone"**
principle is **preserved verbatim** — this ADR only changes **what** that positive check
consults: **lease freshness**, not membership or pid. "Holder is dead" now means "its
lease is stale (not renewed within the TTL)."

### 2. The renew obligation is discharged by an out-of-band background renewer

A `/loom:run` session is a **single-threaded thin orchestrator** (ADR 0012/0013) that
spends most of its wall-clock **suspended inside long sub-agent Task calls** — a developer
or evaluator pass routinely blocks the session for **20–40+ minutes**. During such a call
the session's main thread executes nothing: it **cannot** emit a heartbeat or acquire
ADR 0014's §2 `main`-critical-section lock to refresh a lease. A renew cadence driven from
the **driver loop** could therefore only fire *between* sub-agent calls, so a single 40-min
pass would see **zero** renewals and the session's own lease would go stale mid-slice
**while the session is very much alive** (its blocked sub-agent *is* the progress). A peer
would then classify the lease stale → "holder dead," `git worktree remove -f` an in-progress
slice, and re-grant it — a self-inflicted double-grant, strictly worse than the round-2
reap. **The renew obligation therefore MUST NOT be carried by the blocked driver loop.**

**Renewal is discharged by a detached, out-of-band background renewer gated on a
reuse-robust identity of the stable session process.** The concrete mechanism the
re-implementation slice must build:

- **Capture a reuse-robust session-process identity — pid PAIRED WITH its start-time.** A
  bare pid is **not** a durable identity: after the session process dies the OS is free to
  **recycle its pid** to an unrelated process, and a later `kill -0 <session-pid>` on that
  recycled pid would falsely report the dead session "alive." The identity must therefore be
  a pid the OS cannot forge by reuse. At session start the orchestrator records its **own
  long-lived process pid together with that process's start-time** — the identity pair
  **`{session-pid, session-pid-start-time}`** — in the per-session
  `.git/loom-session-<session-id>/` state (ADR 0014 §1). The pid is the pid of the
  `/loom:run` main session itself: the **stable, long-lived orchestrator-session pid**,
  which stays *alive-but-busy* for the entire duration of a blocking sub-agent call and dies
  **only** when the session genuinely exits or crashes. It is emphatically **not** the
  ephemeral per-invocation `loom-coord` CLI pid that caused the round-2 reap — that pid is
  dead the instant the CLI returns (§4). Reading a process start-time is **OS-specific**
  (its source differs across Linux/macOS/BSD), so the re-implementation must obtain it
  **portably** — see the start-time-capture item in the mechanical carry-forward list
  (Consequences), alongside T1's `stat` portability lesson.
- **The liveness gate is a pid-alive-AND-start-time-matches check.** The renewer's loop
  condition (and any duplicate-suppression check below) treats the session as alive **iff**
  the recorded `session-pid` is alive **AND** the pid's *current* start-time equals the
  recorded `session-pid-start-time`. A recycled pid belongs to a **different** process with
  a **different** start-time, so the AND fails → the gate reports the original session dead →
  the renewer exits. This closes the pid-reuse trap that a bare `kill -0` leaves open. The
  gate is written here at the principle level as `alive(session-pid) && starttime(session-pid)
  == session-pid-start-time`; the exact OS primitive that reads the start-time is a
  re-implementation parameter (see carry-forward).
- **Start the renewer once, on first acquire.** When a session first acquires any lock or
  claim, it launches **exactly one** detached background renewer — shape:

  ```sh
  # detached; runs independently of the blocked main thread.
  # session_alive := kill -0 succeeds AND current start-time of SESSION_PID
  #                  still equals the recorded SESSION_PID_STARTTIME (reuse-robust).
  while session_alive "$SESSION_PID" "$SESSION_PID_STARTTIME"; do
      loom-coord renew --session "$SESSION_ID"   # refresh every held lease, under ADR 0014 §2 lock
      sleep "$RENEW_INTERVAL"                     # ~TTL/3
  done &
  ```

  The renewer heartbeats **independently of the blocked main thread**, so leases stay
  fresh straight through a 40-min sub-agent call — **many** beats occur *during* the block,
  not zero. Its own identity — `renewer-pid` paired with `renewer-pid-start-time` — is
  recorded in the per-session `.git/` state.
- **Never duplicate it.** Launch is **check-then-launch**: before starting a renewer the
  session reads the recorded `{renewer-pid, renewer-pid-start-time}` from its per-session
  state and starts a new one **only if** none is recorded or the recorded one is **not**
  alive under the **same reuse-robust check** (pid dead, *or* pid alive but its start-time
  no longer matches — i.e. the recorded renewer-pid has been recycled to an unrelated
  process). A bare `kill -0` on the recorded `renewer-pid` alone would misread a recycled
  renewer-pid as "alive," suppress a needed relaunch, and let the session's **own** lease go
  stale while it is live (a reap-the-living re-regression) — the start-time pairing forecloses
  that. On a cold-restart bootstrap (ADR 0014 §3) the re-adopting session applies the same
  check — it refreshes `{session-pid, session-pid-start-time}` to the **restarted** process's
  identity and **relaunches the renewer only if the recorded one did not survive the restart**
  (dead, or recycled per the start-time check) — so a restart never leaves two renewers
  racing, and a renewer left running by the pre-restart process is superseded rather than
  duplicated.
- **Stop it on clean session-end.** On orderly session shutdown the session **kills the
  recorded `renewer-pid`** (only after confirming its start-time still matches, so it never
  signals a recycled pid) and releases its held leases, so the leases go stale promptly and a
  peer may reclaim without waiting a full TTL.
- **Orphan self-termination is the crash path.** The renewer's loop condition is the
  reuse-robust `session_alive("$SESSION_PID", "$SESSION_PID_STARTTIME")` check. If the session
  **crashes** or is killed without the orderly stop, that check **fails on the next beat** —
  either the pid is gone, or the OS has recycled it to a process whose start-time no longer
  matches the recorded one — the loop exits, and the renewer **self-terminates**: it stops
  heartbeating, the lease goes stale within one TTL, and the slice becomes reclaimable.
  **Under this reuse-robust identity gate, a dead session cannot keep its own lease alive**,
  while a **live-but-busy** one keeps it fresh. (A bare-pid gate would *not* deliver this: a
  recycled `session-pid` would read "alive" and the orphaned renewer would refresh a dead
  session's lease forever — a permanent wedge, the very T2 class this ADR removes. The
  start-time pairing is what makes the self-termination guarantee hold.)

Renewal refreshes the lease timestamp under ADR 0014's §2 lock, exactly as ADR 0014 §3's
"a session holding a slice longer than the TTL must renew its lease" already required —
this ADR makes that renewal the **liveness mechanism itself** and relocates *who runs it*
from the blocked driver loop to the out-of-band renewer. The **~TTL/3 cadence** (an
operational default; the exact fraction is a slice-plan parameter) is now measured against
a renewer that is **not** suspended during sub-agent calls, so its margin need only cover
clock skew and a single missed *renewer* beat (e.g. a transient lock-contention backoff) —
**not** a multi-hour driver-loop suspension.

### 3. Failure to renew makes the work reclaimable — by design

The out-of-band renewer (§2) keeps a lease fresh for exactly as long as the **session
process is genuinely alive** — as decided by its **reuse-robust identity gate** (pid alive
**AND** its start-time still matches the recorded `session-pid-start-time`, §2), not by a
bare `kill -0` that a recycled pid could fool. When a session **stops running** — it
crashed, was killed, or ended cleanly — its renewer self-terminates (the pid is gone, or a
reused pid fails the start-time match), the lease goes **stale** within one TTL, and its
lock/claim becomes **reclaimable** by a peer (subject to ADR 0014's §2 lock serializing the
reclaim decision). This is **correct, not a defect: a
session that is no longer running is indistinguishable from a crashed one and should be
treated as one.** Crucially, because the renewer is **not** gated on the blocked main
thread, a session that is merely **suspended inside a long (20–40+ min) sub-agent call**
keeps renewing throughout and is **never** reclaimed while busy — the exact failure the
BLOCKER identified is foreclosed.

The **no-forward-progress-but-still-running** case (a wedge or livelock) composes with
[ADR 0013](0013-starvation-loop-guards-cold-restart.md): a session that wedges without
advancing is required to **escalate and stop**, not spin — and once it stops, its process
exits, the renewer's reuse-robust identity gate (§2) fails, and the lease becomes
reclaimable by the path above.
The heartbeat thus proves *the session is still running its work*, not merely that some
transient process once existed (the round-2 pid) nor that a directory persists on disk
after a crash (the round-3 membership) — the two properties both prior signals lacked. A
live, actively-working session — **including one blocked in a sub-agent call** — keeps its
lease fresh and is never reclaimed; a stopped or escalated-and-halted one is reclaimed
within a TTL.

### 4. Worktree-list membership and the ephemeral pid are NOT liveness signals

- **Worktree-directory presence is explicitly demoted.** A crashed session leaves its
  `wt-<sid>` directory on disk, and `git worktree prune` does **not** remove a present
  directory, so membership classifies a crashed session as alive forever (findings T2/T6).
  Membership answers "does a worktree dir exist," not "is the session alive." It **MUST
  NOT** gate liveness. Orphan-worktree cleanup is driven by **lease staleness** — when a
  peer force-reclaims a stale lease under the lock, it then removes that session's orphan
  worktree. This **closes the T2 permanent-wedge** and makes the **T6 orphan-removal path
  reachable** (it now fires off the stale-lease gate, not off an always-populated
  membership read).
- **The ephemeral per-invocation CLI pid is dropped as a liveness signal.** It is always
  dead by the time a peer probes it (the round-2 defect), so it reaps live sessions. **No
  peer ever probes any pid to decide another session's liveness** — a peer consults **only
  lease freshness** (§1), which is primary and sufficient. The one process identity that *is*
  probed is the **stable session process** (its `{session-pid, session-pid-start-time}` pair,
  §2), and it is probed **only locally, by the session's own background renewer**, to decide
  whether to keep beating its **own** leases — an **intra-session** gate, never a
  **cross-session** one. This is the sharp line that keeps §2's renewer sound while §4 keeps
  pid off the peer-facing path: the round-2 defect probed the *ephemeral CLI* pid *across
  sessions*; the renewer probes its *own stable session* process *locally*, and does so via
  the reuse-robust pid+start-time identity (§2) so a recycled pid cannot forge the answer.
  Any pid recorded in the lease stamp itself remains **advisory diagnostic metadata only**,
  never a liveness gate.

### 5. What ADR 0014 preserves (superseded ONLY on the liveness signal)

This ADR supersedes ADR 0014 **only** on the liveness-signal point, mirroring how
[ADR 0011](0011-correct-automated-review-command-to-code-review.md) superseded ADR 0010
**only on the command** and [ADR 0007](0007-namespaced-command-surface.md) superseded
ADR 0001 **only on naming**. Everything else in ADR 0014 stands **unchanged and in
force**:

- **session-owned slice worktrees** off fresh current local `main` (§1);
- the **cross-session `main`-critical-section lock** — atomic `mkdir`/ref-CAS acquire,
  the rename-capture/holder-stamp, the **`lock-TTL`**, and the ADR 0008 exponential
  backoff (§2);
- the **claim/lease registry** in `slice-plans/README.md`'s Active region, the
  **check-then-act-under-the-lock** claim, skip-live-claims, land-clears-the-claim, and
  the **slice-lease TTL/reclaim** semantics (§3);
- **per-session `.git/loom-session-<session-id>/` restart state** and the
  off-`main`, `session-id`-keyed **write-ahead cold-restart anchor** relocated there (§1);
- **cold-restart re-adoption and renewal** of a session's own held leases (§3);
- the **three locked shared-`main` writes** (claim, land, and the folded-in living-doc
  finalize), all under the §2 lock (§1);
- and every §4 preserved/extended invariant.

The **`session-id`** remains ADR 0014's stable, non-`pid`-derived session identifier and
remains **out-of-band coordination metadata only** — never commit/author metadata. This
**preserves [ADR 0001](0001-plugin-architecture-and-orchestrator.md)** (only the session
spawns) and **[ADR 0003](0003-cold-handoffs-commit-per-handoff.md)** (uniform
author-neutral identity; `session-id`/lease state stays out of commit metadata, so the
blind code-evaluator is unaffected). Under this ADR the `session-id` is used to *key* a
lease and identify its owner for renewal/re-adoption, but a session's `session-id`-in-`git
worktree list` **no longer proves it alive** — its **fresh lease** does.

## Consequences

- **Supersedes ADR 0014 only on the liveness signal.** ADR 0014 stays **Accepted** and
  **immutable** (ADRs are superseded, never rewritten — [ADR 0005](0005-specs-frozen-after-approval.md)
  discipline). Read ADR 0014 §3's "liveness keys primarily on `session-id`-in-`git
  worktree list`, pid secondary" as **replaced by** "liveness keys on **lease freshness**
  (renewal heartbeat within the TTL); membership and pid are not liveness signals." Every
  other ADR 0014 decision is untouched and in force (§5). Builds on ADR 0014, and preserves
  ADR 0001 and ADR 0003.
- **Closes the three-round oscillation — including for a session that is silent-by-
  architecture during its long ops.** Lease freshness is neither pid-aggressive (it does
  not depend on a process that is already gone) nor membership-lenient (it does not trust a
  directory that outlives a crash). A live session proves liveness by *continuing to renew*
  — and because the renewer is **out-of-band** (§2), "continuing to renew" holds even while
  the single-threaded orchestrator is **blocked for 20–40+ minutes inside a sub-agent
  call**: the renewer beats through the block, so a **legitimately-busy holder is never
  reclaimed**. A crashed or killed session's renewer falls silent (its **reuse-robust
  identity gate** — pid alive AND start-time matches, §2 — fails) and a wedged one is
  required to escalate-and-stop (ADR 0013), after which its process exits and its renewer
  likewise falls silent — so the slice is reclaimed within one TTL. **Under that reuse-robust
  identity gate** this closes findings **T2** (permanent wedge) and **T6** (unreachable
  orphan-removal), and removes the pid-reaping root cause behind the round-2 regression
  **without** reintroducing it during the long blocking ops that matter most. The closure
  depends on the pid+start-time identity: a **bare-pid** gate would leave the T2 wedge open,
  because a recycled `session-pid` would keep an orphaned renewer refreshing a dead session's
  lease forever (§2).
- **New standing obligation on every session.** On first acquiring any lock or claim, the
  session MUST start (**once**, not duplicated) an **out-of-band background renewer** that
  refreshes every held lease on the ~TTL/3 cadence for as long as the **stable session
  process is alive under the reuse-robust identity gate** (pid alive AND its start-time
  matches the recorded `session-pid-start-time`, §2), and MUST stop it on clean session-end
  (§2). Ceasing to renew — because the
  session crashed, was killed, or wedged in a starvation loop and escalated-and-stopped — is
  *defined* to make the work reclaimable (§3). This composes with ADR 0013's starvation-loop
  guard: a session that wedges without forward progress escalates-and-stops, its process
  exits, its renewer self-terminates, and the work correctly becomes reclaimable.
- **Spec 04's "Multi-session coordination" prose needs a follow-on amendment.** Spec 04
  states ADR 0014's coordination model; it must be amended to describe liveness as
  lease-freshness (heartbeat) rather than worktree-membership, and to record the renew
  obligation/cadence. The spec is **frozen (ADR 0005)**, so on approval this is a
  **deliberate later planning pass, not a landing side effect, and not part of this ADR.**
  (Do **not** edit spec 04 here.)
- **Helper re-implementation is a follow-on developer slice** (the
  `plugins/loom/lib/loom-coord.sh` helper, ADR 0014's deferred third piece of executable
  code, run through the normal plan → plan-eval → develop → code-eval loop, gated by the
  shell gate `shfmt → shellcheck → bats`). Beyond adopting the lease-freshness liveness
  signal, that slice **must also fix the mechanical defects the round-3 review found** so
  they are not carried forward:
  - **T1 — Linux `stat` portability.** The mtime/age read must work on GNU/Linux
    (`/bin/sh=dash`), not only BSD/macOS `stat`. The **gate and tests must exercise the
    Linux `stat` path**, not mask the bug behind local BSD `stat` runs.
  - **Process start-time capture portability (new, from this ADR's §2 identity gate).**
    Reading a process's start-time — the second half of the reuse-robust
    `{session-pid, session-pid-start-time}` identity — is **OS-specific**: the source and
    format differ across Linux (`/proc/<pid>/stat` field 22, or `ps -o lstart=`), macOS/BSD
    (`ps -o lstart=`/`-o start=`), etc. The re-implementation must capture and compare it
    **portably** (same GNU/Linux-`dash` vs BSD/macOS matrix as T1), and the **gate and tests
    must exercise the non-local OS path**, not mask a divergence behind local runs. The
    comparison is exact-equality of the recorded vs current start-time for the pid.
  - **T3 — `awk -v` escape processing** of the `session-id`: `-v` still applies escape
    processing, mangling ids containing a backslash; the id must be matched by exact string
    equality with no escape interpretation.
  - **T4 — holderless-lock reclaim window.** The holderless-lock age-gate refuses reclaim
    until the lock dir is older than `LOOM_LOCK_TTL` (~30s), but the lock-acquire backoff
    budget (~6.2s) is far shorter, so a crash-in-window holderless lock (mtime≈now) is never
    reclaimed within one invocation → the session stays blocked up to `LOOM_LOCK_TTL`. The
    lease-freshness decision does **not** resolve this — a **holderless** lock has no holder
    stamp whose freshness §1 could consult — so the re-implementation must independently
    reconcile the age-gate threshold with the acquire backoff budget (restoring the round-3
    "holderless always reclaimable" behavior it regressed).
  - **T5 — skipped-count accuracy:** a retained/corrupted claim must be counted in the
    "skipped M live claims" summary, not silently dropped.
  - **T7 — single shared acquire helper:** the age-gate/acquire logic (copy-pasted across
    four sites) must be single-sourced so a correctness change lands in exactly one place.
  (These are named as obligations on the re-implementation slice; **not implemented here**.)
- **Playbook bodies to update at the fold** (only **after** the spec-04 amendment is
  approved, per ADR 0005): `parallelism.md`, `orchestration.md`, and `run.md` — describing
  the renew heartbeat and the lease-freshness liveness gate. Named as consequences; not
  edited here.
- **No new status tokens, no gate change.** As with ADR 0014, the lease is bookkeeping in
  the `slice-plans/README.md` Active region, not a `Status:` value; this ADR refines the
  liveness *signal*, adding no lifecycle state and no change to `format → lint → test`.
- **TTL values not re-decided.** The `lock-TTL` and slice-lease TTL numeric values remain
  ADR 0014 slice-plan parameters. This ADR fixes only the renew **cadence's relationship**
  to the TTL (~TTL/3, comfortably below it); the exact cadence fraction is a slice-plan
  parameter.

## Notes

- Open for the re-implementation slice / spec-04 pass: the exact renew-cadence fraction
  (bounded here as comfortably below the TTL, ~TTL/3, measured against the **out-of-band
  renewer** that is *not* suspended during sub-agent calls) and its margin for clock skew
  and a single missed *renewer* beat; the concrete means by which the **stable session
  process identity `{session-pid, session-pid-start-time}`** is captured and recorded in the
  per-session `.git/` state (including the portable start-time read — carry-forward item)
  and the detached-renewer spawn/reap primitive (operational parameters of §2's mechanism);
  whether the lease
  timestamp is stored inline in the `slice-plans/README.md` Active row or in a `.git/`-side
  sidecar (an ADR 0014 open parameter, unchanged); and whether any advisory pid is retained
  in the lease stamp for diagnostics (permitted, but never as a liveness gate). The
  **principle decided here** is that liveness = lease freshness (a renewal heartbeat within
  the TTL, **kept beating by an out-of-band renewer** so a session blocked in a long
  sub-agent call is not reclaimed), that membership and the ephemeral pid are not
  peer-facing liveness signals, and that a session that stops renewing becomes reclaimable
  by design.
