# Per-Session PreCompact Write-Ahead Backstop (`precompact-per-session`)

Status: Landed
Target specs: 04-orchestrator.md, 08-client-adapters.md
Target size: <= 240 LOC net change (keep this plan document <= 250 lines)

## Context

`plugins/loom/hooks/precompact-write-ahead-backstop.sh` enforces the ADR 0013
write-ahead invariant before context compaction and already stores per-session
state under `<git-dir>/loom/precompact/<session-id>/{marker,log}` behind the
spec 08 `hook-wire-v1` adapter contract. However, four gaps remain against M3
slice `precompact-per-session` in `.docs/repository-improvement-plan.md`:

1. **Coordinated session checkpoints are ignored:** High-frequency orchestrator
   checkpoints written by `loom-coord checkpoint-write --session <sid>` live at
   `<git-common-dir>/loom/session-<sid>/checkpoint` — per
   `plugins/loom/bin/loom-coord` (`STATE_DIR="$GITDIR/loom"`, `_with_session_dir`
   and `_session_checkpoint_write_op` writing `$STATE_DIR/session-<id>/checkpoint`,
   with `<id>` bound from `--session <sid>` or `LOOM_SESSION_ID`) and spec 04
   `## Thin-orchestrator invariant`. When the orchestrator starts `loom-coord`
   with `--session <client-session-id>` (or sets `LOOM_SESSION_ID` to match the
   client hook's `session_id`), the hook's `$SESSION` equals `loom-coord`'s
   `<sid>` and its checkpoint file is `<git-common-dir>/loom/session-$SESSION/checkpoint`.
   The hook currently computes its progress anchor (`CUR`) solely from
   `git log -1 --format=%H -- .docs`. As a result, `loom-coord checkpoint-write`
   does not advance the session's compaction marker, and in a multi-session
   repository one session's `.docs/` commit advances `CUR` for another
   coordinated session whose own per-session checkpoint has not moved.
2. **Worktree git-dir resolution:** The hook resolves `git rev-parse --git-dir`
   rather than `git rev-parse --git-common-dir`, which splits `.git/loom/` paths
   when invoked from a session worktree.
3. **Session ID grammar mismatch with `loom-coord`:** The hook accepts leading
   `-`/`_` and rejects `.`, whereas `loom-coord`'s `_valid_identifier` grammar is
   `^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$` with no `..` substring, and JSON type
   checking does not yet verify that `.trigger` and `.session_id` are JSON strings
   before string extraction. (Under spec 08 `hook-wire-v1` and existing test
   `T7a`, missing or invalid `session_id` fails closed with `"Loom hook input
   invalid for pre-compact."` rather than sharing a fallback `default` marker.)
4. **Remediation & log hardening:** Coordinated sessions need a block message
   that instructs the caller to write an advanced checkpoint via
   `loom-coord checkpoint-write --session <sid>` (while uncoordinated sessions
   preserve the byte-exact `hook-wire-v1` fixture message `"commit a .docs/
   checkpoint, then retry"`), and `_loom_append_bounded_log` /
   `_loom_atomic_write` need `mktemp`-backed atomic temp files,
   `LOOM_PRECOMPACT_LOG_CAP` integer validation (invalid or leading-zero values
   fall back to `200`), control-character sanitization, and
   `<timestamp>\t<session>\t<anchor>` log records.

## Out of Scope & Threat-Model Boundary

- **Out of scope:** Modifying `plugins/loom/bin/loom-coord`, changing the frozen
  `plugins/loom/hooks/fixtures/hook-wire-v1/` fixture files, changing
  `plugins/loom/hooks/hooks.json`, or modifying `.docs/spec/` / `.docs/ADR/`.
- **Session-binding scope:** Multi-session checkpoint isolation applies to
  coordinated sessions that bind their `loom-coord` session to the client hook
  `session_id` (via `--session <client-session-id>` or `LOOM_SESSION_ID`
  matching `session_id`); uncoordinated sessions (without a
  `<git-common-dir>/loom/session-$SESSION` directory) continue to share the
  repository-wide `.docs` commit anchor.
- **Threat-model boundary (`.docs/spec/00-overview.md` `## Non-goals`):** Same-user
  local filesystem trust boundary under `.git/loom/`. This slice defends against
  cross-session marker/checkpoint bleed, path traversal or option injection via
  `session_id`, control-character log injection, and partial/concurrent marker or
  log writes. It does not claim OS-level hostile-code containment against a local
  process directly mutating `.git/loom/` files.

## Steps

1. **Harden session ID validation, JSON type checks, and atomic file helpers in
   `plugins/loom/hooks/precompact-write-ahead-backstop.sh`:**
   - Add `_loom_valid_session_id <sid>` enforcing length `1..128`, pattern
     `^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$`, and rejection of any `*..*` substring:
     ```bash
     _loom_valid_session_id() {
         local sid="$1"
         [ -n "$sid" ] && [ "${#sid}" -le 128 ] || return 1
         case "$sid" in
         [!A-Za-z0-9]* | *[!A-Za-z0-9._-]* | *..*) return 1 ;;
         esac
         return 0
     }
     ```
   - Before `jq -r` extraction, require both `.trigger` and `.session_id` to have
     JSON type `"string"` via `jq -e '(.trigger | type == "string") and (.session_id | type == "string")'`,
     failing closed through `_loom_hook_block "$CLIENT" "$INVALID_REASON"` on
     missing, non-string, or invalid values.
   - In `_loom_atomic_write` and `_loom_append_bounded_log`, create temp files
     in the target directory via `mktemp "$dir/.tmp.XXXXXX"` (falling back to
     `"$dir/.tmp.$$.$RANDOM"` if `mktemp` is unavailable in a minimal `PATH`),
     remove `"$tmp"` on write/rename failure, validate `LOOM_PRECOMPACT_LOG_CAP`
     as a positive decimal integer matching `^[1-9][0-9]*$` (invalid or
     leading-zero values fall back to `200`), and strip control characters
     (`LC_ALL=C tr -d '\000-\010\013-\037\177'`) from log lines before writing.

2. **Resolve `--git-common-dir` and validate per-session coordinated checkpoints
   in `plugins/loom/hooks/precompact-write-ahead-backstop.sh`:**
   - Resolve `GITDIR` via `git -C "$REPO_ROOT" rev-parse --git-common-dir 2>/dev/null`
     (falling back to `--git-dir`), relativized against `$REPO_ROOT` when not
     absolute, so linked worktrees share `<common-git-dir>/loom/`.
   - Bind to `plugins/loom/bin/loom-coord`'s per-session state layout
     (`STATE_DIR="$GITDIR/loom"`, `_with_session_dir` /
     `_session_checkpoint_write_op` writing `<git-common-dir>/loom/session-<sid>/checkpoint`
     when the orchestrator starts `loom-coord` with `--session <client-session-id>`
     or `LOOM_SESSION_ID` matching the hook's `session_id`). Compute the
     per-session progress anchor `CUR` and `COORDINATED` flag from
     `<git-common-dir>/loom/session-$SESSION/checkpoint`:
     ```bash
     SESSION_COORD_DIR="$GITDIR/loom/session-$SESSION"
     SESSION_CHECKPOINT="$SESSION_COORD_DIR/checkpoint"
     COORDINATED=0
     if [ -f "$SESSION_CHECKPOINT" ]; then
         COORDINATED=1
         CHK_SHA=$(git -C "$REPO_ROOT" hash-object -- "$SESSION_CHECKPOINT" 2>/dev/null) || CHK_SHA=""
         if [ -z "$CHK_SHA" ]; then
             _loom_hook_allow
         fi
         CUR="checkpoint:$CHK_SHA"
     elif [ -d "$SESSION_COORD_DIR" ]; then
         COORDINATED=1
         CUR="checkpoint:none"
     else
         CUR=$(git -C "$REPO_ROOT" log -1 --format=%H -- .docs 2>/dev/null)
         if [ -z "$CUR" ]; then
             _loom_hook_allow
         fi
     fi
     ```
   - Preserve explicit first-run behavior: when `$MARKER` is absent or unreadable,
     atomically write `$CUR` to `$MARKER` and allow (`exit 0`).
   - When `$CUR != $PREV`, atomically update `$MARKER` to `$CUR` and allow.
   - When `$CUR == $PREV`:
     - On `TRIGGER="manual"`: if `COORDINATED=1`, block with
       `"loom write-ahead backstop: session checkpoint has not advanced before manual compaction (ADR 0013); write an advanced checkpoint via loom-coord checkpoint-write --session ${SESSION}, then retry."`;
       if `COORDINATED=0`, block with the existing `hook-wire-v1` reason
       `"loom write-ahead backstop: .docs/ has not advanced before manual compaction (ADR 0013); commit a .docs/ checkpoint, then retry."`.
     - On `TRIGGER="auto"`: append `$(printf '%s\t%s\t%s' "$TIMESTAMP" "$SESSION" "$CUR")`
       to `$LOG` via `_loom_append_bounded_log` and allow (`exit 0`).

3. **Extend `plugins/loom/hooks/precompact-write-ahead-backstop.bats` with
   multi-session, coordinated-checkpoint, concurrency, and grammar tests:**
   - Keep all existing tests (`T1`–`T13`, `RED-GREEN`, and the 6 `hook-wire-v1`
     fixture tests) passing unchanged.
   - Add `T7f`–`T7i`: session IDs with single dots (`sess.1.a`) succeed; `..`
     (`sess..1`), leading non-alphanumeric (`-bad`, `.hidden`), and non-string
     JSON `session_id` (`123`) fail closed (`status 2`).
   - Add `T12b`: auto no-progress log records `<timestamp>\t<session>\t<anchor>`,
     strips control characters, and falls back to `200` on invalid or
     leading-zero `LOOM_PRECOMPACT_LOG_CAP` (e.g. `abc`, `08`, `0`).
   - Add `T14`: coordinated session round-trip invoking the real
     `plugins/loom/bin/loom-coord session-start --session <sid>` and
     `plugins/loom/bin/loom-coord checkpoint-write --session <sid>` bound to the
     hook's `session_id` `<sid>` — first-run allows, repeated manual compaction
     (or rewriting identical checkpoint bytes) blocks with the `"write an
     advanced checkpoint via loom-coord checkpoint-write --session <sid>"`
     remediation (both Claude exit-2 and Codex JSON wire), and a subsequent
     `loom-coord checkpoint-write --session <sid>` with advanced checkpoint
     content unblocks compaction.
   - Add `T15`: two coordinated sessions (`sA`, `sB`) where `sA` advances via
     `loom-coord checkpoint-write --session sA` AND commits to `.docs/`; `sA`
     compacts (`status 0`) while `sB` remains blocked (`status 2`).
   - Add `T16`: coordinated session directory present without `checkpoint` file
     yet records `checkpoint:none` on first run, blocks on second manual run, and
     unblocks after `loom-coord checkpoint-write --session <sid>`.
   - Add `T17`: concurrent compactions across two sessions (`s-adv` advancing,
     `s-stale` unadvanced) run in parallel without marker corruption or leftover
     `.tmp.*` files.
   - Add `T18`: linked `git worktree add` invocation resolves `--git-common-dir`
     and shares the common `.git/loom/` state directory.

## Verification

- **Fast targeted iteration command:**
  ```bash
  TMPDIR=/private/tmp LOOM_TEST_BASH="$(command -v bash)" LOOM_EXPECTED_BASH_VERSION="^[345]\\." \
    bats plugins/loom/hooks/precompact-write-ahead-backstop.bats
  ```
- **Static checks on touched files:**
  ```bash
  shfmt -i 4 -d plugins/loom/hooks/precompact-write-ahead-backstop.sh \
    plugins/loom/hooks/precompact-write-ahead-backstop.bats
  shellcheck -s bash plugins/loom/hooks/precompact-write-ahead-backstop.sh \
    plugins/loom/hooks/precompact-write-ahead-backstop.bats
  ```
- **Full repository gate:**
  ```bash
  TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check
  ```

## Implementation Evidence

- `TMPDIR=/private/tmp LOOM_TEST_BASH="$(command -v bash)" LOOM_EXPECTED_BASH_VERSION="^[345]\\." bats plugins/loom/hooks/precompact-write-ahead-backstop.bats`
  — 45 tests, 0 failures (existing `T1`–`T13`, `RED-GREEN`, 6 `hook-wire-v1`
  fixtures, root-preference test unchanged; new `T7f`–`T7i`, `T12b` x3, `T14`–`T18`).
- `shfmt -i 4 -d` on the hook and the Bats file: clean. `shellcheck -s bash` on the
  hook: clean; on the Bats file only the four pre-existing info-level findings remain
  (SC2016 line 16, SC2030/SC2031 around the fixture helper), none from new code.
- `/bin/bash -n` on the hook: ok. `node scripts/validate-repository.mjs --root . --all`:
  passed.
- Acceptance mapping: grammar/type checks → `T7f`–`T7i`; log record, control-character
  stripping and cap fallback → `T12b`; coordinated checkpoint anchor and
  remediation on both wires → `T14`, `T16`; cross-session isolation → `T15`;
  concurrency/no leftover `.tmp.*` → `T17`; common-git-dir sharing → `T18`.
- Not run in this pass: the full `scripts/check` repository gate (left to the code
  evaluator).

## Notes

None.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |
| 1 | Cite `loom-coord` (`STATE_DIR="$GITDIR/loom"`, `_with_session_dir`/`_session_checkpoint_write_op`) and explicit `--session <client-session-id>`/`LOOM_SESSION_ID` binding + uncoordinated `.docs` boundary; specify `LOOM_PRECOMPACT_LOG_CAP` invalid/leading-zero fallback to 200 and `"write an advanced checkpoint"` remediation; raise target size to `<= 240 LOC`; fix `Verification` commands (`TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`, `shfmt -i 4 -d`, `shellcheck -s bash`, `TMPDIR=/private/tmp` on `bats`). |
