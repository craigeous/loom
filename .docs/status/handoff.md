# Session Handoff

Status: Living

Restart instructions and compact current context. `progress.md` is the status
source of truth; `roadmap.md` is milestone order.

Current milestone: M9

## Start here each session

1. Confirm repo:
   ```sh
   cd /Users/craig/git/loom
   git status --short
   ```
2. Read `.docs/spec/README.md`, then `.docs/status/progress.md` and this file.
3. Commits are author-neutral under one uniform git identity; roles must not set or
   override `user.*`. The command surface is `/loom:run` plus one-off `/loom:<role>`.

## Where things stand
- **Landed (2026-11-02):** `hc-guard-deny-policy` (M9 1 of 4) via remote-direct. M9 slices `herdr-client-adapter`, `herdr-native-app-hooks`, `herdr-verification` Landed; 952 Bats tests passing (offline fixtures only).
- **Owner decisions (2026-11-03, binding; recorded in ADR 0033 at Plan Review):** D1 retire the macOS checkpoint tooling; D2 narrow 0032's five-harness v0.3.0 scope to evidence-admitted pairs after 0.2; D3 v0.2.0 live proof for Claude Code CLI + Codex CLI first; D4 defer the Herdr/`hc` evaluator question until that proof completes (`hc` evaluators stay prohibited).
- **Planned, awaiting plan evaluation (nothing approved):** ADR 0033 and `dogfood-retirement` (both Plan Review). `dogfood-retirement` may not start until ADR 0033 is Accepted and `herdr-surface-retirement` has landed.
- **Shelved (files and review history kept):** `hc-host-adapter`, `hc-live-probe` — not to be built until the live proof completes and the evaluator question is reopened.
- **Next action:** (1) dispatch a cold plan evaluator on ADR 0033 and `dogfood-retirement`; (2) implement `herdr-surface-retirement` (Approved, runs first); (3) then the v0.2.0 live proof (authenticated isolated Claude and Codex homes; resolve the Codex 401; all five roles + full loop + install/upgrade/uninstall + gate, bound to the final candidate, ADR 0032 E1–E5). No Orca, Antigravity or `hc` build or run until then.
- **Session history:** Archived in [`archive/handoff-history.md`](archive/handoff-history.md) so this handoff stays within the 150-line cold-start budget.
