# 0029 — Herdr Client Adapter and Native App Support

Status: Accepted
Extends: ADR 0018, ADR 0027
Date: 2026-11-01

## Context

Loom's dual-client foundation was established in ADR
[0018](0018-shared-core-and-client-adapters.md) (shared core with Claude and Codex
adapters) and extended in ADR
[0027](0027-client-model-matrix-modernization-and-ambient-inheritance.md) to support
ambient model inheritance and the internal Antigravity adapter.

Milestone M9 of the [repository improvement plan](../repository-improvement-plan.md)
introduces support for Herdr and its native desktop application. As documented in
[Herdr research](../research/2026-11-01-herdr-client-adapter-contract.md), Herdr is a
native agent workspace manager and terminal multiplexer running on macOS
(`/Applications/Herdr.app`, v0.1.10) backed by the headless `herdr-core` (`hc`)
runtime.

To enable Loom workflows and lifecycle roles to run natively within Herdr while
strictly preserving core portability, role governance, and uniform commit identity,
a formal client adapter contract is required.

## Decision

### 1. Authorize Herdr as a Supported Client Adapter

This ADR extends ADR 0018 and ADR 0027 by authorizing **Herdr** as a first-class
client adapter alongside Claude Code, Codex, and Antigravity.

### 2. Plugin Manifest and Marketplace Discovery

Herdr discovers Loom through standard plugin manifests:
- Manifest: `plugins/loom/.herdr-plugin/plugin.json` identifying plugin `loom`,
  version `0.2.0`, description, and skills directory.
- Marketplace metadata: `.herdr-plugin/marketplace.json` pointing to `./plugins/loom`.

### 3. Installed-Root Binding Contract

Herdr uses the `herdr-plugin-root/v1` schema specified in
`plugins/loom/adapters/roots/herdr-plugin-root-v1.json`:
- Environment variable: `HERDR_PLUGIN_ROOT`.
- Invariant enforcement: must be an absolute canonical path pointing to a directory
  containing `.herdr-plugin/plugin.json` naming `loom` version `0.2.0`.
- Helper allowlist: regular executable files in `bin/` restricted to `loom-coord`,
  `loom-verify-identity`, `loom-review`, `loom-eval-workspace`, `loom-doctor`, and
  `loom-profile`.

### 4. Compatibility Matrix Integration

`plugins/loom/adapters/compatibility/v0.3.0.json` is updated to include:
- `clientFloors.herdr`: `"0.1.10"`.
- Root binding: `{ "id": "herdr-plugin-root/v1", "path": "plugins/loom/adapters/roots/herdr-plugin-root-v1.json" }`.
- Profile mappings for Economy, Standard, and Deep review.

### 5. Helper Resolution and Role Launch Integration

- `plugins/loom/bin/loom-resolve-helper` supports `herdr <helper>`, resolving via
  `HERDR_PLUGIN_ROOT` fail-closed.
- `plugins/loom/bin/loom-launch-role` supports `herdr <role>`, launching cold roles
  with `delegation: false`, permissions `one-level`, `LOOM_ROLE=<role>`, and ambient
  model inheritance.

### 6. Native App Lifecycle and Event Hooks Contract

Herdr loads Loom's shared hook configuration through `plugins/loom/.herdr-plugin/plugin.json`
declaring `"hooks": "hooks/hooks.json"`. The hook process receives `HERDR_PLUGIN_ROOT` in its
environment, enabling the three shared hook scripts (`git-identity-guard.sh`,
`role-governance-guard.sh`, and `precompact-write-ahead-backstop.sh`) to resolve and validate
the root via `_loom_hook_select_client`.

Herdr uses standard POSIX process execution conventions for tool and compaction lifecycle hooks:
- Supported events: `PreToolUse` (evaluating `tool_input.command` on tool `Bash`) and `PreCompact`
  (evaluating `trigger` and `session_id`).
- Policy allows: exit code `0`, empty stdout and stderr.
- Policy blocks: exit code `2`, empty stdout, single-line message `<reason>\n` on stderr.

## Consequences

- Herdr users can run Loom workflows and roles natively within Herdr spaces and tabs.
- The shared core remains fully portable and neutral; all Herdr specifics reside in
  thin adapter manifests, schemas, and launch mappings.
- Non-delegation, cross-family evaluation, and uniform identity guards remain strictly
  enforced on all Herdr role invocations.
