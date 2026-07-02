# 0015 — Lease-Renewal Heartbeat as the Liveness Signal

Status: Draft
Date: 2026-07-02

## Context

[ADR 0014](0014-multi-session-worktree-coordination.md) (Accepted, immutable) makes N
independent `/loom:run` sessions coordinate on the one shared `main` through a
cross-session lock and a slice-lease protocol. Both of its force-clear paths — the §2
stale-**lock** reclaim and the §3 stale-**lease** reclaim — are gated on a positive
**"holder is dead" liveness check**, not on a TTL alone. ADR 0014 §3/§F5 chose that
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
liveness-signal point** (its §3/§F5 "session-id-in-`git worktree list`, pid secondary"
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

### 2. The renew obligation and cadence (a driver-loop responsibility)

While holding a lock or a claim, a session **MUST** renew its lease on a cadence **well
below the TTL** — nominally **~TTL/3** (an operational default; the exact fraction is a
slice-plan parameter, bounded by "comfortably below the TTL with margin for clock skew
and a missed beat"). Renewal refreshes the lease timestamp under the §2 lock, exactly as
ADR 0014 §3's "a session holding a slice longer than the TTL must renew its lease" already
required — this ADR makes that renewal the **liveness mechanism itself**, not merely
anti-reclaim bookkeeping. Renewal is a **driver-loop responsibility** of the session (the
thin orchestrator), consistent with ADR 0014 §3's cold-restart re-adoption, under which a
bootstrapping session re-adopts its held-claims set and renews each held lease.

### 3. Failure to renew makes the work reclaimable — by design

If a session **stops renewing** — because it crashed, hung, wedged in a starvation loop
([ADR 0013](0013-starvation-loop-guards-cold-restart.md)), or otherwise stopped making
progress — its lease goes **stale** within one TTL and its lock/claim becomes
**reclaimable** by a peer (subject to the §2 lock's serialization of the reclaim decision).
This is **correct, not a defect: a session that has stopped making progress is
indistinguishable from a crashed one, and should be treated as one.** The heartbeat is a
liveness proof of *ongoing progress*, not merely of *process existence* — which is exactly
the property both prior signals lacked (pid proved a transient process that is already
gone; membership proved a directory that outlives the crash). A live, actively-working
session keeps its lease fresh and is never reclaimed; a silent one is reclaimed within a
TTL.

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
  dead by the time a peer probes it (the round-2 defect), so it reaps live sessions. If a
  pid is retained at all it may only be **advisory diagnostic metadata** in the lease
  stamp (never a liveness gate), and if any pid were ever to be used as a signal it must be
  a **stable, long-lived session pid**, never the per-invocation CLI pid — but **lease
  freshness is primary and sufficient**, so no pid probe is required for correctness.

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
  discipline). Read ADR 0014 §3/§F5's "liveness keys primarily on `session-id`-in-`git
  worktree list`, pid secondary" as **replaced by** "liveness keys on **lease freshness**
  (renewal heartbeat within the TTL); membership and pid are not liveness signals." Every
  other ADR 0014 decision is untouched and in force (§5). Builds on ADR 0014, and preserves
  ADR 0001 and ADR 0003.
- **Closes the three-round oscillation.** Lease freshness is neither pid-aggressive (it
  does not depend on a process that is already gone) nor membership-lenient (it does not
  trust a directory that outlives a crash). A live session proves liveness by *continuing
  to renew*; a crashed or wedged one falls silent and is reclaimed within one TTL. This
  directly closes findings **T2** (permanent wedge) and **T6** (unreachable orphan-removal),
  and removes the pid-reaping root cause behind the round-2 regression.
- **New standing obligation on every session.** While holding any lock or claim, the
  session's driver loop MUST renew its lease on the ~TTL/3 cadence (§2). Ceasing to renew
  is *defined* to make the work reclaimable (§3). This composes with ADR 0013's
  starvation-loop guard: a session that wedges without forward progress will also stop
  renewing and correctly become reclaimable.
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
  - **T3 — `awk -v` escape processing** of the `session-id`: `-v` still applies escape
    processing, mangling ids containing a backslash; the id must be matched by exact string
    equality with no escape interpretation.
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
  (bounded here as comfortably below the TTL, ~TTL/3) and its margin for clock skew and a
  single missed beat; whether the lease timestamp is stored inline in the
  `slice-plans/README.md` Active row or in a `.git/`-side sidecar (an ADR 0014 open
  parameter, unchanged); and whether any advisory pid is retained in the lease stamp for
  diagnostics (permitted, but never as a liveness gate). The **principle decided here** is
  that liveness = lease freshness (a renewal heartbeat within the TTL), that membership and
  the ephemeral pid are not liveness signals, and that a session that stops renewing
  becomes reclaimable by design.
