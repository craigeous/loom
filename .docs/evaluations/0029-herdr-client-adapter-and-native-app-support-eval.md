# Evaluation — ADR 0029 Herdr Client Adapter and Native App Support

Artifact: `.docs/ADR/0029-herdr-client-adapter-and-native-app-support.md`
Authority: spec 00-overview, spec 10-packaging, ADR 0018, ADR 0027, plan-eval-rubric.md
Round: 0
Verdict: PASS

## Summary

ADR 0029 extends ADR 0018 and ADR 0027 to authorize Herdr as a supported client adapter. It grounds itself in the approved research note `.docs/research/2026-11-01-herdr-client-adapter-contract.md` and Milestone M9 of the repository improvement plan. It specifies the plugin discovery manifest, marketplace metadata, installed-root binding `herdr-plugin-root/v1` via `HERDR_PLUGIN_ROOT`, compatibility matrix integration in `v0.3.0.json`, and helper/role launch integration.

## Findings

No blocking or major findings. The decision preserves shared core portability, non-delegation, and uniform identity guards while providing the formal architectural authority required for Milestone M9.
