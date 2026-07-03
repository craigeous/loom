# Review findings — multi-session-lock-helper

Automated review of the slice's code (`plugins/loom/lib/loom-coord.sh` + `.bats`; `.docs/`
markdown out of scope). Advisory input to the blind code-evaluator. Transcribed from real
command output (valid, complete run — an earlier run was voided by a spend-limit finder crash).
Identity-neutral.

**This revision reviews the round-4 fix (`9fa9b63..9a79c27`)** of the git-CAS helper. The CAS
core remains sound; the round-4 fix closed the prior V1-V6 but introduced new fail-open
regressions and shipped two ineffective regression tests.

## /code-review
Status: ran-with-findings

High-effort review; 14 findings → 7 distinct defects.

### Finding W1
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:48 (also :1124)
- description: `LOOM_LOCK_RENEW_INTERVAL` **env override is not validated** against `LOOM_LOCK_TTL` nor floored `>=1` (only the derived default is floored at :47). An operator setting it `> TTL` → the renewer heartbeats the lock **slower than it expires** → a peer steals the (still-"active") lock → double-grant; setting it `=0` → **division-by-zero** at :1124, the renewer subshell exits immediately while `renewer-start` still reports success → lock never heartbeat → stale → stolen. Fail-open in a fail-closed coordinator. (The V1 fix floored the default but not the override.)
- confidence: CONFIRMED

### Finding W2
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:285 (also :283)
- description: Storing the **raw slice name as tab/newline-delimited blob field 3** (the V5/V6 change) removes the newline-safety the percent-encoded refname used to provide. A slice name containing a newline makes `_make_claim_blob_for` write a 2-line blob `sid<TAB>ts<TAB>part1\npart2`; every later owner check `decode_claim_field <sha> 1` runs `awk -F'\t' '{print $1}'` over BOTH lines → returns `sid\npart2` != SESSION_ID → owner check fails (exit 5) though the session owns the claim → the renewer can never heartbeat it → lease goes stale → cleanup sweeps it while the session still holds the slice → a peer re-claims → **two sessions edit the same slice**. Fail-open. (Store the slice name newline/tab-safe — e.g. base64 — or keep it out of the parsed blob.)
- confidence: CONFIRMED

### Finding W3
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:272
- description: V5/V6 changed the claim-ref naming from percent-encoding to a `git hash-object` SHA — an **incompatible naming change with no migration/version marker**. A claim created under the old scheme (or by a concurrently-running old-version invocation during an upgrade) is keyed differently and is invisible to the new code → the same slice can be double-claimed. (Low impact for an unreleased helper with no old refs in existence, but a concurrent old+new version would collide; add a ref-schema version marker.)
- confidence: PLAUSIBLE

### Finding W4
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:689 (also :688)
- description: `list-claims` recovers the slice name via `awk -F'\t' '{print $3}'`, which **truncates at the first embedded tab** (and a newline splits the blob into a second awk record), so a slice name containing a tab/newline is displayed corrupted → an operator cannot map the row back to the real slice. Same raw-slice-name flaw as W2; defeats the V5/V6 purpose of storing the original name.
- confidence: CONFIRMED

### Finding W5
- source: /code-review
- location: plugins/loom/lib/loom-coord.bats:1500
- description: **The V2 regression test is ineffective** — it renews the planted claim to `ts=now` before running cleanup, so cleanup skips it at the freshness check (`loom-coord.sh:1016`) and **never reaches the V2 delete-CAS-first branch it purports to guard**. Reverting the V2 fix to destroy-before-CAS leaves this test GREEN → a future regression that destroys a live holder's worktree ships undetected. The test must exercise the **stale-claim** path where the reorder matters.
- confidence: CONFIRMED

### Finding W6
- source: /code-review
- location: plugins/loom/lib/loom-coord.bats:1538
- description: **The V3 regression test is ineffective** — same root cause: it renews the claim to `ts=now`, so reclaim exits 6 at the freshness guard (`loom-coord.sh:644`) and never reaches the V3 CAS-steal-first path (exit 4) it claims to verify. A reclaim-TOCTOU worktree-destruction regression is not caught.
- confidence: CONFIRMED

### Finding W7
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:687
- description: `list-claims` re-reads each claim blob **three times** (three `git cat-file` spawns per ref) to extract three tab fields — read the blob once and split. Efficiency cleanup.
- confidence: CONFIRMED (minor)

## /security-review
Status: ran-clean

No concrete (>=0.8) vulnerabilities newly introduced. The blob-stored slice name reaches no
dangerous sink (stdin-hashed; `printf %s`; fixed-string `grep -qxF`); the hashing keeps the raw
name off every `git` option position; the lock-release retry loop provably cannot delete another
session's lock (re-reads, exits when `sid != self`); `rm -rf`/`kill`/`mv` sinks are fed by trusted
session-id / tool-written state. (W2/W4 are correctness defects, not security vulnerabilities.)
