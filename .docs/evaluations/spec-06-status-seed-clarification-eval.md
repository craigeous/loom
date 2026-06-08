# Evaluation: spec/06-init-modes.md §1 — status-seed "empty" clarification

Verdict: PASS
Round: 1
Reviewed against: `.docs/spec/06-init-modes.md` (full, for internal consistency);
authority/consistency targets `greenfield.md` (Step C),
`docs-layout.md` (Seeds), `.docs/spec/01-concepts.md`; amendment commit `ebb1b07`.

## Findings

- [MINOR] The bullet's example list ("a phase / next-step marker pointing at the
  first owner step") is illustrative via "e.g.", which is appropriate — the body
  (`greenfield.md` Step C) holds the concrete seed values. No change required;
  noted only so a future reader doesn't mistake the example for an exhaustive
  contract. — §1, first bullet.

## Required changes (for FAIL)

None.

## Notes

The amendment resolves a real defect: the prior wording — seed `status/` "(empty
roadmap, progress, handoff)" — read literally implied zero-byte files, which
directly contradicted the Greenfield body it governs. `greenfield.md` Step C
seeds `progress.md` with `Phase: init / Greenfield scaffold complete`,
`handoff.md` with "start here" instructions plus the next step "Declare scope
with the owner and run `/loom:run`", and `roadmap.md` with "Start with the
milestones the owner names." These are non-empty scaffold seeds. The reworded
bullet now authorizes exactly that: "no project decisions, only scaffold metadata
(e.g. a phase / next-step marker pointing at the first owner step)," and pins the
intended meaning with "'Empty' here means no prior design/project content, not a
zero-byte file." The example tracks the body's actual seed values precisely.

Consistency checks:
- vs `greenfield.md` — the reworded bullet authorizes Step C's seeds and
  contradicts nothing else in the body. Step B ("No spec bodies authored") and
  Step F ("does not author any design artifact") are reinforced, not loosened.
- vs `docs-layout.md` Seeds and `.docs/spec/01-concepts.md` — both describe
  status/ files by role/fields and do not constrain seeding in a way the new
  wording violates.
- vs §2 (Unaligned: "Seed `status/` with current state and an initial roadmap")
  — the reworded §1 is explicitly scoped to Greenfield and does not touch or
  conflict with the distinct Unaligned seeding.

Scope discipline: the change does NOT expand scope. It does not authorize design
decisions in Greenfield — it explicitly forbids "project decisions" in the seed,
keeping faith with §1's "Begin with the owner" sequencing. The diff is genuinely a
single-bullet edit; §2, §3, Detection, Gate establishment, and Playbook
re-application are untouched. No collateral drift. The new wording cleanly
distinguishes "no design content" from "zero bytes" without introducing a fresh
ambiguity.
