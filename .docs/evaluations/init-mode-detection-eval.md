# Evaluation: init-mode-detection

Verdict: PASS
Round: 1
Reviewed against: `.docs/spec/06-init-modes.md` (detection sketch + three modes),
`.docs/spec/README.md` (frozen-spec / no-spec-edit rules), `.docs/status/roadmap.md`
(M2 scope), `.docs/spec/03-artifact-lifecycle.md` (status machine, markdown verification),
`.docs/spec/08-playbook.md`, and the runtime files the plan touches
(`plugins/loom/commands/{run,init,status}.md`,
`plugins/loom/skills/loom-playbook/references/{orchestration,docs-layout}.md`,
`plugins/loom/skills/loom-playbook/SKILL.md`).

## Findings

- [MINOR] Step 1 header bullet (lines 56–59) is muddled: it instructs the author to
  write a purpose line, then mid-sentence redirects the path target
  ("the spec is `../../../../.docs/spec/...` — here, point to the managed-project
  equivalent `.docs/spec/06-init-modes.md`"). The intent (point at the spec by a
  resolvable relative path) is recoverable, but the literal text mixes an instruction
  to the author with the artifact content. The implementer should emit a clean purpose
  line and a single correct relative link to `06-init-modes.md`. Not a blocker — the
  Verification section's "Links resolve" check guards the outcome.
- [MINOR] The "empty/near-empty" allowlist (lines 74–81) introduces a concrete
  definition (`.git*`, `README*`, `LICENSE*`, `.editorconfig`, near-empty `CLAUDE.md`)
  that is a *reasonable disambiguation* of spec 06's undefined term but is a new
  judgment call not dictated by the spec. This is exactly the kind of precision the
  slice exists to add, and it is scoped to the playbook reference (not the spec), so it
  is acceptable. Flagged only so the implementer keeps it presented as "loom's operative
  definition of the spec term," not as if the spec itself enumerated the list.
- [MINOR] Step 4 (line 122) repoints `run.md` by editing a parenthetical
  "(see orchestration.md)" to "(run the classifier in `init-detection.md` via
  orchestration.md)". The current `run.md:19` text is `(see orchestration.md)` — the
  claim is accurate — but `run.md` keeps its own inline per-mode branch list
  ("greenfield → scaffold; unaligned → alignment pass; initialized → ..."), which is a
  *dispatch* sketch, not a *classification* restatement, so leaving it is consistent
  with the single-source-of-truth goal. No change required; noted so the implementer
  does not over-delete.

## Required changes (for FAIL)

None. (MINORs above are improvements, not gating.)

## Notes

Correctness & spec-fidelity: PASS. The classification procedure (lines 82–89) is a
faithful, logically-equivalent reordering of the spec-06 sketch. Spec 06 says
`no .docs/ and empty/near-empty → Greenfield`; `no .docs/ (or .docs/ not loom-shaped)
→ Unaligned`; `else → Initialized`. The plan's first-match form — loom-shaped →
Initialized, absent+empty → Greenfield, otherwise → Unaligned — partitions the input
space identically (present-but-not-loom-shaped and absent-but-non-empty both land in
Unaligned, matching the spec's "`.docs/` not loom-shaped" branch). The plan explicitly
documents this equivalence (lines 90–92). The "loom-shaped" marker set
(`spec/README.md`; `status/` with `roadmap.md`, `progress.md`, `handoff.md`) is a
faithful subset of the canonical tree in `docs-layout.md`, which the plan correctly
treats as the source it points at rather than something it edits.

No spec/ADR change is proposed. Non-goals (lines 43–49) explicitly exclude `.docs/spec/`
edits, new ADRs, per-mode behavior bodies, and edits to the `docs-layout.md` canonical
tree. The Verification section additionally guards this with a `git diff --name-only`
check confined to `references/`, `commands/`, and `slice-plans/`. This satisfies
ADR 0005 / spec README's frozen-spec rule.

Scope: PASS. Single coherent goal — make detection precise and single-sourced — sized
for one implement+review pass: add one reference file, repoint four call sites, one
conditional SKILL.md cross-link. The deferral of per-mode behaviors to later M2 slices
is correct and matches the roadmap's M2 decomposition.

Soundness of current-state claims: VERIFIED. The four cited sites exist with the exact
quoted text (`run.md:19`, `init.md:12`, `status.md:12`,
`orchestration.md:28–44`); `grep -rn "near-empty\|loom-shaped\|empty/near-empty"
plugins/loom/` returns matches only in `status.md` and `orchestration.md` today, which
is what the slice removes/redirects; `init-detection.md` does not yet exist; SKILL.md
*does* enumerate the `references/` files (lines 43–48), so step 6's conditional
("if it enumerates them, add the entry") will fire and is correctly conditional.

Completeness & verification: PASS. Steps are numbered, file-scoped, and followable by an
independent reader. The plan correctly recognizes loom's own repo has no compiled gate
and that acceptance is by review against the spec (per CLAUDE.md), and it names concrete,
checkable acceptance criteria (spec fidelity, single-source grep, no-spec-edit diff, link
resolution, read-only guarantee, regression guard on the four call sites). This is the
right verification model for a markdown artifact.

Playbook conformance: PASS. The artifact carries a `Status:` line, lives in
`.docs/slice-plans/`, names its target specs, and follows the slice-plan shape.
The read-only guarantee for detection (lines 99–100, restated in Verification) is a
sound and necessary property given `/loom:status` must not mutate.
