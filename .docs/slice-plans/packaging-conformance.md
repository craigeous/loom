# Packaging Conformance

Status: Approved
Target specs: 00-overview.md, 03-artifact-lifecycle.md, 10-packaging.md
Target size: <= 150 LOC net code change, plus standalone assets and bounded metadata/docs edits

## Context

M7 calls for one coherent packaging contract. Spec 10 already prescribes SemVer,
`v0.2.0`, runtime floors, and release evidence. This slice checks the distribution
against that contract and adds license and changelog checks; it does not establish
that a release has passed its full matrix.

## Out of Scope & Threat-Model Boundary

No release, tag, publication, client-floor change, new platform support, or relaxation
of spec 10's release gate. README's broader refresh is a separate M7 slice; the only
README edit here is the bounded supported-platforms and prerequisites section, including
external plugin dependency status. Preserve historical records, quoted external API
names, and compatibility-required `Task` references. Per spec 00's non-goals, hostile
local code containment and unsupported Windows/WSL environments are outside this slice.
Private macOS dogfood is not public release evidence.

## Steps

1. **Inventory and scope:** Compare spec 10 with `.claude-plugin/marketplace.json`,
   `.agents/plugins/marketplace.json`, `plugins/loom/.claude-plugin/plugin.json`,
   `plugins/loom/.codex-plugin/plugin.json`, the release metadata and helpers under
   `plugins/loom/`, and current README/plugin documentation. Record discrepancies,
   their paths, resolutions, and retained terminology matches in this plan's `## Notes`
   as implementation evidence. Edits are confined to those four manifest/catalog
   files, root `LICENSE` and `CHANGELOG.md`, `scripts/validate-repository.mjs`,
   `scripts/tests/repository-validation.bats`, and the bounded README section above.
   If a discrepancy requires another file or a spec change, stop and return the plan
   as `Needs Clarification` for rescoping or a separately evaluated spec amendment;
   a developer cannot amend the spec inside this slice.
2. **License and history:** Add `LICENSE` using the complete MIT license text from
   <https://opensource.org/license/mit>, with `Copyright (c) 2026 Craig Pfeiffer`.
   Add `CHANGELOG.md` with exact heading `## [0.2.0]` and evidenced changes leading to
   that release, without claiming it has shipped or fabricating a release date.
3. **Version and metadata:** In the four named manifest/catalog files reconcile any
   discrepancies permitted by their client schemas with product version `0.2.0` and
   tag convention `v0.2.0`. Check the release metadata and helper `--version` outputs
   discovered in step 1 against spec 10; a needed edit outside the named files invokes
   the stop rule. Preserve independent schema and protocol versions; build SHAs are
   provenance, not product versions. Do not create a tag.
4. **Support and dependencies:** In the bounded `README.md` section declare Ubuntu
   22.04/24.04 x86-64 and macOS 14+ on Apple silicon and x86-64 where supported by the
   client, Bash 3.2+, Git 2.34+, jq 1.6+, Claude Code 2.1.216 and Codex CLI 0.144.6.
   Preserve spec 10's evidence requirement for newer clients. Inventory the named
   manifests and catalogs for external plugin dependencies; document zero only if
   confirmed, distinguishing system/client tools from plugins. Apply the stop rule
   to any discrepancy requiring an out-of-scope edit.
5. **Terminology:** Run the scoped sweep below over README and current plugin docs.
   Replace references to agents with `Agent` only within the bounded README section;
   retain actual Orca API/task identifiers, compatibility aliases, and ordinary uses.
   Record every retained match and reason in `## Notes`; an actionable match elsewhere
   invokes the stop rule. Historical `.docs/` evidence is excluded from the sweep.
6. **Validation:** In `scripts/validate-repository.mjs`, add an `--all`-only packaging
   check at the final mode dispatch alongside `validateDocsState()`, using `readText()`
   and its `safeNode` required-regular-file checks. Embed the canonical MIT text from
   the source in step 2 as a constant and compare the complete license including the
   exact copyright line, allowing only a final newline difference. Require exactly one
   `## [0.2.0]` heading and at least one nonblank Markdown list item with nonwhitespace
   content before the next level-two heading or EOF. Report the file and failed condition.
   In `scripts/tests/repository-validation.bats`, populate conforming files in shared
   fixture setup for every `--all` root, and add isolated cases for valid files, each
   missing file, altered MIT text or copyright, absent or duplicate version heading,
   and an empty or whitespace-only version section. Confirm `--metadata` and `--links`
   do not impose the new requirement.
7. **Budget and finish:** Estimate net code changes as ~35 lines for
   `scripts/validate-repository.mjs` and ~80 for `repository-validation.bats` (about
   115 total, maximum 150). Standalone assets are separate: `LICENSE` ~21 lines and
   `CHANGELOG.md` ~40 lines. Manifest/catalog and bounded README edits are separately
   limited to ~35 net lines; total estimated net change is ~211 lines across all files.
   If code exceeds 150 lines or any estimate/scope proves infeasible, stop for rescoping.
   Update the plan and index through spec 03's lifecycle; obtain independent code
   evaluation and remote landing evidence as required.

## Verification

Run from the repository root. The jq checks fail on a missing/incorrect version or a
plugin dependency declaration; the Codex catalog must point to the same plugin root
and any version it carries must agree. Inspect all results of the `rg` sweeps and
record the exact allowlisted matches in `## Notes`: Orca API/task identifiers, actual
compatibility aliases, and unrelated ordinary uses only. `rg` exit 1 means no matches.

```sh
jq -e '.version == "0.2.0"' plugins/loom/.claude-plugin/plugin.json
jq -e '.version == "0.2.0"' plugins/loom/.codex-plugin/plugin.json
jq -e '[.plugins[] | select(.name == "loom") | .version] == ["0.2.0"]' .claude-plugin/marketplace.json
jq -e '[.plugins[] | select(.name == "loom") | select(.source == "./plugins/loom") | select((.version // "0.2.0") == "0.2.0")] | length == 1' .agents/plugins/marketplace.json
jq -e 'all(.. | objects; ((.dependencies? // []) | length) == 0)' \
  plugins/loom/.claude-plugin/plugin.json plugins/loom/.codex-plugin/plugin.json \
  .claude-plugin/marketplace.json .agents/plugins/marketplace.json
rg -n -i '(^|[^[:alnum:]_])(task|tasks)([^[:alnum:]_]|$)' README.md plugins/loom -g '*.md' || test "$?" -eq 1
rg -n -i 'plugin.dependencies|dependencies.*plugin|plugin.*dependencies' README.md plugins/loom -g '*.md' -g '*.json' || test "$?" -eq 1
```

Inventory helpers exposing `--version` and execute each identified helper; compare its
output with `0.2.0` and record commands and results in `## Notes`. Compare the release
metadata and any schema-required catalog version/provenance with spec 10; apply the
stop rule to out-of-scope fixes. Run the targeted and full gates (set `LOOM_NODE` to
the pinned absolute Node executable required by the Bats suite):

```sh
TMPDIR=/private/tmp LOOM_NODE="$(command -v node)" bats --filter 'packaging' scripts/tests/repository-validation.bats
TMPDIR=/private/tmp LOOM_NODE="$(command -v node)" bats scripts/tests/repository-validation.bats
node scripts/validate-repository.mjs --root . --all
TMPDIR=/private/tmp scripts/check
```

Release matrix evidence remains a separate release prerequisite.

## Notes

Implementation inventory and retained-match evidence will be recorded here.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |
| 1 | Scoped files and stop rules; specified mechanical checks, validator contract, copyright, budget, and complete gate commands. |
