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

---

# Round 2 (code)

Verdict: PASS
Round: 2
Commit reviewed: `b0bd3e9` (`slice initialized-init-behavior: add initialized.md
and repoint call sites`).
Reviewed against: `.docs/spec/06-init-modes.md` §3 + "Playbook re-application
(idempotent)"; `status-machine.md` (statuses + dispatch table);
`orchestration.md` Init-mode section; `commands/run.md` Step 3 driver loop;
`commands/init.md` Step 3; the prior Round 1 plan-eval above. No compiled gate
(loom is markdown) — acceptance verified mechanically with `rg`/`ls`/`realpath`
against the real tree, not by trusting the diff's self-description.

## Mechanical-check results

1. **Spec-06 §3 fidelity (state-derived menu).** `initialized.md` Step 1 derives
   the menu from real `.docs/` `Status:` lines + `git status`/`git log` and
   cross-references the `status-machine.md` dispatch table; each of the five spec
   §3 menu items is a table row tied to its triggering status. The hard rule
   ("derived from actual current statuses, never a static list divorced from real
   state") is stated explicitly. Verified the body restates none of run.md's a–g
   sub-steps: `rg '^\s*[a-g]\.' initialized.md` → none; handoff points at
   `run.md` Step 3 as authoritative. PASS.
2. **Dispatch-table cross-check (no invented status).** Every status the menu
   references exists in `status-machine.md`, and the next-actor mappings match the
   dispatch table exactly: `Plan Review`→plan evaluator, `In Progress`→developer,
   `Implemented`→code evaluator, `Research Review`→plan evaluator. `Needs
   Clarification` + round-limit/escalation surfaced as real states. PASS.
3. **Idempotent re-application single-sourced (Q10).** Full merge strategy lives
   only in `initialized.md` Step 3 (auto-apply clean / recommend conflicts / never
   clobber), matching spec-06's "Playbook re-application (idempotent)".
   `rg 'initialized\.md' orchestration.md` → two pointer hits (Init bullet + the
   former one-liner now reads "see initialized.md for the merge strategy …"). The
   inline divergent restatement "Re-alignment is idempotent: auto-apply … Never
   clobber project edits." is gone; what remains is a pointer with a parenthetical
   summary, not an owned rule. No duplication/divergence. PASS.
4. **Gate-learning stays a forward pointer.** `rg -i gate-learning initialized.md`
   → marked deferred throughout; closing note: "Gate-learning is out of scope here
   and remains a forward pointer." Matches `greenfield.md` Step E / `unaligned.md`
   Step 2 pattern. No gate logic implemented. PASS.
5. **Call sites + links.** Old phrasings gone in orchestration.md + run.md
   ("behavior body forthcoming", "summarize current state and continue") and
   "forthcoming M2 slice" gone from CLAUDE.md (all `rg` → zero). All four call
   sites point at `initialized.md` (orchestration.md, run.md, init.md, SKILL.md).
   Every relative link in `initialized.md` resolves against the real tree:
   `../../../../../.docs/spec/06-init-modes.md`, `status-machine.md`,
   `orchestration.md`, `../../../commands/run.md` (`realpath` →
   `plugins/loom/commands/run.md`), `commit-convention.md`. PASS.
6. **Scope discipline.** `git show --name-only` = `initialized.md` (new) +
   `orchestration.md` + `run.md` + `init.md` + `SKILL.md` + `CLAUDE.md` +
   slice-plan status line. No path under `.docs/spec/` or `.docs/ADR/`. SKILL.md
   bullet sits immediately after `unaligned.md` (lines 53→54). PASS.
7. **CLAUDE.md no over-claim.** Heading stays "Repo layout (M2 in progress)". The
   "per-mode trio … is now complete" clause is correctly scoped to the per-mode
   bodies and the same sentence states "gate-learning remains a forward pointer";
   no claim that M2 itself is done. PASS.

## Findings

- [MINOR] `.docs/slice-plans/README.md` "Active plans" entry still shows
  `Plan Review` for this slice (added in the plan commit `caea545`). README index
  archival is the finalize step's job, not this slice's developer scope, and the
  file is correctly absent from this commit — non-blocking, carried forward from
  Round 1's MINOR. The finalize pass should move it to Archived with the landing
  hash.
- [MINOR] `initialized.md` Step 3 adds a third merge bullet ("Never clobber …
  regardless of merge cleanliness") beyond spec-06's two bullets. It is an
  emphasis of the never-clobber invariant, not a contradiction — harmless.

## Required changes

None — no blockers, no unaddressed majors. The two MINORs above are advisory.
