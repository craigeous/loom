# Review findings — multi-session-lock-helper

Automated review of the slice's code (`plugins/loom/lib/loom-coord.sh`; bats + `.docs/`
markdown out of scope). Advisory input to the blind code-evaluator. Transcribed from real
command output. Identity-neutral.

**This revision reviews the round-3 root-cause fix commit (`692bb14..21f9970`)** — the
`wt_sid_match` porcelain-parser rework, R1 recovery-override removal, and age-gated holderless
reclaim. The re-review finds the fix again introduced regressions (3rd consecutive round).

## /code-review
Status: ran-with-findings

High-effort review. 7 distinct CONFIRMED defects (several the same root cause at multiple call
sites, folded). The correctness set is dominated by a Linux-only crash in the age-gate and a
permanent slice wedge from the new membership-only liveness model.

### Finding T1
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:117 (also :406)
- description: `dir_mtime_epoch` tries BSD `stat -f %m` FIRST; on GNU/Linux `-f` means `--file-system` and `%m` is a bogus operand → stat prints a multi-line filesystem block to stdout AND exits 1, so the `|| stat -c %Y` fallback APPENDS the real mtime to that garbage. On any Linux host (`/bin/sh=dash`), `h_dir_age=$(($(now) - h_dir_mt))` fails "Illegal number" → the helper aborts (exit 2); the crash-recovery age-gate never works and the holderless lock is never reclaimed. **Local macOS bats runs (BSD stat) pass, masking it** — a portability bug the green gate cannot see.
- confidence: CONFIRMED

### Finding T2
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:934 (also :39; test :835)
- description: Removing the cleanup recovery-override makes worktree-list membership the SOLE liveness signal, so a crashed session whose `wt-<sid>` directory still exists on disk is classified **permanently alive** (`git worktree prune` won't remove a present dir). cleanup reports "skipped 1" and never sweeps the slice; `reclaim` returns exit 6 "holder still alive" forever → the slice is deadlocked until an operator manually runs `git worktree remove`. The dead-branch orphan-removal (942-946) is unreachable (see T6). (Architectural: membership ≠ liveness for a crashed session with a lingering worktree.)
- confidence: CONFIRMED

### Finding T3
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:128
- description: `wt_sid_match` passes the id via `awk -v sid="$1"`, which subjects the value to awk **escape-sequence processing**; a session-id containing a backslash (`wt-foo\bar` → `\b` becomes backspace) is silently mangled before the exact-match compare → the live worktree is not found → `is_alive` false → concurrent reclaim/claim double-grants the slice. (`-v` avoids code-injection but not escape processing.)
- confidence: CONFIRMED

### Finding T4
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:408
- description: The holderless age-gate refuses reclaim until the lock dir is older than `LOOM_LOCK_TTL` (default 30s), but the lock-acquire backoff budget (5 retries ≈ 6.2s) is far shorter. A crash-in-window holderless lock (mtime≈now) is never reclaimed within one invocation: age (~0s) < TTL (30s) → never `clear_and_own` → exhausts retries → exits 3 "lock busy" and the session stays blocked up to `LOOM_LOCK_TTL` after the crash. Regression from the prior "holderless always reclaimable" behavior.
- confidence: CONFIRMED

### Finding T5
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:925
- description: The R7 empty-sid guard preserves the row but does not increment `skipped`, so a retained (corrupted) claim is neither swept nor counted → the "swept N; skipped M live claims" summary undercounts live claims, misleading an operator.
- confidence: CONFIRMED (lower severity)

### Finding T6
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:943 (also :941, :602)
- description: The F6 orphan-worktree `git worktree remove -f` inside cleanup's dead branch is now **unreachable dead code**: `is_dead=1` requires `wt_sid_match` to return empty, but `wt_path` is computed from the same `wt_sid_match`, so it is always empty and the removal never fires. Orphaned `wt-<sid>` dirs from crashed sessions accumulate indefinitely — the capability the F6 fix was supposed to add is nullified (and it is the flip side of T2).
- confidence: CONFIRMED

### Finding T7
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:404 (also :730, :818, :896)
- description: The holderless age-gate block is copy-pasted verbatim across FOUR acquire sites (lock-acquire, session-bootstrap, session-end, cleanup) instead of a shared helper — and the copies are already drifting. Any correctness change (e.g. the T1 stat fix or the T4 window) must be applied in four places → one will be missed and the acquire paths will disagree. (The round-3 directive to "single-source the acquire logic" was not met.)
- confidence: CONFIRMED (cleanup)

## /security-review
Status: ran-clean

No concrete (>=0.8) vulnerabilities. `wt_sid_match` passes `sid` as an awk `-v` DATA variable
(no program injection) and compares by pure string equality; `dir_mtime_epoch` only stats the
fixed `$LOCK_DIR`; `git worktree remove -f`/`mv`/`rm -rf` sinks act only on git-registered
worktrees or trusted `.git/loom/` paths. No untrusted-input flow. (The T3 awk-escape and T1
stat-portability issues are correctness defects, not security vulnerabilities.)
