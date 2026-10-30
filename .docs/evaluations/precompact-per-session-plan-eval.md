# Evaluation: precompact-per-session (slice-plan)

Verdict: PASS
Round: 1
Reviewed against: Round 1 findings (this file's prior FAIL); revision diff `git diff e6d64fa..fbb17d2 -- .docs/slice-plans/precompact-per-session.md`; `plugins/loom/bin/loom-coord` (header L20-25, `SESSION_ID="${LOOM_SESSION_ID:-}"` L108, `cmd_checkpoint_write` / `cmd_session_start`); `.docs/spec/00-overview.md` `## Non-goals`; `gates` convention in project CLAUDE.md.

> Round note: this is a re-review under the Round >= 1 non-expansion rule. Only Round 1
> findings and the revision diff were checked. A PASS resolving a Round 1 FAIL keeps
> `Round: 1` per the counting rule.

## Round 1 findings — resolution

- [MAJOR] **Session-ID binding unsourced — RESOLVED.** `## Context` item 1 and Step 2 now cite
  `loom-coord`'s layout (`STATE_DIR="$GITDIR/loom"`, `_with_session_dir`,
  `_session_checkpoint_write_op` writing `$STATE_DIR/session-<id>/checkpoint`). I verified this
  mechanically: the `loom-coord` header documents `$STATE_DIR/session-<id>/checkpoint`, the id comes
  from `--session` or `LOOM_SESSION_ID` (L108), and `checkpoint-write` runs through
  `_with_session_dir ... require`. The plan takes the "narrow the claim honestly" option from the
  Required changes. The binding is stated as conditional on the orchestrator starting `loom-coord`
  with `--session <client-session-id>` or `LOOM_SESSION_ID`. A new `Session-binding scope` bullet
  says isolation applies only to coordinated sessions bound this way, and that uncoordinated
  sessions keep the shared `.docs` anchor. This also resolves the MINOR on residual bleed for
  uncoordinated sessions. T14 now invokes the real `loom-coord session-start` and
  `checkpoint-write` with the hook's `session_id`. No new protocol is invented, and `loom-coord`
  stays out of scope.
- [MAJOR] **Wrong gate / flags — RESOLVED.** The Verification section now uses
  `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`, `shfmt -i 4 -d` (no `-ci`), and
  `shellcheck -s bash`. The machine-specific absolute path is gone.
- [MINOR] **`LOOM_PRECOMPACT_LOG_CAP` fallback — RESOLVED.** The plan now uses `^[1-9][0-9]*$`, with
  invalid or leading-zero values falling back to 200. T12b covers `abc`, `08`, `0`.
- [MINOR] **Remediation wording — RESOLVED.** The coordinated block message now says "write an
  advanced checkpoint via loom-coord checkpoint-write --session ${SESSION}". T14 covers
  identical-bytes rewrite still blocking.
- [MINOR] **Residual uncoordinated bleed — RESOLVED** (see the session-binding scope bullet above).
- [MINOR] **`TMPDIR` on the fast bats command and LOC budget — RESOLVED.** The fast command now
  sets `TMPDIR=/private/tmp`, and the target size is raised to <= 240 LOC. The plan is 199 lines,
  within the 250 cap.

## New findings

None. The revision diff touches only the items above; no regressions were introduced.

## Notes

- Residual (non-blocking, not a finding): whether the real orchestrator in production starts
  `loom-coord` with the client hook `session_id` is outside this slice and is honestly stated as a
  precondition. Without that binding the hook degrades to the existing `.docs` anchor, which is
  the status quo, so the slice is no worse and is safe to implement.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 1 | plan | FAIL | First review. MAJOR: hook `session_id` ↔ `loom-coord` sid / checkpoint path unsourced. MAJOR: wrong full gate and shfmt `-ci` / shellcheck flags. Four MINORs. |
| 1 (re-review) | plan | PASS | Revision cites and verifies the `loom-coord` layout, narrows the isolation claim to bound coordinated sessions, and fixes the gate commands. All MINORs addressed. No new findings. |
