# Evaluations

Blind verdicts authored by the **plan evaluator** and **code evaluator**. One file
per artifact reviewed, named to parallel the artifact:

```
slice-plans/native-result-thread.md  →  evaluations/native-result-thread-eval.md
spec/02-roles.md                     →  evaluations/02-roles-eval.md
```

Keeping verdicts here (rather than inline in the artifact) keeps work files clean
and verdicts scannable. The artifact's own `## Notes` section is for *clarification
requests* between roles; the eval file is the *verdict*.

Verdicts are **blind**: the evaluator never sees author identity or author
reasoning — only the artifact and the authority it's judged against. Format and the
PASS/FAIL + severity rules are in
[../spec/05-blind-evaluation.md](../spec/05-blind-evaluation.md).

## Current program evaluations

- [macOS dogfood program amendment](macos-dogfood-program-amendment-eval.md) —
  planner-owned frozen-spec/program set; degraded bootstrap provenance until its
  protected publication settles.
- [ADR 0024 ratification](0024-macos-first-dual-client-dogfood-bootstrap-amendment-eval.md)
  and [owner acceptance](0024-macos-first-dual-client-dogfood-bootstrap-amendment-acceptance.md)
  — immutable authority for the private Apple-silicon checkpoint.
- [ci-baseline](ci-baseline-eval.md) and
  [review findings](ci-baseline-review-findings.md) — landed M0 evidence.
- [macOS dual-client dogfood plan](macos-dual-client-dogfood-plan-eval.md) —
  plan evaluation history (Approved).
- [macOS dual-client dogfood review findings](macos-dual-client-dogfood-review-findings.md)
  — bootstrap review — three cold auxiliary workers (correctness/tests/security),
  loom-repository-bootstrap/v1 degraded, not loom-local-review/v1 (ADR 0023 §3) —
  findings feeding the blind code-evaluator as advisory input.
- [macOS dual-client dogfood code evaluation](macos-dual-client-dogfood-eval.md) —
  FAIL round 0 (harness injection-coverage + cleanup hardening) → fix → resolving
  PASS round 0; `Ready to Publish` pending ADR-0023 settlement.
- [coord-identifier-boundaries plan evaluation](coord-identifier-boundaries-plan-eval.md)
  — FAIL round 0 (slice-name grammar over-restriction breaking SC1/V5b) → revised →
  Approved.
- [coord-identifier-boundaries review findings](coord-identifier-boundaries-review-findings.md)
  — bootstrap review — three cold auxiliary workers (correctness/tests/security),
  loom-repository-bootstrap/v1 degraded, not loom-local-review/v1 (ADR 0023 §3) —
  4 MINOR findings (T1-T4: secondary call-site test-coverage gaps + a NEG-ID doc
  miscount), no BLOCKER/MAJOR.
- [coord-identifier-boundaries code evaluation](coord-identifier-boundaries-eval.md) —
  PASS round 0 (M1 slice 1); all four review findings adjudicated CONFIRMED MINOR,
  non-blocking; `Ready to Publish` pending ADR-0023 settlement.
- [ADR 0025 reconciliation-authority plan evaluation](0025-reconciliation-authority-eval.md)
  — `bootstrap-ratification: degraded`; PASS round 0 with three MINOR folded,
  resolving PASS; advisory only.
- [ADR 0025 reconciliation-authority owner acceptance](0025-reconciliation-authority-acceptance.md)
  — dispositive owner gate, Accepted 2026-07-25.
- [ADR 0026 plugin prompt/doc scope plan evaluation](0026-docs-governance-plugin-prompt-doc-scope-eval.md)
  — `bootstrap-ratification: degraded`; PASS round 0 with the frontmatter
  carve-out MINOR folded in, resolving PASS; advisory only.
- [ADR 0026 plugin prompt/doc scope owner acceptance](0026-docs-governance-plugin-prompt-doc-scope-acceptance.md)
  — dispositive owner gate, Accepted 2026-07-25.

See also [`../status/progress.md`](../status/progress.md) § "M0 errata" — the
record-keeping reconciliation of four early-stretch process deviations found by the
2026-07-24 program-design and implementation-audit reviews (non-uniform commit
identity, a merge commit, a PR-vs-`remote-direct` publication-mode mismatch, and an
incomplete ci-baseline evidence set).

All other files in this directory remain durable historical verdicts and are not
rewritten when a later decision supersedes their subject.
- [`precompact-per-session-plan-eval.md`](precompact-per-session-plan-eval.md) — `precompact-per-session` slice-plan evaluation (Round 1: PASS)
- [`precompact-per-session-eval.md`](precompact-per-session-eval.md) — `precompact-per-session` code evaluation (Round 0: PASS)
- [`role-governance-guardrails-plan-eval.md`](role-governance-guardrails-plan-eval.md) — `role-governance-guardrails` slice-plan evaluation (Round 0: FAIL; split into focused slices)
- [`model-matrix-and-dynamic-discovery-plan-eval.md`](model-matrix-and-dynamic-discovery-plan-eval.md) — `model-matrix-and-dynamic-discovery` slice-plan evaluation (Round 2: PASS)
- [`0027-client-model-matrix-modernization-and-ambient-inheritance-eval.md`](0027-client-model-matrix-modernization-and-ambient-inheritance-eval.md) — ADR 0027 plan evaluation (Round 1: PASS)
- [`model-matrix-and-dynamic-discovery-eval.md`](model-matrix-and-dynamic-discovery-eval.md) — `model-matrix-and-dynamic-discovery` code evaluation (Round 1: PASS)
- [`role-governance-guard-plan-eval.md`](role-governance-guard-plan-eval.md) — `role-governance-guard` slice-plan evaluation (Round 1: PASS)
- [`role-governance-guard-eval.md`](role-governance-guard-eval.md) — `role-governance-guard` code evaluation (Round 2: PASS)
- [`remote-first-integration-candidate-plan-eval.md`](remote-first-integration-candidate-plan-eval.md) — `remote-first-integration-candidate` slice-plan evaluation (Round 0: PASS)
- [`remote-first-integration-candidate-eval.md`](remote-first-integration-candidate-eval.md) — `remote-first-integration-candidate` code evaluation (Round 2: PASS)
- [`coordination-state-separation-plan-eval.md`](coordination-state-separation-plan-eval.md) — `coordination-state-separation` slice-plan evaluation (Round 2: PASS)
- [`coordination-state-separation-eval.md`](coordination-state-separation-eval.md) — `coordination-state-separation` code evaluation (Round 1: PASS)
- [`identity-guard-contract-plan-eval.md`](identity-guard-contract-plan-eval.md) — `identity-guard-contract` slice-plan evaluation (Round 3: PASS)
- [`identity-guard-contract-eval.md`](identity-guard-contract-eval.md) — `identity-guard-contract` code evaluation (Round 2: PASS)
- [`local-review-helper-plan-eval.md`](local-review-helper-plan-eval.md) — `local-review-helper` slice-plan evaluation (Round 2: PASS)
- [`local-review-helper-eval.md`](local-review-helper-eval.md) — `local-review-helper` code evaluation (Round 1: PASS)
- [`local-review-agents-plan-eval.md`](local-review-agents-plan-eval.md) — `local-review-agents` slice-plan evaluation (Round 0: PASS)
- [`local-review-agents-eval.md`](local-review-agents-eval.md) — `local-review-agents` code evaluation (Round 0: PASS)
- [`local-review-orchestration-plan-eval.md`](local-review-orchestration-plan-eval.md) — `local-review-orchestration` slice-plan evaluation (Round 0: PASS)
- [`local-review-orchestration-eval.md`](local-review-orchestration-eval.md) — `local-review-orchestration` code evaluation (Round 0: PASS)
