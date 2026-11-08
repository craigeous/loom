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
- **Landed (2026-11-08):** `antigravity-model-adapter` (M9 / v0.3.0 Slice 4): Antigravity model adapter (`plugins/loom/bin/loom-launch-role` model-family extraction across anthropic, openai, google, and oss; cross-family evaluation invariant enforcement with fail-closed checks on aliases and missing author models; author routing persistence via `--routing-file`; Antigravity CLI floor 1.4.12 enforcement), `plugins/loom/adapters/roots/antigravity-plugin-root-v1.json` registered under `loom-installed-root-binding-v1.schema.json`, `v0.3.0.json` matrix `clientFloors.antigravity` registered with `1.4.12` floor, profile mappings, root descriptor, byte-equal fixture, and repository validator checks; 113/113 Bats tests in `loom-launch-role.bats` passing; local review `ran-clean`; code evaluation passed Round 0 (PASS via OpenAI Codex `gpt-6.1-terra`); plan archived.
- **Landed (2026-11-08):** `orca-host-adapter` (M9 / v0.3.0 Slice 3): `loom-host-orca` observation/cleanup helper, `v0.3.0` matrix `hostFloors.orca` registration, `loom-host-binding-v1` schema update, fixture, and repository validator; 22/22 Bats tests passing under Bash 3.2; local review `ran-clean`; code evaluation passed Round 2 (PASS via OpenAI Codex `gpt-6.1-terra`); plan archived.
- **Landed (2026-11-08):** `hc-live-probe` (M9 / v0.3.0 Slice 2): generic live probe script `scripts/hc-live-probe` and offline Bats suite `scripts/tests/hc-live-probe.bats` (20/20 tests passing under Bash 3.2, 260 LOC budget respected); local review `ran-clean`; code evaluation passed Round 5 (PASS via OpenAI Codex `gpt-6.1-terra`); live probe executed with scratch evidence recorded; plan archived.
- **Landed (2026-11-08):** `hc-host-adapter` (M9 / v0.3.0 Slice 1): `loom-host-hc` observation/cleanup helper, `v0.3.0` matrix `hostFloors` registration, `loom-host-binding-v1` schema, fixture, and repository validator; 271 Bats tests passing; code evaluation passed Round 4 (PASS via OpenAI Codex `gpt-6.1-terra`); plan archived.
- **Accepted (2026-11-08):** ADR 0034 (Admit Antigravity, Orca, and Herdr (`hc`) to v0.3.0 Scope and Settle Evaluator Governance) Accepted after Round 3 PASS via Codex cross-family evaluation. Formally admits Antigravity, Orca, and Herdr to v0.3.0. Settles host evaluator governance (ADR 0034 §2): interactive roles run inside host harnesses (`herdr`, `orca`), while evaluators run in cold, isolated POSIX workspaces with certified model CLIs (`codex` or `claude`). Slices ordered: (1) `hc-host-adapter`, (2) `hc-live-probe`, (3) `orca-host-adapter`, (4) `antigravity-model-adapter`.
- **Landed (2026-11-07):** `codex-launch-schema-fix` (v0.2.1 preparation): removed `--output-schema` from `codex exec` in `loom-launch-role`, allowing native unwrapped execution; enforced non-symlinked regular file check on launch descriptor schema; 103/103 Bats tests passing.
- **Published (2026-11-07):** `v0.2.0` release tag and release evidence (`.docs/evaluations/release-evidence/v0.2.0.json`, ADR 0032 E1–E5, ADR 0033 D3) published to `origin/main`. Live conformance proven for Claude Code CLI (2.1.216 floor) and Codex CLI (0.144.6 floor) on macOS 14+ Apple silicon.
- **Landed (2026-11-07):** `release-conformance-and-evidence-schema` via remote-direct: v0.2.0 release-evidence schema (`loom-release-evidence/v1`) and chain validator, macOS-only CI runner and docs alignment (G4, G5; ADR 0032 §3, §8).
- **Landed (2026-11-06):** `launcher-matrix-and-rotation-fix` via remote-direct: `loom-launch-role` binds the release compatibility matrix (0.2.0 default) and rotates the default to two clients (claude ↔ codex), without Antigravity.
- **Landed (2026-11-06):** `instruction-adapter-sync` via remote-direct: the ADR 0032 §2 wording is in the instruction digest and all three derived blocks; hashes re-stamped; `--all` now fails on digest/marker/shared-line drift.
- **Landed (2026-11-05):** `dogfood-retirement` (ADR 0033 D1) via remote-direct: the macOS dual-client checkpoint tooling and its temporary gate exclusion list are deleted; the preserved evidence record and its schema check remain; `dogfood-int-race` is Abandoned.
- **Landed (2026-11-05):** `herdr-surface-retirement` (M9 4 of 4) via remote-direct: Herdr plugin surfaces retired; Claude and Codex are the only supported clients.
- **Landed (2026-11-02):** `hc-guard-deny-policy` (M9 1 of 4) via remote-direct. M9 slices `herdr-client-adapter`, `herdr-native-app-hooks`, `herdr-verification` Landed; 952 Bats tests passing (offline fixtures only).
- **Next action:** Deliver Slice 5 (`v0.3.0-live-conformance` / release evidence per ADR 0034 §4 and §5): live conformance runs across admitted harnesses (Claude, Codex, Antigravity, Orca, Herdr) and v0.3.0 release candidate tagging.
- **Session history:** Archived in [`archive/handoff-history.md`](archive/handoff-history.md) so this handoff stays within the 150-line cold-start budget.
