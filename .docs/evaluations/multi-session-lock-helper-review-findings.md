# Review findings — multi-session-lock-helper

Automated review of the slice's code (`plugins/loom/lib/loom-coord.sh`; bats + `.docs/`
markdown out of scope). Advisory input to the blind code-evaluator. Transcribed from real
command output. Identity-neutral.

**This revision reviews the git-CAS RE-IMPLEMENTATION (`eedfc43..9fa9b63`, 3 passes).** The
CAS primitive itself is now correct (git owns atomicity — the prior mkdir-CAS ABA/race class is
eliminated, confirmed by the review). The remaining defects are in peripheral logic (renewer
cadence, destroy-before-CAS ordering, the renewer↔release race, ref-name encoding, case-fold).

## /code-review
Status: ran-with-findings

High-effort review; ~10 distinct defects (correctness-first; lower-value cleanup items dropped
under the cap). CONFIRMED set below.

### Finding V1
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:43
- description: Default `LOOM_RENEW_INTERVAL` (1200s) is **40× the lock TTL** (`LOOM_LOCK_TTL` 30s), so the renewer's lock heartbeat (the U3 fix) cannot keep a held lock fresh: a session holding `refs/loom/lock` across an op >30s has its lock value-CAS-stolen by a peer at the 30s mark → both believe they hold it → double-grant. The renew cadence must be well below the SHORTEST TTL it must refresh (i.e. < lock TTL ⇒ ~TTL/3).
- confidence: CONFIRMED

### Finding V2
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:1006 (also :1011)
- description: `cleanup` runs `git worktree remove -f` on the holder's worktree and `rm -rf` its `.git/loom/session-<id>` dir **BEFORE** the guarding `update-ref -d <ref> <old-SHA>`, and `renew` is lock-free. A live session whose claim was momentarily stale in cleanup's `for-each-ref` snapshot renews (SHA S1→S2) mid-sweep; cleanup destroys its worktree (uncommitted work) + session dir, then the delete-CAS fails (ref is now S2) → **a LIVE session's resources are destroyed and its claim ref is left orphaned** (no held-claims backref). Destructive ops must run ONLY AFTER the CAS succeeds.
- confidence: CONFIRMED

### Finding V3
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:649
- description: `reclaim` force-removes the stale holder's worktree **before** the guarding value-CAS steal. A holder that renews in the TOCTOU window (renew is lock-free) has its worktree/files deleted, and then the value-CAS correctly FAILS (SHA changed) and reclaim exits — so a now-live peer's worktree is destroyed even though the reclaim was refused (U6 violation). Same "destroy before confirm" bug as V2.
- confidence: CONFIRMED

### Finding V4
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:435 (also :431)
- description: `lock-release` reads `cur_sha=X`, confirms sid==self, then the session's OWN background renewer value-CAS-updates the lock blob X→Y (still sid==self, fresh ts); the `update-ref -d <lock> X` then fails, the code re-reads `new_sha=Y` (non-empty) and exits 5 "ref changed during release" — but the session still owns the lock, it is never deleted, and the renewer keeps it fresh so it never goes stale → **permanent deadlock** (peers blocked; self can't re-acquire until session-end). This is the ADR-0016 "renewer↔release CAS-on-current-value" note: release must stop the renewer and/or re-read + retry the delete-CAS on the current SHA while sid==self.
- confidence: CONFIRMED

### Finding V5
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:265 (also :269)
- description: `slice_to_refname` percent-encodes only bytes outside `[A-Za-z0-9._/-]` and does NOT enforce git's ref grammar, so legal slice names produce refnames git refuses: `foo.lock`, `a..b`, `feature/.hack`, or names ending in `/` or `.` pass through unencoded. `git update-ref` then fails "bad name", and `cmd_claim` maps that to exit 4 "claimed by another session" → the slice can NEVER be claimed/renewed/released/reclaimed → a **permanent live-lock on any git-illegal-ref-token slice name**, even with no peer holding it. Encode to satisfy `git check-ref-format` (e.g. encode `.`-sequences, `.lock`, leading/trailing `.`/`/`).
- confidence: CONFIRMED

### Finding V6
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:285
- description: Claim refs are loose ref FILES, so on a **case-insensitive filesystem** (macOS default APFS/HFS+ — the dev host) two distinct slice names differing only in case (`Auth` vs `auth`) map to the same ref file → one slice's claim silently aliases the other's (false "already claimed" or cross-grant). Encode case (or hash) so distinct names never case-fold to one ref path.
- confidence: CONFIRMED

### Additional (lower-severity / cleanup)
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh (various)
- description: The review noted ~4 further lower-value items (leftover dead test code from the deleted mkdir/TSV machinery, a redundant `cat-file`, a stale header comment) dropped under the report cap — worth a cleanup sweep in the fix.
- confidence: CONFIRMED (minor)

## /security-review
Status: ran-clean

No concrete (>=0.8) vulnerabilities. The git argument-injection check is safe (every value in a
`git` option/ref position is a fixed literal, a 40-hex SHA, or a `refs/loom/`-prefixed ref — none
can lead with `-`); holder/claim blobs are read only via `cat-file | awk` string comparison, never
`eval`'d; `rm -rf`/`kill`/`mv` sinks are fed by trusted session-id / tool-written state; the
`/proc` field-22 parse is string-compared only. The V5 ref-grammar / V6 case-fold issues are
correctness defects that fail closed, not security vulnerabilities.
