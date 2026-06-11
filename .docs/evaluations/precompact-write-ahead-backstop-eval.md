# Evaluation: precompact-write-ahead-backstop-plan

Verdict: PASS
Round: 0
Reviewed against: ADR 0013 (§Decision 5, §Context hard safety constraint),
spec 04 (Thin-orchestrator invariant / cold-restart), gates/shell.md, and the
existing-hook pattern (git-identity-guard.sh / .bats / hooks.json).

## Findings

- [MINOR] The progress anchor `git log -1 --format=%H -- .docs` resolves `.docs`
  **relative to the hook's `cwd`**, while the marker path is resolved via `git
  rev-parse --git-dir`. If a future caller invokes the hook from a subdirectory,
  `-- .docs` could match nothing → empty `CUR` → fail-open allow. This degrades in
  the *safe* (never-block) direction and matches loom's "orchestrator runs at repo
  root" assumption, so it is not a defect — but the plan should state that `.docs`
  is cwd-relative and that a non-root cwd fails open by design (consider anchoring
  on the git toplevel for robustness).
- [MINOR] Step 2's `hooks.json` `description` instruction is phrased as a choice
  ("update… **or** leave intact…") before resolving to "extend `description` to
  mention the write-ahead backstop." The directive lands concretely (extend), but
  the either/or framing is mildly self-contradictory; drop the alternative so the
  step reads as a single unambiguous edit.
- [MINOR] T9 (jq-absent fallback) is marked optional. Given the hook ships a
  `grep`/`sed` fallback branch that selects the block-vs-allow path, exercising it
  is cheap and the existing `guard_no_jq` helper makes it nearly free; recommend
  promoting it to required so the fallback branch is regression-covered like the
  identity guard's F1–F3.

## Required changes (for FAIL)

(none — PASS)

## Notes

The slice satisfies the four rubric-critical checks:

- **(a) Safety decisions concrete; auto-never-wedge holds.** The only `exit 2`
  path is `manual` + no-progress. `auto`, empty, and unknown triggers all route to
  `exit 0` (Decision 1; step 1 "empty → treat as `auto`"; T3/T6). An `auto`
  compaction therefore can never be hard-blocked, satisfying ADR 0013's hard
  constraint that a near-full session must never be wedged. The backstop downgrades
  `auto` no-progress to an appended log line, preserving observability without risk.
- **(b) No-progress + marker scheme sound, coarseness honestly bounded.** Anchor =
  `git log -1 --format=%H -- .docs` (verified to return a SHA in this repo) vs a
  marker under `<git-dir>/loom/` — outside the tracked worktree, survives
  compaction, needs no `.gitignore`. First-run records + allows; the marker is not
  advanced on a block, so a genuine subsequent checkpoint is still detected as
  progress. Decision 3's "Accepted coarseness" section states the false-positive
  bound openly (a legitimate `manual` compaction with no new `.docs/` work blocks
  once, with remediation) and ties it to ADR 0013's open question rather than hiding
  it.
- **(c) bats cases exercise the claimed behavior.** T1–T8 map one-to-one onto the
  decisions: advance→allow+marker-update; `manual` no-progress→block+remediation
  cue+marker-unchanged; `auto` no-progress→allow+log-line+marker-unchanged;
  first-run→create+allow; persistence round-trip; empty-trigger→auto; fail-open
  non-repo; fail-open empty stdin. Tests run in an isolated temp git repo so the
  marker/log never touch loom's real `.git/`. T9 mirrors the real `guard_no_jq`
  helper (confirmed present in git-identity-guard.bats).
- **(d) Single small slice.** One new hook, one additive `hooks.json` edit, one new
  bats file; purely additive plugin code, no spec/ADR text change. Single-purpose.

Mechanically verified: `hooks.json` is valid JSON with only a `PreToolUse` key
(the plan's `PreCompact`-alongside claim is correct); no precompact files exist yet;
`git log -1 --format=%H -- .docs` and `git rev-parse --git-dir` both resolve as the
plan assumes. Verification names the shell gate (`shfmt -i 4 -d` → `shellcheck` →
`bats`) verbatim and the regression proof (existing suite unchanged; hooks.json
stays valid JSON). Playbook conformance is good: identity-neutral, POSIX-sh,
fail-open, registration shape mirrors the existing guard. Fresh artifact, no prior
FAIL → round 0.
