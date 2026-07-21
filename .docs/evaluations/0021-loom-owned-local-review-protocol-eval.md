# Evaluation: 0021 — Loom-Owned Local Review Protocol

Verdict: FAIL
Round: 1
Reviewed against: repository improvement plan M4; approved dual-platform architecture research M4 impact; accepted ADR 0018; ADRs 0010, 0011, and 0017; plan-evaluation rubric and severity rules.

## Findings

- [BLOCKER] Decision §4 and the Consequences introduce three new cold finder
  "roles" and "role assets," contradicting accepted ADR 0018's explicit invariant that
  Loom has exactly five logical roles and that a future role/hierarchy change requires
  a new ADR. The M4 authority asks for reviewer agents, not expansion of Loom's logical
  lifecycle-role set. As written, adapters cannot implement both decisions without
  silently choosing whether finders count as roles.
- [BLOCKER] The claimed partial supersession of ADR 0017 conflates
  infrastructure-degraded execution with command unavailability. ADR 0017 does not
  permit a failed/degraded run to terminate as `skipped: command-unavailable`; it makes
  that run invalid, pauses, and requires rerun (or an honest non-run meanwhile). The
  availability skip being removed originates in ADR 0010 §7 and is preserved by ADR
  0011. Mis-scoping this replacement against immutable ADR 0017 creates two readings of
  the required failure path.

## Required changes (for FAIL)

1. Define correctness/tests/security finders as protocol workers or reviewer agents
   outside ADR 0018's five logical roles, and use that terminology consistently; or
   explicitly supersede ADR 0018 and reconcile the hierarchy/model-policy contract.
2. Scope the unavailable-command replacement to ADR 0010/0011. State that ADR 0017's
   infrastructure-degraded invalid/pause/rerun rule is preserved without describing it
   as an allowance for a terminal unavailable skip.

## Notes

The exact-SHA, versioned manifest/result, fail-closed aggregate, deterministic
validation, advisory findings, evaluator-owned verdict, and prompt/protocol versioning
otherwise satisfy M4. This is a fresh review; the first FAIL is Round 1.

