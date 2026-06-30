# 0014 — Multi-Session Worktree Coordination

Status: Plan Review
Date: 2026-06-29

## Context

[ADR 0008](0008-parallel-docs-coordination-worktree-per-slice.md) makes a **single**
orchestrator's sub-agent worktrees conflict-free **by construction**: each in-flight
slice is a disjoint, uniquely-named file set on its own branch+worktree, and the three
living docs + the `slice-plans/README.md` index are "main-only, owned by the
orchestrator, **serialized**." That serialization is real only because ADR 0008 assumes
exactly **one** orchestrator session writing main.

The owner runs **multiple independent top-level `/loom:run` sessions** against the same
repository at once (each is its own thin orchestrator — [ADR 0012](0012-thin-orchestrator-sonnet-default-bounded-return.md) —
that cold-restarts independently — [ADR 0013](0013-starvation-loop-guards-cold-restart.md)).
With N sessions, ADR 0008's "serialized on main" is **false**: nothing serializes one
session's main writes against another's. The sessions race at **four** points:

1. **Shared `main` working tree.** Every session mutates the same physical checkout —
   concurrent file writes clobber each other and concurrent git writes collide on the
   shared `.git/` `index.lock` (ADR 0008 §3 / research gotcha 1, but now *across*
   sessions, where there is no single serializing writer).
2. **Driver-loop dispatch.** Both sessions scan the same `Status:` lines
   ([status-machine.md](../../plugins/loom/skills/loom-playbook/references/status-machine.md))
   and independently pick the **same** next action → the **same** slice is implemented
   twice, wasting work and producing two divergent branches for one slice.
3. **Main living-doc + `slice-plans/README.md` writes.** ADR 0008 routes these through
   "the orchestrator on main, serialized." With N orchestrators there is no
   cross-session serialization — concurrent writers race the index and clobber each
   other's living-doc edits.
4. **Concurrent merge+finalize on `main`.** Two sessions landing a slice at the same
   moment corrupt the index / leave a half-merged tree (ADR 0008's land sequence
   assumes a single serial lander).

ADR 0008's *intra-session* guarantee is sound and unchanged: disjoint slice files
**cannot** collide, so they need no lock. What is missing is a model for the
**irreducibly-shared** resource — the one `main` checkout and the single-instance
coordination files on it — when more than one session contends for it. That resource
**cannot** be made conflict-free by construction the way disjoint slice files can; it
needs real mutual exclusion.

**Foundation preserved.** [ADR 0001](0001-plugin-architecture-and-orchestrator.md) (only
the orchestrator/session spawns) and [ADR 0003](0003-cold-handoffs-commit-per-handoff.md)
(uniform author-neutral identity across all roles and worktrees) are prerequisites this
ADR relies on and does **not** change. ADR 0003 is what keeps cross-session commits
blind-eval-safe: a slice landed by session A is indistinguishable in author/committer
metadata from one landed by session B, so the blind code-evaluator still sees one
uniform identity. The worktree mechanics are the prior art in
`.docs/research/2026-06-08-git-worktree-parallel-slices.md` (Approved) — reused here, not
re-derived.

**In scope:** the multi-session coordination model — session-owned slice worktrees, the
cross-session lock on `main`'s critical section and its backoff, the slice claim/lease
protocol with stale-claim reclaim, and which ADR 0008 invariants are preserved vs
extended. **Out of scope:** the concrete lock/claim *mechanism* implementation (a
POSIX-sh helper — record the contract, not the code; a playbook build item, exactly as
ADR 0008 deferred its `background`-spawn wiring); any change to the status state machine
(spec [03](../spec/03-artifact-lifecycle.md), unchanged); and spec
[04](../spec/04-orchestrator.md)'s Parallelism amendment, which is a deliberate later
planning pass (specs frozen — [ADR 0005](0005-specs-frozen-after-approval.md)), not part
of this ADR.

## Decision

Extend ADR 0008 from "one orchestrator's sub-agents in worktrees" to "**N independent
sessions**, each owning its slice worktrees, coordinating on the one shared `main`
through a cross-session lock and a slice-lease protocol." Three parts.

### 1. Session-owned slice worktrees and per-session restart state

A top-level `/loom:run` session **never does slice work in the shared `main` checkout.**
When a session picks up a slice it creates **its own** worktree off **fresh current
`main`** and runs all of that slice's roles there:

```
git worktree add -b <slice-branch> <session-owned-path> main
```

This is ADR 0008 §1's `git worktree add` rule, **extended one level**: where ADR 0008
isolated *one orchestrator's sub-agents* into per-slice worktrees, ADR 0014 isolates
*each session's* slice work the same way. The disjoint-files-by-construction guarantee
(ADR 0008 §2) therefore carries over unchanged at the slice level — two sessions building
two independent slices still write disjoint, uniquely-named path sets and cannot collide
on any slice file. (The base is the shared **local** `main`, not `origin/main`: loom
commits directly to local `main` and does **not** push, so a landed slice appears on
local `main` first and `origin/main` lags. This refines ADR 0008 §1's literal
`origin/main` for loom's single-machine, no-push model; see §3 for the
authoritative-read rule.)

**Per-session restart state — off `main`, never the shared living docs.** A thin session
must, per [ADR 0013](0013-starvation-loop-guards-cold-restart.md) rule 1, write its
**next intended action ahead of every large/in-window op** so a cold restart
([ADR 0012](0012-thin-orchestrator-sonnet-default-bounded-return.md), ~60% budget)
resumes from an advancing anchor. Under a **single** orchestrator, ADR 0008's one shared
`handoff.md` could double as both the human-facing status doc **and** that machine
cold-restart anchor. With **N** sessions those two roles **must split**, because a shared
single-instance `handoff.md` would (a) be a frequent shared-`main` write **outside** the
§2 lock and (b) let a restarting session A re-bootstrap from session B's checkpoint and
resume B's action (and misfire ADR 0013 rule 3's forward-progress guard). Therefore:

- The **machine cold-restart anchor** moves to **per-session state keyed by `session-id`,
  persisted outside the tracked worktree** (under `.git/`, like the §2 lock dir and
  ADR 0013 §5's marker — e.g. `.git/loom-session-<session-id>/`). It holds the session's
  **`session-id`**, its **write-ahead checkpoint** (next intended action), and its
  **held-claims set** (which slices it currently leases, §3). Because it is under `.git/`
  it is **never** a tracked, mergeable `main` file: writing it is **not** a `main` write,
  needs **no** lock, and is **per session**, so a restarting session reads only **its
  own** anchor — never another session's. This **preserves ADR 0013 rule 1's write-ahead
  invariant** (lead-not-trail, advancing anchor) and **extends only its medium** — from
  the shared `main` `handoff.md` to a per-session `.git/` checkpoint; ADR 0013 stays
  Accepted/immutable. ADR 0013 rule 3's forward-progress guard now reads this
  **per-session** checkpoint plus the session's own most-recent commit, so it can never
  confuse one session's progress for another's.
- The **human-facing `handoff.md`** (and `roadmap.md`/`progress.md`) **stay shared,
  single-instance, on `main`** — ADR 0008's living-doc model is intact — but a session
  updates them only as part of **land**, under the §2 lock (below), at milestone
  granularity, **not** on the per-op write-ahead cadence. That frequent write-ahead
  cadence is absorbed entirely by the off-`main` per-session checkpoint.

**Exactly which shared-`main` writes exist, and how each is multi-session-safe.** With
the restart anchor moved off `main`, a session mutates the shared `main` checkout at
exactly **two** moments, **both inside the §2 lock**:

1. **Claim** — write the slice's lease into `slice-plans/README.md`'s Active region (§3).
2. **Land** — merge+finalize: `git merge <slice-branch>`, the living-doc finalize updates
   (`progress.md`/`handoff.md`, and `roadmap.md` if a milestone closed), and moving the
   slice Active → Archived in `slice-plans/README.md` (ADR 0008 §2). The living-doc writes
   ADR 0008 routes "through the orchestrator on main, serialized" are folded **into this
   locked land section** — so they are shared-`main` writes **under the lock**, not a
   separate unguarded write.

The per-session write-ahead **checkpoint is deliberately *not* one of these** — it is
off-`main` per-session `.git/` state. At all other times a session operates only in its
own slice worktree(s). This closes race point 1 (no free-for-all on the `main` working
tree), brings **every** shared-`main` write under the §2 lock, and is the precondition
for closing 2–4. The "all four races closed" property now holds with **no** unguarded
living-doc/`handoff.md` write left open.

### 2. A cross-session lock on `main`'s critical section

The critical section is **`{claim-a-slice, merge+finalize}`** — the only operations that
touch the shared `main` checkout and its single-instance coordination files (the three
living docs + `slice-plans/README.md`). Guard it with a **cross-session mutex**:

- **Atomic acquire/release primitive.** Use an OS-atomic primitive — a `mkdir`-based lock
  directory under `.git/` (e.g. `.git/loom-main.lock/`; `mkdir` is atomic and fails if it
  exists) **or** a git-ref compare-and-swap. It must live **outside** the tracked worktree
  (under `.git/`, like ADR 0013 §5's checkpoint marker) so it is never itself a tracked,
  mergeable file, and it must be **per-repository** (shared across all sessions/worktrees,
  since `.git/` is shared). On acquire, the holder **stamps the lock with its own
  liveness identity** — a small file inside the lock dir (e.g. `holder` containing
  `{session-id, pid, acquired-timestamp}`); on release it removes the lock dir. The
  `session-id`/`pid` are out-of-band liveness metadata only — **never** commit/author
  metadata (ADR 0003 untouched).
- **Stale-lock liveness reclaim — a `lock-TTL`, distinct from the §3 slice-lease TTL.**
  An `mkdir` lock does **not** free itself: a session that dies mid-critical-section while
  holding `.git/loom-main.lock/` would otherwise deadlock **every** other session, which
  would back off forever. To break that deadlock the lock carries its **own** short
  **`lock-TTL`** — covering the *lock dir*, separate from and much shorter than the
  slice-lease TTL of §3 (a held lock is a milliseconds-to-seconds main-side op, §below;
  a lease spans a whole slice). A contender that has been backing off past the `lock-TTL`
  must not blindly clear the lock on the timeout alone — **the liveness check, not the TTL,
  gates the force-clear.** It reads the lock's `holder` stamp and **verifies the holder is
  actually dead** — its `session-id` is absent from `git worktree list` **and/or** its
  `pid` is not alive (`kill -0`) — and **only then** force-clears the stale lock dir
  (`rm -rf`/`rmdir`) and re-acquires (re-stamping with its own holder). A holder that is
  **live but slow** (still in `git worktree list` / `pid` alive) must **NOT** be cleared —
  the contender keeps backing off and lets the slow holder finish. This is a **distinct
  mechanism from the §3 slice-lease TTL**: §2's `lock-TTL` protects the short main-critical
  lock against a crashed lock-holder; §3's lease TTL protects a whole in-flight slice
  against a crashed claimant.
- **Backoff on contention — reuse ADR 0008 §3.** A session that cannot acquire the lock
  retries with the **exponential backoff ADR 0008 §3 already defines** for `index.lock`
  (3–5 attempts at ~200ms, 400ms, 800ms, …). This is the **same** mechanism applied to a
  **coarser** resource: ADR 0008 §3 backs off on the transient `.git/index.lock`; ADR 0014
  backs off on the explicit `main`-critical-section lock. The transient-`index.lock`
  backoff of ADR 0008 §3 still applies **underneath** for the individual git writes inside
  the section.
- **Hold the lock only for the critical section, never across role spawns.** The lock
  brackets a **short, bounded** main-side operation (claim, or merge+finalize); a session
  does **not** hold it while a role works in a slice worktree. This keeps the serialized
  resource contended for milliseconds-to-seconds, not for the duration of a slice.

This makes ADR 0008's "serialized on main" true **across** sessions, not merely within
one — closing race points 3 and 4. It applies **only** to the irreducibly-shared `main`
critical section; it does **not** weaken ADR 0008's conflict-free-by-construction
guarantee for disjoint slice files, which remain lock-free.

### 3. Slice claiming / leasing

Two sessions must not pick the **same** next action (race point 2). A **lease** in the
`slice-plans/README.md` Active region, written under the §2 lock, prevents it:

- **Scan a fresh view of current `main` — never the slice-worktree snapshot.** A session's
  slice worktree is created off a **snapshot** of current `main` (§1) and goes stale the
  moment any other session lands or claims work. The per-loop **dispatch scan** — reading
  the `Status:` lines *and* the lease/Active claim-state to derive the next action — must
  therefore be performed against a **fresh view of current `main`**, **not** the session's
  own stale slice-worktree checkout. **The single authoritative read for "what has landed
  and what is claimed" is the shared *local* `main`** — loom commits directly to local
  `main` and does **not** push, so a peer's claim/land lands on local `main` first while
  `origin/main` lags (and reading it would force a needless fetch/push round-trip, worse
  still inside the held lock). The **unlocked** dispatch scan may consult `origin/main`
  (via `git fetch`) only as an **optimization / pre-filter**; it is **not** authoritative.
  The check-then-act re-read that correctness depends on (next bullet) reads **local
  `main` under the §2 lock**. This stops a session re-picking a slice that another session
  already landed or claimed but that is invisible in its frozen snapshot.
- **Claim is a check-then-act under the lock — the lock serializes the *decision*, not
  just the write.** To take slice X a session acquires the §2 lock and, **while holding
  it, re-reads the lease/Active region from current local `main`** (the authoritative read
  above). If X was **claimed (a live lease) or landed (moved to Archived)** by another
  session in the interim — between the unlocked dispatch scan and acquiring the lock — the
  session **aborts the claim and re-selects** a different next action (or releases and
  loops). **Only when the re-read still shows X free** does it write its
  **claim** — a `{session-id, pid, lease-timestamp}` marker in the **Active** region
  (session-id is a per-session identifier, e.g. a uuid, and `pid` is recorded so the §3
  liveness check has a probe target; **not** the author identity — ADR 0003's
  uniform identity is untouched) — commit that index update on `main`, then release the
  lock. Only **then** does it create the slice worktree (§1) and dispatch roles. This
  closes the claim TOCTOU: because the read-validate-write is one locked section, two
  sessions cannot both observe X free and both claim it.
- **Skip live claims.** When deriving the next action, a session **skips** any slice whose
  Active entry carries a **live** (non-expired) claim by another session. This makes the
  driver-loop dispatch session-aware: two sessions scanning the same `Status:` lines now
  diverge on which slice they take.
- **Cold-restart lease recovery — a restarting session re-adopts and renews its own
  leases.** A lease spans a whole slice (below), so it routinely straddles a session's
  **own** ~60% lossless cold restart (ADR 0012/0013), which clears the window of the
  **same** OS process and gives it a **new** `pid`. The lease must survive that, and two
  facts make it safe:
  - **`session-id` is stable across restart and never `pid`-derived.** It is allocated
    **once** at session start and persisted in the per-session `.git/` state of §1
    (recoverable by the same process after a context clear). On **cold-restart bootstrap**
    the session **re-reads that state**, re-adopts its `session-id` and its **held-claims
    set**, and — under the §2 lock — **renews each held lease**: refresh its
    `lease-timestamp` **and** overwrite its recorded `pid` with the new process's `pid`.
    A restarted session therefore recognizes its own leases and **renews** rather than
    orphaning them.
  - **The liveness check sees the session as alive across its own restart.** A cold
    restart clears context, **not** the filesystem: the session's worktrees persist on
    disk, so its `session-id` stays present in `git worktree list` for the whole restart.
    The liveness gate (below) keys **primarily on `session-id`-in-`git worktree list`**,
    with `pid` only a secondary probe, so a peer **never** sees the lease as dead during
    the restart — even in the brief window before the `pid` is refreshed. Equally, the
    live `session-id` does not block *legitimate* reclaim indefinitely, because the
    restarting session refreshes the lease promptly on bootstrap.

  This satisfies the cold-restart invariant — a restarting session **recovers** (re-adopts
  and renews) its claim rather than orphaning it or deadlocking, and a still-live session's
  slice is never reclaimed across its own restart.
- **Stale-claim reclaim (slice-lease TTL).** A crashed session leaves a stale lease and an
  orphaned worktree. A claim whose `lease-timestamp` is older than the **slice-lease TTL**
  is a reclaim *candidate*, but — as with the §2 lock — the force-reclaim is gated on a
  positive **liveness check, not the TTL alone**: under the §2 lock, the reclaiming session
  verifies the lease's `session-id` is dead (absent from `git worktree list`, and/or its
  recorded `pid` not alive) before it runs `git worktree prune` + `git worktree remove -f`
  for the orphan (ADR 0008 §3 crash cleanup), clears or overwrites the expired Active entry,
  and claims the slice itself. A live-but-slow holder is **not** reclaimed. A session holding a slice
  longer than the TTL must **renew** its lease (refresh the timestamp under the lock) so a
  legitimately long-running slice is not reclaimed out from under it. (The concrete TTL
  value and the renew cadence are a slice-plan parameter, not fixed here.)
- **Land clears the claim.** Landing a slice (the merge+finalize already inside the §2
  lock, ADR 0008 §2) moves its entry Active → Archived in the same locked section, which
  **is** the claim release. No separate unclaim step.

This makes the lease the single source of "who is doing what" across sessions, written on
`main` under the one lock that already serializes the index.

### 4. What ADR 0008 invariants are preserved vs extended

- **Preserved unchanged:** disjoint slice files are conflict-free **by construction** and
  remain **lock-free** (ADR 0008 §1/§2); the orchestrator/session is the only spawner
  (ADR 0001); uniform author-neutral identity across all worktrees and sessions
  (ADR 0003) — sessions are distinguished by an out-of-band `session-id` in the lease,
  **never** by commit metadata, so blind eval is unaffected; the per-worktree
  `git-identity-guard.sh` hook stays stateless and parallel-safe (ADR 0008 §3), which now
  also means **cross-session**-safe; planning of shared design memory
  (`spec/`/`ADR/`/`research/`) stays a non-parallel serial pass (ADR 0008 §4 / ADR 0005).
- **Extended:** ADR 0008's "main-only, serialized" coordination — previously guaranteed by
  there being a single orchestrator — is now guaranteed by the §2 cross-session lock; the
  `git worktree add` isolation extends from one orchestrator's sub-agents to each session's
  slice work, with its base read as the shared **local** `main` (loom's no-push model,
  §1/§3) rather than ADR 0008 §1's literal `origin/main`; ADR 0008 §3's exponential
  backoff extends from the transient `index.lock` to the explicit `main`-critical-section
  lock — which **additionally** gains its own `lock-TTL` liveness-reclaim (§2) so a crashed
  lock-holder cannot deadlock all sessions; the `slice-plans/README.md` Active region gains
  a **lease** dimension (`session-id` + `pid` + `lease-timestamp`) on top of the
  Active/Archived bookkeeping ADR 0008 already put there; and **ADR 0013 rule 1's
  cold-restart anchor** extends its *medium* — from the shared `main` `handoff.md` to a
  **per-session `.git/` checkpoint** keyed by a stable, non-`pid` `session-id` (its
  write-ahead *invariant* unchanged) — while the human-facing `handoff.md` stays shared on
  `main`, written at land under the §2 lock.

## Consequences

- **ADR 0008's single-orchestrator assumption is lifted.** "Serialized on main" becomes a
  cross-session property, so the owner may safely run multiple `/loom:run` sessions on one
  repo. This **builds on and extends** ADR 0008 (the way ADR 0012 extends ADR 0002); it
  **supersedes nothing** — ADR 0008 remains Accepted and immutable, and every one of its
  intra-session guarantees still holds.
- **Builds on, does not change, ADR 0001, 0003, 0012, and 0013.** Only-the-session-spawns
  and uniform author-neutral identity (0001/0003) are prerequisites; the `session-id`/`pid`
  live out of band — in the lease and the per-session `.git/` state — so cross-session
  commits stay indistinguishable to the blind evaluator. ADR 0012/0013's thin-orchestrator
  cold-restart is **preserved**: rule 1's write-ahead invariant holds with its anchor
  relocated to per-session `.git/` state (§1), and rule 3's forward-progress guard reads
  that per-session state — so a session never resumes another's checkpointed action, and a
  session re-adopts and renews its own leases across its own restart (§3).
- **Spec 04's Parallelism section needs a multi-session amendment.** Spec 04 currently
  states ADR 0008's single-orchestrator coordination model; it must be amended to fold in
  this multi-session model (session-owned worktrees, the main-critical-section lock, the
  lease protocol). The spec is frozen (ADR 0005), so on approval that is a **deliberate
  later planning pass**, **not** a landing side effect — and **not** part of this ADR. (Spec
  08 playbook guidance and `09-open-questions.md`, if it tracks a related OQ, are folded in
  the same pass.)
- **New playbook build item (the mechanism, deferred — like ADR 0008's spawn wiring).**
  The concrete lock + claim/lease helper is loom's **third** piece of executable code
  (after `git-identity-guard.sh` and `precompact-write-ahead-backstop.sh`): a **POSIX-sh**
  helper alongside the existing two hooks, **identity-neutral**, persisting its lock/marker
  **outside** the tracked worktree (under `.git/`), gated by the **shell gate**
  (`shfmt` → `shellcheck` → `bats`) and code-eval. This ADR records the **contract**: atomic
  acquire/release with a holder liveness-stamp (`{session-id, pid, acquired-timestamp}`);
  backoff; the **lock-TTL stale-lock liveness reclaim** of §2 (verify-dead-then-force-clear,
  never clear a live-but-slow holder); the **per-session restart state** of §1 (a
  `.git/`-side, `session-id`-keyed record of `{session-id, write-ahead checkpoint,
  held-claims}`, **off `main`**, with a `session-id` that is **stable across restart and
  not `pid`-derived**); the **fresh-current-`main` dispatch scan** of §3 with the
  **authoritative read pinned to local `main` under the lock** (`origin/main` only an
  unlocked optimization); the **check-then-act-under-the-lock** claim of §3 (re-validate X
  is still free after acquiring the lock); the **cold-restart lease re-adoption/renew** of
  §3 (on bootstrap, re-read the per-session state and renew each held lease under the lock —
  refresh `lease-timestamp` **and** `pid`); a liveness check keyed **primarily on
  `session-id`-in-`git worktree list`** (so a session's own restart never looks dead); lease
  format; and the slice-lease TTL/reclaim semantics. The implementation runs through the
  normal loop
  (plan → plan-eval → develop → code-eval). The `lock-TTL` value, the slice-lease TTL value,
  the renew cadence, and the lock primitive choice (`mkdir`-dir vs ref-CAS) are **slice-plan
  parameters**.
- **Playbook bodies to update at the fold:** `parallelism.md` (the operational
  worktree-per-slice body — add the multi-session layer), `orchestration.md` (the
  claim/land critical-section + lock steps), and `run.md` (each session claims before it
  works). These are wired only **after** the spec-04 amendment is approved, per ADR 0005.
- **Easier:** multiple owner-driven sessions on one repo without clobbering `main`,
  double-implementing a slice, or corrupting a concurrent merge; crashed sessions
  self-heal via TTL reclaim + `git worktree prune`.
- **Harder / new obligations on each session:** it must create session-owned worktrees off
  fresh current **local** `main`, maintain per-session restart state under `.git/`
  (`session-id` + write-ahead checkpoint + held-claims), acquire/release the
  main-critical-section lock around claim and land, write+renew a lease, re-adopt and renew
  its own leases on cold-restart bootstrap, skip live-claimed slices, and run stale-claim
  reclaim. These are the playbook build items above.
- **No new status tokens.** The state machine in spec 03 is unchanged; the lease is
  bookkeeping in the `slice-plans/README.md` Active region (ADR 0008's bucket), **not** a
  new `Status:` value. This ADR adds *cross-session coordination*, not a new lifecycle
  state.

## Notes

- Open for the slice-plan / spec-04 pass: the concrete `lock-TTL` and slice-lease TTL
  values and the lease-renew cadence; the lock primitive choice (`mkdir` lock-dir vs git-ref
  CAS) and its exact failure semantics; whether the lease marker is a structured line in
  `slice-plans/README.md` or a sidecar under `.git/`; the exact liveness probe
  (`git worktree list` vs `kill -0 <pid>` vs both, and the fallback when neither is
  available); and the exact persistence location/format of the per-session `.git/` restart
  state (§1) plus the source from which a stable, non-`pid` `session-id` is allocated and
  recovered after a context clear (e.g. a session-scoped environment handle the same
  process keeps, or a `.git/`-side current-session marker). The **principle** that a
  force-clear is gated on a positive holder-is-dead check — for both the §2 stale lock and
  the §3 stale lease — is **decided here**, as is that the **cold-restart anchor is
  off-`main`, per-session, and keyed by a `session-id` stable across restart** (§1); only
  the probe's concrete form and that state's concrete location/derivation are parameters.
