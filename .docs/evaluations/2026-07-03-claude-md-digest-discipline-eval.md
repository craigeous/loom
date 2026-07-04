# Evaluation: 2026-07-03-claude-md-digest-discipline

Verdict: FAIL
Round: 1
Reviewed against: cited sources [1]–[7] — local files `CLAUDE.md`,
`.docs/spec/08-playbook.md`, `.docs/spec/03-artifact-lifecycle.md`,
`.docs/ADR/0012-*.md` / `0013-*.md`; external URLs [3][4] not independently
fetched (see Notes).

## Findings

- [MAJOR] Citation [7] is inaccurate on two counts. (a) The cited path
  `.docs/ADR/0012-thin-orchestrator-context-aware-cold-restart.md` **does not
  exist**; the real file is `0012-thin-orchestrator-sonnet-default-bounded-return.md`
  (verified via `ls .docs/ADR/`). The note's title paraphrase "Thin Orchestrator,
  Context-Aware Cold Restart" is likewise not ADR 0012's actual title. (b) The
  note attributes the "**~60% restart trigger**" to ADR 0012, but that numeric
  trigger is established in **ADR 0013** (`0013-starvation-loop-guards...`, which
  states the checkpoint/re-bootstrap "at ~60% of budget"). ADR 0012 establishes
  context-budget discipline and cold-restart-as-the-answer (Decision 4) but does
  **not** own the ~60% number. This mis-sources a specific operational parameter
  and points a reader at a nonexistent file — squarely in scope for a
  sources-resolve / sources-support check. The load-bearing alignment claim
  (loom already practices context-budget discipline → CLAUDE.md concision is
  consistent with it) is itself correct and does trace to ADR 0012; only the
  citation form and the ~60% attribution are wrong.

- [MINOR] The `parallelism.md` bullet is **9 lines** (CLAUDE.md 82–90), not the
  "10 lines" stated in [2], the Diagnosis restatement list (line 16), and the
  Target compression example (line 39). Off by one; does not change the argument.

- [MINOR] "Gate (19 lines)" (Diagnosis, line 15) — the Gate section is lines
  168–188 = **21 lines** (19 excluding the header and trailing blank is a
  defensible reading, but state the basis). Cosmetic.

- [MINOR] Citation [5] gives spec-08 range "lines 69–106"; the
  `### CLAUDE.md auto-propagation` subsection actually runs 69–105 (`## Verified
  gate` begins at 107). Trivial off-by-one.

- [MINOR] External citations [3][4] (claude.com blog, code.claude.com
  best-practices) were **not independently fetched** — this evaluator has no
  verified web access, so the verbatim quotes ("less than 200 lines… as low as
  60 lines"; "Would removing this cause Claude to make mistakes?") and the
  attributed inclusion/exclusion test could not be confirmed against source. This
  is a stated tool limitation, **not** grounds for FAIL: the claims are internally
  consistent and plausible, and the note's local reasoning stands on its own
  (67% restatement measured directly). Flagged as context.

## Required changes (for FAIL)

1. Fix citation [7]: correct the ADR-0012 filename to
   `0012-thin-orchestrator-sonnet-default-bounded-return.md` (and correct the
   title paraphrase to match the real ADR 0012 title). Re-attribute the "~60%
   restart trigger" to **ADR 0013** (starvation-loop guards / cold-restart
   trigger), keeping the ADR-0012 attribution only for context-budget
   discipline and the cold-restart-as-answer decision. Reconcile the same ~60%
   attribution wherever it recurs (lines 42–43 compression example text, line 77,
   line 87).

## Notes

Everything else checked out mechanically and the note is otherwise sound:

- **Diagnosis numbers accurate.** `CLAUDE.md` is **197 lines** (`wc -l`); the
  Repo-layout section spans **lines 27–158 = 132 lines = 67.0%** of the file
  (`## Repo layout` at 27, `## Project conventions` at 159). ✓
- **Restatement examples accurate** except the parallelism off-by-one above:
  `init-detection.md` bullet 57–59 (3 lines) ✓; `orchestration.md` bullet
  122–143 (22 lines) ✓; `infrastructure-blocked` bullet 144–156 (13 lines) ✓.
- **Spec-gap claim confirmed.** Spec 08 §"CLAUDE.md auto-propagation" (69–105)
  defines the four inclusion categories + per-slice-history exclusion but has
  **no shape/size or point-don't-restate rule**; spec 03 finalize step 2 (73–81)
  likewise governs scope, not shape. The proposed "Shape and Concision
  Discipline" subsection is **additive** — it constrains how included content is
  expressed, not what is included — so it does not contradict the existing
  inclusion/exclusion rules. ✓
- **Proposed target shape follows soundly from the diagnosis** (80–100 lines,
  stable-top + pointer-index zones, one-clause pointers) and is actionable.
- **Scope discipline is good:** the note proposes and defers the amendment
  decision to the planner (line 112 and the Open Questions), consistent with the
  research role.

Because the substantive reasoning is sound, the required change is narrow and
mechanical — a corrected citation, not a rethink.
