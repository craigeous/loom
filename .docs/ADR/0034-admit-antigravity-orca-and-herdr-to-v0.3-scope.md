# 0034 — Admit Antigravity, Orca, and Herdr (hc) to the v0.3.0 Scope and Settle Evaluator Governance

Status: Plan Review
Date: 2026-11-08

## Context

[ADR 0032](0032-release-client-mapping-and-retirement-of-dogfood-tier.md) (Accepted),
grounded in the approved [repository improvement plan](../repository-improvement-plan.md),
defined a release table whose v0.3.0 row required five macOS Apple-silicon harnesses:
Claude Code CLI, Codex CLI, Antigravity, Orca, and Herdr (`hc`).

[ADR 0033](0033-narrow-v0.3-scope-and-retire-macos-checkpoint-tooling.md) (Accepted)
narrowed that blanket requirement: it prioritized the v0.2.0 live proof for the two shipped
clients (Claude Code CLI and Codex CLI), deferred Antigravity, Orca, and Herdr (`hc`), and
stipulated (§1) that any harness added to v0.3.0 must be admitted by a separate admission
ADR citing verified CLI behavior, a pinned floor, the ADR 0032 §6 work list, and an E1–E5
plan. Furthermore, ADR 0033 D4 deferred the Herdr/`hc` evaluator question until the v0.2.0
proof completed, holding `hc` evaluators prohibited under [ADR 0031](0031-herdr-as-an-hc-driven-client.md) §5.

The prerequisite work has completed:
1. Candidate `78a21fb9dd681912b6b0f866bba5d4d58a2b13c5` was tagged `v0.2.0` with full live
   release evidence recorded in `.docs/evaluations/release-evidence/v0.2.0.json` and published
   to `origin/main`.
2. The follow-on slice `codex-launch-schema-fix` removed `--output-schema` from `codex exec`,
   enabling un-wrapped native Codex role execution across all five roles.
3. Live command-line environments are present, authenticated, and verified on macOS 14+ Apple silicon:
   - **Orca (`orca`):** version `1.4.250` at `/Applications/Orca.app/Contents/Resources/bin/orca`,
     providing terminal and session lifecycle primitives (`terminal create/send/wait/close/list`).
   - **Herdr (`hc`):** version `0.1.16` at `/Users/craig/.local/bin/hc`, documented in
     [hc runtime reference](../research/2026-11-01-hc-agent-runtime-reference.md) and
     [Herdr client adapter contract](../research/2026-11-01-herdr-client-adapter-contract.md).
   - **Antigravity (`agy`):** version `1.4.12` at `/Users/craig/.local/bin/agy`, providing dynamic
     model discovery (`agy models`) per [ADR 0027](0027-client-model-matrix-modernization-and-ambient-inheritance.md).

The owner has directed the admission of Antigravity, Orca, and Herdr (`hc`) into Loom to enable
active development and workflow usage under Herdr and Orca.

## Decision

ADR 0034 admits Antigravity, Orca, and Herdr (`hc`) to the v0.3.0 release scope on macOS 14+
Apple silicon under the pair rule of ADR 0032 §1, superseding the deferrals in ADR 0033 §1.

### 1. Pinned Floors and Matrix Bindings

The v0.3.0 compatibility matrix (`plugins/loom/adapters/compatibility/v0.3.0.json`) binds:
- **Claude Code CLI (`claude`):** floor `2.1.216` (carried from v0.2.0).
- **Codex CLI (`codex`):** floor `0.144.6` (carried from v0.2.0).
- **Antigravity (`agy`):** pinned floor `1.4.12`.
- **Orca (`orca`):** pinned floor `1.4.250`.
- **Herdr (`hc`):** pinned floor `0.1.16`.

Versions below these floors or unknown binaries fail closed at launch.

### 2. Resolution of the Herdr/Orca Evaluator Governance Question

ADR 0031 §5 correctly observed that `hc` cannot enforce controlled-input blind evaluation
isolation ([ADR 0022](0022-controlled-input-independent-evaluation.md)) because processes under
the same user account can observe other terminal buffers and metadata.

This limitation is resolved by strictly separating **execution hosts** from **blind evaluators**:
1. Herdr (`hc`) and Orca (`orca`) are admitted as **development and execution hosts** for authoring
   and interactive roles (researcher, planner, developer).
2. Evaluator roles (`plan-evaluator`, `code-evaluator`) SHALL NOT execute as unconfined interactive
   sessions inside `hc` or `orca`.
3. When Loom runs under an `hc` or `orca` session, the orchestrator delegates evaluation roles to
   isolated, sanitized evaluation workspaces (`0700` scratch directories per ADR 0022) executed
   by certified model CLI clients (`codex` or `claude`).
4. This supersedes ADR 0031 §5's absolute ban on Herdr workflows: Herdr is authorized as an
   interactive host, while evaluator blindness and isolation remain cryptographically and
   mechanically preserved.

### 3. Enforced Cross-Family Evaluation Rotation

To satisfy [ADR 0004](0004-blind-evaluation-role-separation.md), [ADR 0027](0027-client-model-matrix-modernization-and-ambient-inheritance.md),
and [ADR 0032](0032-release-client-mapping-and-retirement-of-dogfood-tier.md) §6, no model family
may evaluate its own work:
- If the author client is `claude`, evaluation routes to `codex`.
- If the author client is `codex`, evaluation routes to `claude`.
- If the author client is `antigravity`, evaluation routes to `codex` (or `claude`).
- Any attempt to evaluate an artifact using the author's own model family fails closed (`exit 2`)
  in `loom-launch-role`.

### 4. Slicing Order for v0.3.0 Delivery

Work proceeds across four focused slices:
1. **Slice `hc-host-adapter`:** Un-shelve `.docs/slice-plans/hc-host-adapter.md`, implement
   `plugins/loom/bin/loom-host-hc` (create, list, get, wait, stop, clean), register v0.3.0 metadata,
   and add offline Bats test suite.
2. **Slice `orca-host-adapter`:** Implement `plugins/loom/bin/loom-host-orca` providing terminal
   lifecycle integration for Orca per Spec 07, with offline Bats test suite.
3. **Slice `antigravity-conformance`:** Update `v0.3.0.json` compatibility matrix, align
   `loom-launch-role` auto-rotation with `crossFamilyVerified: true`, and verify dynamic model resolution.
4. **Slice `v0.3.0-live-proof`:** Execute live probes across `hc`, `orca`, and `agy` on macOS Apple
   silicon, compile the `loom-release-evidence/v1` record, and verify the platform gate.

## Consequences

- Herdr (`hc`), Orca (`orca`), and Antigravity (`agy`) are formally admitted to the v0.3.0 milestone.
- The `hc` evaluator prohibition of ADR 0031 §5 is narrowed to forbid in-harness evaluation while
  authorizing `hc` as an interactive orchestrator and authoring host.
- The v0.3.0 release row on macOS 14+ Apple silicon requires all five harnesses to satisfy ADR 0032
  §3 (E1–E5) before v0.3.0 is tagged.
- Follow-on work: Un-shelve `hc-host-adapter.md`, advance it through evaluation, and implement
  `loom-host-hc`.
