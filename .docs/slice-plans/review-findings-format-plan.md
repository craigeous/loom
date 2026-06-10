# Review-findings artifact format reference (ADR 0010 Slice A)

Status: In Progress
Target specs: 04-orchestrator.md (§ "Automated review before a slice lands"), 02-roles.md (Code Evaluator)

## Context

ADR 0010 (Accepted) added orchestrator-run automated review to loom's code-review
phase: when a slice reaches `Implemented`, the orchestrator runs Claude Code's
built-in `/review` and `/security-review` on the slice's commit diff, captures the
output into a committed, identity-neutral, per-slice **findings artifact**, and
hands it to the blind code-evaluator as an additional input. Specs
[`04-orchestrator.md`](../spec/04-orchestrator.md) (§ "Automated review before a
slice lands") and [`02-roles.md`](../spec/02-roles.md) (Code Evaluator) are Approved
and now describe this. The playbook does not yet have a single authoritative
definition of the findings artifact's **format** — that is what this slice creates.

ADR 0010 §2 decided the location/naming (`.docs/evaluations/<slice-name>-review-findings.md`),
the committed-author-neutral-per-slice properties, and the requirement that the
artifact records a status distinguishable across **four states**
(ran-with-findings / ran-clean / skipped:docs-only / skipped:command-unavailable),
with a skip never confusable with a clean review — and explicitly left only the
artifact's **internal format/content layout** to this follow-on slice. ADR 0010 §4
decided findings are advisory and the evaluator adjudicates and owns the verdict via
[`severity.md`](../../plugins/loom/skills/loom-playbook/references/severity.md).

This is **Slice A** of three ADR 0010 follow-on playbook slices, and it lands first
because the other two reference it as their single-source dependency for the artifact
format:

- **Slice B** (later, not here): `references/orchestration.md` — the orchestrator's
  run/dispatch step that executes the commands and *writes* this artifact.
- **Slice C** (later, not here): `agents/code-evaluator.md` + `references/code-eval-rubric.md`
  — the code-evaluator's *reads* and the *adjudication procedure* (confirm/reject,
  map to severity, record discards).

**Single-source boundary (load-bearing).** This file owns the artifact **format**
only. It must **point to**, not restate:
- the orchestrator's *run procedure* (spec 04 / Slice B), and
- the evaluator's *adjudication procedure* (`severity.md` + `code-eval-rubric.md` /
  Slice C).

### In scope

- **New file** `plugins/loom/skills/loom-playbook/references/review-findings.md` —
  the single authoritative playbook definition of the review-findings artifact's format.
- **One References bullet** for it in `SKILL.md` (the `## References (references/)` list).

### Out of scope (do not touch in this slice)

- `references/orchestration.md` (Slice B), `agents/code-evaluator.md` and
  `references/code-eval-rubric.md` (Slice C).
- Any `spec/` or `ADR/` file (frozen; changed only by planning).
- `.docs/slice-plans/README.md` (the slice-plans index — orchestrator-owned).
- Any `.docs/status/` living doc (roadmap/progress/handoff — orchestrator-owned) and
  `CLAUDE.md` (developer finalize pass, not this plan).
- Restating the run procedure or the adjudication procedure (point, don't restate).

## Steps

### Step 1 — Create `plugins/loom/skills/loom-playbook/references/review-findings.md`

Author a new reference, matching the voice/shape of existing references
(`parallelism.md`, `migration-recipe.md`, `severity.md`): a one-paragraph purpose
header, then short titled sections, link to authority via relative paths. Cover
exactly the following, and nothing that belongs to Slice B or C.

1. **Purpose & authority.** State the artifact carries `/review` + `/security-review`
   output **from the orchestrator to the blind code-evaluator**, as an additional
   input alongside the commit diff, slice-plan, specs, and gate evidence. Cite
   [ADR 0010](../../../../../.docs/ADR/0010-orchestrator-run-automated-review-in-code-eval.md),
   spec [04](../../../../../.docs/spec/04-orchestrator.md) § "Automated review before
   a slice lands", and spec [02](../../../../../.docs/spec/02-roles.md) (Code
   Evaluator). Include **one sentence** on why the orchestrator (not the evaluator)
   produces it: only the orchestrator may spawn and a sub-agent cannot safely run a
   command that may spawn — cite
   [ADR 0001](../../../../../.docs/ADR/0001-plugin-architecture-and-orchestrator.md).
   (Verify the relative-path depth resolves from `references/` before relying on it —
   see Verification; existing references use the `../../../../../.docs/...` form.)

2. **Location & naming.** Fix the path `.docs/evaluations/<slice-name>-review-findings.md`,
   a **per-slice companion** to `<slice-name>-eval.md` in the same `evaluations/`
   namespace, distinct from the evaluator's own verdict file. State that under
   worktree parallelism it is **branch-local and uniquely named** (one per slice, so
   it never collides across branches) — consistent with
   [`parallelism.md`](parallelism.md) (slice-branch-local, uniquely-named files).
   State it is **committed author-neutral** per
   [`commit-convention.md`](commit-convention.md). Do **not** describe *when* the
   orchestrator writes/commits it in the driver loop — that is Slice B; point to
   spec 04 instead.

3. **Identity-neutral content rule (invariant).** State as an explicit invariant:
   the artifact **records findings only** — it names **no author**, carries **no
   GitHub PR metadata, no PR number/owner, no SHAs-used-as-identity**, and **nothing
   that would leak authorship** into the blind evaluator. Cite
   [ADR 0004](../../../../../.docs/ADR/0004-blind-evaluation-role-separation.md) and
   note the orchestrator scrubs any incidental identity before handing it over
   (ADR 0010 §3). Phrase it as a hard invariant ("the review-findings input is
   identity-neutral"), not a guideline.

4. **The required status field — per command.** Specify an **explicit, machine- and
   human-distinguishable status**, recorded **per command** (since `/review` and
   `/security-review` each run and may have different outcomes). The status must
   cover at least the four ADR 0010 §2 states:
   - `ran-with-findings`
   - `ran-clean` (ran, no findings)
   - `skipped: docs-only` (pure-docs slice — ADR 0010 §5)
   - `skipped: command-unavailable` (built-in not available — ADR 0010 §7)

   State the rule that a **skip is never confusable with a clean review**, and the
   **two skip reasons are distinguishable from each other**. Define a concrete,
   stable encoding (e.g. a literal `Status:` line per command using these exact
   tokens) so tooling and a human reader can always tell the states apart — this is
   the format decision ADR 0010 §2 deferred to this slice. Cite ADR 0010 §2, §5, §7.

5. **What a finding entry contains.** Define the fields of a single finding entry,
   kept terse and advisory:
   - **source command** — `/review` vs `/security-review`;
   - **location** — file path and line range, drawn from the slice diff;
   - **description** — a short statement of the issue;
   - **confidence signal** — the command's confidence score/label **if present**
     (`/review` scores confidence and expects false positives — ADR 0010 §4); omit
     if the command emits none.

   Keep the framing advisory — the entry is input the evaluator adjudicates, not a verdict.

6. **Adjudication pointer (boundary, do not restate).** State in **one or two
   sentences** that the evaluator treats findings as **advisory input, not auto-FAIL**;
   it confirms/rejects each against the diff/plan/specs and maps confirmed ones to
   severity per [`severity.md`](severity.md) — the **single verdict authority**.
   **Point** to `severity.md` and `code-eval-rubric.md` for the adjudication
   procedure; do **not** restate the confirm/reject/discard steps or the severity
   mapping here (that is Slice C's single-source home in the rubric). Make the
   boundary explicit in the prose: *this file owns the artifact format; the rubric
   owns the adjudication procedure.*

7. **Example / skeleton (terse, illustrative).** Include one small fenced skeleton of
   the artifact showing: a title/header line tying it to `<slice-name>`, the per-command
   `Status:` lines using the four-state tokens, and one or two example finding entries
   with the fields from item 5. Mark it **illustrative**. Keep it short — a dozen-ish
   lines, not an exhaustive schema.

   The skeleton must demonstrate the distinguishable-status rule concretely — e.g.
   show one command `ran-clean` and the other `ran-with-findings`, or a `skipped:`
   variant — so the four-state requirement is unmistakable from the example.

### Step 2 — Add the `SKILL.md` References bullet

In `plugins/loom/skills/loom-playbook/SKILL.md`, in the `## References (references/)`
list (the bulleted list beginning near line 41), add **one** bullet for
`review-findings.md`, matching the existing entry style (backticked filename + em-dash
+ a one-line description that names what it owns and cites ADR 0010). Place it in a
sensible position relative to the other code-review/eval entries (e.g. after
`code-eval-rubric.md`/`severity.md`, or grouped with the eval-phase references).

Example shape (wording to be finalized by the developer, kept consistent with
neighbors):

```
- `review-findings.md` — the format of the orchestrator-written, identity-neutral
  per-slice review-findings artifact (`/review` + `/security-review` output) the
  blind code-evaluator reads (ADR 0010); owns the artifact format, not the run or
  adjudication procedure.
```

Do **not** edit any other part of `SKILL.md`.

## Verification

This is a **pure-markdown slice** — the `format → lint → test` gate does **not**
apply. The acceptance check is the **blind code-evaluator's fidelity/consistency
review**, performed mechanically (not by eye) with `rg`-style cross-reference checks:

1. **File exists and is in scope.** Exactly two files change:
   `plugins/loom/skills/loom-playbook/references/review-findings.md` (new) and
   `plugins/loom/skills/loom-playbook/SKILL.md` (one added bullet). No `spec/`,
   `ADR/`, `slice-plans/README.md`, `status/`, `CLAUDE.md`, `orchestration.md`,
   `code-eval-rubric.md`, or `agents/code-evaluator.md` edits.
   - Mechanical check: `git diff --name-only` against the pre-slice commit lists only
     those two paths.

2. **Format fidelity to ADR 0010 + spec.** The reference fixes the path
   `.docs/evaluations/<slice-name>-review-findings.md`, the per-command status with all
   **four** distinguishable states (ran-with-findings / ran-clean / skipped:docs-only /
   skipped:command-unavailable), the identity-neutral invariant, and the finding-entry
   fields — and does not contradict spec 04's § "Automated review before a slice lands"
   or spec 02's Code Evaluator section.
   - Mechanical check: `rg -n "ran-with-findings|ran-clean|skipped" plugins/loom/skills/loom-playbook/references/review-findings.md`
     surfaces all four states; `rg -n "review-findings" plugins/loom/skills/loom-playbook/references/review-findings.md`
     confirms the decided path.

3. **Single-source boundary held.** The file **points to** `severity.md` /
   `code-eval-rubric.md` for adjudication and to spec 04 for the run step, and does
   **not** restate either procedure (no confirm/reject/discard steps, no severity
   mapping table, no driver-loop run sequence).
   - Mechanical check: `rg -n "severity.md|code-eval-rubric|04-orchestrator" plugins/loom/skills/loom-playbook/references/review-findings.md`
     confirms the pointers are present.

4. **Authority citations resolve.** ADR 0001/0004/0010, spec 04, spec 02,
   `severity.md`, `parallelism.md`, and `commit-convention.md` are cited, and every
   relative link resolves from `references/`.
   - Mechanical check: resolve each `](...)` target with `test -e` (or equivalent)
     relative to the file's directory; the existing references use the
     `../../../../../.docs/...` depth for `.docs/` targets and bare `name.md` for
     sibling references — match that.

5. **SKILL.md bullet present and well-formed.** `rg -n "review-findings.md"
   plugins/loom/skills/loom-playbook/SKILL.md` returns the new bullet, and it matches
   the surrounding bullet style.

## Notes

(none)
