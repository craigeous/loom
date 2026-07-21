# 01 — Concepts & `.docs/` Layout

Status: Draft

## Authority

ADRs [0003](../ADR/0003-cold-handoffs-commit-per-handoff.md),
[0005](../ADR/0005-specs-frozen-after-approval.md),
[0018](../ADR/0018-shared-core-and-client-adapters.md),
[0020](../ADR/0020-remote-publication-is-the-landing-authority.md), and
[0022](../ADR/0022-controlled-input-independent-evaluation.md).

## Managed-project memory

Every Loom-managed project commits this layout:

```text
.docs/
├── research/                 # cited inputs to planning
├── ADR/                      # numbered immutable decisions
├── spec/                     # authoritative intended design
├── slice-plans/
│   └── archive/              # landed or abandoned plans
├── evaluations/              # recorded verdicts and review-findings companions
└── status/
    ├── roadmap.md            # milestones and future work
    ├── progress.md           # chronological project history
    ├── handoff.md            # compact current restart state
    └── project-instructions.md # canonical client-neutral instruction digest
```

Loom dogfoods the same layout. Runtime coordination and per-run isolation data live
under the repository's common Git directory or fresh temporary roots, never as
undeclared tracked state.

## Artifact classes

| Artifact | Location | Durability | Producer | Acceptance/authority |
|---|---|---|---|---|
| Research | `research/` | reference | researcher | plan evaluator source check |
| ADR | `ADR/` | immutable after acceptance | planner | plan evaluator / owner |
| Spec | `spec/` | frozen after approval | planner | plan evaluator / owner |
| Slice-plan | `slice-plans/` | transient | planner | plan evaluator / owner |
| Review findings | `evaluations/*-review-findings.md` | evidence | deterministic assembler | advisory only |
| Evaluation | `evaluations/*-eval.md` | evidence | deterministic recorder | evaluator verdict |
| Living status | `status/` | living | deterministic/orchestrated finalization | operational, not design authority |
| Code | repository | durable | developer | code evaluator / owner, then remote publication |

The producing evaluator writes a verdict only inside its isolated run output. The
deterministic recorder validates and copies it into `.docs/evaluations/`; the
orchestrator makes the author-neutral handoff commit. The committed file remains the
durable evaluation artifact even though the evaluator has no checkout write access.

## Durable, transient, and living

- Accepted ADRs are historical decisions and are never rewritten. A later ADR may
  explicitly supersede part or all of one.
- Approved specs are frozen intended design. They re-enter `Plan Review` only in a
  planner-authored amendment cycle.
- Slice-plans are executable proposals for one small, vertically useful change.
  Landing archives them and updates living status; it does not modify specs.
- Status files answer operational questions. They cannot override a spec or ADR.
- `project-instructions.md` is living but canonical for generated instruction
  adapters. It summarizes existing authority and never creates new authority.

## Exact revisions and provenance

Any operation whose meaning depends on repository content records full object IDs,
not symbolic moving refs. Local review binds `base_sha` and `head_sha`; evaluation
binds its artifact/input hashes and, where applicable, `head_sha` and `evidence_sha`;
publication binds initial/final remote bases and candidate/result SHA. A dirty
checkout, local `main`, `origin/HEAD`, or a PR number is never an implicit substitute.

## Status as dispatcher

Gated artifacts carry one legal `Status:` token. The orchestrator combines those
tokens with validated coordination state, evaluation manifests, review-run state,
and remote publication receipts. A tracked status assertion alone cannot prove
`Landed`; the configured remote plus receipt is authoritative. See spec
[03](03-artifact-lifecycle.md).

## Isolation workspaces are not project artifacts

Local-review runs and evaluator exports are fresh per-run directories outside the
managed checkout. They exclude `.git`, credentials, transcripts, and unrelated
history; immutable inputs are read-only and outputs are confined to run-specific
directories. Disposable writable gate copies are destroyed after evidence is
recorded. Only validated normalized findings, verdicts, and receipts enter `.docs/`.

## Naming and linkage

- Evaluation: `.docs/evaluations/<artifact-name>-eval.md`.
- Local-review companion: `.docs/evaluations/<slice>-review-findings.md`.
- Active plan: `.docs/slice-plans/<slice>-plan.md`; archived plan retains its name.
- Every spec names accepted ADR authority; every slice-plan names target specs.
- Relative links must resolve in both active and archived locations and are checked
  by the documentation validator.
