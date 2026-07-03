# Review findings — multi-session-lock-helper

Automated review of the slice's code (`plugins/loom/lib/loom-coord.sh` + `.bats`; `.docs/`
markdown out of scope). Advisory input. Transcribed from a real, complete `/code-review`
run. Identity-neutral.

**This revision reviews the W1-W7 fix (`9a79c27..46e85dc`).** The git-CAS core stays sound; the
fix introduced a new fail-open (X1) and a new wedge (X4), and the V2/V3 test gap is STILL open.

## /code-review
Status: ran-with-findings

### Finding X1
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:52 (renewer arithmetic :1169)
- description: The W1 `LOOM_LOCK_RENEW_INTERVAL` validator accepts **zero-padded all-digit** overrides (`08`, `09`): they pass the `*[!0-9]*` glob and the numeric tests, so validation leaves them as-is. The detached renewer then aborts at `_lease_every=$((_interval / _lock_interval))` because POSIX `$(( ))` rejects `08`/`09` as invalid octal → `renewer-start` reports success but the renewer subshell dies → the lock is never heartbeat → after TTL a peer steals it from a live holder → **double-grant**. Fix: normalize to base-10 (strip leading zeros or use `$((10#$x))`), or reject leading-zero input.
- confidence: CONFIRMED

### Finding X2
- source: /code-review
- location: plugins/loom/lib/loom-coord.bats:1506 (also :1526)
- description: **The V2 regression test is STILL ineffective.** It now plants a stale claim but with **no concurrent renewal**, so a reverted destroy-before-CAS ordering in `cmd_cleanup` reaches the same end state (ref deleted, worktree removed) and the test passes identically — empirically confirmed. The test does NOT guard the reorder. **Required mechanism:** the test must have the claim **renewed concurrently DURING cleanup's snapshot→destroy window** (claim stale in the for-each-ref snapshot, then renewed fresh before the CAS), so destroy-before-CAS force-removes a LIVE holder's worktree (test FAILS) while destroy-after-CAS refuses the CAS and leaves it intact (test PASSES). Verify the test fails on a reverted fix.
- confidence: CONFIRMED

### Finding X3
- source: /code-review
- location: plugins/loom/lib/loom-coord.bats:1539 (also :1561)
- description: **The V3 regression test is STILL ineffective** — same root cause (stale claim, no concurrent renewal); its own comment admits it only checks the path is "reachable and functional", not destroy-after-CAS. A reverted destroy-before-CAS in `cmd_reclaim` ships green. Same fix: renew the claim concurrently in reclaim's TOCTOU window so destroy-before-CAS destroys a live holder's worktree (FAIL) vs destroy-after-CAS refuses (PASS).
- confidence: CONFIRMED

### Finding X4
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:1255 (schema gate at dispatch)
- description: The new W3 schema gate (`_check_or_set_schema`) runs at dispatch **before every subcommand, including teardown/recovery paths** (`lock-release`, `release-claim`, `cleanup`, `session-end`) which previously always ran. If `refs/loom/schema` ever holds a non-`2` value or an unreadable blob (`cat-file` failure → empty `_cur_ver` != `2`), EVERY subcommand exits 10 → a session can no longer release its lock/claims or run cleanup to recover → **the shared main checkout stays wedged for all sessions with no tool-level recovery.** Fix: do NOT gate teardown/recovery paths on the schema version (they must always run); gate only acquire/claim, or make a mismatch non-fatal on teardown.
- confidence: CONFIRMED

### Finding X5
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:735
- description: `list-claims` decodes field 3 with `base64 -d`; on a **pre-W2 (v1) plaintext** claim blob the field is plaintext, so `base64 -d` emits binary garbage (non-empty), which the `[ -n "$_slice" ]` branch prints as the slice name instead of falling back to the refname. The W3 marker is created fresh as v2 without validating pre-existing claim blobs. Fix: fall back to the refname / try-decode-else-plaintext, or key decode on the per-claim schema.
- confidence: CONFIRMED

### Finding X6
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:56
- description: The W1 too-large-override clamp resets to `_default_lri` (=`TTL/3` floored to 1), which is NOT strictly `< LOOM_LOCK_TTL` when `TTL=1` (yields 1 == TTL) → heartbeat fires at the lease-expiry boundary → stealable. Degenerate-config edge; enforce strictly-less (or document/floor a minimum TTL).
- confidence: CONFIRMED (minor)

### Finding X7
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:735
- description: `base64 -d` is not portable — some BSD/POSIX `base64` accept only `-D` for decode; the error is swallowed so decode silently fails (empty → refname fallback, but on some platforms EVERY slice name silently fails to display). Use a portable decode (try `-d` then `-D`, or `openssl base64 -d`, or a POSIX fallback).
- confidence: CONFIRMED (portability)

## /security-review
Status: ran-clean

No concrete (>=0.8) vulnerabilities newly introduced. The base64-decoded slice name reaches only
`printf` (never `eval`/git-option/path); the schema marker uses only constants + hex SHAs; the clamp
arithmetic digit-validates before `$(( ))`; no new `rm`/`kill`/`mv`/`git` sink is fed by untrusted
input. (X1/X4/X5 are correctness defects, not security vulnerabilities.)
