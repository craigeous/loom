# ADR 0011 playbook conformance: `/review` → `/code-review`

Status: Plan Review
Target specs: 04-orchestrator.md, 02-roles.md

## Context

Accepted [ADR 0011](../ADR/0011-correct-automated-review-command-to-code-review.md)
corrects the orchestrator's automated-review command: the local-diff review command
is **`/code-review`**, not `/review` (the built-in `/review` is PR-bound). It also
adds the commit-range invocation detail — at `Implemented` the slice is already
committed, so the working tree is empty; the orchestrator must target the slice's
**commit range / branch** (e.g. `git diff <base>...<slice-HEAD>`), not the empty
working tree. `/security-review` is unchanged.

Specs [04](../spec/04-orchestrator.md) § "Automated review before a slice lands"
and [02](../spec/02-roles.md) (Code Evaluator) have been re-approved to match —
04 now names `/code-review` and carries a **"Target the slice's commit range"**
bullet. This slice brings the **playbook references** into line with those frozen
specs and ADR 0011. ADR 0011 §Consequences names this as a "Playbook follow-up"
slice, sequenced after the spec amendments (now done).

**The change is mechanical and safe.** `/review` (with leading slash) is *not* a
substring of `/security-review` (which has no bare `/review`), and no `/code-review`
exists in these files yet, so a targeted bare-`/review` → `/code-review` swap cannot
corrupt `/security-review`. Verified pre-state (`rg -n '/review\b'`): every bare
`/review` hit lives in the three files below; `/security-review` counts are
orchestration.md=1, code-eval-rubric.md=1, review-findings.md=6.

**Out of scope (do not touch):**
- `plugins/loom/agents/code-evaluator.md` — confirmed by `rg` to contain **no**
  `/review` mention (it points to the rubric generically). Leave untouched; the plan
  re-confirms this in Verification.
- Specs, ADRs, `SKILL.md`, the slice-plans `README.md` index, and the
  `.docs/status/` living docs. None are edited by this slice.

## Steps

1. **`plugins/loom/skills/loom-playbook/references/orchestration.md`** — the
   "Automated review before a slice lands" section (lines ~59–83).

   a. **Authority line (~63).** Add an ADR 0011 citation alongside the existing
      ADR 0010 one. The authority currently reads:
      ```
      [ADR 0010](../../../../../.docs/ADR/0010-orchestrator-run-automated-review-in-code-eval.md)
      §1.
      ```
      Add a link to
      `../../../../../.docs/ADR/0011-correct-automated-review-command-to-code-review.md`
      (same relative-path depth as the existing ADR 0010 link) so both ADRs are
      cited.

   b. **Run step (~67).** Change the bare `/review` to `/code-review`:
      ```
      run Claude Code's built-in `/code-review` and `/security-review` on the slice's
      ```
      Leave `/security-review` exactly as-is.

   c. **Add a commit-range targeting detail** mirroring spec 04's new "Target the
      slice's commit range" bullet (spec 04 §, lines 62–67). Add a new bullet in
      this section (place it adjacent to the existing "Local diff mode only" bullet,
      ~74–77, which is the natural home for invocation detail) stating: at
      `Implemented` the slice is already committed, so the working tree is empty;
      the orchestrator targets the slice's **commit range / branch** when running
      `/code-review` — e.g. `git diff <base>...<slice-HEAD>` or passing the slice
      branch/range as the command's target argument — never the empty working tree.
      Cite ADR 0011 §2 on this bullet. Keep wording consistent with spec 04's bullet
      (do not contradict or restate verbatim beyond what conveys the same fact). Use
      the same `../../../../../.docs/ADR/0011-...` link form as in step 1a.

2. **`plugins/loom/skills/loom-playbook/references/code-eval-rubric.md`** — the
   "Review-findings adjudication" section.

   a. **Line ~40–41.** In the parenthetical "produced by running `/review` and
      `/security-review` on the slice diff", change `/review` → `/code-review`.
      Where ADR 0010 is cited on that same sentence (~41), add an ADR 0011 citation
      alongside it (same relative-path link form already used for the ADR 0010 link
      on line 41: `../../../../../.docs/ADR/0011-...`).

   b. **Line ~51.** In "(`/review` scores confidence and explicitly expects false
      positives …", change `/review` → `/code-review`. Leave the surrounding
      adjudication wording otherwise unchanged.

3. **`plugins/loom/skills/loom-playbook/references/review-findings.md`** — replace
   every bare `/review` with `/code-review` (`/security-review` stays). The bare
   `/review` occurrences are:
   - line ~4 — "carries `/review` and `/security-review` output";
   - line ~69 — "`/review` and `/security-review` run independently";
   - line ~94 — "**source command** — `/review` or `/security-review`";
   - line ~98 — "(e.g. `/review` scores confidence and explicitly expects false
     positives …";
   - line ~123 — the illustrative-skeleton heading `## /review` (first skeleton);
   - line ~141 — the illustrative-skeleton heading `## /review` (docs-only skeleton).

   In both skeletons the heading becomes `## /code-review`; the `## /security-review`
   headings stay. (The skeletons are illustrative structure, not a schema — only the
   command name changes.)

## Verification

This is a **pure-markdown** slice — there is **no** `format → lint → test` gate to
run. The substantive check is the blind code-evaluator's fidelity/consistency review
against ADR 0011 and re-approved specs 04/02. The developer must run the following
mechanical checks and record the results:

- **(a) Zero bare `/review` remain in the three files.** ripgrep in this environment
  lacks PCRE2/look-around, so a negative-lookahead pattern is not available. Instead
  run:
  ```
  rg -n '/review\b' plugins/loom/skills/loom-playbook/references/orchestration.md \
    plugins/loom/skills/loom-playbook/references/code-eval-rubric.md \
    plugins/loom/skills/loom-playbook/references/review-findings.md
  ```
  and **eyeball that every remaining hit is part of `/code-review` or
  `/security-review`** (i.e. each match is immediately preceded by `code` or
  `security-`). Equivalently, cross-check with
  `rg -n '/code-review|/security-review'` and confirm the hit counts add up to the
  total `/review\b` hits (no orphan bare `/review`).

- **(b) `/security-review` count unchanged.** `rg -c '/security-review'` on each file
  must still report orchestration.md=1, code-eval-rubric.md=1, review-findings.md=6.

- **(c) Every former `/review` is now `/code-review`.** Confirm `rg -c '/code-review'`
  reports at least: orchestration.md ≥ 1 (run step + any in the new commit-range
  bullet), code-eval-rubric.md = 2 (lines ~40 and ~51), review-findings.md = 6
  (the six former bare-`/review` sites: ~4, ~69, ~94, ~98, and the two `## ` skeleton
  headings).

- **(d) Out-of-scope file untouched.**
  `rg -n '/review\b' plugins/loom/agents/code-evaluator.md` must return **no hits**
  (the file was never to be edited and contains no `/review` mention to begin with).
  No edits to specs, ADRs, `SKILL.md`, the slice-plans `README.md`, or `.docs/status/`.

- **(e) ADR 0011 cited** wherever ADR 0010 is cited for the command/invocation in the
  three edited files (orchestration.md authority + commit-range bullet;
  code-eval-rubric.md ~41). New links resolve to
  `0011-correct-automated-review-command-to-code-review.md` at the correct
  relative-path depth (mirror the adjacent ADR 0010 link's depth in each file).

## Notes

<none>
