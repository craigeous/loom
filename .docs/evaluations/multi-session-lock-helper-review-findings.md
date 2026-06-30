# Review findings — multi-session-lock-helper

Automated review of the slice's code diff (`plugins/loom/lib/loom-coord.sh`; the
bats test and `.docs/` markdown were out of scope). Advisory input to the blind
code-evaluator — the evaluator confirms/rejects each finding against the diff,
plan, and specs and owns the verdict (`severity.md` / `code-eval-rubric.md`).
Transcribed from the actual command output. Identity-neutral.

## /code-review
Status: ran-with-findings

High-effort review (finder-per-angle + independent per-location verify pass). 20
verified findings collapsing to 9 distinct defects. Each carries the command's own
verdict label (CONFIRMED / PLAUSIBLE) as its confidence signal.

### Finding 1
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:200 (also :190)
- description: Claim-registry lookups/edits use **unanchored** `grep -F "${slice}\t"`, so a query for one slice matches any slice whose name it is a tab-suffix of, silently editing the wrong row. E.g. claiming `v2` while `auth-v2` is claimed: `grep -vF "v2\t"` drops `auth-v2`'s line, so a third session sees `auth-v2` as unclaimed and claims it → two sessions develop `auth-v2` against main (the exact double-grant the helper prevents).
- confidence: CONFIRMED

### Finding 2
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:849 (also :824)
- description: `cleanup` reads, filters, and `mv`-overwrites the CLAIMS registry **even when it failed to acquire the lock** (`got_lock=0`), mutating shared state without mutual exclusion. A concurrent `claim X` that appends X after cleanup snapshotted CLAIMS is clobbered by cleanup's `mv` → X's claim lost → a third session re-claims X → double-grant against main.
- confidence: CONFIRMED

### Finding 3
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:357 (also :803)
- description: Stale-lock reclaim is gated on `[ -f "$HOLDER_FILE" ]`, so a lock dir created by a crash **between `mkdir LOCK_DIR` and `stamp_holder`** (no holder file) is never recognized as stale and never reclaimed. Every subsequent `lock-acquire` finds the dir, skips the stale branch (holder absent), exhausts retries, exits 3 "busy" forever → all sessions deadlock on main until manual deletion.
- confidence: CONFIRMED

### Finding 4
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:125
- description: `is_alive`'s primary liveness probe is `git worktree list --porcelain | grep -qF "$sid"`, an **unanchored substring match**, so a dead session is reported alive whenever its id is a substring of any live worktree path/branch — its expired lock is never reclaimed and its claims are treated as live, wedging coordination.
- confidence: CONFIRMED

### Finding 5
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:365
- description: Holder liveness relies **solely** on the session-id appearing in `git worktree list` (the stored pid is the long-exited per-invocation CLI pid). A genuinely-active holder working the main checkout for >`LOOM_LOCK_TTL` without a sid-bearing worktree is judged dead and its lock reclaimed → two sessions hold the main lock and write main concurrently. (Ties to the W precondition that worktree paths embed the session-id.)
- confidence: PLAUSIBLE

### Finding 6
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:565 (also :837)
- description: The awk extracting a dead peer's orphan worktree path resets `p`/`b` on every line via the catch-all `/^/` block before both can be set, so it **never prints a path** — the `git worktree remove -f` orphan-cleanup branch is dead code. A crashed peer's leftover worktree dir (which `git worktree prune` won't remove) accumulates forever. Test RCL1 avoids creating a worktree, so it never exercises this path.
- confidence: CONFIRMED

### Finding 7
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:776 (also :750)
- description: `cmd_session_end` unconditionally `rm -rf`s the session dir (incl. held-claims) **even when it could not acquire the lock** (`got_lock=0`) and therefore never released the session's claims from the registry. The claims remain orphaned in CLAIMS with no held-claims record, blocking peers until a later cleanup sweep. (session-end's mkdir loop has no stale-lock handling.)
- confidence: CONFIRMED

### Finding 8
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:663 (also :700)
- description: The `ORIG_SUBCOMMAND` save / `SUBCOMMAND="lock-acquire"` set / restore dance around the inline function is **dead code** — the inner function never reads `SUBCOMMAND`. Pure noise; should be deleted.
- confidence: CONFIRMED (non-correctness cleanup)

### Finding 9
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:830 (also :836)
- description: `cmd_cleanup` re-runs `git worktree list --porcelain` per dead claim after `is_alive` already ran it, and `is_alive` re-runs it on every call — roughly 2× per claim over a constant-for-the-sweep list. Efficiency cleanup (hoist the list once).
- confidence: CONFIRMED (non-correctness cleanup)

## /security-review
Status: ran-clean

Threat-modeled review of `loom-coord.sh` found no concrete, exploitable (>=0.8
confidence) vulnerabilities. Every dangerous sink (`kill -0 "$pid"`,
`git -C "$REPO_ROOT" worktree remove -f "$wt_path"`, `grep -F`, `mv`/`rm -rf`,
`sleep "$frac"`) is double-quoted and fed only by trusted orchestrator-supplied
CLI args/env vars (`--session` / `LOOM_SESSION_ID`, the slice positional) or by
state the tool itself wrote under `.git/loom/`; no untrusted-input flow (e.g. a PR
branch name) reaches a path-construction or command sink within this file. Shell
command-injection is discounted absent an untrusted source (review precedent). No
secrets are read, written, or logged.
