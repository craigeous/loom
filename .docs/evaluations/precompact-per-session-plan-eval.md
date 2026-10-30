# Evaluation: precompact-per-session (slice-plan)

Verdict: FAIL
Round: 1
Reviewed against: `.docs/repository-improvement-plan.md` §"Slice: `precompact-per-session`" (lines 495-522); `.docs/spec/04-orchestrator.md` (`## Thin-orchestrator invariant`, coordination containment rule ~L397); `.docs/spec/00-overview.md` `## Non-goals`; current tree `plugins/loom/hooks/precompact-write-ahead-backstop.{sh,bats}`; `plan-eval-rubric.md`; `severity.md`.

> Round note: this is the first review of a fresh artifact (requested as Round 0).
> Per the counting rule, a FAIL increments the counter, so this FAIL is recorded as
> `Round: 1`. A later PASS resolving it repeats `Round: 1`.

## Findings

- [MAJOR] **The session-ID binding between the hook and `loom-coord` is assumed, never sourced or established.** — `## Context` item 1, Step 2 sketch (`SESSION_COORD_DIR="$GITDIR/loom/session-$SESSION"`), T14/T15/T16. The hook's `$SESSION` is the client-supplied hook `session_id` (for Claude Code, the host's own session identifier). The plan treats it as identical to the `<sid>` passed to `loom-coord session-start` / `checkpoint-write --session <sid>`, and treats `<git-common-dir>/loom/session-<sid>/checkpoint` as the exact on-disk layout. The plan cites spec 04 `## Thin-orchestrator invariant` for this, but that section only says restart state is "per-session and untracked under the common Git directory". It names neither the path nor how the id is derived. If the orchestrator's `loom-coord` session id is not the client hook `session_id`, the `COORDINATED=1` branch never fires in production. Every coordinated session would then silently fall back to the repository-wide `.docs` anchor, which is the very cross-session bleed the slice is meant to close, and the improvement-plan criterion "validate advancement of the actual per-session checkpoint written by `loom-coord checkpoint-write`" would go unmet. T14–T16 pass the same literal sid to both sides, so they would pass even though they prove nothing about that binding. `loom-coord` is explicitly out of scope to modify, so the plan must pin its layout and id contract to a citable authority. That authority was not in this review's read scope, so I could not verify the claim mechanically. An independent developer could implement this wrongly.
- [MAJOR] **The Verification section names the wrong full gate and static-check flags that fail on unchanged code.** — `## Verification`. (a) The "Full repository gate" is `node scripts/validate-repository.mjs --root /Users/craig/git/loom --all`, which hardcodes one machine's absolute path. The project's shell gate is `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`, run once on the candidate commit. (b) `shfmt -d -i 4 -ci` adds `-ci` (indent switch cases). The existing hook writes `case` arms flush with `case` (e.g. `manual | auto) ;;` at L158-161, and L41-44, L73-78, L101-110), and so does the plan's own `_loom_valid_session_id` sketch. The prescribed format check would therefore flag unchanged lines and new code that follows the plan exactly. (c) `shellcheck` is given without `-s bash`. Following the plan's verification as written either fails spuriously or skips the real gate.
- [MINOR] Handling of an invalid `LOOM_PRECOMPACT_LOG_CAP` is underspecified. Step 1 says "validate ... as a positive decimal integer (default `200`)" but does not say whether an invalid value falls back to 200 (T12b implies it does) or fails. It also does not say whether leading zeros are rejected: Bash `$((08 - 1))` is an arithmetic error. State "invalid or leading-zero → 200".
- [MINOR] The remediation path depends on checkpoint content changing. The anchor is `git hash-object` of the checkpoint file, so a `checkpoint-write` that rewrites byte-identical content (same next action, no timestamp) does not unblock. That is arguably correct given spec 04's starvation rule, but the coordinated block message should say "write an advanced checkpoint" so the improvement plan's "manual remediation always provides a real path forward" is honest.
- [MINOR] Residual bleed for uncoordinated sessions is not stated. Sessions without a `session-<sid>` directory still share the repository-wide `.docs` anchor. Add one line to `## Out of Scope & Threat-Model Boundary` saying multi-session isolation is guaranteed only for coordinated sessions.
- [MINOR] The fast bats command omits `TMPDIR=/private/tmp`, which the project convention uses on macOS. The 180-LOC budget also looks tight for roughly 50 LOC of script changes plus nine new tests, including worktree and concurrency fixtures. Consider whether the budget is realistic.

## Required changes (for FAIL)

1. In `## Context` (and, where needed, Step 2), cite the authority that fixes the `loom-coord` checkpoint layout (`<git-common-dir>/loom/session-<sid>/checkpoint`) and the derivation of `<sid>`. That means the governing ADR/spec section or the exact `loom-coord` function. State explicitly that the hook's `session_id` equals the `loom-coord` session id, and how that is guaranteed (e.g. the orchestrator starts its coord session with the client session id). If that is not guaranteed today, choose one minimal option and state it: either narrow the slice's claim honestly, or define the minimal lookup the hook uses. Do not invent a new protocol. Make T14 reflect the real binding, not just a shared literal.
2. Replace the full-gate line with `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check` (no absolute machine path). Drop `-ci` from `shfmt` (use `shfmt -i 4 -d`) and add `-s bash` to `shellcheck`.

## Notes

- Strengths: the plan follows the canonical structure (`Target size:`, explicit `## Out of Scope & Threat-Model Boundary`, numbered file-scoped steps, Revision Log) and stays well under 250 lines. It preserves the byte-exact `hook-wire-v1` uncoordinated reason and leaves the frozen fixtures alone. It keeps the fail-closed `INVALID_REASON` path for missing or non-string `trigger`/`session_id`, which is consistent with the existing T6a/T6d/T7a. The `--git-common-dir` switch uses `git -C "$REPO_ROOT"`, so a relative `.git` result is correctly relativized for the main worktree. The new reason stays under the 512-byte sanitizer bound even with a 128-character sid. The tightened session-id grammar is still compatible with every existing test id.
- The threat model is proportional and consistent with `00-overview.md` `## Non-goals`. No same-user `.git/loom` tampering defenses are demanded.
- Neither MAJOR requires redesign. Each is a citation/clarification plus a one-line command fix.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 1 | plan | FAIL | First review. MAJOR: hook `session_id` ↔ `loom-coord` sid / checkpoint path is unsourced (coordinated branch may be dead in production, tests vacuous). MAJOR: wrong full gate and shfmt `-ci` / shellcheck flags. Four MINORs. |
