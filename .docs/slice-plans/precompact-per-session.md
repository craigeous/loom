# Per-Session PreCompact Write-Ahead Backstop (`precompact-per-session`)

Status: Draft
Target specs: 04-orchestrator.md, 08-client-adapters.md
Target size: <= 180 LOC net change (keep this plan document <= 250 lines)

## Context

`plugins/loom/hooks/precompact-write-ahead-backstop.sh` enforces the ADR 0013
write-ahead invariant before context compaction and already stores per-session
state under `<git-dir>/loom/precompact/<session-id>/{marker,log}` behind the
spec 08 `hook-wire-v1` adapter contract. However, four gaps remain against M3
slice `precompact-per-session` in `.docs/repository-improvement-plan.md`:

1. **Coordinated session checkpoints are ignored:** High-frequency orchestrator
   checkpoints written by `loom-coord checkpoint-write --session <sid>` live at
   `<git-common-dir>/loom/session-<sid>/checkpoint` (untracked under `.git/loom/`,
   per spec 04 `## Thin-orchestrator invariant`). The hook currently computes its
   progress anchor (`CUR`) solely from `git log -1 --format=%H -- .docs`. As a
   result, `loom-coord checkpoint-write` does not advance the session's
   compaction marker, and in a multi-session repository one session's `.docs/`
   commit advances `CUR` for another coordinated session whose own per-session
   checkpoint has not moved.
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
   that names `loom-coord checkpoint-write --session <sid>` (while uncoordinated
   sessions preserve the byte-exact `hook-wire-v1` fixture message `"commit a
   .docs/ checkpoint, then retry"`), and `_loom_append_bounded_log` /
   `_loom_atomic_write` need `mktemp`-backed atomic temp files, `LOOM_PRECOMPACT_LOG_CAP`
   integer validation, control-character sanitization, and `<timestamp>\t<session>\t<anchor>`
   log records.

## Out of Scope & Threat-Model Boundary

- **Out of scope:** Modifying `plugins/loom/bin/loom-coord`, changing the frozen
  `plugins/loom/hooks/fixtures/hook-wire-v1/` fixture files, changing
  `plugins/loom/hooks/hooks.json`, or modifying `.docs/spec/` / `.docs/ADR/`.
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
     as a positive decimal integer (default `200`), and strip control characters
     (`LC_ALL=C tr -d '\000-\010\013-\037\177'`) from log lines before writing.

2. **Resolve `--git-common-dir` and validate per-session coordinated checkpoints
   in `plugins/loom/hooks/precompact-write-ahead-backstop.sh`:**
   - Resolve `GITDIR` via `git -C "$REPO_ROOT" rev-parse --git-common-dir 2>/dev/null`
     (falling back to `--git-dir`), relativized against `$REPO_ROOT` when not
     absolute, so linked worktrees share `<common-git-dir>/loom/`.
   - Compute the per-session progress anchor `CUR` and `COORDINATED` flag as:
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
       `"loom write-ahead backstop: session checkpoint has not advanced before manual compaction (ADR 0013); run loom-coord checkpoint-write --session ${SESSION}, then retry."`;
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
     strips control characters, and survives a non-numeric `LOOM_PRECOMPACT_LOG_CAP`.
   - Add `T14`: coordinated session round-trip using real `plugins/loom/bin/loom-coord`
     (`session-start` + `checkpoint-write`) — first-run allows, repeated manual
     compaction blocks with the `loom-coord checkpoint-write --session <sid>`
     remediation (both Claude exit-2 and Codex JSON wire), and a subsequent
     `loom-coord checkpoint-write` advances the checkpoint and unblocks compaction.
   - Add `T15`: two coordinated sessions (`sA`, `sB`) where `sA` advances via
     `loom-coord checkpoint-write --session sA` AND commits to `.docs/`; `sA`
     compacts (`status 0`) while `sB` remains blocked (`status 2`).
   - Add `T16`: coordinated session directory present without `checkpoint` file
     yet records `checkpoint:none` on first run, blocks on second manual run, and
     unblocks after `loom-coord checkpoint-write`.
   - Add `T17`: concurrent compactions across two sessions (`s-adv` advancing,
     `s-stale` unadvanced) run in parallel without marker corruption or leftover
     `.tmp.*` files.
   - Add `T18`: linked `git worktree add` invocation resolves `--git-common-dir`
     and shares the common `.git/loom/` state directory.

## Verification

- **Fast targeted iteration command:**
  ```bash
  LOOM_TEST_BASH="$(command -v bash)" LOOM_EXPECTED_BASH_VERSION="^[345]\\." \
    bats plugins/loom/hooks/precompact-write-ahead-backstop.bats
  ```
- **Static checks on touched files:**
  ```bash
  shfmt -d -i 4 -ci plugins/loom/hooks/precompact-write-ahead-backstop.sh \
    plugins/loom/hooks/precompact-write-ahead-backstop.bats
  shellcheck plugins/loom/hooks/precompact-write-ahead-backstop.sh \
    plugins/loom/hooks/precompact-write-ahead-backstop.bats
  ```
- **Full repository gate:**
  ```bash
  node scripts/validate-repository.mjs --root /Users/craig/git/loom --all
  ```

## Notes

None.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |
