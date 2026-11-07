# Proposed spec amendments — v0.2.0 release conformance and evidence

Status: Plan Review
Target specs: 10-packaging.md, 07-command-surface.md
Target size: <= 200 LOC net change (keep document <= 250 lines)

## Context

This is a **drafted diff for the plan evaluator**. Nothing here is applied. Specs 07 and
10 are frozen (ADR 0005) and change only after this draft passes cold plan evaluation.
If ADR 0032 or ADR 0033 is superseded before approval, discard or revise this file.

Authority: ADR 0032 §1, §3, §4 and §8, and ADR 0033 D3 (owner decision: the v0.2.0 live
proof comes first). ADR 0032 §8 lists the spec 10 and spec 07 edits as "listed, not
drafted", and §3 leaves the evidence file format, the E4 run storage and the archive to a
spec 10 amendment. This draft supplies that text. It is the Dependency named in
[release-conformance-and-evidence-schema](release-conformance-and-evidence-schema.md):
that plan's schema cannot reach Approved until this one does.

Decisions carried into the spec text from the sibling plan (D-a to D-e). The evaluator
confirms or redirects each one:

- **D-a** The v1 record schema binds to release 0.2.0, tag `v0.2.0` and its matrix only.
- **D-b** CI runs one macOS 14 arm64 lane on `/bin/bash` 3.2.57. Bash 5.x is required as
  recorded evidence (`bashRuns.bash5`), not as a CI row.
- **D-c** Upgrade is a per-pair lifecycle item (d): install the prior candidate, upgrade,
  then uninstall.
- **D-d** The sanitized log archive is an evidence asset attached before publication. The
  spec 10 sentence on release assets is narrowed to build assets.
- **D-e** Logs are external and hashed. Only hashes and metadata are committed.

Not drafted here: the v0.3.0 matrix correction (ADR 0032 §6, §8) and v0.3.0 admission.
ADR 0033 §1 defers both until a pair is admitted.

## Out of Scope & Threat-Model Boundary

- No code, schema, matrix, workflow, README, `CLAUDE.md`, ADR or spec edit is made by
  this artifact. The diffs below apply only after approval.
- Antigravity, Orca and Herdr (`hc`) stay deferred (ADR 0033 §1). No workflow or role row
  is added for them. Spec 07 "Host surfaces" is unchanged.
- Ubuntu moves to v0.4.0 and macOS Intel is unsupported. No Ubuntu or Intel row is added.
- The record is self-attested. It proves hash and binding consistency, not that a run
  happened. E5 is the accountability control. No credential, auth file content or
  environment dump is recorded (spec 06 isolation).

## Drafted Diff A — `10-packaging.md`

```diff
@@ ## Authority
-[0022](../ADR/0022-controlled-input-independent-evaluation.md), and
-[0031](../ADR/0031-herdr-as-an-hc-driven-client.md), informed by the
+[0022](../ADR/0022-controlled-input-independent-evaluation.md),
+[0031](../ADR/0031-herdr-as-an-hc-driven-client.md),
+[0032](../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md), and
+[0033](../ADR/0033-narrow-v0.3-scope-and-retire-macos-checkpoint-tooling.md), informed by the
 [approved dual-platform research](../research/2026-07-21-dual-platform-plugin-architecture.md).
@@ ## Supported runtime and platforms
 The v0.2 support matrix is:

-- Ubuntu 22.04 LTS and 24.04 LTS on x86-64;
-- macOS 14+ on Apple silicon and x86-64 where the selected client supports it;
+- macOS 14+ on Apple silicon (arm64), where the selected harness itself is supported;
 - Bash 3.2+, Git 2.34+, jq 1.6+; and
 - one supported client at or above the exact tested floor: Claude Code 2.1.216 or
   Codex CLI 0.144.6.

-Tests run Bash 3.2 and current Bash 5.x. Native Windows, PowerShell, Git Bash/MSYS2,
-Cygwin, and WSL are unsupported in v0.2. Documentation may identify an unverified
-community path but must not imply release support.
+Platform scope (ADR 0032 §1): v0.2.0 and v0.3.0 support macOS 14+ on Apple silicon only.
+macOS Intel is unsupported in every release. Ubuntu 22.04 and 24.04 on x86-64 are v0.4.0
+platforms. The v0.2.0 harnesses are Claude Code CLI and Codex CLI; v0.3.0 adds only pairs
+admitted under ADR 0033 §1. Support is per (platform, harness) pair (see Release
+conformance evidence).
+
+Bash obligation: CI runs one macOS 14 arm64 lane on `/bin/bash` 3.2.57, the floor. Bash
+5.x is required as recorded evidence (`bashRuns.bash5`). Native Windows, PowerShell, Git
+Bash/MSYS2, Cygwin, and WSL are unsupported in v0.2. Documentation may identify an
+unverified community path but must not imply release support.
@@ ## Release gate
 - the full local check;
-- Ubuntu and macOS CI, Bash floor/current lanes, and both required client-floor
-  adapter matrices;
+- macOS 14 arm64 CI (the `/bin/bash` 3.2.57 lane) and the adapter matrix for every
+  REQUIRED pair in the release row (Ubuntu CI is required from v0.4.0);
@@ ## Release gate
-- agreement of manifests, catalogs, helpers, schemas, docs, and release metadata; and
-- proof the `vX.Y.Z` tag resolves to the exact tested commit.
+- agreement of manifests, catalogs, helpers, schemas, docs, and release metadata;
+- proof the `vX.Y.Z` tag resolves to the exact tested commit; and
+- a release conformance record that verifies under Release conformance evidence.

-No v0.2 artifact is published until improvement milestones M0–M7 are green on the
-declared matrix. Release assets derive from that tag and are never edited afterward.
+No v0.2.0 artifact is published until improvement milestones M0–M7 are green on the
+declared matrix and the v0.2.0 record verifies. Build assets derive from that tag and are
+never edited afterward. The sanitized evidence archive is an evidence asset, not a build asset.
@@ ## Private Apple-silicon dogfood evidence
-## Private Apple-silicon dogfood evidence
-
-Before M1, ADR 0024 permits one private Darwin `arm64` checkpoint using exact floors
-Claude Code 2.1.216 and Codex CLI 0.144.6. In isolated client/project homes, each
-client must pass clean marketplace/plugin install, second reinstall, discovery,
-explicit workflow invocation, real cold role launch, hook/trust fixtures, absolute-
-root helper execution, inside/outside-project behavior, and clean uninstall. Evidence
-records commands, versions, roots, exits, structured-output/fixture hashes, and
-before/after inventories.
-
-This checkpoint is not release evidence. v0.2 still requires M0 through M7 and the
-full Ubuntu 22.04/24.04 x86-64 plus macOS 14+ `arm64` and Intel matrix, including
-both pinned-client install/behavior lanes, fresh-clone checks, synchronized metadata,
-and exact tested tag.
+## Release conformance evidence
+
+A (platform, harness) pair is supported in release R only when ADR 0032 §1 lists it as
+REQUIRED and every element below verifies for it. The v0.2.0 required pairs are macOS 14+
+Apple silicon (arm64) with `claude-code-cli` and `codex-cli`. ADR 0024 checkpoint evidence
+is historical and confers no status. Evidence from one platform or harness is not
+conformance for another.
+
+Per required pair, the record carries:
+
+- **E1 matrix entry:** the harness in `plugins/loom/adapters/compatibility/vR.json` with its
+  pinned floor (Claude Code 2.1.216 or Codex CLI 0.144.6), profile mapping and platform.
+- **E2 binding:** `claude-plugin-root/v1` (Claude Code CLI) or `codex-skill-source/v1`
+  (Codex CLI).
+- **E3 offline conformance:** the Bats suites in `scripts/check` on that platform, as a
+  run ID, result and log.
+- **E4 live conformance** at the pinned floor, each run with a log and SHA-256: (a) all
+  five roles launched and returned through the harness, each with an output hash; (b) one
+  full loop from research through landing, with blind review verified (ADR 0022) and every
+  handoff committed; (c) `scripts/check` passing on the platform; (d) lifecycle: install of
+  the prior candidate, upgrade to the candidate, then uninstall. Item (d) is not a new ADR
+  0032 element. It is the clean install/upgrade/uninstall requirement that ADR 0032 §4 and
+  §5 keep, applied per pair.
+- **authSource:** how the isolated client was authenticated (`owner-login-isolated`,
+  `setup-token-env` or `api-key-env`). No credential value or auth file content is recorded.
+- **E5 owner acknowledgement:** names each pair, the evidence-set hash and the candidate.
+
+Record-level, the candidate has two runs: `bashRuns.bash32` (`/bin/bash` 3.2.57, the CI
+lane) and `bashRuns.bash5` (a full `scripts/check` under Bash 5.x, version recorded). Both
+must pass.
+
+**Record.** `.docs/evaluations/release-evidence/vR.json`, schema `loom-release-evidence/v1`
+(`plugins/loom/schemas/loom-release-evidence-v1.schema.json`). The v1 schema is bound to
+release 0.2.0, tag `v0.2.0` and its matrix; a later release needs a new schema version.
+The record is written after the candidate is chosen and tagged, so the candidate commit
+never contains its own hash. Corrections are new files; published records are not edited.
+
+**Candidate binding.** A record verifies only if all of these hold:
+
+1. `git rev-parse vR^{commit}` equals `candidate`;
+2. `git merge-base --is-ancestor vR <record-commit>` succeeds, and the record is on `main`;
+3. `ownerAck.candidate` equals `candidate`, and every pair's `priorCandidate` differs from it;
+4. each pair's E1 and E2 entries match the matrix and binding that the record names.
+
+A change to the candidate requires a new tag and a new record. `validate-repository
+--metadata` checks the shape and these bindings; it cannot prove that a run happened.
+
+**Sanitized archive.** Logs are not committed. The archive
+`loom-release-evidence-<tag>-<candidate>.tar.gz` is attached to the release before
+publication. It holds `MANIFEST.sha256` and `logs/<harness-or-gate>/<name>.log` only.
+Every log path matches `^logs/(?!.*\.\.)[a-z0-9][a-z0-9._/-]*$`. Logs are sanitized before
+hashing: no credential values, auth file content, environment dumps, or absolute owner
+paths (home becomes `~`). `MANIFEST.sha256` is `find logs -type f | LC_ALL=C sort | xargs
+shasum -a 256`. Each record `logSha256` equals its manifest line, and `ownerAck.evidenceSet`
+equals `shasum -a 256 MANIFEST.sha256`. Verification needs no credentials.

 Workflow-profile policy and target-branch history shape are deliberately not release
 contracts here. They require benchmark evidence and a later accepted decision.
```

## Drafted Diff B — `07-command-surface.md`

Lines 94–120 (the section to end of file). The role adapter table and the workflow
pairs are unchanged; only the heading, lead sentence and closing paragraph change.

```diff
@@ ## Private dogfood workflow and role mapping
-## Private dogfood workflow and role mapping
+## v0.2.0 release conformance workflow and role mapping

-The ADR 0024 code slice must prove these exact client-native workflow pairs:
+The v0.2.0 release conformance run (spec 10, Release conformance evidence; ADR 0032 §3 E4)
+must prove these exact client-native workflow pairs for each required pair, Claude Code CLI
+and Codex CLI:
@@ ## Private dogfood workflow and role mapping
-These are intended mappings. Codex behavior is pending until the exact-candidate
-dogfood evaluation passes; ChatGPT desktop and Codex IDE are outside this checkpoint.
+These are the v0.2.0 mappings. Each client's behavior counts as supported only when the
+v0.2.0 record verifies for its pair. ChatGPT desktop and Codex IDE are not v0.2.0 surfaces,
+and Antigravity, Orca and Herdr (`hc`) have no mapping in v0.2.0.
```

## Steps (evaluator checklist)

1. **Platform.** Diff A runtime text matches ADR 0032 §1: v0.2.0 has two REQUIRED pairs,
   macOS 14+ arm64 only, Ubuntu at v0.4.0, macOS Intel unsupported.
2. **Elements.** E1–E5 match ADR 0032 §3 wording. The only additions are `bashRuns` (the
   Bash 3.2+ runtime that ADR 0032 §4 keeps) and item (d) (the upgrade requirement that
   ADR 0032 §4 and §5 keep). Each addition is labelled.
3. **Record.** Path, schema id and binding rules match ADR 0032 §3: `vR.json`, record on
   `main`, descends from the tag, append-only.
4. **Retirement.** No spec 10 or 07 text names `scripts/macos-dual-client-dogfood`, a
   `loom-dogfood-*` schema, or "dogfood" as a support status (ADR 0032 §2, ADR 0033 §3).
   ADR 0024 appears only as history.
5. **Deferral.** Antigravity, Orca and Herdr are named only as deferred (ADR 0033 §1).
6. **Spec 07.** The role table and the workflow pairs are unchanged.
7. **Size.** Net change is within 200 LOC and this file within 250 lines.
8. **Decisions D-a to D-e.** Each is confirmed or redirected.

## Verification

- Mechanical: each non-empty `-` line in Diffs A and B occurs verbatim in its target spec.
- `node scripts/validate-repository.mjs --all` exits 0. This is a snapshot check and does
  not verify status transitions.
- `wc -l` on this file is at most 250. The header has no date and no link before the first
  `##`.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |
