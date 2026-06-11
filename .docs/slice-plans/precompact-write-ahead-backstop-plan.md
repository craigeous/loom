# PreCompact Write-Ahead Backstop Hook

Status: Approved
Target specs: 04-orchestrator.md (Thin-orchestrator invariant), ADR 0013 §Decision 5

## Context

ADR 0013 made the orchestrator's lossless cold-restart safe with four advisory
discipline rules (write-ahead checkpoint, restart-before-big-op, forward-progress
guard, lossless-beats-lossy) — all **prompt-level**, all already wired into spec 04
and the playbook. They tell a well-behaved orchestrator what to do but do **not**
enforce it. If the orchestrator blows its budget *before* committing a checkpoint,
the restart re-derives the same action and clears again — a starvation loop.

This slice implements ADR 0013 **§Decision 5 only**: loom's second piece of
executable code, a **PreCompact hook** that makes the write-ahead invariant
*observable*. Before a compaction it checks whether `.docs/` has **advanced** since
a marker it recorded at the previous compaction. "Advanced" = the last
`.docs/`-touching commit SHA differs from the recorded marker. If `.docs/` has not
advanced, the hook signals the no-progress condition.

The hook mirrors the existing `git-identity-guard.sh` in style, structure, and test
discipline: POSIX-sh, identity-neutral, fail-open on any ambiguity, auto-discovered
via `hooks.json`, gated by the shell gate (`shfmt -i 4 -d` → `shellcheck` → `bats`).

**Verified PreCompact facts** (given): event fires *before* a compaction; matcher is
`manual` or `auto`; stdin JSON carries `session_id`, `transcript_path`, `cwd`,
`hook_event_name`, `compaction_trigger`; decision control is **exit 0 = allow / exit
2 = block (stderr shown as feedback)**; the hook **cannot** inject compaction
instructions and **cannot** read token counts.

**Out of scope:** rules 1–4 (already wired); any change to spec/ADR text (this slice
is purely additive plugin code); the `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` lever; reading
context %.

### Resolved safety decisions (the four ADR 0013 deferred to the slice)

1. **block-vs-warn × manual-vs-auto.**
   - `manual` + no-progress → **exit 2** (block) with a remediation message on stderr.
     A manual `/compact` is operator-initiated and has no wedge risk: blocking it
     just declines that one compaction and surfaces the no-progress condition, which
     is exactly the write-ahead violation we want caught. The operator commits a real
     `.docs/` checkpoint (or confirms intent) and re-runs.
   - `auto` + no-progress → **exit 0** (allow), but **record the observation** to a
     log line under the state dir. Hard safety constraint from ADR 0013: an `auto`
     compaction fires because the window is genuinely near-full; **blocking it could
     wedge a session with no headroom and fail it**. So `auto` is *never* blocked —
     the backstop downgrades to a recorded, observable warning the next restart can
     read. Rationale: never-wedge dominates; observability is preserved without risk.
   - Either trigger, progress **advanced** → **exit 0** (allow), update marker.

2. **Marker persistence — `.git/loom/precompact-marker`.**
   A single-line file holding the last recorded `.docs/`-touching commit SHA. Lives
   **outside the tracked worktree** under the resolved git dir (`git rev-parse
   --git-dir`), so it survives compaction, is never committed, and needs no
   `.gitignore` entry. The state dir (`<git-dir>/loom/`) is `mkdir -p`'d on write.
   Co-located observation log: `.git/loom/precompact.log` (append-only, one line per
   no-progress `auto` event: ISO-8601 UTC + session_id + SHA). Rationale: a plain SHA
   file is the minimum durable state; `.git/` is the canonical "outside the worktree
   but tied to this checkout" location.

3. **False-positive guard — compare the last `.docs/`-touching commit, accept
   coarseness honestly.**
   The hook compares `git log -1 --format=%H -- .docs` (the last commit that *touched
   `.docs/`*, not bare HEAD) against the marker. This is the right granularity: loom's
   progress invariant is about durable `.docs/` advancement, so a code-only or
   unrelated commit correctly counts as no-`.docs/`-progress.
   - **First run (marker absent)** → record current SHA + **exit 0** (allow). There is
     no prior compaction to compare against, so never penalize the first one.
   - **Not a git repo / git unavailable / empty stdin / unreadable marker** →
     **exit 0** (fail-open), exactly like `git-identity-guard.sh`. The backstop never
     obstructs a legitimate compaction on a tooling failure.
   - **Accepted coarseness (stated, not hidden):** the hook cannot tell loom's
     intended 60% restart from an unrelated `/compact`, and cannot read token counts.
     A legitimate `manual` compaction with genuinely no new `.docs/` work since the
     last compaction **will be blocked once** — the remediation message explains the
     condition and the two ways forward (commit a checkpoint, or re-run if the block
     was spurious). `auto` is never blocked, so a full session is never wedged. This
     is the ADR 0013 §"Open question" coarseness, validated by the test plan rather
     than engineered away.

4. **`hooks.json` registration:** add a `PreCompact` array alongside the existing
   `PreToolUse` array (both auto-discovered). No matcher field → fires on both
   `manual` and `auto`; the script branches on `compaction_trigger` from stdin.

## Steps

1. **Create `plugins/loom/hooks/precompact-write-ahead-backstop.sh`** (new file,
   `#!/bin/sh`, `shfmt -i 4` style, header comment mirroring
   `git-identity-guard.sh`). Logic, in order:
   - Read all stdin into `INPUT` (`INPUT=$(cat)`).
   - Extract `compaction_trigger` from stdin: prefer `jq -r '.compaction_trigger //
     empty'` when `command -v jq` succeeds; else a `grep -o`/`sed` fallback on the
     `"compaction_trigger"` field (mirror the hook's existing fallback pattern). Empty
     → treat as `auto` (the never-wedge default — fail toward never blocking).
   - Resolve the state location: `GITDIR=$(git rev-parse --git-dir 2>/dev/null)`. If
     that fails (not a repo) → `exit 0` (fail-open). `STATE_DIR="$GITDIR/loom"`;
     `MARKER="$STATE_DIR/precompact-marker"`; `LOG="$STATE_DIR/precompact.log"`.
   - Compute current progress anchor: `CUR=$(git log -1 --format=%H -- .docs
     2>/dev/null)`. If empty (no `.docs/` history) → `exit 0` (fail-open; nothing to
     guard).
   - If `MARKER` is absent or unreadable → `mkdir -p "$STATE_DIR"`; write `CUR` to
     `MARKER`; `exit 0` (first-run / fail-open allow).
   - Read `PREV=$(cat "$MARKER" 2>/dev/null)`.
   - **Progress advanced** (`CUR != PREV`): write `CUR` to `MARKER`; `exit 0`.
   - **No progress** (`CUR = PREV`):
     - If trigger is `manual`: print a multi-line remediation message to **stderr**
       (no-progress detected; `.docs/` has not advanced since the last compaction;
       this is the ADR 0013 write-ahead invariant; remediation: commit a real
       `.docs/` checkpoint to `status/handoff.md` then re-compact, or re-run if this
       block was spurious) and `exit 2`. **Do not** advance the marker on a block (so
       a genuine subsequent checkpoint is still detected as progress).
     - Else (`auto` or empty/unknown): append a UTC-timestamped line to `LOG`
       (`mkdir -p` first; format `<ISO-8601-UTC>\t<session_id-or-unknown>\t<CUR>`);
       `exit 0` (never wedge). Do not advance the marker.
   - All branches are POSIX-sh; identity-neutral (no author names, no
     loom-operator-specific strings); fail-open on every tooling/parse failure.

2. **Register the hook in `plugins/loom/hooks/hooks.json`.** Add a `PreCompact` key to
   the `hooks` object, alongside the existing `PreToolUse` entry, with one entry
   (no `matcher` → both triggers) invoking
   `"${CLAUDE_PLUGIN_ROOT}/hooks/precompact-write-ahead-backstop.sh"` (mirror the
   existing `type:command` / `${CLAUDE_PLUGIN_ROOT}` quoting). Update the top-level
   `description` to note both guards, or leave the existing PreToolUse-scoped wording
   intact and rely on per-hook clarity — extend `description` to mention the
   write-ahead backstop so the file self-documents both hooks.

3. **Create the test suite
   `plugins/loom/hooks/precompact-write-ahead-backstop.bats`** (`#!/usr/bin/env
   bats`, mirroring `git-identity-guard.bats` structure: header comment, a helper that
   drives the hook with hook-shaped JSON on stdin and asserts `$status`). Each test
   runs in an **isolated temp git repo** (`BATS_TEST_TMPDIR` or `mktemp -d`) so the
   marker/log writes never touch loom's real `.git/`: `git init`, set a throwaway
   identity, create a `.docs/` file + commit to seed a real `.docs/`-touching SHA,
   then drive the hook with `cwd` set into that repo. Cases in step 4.

4. **Run the shell gate green and record the evidence** (see Verification).

## Verification

**Gate: Shell** (`gates/shell.md`), run in order on the new files; all must pass:

- format: `shfmt -i 4 -d plugins/loom/hooks/precompact-write-ahead-backstop.sh`
- lint: `shellcheck plugins/loom/hooks/precompact-write-ahead-backstop.sh`
- test: `bats plugins/loom/hooks/precompact-write-ahead-backstop.bats`

The code evaluator **re-runs** this gate (does not trust the recorded result); record
the pass count (e.g. "N/N green") in the slice progress note.

**Required `bats` cases** (new-behavior proof + regression guards):

- **T1 progress-advanced → allow.** Marker holds an old SHA; a newer `.docs/` commit
  exists. `manual` and `auto` variants both → `status -eq 0`; assert the marker file
  now holds the new SHA.
- **T2 no-progress + `manual` → block + remediate.** Marker == current `.docs/` SHA,
  trigger `manual` → `status -eq 2`; assert stderr/`$output` contains the remediation
  cue (e.g. "no-progress" / "handoff"); assert the marker is **unchanged** (not
  advanced on block).
- **T3 no-progress + `auto` → never-wedge.** Same no-progress state, trigger `auto`
  → `status -eq 0`; assert a line was appended to `precompact.log`; assert the marker
  is unchanged.
- **T4 marker-absent first-run → record + allow.** No marker file present, any
  trigger → `status -eq 0`; assert the marker file was **created** holding the current
  `.docs/` SHA.
- **T5 marker read/write round-trip.** After T4-style first run, a second invocation
  with no new `.docs/` commit and `manual` trigger blocks (read-back proves the marker
  persisted); a third invocation after a new `.docs/` commit allows and rewrites the
  marker (write proves advancement detection).
- **T6 empty/unknown trigger → treated as `auto` (never-wedge).** No-progress state,
  `compaction_trigger` absent from JSON → `status -eq 0` (fails toward allow).
- **T7 fail-open: not a git repo.** Drive the hook with `cwd` outside any repo (or
  stub so `git rev-parse --git-dir` fails) → `status -eq 0`.
- **T8 fail-open: empty stdin** → `status -eq 0`.
- **(optional) T9 jq-absent fallback** mirroring `git-identity-guard.bats`'
  `guard_no_jq`: stub PATH without jq, confirm `compaction_trigger` extraction still
  drives the correct branch for a `manual` no-progress block.

**Regression proof:** the existing `git-identity-guard.bats` suite must still pass
unchanged, and `hooks.json` must remain valid JSON (`jq . plugins/loom/hooks/hooks.json`)
with the `PreToolUse` entry intact.

## Notes

(none)
