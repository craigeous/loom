# Evaluation: CLAUDE.md auto-propagation amendment (specs 03 + 08)

Verdict: PASS
Round: 0
Reviewed against: `.docs/spec/03-artifact-lifecycle.md` and `.docs/spec/08-playbook.md` as amended by commit `56e1a8d`; authority = the three requirement points (who/when, curated-digest boundary, spec-freeze integrity), ADR `0005-specs-frozen-after-approval.md`, ADR `0008` (parallelism/finalize location), the rest of spec 03 (finalize steps, no-spec-edit rule, round limits), spec 08 (CLAUDE.md template bullet + Evolving the playbook), and `references/plan-eval-rubric.md` + `references/severity.md`.

## Findings

No BLOCKER or MAJOR findings. The amendment satisfies all three requirement points and preserves the spec freeze.

Requirement coverage (verified mechanically via `git show 56e1a8d` and `rg`):

- **Point 1 — who/when.** Both specs state the **developer's finalize pass** maintains `CLAUDE.md` alongside the living-doc updates when a slice lands (spec 03 finalize step 2, lines 73–81; spec 08 "Who and when", lines 74–79). The convention change and its `CLAUDE.md` reflection land together. Present and unambiguous.
- **Point 2 — curated-digest boundary.** Spec 08 (lines 80–99) gives four concrete inclusion categories (durable conventions, repo-layout facts, gate definitions, read-first pointers), each with an example, plus an **explicit per-slice-history exclusion** and a crisp per-slice decision rule ("if the only thing a slice produced is history … no `CLAUDE.md` edit"). Explicitly covers BOTH the root `CLAUDE.md` and the managed-project `CLAUDE.md`, with the boundary stated identical for both. Actionable.
- **Point 3 — spec-freeze integrity.** Spec 03's "**No spec edit happens at landing**" rule is fully intact (lines 84–87), and the new paragraph (lines 89–96) frames `CLAUDE.md` as a **derived, non-spec digest**, places its update "in the same category as updating the living docs," asserts `.docs/spec/` + `.docs/ADR/` "remain untouched at landing," and states "on any conflict, the specs win … it can never become a competing source of truth." ADR 0005 is unmodified (commit touches only the two spec files, confirmed via `--name-only`). No wording permits a developer to edit a spec or makes `CLAUDE.md` a competing source of truth.

Internal-consistency checks (all pass):

- **Finalize-step renumbering (spec 03)** is clean: steps run 1 → 2 → 3 with no duplicate or orphaned numbers, and the archive step is still present (now step 3, line 82). Verified with `rg -n "^[0-9]+\. "`.
- **No over-reach.** The diff changes nothing in the round-limit rule, the threshold (5), the status table, or other lifecycle rules; only the finalize pass (03) and "Evolving the playbook" (08) are touched.
- **Single-source split is correct.** Spec 03 defines the finalize *step* and cross-refs spec 08 for the *boundary* (line 80–81); spec 08 holds the authoritative boundary definition and cross-refs spec 03 for the *step* (line 78–79). They reinforce rather than contradict or wholly duplicate each other.
- **No contradiction with ADR 0008.** ADR 0008 line 206 already contemplates the finalize pass "legitimately edits content files such as the root `CLAUDE.md`," consistent with this amendment (the *where* — on main — is governed by 0008 and is unaffected).

- [MINOR] Spec 08's new subsection sits under "Evolving the playbook" and supersedes the former aspirational bullet, but the earlier "What the playbook contains" bullet (line 40–41, "`CLAUDE.md` template … plus guidance for root-level `CLAUDE.md`") still reads as a static inventory item. It is not contradictory — the new subsection is the mechanism, the inventory bullet is the artifact — but a one-clause forward-pointer from line 41 to the new subsection would aid navigation. Non-blocking.

## Required changes (for FAIL)

None — verdict is PASS.

## Notes

Both spec `Status:` lines correctly read `Plan Review` for this blind review (the freeze rule is satisfied: re-entering the planning cycle is exactly how a frozen spec changes per ADR 0005). The `Status:` lines were not modified by this evaluation.

This is the first evaluation of this artifact (no prior FAIL on file), so it is Round 0.
