# Launcher Matrix Selection and Two-Client Default Rotation (G1, G2)

Status: Plan Review
Target specs: 10-packaging.md (Versioned compatibility and capability mapping)
Authority: [ADR 0032](../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md) (Accepted; §1, §3 E1, §6); [ADR 0033](../ADR/0033-narrow-v0.3-scope-and-retire-macos-checkpoint-tooling.md) (Accepted; §2 sequence)
Inputs: [v0.2.0 live proof preparation](../research/2026-11-06-v020-live-proof-preparation.md) §3 G1 and G2; `plugins/loom/bin/loom-launch-role`; `plugins/loom/bin/loom-launch-role.bats`; `plugins/loom/adapters/compatibility/v0.2.0.json`; `plugins/loom/adapters/compatibility/v0.3.0.json`
Target size: about 150 lines changed across the launcher and its Bats suite; no new files except this plan.

## Context

**G1 — the launcher reads the v0.3.0 matrix.** `plugins/loom/bin/loom-launch-role` hard-codes `adapters/compatibility/v0.3.0.json` (line 492) and fails closed on any other `version` (line 498). Main's product version is `0.2.0` in both plugin manifests, so a v0.2.0 candidate today would launch Codex with the v0.3.0 profile map (`gpt-6.1-terra` / `gpt-6.1-sol`) instead of its own `v0.2.0.json` map (`gpt-5.6-terra` / `gpt-5.6`). ADR 0032 §3 E1 requires the release's own `vR.json` to carry the profile mapping the launcher uses.

**G2 — default rotation reaches Antigravity.** `_next_client_in_cycle` maps `codex` to `antigravity` (line 188), and `loom-launch-role.bats` line 657 asserts the full `claude → codex → antigravity → claude` rotation. ADR 0032 §6 says that rotation SHALL NOT route to Antigravity by default in any v0.2.x build, and ADR 0033 keeps that exclusion in force.

**Baseline (verified 2026-11-06):** `bats plugins/loom/bin/loom-launch-role.bats` passes 80/80 under GNU bash 3.2.57 with `TMPDIR=/private/tmp`.

## Out of Scope & Threat-Model Boundary

- **Matrix values are not changed.** `v0.2.0.json` and `v0.3.0.json` keep their contents. The launch schema (`loom-role-launch-v1.schema.json`) is not changed.
- **Codex model IDs are not verified here.** The `gpt-5.6*` IDs in `v0.2.0.json` are unverified against `codex` 0.144.6 (research Q1). The launcher uses matrix values verbatim; confirming them stays a live-proof item.
- **No spec or ADR text edits.** Spec 10 already names `v0.2.0.json` as the v0.2.0 matrix, so this slice needs no spec change. The `--release` flag is not yet described in spec text; a spec sentence would be a planner amendment that goes through plan evaluation. ADR 0032 §8 finalize edits (research G5) are out of scope.
- **Antigravity is not removed.** Explicit selection (`loom-launch-role antigravity <role>`, and routing files that name it) keeps working. Restoring Antigravity to default rotation needs the v0.3.0 evidence record (ADR 0032 §6) and is not part of this slice.
- **No live runs.** This slice runs no CLI login, no floor-pinned install, no live role launch, no push, and no tag.
- **Codex launches are not run manually.** The Codex path `exec`s the real `codex` binary (`exec env … "$CODEX_BIN"`). Codex behavior is exercised only through the Bats stub (`LOOM_LAUNCH_ROLE_CODEX_BIN`), never by running `loom-launch-role codex …` at a shell.
- **Threat-model boundary.** The release selector chooses among reviewed, tracked matrices. It must never let a caller supply a model or effort value, and every invalid selection fails closed (exit 2).

## Decisions

**D1 — Release selection is a flag, not an environment variable.** Add `--release X.Y.Z`. Do not read `LOOM_COMPATIBILITY_RELEASE` or any other environment variable for the release. An ambient variable could change vendor model mapping silently, which is the failure class ADR 0027 and the existing `VENDOR_OVERRIDE_VARS` guard exist to prevent. Research option (a) is taken; option (b), freezing `v0.2.0.json` as the only matrix, is rejected because the later v0.3.0 proof still needs a reachable v0.3.0 mapping.

**D2 — The default is a constant, cross-checked by a test.** Add `DEFAULT_COMPATIBILITY_RELEASE="0.2.0"` next to the other launcher constants. Do not read a client manifest at runtime: shared policy must not depend on a client-specific manifest (`CLAUDE.md`: shared policy portable, adapters thin). A Bats test asserts the constant equals `version` in both `plugins/loom/.claude-plugin/plugin.json` and `plugins/loom/.codex-plugin/plugin.json`. A release slice that bumps the product version must bump the constant too; the test fails if it does not.

**D3 — The Antigravity exclusion is unconditional.** `_next_client_in_cycle` drops Antigravity from the default cycle for every release this tree can launch, not only v0.2.x. ADR 0032 §6 gates restoration on v0.3.0 evidence, and no release has that evidence. Keep `antigravity → claude` so an author who opted into Antigravity explicitly still gets a cross-family evaluator.

**D4 — Selector validation is strict and fails closed.**
- Syntax must match `^[0-9]+\.[0-9]+\.[0-9]+$`. This excludes `/`, `..`, and `v` prefixes, so the path `$root/adapters/compatibility/v<sel>.json` cannot escape the compatibility directory.
- The file must exist, be a regular file, and not be a symlink.
- Its `schema` must be `loom-compatibility-matrix/v1`.
- Its `version` must equal the selector string exactly, replacing the current literal `"0.3.0"` check.
- Any failure exits 2 with a message naming `--release`. No launch line is printed.

**D5 — Argument shape.** `--release` without a value, or given twice, is a usage error (exit 1), like the other flags' shape errors. A bad value is exit 2, like invalid `--model` or `--effort`.

## Steps

Implementation steps for the developer, in order. Each is one reviewable change within the same slice commit.

1. **Constants.** In `plugins/loom/bin/loom-launch-role`, add `DEFAULT_COMPATIBILITY_RELEASE="0.2.0"` beside `CODEX_MODEL_RE` / `AGY_CACHE_TTL`, with a comment citing D2 and the manifest cross-check test.
2. **Flag parsing.** In `main`, add a `--release)` case next to `--author-client` and `--routing-file`. Require a value (`[ "$#" -ge 2 ] || _usage`) and reject a second occurrence with `_usage` (D5). Default to `DEFAULT_COMPATIBILITY_RELEASE` when unset.
3. **Selector validation.** Before any matrix read, check the selector syntax (D4) and call `_fail "invalid --release …"` on mismatch.
4. **Matrix path.** Replace the literal `adapters/compatibility/v0.3.0.json` (line 492) with `adapters/compatibility/v${release}.json`. Add the existence, regular-file, and not-symlink checks (D4). Replace the `"0.3.0"` version check with equality to the selector.
5. **Usage and header.** Add `[--release X.Y.Z]` to `_usage`. Update the header comment (lines 1–12) so it names the flag and the default, and no longer names `v0.3.0.json`.
6. **Rotation.** In `_next_client_in_cycle` set `claude → codex`, `codex → claude`, `antigravity → claude`. Add a one-line comment citing ADR 0032 §6 and D3.
7. **Bats fixtures.** In `make_root`, copy `v0.2.0.json` as well as `v0.3.0.json`. Tests that tamper with a matrix keep their assertions but target the file the default selects (`v0.2.0.json`), or pass `--release 0.3.0` when they test the v0.3.0 file.
8. **Bats positive Codex expectations.** Change the default Codex expectations (`codex: researcher/developer/planner/plan-evaluator/code-evaluator launches …`) to v0.2.0 values: Economy `gpt-5.6-terra/low`, Standard `gpt-5.6/medium`, Deep review `gpt-5.6/high`. Add a `--release 0.3.0` block asserting `gpt-6.1-terra/low`, `gpt-6.1-terra/medium`, `gpt-6.1-sol/high`. Ambient `gpt-6.1` config tests stay as they are; they test config input, not the matrix.
9. **Bats rotation.** Replace the test at line 657 with the two-client rotation assertions listed under Verification.
10. **New Bats tests.** Add the release-selection and rejection tests listed under Verification.
11. **Slice index.** Add this plan to the `Active plans` list in `.docs/slice-plans/README.md`, one line, in the same format as its neighbours.
12. **Gate.** Run the checks under Verification; commit with the handoff convention.

## Verification

Each check is mechanical. Record the command and its exit status in the slice journal.

**Static**
- V1. `shfmt -i 4 -d plugins/loom/bin/loom-launch-role` and `shellcheck -s bash plugins/loom/bin/loom-launch-role` both exit 0.
- V2. `grep -n 'compatibility/v0\.3\.0\|"0\.3\.0"' plugins/loom/bin/loom-launch-role` returns nothing.
- V3. In `_next_client_in_cycle`, no line maps `codex` to `antigravity`.

**Bats** (under Bash 3.2, with `LOOM_TEST_BASH` set to the physical 3.2 binary as `scripts/run-bats-under` does, and `TMPDIR=/private/tmp`)
- B1. Default release (no flag) emits Codex `gpt-5.6-terra/low` for researcher, `gpt-5.6/medium` for developer, and `gpt-5.6/high` for planner, plan-evaluator, and code-evaluator. Claude output is unchanged.
- B2. `--release 0.3.0` emits the v0.3.0 map (`gpt-6.1-terra/low`, `gpt-6.1-terra/medium`, `gpt-6.1-sol/high`) for the same roles.
- B3. `LOOM_COMPATIBILITY_RELEASE=0.3.0` in the environment is ignored; output still matches the default (D1 negative test).
- B4. Real-tree constant test: `DEFAULT_COMPATIBILITY_RELEASE` equals `.version` in `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json`.
- B5. Invalid syntax fails closed (exit 2, no `loom-role-launch/v1` line on stdout, message names `--release`): `0.2`, `v0.2.0`, `../0.2.0`, `0.2.0/../0.3.0`, and the empty string.
- B6. Unknown release `0.4.0` (no matrix file) fails closed with exit 2.
- B7. A matrix file whose `version` differs from the selector (for example `v0.2.0.json` copied from v0.3.0) fails closed with exit 2 and a version-mismatch message.
- B8. A selected matrix with a bogus `schema` fails closed with exit 2.
- B9. A selected matrix that is a symlink fails closed with exit 2.
- B10. `--release` without a value exits 1; `--release` given twice exits 1.
- B11. Rotation, auto evaluators: `plan-evaluator` with `--author-client claude` → codex; with `codex` → claude. `code-evaluator` with `claude` → codex; with `antigravity` → claude. No auto evaluator run in the test matrix ever emits `"client":"antigravity"`.
- B12. Explicit `loom-launch-role antigravity researcher` still launches (existing test near line 563 unchanged). A routing file that explicitly names `antigravity` still routes there (existing routing test near line 682 passes unchanged or with a recorded reason).
- B13. The full file passes: `bats plugins/loom/bin/loom-launch-role.bats` reports 80 original tests, adjusted as above, plus the new ones, all `ok`.

**Repository**
- R1. `node scripts/validate-repository.mjs --all` exits 0 with this plan at `Plan Review`.
- R2. Full gate on the candidate commit: `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check` exits 0. A narrower pass is acceptable during iteration; the full gate runs once on the candidate.

**Explicitly not a check:** running `loom-launch-role codex …` at a shell to see output. It would exec a real `codex` (see Out of Scope).

## Risks and Revision Log

- **R-a. Behavior change on main.** Every caller of `codex` launches now emits v0.2.0 models. This is intended, because v0.2.0 is the product version. Any caller that needs v0.3.0 mappings must pass `--release 0.3.0`.
- **R-b. Constant drift.** D2 relies on the B4 test and on release discipline. If the product version bumps without the constant, B4 fails the gate.
- **R-c. Unverified model IDs.** Research Q1 stays open. Nothing in this slice verifies `gpt-5.6*` against `codex` 0.144.6; the live proof must.
- **Open for plan evaluation.** Whether D1's flag-only surface needs a spec 10 sentence before approval. The planner's current position is that it does not, and that a spec sentence should be a follow-up amendment, not part of this slice.

## Revision Log

- 2026-11-06 — Initial plan drafted by the planner from the research note (G1, G2) and ADR 0032 §1, §3, §6. Status `Plan Review`.
