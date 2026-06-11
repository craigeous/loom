# Evaluation: adr-0011-playbook-conformance-plan

Verdict: FAIL
Round: 1
Reviewed against: ADR 0011 (Accepted), spec 04-orchestrator.md § "Automated review
before a slice lands" (re-approved), spec 02-roles.md Code Evaluator, the current
plugin tree (`rg -n '/review\b' plugins/loom/`), plan-eval-rubric.md, severity.md.

## Findings

- [BLOCKER] Scope claim is mechanically false; the plan misses a fourth bare
  `/review` and excludes it on a false premise — Context (lines 26–28) asserts
  "every bare `/review` hit lives in the three files below" and the Out-of-scope
  block (line 34) lists `SKILL.md` among files to "not touch." A fresh
  `rg -n '/review\b' plugins/loom/` returns **four** files with bare `/review`:
  `orchestration.md`, `review-findings.md`, `code-eval-rubric.md`, **and
  `plugins/loom/skills/loom-playbook/SKILL.md:51`**. The SKILL.md hit is the same
  PR-bound `/review` that ADR 0011 declares factually wrong — it describes the
  review-findings artifact as carrying "(`/review` + `/security-review` output)",
  i.e. the identical automated-review command being corrected. The plan's stated
  goal (lines 19–20) is to "bring the **playbook references** into line with …
  ADR 0011"; SKILL.md is a playbook reference. Leaving it ships a stale,
  factually-wrong `/review` in the playbook's own entry file and produces an
  incompletely-conformant result. Per severity.md (scope / spec-fidelity violation
  ⇒ BLOCKER) and the rubric's "Invariants verified mechanically" item — the plan
  asserts an `rg`-checkable invariant that does not hold.

  Note: ADR 0011 §Consequences "Playbook follow-up" enumerates orchestration.md,
  review-findings.md, code-eval-rubric.md, and agents/code-evaluator.md and does not
  name SKILL.md. That could support a deliberate exclusion — but the plan does not
  rely on that rationale; it instead asserts (falsely) that no other occurrence
  exists. The plan must either (preferred) include the SKILL.md `/review`
  occurrence, or truthfully scope it out with the ADR-§Consequences rationale and
  correct the false "every bare `/review` … in the three files" claim and the
  verification checks that depend on it.

## Required changes (for FAIL)

1. Resolve the `SKILL.md:51` bare `/review`. Either (a) add a step swapping
   `SKILL.md:51` `/review` → `/code-review` (leaving `/security-review`) and update
   the file list, Context invariant, and Verification accordingly; or (b) if it is
   to remain out of scope per ADR 0011 §Consequences, state that explicitly as the
   rationale and remove/correct the false claim that "every bare `/review` hit lives
   in the three files below."
2. Correct the pre-state mechanical claim in Context (lines 26–28) so it matches the
   actual `rg -n '/review\b' plugins/loom/` output (four files, not three), and make
   Verification step (a) cover whichever files end up in scope.

## Notes

Everything else in the plan checks out and is strong; the only defect is the missed
fourth occurrence / inaccurate invariant.

- ADR-conformance of the core swap is correct: `/review` → `/code-review` leaving
  `/security-review`, plus the commit-range targeting bullet, both match ADR 0011 §1
  and §2 and the re-approved spec 04 (verified: spec 04 lines 51–53 name
  `/code-review`; lines 62–67 carry the "Target the slice's commit range" bullet
  citing ADR 0011 §2).
- Per-file steps are accurate against the real tree: orchestration.md authority
  (~63), run step (line 67), and the "Local diff mode only" bullet (~74–77) exist as
  described; code-eval-rubric.md hits at lines 40 and 51 are correct; the six
  review-findings.md sites (lines 4, 69, 94, 98, and the two `## /review` skeleton
  headings at 123 and 141) all verified.
- Safe-replacement reasoning is sound and confirmed: `/review` is not a substring of
  `/security-review` (no bare `/review` inside it), and `rg -n '/code-review'
  plugins/loom/` returns no pre-existing hits — a targeted swap cannot corrupt
  `/security-review`.
- `/security-review` baseline counts confirmed: orchestration.md=1,
  code-eval-rubric.md=1, review-findings.md=6 — matching the plan's stated post-swap
  invariant.
- `agents/code-evaluator.md` correctly excluded: `rg -n '/review\b'` on it returns
  no hits (exit 1), so omitting it is correct, not an omission.
- Pure-markdown / no `format → lint → test` gate observation is correct; the named
  mechanical verification checks (b)–(e) are appropriate. The lookaround caveat in
  check (a) (ripgrep here lacks PCRE2) is accurate; the count cross-check workaround
  is sound.
- No edits to specs/ADRs/index/living docs are proposed — scope discipline is
  otherwise respected.

<!--
Round 1: fresh artifact, first review is a FAIL ⇒ round advances 0 → 1.
-->
