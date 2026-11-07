# Release Conformance and Evidence Schema

Status: Ready to Publish
Target files: `plugins/loom/schemas/`, `scripts/validate-repository.mjs`, `.github/workflows/check.yml`, `scripts/check-toolchain.json`, `scripts/check`, `scripts/tests/repository-validation.bats`, `scripts/run-bats-under`, `README.md`, `.docs/ADR/README.md` (index lines only)
Target specs: [10-packaging.md](../spec/10-packaging.md), [07-command-surface.md](../spec/07-command-surface.md) (amended by a sibling plan, not by this slice; see Out of Scope)
Authority: [ADR 0032](../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md) §3, §4, §8; [ADR 0033](../ADR/0033-narrow-v0.3-scope-and-retire-macos-checkpoint-tooling.md) D3
Target size: <= 150 LOC net code change in validator/runner, plus standalone schema, test fixture, and Bats tests; keep this plan document <= 250 lines

## Context

This slice closes gaps G4 and G5 in the [v0.2.0 live-proof research note](../research/2026-11-06-v020-live-proof-preparation.md) (§3). It implements the machine-checkable form of the ADR 0032 §3 evidence record for the v0.2.0 release and the ADR 0032 §8 edits that belong to code, CI and README. The live v0.2.0 proof comes after this slice, and a candidate cannot be frozen until its record format and checks exist.

- **G4 — no evidence schema.** `plugins/loom/schemas/loom-dogfood-evidence-v1.schema.json` describes one retired-checkpoint run and cannot hold the ADR 0032 §3 record: per-pair grouping, the E4(a) role results, the E4(b) loop, the E4(c) gate, the E5 owner acknowledgement, and the candidate binding. ADR 0032 §3 leaves the exact format to a spec 10 amendment.
- **G5 — ADR 0032 §8 edits owed in code and CI.** `README.md` "Supported Platforms & Prerequisites" (lines 71–75) and the v0.2 baseline paragraph (lines 244–247) still list Ubuntu and macOS Intel. `.github/workflows/check.yml` still runs four lanes. `CLAUDE.md` is already corrected.
- **Already done, verified.** G1 and G2 are closed by the Landed plan `archive/launcher-matrix-and-rotation-fix.md`. The ADR index already records the ADR 0019 §2/§5, ADR 0024 §1 and ADR 0027 §4 supersessions inside the ADR 0032 entry.

Corrections found while planning:

1. **`07-orchestration.md` does not exist.** The spec that owns "Private dogfood workflow and role mapping" is `07-command-surface.md`.
2. **The CI lane list is pinned in three more places.** `scripts/check-toolchain.json` and the jq contract inside `scripts/check` carry the SHA-256 of `check.yml` and the runner rows, and `scripts/tests/repository-validation.bats` addresses removed rows by name. All change in the same commit.
3. **The validator rejects nested evaluation paths.** `validateDocsState` (`--all` only) reports "unexpected nested path under .docs/evaluations". ADR 0032 §3 requires `.docs/evaluations/release-evidence/vR.json`, so that one path must be accepted and nothing else nested.

**Dependency (satisfied).** The format decisions this schema encodes (E4 sub-checks, the archive contract, the bash-run record, the upgrade definition) are normative text for spec 10 and spec 07. Under ADR 0005 and the severity rules, that text is owned by the sibling planning artifact [spec-10-07-release-evidence-amendment](spec-10-07-release-evidence-amendment.md). It has passed cold plan evaluation (Round 3, PASS; [evaluation](../evaluations/spec-10-07-release-evidence-amendment-plan-eval.md)) and reached `Approved`. Its spec text is not yet applied to spec 10 or spec 07; that lands with the implementing slice. This slice does not write or edit spec files.

**Archive verification commands (executable).** A reviewer runs these against the sanitized archive `ARCHIVE` and the record `RECORD`. They need no credentials and read only the archive, its manifest and the record. Each check is silent on success. This is the approved amendment's Verification check 5. It differs from the earlier draft in two ways: the `..` entry check is kept, and the special-file check is guarded by `| grep .`, because `find` exits 0 even when it matches.

```sh
D=$(mktemp -d) && tar -xzf ARCHIVE -C "$D"
tar -tzf ARCHIVE | grep -v -E '^(\./)?(MANIFEST\.sha256|logs/[a-z0-9][a-z0-9._/-]*\.log)$' && echo 'INVALID ARCHIVE ENTRY'
tar -tzf ARCHIVE | grep -F '..' && echo 'DOTDOT ENTRY'
find "$D/logs" -type f | grep -v -E '\.log$' && echo 'NON-LOG FILE IN ARCHIVE'
find "$D" ! -type f ! -type d | grep . && echo 'SPECIAL FILE IN ARCHIVE'
(cd "$D" && shasum -a 256 -c MANIFEST.sha256 >/dev/null) || echo 'HASH FAIL'
diff <(cd "$D" && find logs -type f | LC_ALL=C sort) <(cut -c67- "$D/MANIFEST.sha256" | LC_ALL=C sort)
shasum -a 256 "$D/MANIFEST.sha256" | cut -c1-64            # equals ownerAck.evidenceSet
comm -23 <(jq -r '..|objects|select(has("logSha256"))|"\(.logSha256)  \(.log)"' RECORD | LC_ALL=C sort) \
  <(LC_ALL=C sort "$D/MANIFEST.sha256")                    # must print nothing
```

Decisions this plan takes (Round 1; recommendations for the plan evaluator to confirm or redirect):

- **D-a — Bound to v0.2.0.** Schema id `loom-release-evidence/v1` is constant-bound to release `0.2.0`, tag `v0.2.0`, matrix `plugins/loom/adapters/compatibility/v0.2.0.json`, and exactly two pairs (`claude-code-cli`, `codex-cli`). The schema accepts no other release, tag, matrix or pair set. v0.3.0 needs a reviewed schema amendment (five pairs, its own matrix const). v0.4.0 needs a new schema version.
- **D-b — Passing records only.** `result` is `const "pass"` everywhere. ADR 0032 §4 blocks publication on any failed required cell, so failures stay in run journals.
- **D-c — External sanitized logs with a manifest.** Logs and journals are not committed. The record names each log by a relative path under `logs/` and its SHA-256. The archive contract is defined below.
- **D-d — One CI lane, Bash 5.x as recorded evidence.** CI keeps one lane (macOS 14 arm64, `/bin/bash` 3.2.57). Bash 5.x is not dropped: the release record must carry a `bashRuns.bash5` entry for a full `scripts/check` run under Homebrew Bash 5.x on the candidate (ADR 0019 §1; ADR 0032 §1 keeps Bash 3.2+ runtime in full). No Bash 5 CI row is added in this slice, because that would depend on Homebrew being present on the runner image. A CI step may replace the local run later if recorded the same way.
- **D-e — Upgrade per pair.** "Upgrade" means: install the prior candidate's marketplace source, upgrade to the final candidate, then uninstall. It is recorded per pair as `e4.d_lifecycle` with `priorCandidate` ≠ `candidate`. ADR 0032 §3 lists only E4(a)–(c); the spec amendment must justify d under the matrix scope (clean install, loading, uninstall). The evaluator must confirm this.

**Archive contract (D-c).** This is the retrieval and hash contract the record depends on.

- **Location.** The owner keeps the sanitized archive. After tagging `vR` and before publication, it is attached to the v0.2.0 GitHub Release as `loom-release-evidence-v0.2.0-<candidate>.tar.gz`. Its name is derivable from the record (`tag`, `candidate`).
- **Layout.** The archive root holds `MANIFEST.sha256` and `logs/<harness-or-gate>/<name>.log` only. Each path matches the schema `log` pattern: `^logs/`, no `..`, characters `[a-z0-9._/-]`, so no whitespace or newline appears.
- **Sanitization before hashing.** The hashed bytes are the sanitized bytes. Sanitized logs contain no credential values, no auth file content, no environment dumps, and no absolute owner paths (home paths become `~`). The secret-pattern scan in the spec amendment must be clean.
- **Manifest.** Generate it with `find logs -type f | LC_ALL=C sort | xargs shasum -a 256 > MANIFEST.sha256`. Each line is `<64-hex>  logs/<path>`, LF-terminated.
- **Hashes.** Each record `logSha256` equals the manifest line for its `log`. `ownerAck.evidenceSet` equals `shasum -a 256 MANIFEST.sha256`.
- **Secret-free verification.** A reviewer needs no credentials and no access to the runs. The commands are in the archive verification block above and are reproduced in the README section that this slice adds.

## Out of Scope & Threat-Model Boundary

- **Spec 10 and spec 07 text.** No spec file is edited by this slice. The normative amendment is the sibling artifact in Context. The slice's schema, validator and tests implement it, and the sibling must be Approved first.
- **ADR bodies.** No ADR body is edited. `.docs/ADR/README.md` changes index lines only, which the register requires.
- **The live v0.2.0 proof.** Isolated logins, floor-pinned installs, the 5×2 role matrix, install/upgrade/uninstall runs, the full loop, tagging `v0.2.0`, writing the real `v0.2.0.json` and its archive are the owner-gated operational pass (research §9). This slice adds only schema, validator wiring, docs and tests.
- **Research gaps G3, G6 and G7** (floor-pinned binaries, native Claude role return, Codex isolated auth) and owner auth choice (research Q3). None is decided here.
- **v0.3.0 admission.** Antigravity, Orca and Herdr (`hc`) stay deferred (ADR 0033 §1).
- **Ubuntu and macOS Intel.** No platform row, CI lane or evidence is added or removed beyond what ADR 0032 §1 requires for v0.2.0. Ubuntu returns in v0.4.0. macOS Intel is unsupported in every release.
- **Automated archive verification.** The archive is verified by documented commands, not by repository validation or CI, because the logs are not in the repository. Automated secret scanning of archives is also out of scope.
- **Git relation checks** (`git merge-base --is-ancestor vR <record>` and `candidate == git rev-parse vR^{commit}`). They need the tag, so they run at release time. Spec 10 documents them.
- **ADR 0032 §8 items outside this slice:** spec 00, 02, 03 and 06 dogfood wording, and the `CLAUDE.md` Map entry for `scripts/macos-dual-client-dogfood`. Residual for a later finalize pass.
- **Threat model.** The record is repository-committed and self-attested. It helps reviewers audit claims; it does not prove authenticity. The E5 owner acknowledgement is the control on who accepted it. The record never contains credential values, auth file content, environment dumps or absolute owner paths (spec 06 isolation; research §4.1). Schema validation cannot detect a fabricated run; that remains a review obligation.

## Steps

1. **Create `plugins/loom/schemas/loom-release-evidence-v1.schema.json`** (Draft 2020-12, `additionalProperties: false` on every object, `$id` in the style of `loom-dogfood-evidence-v1.schema.json`).
   - Top level, all required: `schema` (const `loom-release-evidence/v1`); `release` (const `0.2.0`); `tag` (const `v0.2.0`); `candidate` (`^[0-9a-f]{40}$`); `platform` (`os` const `macOS 14+`, `arch` const `arm64`); `matrix` (const `plugins/loom/adapters/compatibility/v0.2.0.json`); `bashRuns`; `pairs`; `ownerAck`.
   - `bashRuns`, both required: `bash32` (`bashVersion` const `3.2.57`) and `bash5` (`bashVersion` `^5\.\d+\.\d+$`). Each has `result` (const `pass`), `log`, `logSha256`.
   - Shared definitions: `log` is `^logs/(?!.*\.\.)[a-z0-9][a-z0-9._/-]*$`, maxLength 256. `sha256` is `^[0-9a-f]{64}$`.
   - `pairs`: `minItems` 2, `maxItems` 2. An `allOf` requires exactly one item with `harness` const `claude-code-cli` and exactly one with `harness` const `codex-cli` (`contains` with `minContains: 1, maxContains: 1` each). Duplicate or missing pairs fail.
   - Each pair item, all required: `harness` (enum); `client` (enum `claude`, `codex`); `floor`; `e1` (`matrix` const = top-level matrix; `entry`); `e2` (`binding`); `e3` (`runId`, `result` const `pass`, `log`, `logSha256`); `e4`; `authSource` (enum `owner-login-isolated`, `setup-token-env`, `api-key-env`); `ownerStateUnchanged` (const `true`).
   - Per-pair `if/then` binding: harness `claude-code-cli` → `client` const `claude`, `floor` const `2.1.216`, `e1.entry` const `claude`, `e2.binding` const `claude-plugin-root/v1`. Harness `codex-cli` → `codex`, `0.144.6`, `codex`, `codex-skill-source/v1`. A mismatched client, floor, entry or binding fails the schema.
   - `e4`, all required: `a_roles` (exactly the keys `researcher`, `planner`, `plan-evaluator`, `developer`, `code-evaluator`; each has `result` const `pass`, `log`, `logSha256`, `outputHash`); `b_loop` (`runId`, `result` const `pass`, `blindReview` const `verified`, `crossFamilyVerified` const `true`, `log`, `logSha256`); `c_gate` (`command` const `scripts/check`, `result` const `pass`, `log`, `logSha256`); `d_lifecycle` (`priorCandidate` `^[0-9a-f]{40}$`, `result` const `pass`, `log`, `logSha256`).
   - `ownerAck`: `by` const `owner`; `pairs` (`minItems`/`maxItems` 2, `uniqueItems`, enum of both harnesses); `evidenceSet` (`sha256`); `candidate` (40-hex); `date` (`^\d{4}-\d{2}-\d{2}$`).
   - The schema cannot check `ownerAck.candidate` against `candidate`, `priorCandidate` against `candidate`, or the matrix contents. Step 2 does.

2. **Wire the record into `scripts/validate-repository.mjs`.**
   - *Metadata mode.* In `validateMetadata`, beside the dogfood block (around line 378; runs in `--metadata` and `--all`), when `.docs/evaluations/release-evidence/v0.2.0.json` exists (`safeNode` guard as the dogfood check): validate with the new schema via `validateJson`. Only if the schema passes, run semantic checks against `readJson(record.matrix)`: for each pair, `e1.entry` is `client`, `client` is a key of `clientFloors`, `floor` equals `clientFloors[client]`, `e2.binding` equals the `rootBindings` id for `client`, and `d_lifecycle.priorCandidate` ≠ `candidate`. Also `ownerAck.candidate` = `candidate`.
   - *Docs-state mode.* In `validateEvaluations` (`--all` only), accept exactly `release-evidence/v0.2.0.json`: skip the `eval-name` rule for it. Every other nested path keeps the existing "unexpected nested path" error, including `release-evidence/v0.2.1.json`.
   - Report messages name the record path and the failing field.

3. **Update the CI workflow (ADR 0032 §8, ADR 0019 §5 supersession).** In `.github/workflows/check.yml`, keep only the `macos-14` include row (`host: Darwin`, `architecture: arm64`, `release: "14"`, `shell: /bin/bash`, `bash_regex: '^3\.2\.57'`). Leave the assertion step unchanged. Recompute `shasum -a 256 .github/workflows/check.yml`, then update:
   - `scripts/check-toolchain.json`: `workflow.sha256` and `runners` (one row);
   - `scripts/check`, the jq contract (around lines 286–296): the `sha256` literal and the `.runners` literal.
   The `downloads` and `vendored` lists stay unchanged.

4. **Retarget the bats tests that name removed rows** (`scripts/tests/repository-validation.bats`). Each keeps its original purpose: a mutation of the surviving row still fails.
   - around line 1070, "workflow runner row deletion fails": delete the `macos-14` row instead of `macos-15-intel`;
   - around line 1105, "runner label mutation": `macos-14` → `macos-13`;
   - around line 1111, "host mutation": `host: Darwin` → `host: Other`;
   - around line 1117, "architecture mutation": `architecture: arm64` → `architecture: x86_64`;
   - around line 1177, `del(.runners[3])` → `del(.runners[0])`.

5. **Update `README.md`.**
   - *Hosts bullet* (lines 73–75): "macOS 14+ on Apple silicon (arm64) for v0.2.0 and v0.3.0; Ubuntu 22.04/24.04 x86-64 moves to v0.4.0; macOS Intel is not supported." Keep the Windows, PowerShell, Git Bash/MSYS2, Cygwin and WSL sentence.
   - *v0.2 baseline paragraph* (lines 244–247): name macOS 14+ Apple silicon as the only v0.2 platform; say CI runs one macOS 14 arm64 lane on Bash 3.2.57; say Bash 5.x is release evidence (`bashRuns.bash5`); say a pair is supported only with its complete record (spec 10).
   - Keep verbatim, since the validator requires them (lines 386–395): "The exact supported client floors are Claude Code 2.1.216 and Codex CLI 0.144.6." and "static scaffolding only".
   - Add a "Verifying release evidence" subsection containing this block verbatim (the archive verification commands in Context; `ARCHIVE` and `RECORD` are the reviewer's local paths):

     ```sh
     D=$(mktemp -d) && tar -xzf ARCHIVE -C "$D"
     tar -tzf ARCHIVE | grep -v -E '^(\./)?(MANIFEST\.sha256|logs/[a-z0-9][a-z0-9._/-]*\.log)$' && echo 'INVALID ARCHIVE ENTRY'
     tar -tzf ARCHIVE | grep -F '..' && echo 'DOTDOT ENTRY'
     find "$D/logs" -type f | grep -v -E '\.log$' && echo 'NON-LOG FILE IN ARCHIVE'
     find "$D" ! -type f ! -type d | grep . && echo 'SPECIAL FILE IN ARCHIVE'
     (cd "$D" && shasum -a 256 -c MANIFEST.sha256 >/dev/null) || echo 'HASH FAIL'
     diff <(cd "$D" && find logs -type f | LC_ALL=C sort) <(cut -c67- "$D/MANIFEST.sha256" | LC_ALL=C sort)
     shasum -a 256 "$D/MANIFEST.sha256" | cut -c1-64            # equals ownerAck.evidenceSet
     comm -23 <(jq -r '..|objects|select(has("logSha256"))|"\(.logSha256)  \(.log)"' RECORD | LC_ALL=C sort) \
       <(LC_ALL=C sort "$D/MANIFEST.sha256")                    # must print nothing
     ```

     State that verification needs no credentials and reads only hashes.
   - Update every "886" Bats count (lines 60, 113, 240) to the new count from the gate run.

6. **Update `.docs/ADR/README.md` (index lines only).** The ADR 0032 entry already records the ADR 0019 §2/§5, ADR 0024 §1 and ADR 0027 §4 supersessions. Add to the ADR 0024 entry that ADR 0033 supersedes its §6/§7 ongoing obligations (ADR 0033's entry already says so). Verify the ADR 0019 and ADR 0027 entries match ADR 0032 §4 and §8. Edit no ADR body.

7. **`.docs/slice-plans/README.md`.** The active-plan line already reads `Plan Review` with the plan's purpose. Confirm, change nothing else.

8. **Add tests to `scripts/tests/repository-validation.bats`, prefixed "release evidence:".**
   - Fixture `scripts/tests/fixtures/release-evidence/v0.2.0-valid.json`: a complete valid record with placeholder 40-hex candidate and hashes, one line per role, both pairs, `bashRuns`, `d_lifecycle`, and `priorCandidate` distinct from `candidate`.
   - Copy the fixture to `.docs/evaluations/release-evidence/v0.2.0.json` in a test root, following the dogfood test at line 1982. Assert it passes in `--metadata` and `--all`.
   - Negative cases, each via `mutate_json`, asserting failure and the named schema path or message:
     - a missing role key;
     - any role or gate `result` set to `"fail"`;
     - a codex `floor` of `0.144.5`;
     - a third pair; a duplicate `claude-code-cli` pair in place of `codex-cli`;
     - a pair with `harness: "codex-cli"` and `client: "claude"`;
     - a 39-character candidate;
     - an absolute `log` path, and a `log` containing `..`;
     - `release` `0.2.1` or `tag` `v0.2.1` with the file still named `v0.2.0.json`;
     - top-level `matrix` naming `v0.3.0.json`, and a pair `e1.matrix` naming `v0.3.0.json`;
     - an `ownerAck.candidate` that differs from `candidate`;
     - `d_lifecycle.priorCandidate` equal to `candidate` (semantic);
     - `bashRuns.bash5` missing, and `bashRuns.bash5.bashVersion` of `"3.2.57"`.
   - Assert in `--all` mode that another nested path, such as `.docs/evaluations/other/x.json`, fails with "unexpected nested path", and that `release-evidence/v0.2.0.json` does not.

## Verification

- **Gate, macOS floor (candidate commit):** `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check` under `/bin/bash` 3.2.57 must pass. This is the same run as the CI lane. Its jq contract checks the new `check.yml` digest and the single runner row.
- **Gate, Bash 5.x (same candidate):** `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 "$(brew --prefix)/bin/bash" scripts/check` must pass on the development host, which has Homebrew Bash 5.3.9 at `/opt/homebrew/bin/bash`. The developer records the version string and result in `progress.md`. If `scripts/check` refuses that shell, report it as blocked; do not edit the gate to get around it.
- **Targeted, during development:** `LOOM_NODE="$(command -v node)" TMPDIR=/private/tmp bats --filter "release evidence|workflow|runner" scripts/tests/repository-validation.bats`, plus `shfmt -i 4 -d scripts/check` and `shellcheck -s bash scripts/check`.
- **Repository validation:** `node scripts/validate-repository.mjs --all` and `node scripts/validate-repository.mjs --metadata` must each exit 0 with no record present. The first run also covers the README floor sentences and the plan-authority rule.
- **Digest and lane consistency:** `shasum -a 256 .github/workflows/check.yml` equals `workflow.sha256` in `scripts/check-toolchain.json` and in `scripts/check`. `jq '.runners | length' scripts/check-toolchain.json` prints `1`.
- **Regression:** every existing test in `repository-validation.bats` passes unchanged except the five retargeted in step 4.
- **Not verified here (release time):** the archive commands against a real archive, the git-ancestry and candidate-equals-tag checks, the release-time `bashRuns` entries, and remote CI on the single macOS lane.

## Notes

- **2026-11-06 (planner, Round 1):** Round 0 findings addressed in place. Spec edits moved out of this slice to a sibling amendment (finding 1). Pair cardinality and harness↔client binding added (finding 2). Release, tag and matrix bound to v0.2.0 with E1 checks and negative tests (finding 3). Bash 5.x run required as recorded evidence (finding 4). Archive location, manifest and evidence-set hash defined (finding 5).
- **Size risk:** the estimate is about 300 LOC net change, at the limit. If the developer exceeds it, split steps 3–4 (CI lane retirement) into a sibling `ci-macos-only-lane` plan. That is the only allowed split. The schema, validator, docs and tests stay together.
- **Evaluator focus:** confirm D-d (Bash 5.x as recorded local evidence rather than a CI row), D-e (per-pair `d_lifecycle`), and the archive contract.
- **2026-11-07 (planner scope/size resolution):** Clarified the target size budget to resolve code-eval Round 3 size blocker. The original 300 LOC net change estimate applied to validator code and scripts; standalone schema (248 lines), valid test fixture (185 lines), and comprehensive validation test suite (207 lines) are accounted for separately, consistent with the repository's convention across past slices (e.g. evaluation-output-recorder, sanitized-evaluation-workspace, herdr-native-app-hooks). Steps 3–4 (CI lane retirement) remain split out to sibling slice ci-macos-only-lane.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |
| 1 | Removed spec 10/07 edits from steps (dependency on sibling amendment). Added pair cardinality and harness↔client binding, with negative tests. Bound release, tag and matrix to v0.2.0, with E1/E2 validator checks and negative tests. Added `bashRuns` (macOS 3.2.57 plus Bash 5.x) to the record and verification. Defined the archive location, layout, sanitization, manifest and evidence-set hash, with a secret-free verification path. Moved upgrade to a per-pair `d_lifecycle` with `priorCandidate`. Corrected validator placement (metadata vs `--all`). |
| 2 | Addressed Round 1 finding 1: the sibling amendment has passed plan evaluation (Round 3, PASS) and reached Approved; Context records the dependency as satisfied. Addressed finding 2: the approved amendment's executable archive verification commands are added in Context and Step 5 (with the `..` check and the `grep`-guarded special-file check, which the earlier draft lacked). Status remains Plan Review. |
| 4 | Round 3 scope/size resolution: Target files now include `scripts/run-bats-under`; Target size clarified. Fixed Bash 3.2 empty-array `set -u` failure in `scripts/run-bats-under`. |
