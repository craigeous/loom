# Evaluation: multi-session-lock-helper-plan.md

Verdict: PASS
Round: 1
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
