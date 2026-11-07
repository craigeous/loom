# Release Conformance and Evidence Schema

Status: Plan Review
Target specs: 10-packaging.md, 07-command-surface.md
Target size: <= 300 LOC net change (keep this plan document <= 250 lines)

## Context

This slice closes gaps G4 and G5 in the [v0.2.0 live-proof research note](../research/2026-11-06-v020-live-proof-preparation.md) (§3). It fulfils ADR 0032 §8 and records the ADR 0033 D3 ordering: the v0.2.0 live proof for Claude Code CLI and Codex CLI on macOS 14+ Apple silicon comes first, and it needs a record format and aligned docs before a candidate can be frozen.

- **G4 — no evidence schema.** `plugins/loom/schemas/loom-dogfood-evidence-v1.schema.json` describes one retired-checkpoint run (`platform` const `darwin-arm64`, a single `state`). It cannot hold the ADR 0032 §3 record: per-pair grouping, the five role results (E4(a)), the full-loop result (E4(b)), the gate (E4(c)), the owner acknowledgement (E5), and the candidate binding. ADR 0032 §3 leaves the format to a spec 10 amendment.
- **G5 — ADR 0032 §8 edits owed.** `README.md` "Supported Platforms & Prerequisites" (lines 71–75) and the v0.2 baseline paragraph (lines 244–247) still list Ubuntu and macOS Intel. `.github/workflows/check.yml` still runs four lanes (Ubuntu 22.04 and 24.04, macOS 14 arm64, macOS 15 Intel). Spec 10 and spec 07 still describe the dogfood tier. `CLAUDE.md` is already corrected.
- **Already done, verified.** G1 and G2 (launcher matrix selection, default rotation) are closed by the Landed plan `archive/launcher-matrix-and-rotation-fix.md`. The ADR index already records the ADR 0019 §2/§5, ADR 0024 §1 and ADR 0027 §4 supersessions (inside the ADR 0032 entry).

Corrections found while planning. The brief named a spec and assumed a CI surface that differ from the tree:

1. **`07-orchestration.md` does not exist.** The spec that owns the "Private dogfood workflow and role mapping" section (ADR 0032 §8) is `07-command-surface.md`. This plan targets that file.
2. **The CI lane list is pinned in three more places.** `scripts/check-toolchain.json` and the jq contract inside `scripts/check` each carry the SHA-256 of `check.yml` and the runner rows. `scripts/tests/repository-validation.bats` addresses the removed rows by name. All must change in the same commit, or the gate fails.
3. **The validator rejects nested evaluation paths.** `scripts/validate-repository.mjs` reports "unexpected nested path under .docs/evaluations". ADR 0032 §3 requires `.docs/evaluations/release-evidence/vR.json`, so the validator must accept exactly that path.

Decisions this plan takes (recommendations for the plan evaluator to confirm or redirect):

- **D-a.** Schema id `loom-release-evidence/v1`, scoped to the v0.2.0 row (two pairs, macOS 14+ arm64). v0.3.0 may reuse it only if it adds pairs by enum amendment; v0.4.0 (Ubuntu) requires a new schema version.
- **D-b.** The published record holds passing results only (`result` is `const "pass"`). ADR 0032 §1 says any required-cell failure blocks publication, so failures stay in run journals.
- **D-c.** Run journals and logs are not committed by this slice. The record references each log and stores its SHA-256, computed after sanitization. This answers research Q5 without a nested journal tree.
- **D-d.** CI keeps one lane: macOS 14 arm64 with `/bin/bash` 3.2.57. Bash 5.x stops being CI evidence for v0.2.0. Spec 10 and the README say so. The evaluator may prefer a Homebrew Bash 5 step on the same runner; that stays inside ADR 0032 §8.
- **D-e.** "Upgrade" (research Q4, unresolved) is defined in spec 10 as: install a prior candidate commit's marketplace source, install the final candidate over it, then uninstall. The owner may replace this definition.

## Out of Scope & Threat-Model Boundary

- **The live v0.2.0 proof itself.** Isolated logins, floor-pinned installs, the 5×2 role matrix, install/upgrade/uninstall runs, the full loop, tagging `v0.2.0`, and writing the real `v0.2.0.json` record are the owner-gated operational pass (research §9, steps 3–14). This slice adds only the schema, validator wiring, docs and tests that let that record be checked.
- **Research gaps G3, G6 and G7** (floor-pinned binaries, native Claude role return, Codex isolated auth) and the owner's auth choice (research Q3). None is decided here.
- **v0.3.0 admission.** Antigravity, Orca and Herdr (`hc`) stay deferred (ADR 0033 §1). No admission ADR is written here.
- **Ubuntu.** No Ubuntu platform row, CI lane or evidence is added or removed beyond what ADR 0032 §1 requires for v0.2.0. Ubuntu returns in v0.4.0.
- **macOS Intel.** Not supported in any release. No evidence is accepted for it.
- **ADR 0032 §8 items outside this slice:** spec 00, 02, 03 and 06 dogfood wording, and the `CLAUDE.md` Map entry for `scripts/macos-dual-client-dogfood`. Recorded as residual; a later finalize pass takes them.
- **Git relation checks** (`git merge-base --is-ancestor vR <record>` and `candidate == git rev-parse vR^{commit}`). They need the tag, so they run at release time, not in repository validation or CI. Spec 10 documents the commands. The validator checks the record's shape and its internal consistency only.
- **Threat model.** The record is a repository-committed, self-attested artifact. It helps reviewers audit claims; it does not prove authenticity. The E5 owner acknowledgement is the control on who accepted it. The record must never contain credential values, auth file content, environment dumps, or absolute owner paths (spec 06 isolation rule; research §4.1). Schema validation cannot detect a fabricated run; that remains a review obligation.

## Steps

1. **Create `plugins/loom/schemas/loom-release-evidence-v1.schema.json`** (Draft 2020-12, `additionalProperties: false` at every object, `$id` in the same style as `loom-dogfood-evidence-v1.schema.json`).
   - Top level, all required: `schema` (const `loom-release-evidence/v1`); `release` (`^\d+\.\d+\.\d+$`); `tag` (`^v\d+\.\d+\.\d+$`); `candidate` (`^[0-9a-f]{40}$`); `platform` (`os` const `macOS 14+`, `arch` const `arm64`); `matrix` (`^adapters/compatibility/v\d+\.\d+\.\d+\.json$`); `pairs` (exactly 2 items); `installUpgradeUninstall` (`result` const `pass`, `log`, `logSha256`); `ownerAck`.
   - Shared definitions: `log` is a relative string (1–256 chars, no leading `/`, no `..`); `logSha256` and `outputHash` match `^[0-9a-f]{64}$`.
   - `pairs[]`, all required: `harness` (enum `claude-code-cli`, `codex-cli`); `client` (enum `claude`, `codex`, matching the matrix `clientFloors` keys); `floor` (const `2.1.216` for `claude-code-cli`, `0.144.6` for `codex-cli`, via `allOf` `if/then`); `e1` (`matrix` string, `entry` = client); `e2` (`binding` const `claude-plugin-root/v1` for claude, `codex-skill-source/v1` for codex, via `if/then`); `e3` (`runId`, `result` const `pass`, `log`, `logSha256`); `e4`; `authSource` (enum `owner-login-isolated`, `setup-token-env`, `api-key-env`); `ownerStateUnchanged` (const `true`).
   - `e4.a_roles`: exactly the keys `researcher`, `planner`, `plan-evaluator`, `developer`, `code-evaluator`; each has `result` (const `pass`), `log`, `logSha256`, `outputHash`.
   - `e4.b_loop`: `runId`, `result` (const `pass`), `blindReview` (const `verified`), `crossFamilyVerified` (const `true`), `log`, `logSha256`.
   - `e4.c_gate`: `command` (const `scripts/check`), `result` (const `pass`), `log`, `logSha256`.
   - `ownerAck`: `by` (const `owner`); `pairs` (`uniqueItems`, exactly `claude-code-cli` and `codex-cli`); `evidenceSet` (`^[0-9a-f]{64}$`); `candidate` (`^[0-9a-f]{40}$`); `date` (`^\d{4}-\d{2}-\d{2}$`).
   - The schema cannot check `tag` against `release`, or `ownerAck.candidate` against `candidate`. Step 2 does that.

2. **Wire the record into `scripts/validate-repository.mjs`.** In `validateEvaluations` (around line 1015), accept exactly `release-evidence/v<semver>.json` under `.docs/evaluations/`. For that path:
   - validate the file against the new schema with the same helper the dogfood record uses (around line 378);
   - check that the file name equals `tag` plus `.json`, that `release` equals `tag` without the leading `v`, and that `ownerAck.candidate` equals `candidate`;
   - skip the `eval-name` rule for it.
   Every other nested path keeps the existing "unexpected nested path" error. The check runs only when the record exists (same `safeNode` guard as line 380), in both `--metadata` and `--all`.

3. **Update `.docs/spec/10-packaging.md`.**
   - *Authority:* add links to ADR 0032 and ADR 0033.
   - *Supported runtime and platforms* (lines 103–120): replace the v0.2 matrix with the ADR 0032 §1 v0.2.0 row (macOS 14+ Apple silicon × Claude Code CLI ≥ 2.1.216, Codex CLI ≥ 0.144.6). State that Ubuntu 22.04/24.04 x86-64 moves to v0.4.0 and that macOS Intel is unsupported in every release. Replace "Tests run Bash 3.2 and current Bash 5.x" with: CI gates Bash 3.2.57 on macOS 14; Bash 5.x is local evidence only for v0.2.0 (D-d).
   - *Release gate* (lines 227–247): replace "Ubuntu and macOS CI … both required client-floor adapter matrices" with the macOS 14+ arm64 CI lane plus the E1–E5 record for each required pair. Keep the other gate bullets.
   - *Replace "Private Apple-silicon dogfood evidence"* (lines 249–265) with "Release conformance evidence (ADR 0032 §3)". Cover:
     - E1–E5 in one line each, with ADR 0032 §3 as the normative text;
     - the record path `.docs/evaluations/release-evidence/vR.json`, schema `loom-release-evidence/v1`, append-only after publication;
     - the two candidate-binding commands from ADR 0032 §3, shown as commands;
     - the isolation and no-secrets rules from research §4.1;
     - external-log hashing (D-c);
     - the upgrade definition (D-e);
     - one sentence stating that the ADR 0024 blocked record is historical and is not E4 evidence (ADR 0033 §2).

4. **Update `.docs/spec/07-command-surface.md`** (section at lines 94–121). Retitle it "v0.2.0 release conformance workflow and role mapping". Change the lead sentence to say that the v0.2.0 release (ADR 0032 E4) must prove these pairs for each required client. Keep both mapping tables unchanged. Replace the closing sentence ("Codex behavior is pending until the exact-candidate dogfood evaluation passes…") with: Codex support is claimed only when the `codex-cli` record verifies; ChatGPT desktop and Codex IDE are outside the v0.2.0 row.

5. **Update `README.md`.**
   - *Hosts bullet* (lines 73–75): "macOS 14+ on Apple silicon (arm64) for v0.2.0 and v0.3.0; Ubuntu 22.04/24.04 x86-64 moves to v0.4.0; macOS Intel is not supported." Keep the Windows, PowerShell, Git Bash/MSYS2, Cygwin and WSL sentence.
   - *v0.2 baseline paragraph* (lines 244–247): name macOS 14+ Apple silicon as the only v0.2 platform; say CI covers one macOS 14 arm64 lane on Bash 3.2.57; say a pair is supported only with its complete record (spec 10).
   - Keep these two sentences verbatim. The validator requires them (`validate-repository.mjs` around lines 386–395): "The exact supported client floors are Claude Code 2.1.216 and Codex CLI 0.144.6." and "static scaffolding only".
   - If the Bats snapshot count changes, update the "886" figure.

6. **Update `.github/workflows/check.yml`.** Keep only the `macos-14` include row (`host: Darwin`, `architecture: arm64`, `release: "14"`, `shell: /bin/bash`, `bash_regex: '^3\.2\.57'`). Leave the assertion step unchanged; its Linux branch becomes unreachable, but editing it would widen the digest churn. Then recompute `shasum -a 256` and update both:
   - `scripts/check-toolchain.json`: `workflow.sha256` and `runners` (one row);
   - `scripts/check`, the jq contract (around lines 286–296): the `sha256` literal and the `.runners` literal.
   The `downloads` and `vendored` lists stay unchanged.

7. **Retarget the bats tests that name removed rows** (`scripts/tests/repository-validation.bats`):
   - around line 1070, "workflow runner row deletion fails": delete the `macos-14` row instead of `macos-15-intel`;
   - around line 1105, "runner label mutation": `macos-14` → `macos-13`;
   - around line 1111, "host mutation": `host: Darwin` → `host: Other`;
   - around line 1117, "architecture mutation": `architecture: arm64` → `architecture: x86_64`;
   - around line 1177, `del(.runners[3])` → `del(.runners[0])`.
   Each keeps its original purpose: a mutation of the surviving row must still fail.

8. **Update `.docs/ADR/README.md`.** The ADR 0032 entry already records the ADR 0019 §2/§5, ADR 0024 §1 and ADR 0027 §4 supersessions. Add to the ADR 0024 entry that ADR 0033 supersedes its §6/§7 ongoing obligations. Verify the ADR 0019 and ADR 0027 entries match ADR 0032 §4 and §8. Edit no ADR body.

9. **Update `.docs/slice-plans/README.md`.** Add a line under "Active plans", above `hc-host-adapter.md`: link to `release-conformance-and-evidence-schema.md`, status `Draft`, one-line purpose.

10. **Add tests to `scripts/tests/repository-validation.bats`, prefixed "release evidence:".**
    - Add fixture `scripts/tests/fixtures/release-evidence/v0.2.0-valid.json`: a complete, valid record with placeholder 40-hex candidate and hashes, one line per role.
    - Copy the fixture to `.docs/evaluations/release-evidence/v0.2.0.json` in a test root and assert it passes in `--metadata` and `--all` modes.
    - Use `mutate_json` to assert each of these fails with the schema path named:
      - a missing role key;
      - any `result` set to `"fail"`;
      - a codex `floor` of `0.144.5`;
      - a third pair;
      - a 39-character candidate;
      - an absolute `log` path;
      - a `tag` of `v0.2.1` with the file still named `v0.2.0.json`;
      - an `ownerAck.candidate` that differs from `candidate`.
    - Assert that another nested path under `.docs/evaluations/` still fails with "unexpected nested path".

## Verification

- **Gate (the candidate commit, CLAUDE.md shell gate):** `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check` must pass. The gate's jq contract checks the new `check.yml` digest and the single runner row.
- **Targeted, during development:** `LOOM_NODE="$(command -v node)" TMPDIR=/private/tmp bats --filter "release evidence|workflow|runner" scripts/tests/repository-validation.bats`. Also `shfmt -i 4 -d scripts/check` and `shellcheck -s bash scripts/check`.
- **Repository validation:** `node scripts/validate-repository.mjs --all` and `node scripts/validate-repository.mjs --metadata` must each exit 0 with no record present. The first run also covers the README floor sentences and the plan-authority rule.
- **Digest and lane consistency:** `shasum -a 256 .github/workflows/check.yml` must equal `workflow.sha256` in both `scripts/check-toolchain.json` and `scripts/check`. `jq '.runners | length' scripts/check-toolchain.json` must print `1`.
- **Regression:** every existing test in `repository-validation.bats` passes unchanged except the five retargeted in step 7.
- **Not verified here (release time, not this slice):** the git-ancestry and candidate-equals-tag checks, and remote CI on the single macOS lane.

## Notes

- **2026-11-06 (planner):** This plan is a Draft for plan evaluation. Decisions D-a to D-e are listed in Context. The evaluator should confirm D-d (CI Bash coverage) and D-e (upgrade definition) explicitly.
- **2026-11-06 (planner):** Spec name correction: `07-orchestration.md` (task brief) does not exist; `07-command-surface.md` is the target.
- **2026-11-06 (planner), size risk:** Estimated net change is about 290 LOC (schema ~120, validator ~30, bats ~80, fixture ~45, spec 10 ~+60/−30, spec 07 and README ~+20/−10, `check.yml` and contract literals ~−30). That is tight against the 300 LOC target. If the developer exceeds it, split steps 6–7 (CI lane retirement) into a sibling plan, `ci-macos-only-lane`. That is the only split allowed; the schema and docs stay together.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |
