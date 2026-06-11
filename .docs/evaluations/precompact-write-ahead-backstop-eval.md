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

---

# Code Review

Verdict: PASS
Round: 0
Reviewed against: ADR 0013 (§Decision 5 table, §Context hard safety constraint),
spec 04 (Thin-orchestrator invariant / cold-restart), gates/shell.md, and the
review-findings artifact (advisory). Commit range `origin/HEAD..HEAD`; code in
`347e0d3`.

## Gate (re-run, not trusted)

- format: `shfmt -i 4 -d precompact-write-ahead-backstop.sh` — PASS
- lint: `shellcheck precompact-write-ahead-backstop.sh` — PASS
- test: `bats precompact-write-ahead-backstop.bats` — 11/11 green
- regression: `bats git-identity-guard.bats` — 28/28 green (unchanged)
- `jq . hooks.json` — valid JSON; `PreToolUse` (Bash → git-identity-guard) intact,
  `PreCompact` added alongside (no matcher → both triggers), description extended.

Gate is green; gate is necessary not sufficient — logic and tests traced below.

## Decision-table fidelity (ADR 0013 §Decision 5) — verified line-by-line

- manual + no-progress → exit 2 + stderr remediation, marker NOT advanced
  (sh:102-111; proven T2, T5 pass-2, T9 fallback).
- auto + no-progress → exit 0 + appended log line, marker NOT advanced
  (sh:112-117; proven T3).
- empty/unknown trigger → coerced to `auto` → exit 0 (sh:33-35, 112-117; T6).
- progress advanced → update marker + exit 0 (sh:96-99; T1a/T1b, T5 pass-3).
- first-run (marker absent/unreadable) → record SHA + exit 0 (sh:89-93; T4, T5 pass-1).
- not-a-repo → exit 0 fail-open (sh:62-65; T7). no-.docs-history → exit 0 (sh:83-86).
  empty stdin → empty trigger → auto → exit 0 (T8).
- **Hard safety constraint honored:** the only `exit 2` path is `manual`+no-progress;
  `auto`/empty/unknown never hard-block, so a near-full session is never wedged.

## Correctness + edge cases

- POSIX-sh throughout; `shfmt`/`shellcheck` clean.
- cwd→repo-root resolution: extracts `cwd` from JSON, `cd`s in, resolves via
  `git rev-parse --show-toplevel`; git-dir made absolute (sh:47-75). Cwd-independence
  proven by T10 (run from unrelated dir still resolves REPO). This resolves the
  plan-eval MINOR #1.
- Marker not advanced on block confirmed by T5 pass-2 and re-verified.
- jq + grep/sed fallback for trigger, session_id, and cwd (sh:25-55); fallback
  block-path proven by T9.
- Edge: empty-but-present marker (`PREV=""`) takes the advanced branch → records SHA
  + exit 0 (manually verified). Fail-open / safe direction; consistent with plan
  intent ("unreadable → record and allow"). Not a defect.
- Tests isolate in temp git repos — loom's real `.git/loom/` is never written.

## Scope discipline

Purely additive plugin code: one hook, one bats suite, one additive `hooks.json`
`PreCompact` key + description extension. README.md / plan / artifacts are the
expected index + evaluation files. No `spec/` or `ADR/` text changed.

## Review-findings adjudication (advisory; verdict owned here)

- **Finding 1** (manual-block remediation option 2 "re-run if spurious" is
  non-functional; hook is deterministic and only a `.docs/` commit clears it) —
  **CONFIRMED factually, severity MINOR.** The behavior is exactly what ADR 0013's
  open question and the plan's "Accepted coarseness" prescribe (block once,
  recoverable by checkpoint); the never-wedge property holds (`auto` never blocked).
  Only the remediation wording is mildly misleading — a wording nit, not a
  correctness/safety/spec defect. Does not block landing.
- **Finding 2** (session_id with embedded tab/newline could corrupt the log line) —
  **CONFIRMED possible, severity MINOR.** Harness-supplied semi-trusted input, log-
  shape only; security-review excluded it. Optional hardening. Non-blocking.
- **Finding 3** (append-only log unbounded over a long-lived checkout) —
  **CONFIRMED, severity MINOR/informational.** One short line per no-progress `auto`
  event; DoS-class, out of scope. Non-blocking.

No finding maps to BLOCKER or MAJOR.

## Findings

- [MINOR] Manual-block remediation option 2 ("re-run /compact if spurious") does not
  actually bypass the deterministic re-block; only committing a `.docs/` checkpoint
  clears it. Consider rewording to avoid implying a re-run escape (review Finding 1).
- [MINOR] `session_id` logged via `printf '%s'` without control-char stripping
  (review Finding 2).
- [MINOR] `precompact.log` is unbounded/no rotation (review Finding 3).

## Required changes (for FAIL)

(none — PASS; no BLOCKER, no MAJOR; MINORs recorded for optional follow-up)

---

# Plan Review (prior)

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
