# Review-Findings Artifact Format

The review-findings artifact is the single, committed, identity-neutral record
that carries `/review` and `/security-review` output **from the orchestrator to
the blind code-evaluator**, as an additional input alongside the commit diff,
slice-plan, specs, and gate evidence.

**Authority:**
[ADR 0010](../../../../../.docs/ADR/0010-orchestrator-run-automated-review-in-code-eval.md)
(the governing decision), spec
[04](../../../../../.docs/spec/04-orchestrator.md) §"Automated review before a
slice lands" (the orchestrator's run step — Slice B scope), and spec
[02](../../../../../.docs/spec/02-roles.md) (Code Evaluator). The orchestrator —
not the code-evaluator — produces this artifact because **only the orchestrator may
spawn**, and a sub-agent cannot safely run a command that may spawn; see
[ADR 0001](../../../../../.docs/ADR/0001-plugin-architecture-and-orchestrator.md).

This file owns the artifact **format** only. It **points to**, not restates:

- the orchestrator's run procedure → spec 04 § "Automated review before a slice
  lands" (and Slice B's `references/orchestration.md` update when landed); and
- the evaluator's adjudication procedure → `severity.md` + `code-eval-rubric.md`
  (Slice C scope).

---

## Location and naming

```
.docs/evaluations/<slice-name>-review-findings.md
```

This is a **per-slice companion** to `.docs/evaluations/<slice-name>-eval.md` in
the same `evaluations/` namespace, distinct from the evaluator's own verdict file.

Under worktree parallelism it is **branch-local and uniquely named** — one file
per slice, so it never collides across concurrent branches — consistent with
[`parallelism.md`](parallelism.md) (slice-branch-local, uniquely-named files per
[ADR 0010](../../../../../.docs/ADR/0010-orchestrator-run-automated-review-in-code-eval.md)
§2 / [ADR 0008](../../../../../.docs/ADR/0008-parallel-docs-coordination-worktree-per-slice.md)).

It is **committed author-neutral** per [`commit-convention.md`](commit-convention.md).

*When* the orchestrator writes and commits it in the driver loop is spec 04 scope
(Slice B) — point there, not here.

---

## Identity-neutral content — a hard invariant

**The review-findings artifact is identity-neutral.** This is an invariant, not a
guideline.

The artifact **records findings only** — it names **no author**, carries **no
GitHub PR metadata, no PR number/owner, no SHAs used as identity**, and **nothing
that would leak authorship** into the blind evaluator. The orchestrator scrubs any
incidental identity before handing it over (ADR 0010 §3).

Authority: [ADR 0004](../../../../../.docs/ADR/0004-blind-evaluation-role-separation.md)
(the blind contract) and
[ADR 0010](../../../../../.docs/ADR/0010-orchestrator-run-automated-review-in-code-eval.md)
§3.

---

## Required status field — per command

The artifact records an **explicit, machine- and human-distinguishable status for
each command**. `/review` and `/security-review` run independently and may have
different outcomes.

The status uses a literal `Status:` line per command with exactly these tokens
(ADR 0010 §2, §5, §7):

| Token | Meaning |
|---|---|
| `ran-with-findings` | Command ran; at least one finding recorded below. |
| `ran-clean` | Command ran; no findings. |
| `skipped: docs-only` | Pure-docs slice — review not applicable (ADR 0010 §5). |
| `skipped: command-unavailable` | Built-in not available in this environment (ADR 0010 §7). |

**Rule: a skip is never confusable with a clean review.** `ran-clean` means the
command ran and found nothing; the two `skipped:` tokens mean the command did not
run. The two skip reasons are distinguishable from each other by their distinct
tokens (`skipped: docs-only` vs `skipped: command-unavailable`).

---

## Finding entry fields

Each finding entry is terse and advisory — it is input the evaluator adjudicates,
not a verdict. A single entry contains:

- **source command** — `/review` or `/security-review`;
- **location** — file path and line range, drawn from the slice diff;
- **description** — a short statement of the issue;
- **confidence signal** — the command's confidence score or label **if the command
  emits one** (e.g. `/review` scores confidence and explicitly expects false
  positives — ADR 0010 §4); omit if the command emits none.

---

## Adjudication — boundary pointer

The evaluator treats findings as **advisory input, not auto-FAIL**; it confirms or
rejects each against the diff, plan, and specs, and maps confirmed findings to
severity per [`severity.md`](severity.md) — the single verdict authority. See
[`severity.md`](severity.md) and [`code-eval-rubric.md`](code-eval-rubric.md) for
the adjudication procedure (confirm/reject/discard steps and severity mapping).

**This file owns the artifact format; the rubric owns the adjudication procedure.**

---

## Illustrative skeleton

The skeleton below is **illustrative** — it shows the required structural elements,
not a full schema.

```markdown
# Review findings — <slice-name>

## /review
Status: ran-clean

## /security-review
Status: ran-with-findings

### Finding 1
- source: /security-review
- location: src/handler.rs:42-58
- description: User-supplied input passed to shell command without sanitisation.
- confidence: high
```

Alternatively, for a pure-docs slice both commands carry the same skip status:

```markdown
# Review findings — <slice-name>

## /review
Status: skipped: docs-only

## /security-review
Status: skipped: docs-only
```

These two skeletons together demonstrate all four distinguishable states (the full
set of four tokens is specified in the Required status field section above).
