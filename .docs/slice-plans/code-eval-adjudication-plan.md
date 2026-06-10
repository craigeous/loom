# Code-Evaluator Adjudicates Advisory Review Findings (Slice C)

Status: In Progress
Target specs: 02-roles.md (Code Evaluator), 04-orchestrator.md (context only)

## Context

ADR 0010 (Accepted) added an orchestrator-run automated review (`/review` +
`/security-review`) to loom's code-review phase. Its output reaches the **blind
code-evaluator** as a committed, identity-neutral **review-findings artifact**
(`.docs/evaluations/<slice-name>-review-findings.md`). Spec
[`02-roles.md`](../spec/02-roles.md) (Approved/frozen) was amended to record this:
the Code Evaluator's **Reads** list now includes the review-findings artifact, and
its behavior now includes **"Adjudicates the review findings (ADR 0010)"** — the
findings are advisory input, not an oracle or auto-FAIL; the evaluator
confirms/rejects each, maps confirmed ones to severity, discards false positives
with a recorded reason, and **still owns the verdict** with
[`references/severity.md`](../../plugins/loom/skills/loom-playbook/references/severity.md)
as the single verdict authority.

**Slice A landed** the artifact *format*:
[`references/review-findings.md`](../../plugins/loom/skills/loom-playbook/references/review-findings.md)
is the single source for the artifact's shape and its four canonical per-command
status tokens (`ran-with-findings`, `ran-clean`, `skipped: docs-only`,
`skipped: command-unavailable`).

This slice (**C**) brings the **code-evaluator's playbook** into line with the
amended spec 02. Two files only:

1. [`references/code-eval-rubric.md`](../../plugins/loom/skills/loom-playbook/references/code-eval-rubric.md)
   — gains the **adjudication procedure** (this rubric is its single-source home).
2. [`agents/code-evaluator.md`](../../plugins/loom/agents/code-evaluator.md) — gains
   the **review-findings artifact in its input list** plus a one-line **pointer** to
   the rubric's adjudication procedure.

### Authority (cite, do not restate)

- **Frozen-spec authority:** [`02-roles.md`](../spec/02-roles.md) Code Evaluator
  section — the amended `Reads` list (review-findings artifact) and the "Adjudicates
  the review findings (ADR 0010)" behavior. The playbook must match this; the spec
  wins on any conflict.
- **Decision authority:** [ADR 0010](../ADR/0010-orchestrator-run-automated-review-in-code-eval.md)
  §4 — findings are advisory, the evaluator confirms/rejects/maps/discards, and
  `severity.md` remains the single verdict authority.
- **Artifact format:** [`references/review-findings.md`](../../plugins/loom/skills/loom-playbook/references/review-findings.md)
  (Slice A) — owns the artifact's shape and the four status tokens. **Point to it;
  do not restate.**
- **Verdict authority:** [`references/severity.md`](../../plugins/loom/skills/loom-playbook/references/severity.md)
  — the single source for severity tagging and PASS/FAIL. **Point to it; do not
  restate.**

### Single-source boundary (load-bearing)

- The **rubric** owns the adjudication *procedure*.
- The **agent prompt** only adds the artifact to its input list and **points** (one
  or two lines) to the rubric's procedure — it does not restate the procedure.
- Both files **point** to `review-findings.md` for the artifact *format* and
  `severity.md` for verdict authority — they restate neither. In particular, do not
  re-list the four status tokens or re-explain the severity ladder in either file.

### Out of scope (do not touch)

- [`references/orchestration.md`](../../plugins/loom/skills/loom-playbook/references/orchestration.md)
  — **Slice B, running in PARALLEL** with this slice
  (`orchestration-review-step-plan.md`). It must stay **untouched** so the two
  slices' file sets are disjoint.
- [`references/review-findings.md`](../../plugins/loom/skills/loom-playbook/references/review-findings.md)
  — Slice A; reference only, no edit.
- `SKILL.md`, any `spec/` or `ADR/` file (frozen; planner-only and not in this
  slice), the slice-plans `README.md` index, the living docs in `.docs/status/`,
  and `CLAUDE.md`.

## Steps

### Step 1 — Add the adjudication procedure to `code-eval-rubric.md`

In
`plugins/loom/skills/loom-playbook/references/code-eval-rubric.md`, add a **new
titled section** for the review-findings adjudication. Place it **after the
"Correctness" section and before "Hygiene"** (adjudication is a correctness-adjacent
judgment that precedes hygiene/playbook-conformance), so the file reads: Gate →
Fidelity → Correctness → **Review-findings adjudication** → Hygiene → Re-review.

The section must, in the rubric's existing terse imperative voice:

1. Establish the framing: the review-findings artifact (from `/review` +
   `/security-review`, produced by the orchestrator per ADR 0010) is **advisory
   input, not an oracle and not an auto-FAIL**. Point to
   [`review-findings.md`](review-findings.md) for the artifact's shape and statuses
   — **do not restate** the format or list the status tokens.
2. State the procedure as explicit steps:
   - **Confirm or reject** each reported finding against the diff, plan, and specs.
   - For each **confirmed** finding, **map it to severity per
     [`severity.md`](severity.md)** (point, don't restate the ladder); the verdict
     then follows mechanically from the evaluator's own severity-tagged findings —
     exactly as for any other finding.
   - **Discard false positives** with a **recorded one-line reason** in the eval
     file. (Note the rationale briefly: `/review` scores confidence and explicitly
     expects false positives, so an unadjudicated finding must not auto-decide a
     landing.)
3. State the verdict-ownership invariant: the **evaluator still owns the verdict**;
   [`severity.md`](severity.md) remains the **single verdict authority**. The
   findings do not add or override a verdict path.
4. State the skip/clean note: a `skipped: docs-only` or `skipped: command-unavailable`
   status is **informational, not itself a finding** — there is nothing to
   adjudicate when the review did not run, and a skip must not be read as a clean
   review. (Point to `review-findings.md` for what the tokens mean; do not restate
   the table.)

Sketch of the section to add (wording may be refined; structure and pointers are
load-bearing):

```markdown
## Review-findings adjudication

The orchestrator hands you a **review-findings artifact**
(`evaluations/<slice-name>-review-findings.md`, from `/review` + `/security-review`
— [ADR 0010](...)) as an additional input. It is **advisory input, not an oracle and
not an auto-FAIL.** See [`review-findings.md`](review-findings.md) for its shape and
statuses — don't restate them here.

- **Confirm or reject** each reported finding against the diff, plan, and specs.
- For each **confirmed** finding, tag it to severity per
  [`severity.md`](severity.md); the verdict follows from your own severity-tagged
  findings, like any other.
- **Discard false positives** with a one-line reason recorded in the eval file
  (`/review` scores confidence and expects false positives — an unadjudicated
  finding must not decide a landing).
- You **still own the verdict** — `severity.md` is the single verdict authority; the
  findings add a dimension, not a verdict path.
- A `skipped:`/`ran-clean` status is **informational**; a skip is not itself a
  finding and is never a clean review.
```

Keep the section short — it is a procedure pointer-set, not a re-derivation of
`severity.md` or `review-findings.md`.

### Step 2 — Add the artifact to the agent's inputs + a pointer to the rubric

In `plugins/loom/agents/code-evaluator.md`, make two minimal, voice-consistent
edits. **Do not** restate the adjudication procedure here — the rubric (Step 1) owns
it.

2a. **Inputs.** In the **"How you work" step 1** (where the evaluator is told to read
the diff, slice-plan, and target specs), add the **review-findings artifact**
(`.docs/evaluations/<slice-name>-review-findings.md`) to the list of inputs it reads,
alongside the diff, slice-plan, specs, and gate evidence. Match the spec 02 Reads
list: the artifact is an *additional* input. Keep it identity-neutral framing —
consistent with the existing "## The blind contract" section (the artifact names no
author).

2b. **Pointer to the procedure.** In **step 3** (the "judge against the rubric" step,
which already lists the rubric's checks), add a short clause directing the evaluator
to **adjudicate the review findings per the rubric** — pointing to
`code-eval-rubric.md`'s adjudication procedure, **without restating it**. One or two
lines: e.g. "adjudicate the review-findings artifact (confirm/reject each finding,
map confirmed ones to severity, discard false positives) per the rubric's
review-findings adjudication section." The phrase "you still own the verdict;
`severity.md` is the single verdict authority" may be echoed in one short clause if
it fits the voice, but the *procedure* stays in the rubric.

Use the agent's existing reference idiom for paths
(`${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/references/code-eval-rubric.md`), as the
file already does for the rubric and `severity.md`.

## Verification

This is a **pure-markdown** slice — there is **no `format → lint → test` gate**. The
acceptance check is the **blind code-eval's fidelity/consistency review**, performed
mechanically (`rg`/`test -e`), confirming the two files match the amended spec 02 and
respect the single-source boundary. Concretely:

1. **Only the two in-scope files changed.** The diff touches
   `references/code-eval-rubric.md` and `agents/code-evaluator.md` **only** — no
   `orchestration.md` (Slice B), no `review-findings.md`, no `SKILL.md`, no
   `spec/`/`ADR/`, no slice-plans `README.md`, no living docs, no `CLAUDE.md`.
   - `git diff --name-only <base>..HEAD` lists exactly those two files.

2. **Rubric has the adjudication section, in order.**
   - `rg -n "## Review-findings adjudication" plugins/loom/skills/loom-playbook/references/code-eval-rubric.md`
     returns one match.
   - The section sits **after "## Correctness" and before "## Hygiene"** — confirm
     by line order in `rg -n "^## " plugins/loom/skills/loom-playbook/references/code-eval-rubric.md`.

3. **Rubric points, doesn't restate.** The adjudication section links both
   `review-findings.md` and `severity.md` and uses the advisory framing.
   - `rg -n "review-findings.md|severity.md|advisory|confirm or reject|false positive|own the verdict" plugins/loom/skills/loom-playbook/references/code-eval-rubric.md`
     shows the pointers and the four procedure beats.
   - **Negative check (no token re-listing):** the rubric does **not** re-list the
     status-token table — `rg -n "ran-with-findings|ran-clean|skipped: command-unavailable" plugins/loom/skills/loom-playbook/references/code-eval-rubric.md`
     ideally returns nothing (a single illustrative mention of `skipped`/`ran-clean`
     in the informational-note line is acceptable; the four-token *table* must not be
     reproduced).

4. **Agent inputs include the artifact.**
   - `rg -n "review-findings" plugins/loom/agents/code-evaluator.md` returns at least
     one match in the "How you work" inputs area (step 1).
   - `rg -n "adjudicat" plugins/loom/agents/code-evaluator.md` returns a match in
     step 3 (the pointer to the rubric).

5. **Agent points, doesn't restate the procedure.** The agent's adjudication mention
   is one or two lines that defer to the rubric — it does **not** reproduce the
   confirm/reject/map/discard procedure in full. Confirm by reading the changed
   lines: the procedure body lives only in the rubric.
   - `test -e plugins/loom/skills/loom-playbook/references/code-eval-rubric.md` and
     the agent references it by the `${CLAUDE_PLUGIN_ROOT}/...` idiom:
     `rg -n "code-eval-rubric.md" plugins/loom/agents/code-evaluator.md`.

6. **Spec fidelity.** Read `02-roles.md` Code Evaluator section and confirm the two
   files now reflect both the amended **Reads** (review-findings artifact) and the
   **"Adjudicates the review findings"** behavior, with `severity.md` named as the
   single verdict authority and the findings framed advisory (not auto-FAIL).

7. **Commit is author-neutral and single-slice** per
   [`commit-convention.md`](../../plugins/loom/skills/loom-playbook/references/commit-convention.md):
   `git show -s --format='%an <%ae>'` is the configured identity, **not**
   `*@localhost`.

## Notes

(none)
