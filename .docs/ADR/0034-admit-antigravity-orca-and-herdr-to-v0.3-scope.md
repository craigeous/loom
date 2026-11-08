# 0034 — Admit Antigravity, Orca, and Herdr (hc) to the v0.3.0 Scope and Settle Evaluator Governance

Status: Plan Review
Date: 2026-11-08

## Context

[ADR 0032](0032-release-client-mapping-and-retirement-of-dogfood-tier.md) (Accepted),
grounded in the approved [repository improvement plan](../repository-improvement-plan.md),
fixed a release table whose v0.3.0 row required five macOS Apple-silicon harnesses:
Claude Code CLI, Codex CLI, Antigravity, Orca, and Herdr (`hc`).

[ADR 0033](0033-narrow-v0.3-scope-and-retire-macos-checkpoint-tooling.md) (Accepted)
narrowed that blanket requirement: it prioritized the v0.2.0 live proof for the two shipped
clients (Claude Code CLI and Codex CLI), deferred Antigravity, Orca, and Herdr (`hc`), and
stipulated (§1) that any harness added to v0.3.0 must be admitted by a separate admission
ADR citing verified CLI behavior, a pinned floor, the ADR 0032 §6 work list, and an E1–E5
plan. Furthermore, ADR 0033 D4 deferred the Herdr/`hc` evaluator question until the v0.2.0
proof completed, leaving `hc` evaluators prohibited under [ADR 0031](0031-herdr-as-an-hc-driven-client.md) §5.

The prerequisite conditions have now been satisfied:
1. Candidate `78a21fb9dd681912b6b0f866bba5d4d58a2b13c5` was tagged `v0.2.0` with full live
   release evidence recorded in `.docs/evaluations/release-evidence/v0.2.0.json` and published
   to `origin/main`.
2. Slice `codex-launch-schema-fix` removed `--output-schema` from `codex exec`, enabling
   un-wrapped native Codex role execution across all five roles.
3. Verified command-line environments and runtime research exist on macOS 14+ Apple silicon:
   - **Orca (`orca`):** version `1.4.250` at `/Applications/Orca.app/Contents/Resources/bin/orca`,
     researched in [Orca and Antigravity runtime reference](../research/2026-11-08-orca-and-antigravity-runtime-reference.md).
   - **Herdr (`hc`):** version `0.1.16` at `/Users/craig/.local/bin/hc`, researched in
     [hc runtime reference](../research/2026-11-01-hc-agent-runtime-reference.md) and
     [Herdr client adapter contract](../research/2026-11-01-herdr-client-adapter-contract.md).
   - **Antigravity (`agy`):** version `1.4.12` at `/Users/craig/.local/bin/agy`, researched in
     [Orca and Antigravity runtime reference](../research/2026-11-08-orca-and-antigravity-runtime-reference.md)
     and [ADR 0027](0027-client-model-matrix-modernization-and-ambient-inheritance.md).

The owner has directed the formal admission of Antigravity, Orca, and Herdr (`hc`) into Loom
to enable active development and workflow usage under Herdr and Orca.

## Decision

ADR 0034 admits Antigravity, Orca, and Herdr (`hc`) to the v0.3.0 release scope on macOS 14+
Apple silicon under the pair rule of ADR 0032 §1, superseding the deferrals in ADR 0033 §1.

### 1. Pinned Floors, Bindings, and ADR 0032 §6 Dispositions

The v0.3.0 compatibility matrix (`plugins/loom/adapters/compatibility/v0.3.0.json`) binds:
- **Claude Code CLI (`claude`):** floor `2.1.216`, client adapter `claude-plugin-root/v1`.
- **Codex CLI (`codex`):** floor `0.144.6`, client adapter `codex-skill-source/v1`.
- **Antigravity (`agy`):** floor `1.4.12`, client adapter `antigravity-plugin-root/v1`.
  - Disposes ADR 0032 §6 work list: pins `1.4.12`; binds matrix profile mappings from `agy models`
    (`Economy` -> `gemini-3.8-flash-low`, `Standard` -> `gemini-4-argon-medium`, `Deep review` -> `gemini-4-argon-high`);
    retains descriptor schema validation; restores Antigravity to the v0.3.0 matrix.
- **Orca (`orca`):** floor `1.4.250`, host adapter `plugins/loom/bin/loom-host-orca`, descriptor `orca-host/v1`.
  - Disposes ADR 0032 §6 work list: implements terminal and worktree counterpart primitives
    per Spec 07; pins `1.4.250`; introduces `loom-host-orca` helper and offline Bats test suite.
- **Herdr (`hc`):** floor `0.1.16`, host adapter `plugins/loom/bin/loom-host-hc`, descriptor `hc-host/v1`.
  - Disposes ADR 0032 §6 and ADR 0031 §7–§8: replaces stale `herdr-plugin-root` with `hc-host/v1`;
    implements `loom-host-hc` (create, get, list, stop, clean); verifies with offline Bats test suite.

Versions below these floors or unknown binaries fail closed (`exit 2`) at launch.

### 2. Evaluator Governance, Isolation Boundary, and ADR 0031 Clarification

ADR 0031 §5 recognized that `hc` cannot enforce blind evaluation isolation because processes running
under the same user account have shared access to terminal buffers, labels, and local IPC.
ADR 0034 clarifies the exact boundaries:

1. **`hc` evaluators remain strictly prohibited:** ADR 0031 §5's prohibition of `hc` evaluator roles
   is **NOT** lifted. No `plan-evaluator` or `code-evaluator` session shall run as an `hc` terminal
   or be dispatched through `hc`.
2. **Interactive host authorization:** Herdr (`hc`) is authorized strictly as an interactive
   orchestration and authoring host for human and non-evaluator roles (researcher, planner, developer).
3. **Evaluator process and filesystem isolation boundary:**
   - Evaluator roles triggered during an `hc` or `orca` session SHALL be dispatched directly to
     isolated, sanitized POSIX workspaces (`0700` scratch directories per [ADR 0022](0022-controlled-input-independent-evaluation.md)).
   - Evaluators execute as independent CLI processes (`codex exec` or `claude -p`) without
     inheriting `hc` terminal handles, `ORCA_*` session variables, or parent IPC channels.
   - Consistent with [ADR 0022](0022-controlled-input-independent-evaluation.md) and
     [ADR 0017](0017-infrastructure-blocked-escalation.md), Loom acknowledges honestly that this
     provides process and controlled-input separation, not an impenetrable OS kernel sandbox
     against malicious local tampering under the same UID.
4. **Surviving live-probe gate:** The live `hc` probe requirements of ADR 0031 §6 remain in force;
   no role is launched via `hc` until the probe suite completes and records clean receipts.

### 3. Model-Family-Aware Cross-Family Evaluation Rotation

To satisfy [ADR 0004](0004-blind-evaluation-role-separation.md) and [ADR 0032](0032-release-client-mapping-and-retirement-of-dogfood-tier.md) §6,
cross-family evaluation MUST inspect the **underlying model provider family**, not solely the
harness/client name:

- **Model Families:**
  - `anthropic`: Claude Code CLI, Claude models via Antigravity (`claude-*`).
  - `openai`: Codex CLI (`gpt-6*`), OpenAI models.
  - `google`: Gemini models via Antigravity (`gemini-*`).
  - `oss`: Open-weights models via Antigravity (`gpt-oss-*`).
- **Rotation Rules:**
  - `authorFamily != evaluatorFamily` is strictly enforced.
  - If author is `claude` (`anthropic`), evaluator routes to `codex` (`openai`) or `agy` with Gemini (`google`).
  - If author is `codex` (`openai`), evaluator routes to `claude` (`anthropic`) or `agy` with Gemini (`google`).
  - If author is `antigravity` using Gemini (`google`), evaluator routes to `codex` (`openai`) or `claude` (`anthropic`).
  - If author is `antigravity` using Claude (`anthropic`), evaluator routes to `codex` (`openai`), never `claude`.
  - If the author's underlying model family cannot be deterministically resolved, the launch fails closed (`exit 2`).

### 4. Actionable E1–E5 Conformance Plan

Per ADR 0032 §3, each admitted pair must satisfy E1–E5 before v0.3.0 can be tagged:
- **E1 (Compatibility Matrix):** `adapters/compatibility/v0.3.0.json` defines all five pairs with
  pinned floors, allowed helpers, and role profile mappings.
- **E2 (Installed Root & Host Bindings):** Bindings created and validated by JSON Schema:
  `antigravity-plugin-root-v1.json`, `orca-host-v1.json`, and `hc-host-v1.json`.
- **E3 (Automated Repository Gate):** Full repository gate (`scripts/check`) passes under both
  Bash 3.2.57 and Bash 5.3+, including offline Bats suites for `loom-host-hc`, `loom-host-orca`,
  and `agy` model resolution.
- **E4 (Live Conformance Evidence):** Live executions on macOS 14+ Apple silicon:
  - `hc`: clean daemon connectivity, terminal create, wait, read, close, and probe execution.
  - `orca`: terminal create, send, wait, read, and close within Orca runtime.
  - `agy`: model discovery, cold role execution, and verified cross-family evaluation.
- **E5 (Release Evidence Record):** Evidence compiled into `.docs/evaluations/release-evidence/v0.3.0.json`
  validated by `scripts/validate-repository.mjs --release 0.3.0`.

### 5. Implementation Slicing Sequence

1. **Slice `hc-host-adapter`:** Un-shelve `.docs/slice-plans/hc-host-adapter.md`, deliver
   `plugins/loom/bin/loom-host-hc` (create, list, get, wait, stop, clean), register v0.3.0 metadata,
   and pass offline Bats tests.
2. **Slice `orca-host-adapter`:** Deliver `plugins/loom/bin/loom-host-orca` providing terminal
   lifecycle integration for Orca, with offline Bats tests.
3. **Slice `antigravity-conformance`:** Update `v0.3.0.json`, implement model-family extraction
   and cross-family enforcement in `loom-launch-role`, and verify dynamic discovery caching.
4. **Slice `hc-live-probe`:** Un-shelve and execute `.docs/slice-plans/hc-live-probe.md`, recording
   live terminal and lifecycle evidence for Herdr.
5. **Slice `v0.3.0-live-proof`:** Run the complete five-harness live proof and assemble the
   v0.3.0 release evidence record.

## Consequences

- Antigravity, Orca, and Herdr (`hc`) are formally admitted to the v0.3.0 roadmap with explicit
  pinned floors, bindings, and E1–E5 criteria.
- ADR 0033 §1's blanket deferrals are superseded.
- ADR 0031 §5's prohibition on `hc` evaluators is explicitly preserved and clarified; `hc` is
  authorized solely as an authoring and development host.
- Cross-family evaluation is upgraded to enforce model provider family separation (`google` vs
  `anthropic` vs `openai`), preventing intra-family self-review under multi-model harnesses.
- Follow-on work: Un-shelve `.docs/slice-plans/hc-host-adapter.md` and begin Slice 1 implementation.
