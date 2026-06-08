# Evaluation: 07 — Command Surface

Verdict: PASS
Round: 1
Reviewed against: the built command files `plugins/loom/commands/*.md`
(run, research, plan, eval-plan, develop, eval-code, status, init); the built
agents `plugins/loom/agents/*.md`; ADRs 0001 (plugin/orchestrator), 0002
(model tiers), 0006 (self-marketplace namespacing); sibling Approved specs 02
(roles), 04 (orchestrator); and spec 10 (packaging).

## Findings

- [MINOR] The header asserts namespacing was "confirmed empirically at M1
  install"; this is an unverifiable provenance claim in the artifact. It is
  consistent with spec 10's "OQ-D resolved, empirically", so it is not drift,
  but the spec carries no link to that evidence. — line 7; optional.
- [MINOR] `/loom:plan` is listed with no argument while the built `plan.md`
  declares `argument-hint: [what to plan]`. The argument is optional, so the
  bare form is valid usage and not a contradiction — but the table could note
  the optional `[what to plan]` for parity with the other rows. — line 18.

## Required changes (for FAIL)

None — PASS.

## Notes

Fidelity check (the core of this review): the spec's command list, names,
namespacing, and per-command behavior were checked against the real tree.

- Command set: the spec lists exactly 8 commands (run, research, plan,
  eval-plan, develop, eval-code, status, init). `plugins/loom/commands/`
  contains exactly those 8 files — no extras, no omissions. Each surfaces as
  `/loom:<filename>` as the spec states.
- Behavior: every "What it does" cell matches the body of its command file
  (orchestrator/driver-loop for run; one-off single-pass + stop for the others;
  status is read-only, no agents/writes; init detects mode and scaffolds/aligns).
- Blind evaluators: eval-plan.md and eval-code.md both gather blind inputs only
  and pass no author/identity hint — matches the spec's "blind" labels and
  ADR 0004 / spec 05.
- Namespacing: no bare `/loom` appears anywhere; commands are `/loom:<name>`,
  agents `loom:<role>`. Matches ADR 0001/0006 and spec 10. The "plugin" (not
  "skill") framing is correct — the playbook is a bundled skill, the product is
  a plugin.
- Agents: the spec names 5 agents with tiers researcher(haiku),
  planner(opus), plan-evaluator(opus), developer(sonnet), code-evaluator(opus).
  Verified against each agent file's frontmatter — all 5 exist with exactly
  those tiers (ADR 0002, spec 02).
- Shared logic: the spec points commands at
  `skills/loom-playbook/references/orchestration.md` (+ `status-machine.md`);
  both files exist and `run.md` reads exactly those two. Consistent.
- Sibling/packaging consistency: spec 04's "One-off invocation" and spec 10's
  "Command surface" enumerate the identical surface and cross-reference 07;
  no contradiction.

No BLOCKER or MAJOR findings. The spec is an accurate, internally coherent
description of the shipped command surface.
