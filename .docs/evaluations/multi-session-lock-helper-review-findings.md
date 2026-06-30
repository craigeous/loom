# Review findings — multi-session-lock-helper

Automated review of the slice's code (`plugins/loom/lib/loom-coord.sh`; bats + `.docs/`
markdown out of scope). Advisory input to the blind code-evaluator — it confirms/rejects
each finding and owns the verdict (`severity.md` / `code-eval-rubric.md`). Transcribed from
real command output. Identity-neutral.

**This revision reviews the FIX commit (`8f28b59..692bb14`)** that resolved the prior round's
8 confirmed defects. The re-review finds the fixes introduced new regressions.

## /code-review
Status: ran-with-findings

High-effort review (finder-per-angle + independent per-location verify). 17 verified findings
→ 7 distinct defects, clustered on the three reworked areas (is_alive liveness, holderless-lock
reclaim, cleanup recovery override). Each carries the command's verdict label as its confidence
signal. Several were demonstrated empirically.

### Finding R1
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:891
- description: cleanup's new recovery-override removes the old invariant "a session present in the worktree list is never swept". It force-removes the worktree + sweeps the claim when lease-age > `LOOM_LEASE_TTL` AND the stored pid is dead — but the stored pid is the **ephemeral `$$` of the claim-time loom-coord process** (lines 478/510/586), so `! kill -0 "$pid"` is essentially always true → the guard collapses to a pure lease-age test. A live `/loom:run` session holding slice-X for >`LOOM_LEASE_TTL` (default 3600s) without a `renew` (e.g. a long developer/eval pass) has its **still-active worktree `git worktree remove -f`'d (uncommitted work destroyed)** and its claim row deleted → another session claims the same slice → double-grant/corruption. (Regression: the old `is_alive` kept any session in the worktree list regardless of lease age.)
- confidence: CONFIRMED

### Finding R2
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:887 (same root cause :127)
- description: cleanup's reclaimability `grep -qE "${sid}(/|$)"` is **unanchored at the leading boundary**, so a dead claim whose session-id is a trailing substring of a LIVE session's worktree path force-removes the live worktree. Demonstrated: dead `bar` vs live `.../wt-foo-bar` — `printf 'worktree /home/u/wt-foo-bar' | grep -qE 'bar(/|$)'` matches → the override fires on the live `foo-bar` worktree → `git worktree remove -f` destroys its uncommitted work.
- confidence: CONFIRMED

### Finding R3
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:127
- description: `is_alive` switched `grep -qF` (literal) → `grep -qE` (regex), interpolating the session-id into an ERE **unescaped**. A session-id with regex metacharacters (e.g. `run[1]`) makes `grep -qE` exit 2 (regex error, confirmed "mismatched [ ]"); the `if` reads as no-match, falls through to the (stale/dead) pid probe → a genuinely **live** cold-restarted session is reported DEAD → another session reclaims its slice → double-grant. A milder id like `a.c` over-matches an unrelated live worktree `wt-abc` → falsely reports a dead session alive, permanently blocking reclaim.
- confidence: CONFIRMED

### Finding R4
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:379 (duplicated :856 cleanup, :782 session-end)
- description: The new holderless-lock reclaim path cannot distinguish a crash from a peer **mid-acquire**, racing the non-atomic `mkdir LOCK_DIR` → `stamp_holder` window. Session X `mkdir`s LOCK_DIR then is preempted before `stamp_holder`; session Y sees mkdir fail + no holder file + `-d LOCK_DIR`, enters the new `elif` → `clear_and_own` with empty `h_obs` (ABA check passes, nothing to compare) → Y seizes + stamps itself; X resumes and stamps too → **both believe they hold the exclusive main lock** → concurrent writes to shared main. (The old code returned 1 on an empty holder, so this race didn't exist.)
- confidence: CONFIRMED

### Finding R5
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:691 (also :703, :761)
- description: `session-bootstrap`'s inline `cmd_lock_acquire_internal` was **not** given the holderless-lock-dir reclaim branch that `lock-acquire`/`cleanup`/`session-end` received, so a holderless lock dir wedges cold-restart re-adoption: the inline loop's `mkdir` fails, the `[ -f HOLDER_FILE ]` branch is skipped, there is no `elif [ -d LOCK_DIR ]` branch → backs off, exhausts retries, exits 3 "could not acquire lock". The restarting session cannot renew/re-adopt its claims — contradicting the fix's "holderless dirs always reclaimable" elsewhere. (Inconsistent fix across call sites.)
- confidence: CONFIRMED

### Finding R6
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:578 (also :905 cleanup)
- description: The rewritten orphan-worktree awk `/^worktree /{print $2}` splits on whitespace and keeps only `$2`, **truncating any worktree path containing a space**. A dead session's worktree at `/Users/me/my repos/wt-ses-x` yields only `/Users/me/my` → `[ -d "$wt_path" ]` false → `git worktree remove -f` never runs → orphan worktree leaks on disk + stays registered.
- confidence: CONFIRMED

### Finding R7
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:887
- description: cleanup's inline reclaimability `grep` lacks the empty-sid guard that `is_alive` has, so a claims row with an **empty session-id field** matches every worktree line (or none safely), mis-driving the recovery override. Add the same empty-sid guard used by `is_alive`.
- confidence: CONFIRMED (lower severity)

## /security-review
Status: ran-clean

Re-review of the fixed helper found no concrete (>=0.8) vulnerabilities. The fixes added no new
sink fed by a nameable untrusted source: the `is_alive` ERE `$sid`, the orphan-worktree `$wt_path`
(from `git worktree list`, acted on only via `git worktree remove -f` of a git-registered worktree),
and the `clear_and_own`/cleanup `mv`/`rm -rf` path components are all trusted-caller/git-authoritative
and stay within `.git/loom/`. Every command expansion is double-quoted; no untrusted-input flow.
(Note: the `grep -qE "${sid}"` unescaped-regex issue is a real *correctness* defect — see /code-review
R3 — but not a security vulnerability under the threat model; regex injection is excluded by precedent
and `$sid` is trusted.)
