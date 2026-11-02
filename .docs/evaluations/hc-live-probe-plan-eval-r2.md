# Evaluation: hc-live-probe

Verdict: PASS
Round: 2

## Required changes

None for this independent probe slice.

## Findings

- [MINOR] Cross-plan coordination needs correction: `.docs/slice-plans/herdr-surface-retirement.md:17` says slice 2 edits `v0.3.0.json`, but `.docs/slice-plans/hc-host-adapter.md:50` and `:90` explicitly exclude a matrix edit and register the binding at a fixed path. The latter also conflicts with the owner's instruction to register the helper under the v0.3.0 matrix. This probe explicitly needs no code from those slices, so the conflict does not prevent its implementation; resolve it in the host and retirement plans. Command: `rg -n 'v0.3.0.json|No matrix|Registration is the binding' .docs/slice-plans/{hc-host-adapter,herdr-surface-retirement}.md`.

## Mechanical checks and scope

- Round 1 findings resolved: P4 uses `status.state`, P6 references P4, and the stub checks wrong `status.state`; the explicit blind-review open gate excludes evaluator roles. Commands: `git diff 3e04b23 -- .docs/slice-plans/hc-live-probe.md` and `rg -n 'status.state|blind|evaluator' .docs/slice-plans/hc-live-probe.md .docs/ADR/0031-herdr-as-an-hc-driven-client.md .docs/research/2026-11-01-hc-agent-runtime-reference.md`.
- `wc -l .docs/slice-plans/hc-live-probe.md` returns 126; line 6 sets a 260 added LOC slice budget for script and Bats. The exact gate is `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check` (line 115).
- `for p in .docs/status/progress.md .docs/slice-plans/README.md CLAUDE.md scripts/hc-live-probe scripts/tests/hc-live-probe.bats; do test -e "$p" && printf 'exists %s\n' "$p" || printf 'new %s\n' "$p"; done` confirms existing touched paths and the two paths marked new. Acceptance criteria P1–P7 specify observable command outputs, JSON or stub behavior; live execution remains prospective. No UI or role launch is required. `jq -e . plugins/loom/adapters/compatibility/v0.3.0.json` succeeds.
- `rg -n 'status.state|blind|evaluator|schema|binding|v0.3.0|wrapper|sh -c|bash -c|timeout|xargs|scripts/check|Target size|GUI|slice' .docs/slice-plans/{hc-live-probe,hc-host-adapter,hc-guard-deny-policy,herdr-surface-retirement}.md .docs/ADR/0031-herdr-as-an-hc-driven-client.md .docs/research/2026-11-01-hc-agent-runtime-reference.md` checks split dependencies, wrapper tests, unchanged v0.2.0 evidence, blind-review gates, binding location and schema. Codex and evaluator role use remain unsupported; Orca and Antigravity are not in this probe. The host and retirement plans agree on keeping the host binding and its new schema, and the open blind-review item, subject to the finding above.
- No live hc command, agent, or gate was run during this review.

## Prior Rounds Summary

Round 1 FAIL: the reported-status field and unresolved blind-review constraint were missing or incorrect. Both are addressed in the revision.
