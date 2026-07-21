# Evaluation: 0022 — Controlled-Input Independent Evaluation and Its Isolation Boundary

Verdict: FAIL
Round: 1
Reviewed against: repository improvement plan M5; approved dual-platform architecture research M5 impact; ADRs 0003, 0004, 0018, and 0021; plan-evaluation rubric, tooling guidance, and severity rules.

## Findings

- [BLOCKER] Decision §2 weakens M5's explicit acceptance criterion that evaluators
  can rerun the gate. It permits rerun only when every build/cache/temp write can be
  redirected and otherwise substitutes pre-recorded evidence or an `unsupported`
  classification. Ordinary gates write beside source, so a conforming implementation
  could satisfy this ADR while failing the program authority. A read-only judgment copy
  does not require abandoning rerun: the design needs a separate disposable, writable,
  hash-bound gate execution tree or an equally concrete mechanism.
- [MAJOR] The plan/research allowlist does not specify how current-tree evidence and
  external cited sources are captured with freshness/provenance. The plan-evaluation
  rubric requires mechanical checks of asserted invariants, and research review requires
  sources to resolve and support claims. Supplying only the artifact, cited/upstream
  authority, rubric, and prior verdict/diff is ambiguous when the claim is about uncited
  current files or a live external source while evaluator network tools are denied.

## Required changes (for FAIL)

1. Preserve M5's gate-rerun requirement by defining a sanitized writable gate workspace
   derived from and verified against the exact read-only source input; keep all resulting
   writes outside the judgment source and repository.
2. Add deterministic, hashed current-tree evidence and captured external-source inputs
   (with retrieval provenance/freshness) whenever the rubric requires them, while still
   excluding unrelated repository and identity context.

## Notes

The narrower trust claim, no-self-approval rule, explicit residual limitations,
deterministic recorder, per-run hashing, and adapter canary obligations correctly
replace ADR 0004's overclaim. This is a fresh review; the first FAIL is Round 1.

