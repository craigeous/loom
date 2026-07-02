# 0016 — Git-Native Ref Compare-and-Swap as the Lock/Claim Substrate

Status: Plan Review
Date: 2026-07-02

## Context

[ADR 0014](0014-multi-session-worktree-coordination.md) (Accepted/immutable) lets the
owner run **N independent `/loom:run` sessions** against one repo by serializing their
writes to the one shared `main` through a **cross-session lock** and a **slice-lease**
protocol. [ADR 0015](0015-lease-renewal-heartbeat-liveness.md) (Accepted/immutable) then
fixed the **liveness signal** — a holder is live iff its **lease is fresh** (a renewal
heartbeat within the TTL), kept beating by an out-of-band renewer; worktree-list
membership and the process pid are not liveness signals.

Neither ADR fixed the **lock/claim *substrate*** — the concrete atomic primitive under
the coordination model. ADR 0014 §2 deliberately left the primitive **open** ("an
OS-atomic primitive — a `mkdir`-based lock directory … **or** a git-ref
compare-and-swap"), a slice-plan parameter. The
[multi-session-lock-helper slice-plan](../slice-plans/multi-session-lock-helper-plan.md)
resolved that parameter to a **hand-rolled `mkdir` lock directory + a rename-capture CAS
stale-steal + a TSV claims registry** (`<git-dir>/loom/main.lock/` with a `holder` file;
`<git-dir>/loom/claims`). Spec [04](../spec/04-orchestrator.md)'s "Multi-session
coordination" prose likewise names the mkdir/rename-capture substrate.

That hand-rolled substrate went **four implementation rounds** and the last blind review
([multi-session-lock-helper-review-findings.md](../evaluations/multi-session-lock-helper-review-findings.md))
CONFIRMED a fresh cluster of **concurrency-correctness double-grant paths that are
artifacts of hand-rolling atomicity in POSIX-sh**, not of the coordination model:

- **U1 — lock-reclaim CAS ABA/TOCTOU (CONFIRMED).** `clear_and_own` re-reads the holder
  for its ABA baseline (`h_obs`) **separately** from the caller's staleness check, so two
  contenders that both saw the lock stale can both "capture" it and **two holders write
  `.docs/` concurrently**. This is the intrinsic hazard of reconstructing compare-and-swap
  out of `mkdir` + directory `rename(2)` + a re-read.
- **U3 — the lock is never heartbeat (PLAUSIBLE).** The renewer refreshes the **lease**
  (claim) but **not the lock stamp**, so a live session holding the main lock through a
  `land`/merge that exceeds `LOOM_LOCK_TTL` (30 s) has its lock **stolen** by a peer →
  concurrent writers.
- **U4 — narrowed holderless-reclaim window widened a double-grant (CONFIRMED).** The
  non-atomic `mkdir`→`stamp_holder` gap: a contender reclaims a holderless dir while the
  first acquirer is descheduled between `mkdir` and its stamp, and **both report
  "acquired"**. This gap exists **only** because acquire is two steps (create the dir,
  then write the holder) rather than one atomic operation.

The remaining findings — **U2** (fail-OPEN on empty/non-numeric lease epoch), **U5**
(`renewer-stop` kills a recycled pid when start-time is empty), **U6** (cleanup sweeps
live claims / `rm -rf`s a live session dir), and the **secondary** cluster (non-atomic
`session.pid` write; `/proc/<pid>/stat` field-22 start-time mis-parse when `comm`
contains spaces/parens; the portable-`stat` / start-time lesson exercised on Linux, not
masked) — are **not** substrate-specific: they are ordinary fail-closed/parse defects that
**survive any substrate change** and must be carried forward.

The owner has **decided the direction: use git's own atomic reference compare-and-swap as
the lock/claim substrate.** This ADR records that decision and scopes the supersession
precisely. It does **not** re-open the coordination model (ADR 0014) or the liveness
signal (ADR 0015).

**In scope:** the lock/claim **substrate** — git refs + `git update-ref` CAS; the ref
layout; acquire / stale-steal / release / claim / renew / release-claim / reclaim expressed
as CAS ops; **lock-lease renewal** to fix U3; and the ABA-safety argument.

**Out of scope (flagged as follow-ons, not done here):** the **spec-04 amendment**
(a deliberate frozen-spec planning pass — [ADR 0005](0005-specs-frozen-after-approval.md));
the **helper re-implementation** slice (a developer slice through the normal
plan → plan-eval → develop → code-eval loop), which must **carry forward the non-substrate
defects** below; and the concrete **TTL values / renew cadence**, which remain ADR
0014/0015 slice-plan parameters.

## Decision

**Use git's own atomic reference compare-and-swap — `git update-ref <ref> <newvalue>
<oldvalue>` — as the lock/claim substrate, replacing the hand-rolled `mkdir` lock +
rename-capture CAS + TSV claims registry.** This supersedes ADR 0014 **only on the
lock/claim mechanism**, mirroring how [ADR 0011](0011-correct-automated-review-command-to-code-review.md)
superseded ADR 0010 **only on the command** and how ADR 0015 superseded ADR 0014 **only on
the liveness signal**. ADR 0014's coordination model and ADR 0015's lease-freshness
liveness stand **unchanged** and now ride this substrate (see §5).

### 1. The lock is a git ref; acquire/steal/release are CAS ops

The `main`-critical-section lock (ADR 0014 §2) is a single git ref — **`refs/loom/lock`**
— whose value is a small **blob** object encoding the holder record
**`{session-id, lease-timestamp, session-pid, start-time}`**. The record object is created
content-addressably with `git hash-object -w --stdin` (which produces a **blob**, carrying
**no** author/committer metadata — see §5 on ADR 0003). Every state transition is a
compare-and-swap against the **exact object SHA the caller last read**:

- **Acquire (create-only CAS).** `git update-ref refs/loom/lock <holder-blob>
  0000000000000000000000000000000000000000` — the null old-value requires the ref to be
  **absent**; it fails if any peer already holds the lock. On success the caller holds it.
- **Stale-steal (value CAS).** Read the current holder blob SHA `H_obs` **and** decode its
  lease-timestamp; **only when the lease is stale by ADR 0015** (older than the `lock-TTL`),
  `git update-ref refs/loom/lock <my-holder-blob> <H_obs>`. git's old-value check requires
  the ref to **still equal `H_obs`** at the instant of the swap; if any peer changed it in
  the interim the CAS **fails** and the caller loses and retries.
- **Release (delete CAS).** `git update-ref -d refs/loom/lock <my-holder-blob>` — deletes
  the ref **only if** it still equals the caller's own holder blob, so a session that
  already lost the lock cannot delete a peer's.

**ABA-safe by construction.** The old-value in a CAS is the **exact prior object SHA the
caller read** — not a re-derived baseline read separately from the staleness check (the U1
defect). git compares that SHA atomically under its own per-ref lock and swaps only on an
exact match. Any peer that changed the ref between the caller's read and its `update-ref`
makes the old-SHA check **fail → the caller cleanly loses and retries** — there is no
window in which two contenders both believe they captured the same stale lock. This
**eliminates U1** (the ABA/TOCTOU double-grant), **eliminates U4** (there is no separate
`mkdir`→`stamp` window: the holder blob is created *first*, then the ref is pointed at it in
one atomic operation, so an acquired lock is fully-stamped the instant it exists), and
retires the entire hand-rolled `clear_and_own` / rename-capture machinery.

### 2. Claims are per-slice refs; claim/renew/reclaim are CAS ops

Each slice claim (ADR 0014 §3 lease) is a per-slice ref — **`refs/loom/claims/<slice>`** —
whose value is a blob encoding **`{session-id, lease-timestamp}`** (the pid, if recorded at
all, is advisory diagnostics only — ADR 0015). The TSV claims registry is retired; each
claim is an independent ref:

- **Claim (create-or-steal CAS).** Read `refs/loom/claims/<slice>`. If absent →
  create-only CAS from null (as §1). If present and **fresh** by another session → the
  slice is taken (abort + re-select). If present and **stale** by ADR 0015 (lease older
  than the slice-lease TTL) → value-CAS steal from the exact read SHA, gated on staleness.
  If the caller's **own** fresh claim → idempotent re-affirm.
- **Renew.** Value-CAS the claim ref (and the lock ref, §3) from its exact read SHA to a
  blob with a refreshed `lease-timestamp`.
- **Release-claim / land-clears-the-claim.** Delete-CAS the claim ref from the caller's own
  blob (land subsumes this, ADR 0014 §3).
- **Reclaim.** Stale + liveness-gated (ADR 0015 lease-freshness) value-CAS steal, plus the
  orphan-worktree cleanup (`git worktree prune` / `git worktree remove -f`) ADR 0014 §3
  already defines.

Because each claim is an independent ref, two sessions claiming **different** slices never
contend, and two sessions racing the **same** slice resolve by CAS — exactly one wins.

### 3. Lease-freshness liveness (ADR 0015) is preserved AND now also fixes U3

ADR 0015's liveness signal is unchanged: a holder is live iff its **lease-timestamp is
within the TTL**, kept fresh by the out-of-band background renewer (ADR 0015 §2), and every
force-steal is gated on that lease-freshness check. The renewer's heartbeat is now a
**CAS-renew of the holder ref's `lease-timestamp`** (§2 for claims, and — the U3 fix —
**also for the lock ref while the lock is held**). Because the lock ref's holder record
carries a `lease-timestamp` (§1) and the renewer refreshes it, a session running a long
`land`/merge keeps its **lock** lease fresh, so a peer's stale-steal gate (§1) sees the
lock as **live** and does **not** steal it. This **closes U3** (the un-renewed lock stolen
mid-critical-section) directly within the ADR 0015 model — the steal decision keys on the
holder's lease freshness, which the renewer now keeps fresh for the lock, not only the
claim. Peers still decide liveness by lease freshness alone (never by membership or pid).

### 4. git owns the atomicity across all worktrees; the concurrency guarantee

All worktrees of a repository **share one common ref store** (the common git dir), so a ref
written by session A is **immediately visible** to session B — the natural cross-session
medium, exactly where the mkdir lock and TSV registry already lived (under `.git/`,
shared). `refs/loom/lock` and `refs/loom/claims/*` are **ordinary refs in the common ref
store**, **not** per-worktree pseudo-refs (they must not be created under any
per-worktree/`refs/worktree/` namespace, which would defeat cross-session visibility).

The concurrency guarantee this substrate **relies on**: **git ref updates are atomic.**
`git update-ref <ref> <new> <old>` takes git's own per-ref lock, verifies the ref still
equals `<old>`, sets `<new>`, and releases — as one atomic transaction; a mismatch (or a
lost race for the ref's own transient `.lock`) makes the command exit **non-zero**, a
**clean, detectable failure** the caller retries with backoff. This **replaces the
hand-rolled `index.lock`-style retry with git's own ref-transaction semantics**: loom no
longer reconstructs compare-and-swap out of filesystem primitives — it delegates atomicity
to the tool that already owns it. The transient ref-`.lock` contention is retried with the
**same ADR 0008 §3 exponential backoff** the coordination model already mandates (the same
mechanism, now under a git-native primitive); a losing *value*-CAS is likewise a retry.

### 5. What ADR 0014/0015 preserve (superseded ONLY on the substrate)

This ADR supersedes ADR 0014 **only on the lock/claim mechanism** — the concrete atomic
primitive and its storage. **Everything else in ADR 0014 and all of ADR 0015 stand
unchanged and in force:**

- ADR 0014's **coordination model in full**: session-owned slice worktrees off fresh
  current local `main` (§1); per-session `.git/loom-session-<session-id>/` restart state and
  the off-`main`, `session-id`-keyed write-ahead cold-restart anchor (§1); the **three
  locked shared-`main` writes** (claim, land, folded-in living-doc finalize) (§1); the
  check-then-act-under-the-lock claim, skip-live-claims, land-clears-the-claim, and
  stale-lease TTL/reclaim **semantics** (§3); cold-restart lease re-adoption/renewal (§3);
  and every §4 preserved/extended invariant. Only the **substrate** those semantics run on
  changes (mkdir-dir + TSV → refs + `update-ref` CAS).
- ADR 0015's **lease-freshness liveness** in full: liveness = lease freshness (a renewal
  heartbeat within the TTL); the out-of-band renewer with its reuse-robust
  `{session-pid, session-pid-start-time}` identity gate; membership and the ephemeral pid
  are not liveness signals. §3 above extends the renewer's heartbeat to cover the **lock**
  ref, which ADR 0015 already contemplated ("the lock must be heartbeat too").
- [ADR 0001](0001-plugin-architecture-and-orchestrator.md) — only the session spawns —
  untouched.
- [ADR 0003](0003-cold-handoffs-commit-per-handoff.md) — the holder record lives in a
  **`refs/loom/*` blob** (via `git hash-object -w`), which carries **no** author/committer
  metadata, and those refs are **never** `refs/heads/*` branch history and **never** appear
  in the blind code-evaluator's slice-commit diff. The `session-id`/`session-pid` in the
  record are out-of-band coordination metadata only — **never** commit/author metadata.
  Uniform author-neutral identity is untouched.

ADR 0015 §5's preserved-list incidentally re-states the old mkdir/rename-capture substrate;
read every such substrate reference (in ADR 0014 §2 and ADR 0015 §5) as pointing to the
substrate **now in force** — git `update-ref` CAS — while ADR 0015's liveness *decision*
is untouched.

## Consequences

- **Supersedes ADR 0014 only on the lock/claim mechanism.** ADR 0014 and ADR 0015 stay
  **Accepted** and **immutable** (superseded, never rewritten — ADR 0005 discipline). Read
  ADR 0014 §2's "atomic acquire/release primitive — a `mkdir`-based lock directory … or a
  git-ref compare-and-swap," together with the slice-plan's resolution of that parameter to
  a mkdir lock + rename-capture CAS + TSV registry, as **replaced by** git-native
  `update-ref` CAS on `refs/loom/lock` + `refs/loom/claims/<slice>`. Every other ADR 0014
  decision and all of ADR 0015 are untouched and in force (§5). Builds on ADR 0014/0015 and
  preserves ADR 0001/0003.
- **Closes the substrate-artifact double-grants.** The git-native CAS **eliminates U1**
  (ABA/TOCTOU — the old-value SHA is the read SHA, checked atomically) and **U4** (no
  non-atomic `mkdir`→`stamp` window — the holder blob exists before the ref points at it),
  and **fixes U3** by extending the ADR 0015 renewer's heartbeat to CAS-renew the **lock**
  ref's lease-timestamp so a long `land` is never stolen. The hand-rolled `clear_and_own`
  rename-capture machinery is retired.
- **The helper re-implementation slice MUST carry forward the non-substrate defects** the
  last review found — the substrate change does **not** auto-fix these, and they must not be
  reintroduced on the git-CAS substrate (named here as obligations; **not implemented
  here**):
  - **U2 — fail-CLOSED on a bad lease epoch.** An empty/non-numeric `lease-timestamp` must
    be treated as **not fresh in the fail-closed direction** — i.e. it must **never**
    classify a peer's live claim as stale/reclaimable. (In the ref model the timestamp is a
    field of the holder blob; the parse must reject an unparseable epoch as ambiguous →
    deny, not as `0` → stale.)
  - **U5 — guard `renewer-stop` against a recycled pid.** When the recorded renewer
    start-time is empty, `renewer-stop` must **not** `kill` the bare recorded pid: with no
    start-time to confirm identity it may signal an unrelated recycled process. It must fail
    closed (skip the kill) rather than bypass the `{pid, start-time}` identity gate.
  - **U6 — cleanup must not sweep live claims / `rm -rf` a live session dir.** The repo-wide
    cleanup sweep must gate every claim removal and every `session-<id>/` `rm -rf` on the
    same lease-freshness liveness check, so a live-but-momentarily-stale holder's claim and
    per-session state are never destroyed.
  - **Secondary robustness carry-forwards.** Atomic `session.pid` write (write-to-temp +
    `mv`, never a partial read); correct start-time parse that is robust to a `comm` field
    containing spaces/parens (do **not** naively split `/proc/<pid>/stat` on whitespace to
    reach field 22); and the **portable `stat` / process-start-time** lesson — the gate and
    `bats` tests must **exercise the Linux path** (GNU/Linux `dash`), not mask a divergence
    behind local BSD/macOS runs.
  - The git-CAS substrate **obviates** several mkdir-specific mechanical obligations the
    prior rounds carried (the holderless-lock reclaim-window reconciliation and the
    single-sourced mkdir age-gate/acquire helper) — those defects cannot recur without the
    mkdir primitive. The **coordination semantics** the re-implementation must still honor
    (three locked writes, check-then-act claim, cold-restart re-adoption, renew cadence
    ≈ TTL/3) are unchanged from ADR 0014/0015.
- **Spec 04's "Multi-session coordination" prose needs a follow-on amendment.** Spec 04
  currently names the `mkdir`/rename-capture-CAS substrate; it must be amended to fold in
  the git-`update-ref` CAS substrate (the ref layout, acquire/steal/release/claim/renew as
  CAS ops, the lock-ref heartbeat). The spec is **frozen (ADR 0005)**, so on approval this
  is a **deliberate later planning pass, not a landing side effect, and not part of this
  ADR** — spec 04 is **not** edited here.
- **Playbook bodies + the helper re-implementation follow at the fold.** After the spec-04
  amendment is approved, `parallelism.md` / `orchestration.md` / `run.md` describe the
  git-CAS substrate, and the `plugins/loom/lib/loom-coord.sh` helper is **re-implemented**
  on refs (gated by the shell gate `shfmt → shellcheck → bats`, run through the normal
  loop). The lock/claim state moves from `<git-dir>/loom/main.lock/` + `<git-dir>/loom/claims`
  to `refs/loom/lock` + `refs/loom/claims/*`; the per-session `.git/loom-session-<id>/`
  restart state (ADR 0014 §1) is unchanged.
- **No new status tokens, no gate change.** As with ADR 0014/0015, the claim is coordination
  bookkeeping (now a ref, not a `Status:` value); this ADR changes only the substrate, adding
  no lifecycle state and no change to `format → lint → test`.
- **Easier / harder.** Easier: loom delegates cross-worktree atomicity to git's ref
  transactions instead of reconstructing CAS from `mkdir`+`rename`, removing the class of
  hand-rolled-atomicity double-grants (U1/U3/U4). Harder / new: the helper must encode/decode
  the holder blob (`hash-object -w` / `cat-file`), drive create-only, value, and delete CAS
  correctly, and keep `refs/loom/*` out of any per-worktree ref namespace so cross-session
  visibility holds.

## Notes

- Open for the re-implementation slice / spec-04 pass: whether the holder record is a plain
  blob (recommended — no author metadata) or a structured line, and its exact field
  encoding; whether `refs/loom/lock` and `refs/loom/claims/<slice>` are the final names;
  the exact create-only sentinel (the all-zero OID vs `git update-ref --stdin`
  `create`/`verify` transactions for multi-ref atomicity); and the retry policy for a lost
  ref-`.lock` vs a lost value-CAS (both reuse the ADR 0008 backoff). The **principles
  decided here** are: the substrate is git `update-ref` CAS on `refs/loom/*`; the CAS
  old-value is the exact read object SHA (ABA-safe by construction); the lock ref's lease is
  heartbeat by the ADR 0015 renewer (U3 fixed); the refs live in the **common** shared ref
  store; and the non-substrate defects U2/U5/U6 + secondary are re-implementation
  obligations, not auto-fixed by the substrate change.
