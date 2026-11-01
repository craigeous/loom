# 0030 — Herdr Native App Lifecycle and Event Hooks

Status: Accepted
Extends: ADR 0003, ADR 0013, ADR 0018, ADR 0029
Date: 2026-11-01

## Context

Milestone M9 slice 1 established the Herdr client adapter foundation in ADR
[0029](0029-herdr-client-adapter-and-native-app-support.md).

To enforce Loom's uniform identity invariant (ADR
[0003](0003-cold-handoffs-commit-per-handoff.md)), role governance anti-drift
rules, and write-ahead compaction backstop (ADR
[0013](0013-starvation-loop-guards-cold-restart.md)) when running inside Herdr's
native desktop application (`/Applications/Herdr.app`, v0.1.10), a formal lifecycle
and event hook contract is required.

As researched in
[Herdr native app hooks research](../research/2026-11-01-herdr-native-app-hooks-contract.md),
Herdr discovers plugin hooks through directory manifests and executes hook processes
in an isolated environment with `HERDR_PLUGIN_ROOT`.

## Decision

### 1. Hook Manifest Declaration

`plugins/loom/.herdr-plugin/plugin.json` declares `"hooks": "hooks/hooks.json"`.
Repository validation in `scripts/validate-repository.mjs` verifies this declaration
alongside manifest identity and version fields.

### 2. Multi-Client Hook Dispatcher

`plugins/loom/hooks/hooks.json` commands resolve the hook executable path across all
three supported clients:
```json
"${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-${HERDR_PLUGIN_ROOT:-}}}/hooks/<script>.sh"
```
The description is updated to reflect three clients: Claude Code, Codex CLI, and Herdr.

### 3. Fail-Closed Root and Client Selection

In `git-identity-guard.sh`, `role-governance-guard.sh`, and
`precompact-write-ahead-backstop.sh`, `_loom_hook_select_client` validates
`HERDR_PLUGIN_ROOT` against `.herdr-plugin/plugin.json` (canonical physical
directory, `name == loom`, `version == 0.2.0`). It returns `herdr` only when exactly
one client root validates. Any ambiguous state (two or three valid roots) or
missing/invalid state fails closed through the fixed invalid-input block.

### 4. Process Execution and Block Wire Envelope

In Herdr's POSIX execution runtime, hook processes communicate via exit code and
standard streams:
- Policy allow: exit code `0`, empty stdout and stderr.
- Policy block or malformed input: exit code `2`, empty stdout, single-line error
  message `<reason>\n` on stderr.

### 5. Provisional Contract and Verification Boundary

This wire contract is established as a provisional default for M9 slice 2
(`herdr-native-app-hooks`) to enable offline fixture construction and deterministic
Bats testing. End-to-end behavioral verification with live `/Applications/Herdr.app`
is owned by M9 slice 3 (`herdr-verification`).

## Consequences

- Herdr users receive the same fail-closed identity, role governance, and compaction
  protection as Claude Code and Codex users.
- The shared hook manifest and scripts support all three clients with zero divergence.
- Test suites and offline gates run deterministically without requiring a live display.
