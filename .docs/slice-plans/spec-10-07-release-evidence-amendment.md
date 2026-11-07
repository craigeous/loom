# Proposed spec amendments — v0.2.0 release conformance and evidence

Status: Plan Review
Target specs: 10-packaging.md, 07-command-surface.md
Target size: <= 200 LOC net change (keep document <= 250 lines)

## Context

Drafted diff for the plan evaluator; nothing here is applied. Specs 07 and 10 are frozen
(ADR 0005) and change only after this draft passes cold plan evaluation; discard or revise
this file if ADR 0032 or 0033 is superseded. Authority: ADR 0032 §1, §3–§5, §8 and ADR 0033
§1–§2 (owner decision D3: v0.2.0 live proof first). ADR 0032 §8 lists these edits as "listed,
not drafted"; this draft supplies them and is the dependency of
[release-conformance-and-evidence-schema](release-conformance-and-evidence-schema.md).

Sibling-plan decisions; the evaluator confirms or redirects each:

- **D-a** (redirected in Round 1) The v1 record binds to release 0.2.0, tag `v0.2.0`, two pairs.
- **D-b** One macOS 14 arm64 CI lane on `/bin/bash` 3.2.57; Bash 5.x is recorded evidence.
- **D-c** Lifecycle item (d) per pair: clean candidate install, prior-candidate upgrade, uninstall.
- **D-d** The sanitized log archive is an evidence asset, not a build asset.
- **D-e** Logs are external and hashed; only hashes and metadata are committed.

Not drafted: the v0.3.0 matrix correction and any admission, which enters only through an accepted admission ADR (ADR 0032 §6; ADR 0033 §1).

## Out of Scope & Threat-Model Boundary

- Antigravity, Orca and Herdr (`hc`) are deferred (ADR 0033 §1): no v0.2.0 status, matrix entry or binding. The record is self-attested; it proves consistency, not that a run happened.

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
+Bash obligation: CI runs one macOS 14 arm64 lane on `/bin/bash` 3.2.57, the floor; Bash 5.x
+is required as recorded evidence (`bashRuns.bash5`). Native Windows, PowerShell, Git
+Bash/MSYS2, Cygwin, and WSL are unsupported. Documentation may identify an unverified
+community path but must not imply release support.
+
+**Release status (ADR 0032 §1, as amended by ADR 0033 §1).** A pair is *supported* in release R only if it is REQUIRED in R's row and R's record verifies.

+| Release | Platform | Harness | Status |
+|---|---|---|---|
+| v0.2.0 | macOS 14+ arm64 | Claude Code CLI | REQUIRED |
+| v0.2.0 | macOS 14+ arm64 | Codex CLI | REQUIRED |
+| v0.3.0 | macOS 14+ arm64 | the two v0.2.0 pairs | REQUIRED (carried) |
+| v0.3.0 | macOS 14+ arm64 | any other harness | absent unless admitted by a per-harness ADR under ADR 0033 §1 |
+| v0.4.0 | Ubuntu 22.04, 24.04 x86-64 | fixed by the v0.4.0 planning ADR | not in v0.2.0 or v0.3.0 |
+| any | macOS Intel | any | unsupported |
+
+Antigravity, Orca and Herdr (`hc`) are **deferred** (ADR 0033 §1); a pair in no row is unsupported.
@@ ## Release gate
 - the full local check;
-- Ubuntu and macOS CI, Bash floor/current lanes, and both required client-floor
-  adapter matrices;
+- macOS 14 arm64 CI (`/bin/bash` 3.2.57 lane) and each REQUIRED pair's adapter matrix;
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
+A (platform, harness) pair is supported in release R only when the applicable release row
+(ADR 0032 §1 for v0.2.0, or an accepted per-harness admission ADR under ADR 0033 §1) lists
+it as REQUIRED for R and every element below verifies. ADR 0024 evidence is historical; one
+platform's or harness's evidence is not conformance for another.
+
+Per required pair, the record carries:
+
+- **E1 matrix entry:** the harness in `plugins/loom/adapters/compatibility/vR.json` with its
+  pinned floor, profile mapping and platform.
+- **E2 binding:** `claude-plugin-root/v1` or `codex-skill-source/v1`, plus manifest and
+  catalog loading (manifest and marketplace catalog load; name and version match the release).
+- **E3 offline conformance:** Bats tests in `scripts/check` on that platform for the launch
+  descriptor from `loom-launch-role`, role contract parity across all five roles, the hook/
+  guard behavior the harness exposes, and refusal of unknown and below-floor versions.
+- **E4 live conformance** at the pinned floor. Each run records platform, harness floor, result
+  and log reference (path and `logSha256`): (a) all five roles launched and returned through the
+  harness, each with an output hash; (b) one full loop from research through landing, with blind
+  review (ADR 0022) and every handoff committed; (c) `scripts/check` passing on the platform; (d)
+  in fresh isolated homes, clean install of the candidate; prior-candidate install, then upgrade
+  to the candidate; clean uninstall (ADR 0032 §4–§5). `authSource` names how the isolated client
+  was authenticated (never a value).
+- **E5 owner acknowledgement:** names each pair, the evidence-set hash and the candidate.
+
+Record-level: `bashRuns.bash32` (`/bin/bash` 3.2.57, the CI lane) and `bashRuns.bash5` (full
+`scripts/check` under Bash 5.x) must both pass.
+
+**Record.** `.docs/evaluations/release-evidence/vR.json`, schema `loom-release-evidence/v1`
+(`plugins/loom/schemas/loom-release-evidence-v1.schema.json`), bound to release 0.2.0 and its two
+pairs. Written after the candidate is tagged, so the candidate never contains its own hash.
+Published records are never edited.
+
+**Corrections.** `vR.corr<N>.json`, N = 1, 2, … with no gaps. The current record has the highest N
+(compared as an integer), or is `vR.json` if none exists. Each carries `supersedes: {path, sha256}`
+naming its predecessor, unbroken back to `vR.json`. A correction never changes the candidate.
+
+**Candidate binding.** A record verifies only if (1) `git rev-parse vR^{commit}` equals `candidate`;
+(2) `git merge-base --is-ancestor vR <record-commit>` succeeds and the record is on `main`; (3)
+`ownerAck.candidate` equals `candidate` and each `priorCandidate` differs from it; (4) each pair's
+E1 and E2 entries match the matrix and binding the record names. Items 1–2 are release-time git
+checks; items 3–4, shape, naming, the correction chain and log paths are repo validation. Neither
+can prove that a run happened.
+
+**Sanitized archive.** Logs are not committed. `loom-release-evidence-<tag>-<candidate>.tar.gz` is
+attached before publication and holds only `MANIFEST.sha256` and `logs/<name>.log` files matching
+`^logs/(?!.*\.\.)[a-z0-9][a-z0-9._/-]*$`, sanitized before hashing (no credential values, auth file
+content, environment dumps; home becomes `~`). `MANIFEST.sha256` is `find logs -type f | LC_ALL=C
+sort | xargs shasum -a 256`. Each run's `logSha256` equals its manifest line; `ownerAck.evidenceSet`
+equals `shasum -a 256 MANIFEST.sha256`.

 Workflow-profile policy and target-branch history shape are deliberately not release
 contracts here. They require benchmark evidence and a later accepted decision.
@@ ## Versioned compatibility and capability mapping
-The matrix records `hc` as a host with a floor of `0.1.16` (the only observed
-version) and does not floor herdr-app, which loom does not call. It carries no Herdr
-root binding and no per-profile Herdr entry. A host entry never changes the profile
-map; model and effort are carried in the inner client's command string.
+Herdr (`hc`) is deferred under ADR 0033 §1 and has no entry in the v0.2.0 matrix. The `herdr`
+entries in `v0.3.0.json` (floor `0.1.10`, `herdr-plugin-root/v1`) are stale under ADR 0031 and
+ADR 0032 §6 and are corrected only on admission. A host entry never changes the profile map;
+model and effort are carried in the inner client's command string.
@@ ## Installed-root and helper binding
-- **Herdr.** Herdr has no installed root, manifest, marketplace or hook binding. It is a
+- **Herdr (deferred, ADR 0033 §1; no v0.2.0 binding).** Herdr has no installed root, manifest, marketplace or hook binding. It is a
   host driven through `hc` (spec 07 §Host surfaces); roles it launches resolve helpers
   through their own client's root above. Herdr does not install, host or intercept hooks;
   Claude Code and Codex hooks keep running in their own plugin systems under the
   existing wires of spec 08.
```

## Drafted Diff B — `07-command-surface.md`

```diff
@@ ## Host surfaces (Orca, Herdr `hc`)
+**Status (ADR 0033 §1).** Orca and Herdr (`hc`) are deferred: the text below is design for a future admission, with no v0.2.0 status or matrix entry.

@@ ## Private dogfood workflow and role mapping
-## Private dogfood workflow and role mapping
+## v0.2.0 release conformance workflow and role mapping

-The ADR 0024 code slice must prove these exact client-native workflow pairs:
+The v0.2.0 release conformance run (spec 10, Release conformance evidence; ADR 0032 §3 E4) must
+prove these exact client-native workflow pairs for each required pair, Claude Code CLI and Codex CLI:
@@ ## Private dogfood workflow and role mapping
-These are intended mappings. Codex behavior is pending until the exact-candidate
-dogfood evaluation passes; ChatGPT desktop and Codex IDE are outside this checkpoint.
+These are the v0.2.0 mappings. Each client's behavior counts as supported only when the
+v0.2.0 record verifies for its pair. ChatGPT desktop and Codex IDE are not v0.2.0 surfaces,
+and Antigravity, Orca and Herdr (`hc`) have no mapping in v0.2.0.
```

## Steps (evaluator checklist)

1. **Platform, elements, record.** Status table, E1–E5 and record match ADR 0032 §1, §3 (as amended by ADR 0033 §1); additions are labelled.
2. **Retirement, deferral, size, decisions.** Checks 1–2 and 6 pass; spec 07 role table and pairs unchanged (ADR 0032 §2, ADR 0033 §3); each of D-a to D-e is confirmed or redirected.

## Verification

Checks 1–2 run before approval; check 6 runs on the amended specs; checks 3–5 are release-time and kept apart from repo validation.

1. **Diff fidelity:** every `-` line in Diffs A and B occurs verbatim in its target spec.

```sh
A=.docs/slice-plans/spec-10-07-release-evidence-amendment.md
awk '/^## Drafted Diff/{t=/Diff A/?"10-packaging.md":"07-command-surface.md"; next} /^## /{t=""}
  /^```diff/{d=1; next} /^```/{d=0} d && /^-/ && !/^---/ && length($0)>1 {print t "\t" substr($0,2)}' "$A" |
while IFS="$(printf '\t')" read -r t line; do grep -qxF -- "$line" ".docs/spec/$t" || echo "MISSING $t: $line"; done
```

2. **Size:** net change (added minus removed diff lines) is at most 200; file at most 250 lines.

```sh
awk '/^```diff/{d=1;next} /^```/{d=0} d && /^\+/ && !/^\+\+\+/{a++} d && /^-/ && !/^---/{r++}
  END{print "net=" a-r}' "$A"; wc -l < "$A"
```

3. **Repo validation** (offline): `node scripts/validate-repository.mjs --all` exits 0; once implemented, `--metadata` also checks record shape, names, log paths, corrections, E1/E2.
4. **Release git checks** (`RECORD` = record commit): `git rev-parse "vR^{commit}"` equals `candidate`; `git merge-base --is-ancestor vR RECORD`; after `git fetch origin main`, `git merge-base --is-ancestor RECORD origin/main` succeeds.
5. **Archive and hash checks** (release procedure; no credentials; extract into a new empty directory):

```sh
D=$(mktemp -d) && tar -xzf ARCHIVE -C "$D"
tar -tzf ARCHIVE | grep -v -E '^(\./)?(MANIFEST\.sha256|logs/[a-z0-9][a-z0-9._/-]*)$' && echo 'INVALID ARCHIVE ENTRY'
tar -tzf ARCHIVE | grep -F '..' && echo 'DOTDOT ENTRY'
find "$D/logs" ! -type f && echo 'NON-FILE IN LOGS'
(cd "$D" && shasum -a 256 -c MANIFEST.sha256 >/dev/null) || echo "HASH FAIL"
diff <(cd "$D" && find logs -type f | LC_ALL=C sort) <(cut -c67- "$D/MANIFEST.sha256" | LC_ALL=C sort)
shasum -a 256 "$D/MANIFEST.sha256" | cut -c1-64            # equals ownerAck.evidenceSet
comm -23 <(jq -r '..|objects|select(has("logSha256"))|"\(.logSha256)  \(.log)"' RECORD | LC_ALL=C sort) \
  <(LC_ALL=C sort "$D/MANIFEST.sha256")                    # must print nothing
```

6. **Retirement and deferral invariants** (amended specs; silent on success; each host checked):

```sh
grep -E '(scripts/macos-dual-client-dogfood|loom-dogfood-)' .docs/spec/10-packaging.md .docs/spec/07-command-surface.md && echo 'STALE DOGFOOD NAME'
for h in Antigravity Orca Herdr; do grep -qE "$h.*deferred" .docs/spec/10-packaging.md .docs/spec/07-command-surface.md || echo "UNLABELLED $h"; done
```

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |
| 1 | Addressed F1–F3: restored manifest/catalog loading, offline and live per-run detail, and explicit candidate clean install (F1). Added the per-release status table, admission-based pair support, and Herdr deferral in retained spec 10 text and the spec 07 host section (F2). Defined `vR.corr<N>.json` corrections, split git checks from repo validation, and added executable checks (F3). |
| 2 | Addressed F2: pair support now cites the applicable release row, including an accepted per-harness admission ADR (ADR 0033 §1). Addressed F3: archive check pins the log path pattern and file types (plus a `..` check for the pattern's exclusion); added retirement and per-host deferral checks (6). |
