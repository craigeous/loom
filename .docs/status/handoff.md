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
- **Landed (2026-11-07):** `codex-launch-schema-fix` (v0.2.1 preparation): removed `--output-schema` from `codex exec` in `loom-launch-role`, allowing native unwrapped execution; enforced non-symlinked regular file check on launch descriptor schema; 103/103 Bats tests passing.
- **Published (2026-11-07):** `v0.2.0` release tag and release evidence (`.docs/evaluations/release-evidence/v0.2.0.json`, ADR 0032 E1–E5, ADR 0033 D3) published to `origin/main`. Live conformance proven for Claude Code CLI (2.1.216 floor) and Codex CLI (0.144.6 floor) on macOS 14+ Apple silicon.
- **Landed (2026-11-07):** `release-conformance-and-evidence-schema` via remote-direct: v0.2.0 release-evidence schema (`loom-release-evidence/v1`) and chain validator, macOS-only CI runner and docs alignment (G4, G5; ADR 0032 §3, §8).
- **Landed (2026-11-06):** `launcher-matrix-and-rotation-fix` via remote-direct: `loom-launch-role` binds the release compatibility matrix (0.2.0 default) and rotates the default to two clients (claude ↔ codex), without Antigravity.
- **Landed (2026-11-06):** `instruction-adapter-sync` via remote-direct: the ADR 0032 §2 wording is in the instruction digest and all three derived blocks; hashes re-stamped; `--all` now fails on digest/marker/shared-line drift. Follow-up (optional): a Bats case with a drifted `GEMINI.md` and extra marker-structure negatives (review TST-1..3, MINOR).
- **Landed (2026-11-05):** `dogfood-retirement` (ADR 0033 D1) via remote-direct: the macOS dual-client checkpoint tooling and its temporary gate exclusion list are deleted; the preserved evidence record and its schema check remain; `dogfood-int-race` is Abandoned.
- **Landed (2026-11-05):** `herdr-surface-retirement` (M9 4 of 4) via remote-direct: Herdr plugin surfaces retired; Claude and Codex are the only supported clients. `hc-host-adapter` and `hc-live-probe` stay shelved (ADR 0033 D4); no probe evidence recorded.
- **Landed (2026-11-02):** `hc-guard-deny-policy` (M9 1 of 4) via remote-direct. M9 slices `herdr-client-adapter`, `herdr-native-app-hooks`, `herdr-verification` Landed; 952 Bats tests passing (offline fixtures only).
- **Owner decisions (2026-11-03, binding; recorded in ADR 0033, Accepted):** D1 retire the macOS checkpoint tooling; D2 narrow 0032's five-harness v0.3.0 scope to evidence-admitted pairs after 0.2; D3 v0.2.0 live proof for Claude Code CLI + Codex CLI first; D4 defer the Herdr/`hc` evaluator question until that proof completes (`hc` evaluators stay prohibited).
- **Shelved (files and review history kept):** `hc-host-adapter`, `hc-live-probe` — not to be built until the live proof completes and the evaluator question is reopened.
- **Next action:** Confirm owner approval to push `codex-launch-schema-fix` to `origin/main`, then proceed with Track 2 (Orca host surface admission for v0.3.0) or remaining scope.
- **Session history:** Archived in [`archive/handoff-history.md`](archive/handoff-history.md) so this handoff stays within the 150-line cold-start budget.
