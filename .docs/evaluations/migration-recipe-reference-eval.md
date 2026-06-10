# Evaluation: migration-recipe-reference

Verdict: PASS
Round: 0
Reviewed against: ADR 0009 §5 (load-bearing properties) + §7 (operational
preconditions); spec 06-init-modes.md §2b (target spec; "the recipe text is a
playbook reference… not spec text"); field report 2026-06-09-unaligned-init-
migration-field-report.md (§4, §5, Operational failures); gate-learning.md
(structural model) + SKILL.md (References list); plan-eval-rubric.md + severity.md.

## Findings

- [MINOR] Verification check F (`rg -nF -- '](X.md)'`) demands the literal
  `](X.md)` example string, while the plan's preamble says "Wording may be the
  author's." The example is itself load-bearing (it is ADR 0009 §5's own notation
  for the bare-markdown-link form), so the demand is defensible, but it sits in
  mild tension with the flexible-wording note. Consider phrasing the check around
  the *concept* (bare markdown link target) rather than the exact glyphs, or note
  that this literal is intentionally required. Does not block.

## Required changes (for FAIL)

None.

## Notes

The plan is executable and file-scoped. Each load-bearing property required by
the authority is mapped to a concrete recipe section with a `rg` verification:

- ADR 0009 §7 dirty-tree check → Step A.1 (with `git status --porcelain` /
  stash sketch) → check B.
- ADR 0009 §7 untracked `git mv`-skip → Step A.2 (`git ls-files --others`,
  `mv` + `git add` separately) → check B.
- ADR 0009 §7 NUL-delimited lists → Step A.3 (`-print0 | xargs -0`, `$(find …)`
  named as the anti-pattern) → check B.
- ADR 0009 §5 numbered-spine → `spec/` + `status/` split with two-directional
  rewrite → Step B (08/09/10 → status/, rest → spec/; numbering gaps accepted;
  same-dir → `../status/`, outbound → `../spec/`) → check C.
- ADR 0009 §5 ordered specific-before-generic → Step C → check D.
- ADR 0009 §5 idempotency / self-match `(?<!\.)` → Step D (`..docs/` artifact
  named; re-run no-op stated) → check E.
- ADR 0009 §5 three reference forms separately → Step E → check F.
- ADR 0009 §5 living-rewritten vs archived-snapshot boundary → Step F (archive
  excluded from rewrite passes) → check G.
- ADR 0009 §4 / spec 06 §2b status-preservation → Step G as a *pointer*, not a
  restatement → check H.
- Final link validation → Step H (concrete `rg` for un-rewritten `docs/` and
  `..docs/` artifacts) → check I.

Faithfulness / no over-reach confirmed: the recipe is positioned as the
mechanical "how" of the migrate path and explicitly declines to restate the owner
gate (ADR 0009 §3), the status-preservation *policy* (§4), and the
init-inline-vs-spawn division (§6), keeping those single-sourced in the frozen
spec / Accepted ADR. This matches spec 06 §2b's deferral of the recipe text to
the playbook.

Scope/hygiene confirmed: the out-of-scope list forbids edits to `.docs/spec/`,
`.docs/ADR/`, `references/unaligned.md`, and `references/init-detection.md`, with
a hard-fail scope guard (check L). The plan delivers only the new reference +
`SKILL.md` (+ plan + README), uses the standard template, carries
`Status: Plan Review`, targets spec 06, and the README Active entry is present
and accurate.

Mechanical checks verified against the real tree: the relative-link form
`../../../../../.docs/...` resolves correctly from
`plugins/loom/skills/loom-playbook/references/` to repo root (confirmed); the
sibling structural model `gate-learning.md` uses that exact form; the slice-1
landing (`c96fd90`) and its archived plan both exist as the Context claims; the
SKILL.md References list style (backtick-name + dash-description, no link) matches
the suggested entry. No compiled gate is correctly declared (markdown repo);
acceptance is review against authority plus the per-property `rg` checks.
