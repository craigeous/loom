# Evaluation: multi-session-lock-helper-plan.md

Verdict: FAIL
Round: 1
Reviewed against: ADR 0014 (§1/§2/§3 + §Consequences contract); spec 04 → "Multi-session
coordination (ADR 0014)" (the three locked main writes + session-id-primary liveness);
`gates/shell.md`; existing hook style in `plugins/loom/hooks/*.sh`; plan-eval-rubric.

## Findings

- [BLOCKER] **Stale-lock force-clear is not concurrency-safe — it reintroduces a
  double-acquire race on the very critical section the lock exists to protect.**
  `lock-acquire` (CLI table, line 111) specifies the stale path as: read `holder`, probe
  dead, "force-clear (`rm -rf` the lock dir) and re-acquire (re-stamp)." A plain
  `rm -rf "$LOCK_DIR"` is unconditional on the directory, not on the dead holder it
  observed. With two contenders A and B and one **dead** holder D:
  - B reads `holder=D`, probes D dead (decides to clear);
  - A reads `holder=D`, probes D dead;
  - A `rm -rf` D, A `mkdir` (OK), stamps `holder=A`, returns `acquired`;
  - B `rm -rf` — **deletes A's live lock dir** — B `mkdir` (OK), stamps `holder=B`,
    returns `acquired`.
  Both sessions are now told they hold the lock. `mkdir` atomicity does **not** save
  this, because the unconditional `rm -rf` destroys a freshly-won lock. The `claim`/`renew`
  subcommands re-assert `lock_held_by_self` and would mostly catch A on the *claim* path
  (A gets exit 5), but **land is a raw `git merge`+finalize performed by W with no
  helper-mediated post-acquire holder re-check** (Claim-store boundary + Scope sections
  delegate land to W). So two sessions can both believe they hold the lock and both enter
  the land critical section → exactly ADR 0014 race point 4 (concurrent merge corruption)
  the lock is built to prevent. The force-clear must be made atomic per-contender — e.g.
  atomically `mv`/rename the observed-stale lock dir to a unique per-contender name (only
  one rename of a given dir can win), verify it captured the dead holder, then remove it
  and `mkdir` the fresh lock; or an equivalent compare-and-swap. A bare `rm -rf` + re-`mkdir`
  is insufficient for a primitive whose entire job is mutual exclusion.

- [BLOCKER] **No test proves single-winner under concurrent force-clear.** The bats plan's
  "stale force-clear gated on liveness (positive)" exercises a *single* contender against a
  dead holder. The safety-critical negative — **two contenders, one dead holder → exactly
  one ends up holding** (the other gets exit 3, holder stamp belongs to exactly one) — is
  absent. A plan that asserts mutual exclusion but never tests it under concurrent stale
  reclaim does not prove the property. Add this case (and, given the land path, a case that
  a second "acquired" can never be observed while a first is held).

- [MAJOR] **The helper exposes no holder-assertion primitive for W's raw land write.**
  All claim/lease subcommands re-check `lock_held_by_self`, but land (W's wiring) is a raw
  `git merge`. There is no `lock-verify --session` (assert-held → exit 5 if not) the lander
  can call immediately before the merge to confirm ownership after any force-clear window.
  Even with the BLOCKER fixed, the lock's safety for the land path depends on a primitive
  this helper does not provide. Add an assert-held subcommand (or specify `lock-holder`
  comparison as the mandated land precondition) so the highest-stakes main write is not the
  one path with no ownership re-check.

- [MINOR] **Dual claim-store (`.git/loom/claims` registry vs the spec-authoritative
  `slice-plans/README.md` lease) — pin the write-ordering and exit-0 semantics.** Spec 04
  pins the authoritative lease to the README Active region; the plan introduces a sidecar
  registry (permitted by ADR 0014 Notes' "sidecar under `.git/`" option) and delegates the
  README render + the "landed-in-interim" (Active→Archived) half of check-then-act to W.
  Consequently the helper's `claim` exit 0 means "no live peer claim in the registry" — it
  does **not** mean "not already landed." That is documented, but the cross-store
  consistency rule W must honor (which store is written first under the held lock so a
  partial failure fails closed, not open) is not stated. Specify it so W cannot wire a
  registry-grants-but-README-shows-archived window.

- [MINOR] **Session-id-primary liveness silently depends on W embedding the session-id in
  worktree paths.** The probe is "session-id token appears in `git worktree list
  --porcelain`," and the bats fabrication relies on a worktree *path* containing the token.
  If W names worktrees without the session-id, every live holder reads as dead → the helper
  force-clears live locks/leases (catastrophic). This is derivable from spec 04's
  session-id-primary rule, but the helper's correctness rests on it — state it as an
  explicit precondition on W's worktree naming.

## Required changes (for FAIL)

1. Replace the `rm -rf` + re-`mkdir` stale-clear with an **atomic, per-contender
   clear-and-own** (rename-capture or CAS) so two contenders observing the same dead holder
   cannot both end up holding the lock; describe the exact sequence in the `lock-acquire`
   behavior cell.
2. Add a bats case proving **mutual exclusion under concurrent stale reclaim** (two
   contenders, one dead holder → exactly one holder; the loser exits 3), and that a second
   `acquired` is never observable while a first is held.
3. Provide a holder-assertion primitive (e.g. `lock-verify --session` → exit 5 if not
   self) for W's raw land write, or specify the mandated `lock-holder`-compare precondition
   for land.
4. (MINOR, recommended) State the registry↔README write-ordering / fail-closed rule W must
   honor, and the W precondition that worktree paths embed the session-id.

## Notes

The plan is otherwise faithful and unusually thorough: lock-TTL (30s) is correctly held
distinct from the slice-lease TTL (3600s); the live-holder-NOT-cleared, interim-claim-abort,
reclaim-does-not-steal-a-live-lease, and restart-re-adoption-renews negatives are all named
as bats cases; fail-closed (exit 10, asserted ≠ 0) correctly inverts the guard hooks;
ADR 0003 is untouched (no commits, no identity); scope is clean (helper not a hook, W wiring
and README rendering scoped out, `plugins/loom/lib/` a sensible home); and the
`precompact-write-ahead-backstop.sh` state-resolution reference (lines 60–80) checks out
against the real file. The verdict turns solely on the lock primitive's concurrency safety:
a mutex whose stale-reclaim can hand "acquired" to two sessions is not yet a mutex, and the
suite does not test the property. Close the force-clear race and prove it, and this is a
PASS.
