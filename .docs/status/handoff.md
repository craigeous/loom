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
- **Landed (2026-11-06):** `instruction-adapter-sync` via remote-direct: the ADR 0032 §2 wording is in the instruction digest and all three derived blocks; hashes re-stamped; `--all` now fails on digest/marker/shared-line drift. Follow-up (optional): a Bats case with a drifted `GEMINI.md` and extra marker-structure negatives (review TST-1..3, MINOR).
- **Landed (2026-11-05):** `dogfood-retirement` (ADR 0033 D1) via remote-direct: the macOS dual-client checkpoint tooling and its temporary gate exclusion list are deleted; the preserved evidence record and its schema check remain; `dogfood-int-race` is Abandoned. The exclusion reader is retired, so its follow-up test is moot.
- **Landed (2026-11-05):** `herdr-surface-retirement` (M9 4 of 4) via remote-direct: Herdr plugin surfaces retired; Claude and Codex are the only supported clients. `hc-host-adapter` and `hc-live-probe` stay shelved (ADR 0033 D4); no probe evidence recorded.
- **Landed (2026-11-02):** `hc-guard-deny-policy` (M9 1 of 4) via remote-direct. M9 slices `herdr-client-adapter`, `herdr-native-app-hooks`, `herdr-verification` Landed; 952 Bats tests passing (offline fixtures only).
- **Owner decisions (2026-11-03, binding; recorded in ADR 0033, Accepted):** D1 retire the macOS checkpoint tooling; D2 narrow 0032's five-harness v0.3.0 scope to evidence-admitted pairs after 0.2; D3 v0.2.0 live proof for Claude Code CLI + Codex CLI first; D4 defer the Herdr/`hc` evaluator question until that proof completes (`hc` evaluators stay prohibited).
- **Landed (2026-11-05):** `dogfood-gate-exclusion` via remote-direct (`94024cc`, receipt verified): `scripts/check` skips files listed in `scripts/check-bats-exclusions.txt` (only the macOS dogfood suite) until `dogfood-retirement` deletes it. Follow-up: Bats test for the reader (TST-1, unplanned).
- **Shelved (files and review history kept):** `hc-host-adapter`, `hc-live-probe` — not to be built until the live proof completes and the evaluator question is reopened.
- **Next action:** (1) the v0.2.0 live proof (authenticated isolated Claude and Codex homes; resolve the Codex 401; all five roles + full loop + install/upgrade/uninstall + gate, bound to the final candidate, ADR 0032 E1–E5). No Orca, Antigravity or `hc` build or run until then.
- **Session history:** Archived in [`archive/handoff-history.md`](archive/handoff-history.md) so this handoff stays within the 150-line cold-start budget.
