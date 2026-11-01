# Evaluation — Herdr Client Adapter Contract

Artifact: .docs/research/2026-11-01-herdr-client-adapter-contract.md
Reviewed against: spec 00, spec 10, ADR 0018, ADR 0027, plan-eval-rubric.md
Round: 0
Verdict: PASS

## Summary

The research note compiles primary documentation from `/Applications/Herdr.app`, the `herdr-app` CLI, embedded strings, and official documentation to specify the Herdr client adapter contracts for Loom.

## Findings

- Source verification: Sources [1] through [6] are physically present and verified. `/Applications/Herdr.app/Contents/Info.plist` establishes version `0.1.10` and identifier `dev.herdr.app`. CLI `--skill` and `--help` establish `herdr-app` syntax, spaces/tabs/panes structure, `HERDR_APP_HOME`, and `herdr-core` backend.
- Plugin and binding contracts: The `HERDR_PLUGIN_ROOT` environment variable and `herdr-plugin-root-v1.json` descriptor follow Loom's established `loom-installed-root-binding-v1` schema and helper allowlists.
- Compatibility integration: The mapping of three capability profiles to Herdr execution profiles conforms to ADR 0018 and ADR 0027.
