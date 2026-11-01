# Living Document Shape

Status: Implemented
Target specs: 03-artifact-lifecycle.md, 08-playbook.md
Target size: <= 250 LOC net change (keep this plan document <= 250 lines)

## Context

M6 asks for mechanically checked ownership and size boundaries for the living
status documents and consistency with README status. The existing `--all` docs
state validator checks lifecycle metadata and headings, but does not enforce this
shape. The handoff is below 150 lines yet contains old landing summaries; the
roadmap still marks `docs-state-validator` incomplete despite the handoff and
archived plan recording its landing. Preserve historical information while making
restart state and the current milestone easy to find.

## Out of Scope & Threat-Model Boundary

No spec amendments, doctor changes, release or publication changes, or attempt to
prove the semantic truth of arbitrary prose. Rules check a documented structural
contract, not whether every sentence belongs in its proper document. The trusted
repository and local execution boundary remains that of spec 00 Non-goals: no
OS-level hostile-code containment or proof of independent reasoning. Existing
lifecycle and link validation remain authoritative and must not be weakened.

## Steps

1. In `.docs/status/handoff.md`, retain only actionable restart instructions,
   current milestone/state, blockers and next action under `## Start here each
   session` and `## Where things stand`; remove obsolete session summaries. Move
   removed history without loss to `.docs/status/archive/handoff-history.md`,
   appending to the existing archive and retaining a link to it. Keep at most 150
   physical lines, counting a final unterminated line and blank lines. No exemption
   is introduced by this slice.
2. In `.docs/status/progress.md`, retain history and add `## Action history` with
   at least one standard entry `- YYYY-MM-DD — <action>`; migrate existing action
   summaries into that section without deleting historical detail. In
   `.docs/status/roadmap.md`, preserve milestone and future-work information,
   move historical narrative to progress where needed, and mark the already landed
   `docs-state-validator` checkbox complete. Keep `## Repository improvement
   program (2026)` as the milestone list. Do not claim this slice landed before
   remote verification.
3. Establish one exact `Current milestone: M<N>` line in each of `README.md`,
   `.docs/status/handoff.md`, `.docs/status/progress.md`, and
   `.docs/status/roadmap.md`, using the same milestone identifier. Place the
   roadmap line immediately before its program list and use M6 for the current
   state. The roadmap program list must contain exactly one unchecked milestone
   marked `(in progress)` whose `M<N>` equals that line; completed earlier and
   future unchecked milestones may remain. These fields are synchronization
   markers, not evidence of a slice's landing.
4. In `scripts/validate-repository.mjs`, call a living-document validator from
   `validateDocsState()` under `--all`, using `readText`, `ruleReport`, and the
   existing Markdown heading parser. Require the three living documents and root
   README, exactly one matching milestone marker in each, exactly one matching
   in-progress roadmap milestone, the two handoff headings above, `## Action
   history` with a nonempty standard dated entry, and the roadmap program heading.
   Reject handoff over 150 lines with a path-specific diagnostic. Apply these
   checks to regular repository fixtures as well as the real root; missing files,
   missing/duplicate markers or headings, malformed action entries, and mismatched
   milestones fail closed. Leave `--metadata` and `--links` behavior unchanged;
   do not add a rule exception for the cap.
5. In `scripts/tests/repository-validation.bats`, update the docs-state fixture to
   supply compliant living docs and README markers. Add focused cases for a passing
   fixture, 150 versus 151 lines (including no trailing newline), missing each
   required heading/file and action entry, duplicate/malformed markers, mismatch
   among all four documents, missing/duplicate in-progress roadmap milestones,
   and unchanged `--metadata`/`--links` behavior. Assert nonzero exit and
   path-specific diagnostics for each failure; preserve existing regression tests.

## Verification

Run the targeted Bats cases with the pinned Node setup used by the repository,
then the complete `scripts/check` gate (format, lint, tests). Run
`node scripts/validate-repository.mjs --root . --all` on the resulting tree.
Confirm the archive retains moved text, the handoff is at most 150 lines, the
markers match the roadmap, and the implementation stays within 250 net changed
lines. The Bats boundary and negative cases prove the mechanical contract; a human
review must assess whether the remaining prose respects each document's ownership.

## Notes

None.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |
