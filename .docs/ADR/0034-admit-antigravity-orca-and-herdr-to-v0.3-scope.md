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
  - *ADR 0032 §6 work-list disposition:* Pins floor `1.4.12` in `v0.3.0.json`; binds E1 matrix
    profile mappings to `agy models` (`Economy` -> `gemini-3.8-flash-low`, `Standard` ->
    `gemini-4-argon-medium`, `Deep review` -> `gemini-4-argon-high`); provides E2 binding
    `antigravity-plugin-root-v1.json`; specifies and verifies role-isolation and role-governance
    properties against ADR 0022 (blocking git mutation for evaluators); expands offline Bats
    tests for stubbed `agy`, below-floor refusal, and rotation; restores Antigravity to default
    evaluator rotation once v0.3.0 E1–E5 evidence is recorded; amends Specs 02, 07, and 10 to
    reflect supported status.
- **Orca (`orca`):** floor `1.4.250`, host adapter `plugins/loom/bin/loom-host-orca`, descriptor `orca-host/v1`.
  - *ADR 0032 §6 work-list disposition:* Implements concrete terminal counterpart primitives
    (terminal create, send, wait, read, close) and worktree isolation in `loom-host-orca`
    matching verified CLI behavior; decides host adapter artifact `plugins/loom/bin/loom-host-orca`
    with E1 matrix entry and E2 descriptor `orca-host-v1.json`; pins floor `1.4.250`; confirms
    Orca-hosted blind evaluation satisfies ADR 0022 by dispatching evaluators to independent
    `0700` POSIX scratch workspaces rather than Orca terminals; adds offline Bats tests against
    stubbed `orca` CLI covering usage and below-floor refusal; executes live runs per E4 and
    obtains owner sign-off per E5.
- **Herdr (`hc`):** floor `0.1.16`, host adapter `plugins/loom/bin/loom-host-hc`, descriptor `hc-host/v1`.
  - *ADR 0032 §6 work-list disposition:* Delivers host adapter `plugins/loom/bin/loom-host-hc`
    (create, get, list, stop, clean) and E2 descriptor `hc-host-v1.json`, replacing stale
    `herdr-plugin-root` in `v0.3.0.json`; confirms Herdr plugin surface retirement (`herdr-surface-retirement`,
    landed `1bed05f`) and evaluator `hc` guard (`hc-guard-deny-policy`, landed `7da94f2`);
    adds offline Bats tests against stubbed `hc` covering usage and below-floor refusal; executes
    owner-run live probes (`hc-live-probe.md`); completes live runs per E4 and owner sign-off per E5.

Versions below these floors or unknown binaries fail closed (`exit 2`) at launch.

### 2. Evaluator Governance and Narrow Supersession of Host Supported Definition

ADR 0031 §5 recognized that `hc` cannot enforce blind evaluation isolation because processes running
under the same user account have shared access to terminal buffers, labels, and local IPC.
Consequently, ADR 0032 §5 noted that because E4 required every role through the harness under test,
Herdr could not become a supported pair while `hc` evaluators remained prohibited.

ADR 0034 resolves this conflict through a **narrow supersession of ADR 0032 §3 and §5 for host harnesses**:
1. **`hc` evaluators remain strictly prohibited:** ADR 0031 §5's prohibition is **reaffirmed and retained**.
   No `plan-evaluator` or `code-evaluator` session shall run as an `hc` terminal or be dispatched through `hc`.
2. **Surviving live-probe gate:** The live `hc` probe requirements of ADR 0031 §6 remain in force;
   no role is launched via `hc` until the probe suite completes and records clean receipts.
3. **Narrow supersession of host supported definition (supersedes ADR 0032 §3 and §5 for hosts):**
   For a host harness (`herdr` or `orca`), the harness is **supported** when:
   - The host adapter correctly creates, observes, communicates with, and cleans up host sessions/terminals.
   - Interactive and authoring roles (researcher, planner, developer) execute successfully within the host.
   - Evaluator roles (`plan-evaluator`, `code-evaluator`) are delegated to independent, sanitized
     POSIX evaluation workspaces (`0700` scratch directories per [ADR 0022](0022-controlled-input-independent-evaluation.md))
     executed by certified model CLI clients (`codex` or `claude`), outside the host terminal tree and
     without inheriting host session handles or IPC environment variables.
   - The full development loop (research → plan → plan-eval → develop → code-eval → finalize)
     completes end-to-end starting from a host session.
   - This supersedes ADR 0032 §5's sentence *"Since E4 requires every role, Herdr cannot be a supported
     pair until that is resolved"*, permitting Herdr to achieve supported status with secure evaluator delegation.
4. **Honest threat-model boundary:** Consistent with [ADR 0022](0022-controlled-input-independent-evaluation.md)
   and [ADR 0017](0017-infrastructure-blocked-escalation.md), Loom acknowledges that evaluator process
   separation and sanitized input export do not constitute an OS kernel-level sandbox against malicious
   local inode tampering under the same UID.

### 3. Model-Family-Aware Cross-Family Evaluation Rotation

To satisfy [ADR 0004](0004-blind-evaluation-role-separation.md) and [ADR 0032](0032-release-client-mapping-and-retirement-of-dogfood-tier.md) §6,
cross-family evaluation MUST inspect the **underlying model provider family**, not solely client names:

- **Model Provider Families:**
  - `anthropic`: Claude Code CLI, Claude models via Antigravity (`claude-*`).
  - `openai`: Codex CLI (`gpt-6*`), OpenAI models.
  - `google`: Gemini models via Antigravity (`gemini-*`).
  - `oss`: Open-weights models via Antigravity (`gpt-oss-*`).
- **Deterministic Resolution & Fail-Closed Invariant:**
  - The launcher MUST deterministically resolve **both** the author's model family (`authorFamily`)
    and the evaluator's model family (`evaluatorFamily`).
  - If `authorFamily` cannot be deterministically resolved: fail closed (`exit 2`).
  - If `evaluatorFamily` cannot be deterministically resolved: fail closed (`exit 2`).
  - If `authorFamily == evaluatorFamily`: fail closed (`exit 2`).
- **Rotation Rules:**
  - If author is `claude` (`anthropic`), evaluator routes to `codex` (`openai`) or `agy` with Gemini (`google`).
  - If author is `codex` (`openai`), evaluator routes to `claude` (`anthropic`) or `agy` with Gemini (`google`).
  - If author is `antigravity` using Gemini (`google`), evaluator routes to `codex` (`openai`) or `claude` (`anthropic`).
  - If author is `antigravity` using Claude (`anthropic`), evaluator routes to `codex` (`openai`), never `claude`.

### 4. Actionable E1–E5 Conformance Plan

Each admitted pair must satisfy ADR 0032 §3 (E1–E5) before v0.3.0 is tagged:
- **E1 (Compatibility Matrix):** `adapters/compatibility/v0.3.0.json` defines all five pairs with
  pinned floors, allowed helpers, and role profile mappings.
- **E2 (Installed Root & Host Bindings):** Validated bindings created under `plugins/loom/adapters/roots/`:
  `claude-plugin-root-v1.json`, `codex-skill-source-v1.json`, `antigravity-plugin-root-v1.json`,
  `orca-host-v1.json`, and `hc-host-v1.json`.
- **E3 (Automated Repository Gate):** Full local gate (`scripts/check`) passes cleanly under both
  macOS Bash 3.2.57 and Bash 5.3+, with comprehensive offline Bats test coverage for all five harnesses
  including parity, guards, and fail-closed refusal of unknown/below-floor versions.
- **E4 (Live Conformance Evidence):** Live executions on macOS 14+ Apple silicon for each pair at
  its pinned floor: clean install/load, interactive role execution, full development loop (with
  evaluators dispatched to isolated `0700` workspaces per §2), and dual-platform gate passing.
- **E5 (Release Evidence Record):** Evidence record `.docs/evaluations/release-evidence/v0.3.0.json`
  conforming to `loom-release-evidence/v1`, validated by `scripts/validate-repository.mjs --release 0.3.0`,
  bearing explicit owner acknowledgement and sign-off, published to `origin/main` atomically with
  the release tag `v0.3.0`.

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
  pinned floors, bindings, and complete E1–E5 criteria.
- ADR 0033 §1's blanket deferrals are superseded.
- ADR 0032 §3 and §5 are narrowly superseded for host harnesses, defining supported host status
  as interactive host execution paired with isolated evaluator delegation, resolving the circular
  Herdr evidence blocker while preserving ADR 0031 §5's prohibition on `hc` evaluators.
- Cross-family evaluation enforces model provider family separation (`google` vs `anthropic` vs
  `openai`), failing closed if either author or evaluator family cannot be deterministically resolved.
- Follow-on work: Un-shelve `.docs/slice-plans/hc-host-adapter.md` and begin Slice 1 implementation.
