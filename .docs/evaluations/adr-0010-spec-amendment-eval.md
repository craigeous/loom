# Evaluation: ADR 0010 spec amendment (spec 04 + spec 02)

Verdict: PASS
Round: 0
Reviewed against: ADR 0010 (Accepted), ADR 0001, ADR 0004, ADR 0005; references/severity.md, references/plan-eval-rubric.md; spec 03 (lifecycle consistency)

## Findings

No BLOCKER, MAJOR, or MINOR findings.

The amendment (commit `d5623d6`, diffed against parent `bc87b26`) is a faithful,
minimal, in-scope fold of ADR 0010 into the two frozen specs it names.

### Faithfulness to ADR 0010 — spec 04 (`## Automated review before a slice lands`)

Every ADR 0010 decision in scope for spec 04 is present and accurate:

- **§1 actor/timing/rationale** — orchestrator (never the code-evaluator) runs
  built-in `/review` + `/security-review` on the slice's commit **diff** when it
  reaches `Implemented`, before/while dispatching the evaluator and **before the
  slice can land**, because only the orchestrator may spawn (ADR 0001) and a
  sub-agent cannot safely run a command that may spawn. Captured verbatim in intent.
- **§1 mode** — "Local diff mode only … Never PR / `--comment` / `--fix` … no
  GitHub round-trip, no PR metadata, no working-tree mutation." Faithful.
- **§2 artifact** — committed, author-neutral, identity-scrubbed, per-slice file
  `.docs/evaluations/<slice-name>-review-findings.md`, named as the `-eval.md`
  companion, handed to the blind evaluator as an additional input. The filename
  matches the ADR's decided convention exactly (verified by `rg`: ADR line 93 vs
  spec 04 line 63).
- **§2/§5/§7 distinguishable status** — the four states (ran-with-findings /
  ran-clean / skipped: docs-only / skipped: command unavailable) are reproduced,
  with "a skip is never confusable with a clean review" and "never silently
  claiming clean." Faithful.
- **§5 applicability** — runs only when the diff touches ≥1 code (non-docs) file;
  pure-docs slices skip-with-a-note. Faithful.
- **§8 gate relationship** — stated as a "new, separate review dimension — **not**
  part of the `format → lint → test` gate, which is unchanged." The gate language
  is not weakened anywhere.

### Faithfulness to ADR 0010 — spec 02 (Code Evaluator)

- **Reads** now includes the orchestrator's `evaluations/<name>-review-findings.md`
  artifact (cited to ADR 0010), alongside the unchanged commit-diff / slice-plan /
  specs / gate-evidence inputs, and preserves the "never receives author identity"
  clause.
- **Adjudication behavior** added: the findings are advisory input, **not an oracle
  or auto-FAIL**; the evaluator confirms or rejects each finding against diff/plan/
  specs, maps confirmed findings to `references/severity.md`, discards false
  positives with a recorded one-line reason, **still owns the verdict**, and
  `severity.md` remains the single verdict authority. Matches ADR §4 point-for-point.

### Blind contract (ADR 0004) intact

No identity-leak path is introduced. The amendment is explicitly local-diff-only,
the findings artifact is identity-neutral/author-neutral, and there is no GitHub
round-trip — each stated in spec 04 and cross-linked to ADR 0004. The Code
Evaluator's "never receives author identity" guarantee is retained unchanged.

### Minimal and in-scope

- Only the two ADR-named specs changed (`git show --name-only d5623d6` → exactly
  `02-roles.md`, `04-orchestrator.md`).
- Within each, only the intended section and the `Status:` line changed; no
  unrelated role, section, or sentence was touched.
- **Spec 03 is untouched** and nothing in the amendment required a spec-03 change:
  spec 03 already defines `Implemented → (code review) → Landed` with *code review*
  as a **phase, not a status** (spec 03 lines 62–66). The new review runs inside
  that existing phase, so **no new `Status:` value is introduced** — consistent with
  ADR 0010 §8 / Consequences ("no status-machine status change"). Verified by `rg`:
  the only new token is the artifact filename, no new `Status:` literal.
- This is the ADR 0005 planner-authored, blind-evaluated frozen-spec amendment
  cycle the ADR Consequences call for — the legitimate channel for changing a frozen
  spec.

### Consistency

Cross-references resolve mechanically: ADR 0010/0001/0004 and
`references/severity.md` all exist at the linked paths. The new text contradicts
neither spec 03's lifecycle, spec 05's blind-evaluation model (preserved), nor the
remainder of spec 02/04.

## Required changes (for FAIL)

None — this is a PASS.

## Notes

ADR 0010 content deliberately *not* restated in the specs — §6 (cost acknowledged)
and §7's "imposed on managed projects like the gate" — is ADR rationale/operational
framing rather than spec-level behavior the amendment must carry. Its omission does
not contradict the ADR and is appropriate minimalism, not a defect.

Per the invocation, both specs are left at `Status: Plan Review`. This is an
owner-gated frozen-spec change: the orchestrator presents this PASS to the owner,
who re-approves (flips the status). The evaluator does not flip status here.
