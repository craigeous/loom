# Evaluation: multi-session-lock-helper

Verdict: FAIL
Round: 2
Reviewed against: ADR 0014 (§1/§2/§3 + §Consequences contract); spec 04 → "Multi-session
coordination (ADR 0014)" (the three locked main writes — claim / lease-renew / land —
and the session-id-primary liveness rule); the Approved slice-plan (CLI contract,
lock/claim/clear-and-own invariants, fail-closed); `gates/shell.md`; the advisory
review-findings artifact. Code-review phase: diff `4bb64b9..8f28b59`
(`plugins/loom/lib/loom-coord.sh` + `.bats`) walked, gate re-run, findings adjudicated.

## Code review — Round 2 (FAIL)

### Gate re-verification (independently re-run)

- `shfmt -i 4 -d` on both files → CLEAN.
- `shellcheck plugins/loom/lib/loom-coord.sh` → CLEAN (SC3043 suppressed file-wide).
- `bats plugins/loom/lib/loom-coord.bats` → 30/30 pass.

The gate is genuinely green, **but green is necessary, not sufficient**: the suite
exercises only happy paths and one sanitized cleanup case. The safety-critical
negatives (concurrent cleanup without the lock, holderless-lock recovery, orphan
worktree removal, substring claim collisions, `got_lock=0` paths) are **not** tested,
and four confirmed correctness bugs survive a green gate.

### Findings adjudication (advisory review-findings + independent verification)

Of 9 `/code-review` findings: **8 CONFIRMED, 1 REJECTED**. `/security-review`
ran-clean (informational, no findings to adjudicate). Findings 1/2/3/6 reproduced
empirically against the real helper in throwaway repos.

- [BLOCKER] **Finding 1 — unanchored `grep -F "${slice}\t"` claim matching
  (`read_claim`/`write_claim`/`remove_claim`, sh:190/200/216).** `grep -F` is an
  unanchored substring match, so `claim v2` matches an existing `auth-v2` line, and
  `write_claim`/`remove_claim`'s `grep -vF "v2\t"` **deletes `auth-v2`'s registry
  row**. Reproduced: seeding `auth-v2\t…` then filtering `v2\t` drops the line → a
  third session sees `auth-v2` free and claims it → **double-grant of a slice against
  main** — the exact safety property the helper exists to uphold. Defeats ADR 0014's
  no-double-grant guarantee.
- [BLOCKER] **Finding 2 — `cleanup` mutates `CLAIMS` without holding the lock
  (sh:824–849).** The claims-sweep read→filter→`mv` block is **outside** the
  `got_lock` guard. Reproduced: with a live peer holding the lock (so `got_lock=0`),
  `cleanup` still rewrote `claims` and dropped a row. A concurrent `claim` under the
  real lock holder, appended after `cleanup` snapshots `CLAIMS`, is clobbered by the
  `mv` → lost claim → re-claim → double-grant. Violates the mutual-exclusion invariant
  on the shared store and the plan's "live claims untouched" contract.
- [BLOCKER] **Finding 3 — holderless lock dir is permanently un-reclaimable
  (sh:357, also cleanup sh:803 / `clear_and_own` sh:274).** A crash between
  `mkdir "$LOCK_DIR"` and `stamp_holder` leaves a lock dir with no `holder` file. The
  stale-reclaim branch is gated on `[ -f "$HOLDER_FILE" ]` and `clear_and_own` returns
  1 when `holder` is empty. Reproduced: `lock-acquire` against a holderless dir → exit
  3 after every retry; **`cleanup` cannot clear it either** (lock dir still present
  after cleanup). All sessions deadlock on main until manual `rm`. A deadlock with no
  recovery path defeats the coordination helper.
- [BLOCKER] **Finding 6 — orphan-worktree path extraction is dead code
  (sh:563–566 / 835–838).** The `awk '… /^/{if(p&&b) print p; p="";b=""}'` catch-all
  `/^/` matches every line and resets `p`/`b` before they ever coexist. Reproduced
  against real porcelain output: prints **nothing**, so the `git worktree remove -f`
  branch in both `reclaim` and `cleanup` never fires. Consequence is not cosmetic: a
  crashed session that left its worktree **dir on disk** keeps its session-id in
  `git worktree list` → `is_alive` returns true → `reclaim`→exit 6 and `cleanup` skips
  it as live → its claim is **never reclaimable**. The plan's mandated crash-recovery
  ("`git worktree remove -f` the orphan worktree") is non-functional. Test CU1 masks
  this by `rm -rf`-ing the dead worktree dir *before* `cleanup`, so `git worktree
  prune` removes the ref and the dead `remove -f` path is never needed.
- [MAJOR] **Finding 4 — `is_alive` primary probe is an unanchored substring
  (`grep -qF "$sid"`, sh:125).** With caller-supplied `--session` tokens, a dead
  session whose id is a substring of any live worktree path/branch is read as alive →
  its lock/claims are never reclaimed (coordination wedge). Same root cause as
  Finding 1; both need exact-field matching.
- [MAJOR] **Finding 7 — `session-end` destroys `held-claims` without releasing the
  registry when `got_lock=0` (sh:740–776).** The lock-acquire loop has no
  stale-handling, and `rm -rf "$sess_dir"` (sh:776) runs unconditionally even when the
  lock was never acquired and claims were never released → orphaned registry rows with
  no held-claims backref. Violates the planned "release then remove" ordering and
  leaves inconsistent shared state that relies on the (also-buggy) `cleanup` to heal.
- [MINOR] **Finding 8 — dead `ORIG_SUBCOMMAND`/`SUBCOMMAND="lock-acquire"` dance in
  `session-bootstrap` (sh:663–700).** The inline function never reads `SUBCOMMAND`;
  pure noise. (The whole inline re-implementation of `lock-acquire` also duplicates
  `cmd_lock_acquire`; consider extracting a shared no-exit acquire helper.)
- [MINOR] **Finding 9 — `cleanup` re-runs `git worktree list` per dead claim while
  `is_alive` already ran it (sh:830/836).** ~2× redundant invocations over a
  constant-for-the-sweep list; hoist once.
- REJECTED — **Finding 5 (PLAUSIBLE)** "holder liveness relies solely on session-id in
  the worktree list; an active holder without a sid-bearing worktree is judged dead."
  This is the spec's own **session-id-primary** rule and is explicitly carried as
  slice W's documented precondition (plan lines 108–116: every session must name its
  worktree path to embed its session-id). The helper correctly depends on, and
  documents, that precondition; it is by-design and out of this code-only slice's
  scope — not a defect in the diff under review.

### Independent observations

- The four BLOCKERs share two root causes — (a) substring matching where exact-field
  (`awk -F'\t' '$1==s'`) matching is required (Findings 1, 4), and (b) shared-state
  mutation / `rm -rf` performed off the `got_lock` guard (Findings 2, 7). Fixing the
  pattern, not just the call sites, is the durable repair.
- Scope, identity, and structure are otherwise sound: code-only, no `hooks.json`
  entry (REG1 asserts it), no commits / no git-identity writes (ADR 0003 untouched),
  state under `<git-dir>/loom/`, fail-closed exit 10 on no-repo (FC1/FC1b prove ≠ 0).
  The rename-capture CAS mutual-exclusion core (the round-1 BLOCKER) holds and L5
  proves it under a real race. These are not regressed; the defects above are new
  correctness gaps in the surrounding claim/cleanup/liveness machinery.

### Required changes (for FAIL)

1. Replace every unanchored `grep -F "${slice}\t"` / `grep -vF "${slice}\t"` claim
   lookup and edit (`read_claim`, `write_claim`, `remove_claim`) with an exact
   first-field match (e.g. `awk -F'\t' -v s="$slice" '$1==s'` for select and
   `$1!=s` for delete). Add a bats case proving `claim v2` does not touch an
   `auth-v2` row (and vice-versa).
2. Gate all `CLAIMS` mutation in `cmd_cleanup` behind `got_lock=1` — when the lock
   cannot be acquired, sweep nothing and exit non-zero (fail-closed). Add a bats case
   that runs `cleanup` while a live peer holds the lock and asserts `claims` is
   unchanged.
3. Make a holderless lock dir recoverable: treat `lock` dir present with absent/empty
   `holder` past TTL as stale in both `lock-acquire` and `cleanup` (and let
   `clear_and_own` capture-and-clear it). Add a bats case seeding a holderless
   `main.lock/` and asserting recovery (not a permanent exit 3).
4. Fix the orphan-worktree path extraction so `git worktree remove -f` actually fires
   in `reclaim` and `cleanup` (correct the awk so a worktree path prints with its
   branch). Add a bats case where the dead session's worktree **dir still exists** on
   disk (do not pre-`rm` it) and assert the orphan is removed and the claim reclaimed.
5. Anchor the `is_alive` worktree probe to a session-id-token boundary rather than a
   bare substring (Finding 4).
6. In `session-end`, do not `rm -rf` the session dir when the lock was not acquired
   and claims were not released; add stale-lock handling to its acquire loop or defer
   removal. Add a `got_lock=0` bats case.
7. (MINOR, may bundle) Remove the dead `SUBCOMMAND` dance in `session-bootstrap`
   (Finding 8); hoist the redundant `git worktree list` in `cleanup` (Finding 9).

## Plan review — Round 1 (PASS, history)

Reviewed against: ADR 0014 (§1/§2/§3 + §Consequences contract); spec 04 → "Multi-session
coordination (ADR 0014)" (the three locked main writes — claim / lease-renew / land —
and the session-id-primary liveness rule); `gates/shell.md`; existing hook style in
`plugins/loom/hooks/*.sh`; plan-eval-rubric. Re-review of the round-1 FAIL; diff
`2494d9d..6686635` walked.

## Prior findings — all resolved

- **(BLOCKER 1, closed) Stale-clear is now concurrency-safe.** The bare `rm -rf` + re-`mkdir`
  is replaced by a per-contender **rename-capture CAS** plus two invariants (new section
  "Lock ownership invariants + atomic clear-and-own", plan lines 145-199). Walked the
  interleavings against a single dead holder D with two contenders A/B:
  - The `mv "$LOCK_DIR" "$CAP"` of a single source serializes to **exactly one** winner
    (loser gets ENOENT, clears nothing, re-loops) — the standard POSIX directory-rename
    CAS, and `CAP`/`LOCK_DIR` are siblings under `$STATE_DIR` so `mv` is a real
    `rename(2)`, not a copy.
  - Ownership is **only ever installed by `mkdir "$LOCK_DIR"` succeeding** (INV-1, the
    single atomic gate), and only on a captured-stamp **== H_obs** match. I could not
    construct a path where two contenders both install ownership: whichever first
    `mkdir`s the freed slot wins; the other's `mkdir` hits EEXIST and degrades to a normal
    contended read. The ABA branch (a live peer reclaimed in the window) yields a
    stamp mismatch → ownership is **never** installed → restore-or-discard. Verified
    against the task's "two contenders both own a stale lock" bar: not reachable.
  - INV-2 (re-assert `holder`==self immediately before every locked effect; for the raw
    `git merge` via the new `lock-verify` precondition) closes ADR 0014 race point 4: even
    a momentarily-displaced live holder aborts fail-closed at its next re-assert rather
    than double-merging.
- **(BLOCKER 2, closed) Real concurrency test added.** New bats case "mutual exclusion
  under concurrent stale reclaim" (lines 310-318) seeds one dead holder, launches **two**
  contenders as concurrent background subshells via the race harness defined in step 2(d)
  (`&` … `wait` … capture each exit code + resulting `holder`), asserts **exactly one**
  exit 0 / the other exit 3 / `holder` == the single winner, under a 10× repeat loop. This
  is a racing process test, not a prose assertion, and it targets the dead-holder reclaim
  race specifically. Paired with "a second `acquired` is never observable while a first is
  held."
- **(MAJOR, closed) `lock-verify --session` holder-assertion primitive** is added to the
  CLI table (exit 0/5/10), to the exit-code contract, as a bats case (verify-self=0,
  verify-other=5, no-lock=5, no-repo=10, asserts no `holder` change), and **mandated as
  W's pre-`git merge` land precondition** (INV-2). Closes the one main write that was
  previously unguarded by a post-acquire re-check.
- **(MINOR a, closed) Registry-before-README ordering + fail-closed rollback** specified
  (lines 89-106): registry write precedes the README commit, both under the one lock; W
  must `release-claim` to roll the registry back if the README render/commit fails. The
  fail-direction rationale (README-claimed-but-registry-free → double-grant) is correct.
- **(MINOR b, closed) W worktree-path-embeds-session-id precondition** stated explicitly
  (lines 108-116) as the foundation the session-id-primary probe rests on.

## Findings

- [MINOR] **Orphaned `$CAP` capture dirs have no sweep.** A contender that crashes between
  `mv "$LOCK_DIR" "$CAP"` and the `rm -rf`/restore leaves a `.main.lock.reclaiming.*` dir
  under `$STATE_DIR`. This is disk litter only — it never touches `$LOCK_DIR` or `claims`,
  and the displaced dir was a *dead* holder's, so the lock is correctly freed — but the
  `cleanup` sweep (plan line 225) lists stale locks/claims/session dirs and does not name
  these captures. Consider having `cleanup` also remove stale `.main.lock.reclaiming.*`.
- [MINOR] **`$CAP` name-collision edge.** `CAP=…reclaiming.<session-id>.<pid>.<epoch>` is
  unique across sessions, but a same-session re-entry within the same epoch second could
  collide; `mv srcdir existing-CAP-dir` nests rather than replaces. Not reachable under
  one-lock-acquire-per-session use, but the developer should guard (e.g. include a short
  random suffix, or `rm -rf "$CAP"` before the `mv`).
- [MINOR] **`lock-verify` → raw `git merge` is an irreducible TOCTOU (W's wiring).** The
  rename-capture introduces a narrow window in which a live holder's lock dir can be
  transiently displaced (the acknowledged ABA case); INV-2 makes every *helper-mediated*
  act safe, but the land path's `git merge` is W's unmediated op, so the gap between
  `lock-verify` and `git merge` is not closed by this helper. This is the spec's own
  helper-provides-`lock-verify` / W-calls-it-before-an-unmediated-merge contract and is out
  of this code-only slice's scope — flagged so W keeps that pair as tight as possible and
  considers a future mediated-land.

## Notes

The revision is faithful and complete: the new lock primitive is a genuine mutex (mkdir is
the sole ownership gate; ownership is never installed on a stamp mismatch; the mv-loser
backs off), and the safety property is now proven by a real racing bats case rather than
asserted. Mechanically verified: `plugins/loom/lib/` does not yet exist (the "new dir" claim
holds); the state-resolution reference matches `precompact-write-ahead-backstop.sh` lines
60-80 (with the fail-direction correctly inverted to fail-closed exit 10); the shell gate is
a path-generic `format → lint → test` recipe the developer applies to the new files, so the
"no `gates/shell.md` edit" claim is correct. Preserved sound parts are not regressed:
lock-TTL (30s) stays distinct from the slice-lease TTL (3600s); fail-closed (exit 10,
asserted ≠ 0) inverts the guard hooks; the three spec-04 locked writes map cleanly (claim /
`renew` / land-via-`lock-verify`); ADR 0003 is untouched (no commits, no identity); scope is
code-only (W wiring + README rendering deferred, not a hook, no `hooks.json` entry). The
three MINORs are advisory housekeeping / W-scoped and do not block.
