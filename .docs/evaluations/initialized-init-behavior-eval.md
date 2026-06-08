# Evaluation: initialized-init-behavior

Verdict: PASS
Round: 1
Reviewed against: `.docs/spec/06-init-modes.md` §3 + "Playbook re-application
(idempotent)"; `init-detection.md`; `status-machine.md` (statuses + dispatch
table); `orchestration.md` (Init-mode section + existing idempotent lines);
`commands/run.md` (Step 3 driver loop); `commands/init.md` Step 3;
`greenfield.md` / `unaligned.md` (the landed pattern). Call-site claims verified
mechanically against the real tree.

## Findings

- [MINOR] Step 7 (slice-plans README "Active plans" entry) is already present in
  the repo — the entry was committed in the same commit as the plan itself
  (`caea545 Plan: Initialized init behavior body slice-plan`). The step as written
  is therefore largely a no-op; harmless, but the developer should treat it as a
  verify-only step rather than an add.
- [MINOR] Verification check #2 (`rg -i "Plan Review|In Progress|Implemented|
  Research Review|roadmap|show status"`) proves the tokens are *present* in
  `initialized.md`, not that each menu item is *mapped* to its triggering status as
  the prose claims. The mapping intent is sound and covered by the body's Step 1
  content + check #3; the regex is just a weaker proxy than the sentence implies.
- [MINOR] Verification check #8's `rg -i "forthcoming M2 slice|M2 (in progress|
  complete|done)"` is mechanically loose (line-wrapped alternation, unescaped
  grouping). Intent is clear; tighten if convenient.

## Required changes (for FAIL)

None — no blockers, no unaddressed majors.

## Notes

Strengths confirmed against authority:

- **State-derived menu, not a static list.** Body Step 1 scans `.docs/` `Status:`
  lines + git and cross-references the `status-machine.md` dispatch table, with the
  explicit hard rule "derived from actual current statuses, never a static list
  divorced from real state." The five spec §3 menu items are each tied to a real
  status (`Plan Review` / `In Progress` / `Implemented` / `Research Review` /
  roadmap), all of which exist in `status-machine.md`. The mapping to next-actor
  (plan evaluator / developer / code evaluator) matches the dispatch table. It also
  surfaces `Needs Clarification` and round-limit/escalation states — both real per
  `status-machine.md` (lines 18, 39–43).
- **Handoff references, not restates, the driver loop.** Step 2 of the body points
  at `/loom:run` Step 3 as the single authoritative loop and explicitly forbids
  restating its a–g sub-steps; scope vocabulary is pointed at orchestration.md.
- **Idempotent rules single-sourced, not duplicated.** Body Step 3 holds the full
  Q10 merge strategy; plan Step 2 converts orchestration.md's inline one-liner
  (lines 51–52) into a pointer at the body, and verification #5 mechanically
  confirms the inline restatement is removed and both orchestration spots point at
  `initialized.md`.
- **Gate-learning stays a forward pointer**, consistent with `greenfield.md` Step E
  / `unaligned.md` Step 2; called out in Out-of-scope and body Steps 3/4 and
  re-asserted in the closing idempotence note.
- **No spec/ADR edits**; hard boundary stated and checked (#10). Both relative
  links verified to resolve from `references/`: `../../../../../.docs/spec/
  06-init-modes.md` and `../../../commands/run.md` (the plan's "verify the `../`
  count" hedge lands on the correct value).

Line-number claims at all call sites verified against the real tree:
orchestration.md 47–49 / 51–52, run.md 24, init.md 23–25, init-detection.md 91,
SKILL.md 53, CLAUDE.md 27 ("Repo layout (M2 in progress)") and 47 ("The
Initialized body is a forthcoming M2 slice."). No over-claim risk: the plan
explicitly keeps the heading at "M2 in progress" and forbids declaring M2 done.
