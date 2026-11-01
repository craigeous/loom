# Evaluation: Herdr client adapter and execution contract

Artifact: `.docs/research/2026-11-01-herdr-client-adapter-contract.md`
Reviewed against: Installed Herdr app `/Applications/Herdr.app`, CLI `--skill`, `--version`, `--help`, strings, and Loom specs/ADRs
Verdict: PASS
Round: 0

## Findings

- Source verification: Sources [1] through [6] are physically present and verified. `/Applications/Herdr.app/Contents/Info.plist` establishes version `0.1.10` and identifier `dev.herdr.app`. CLI `--skill` and `--help` establish `herdr-app` syntax, spaces/tabs/panes structure, `HERDR_APP_HOME`, and `herdr-core` backend.
- Plugin and binding contracts: The `HERDR_PLUGIN_ROOT` environment variable and `herdr-plugin-root-v1.json` descriptor follow Loom's established `loom-installed-root-binding-v1` schema and helper allowlists.
- Compatibility integration: The mapping of three capability profiles to Herdr execution profiles conforms to ADR 0018 and ADR 0027.

## Notes

All citations verified against real local system and repository artifacts.
