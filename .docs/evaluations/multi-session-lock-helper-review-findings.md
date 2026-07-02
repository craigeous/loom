# Review findings — multi-session-lock-helper

Automated review of the slice's code (`plugins/loom/lib/loom-coord.sh`; bats + `.docs/`
markdown out of scope). Advisory input to the blind code-evaluator. Transcribed from real
command output. Identity-neutral.

**This revision reviews the ADR-0015 lease-freshness RE-IMPLEMENTATION (`21f9970..eedfc43`)** —
the design is now sound (ADR 0015 Approved), but the review found the hand-rolled POSIX-sh
mechanism introduced a fresh cluster of concurrency-correctness defects (4th implementation round).

## /code-review
Status: ran-with-findings

High-effort review. Multiple CONFIRMED independent double-grant paths, centered on the mkdir-CAS
lock primitive and the stamp-based lease model.

### Finding U1
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:369 (also :773, :852, :921)
- description: **Lock-reclaim CAS ABA/TOCTOU.** `clear_and_own` re-reads the holder for its ABA baseline (`h_obs`) SEPARATELY from the caller's staleness check. Interleaving: O holds a stale lock; A and B both see it stale; A runs `clear_and_own` and fully acquires (stamps a FRESH epoch); B — which passed its staleness check on O's OLD epoch — now enters `clear_and_own`, reads A's FRESH stamp as `h_obs`, its `mv`→CAP wins, `cap_stamp==h_obs` so the ABA guard passes, B destroys A's fresh lock and stamps itself → **two holders write `.docs/` concurrently.** Replicated at all four `clear_and_own` call sites.
- confidence: CONFIRMED

### Finding U2
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:179 (also :960)
- description: **Fail-OPEN on empty/corrupt epoch.** `claim_is_fresh` computes `$((_now - _epoch))`; an empty/non-numeric epoch is treated as `0` → elapsed `= now` (≫ TTL) → claim classified STALE → reclaimable. A live peer's claim row with an empty epoch field (`slice<TAB>sid<TAB>pid<TAB>`, the exact empty-field shape the T5 test documents) is swept/overwritten → the live peer's slice is double-granted. Empty-sid rows are guarded; empty-epoch rows are not. Fail-open in a fail-closed helper.
- confidence: CONFIRMED

### Finding U3
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:448 (also :852, :921)
- description: **The lock is never heartbeat.** The stale-steal path dropped the old `&& ! is_alive` guard, and the renewer refreshes the LEASE (claim) but NOT the lock stamp. A live session holding the main lock through a critical section that exceeds `LOOM_LOCK_TTL` (30s — e.g. a large `land`/merge/commit of `.docs/`) has its lock STOLEN by a peer → concurrent writers. Fix within ADR 0015: the lock-steal decision must key on the HOLDER's lease freshness (which the renewer keeps fresh), not on an un-renewed lock-stamp epoch — OR the lock must be heartbeat too.
- confidence: PLAUSIBLE

### Finding U4
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:343 (also :51)
- description: **T4 fix widened a double-grant window.** The holderless-lock age-gate was narrowed from `LOOM_LOCK_TTL` (30s) to `LOOM_HOLDERLESS_TTL` (2s default) to recover within one acquire; but this widens the non-atomic `mkdir`→`stamp_holder` window: S1 `mkdir`s the lock then is descheduled >2s (load/cgroup throttling); S2 sees a 2s-old holderless dir, reclaims + acquires; S1 resumes and stamps into the recreated dir, its INV-1 confirm reads back its own write → both report "acquired". The old 30s gate made the required stall 15× larger.
- confidence: CONFIRMED

### Finding U5
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:1099
- description: **renewer-stop kills a recycled pid.** When `renewer.starttime` is empty (because `process_starttime` returned empty at start), `renewer-stop` reads `rst=''`, takes the `[ -z "$rst" ]` branch, and issues `kill` against the recorded pid WITHOUT the start-time identity check → if the renewer died and the OS recycled its pid, an unrelated process is killed. The identity guard exists precisely to prevent this; the empty-`rst` fallback bypasses it.
- confidence: CONFIRMED

### Finding U6
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh:973
- description: **cleanup sweeps live claims + rm-rf's the session dir.** With worktree-membership liveness removed, cleanup sweeps any stale-LEASE claim and `rm -rf`s the owning `session-<id>/` dir; combined with U2/U3 a live-but-momentarily-stale holder can have its per-session state destroyed. (Related to the fail-open/lease-window issues above.)
- confidence: CONFIRMED

### Secondary (cleanup / robustness)
- source: /code-review
- location: plugins/loom/lib/loom-coord.sh (renewer lifecycle + acquire dup)
- description: Unreliable start-time persistence; non-atomic `session.pid` write; awk mis-parse of `/proc/<pid>/stat` field 22 (start-time can be wrong when the comm field contains spaces/parens); copy-pasted acquire loop with an already-diverged wasted-backoff bug.
- confidence: CONFIRMED (lower severity)

## /security-review
Status: ran-clean

No concrete (>=0.8) vulnerabilities. The detached renewer spawns `sh "$_coord" <subcmd>` with every
value as a separate double-quoted argument (no `eval`/injection); `process_starttime` and the portable
`stat` are quoted and read only trusted pids / the fixed lock dir; the `ENVIRON`-passed session-id is
equality-compared only; all `mv`/`rm -rf`/`kill`/`git` sinks are fed by trusted CLI args / minted UUIDs /
git output / tool-written `.git/loom/` state. No untrusted-input flow. (U1-U6 are correctness defects,
not security vulnerabilities.)
