# Launcher Matrix Binding and Two-Client Default Rotation (G1, G2)

Status: Implemented
Target specs: 10-packaging.md (Versioned compatibility and capability mapping)
Authority: [ADR 0032](../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md) (Accepted; §1, §3 E1, §6); [ADR 0033](../ADR/0033-narrow-v0.3-scope-and-retire-macos-checkpoint-tooling.md) (Accepted; §2 sequence)
Inputs: the v0.2.0 live-proof research note §3 G1 and G2 (linked under Context); `plugins/loom/bin/loom-launch-role`; `plugins/loom/bin/loom-launch-role.bats`; `plugins/loom/adapters/compatibility/v0.2.0.json`; `plugins/loom/adapters/compatibility/v0.3.0.json`
Target size: about 150 lines changed across the launcher and its Bats suite; no new files except this plan.

## Context

Grounding: [v0.2.0 live proof preparation](../research/2026-11-06-v020-live-proof-preparation.md) §3 G1 and G2.

**G1 — the launcher reads the v0.3.0 matrix.** `plugins/loom/bin/loom-launch-role` hard-codes `adapters/compatibility/v0.3.0.json` (line 492) and fails closed on any other `version` (line 498). Main's product version is `0.2.0` in both plugin manifests, so a v0.2.0 candidate today would launch Codex with the v0.3.0 profile map (`gpt-6.1-terra` / `gpt-6.1-sol`) instead of its own `v0.2.0.json` map (`gpt-5.6-terra` / `gpt-5.6`). ADR 0032 §3 E1 requires the release's own `vR.json` to carry the profile mapping the launcher uses. Spec 10 names the v0.2.0 effective map, so the binding is to the product release, not to a caller's choice.

**G2 — default rotation reaches Antigravity.** `_next_client_in_cycle` maps `codex` to `antigravity` (line 188), and `loom-launch-role.bats` line 657 asserts the full `claude → codex → antigravity → claude` rotation. ADR 0032 §6 says that rotation SHALL NOT route to Antigravity by default in any v0.2.x build, and ADR 0033 keeps that exclusion in force.

**Baseline (verified 2026-11-06):** `bats plugins/loom/bin/loom-launch-role.bats` passes 80/80 under GNU bash 3.2.57 with `TMPDIR=/private/tmp`.

## Out of Scope & Threat-Model Boundary

- **No caller-selected matrix.** The launcher reads only the matrix for its own product release. A future release's mapping (for example v0.3.0's `gpt-6.1*`) is delivered by that release's reviewed change: it bumps `DEFAULT_COMPATIBILITY_RELEASE` and both manifests, and ships its own `vR.json` (ADR 0032 §3 E1). It is not reachable from a v0.2.0 build by any flag or variable.
- **Matrix values are not changed.** `v0.2.0.json` and `v0.3.0.json` keep their contents. The launch schema (`loom-role-launch-v1.schema.json`) is not changed.
- **Codex model IDs are not verified here.** The `gpt-5.6*` IDs in `v0.2.0.json` are unverified against `codex` 0.144.6 (research Q1). The launcher uses matrix values verbatim; confirming them stays a live-proof item.
- **No spec or ADR text edits.** Spec 10 already names `v0.2.0.json` as the v0.2.0 matrix, so this slice needs no spec change. The `--release` assertion flag is not yet described in spec text; a spec sentence would be a planner amendment that goes through plan evaluation. ADR 0032 §8 finalize edits (research G5) are out of scope.
- **Antigravity is not removed.** Explicit selection (`loom-launch-role antigravity <role>`, and routing files that name it) keeps working. Restoring Antigravity to default rotation needs the v0.3.0 evidence record (ADR 0032 §6) and is not part of this slice.
- **No live runs.** This slice runs no CLI login, no floor-pinned install, no live role launch, no push, and no tag.
- **Codex launches are not run manually.** The Codex path `exec`s the real `codex` binary (`exec env … "$CODEX_BIN"`). Codex behavior is exercised only through the Bats stub (`LOOM_LAUNCH_ROLE_CODEX_BIN`), never by running `loom-launch-role codex …` at a shell.
- **Threat-model boundary.** `--release` is a pin, not a selector. It can only confirm the product release; it never chooses a matrix, and it never supplies a model or effort value. Every mismatch or invalid value fails closed (exit 2).

## Decisions

**D1 — The release is a pin, bound to the product release.** The launcher binds to `DEFAULT_COMPATIBILITY_RELEASE` (D2). An optional `--release X.Y.Z` flag may be supplied; if present it must equal `DEFAULT_COMPATIBILITY_RELEASE` exactly, otherwise the launcher exits 2 before any matrix read. Passing `0.3.0` to a v0.2.0 build fails closed. The flag exists so release-pinned callers and logs name the release they expect and fail loudly on a mismatch. The launcher does not read `LOOM_COMPATIBILITY_RELEASE` or any other environment variable for the release: an ambient variable could change vendor model mapping silently, which is the failure class ADR 0027 and the existing `VENDOR_OVERRIDE_VARS` guard exist to prevent. The earlier draft's caller-selectable matrix is withdrawn (Round 1, evaluator BLOCKER).

**D2 — The release is a constant, cross-checked by a test.** Add `DEFAULT_COMPATIBILITY_RELEASE="0.2.0"` next to the other launcher constants. The matrix path is derived from this constant (`adapters/compatibility/v${DEFAULT_COMPATIBILITY_RELEASE}.json`), never from caller input. Do not read a client manifest at runtime: shared policy must not depend on a client-specific manifest (`CLAUDE.md`: shared policy portable, adapters thin). A Bats test asserts the constant equals `version` in both `plugins/loom/.claude-plugin/plugin.json` and `plugins/loom/.codex-plugin/plugin.json`. A release slice that bumps the product version must bump the constant too and ship its own `vR.json`; the test fails if it does not.

**D3 — The Antigravity exclusion is unconditional.** `_next_client_in_cycle` drops Antigravity from the default cycle for every release this tree can launch, not only v0.2.x. ADR 0032 §6 gates restoration on v0.3.0 evidence, and no release has that evidence. Keep `antigravity → claude` so an author who opted into Antigravity explicitly still gets a cross-family evaluator.

**D4 — Matrix resolution is strict and fails closed.**
- The `--release` value, when given, must equal `DEFAULT_COMPATIBILITY_RELEASE` by string equality. Equality excludes `/`, `..`, `v` prefixes, and every other path-shaped value, so no caller input reaches a path.
- The file `adapters/compatibility/v${DEFAULT_COMPATIBILITY_RELEASE}.json` must exist, be a regular file, and not be a symlink (`-f` and `! -L`).
- Its `schema` must be `loom-compatibility-matrix/v1`.
- Its `version` must equal `DEFAULT_COMPATIBILITY_RELEASE` exactly, replacing the current literal `"0.3.0"` check. A `v0.2.0.json` whose content says `0.3.0` is therefore rejected.
- Any failure exits 2 with a message. A `--release` mismatch names `--release` and both values. No launch line is printed.

**D5 — Argument shape.** `--release` without a value, or given twice, is a usage error (exit 1), like the other flags' shape errors. A value that does not match (D1, D4) is exit 2, like invalid `--model` or `--effort`.

## Steps

Implementation steps for the developer, in order. Each is one reviewable change within the same slice commit.

1. **Constants.** In `plugins/loom/bin/loom-launch-role`, add `DEFAULT_COMPATIBILITY_RELEASE="0.2.0"` beside `CODEX_MODEL_RE` / `AGY_CACHE_TTL`, with a comment citing D2 and the manifest cross-check test.
2. **Flag parsing.** In `main`, add a `--release)` case next to `--author-client` and `--routing-file`. Require a value (`[ "$#" -ge 2 ] || _usage`) and reject a second occurrence with `_usage` (D5). Record the value; leave it unset when the flag is absent.
3. **Pin check.** Before any matrix read, if a release was supplied and it is not `DEFAULT_COMPATIBILITY_RELEASE`, call `_fail "invalid --release <value>: this build binds release $DEFAULT_COMPATIBILITY_RELEASE"` (D1, D4).
4. **Matrix path.** Replace the literal `adapters/compatibility/v0.3.0.json` (line 492) with `adapters/compatibility/v${DEFAULT_COMPATIBILITY_RELEASE}.json`. Add the not-symlink check alongside the existing `-f` check (D4). Replace the `"0.3.0"` version check with equality to `DEFAULT_COMPATIBILITY_RELEASE`.
5. **Usage and header.** Add `[--release X.Y.Z]` to `_usage`, described as "must equal the product release". Update the header comment (lines 1–12) so it names the constant and the flag, and no longer names `v0.3.0.json`.
6. **Rotation.** In `_next_client_in_cycle` set `claude → codex`, `codex → claude`, `antigravity → claude`. Add a one-line comment citing ADR 0032 §6 and D3.
7. **Bats fixtures.** In `make_root`, copy `v0.2.0.json` in addition to the existing `v0.3.0.json` copy. Keep the `v0.3.0.json` copy on purpose: the rejection tests (B2) must show that a present-but-foreign matrix is still refused. Retarget the matrix-tampering tests (currently lines 428–521, which edit `v0.3.0.json`) to `v0.2.0.json`, the file the launcher now reads. Their assertions do not change.
8. **Bats positive Codex expectations.** Change the default Codex expectations (`codex: researcher/developer/planner/plan-evaluator/code-evaluator launches …`) to v0.2.0 values: Economy `gpt-5.6-terra/low`, Standard `gpt-5.6/medium`, Deep review `gpt-5.6/high`. Ambient `gpt-6.1` config tests stay as they are; they test config input, not the matrix.
9. **Bats rotation.** Replace the test at line 657 with the exhaustive rotation assertions in B11.
10. **New Bats tests.** Add the release-pin and rejection tests B2 and B5–B10. No test asserts a v0.3.0 map from a v0.2.0 build.
11. **Slice index.** Add this plan to the `Active plans` list in `.docs/slice-plans/README.md`, one line, in the same format as its neighbours.
12. **Gate.** Run the checks under Verification; commit with the handoff convention.

## Verification

Each check is mechanical. Record the command and its exit status in the slice journal.

**Static**
- V1. `shfmt -i 4 -d plugins/loom/bin/loom-launch-role` and `shellcheck -s bash plugins/loom/bin/loom-launch-role` both exit 0.
- V2. `grep -n 'compatibility/v0\.3\.0\|"0\.3\.0"' plugins/loom/bin/loom-launch-role` returns nothing.
- V3. Rotation invariant, executable. This command prints `PASS` and exits 0 only if the body of `_next_client_in_cycle` maps `codex` to `claude` and contains no `printf 'antigravity'` target (so no client rotates to Antigravity). It exits non-zero if the function is missing, Codex maps anywhere else, or Antigravity appears as a target:
  ```
  f=$(awk '/^_next_client_in_cycle\(\) \{/{p=1} p{print} p&&/^\}/{exit}' plugins/loom/bin/loom-launch-role) \
    && [ -n "$f" ] \
    && printf '%s\n' "$f" | grep -Eq "^ *codex\) printf 'claude'" \
    && ! printf '%s\n' "$f" | grep -q "printf 'antigravity'" \
    && echo PASS
  ```

**Bats** (under Bash 3.2, with `LOOM_TEST_BASH` set to the physical 3.2 binary as `scripts/run-bats-under` does, and `TMPDIR=/private/tmp`)
- B1. Default release (no flag) and `--release 0.2.0` produce equivalent descriptors. For each role in {`researcher`, `developer`, `planner`, `plan-evaluator`, `code-evaluator`}, run both invocations against the same fixture root and capture each stdout. Normalize each with `jq -S 'del(.coldId)'`; the two normalized documents must be byte-identical (`cmp`). Separately, for each invocation assert `coldId` is present and non-empty (`jq -e '.coldId | type == "string" and length > 0'`), and that the two invocations of the same role emit different `coldId` values (fresh per launch, never reused). Role-specific assertions are retained on the default output: Codex `.codex.model` / `.codex.effort` is `gpt-5.6-terra` / `low` for researcher, `gpt-5.6` / `medium` for developer, and `gpt-5.6` / `high` for planner, plan-evaluator, and code-evaluator. Claude output takes the same normalized comparison, and its existing Claude tests are unchanged.
- B2. `--release 0.3.0` in a v0.2.0 build fails closed: exit 2, no `loom-role-launch/v1` line on stdout, stderr names `--release` and `0.2.0`. The fixture root contains `v0.3.0.json`, so the refusal is proven to come from the pin, not from a missing file. No `gpt-6.1` value appears in any output.
- B3. `LOOM_COMPATIBILITY_RELEASE=0.3.0` in the environment is ignored; output still matches the default (D1 negative test).
- B4. Real-tree constant test: `DEFAULT_COMPATIBILITY_RELEASE` equals `.version` in `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json`.
- B5. Malformed pin values fail closed (exit 2, no launch line, stderr names `--release`): `0.2`, `v0.2.0`, `../0.2.0`, `0.2.0/../0.3.0`, and the empty string.
- B6. A future release with no matrix in the fixture (`--release 0.4.0`) fails closed with exit 2 and the same message as B2.
- B7. A `v0.2.0.json` whose `version` is `0.3.0` (for example a copy of `v0.3.0.json` renamed into place) fails closed with exit 2 and a version-mismatch message.
- B8. A selected matrix with a bogus `schema` fails closed with exit 2 (existing test near line 520, retargeted to `v0.2.0.json`).
- B9. A selected matrix that is a symlink fails closed with exit 2. The symlink target is a byte-identical valid copy of `v0.2.0.json` stored outside the matrix path, so only the symlink check can cause the failure.
- B10. `--release` without a value exits 1; `--release` given twice exits 1.
- B11. Rotation, exhaustive: for each evaluator role in {`plan-evaluator`, `code-evaluator`} and each author client in {`claude`, `codex`, `antigravity`}, `loom-launch-role auto <role> --author-client <author>` resolves to: `claude` → `codex`; `codex` → `claude`; `antigravity` → `claude`. Each case asserts the `"client"` and `"authorClient"` fields and `"crossFamilyVerified":true`. No case in the test matrix emits `"client":"antigravity"` for an auto evaluator.
- B12. Explicit `loom-launch-role antigravity researcher` still launches (existing test near line 563 unchanged). A routing file that explicitly names `antigravity` still routes there (existing routing test near line 682 passes unchanged or with a recorded reason).
- B13. The full file passes: `bats plugins/loom/bin/loom-launch-role.bats` reports every test `ok`, with the count recorded in the journal.

**Repository**
- R1. `node scripts/validate-repository.mjs --all` exits 0 with this plan at `Plan Review`.
- R2. Full gate on the candidate commit: `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check` exits 0. A narrower pass is acceptable during iteration; the full gate runs once on the candidate.

**Explicitly not a check:** running `loom-launch-role codex …` at a shell to see output. It would exec a real `codex` (see Out of Scope).

## Risks

- **R-a. Behavior change on main.** Every caller of `codex` launches now emits v0.2.0 models. This is intended, because v0.2.0 is the product version. No v0.2.0 caller can obtain v0.3.0 mappings; that waits for the v0.3.0 release.
- **R-b. Constant drift.** D2 relies on the B4 test and on release discipline. If the product version bumps without the constant, B4 fails the gate.
- **R-c. Unverified model IDs.** Research Q1 stays open. Nothing in this slice verifies `gpt-5.6*` against `codex` 0.144.6; the live proof must.
- **R-d. Pin friction.** Callers that pass `--release` must pass the build's own release. A v0.3.0 build bumps the constant, which is the intended single point of change.
- **Open for plan evaluation.** Whether the `--release` pin flag needs a spec 10 sentence before approval. The planner's current position is that it does not, and that a spec sentence should be a follow-up amendment, not part of this slice.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial plan drafted by the planner from the research note (G1, G2) and ADR 0032 §1, §3, §6. Status `Plan Review`. Evaluation `launcher-matrix-and-rotation-fix-plan-eval.md` round 0: FAIL (BLOCKER, MAJOR). |
| 1 | Resolved the BLOCKER: withdrew the caller-selectable release matrix. The launcher binds to `DEFAULT_COMPATIBILITY_RELEASE` (0.2.0); `--release` is a pin that must equal it, else exit 2. D1, D2, D4, D5, steps 2–4, 7–10, B1–B11, and R-a/R-d revised; B2 is now the mismatch-rejection test. Resolved the MAJOR: V3 now has an executable command, and B11 exhausts both evaluator roles and all author clients. Status `Plan Review`. |
| 2 | Round 2 re-review, resolving the Round 1 MAJOR (evaluation `launcher-matrix-and-rotation-fix-plan-eval.md` round 1: FAIL). B1 no longer compares raw output: each descriptor is normalized with `jq -S 'del(.coldId)'` and byte-compared across the no-flag and `--release 0.2.0` invocations; `coldId` is separately asserted present, non-empty, and fresh per launch. Role-specific Codex model/effort and Claude assertions retained. No decision, step, or other check changed. Status `Plan Review`. |
