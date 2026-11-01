# Owner acceptance: ADR 0030 — Herdr Native App Lifecycle and Event Hooks

Status: Accepted
Accepted-at: 2026-11-01
Accepted-by: owner (repository owner, spec 03 owner-acceptance authority)

## What is accepted

ADR `0030-herdr-native-app-hooks.md` at `Status: Accepted`.

## Basis

- Grounded in approved research note `.docs/research/2026-11-01-herdr-native-app-hooks-contract.md` and repository improvement plan Milestone M9.
- Establishes the multi-client hook dispatcher binding, `HERDR_PLUGIN_ROOT` validation, and provisional POSIX block wire envelope to be verified in `herdr-verification`.
- Dispositive owner acceptance per spec 03.

## Decision accepted

ADR 0030 extends ADR 0003, ADR 0013, ADR 0018, and ADR 0029 to authorize the Herdr native app lifecycle and event hook contracts, manifest hook discovery in `plugin.json`, and fail-closed root selection across all three clients.
