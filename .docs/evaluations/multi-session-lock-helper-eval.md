# Evaluation: multi-session-lock-helper

Verdict: FAIL
Round: 4
Reviewed against: ADR 0014 (§1/§2/§3 + §Consequences contract); ADR 0015 (lease-freshness
liveness + {pid,start-time} renewer); ADR 0016 (git-`update-ref` CAS substrate); spec 04 →
"Multi-session coordination"; the Approved slice-plan (CLI contract, fail-closed);
`gates/shell.md`; the advisory review-findings artifact. Latest phase (Round 4) reviews the
git-CAS RE-IMPLEMENTATION, delta `eedfc43..9fa9b63` (3 commits) —
`plugins/loom/lib/loom-coord.sh` + `.bats` walked, gate re-run, findings adjudicated.

## Code review — Round 4 (FAIL)

Re-review of the **git-CAS re-implementation** (`eedfc43..9fa9b63`: `e0699f2` ref-CAS lock,
`d342a77` claims→refs + lock heartbeat, `9fa9b63` U2/U5/U6/secondary fixes). The substrate
was swapped from the hand-rolled `mkdir`/rename-capture lock + TSV registry to git
`update-ref` CAS on `refs/loom/lock` + `refs/loom/claims/<slice>` per ADR 0016. Adjudicated
the refreshed review-findings artifact (`/code-review` ran-with-findings V1–V6 CONFIRMED;
`/security-review` ran-clean) plus independent verification.

### Gate re-verification (independently re-run)

- `shfmt -i 4 -d plugins/loom/lib/loom-coord.sh` → **CLEAN**.
- `shellcheck plugins/loom/lib/loom-coord.sh` → **CLEAN** (SC3043 suppressed file-wide).
- `bats plugins/loom/lib/loom-coord.bats` → **55/55 pass**. Existing hook suites
  (`git-identity-guard.bats`, `precompact-write-ahead-backstop.bats`) → **39/39**, untouched;
  `hooks.json` has no loom-coord entry (REG1). The gate is genuinely green — but **green is
  not sufficient**: the confirmed defects below survive it because the suite exercises each
  destructive path with an *already-dead* holder and never races a lock-free `renew` against
  cleanup/reclaim (V2/V3), never holds a lock across a renewer heartbeat (V1/V4), and never
  feeds a git-illegal or case-colliding slice name (V5/V6).

### The git-CAS core is SOUND (verified — not regressed)

The substrate itself is correct and closes the prior mkdir-CAS ABA/double-grant class:
acquire is a **create-only CAS** (`update-ref <ref> <blob> <null-OID>` — fails unless the ref
is absent); stale-steal and renew are **value-CAS** against the **exact read SHA**; release is
a **delete-CAS** against the caller's own blob. git takes its per-ref lock and swaps only on an
exact old-SHA match, so two contenders can never both win (CC1 proves exactly-one-winner under
a real concurrent race; SC1 round-trips; the holder blob is created *before* the ref points at
it, so there is no `mkdir`→`stamp` window). Confirmed the prior U1/U4 hand-rolled-atomicity
hazards are retired. **The remaining defects are all in the PERIPHERAL logic around the CAS**,
exactly as the review preamble states.

### Findings adjudication (advisory review-findings + independent verification)

`/code-review` V1–V6: **6 CONFIRMED, 0 rejected** (V5/V6 reproduced empirically in scratch
repos on this macOS host; V1–V4 traced against the source). `/security-review` ran-clean
(informational — no vuln to adjudicate; its note that V5/V6 are correctness-not-security
defects is correct).

- [BLOCKER] **V1 — renewer cadence (1200 s) is 40× the lock TTL (30 s); the lock heartbeat
  cannot keep a held lock fresh (sh:43, heartbeat sh:1096–1109).** The single renewer loop
  heartbeats BOTH the claim refs (lease TTL 3600 s — `1200 ≈ TTL/3`, correct) AND the lock ref
  (lock TTL 30 s — `1200 = 40× TTL`, broken) at the *same* `LOOM_RENEW_INTERVAL`. A session
  holding `refs/loom/lock` across a `land`/merge that exceeds 30 s has its lock value-CAS-stolen
  by a peer at the 30 s mark before the renewer ever beats → two sessions believe they hold the
  lock → concurrent README/merge writers → **double-grant against main**. This directly defeats
  the U3 fix ADR 0016 §3 mandates ("the renewer now keeps [the lock lease] fresh … a long
  `land` is never stolen") — an ADR-0016 invariant violation. Fix: the lock heartbeat needs a
  cadence below the SHORTEST TTL it refreshes (≈ lock-TTL/3 ≈ 10 s), separate from the lease
  cadence.
- [BLOCKER] **V2 — `cleanup` destroys a LIVE holder's worktree + session dir BEFORE the
  guarding delete-CAS (sh:1006–1015).** For a claim whose snapshot lease read stale, cleanup
  runs `worktree remove -f` (sh:1007) and `rm -rf $STATE_DIR/session-$sid` (sh:1011) **before**
  `update-ref -d "$refname" "$sha"` (sh:1014). `renew` is lock-free (value-CAS, sh:547), so a
  holder that renews in the snapshot→destroy window (SHA S1→S2) has its **uncommitted worktree
  and session state destroyed**, then the delete-CAS correctly FAILS (ref is now S2) and the
  claim ref is left **orphaned with no held-claims backref**. Violates the "never destroy a LIVE
  holder's resources" invariant and the ADR-0016 U6 carry-forward ("cleanup must not `rm -rf` a
  live session dir"). Destructive ops must run ONLY AFTER the CAS succeeds.
- [BLOCKER] **V3 — `reclaim` force-removes the holder's worktree BEFORE the value-CAS steal
  (sh:644–661).** Same "destroy before confirm" bug: `worktree remove -f "$wt_path"` (sh:649)
  runs before the value-CAS steal (sh:658). A holder that renews in the TOCTOU window has its
  worktree/files deleted, then the CAS correctly FAILS (SHA changed) and reclaim exits 4 — so a
  now-live peer's worktree is destroyed **even though the reclaim was refused** (U6 violation).
  Prune + destroy must follow, never precede, a successful steal-CAS.
- [BLOCKER] **V4 — `lock-release` wedges on its own renewer's heartbeat → permanent deadlock
  (sh:431–438).** release reads `cur_sha=X`, confirms sid==self, then `update-ref -d <lock> X`;
  if the session's OWN renewer value-CAS-updates the lock X→Y (sid still self, fresh ts) in the
  window (sh:1105), the delete-CAS fails, release re-reads `new_sha=Y` (non-empty) and exits 5
  "ref changed during release" — but the session **still owns the lock, it is never deleted, and
  the renewer keeps it fresh forever** → peers blocked until `session-end`, a lock-wedge. Narrow
  reachability (needs a lock held across a heartbeat, which V1's slow cadence makes rare), but
  ADR 0016 Notes explicitly flags this "renewer↔release CAS-on-current-value" case as an open
  obligation. release must stop the renewer and/or re-read + retry the delete-CAS on the current
  SHA while sid==self, never exit 5 when it still owns the ref.
- [MAJOR] **V5 — `slice_to_refname` does not satisfy `git check-ref-format`; git-illegal
  slice names livelock (sh:265–281).** It percent-encodes only bytes outside
  `[A-Za-z0-9._/-]` and ignores git's ref grammar, so `foo.lock`, `a..b`, `feature/.hack`,
  trailing-`.`/`/` pass through unencoded. **Empirically confirmed** in a scratch repo: `claim
  foo.lock` on a *free* slice → `update-ref` fails "bad name" → `cmd_claim` maps it to **exit 4
  "claimed by another session"** — the slice can never be claimed/renewed/released. Fails CLOSED
  (no double-grant), so MAJOR not BLOCKER, and conventional kebab-case slice names are unaffected
  — but the misleading exit-4 mapping makes a class of legal slice names permanently unworkable.
  Encode to satisfy `git check-ref-format` (dot-sequences, `.lock`, leading/trailing `.`/`/`).
- [MAJOR] **V6 — case-fold ref collision on a case-insensitive filesystem (sh:265–285).**
  Claim refs are loose ref FILES and `slice_to_refname` preserves case, so on macOS APFS/HFS+
  (the dev host) `Auth` and `auth` map to the **same ref file**. **Empirically confirmed**:
  after `claim Auth`, only `refs/loom/claims/Auth` exists and a second `claim auth` resolves to
  it. Two case-distinct slices alias → a genuinely free slice reads as "already claimed" (a
  different session's `claim auth` → exit 4, fail-closed block). Same-session it idempotent-
  reaffirms. Fails closed in the double-grant direction (the ref stores the first owner's sid,
  so a peer never *acquires* the alias), so MAJOR — but on the primary dev platform it silently
  blocks a free slice. Encode/hash case so distinct names never case-fold to one ref path.
- [MINOR] **V-additional — leftover staleness from the substrate swap.** The header comment
  still describes "a cross-session **mkdir** lock" (sh:7) after the git-CAS rework; plus the
  review noted leftover dead test code / a redundant `cat-file` dropped under the report cap.
  Housekeeping; does not block on its own.

### Independent observations

- The four BLOCKERs cluster on **one root cause: `renew` is lock-free (correct per ADR 0016 §2)
  but the destructive/authoritative paths were not made CAS-final.** V2/V3 perform irreversible
  destruction (`worktree remove -f`, `rm -rf`) *before* the CAS that is supposed to authorize it;
  V4 mishandles a self-concurrent CAS on the lock; V1 lets the lock lease go stale under a live
  holder. The durable repair is the same discipline everywhere: **compute → CAS → (only on CAS
  success) destroy**, and give the lock its own fast heartbeat cadence.
- **Not regressed (verified):** the git-CAS core (create-only/value/delete CAS — CC1 races it),
  lock-TTL (30 s) ≠ lease-TTL (3600 s), fail-closed exit 10 outside a repo, `lock-verify`
  (0/5/10), the U2 (empty-epoch → fresh/fail-closed), U5 (`renewer-stop` identity gate), and
  PROC-1 (field-22 last-`)` parse) carry-forwards all hold. Scope/identity are clean: code-only,
  no `hooks.json` entry, holder/claim state is `refs/loom/*` blobs (no author metadata — ADR
  0003 untouched), no commits made.

### Required changes (for FAIL)

1. **V1** — give the lock heartbeat its own cadence below the lock TTL (≈ `LOOM_LOCK_TTL/3`),
   decoupled from the lease cadence; add a bats case holding a lock past `LOOM_LOCK_TTL` and
   asserting the renewer keeps it un-stealable by a peer.
2. **V2** — in `cleanup`, run the delete-CAS (`update-ref -d <refname> <sha>`) FIRST and perform
   `worktree remove -f` / `rm -rf session-<id>` only after it succeeds; add a bats case racing a
   lock-free `renew` (SHA change) into the sweep window and asserting the live worktree survives.
3. **V3** — in `reclaim`, perform the value-CAS steal FIRST and prune/`worktree remove -f` only
   after it succeeds; add a bats case where a renew in the TOCTOU window leaves the worktree
   intact on a refused reclaim.
4. **V4** — `lock-release` must not exit 5 while it still owns the ref: stop the renewer before
   release and/or re-read + retry the delete-CAS on the current SHA while sid==self; add a bats
   case simulating a renewer heartbeat between the read and the delete and asserting the lock is
   released (not wedged).
5. **V5** — encode `slice_to_refname` to satisfy `git check-ref-format` (handle `.` sequences,
   `.lock` suffix, leading/trailing `.`/`/`); add a bats case claiming a slice named `foo.lock`
   / `a..b` and asserting exit 0, not a misleading exit 4.
6. **V6** — encode or hash case so case-distinct slice names never map to one ref path; add a
   bats case (on a case-insensitive FS, or via an injected collision) asserting `Auth` and
   `auth` are independent claims.
7. **V-additional (MINOR)** — update the header comment (mkdir → git-CAS) and sweep the leftover
   dead test code / redundant `cat-file`.

## Code review — Round 3 (FAIL)

Re-review of the fix commit `692bb14` (delta `8f28b59..692bb14`; full slice
`4bb64b9..HEAD -- plugins/loom/lib/`). The round-2 FAIL's 4 BLOCKERs + 2 MAJORs +
2 MINORs were addressed, **but the fix pass introduced new regressions** clustered on
the three reworked areas (is_alive liveness matching, holderless-lock reclaim, cleanup's
new recovery override). Adjudicated the refreshed review-findings artifact
(`/code-review` ran-with-findings R1–R7; `/security-review` ran-clean) plus independent
verification.

### Gate re-verification (independently re-run)

- `shfmt -i 4 -d` on both files → CLEAN.
- `shellcheck plugins/loom/lib/loom-coord.sh` → CLEAN (SC3043 suppressed file-wide).
- `bats plugins/loom/lib/loom-coord.bats` → **37/37 pass** (30 original + 7 new
  negatives). Existing hook suites untouched.

The gate is genuinely green, **but green is not sufficient**: the 7 new negatives
prove the F1/F2/F7 fixes (exact-field claim match, lock-gated cleanup mutation,
session-end ordering) — those are sound and not regressed. But NEG-F3/F4/F6 test only
the narrow happy variant of the reworked paths and **mask** the new regressions:
NEG-F3 reclaims a *static* holderless dir with no racing peer (never exercises the
mkdir→stamp race of R4); NEG-F4 covers only the *trailing* substring `ses-foo` vs
`ses-foo-bar` (not the *leading* boundary of R2/R3); NEG-F6 fabricates a dead pid
(99999999) and so encodes the unsafe recovery override (R1) as *expected* behavior
while never testing a real live session whose stored pid is the ephemeral claim-time
`$$`. All four new BLOCKER-class defects survive a green gate.

### Round-2 carry-over (resolved — cited against the delta)

- **R2-Finding 1 (BLOCKER, RESOLVED)** — `read_claim`/`write_claim`/`remove_claim`
  now use `awk -F'\t' -v s="$slice" '$1==s'` / `$1!=s` (sh:193/203/219). Exact
  first-field match; NEG-F1/F1b prove `v2` ops do not touch `auth-v2`. Fixed.
- **R2-Finding 2 (BLOCKER, RESOLVED)** — all `CLAIMS` mutation in `cmd_cleanup` is
  now inside `if [ "$got_lock" -eq 1 ]` (sh:871); lock-less cleanup exits 3
  fail-closed (sh:920-928). NEG-F2 proves it. Fixed.
- **R2-Findings 3/6 (BLOCKER) "fixed" but the fixes are unsafe** — see R4/R5 (holderless)
  and R1/R6 (orphan-worktree override) below; the round-2 deadlock/dead-code is gone
  but replaced by new safety breaks.
- **R2-Findings 4/7/8/9** — F4 added only the *trailing* anchor (R2/R3 remain);
  F7 session-end ordering is correctly fixed (NEG-F7 proves got_lock=0 preserves
  state); F8/F9 cleanup applied (dead `SUBCOMMAND` dance removed, worktree-list hoisted).

### Findings adjudication (advisory review-findings + independent verification)

`/code-review` R1–R7: **7 CONFIRMED, 0 rejected** (all reproduced empirically against
the helper). `/security-review` ran-clean (informational — no vuln to adjudicate; its
note that the unescaped `grep -qE "${sid}"` is a *correctness* not *security* defect is
correct, and is adjudicated as R3 below).

- [BLOCKER] **R1 — cleanup's recovery override destroys LIVE worktrees + double-grants
  (sh:886-897).** The new override sweeps a claim whose session-id IS present in
  `git worktree list` when `lease-age ≥ LOOM_LEASE_TTL` AND `! kill -0 "$pid"`. But the
  stored `pid` is the **ephemeral claim-time `$$`** of the short-lived loom-coord
  process (written at sh:478/510/586); that process has long exited, so `kill -0`
  is ~always false → the guard collapses to a **pure lease-age test**. A live
  `/loom:run` session holding a slice for >`LOOM_LEASE_TTL` (default 3600s) without an
  intervening `renew` (a long dev/eval pass — plausible) has its still-active worktree
  `git worktree remove -f`'d (**uncommitted work destroyed**) and its claim row deleted
  → a peer claims the same slice → **double-grant against main**. Directly violates the
  session-id-primary rule (plan line 65, ADR 0014: "Force-clear requires session-id
  **absent**") and the cleanup contract ("**Live** sessions/claims/locks are
  untouched", plan line 225). Empirically confirmed the ephemeral-pid premise; NEG-F6
  encodes this very removal as "correct" using a fabricated dead pid.
- [BLOCKER] **R2 — worktree-list match unanchored at the LEADING boundary
  (`grep -qE "${sid}(/|$)"`, sh:127 is_alive, sh:887/906 cleanup).** Only the trailing
  side is anchored. Reproduced: dead `bar` matches live `worktree /home/u/wt-foo-bar`.
  In `is_alive` this is a false-**alive** (reclaim wedge); in cleanup it makes the R1
  override fire on the **live `foo-bar`** worktree and extract *its* path for
  `worktree remove -f` → live-worktree destruction. The round-2 F4 fix added the
  trailing anchor but left the leading boundary open. Must match the session-id as a
  full path segment at both boundaries.
- [BLOCKER] **R4 — holderless-lock reclaim double-owns the main lock (sh:379, dup
  sh:782 session-end / sh:856 cleanup).** The new `elif [ -d "$LOCK_DIR" ]` branch
  treats ANY holderless dir as reclaimable **with no age gate** — but `cmd_lock_acquire`
  is non-atomic between `mkdir "$LOCK_DIR"` (sh:348) and `stamp_holder` (sh:349), so a
  holderless dir also exists transiently during a LIVE peer's normal acquire. Trace:
  X `mkdir`s the dir; Y sees mkdir-fail + no holder + dir present → `clear_and_own`
  with empty `h_obs` (the `is_alive` guard at sh:281 is skipped, the ABA check at
  sh:309 passes vacuously since both stamps are empty) → Y `mv`s X's fresh dir away,
  `rm`s it, `mkdir`s a new one, stamps Y, returns `acquired`. X then runs its
  unconditional `stamp_holder` into Y's dir and also returns `acquired`. Both pass a
  re-assert at different instants (Y between its stamp and X's overwrite; X after) →
  **both perform a main write → lock double-ownership**. INV-2 does not save this:
  its premise (plan line 156) is that `holder` is installed only by a winning `mkdir`
  and is stable-single-valued, but here `stamp_holder` writes `holder` without
  re-verifying ownership of the dir it created. The round-2 required-change #3 said
  "treat lock dir … with absent/empty holder **past TTL** as stale" — the implementation
  dropped the TTL/age gate. NEG-F3 never races a mid-acquire peer, so it misses this.
- [BLOCKER] **R5 — cold-restart re-adoption wedges on a holderless lock
  (`cmd_lock_acquire_internal`, sh:676-710).** session-bootstrap's inline acquire was
  NOT given the holderless branch the other three call sites received: its `mkdir`
  fails, `[ -f "$HOLDER_FILE" ]` is false, there is no `elif [ -d "$LOCK_DIR" ]` → it
  backs off, exhausts retries, exits 3 "could not acquire lock". A session that crashed
  mid-acquire (leaving a holderless dir) and then cold-restarts cannot renew/re-adopt
  its claims — a **cold-restart wedge**, contradicting ADR 0014's "cold-restart
  re-adoption must not wedge" and the fix's own "holderless = always reclaimable" claim
  elsewhere. (Note: the *correct* repair is the race-safe holderless handling of R4,
  applied consistently here too — not the current unsafe branch.)
- [MAJOR] **R3 — `is_alive` interpolates `$sid` into an ERE unescaped (sh:127).** The
  F4 fix switched `grep -qF` (literal) → `grep -qE` to add the anchor, but a
  caller-supplied `--session` token with ERE metacharacters now mis-parses:
  reproduced `run[1...` → grep exit 2 (regex error) → the `if` reads as no-match →
  falls through to the (ephemeral, dead) pid probe → a genuinely **live** session is
  reported DEAD → its slice is reclaimed → double-grant; a milder `a.c` over-matches
  `wt-abc` → false-alive wedge. Default uuids are ERE-safe so the happy path holds,
  but the plan explicitly supports arbitrary caller tokens; match the id literally
  (boundary-anchored fixed-string / awk segment-exact), not as a regex.
- [MAJOR] **R6 — orphan-worktree path extraction truncates paths with spaces
  (`awk '/^worktree /{print $2}'`, sh:578 reclaim / sh:904 cleanup).** Reproduced:
  `worktree /Users/me/my repos/wt-x` → `$2` = `/Users/me/my` → `[ -d "$wt_path" ]`
  false → `worktree remove -f` never runs → the orphan leaks on disk and stays
  registered (so its session-id lingers in `git worktree list`). Strip the leading
  `worktree ` prefix instead of taking `$2`. (Narrower than round-2 Finding 6, which
  printed nothing for ALL paths; now broken only for spaced paths — macOS home dirs
  qualify.)
- [MINOR] **R7 — cleanup's inline match lacks the empty-sid guard `is_alive` has
  (sh:887).** A claims row with an empty session-id field makes `grep -qE "(/|$)"`
  match every worktree line (confirmed), mis-driving the override and the wt_path
  extraction (which could then target an arbitrary live worktree). The helper never
  writes an empty-sid row, so this needs a corrupted/hand-seeded registry to trigger;
  mirror the `is_alive` `[ -z "$sid" ] && skip` guard. Low severity, does not block on
  its own.

### Independent observations

- The four BLOCKERs share two root causes: (a) the worktree-list liveness probe matches
  the session-id as an **unanchored / regex substring** instead of an exact path
  segment (R2, R3, and feeds R1/R7); and (b) the **holderless-lock reclaim has no age
  gate and `stamp_holder` is unconditional**, so a live peer's non-atomic
  mkdir→stamp window is reclaimable (R4, R5). Fixing the *patterns* — a literal
  both-boundary segment match, and a TTL/mtime-gated + ownership-reverifying acquire —
  is the durable repair, not the per-call-site patches.
- The recovery override (R1) is **fundamentally unsound under session-id-primary** and
  should be removed/redesigned, not tuned: any signal that force-clears a session
  *present* in the worktree list contradicts ADR 0014. Reclaiming a crashed-but-dir-on-disk
  worktree needs a liveness signal independent of the ephemeral claim-time pid (e.g.
  rely on `git worktree prune` + session-id-absent, or a durable per-session liveness
  token), never lease-age + `kill -0 $$`.
- **Not regressed (verified):** the rename-capture CAS core for the *holder-present*
  stale path (mkdir is the sole ownership gate; ABA mismatch never installs ownership),
  lock-TTL (30s) ≠ lease-TTL (3600s), fail-closed exit 10 outside a repo (FC1/FC1b),
  `lock-verify` (0/5/10), and the F1/F2/F7 fixes above. The new defects are confined to
  the liveness-match and holderless-reclaim machinery added this pass.

### Required changes (for FAIL)

1. **Remove the cleanup recovery override (R1).** Do not sweep a claim whose session-id
   is present in `git worktree list`, and never gate reclaim on the ephemeral claim-time
   `$$`. Reclaim crashed-but-on-disk worktrees via a pid-independent signal
   (`prune` + session-id-absent, or a durable liveness token). Add a bats case: a LIVE
   session past `LOOM_LEASE_TTL` without `renew` (real worktree, claim pid = a
   process that has exited) is **NOT** swept and its worktree survives.
2. **Anchor the worktree-list match at BOTH boundaries as a literal (R2, R3).** Replace
   `grep -qE "${sid}(/|$)"` in `is_alive` (sh:127) and cleanup (sh:887/906) with a
   fixed-string, full-path-segment match (e.g. awk over `git worktree list --porcelain`
   `worktree ` paths, exact-segment compare). Add bats: dead `bar` must NOT match live
   `wt-foo-bar`; a session-id with ERE metacharacters is matched literally.
3. **Make holderless-lock reclaim race-safe (R4).** Gate it on age (holderless dir
   persisted past `lock-TTL`, e.g. via dir mtime) AND/OR make `stamp_holder` verify the
   acquirer still owns the dir it `mkdir`'d (fail closed otherwise) so a displaced live
   acquirer cannot also return `acquired`. Add a concurrency bats case racing a
   contender against a peer paused between `mkdir` and `stamp_holder`; assert exactly
   one holder ever acts.
4. **Give `cmd_lock_acquire_internal` the same corrected holderless/stale handling
   (R5)** so cold-restart re-adoption does not wedge on a holderless dir. Add a bats
   case: `session-bootstrap` recovers (renews claims) when a holderless lock dir is
   present.
5. **Fix orphan-worktree path extraction for paths with spaces (R6)** — strip the
   `worktree ` prefix rather than `awk '{print $2}'`. Add a spaced-path bats case.
6. **Add the empty-sid guard to cleanup's inline match (R7).**
7. Strengthen NEG-F3/F4/F6 so they actually exercise the regression surface (mid-acquire
   race; leading-boundary substring; spaced path + a real live-session-not-swept case).

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
