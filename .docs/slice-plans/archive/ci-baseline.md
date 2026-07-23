# Reproducible local check and dual-platform CI baseline

Status: Archived
Target specs: [08-playbook.md](../spec/08-playbook.md),
[10-packaging.md](../spec/10-packaging.md)
Authority: [ADR 0018](../ADR/0018-shared-core-and-client-adapters.md),
[ADR 0019](../ADR/0019-supported-runtime-and-release-contract.md)
Improvement slice: `ci-baseline` (M0)

## Context

This is the first implementation slice in M0. It makes the current repository
reproducibly checkable and lands the minimum release-owned dual-client metadata,
compatibility, and installed-root contracts that later M0 adapter smokes need. It
does **not** complete ADR 0019's M0 client-behavior obligation: clean install,
workflow/role launch, hook activation, helper resolution, and uninstall remain a
named, release-blocking M0 follow-up after their adapters exist. Schema-valid Codex
metadata is not install or behavior evidence.

### Verified starting point

- `shfmt -i 4 -d`, ShellCheck, `sh -n`, and all **103 existing Bats tests** pass.
  Observed versions are shfmt 3.13.1, ShellCheck 0.11.0, and Bats 1.13.0. The count
  is a planning fact, never a gate constant.
- `claude --version` is 2.1.216. The exact command
  `claude plugin validate plugins/loom --strict` fails because the unquoted
  `argument-hint` in `plugins/loom/commands/run.md` is invalid YAML and warns that
  the Claude manifest lacks a version.
- `codex --version` is 0.144.6. It has marketplace/plugin add, list, upgrade, and
  remove commands but no `plugin validate`; a pinned local contract is therefore
  required for static validation, while an isolated floor-client smoke remains
  independently required.
- There is no `scripts/check`, CI workflow, Codex manifest/catalog, compatibility
  matrix, or installed-root binding metadata in the tree.
- The three shipped executables declare `#!/bin/sh`, while ADR 0019 requires
  `#!/usr/bin/env bash` and Bash 3.2+. More importantly, the existing Bats suites
  explicitly invoke those executables with `sh`; a shebang edit or `bash -n` alone
  would not prove runtime compatibility.
- The repository is public. GitHub's hosted-runner table, checked 2026-07-21,
  identifies standard `macos-14` as arm64 and standard `macos-15-intel` as x86-64;
  `ubuntu-22.04` and `ubuntu-24.04` are x86-64. The plan uses those actual labels,
  not the paid `macos-14-large` label. Source:
  <https://docs.github.com/en/actions/reference/runners/github-hosted-runners>.

### Slice decisions

1. `scripts/check` is the one documented local gate. It uses repository-relative
   discovery, stable stage order, first-failure reporting, and no hard-coded test
   count.
2. Exact test-tool pins remain shfmt 3.13.1, ShellCheck 0.11.0, Bats 1.13.0,
   Claude Code 2.1.216, Node 22.17.0, Ajv 8.17.1, YAML 2.8.0,
   markdown-it 14.1.0, and github-slugger 2.0.0. Bash/Git/jq are runtime
   contracts: Bash 3.2+, Git 2.34+, and jq 1.6+.
3. All introduced product/release-contract metadata uses exact version `0.2.0`.
   This slice does not create a tag, changelog, license, release, or claim that
   v0.2.0 is publishable.
4. The release-owned compatibility matrix records the complete required v0.2.0
   client surfaces and exact profile mapping from spec 10. The gate proves that
   declaration is internally consistent; it does not prove those surfaces work.
5. Every malformed JSON or JSON-Schema test input is checked in with an inert
   suffix such as `.json.in`. Malformed frontmatter is `.md.in`. A Bats helper
   materializes those seeds under `mktemp -d`, with production filenames, only for
   the duration of that test. Consequently no negative fixture can match the real
   tree's tracked `*.json` or shipped-frontmatter scans.
6. Bats is launched by the selected absolute Bash, and every test invocation of a
   shipped Loom script uses that same absolute Bash. A canary proves the Bats
   process and an executable child report the expected `BASH_VERSION`; syntax-only
   evidence is insufficient.
7. CI covers both supported Ubuntu LTS hosts and both macOS architectures. The
   macOS jobs use system `/bin/bash` 3.2 with a controlled invocation; Ubuntu jobs
   use runner `/usr/bin/bash` 5.x. Thus the suite actually executes under the floor
   and current Bash lines.
8. Link checking parses Markdown nodes, excludes only the two named historical
   trees, and uses github-slugger for stable local-fragment IDs. Its negative
   behavior receives its own regression fixtures.

### Explicitly out of scope

- M1 coordinator/hook safety work, including identifier containment, lock races,
  schema CAS, destructive cleanup, or any hook-policy behavior change.
- Shared-role extraction, the eight future Codex workflow skills, hook wire
  adapters/fixtures, installed-root bootstrap code, project-instruction rendering,
  or `loom doctor`.
- Claude/Codex marketplace add or plugin install; workflow/skill discovery and
  invocation; cold-role launch; hook trust/activation; effective model selection;
  helper execution; upgrade; uninstall; and fresh-clone end-to-end behavior. These
  form the subsequent `client-floor-adapter-smoke` M0 slice and must be green before
  M0 can be called complete.
- Release automation, `LICENSE`, `CHANGELOG.md`, migration notes, a Git tag, release
  assets derived from a tag, or publication of v0.2.0.
- Full spec-08 mechanical invariants whose product artifacts do not yet exist.
- Editing frozen specs, ADRs, status/evaluation files, archived plans, or the
  slice-plan index.

Only validation blockers and shell-invocation changes named below may alter existing
product behavior. In particular, no hook input field, output encoding, fail direction,
state transition, or coordinator algorithm changes in this slice.

## Files in the implementation diff

The developer may add or edit only these paths (grouped globs denote children):

- `.github/workflows/check.yml`
- `.gitignore`
- `.agents/plugins/marketplace.json` (new)
- `.claude-plugin/marketplace.json`
- `plugins/loom/.codex-plugin/plugin.json` (new)
- `plugins/loom/.claude-plugin/plugin.json`
- `plugins/loom/adapters/compatibility/v0.2.0.json` (new)
- `plugins/loom/adapters/roots/claude-plugin-root-v1.json` (new)
- `plugins/loom/adapters/roots/codex-skill-source-v1.json` (new)
- `plugins/loom/adapters/fixtures/v0.2.0/metadata/**` (new release-owned fixtures)
- `plugins/loom/schemas/loom-compatibility-matrix-v1.schema.json` (new)
- `plugins/loom/schemas/loom-installed-root-binding-v1.schema.json` (new)
- `plugins/loom/commands/run.md`
- `plugins/loom/bin/loom-coord`
- `plugins/loom/bin/loom-coord.bats`
- `plugins/loom/hooks/git-identity-guard.sh`
- `plugins/loom/hooks/git-identity-guard.bats`
- `plugins/loom/hooks/precompact-write-ahead-backstop.sh`
- `plugins/loom/hooks/precompact-write-ahead-backstop.bats`
- `plugins/loom/skills/loom-playbook/gates/shell.md`
- `scripts/check` (new)
- `scripts/run-bats-under` (new)
- `scripts/check-toolchain.json` (new)
- `scripts/check-tools/package.json` and `scripts/check-tools/package-lock.json`
  (new)
- `scripts/schemas/*.schema.json` (new pinned client/frontmatter schemas)
- `scripts/validate-repository.mjs` (new)
- `scripts/tests/repository-validation.bats` (new)
- `scripts/tests/shell-runtime.bats` (new)
- `scripts/tests/fixtures/**` (new; negative sources use inert suffixes)
- `scripts/validation/relative-link-allowlist.txt` (new)
- `README.md`
- `CLAUDE.md`

If an upstream client schema cannot legally be vendored, use a narrow repository-
contract schema derived from the floor client's documented/observed fields and mark
that provenance honestly. Never label a locally derived Codex schema as an official
Codex validator, and never fetch a floating schema during the gate.

## Steps

### 1. Add red validator and runtime-contract tests

Create `scripts/tests/repository-validation.bats`. Its helper copies a valid fixture
tree to a unique `mktemp -d`, applies one inert overlay by renaming `.json.in` to
`.json`, `.md.in` to `.md`, or `.allowlist.in` to the live allowlist name, runs the
validator against that temporary root, and removes the root in `teardown`. The
checked-in negative-source directory itself must contain **zero** files ending in
`.json` and zero shipped-frontmatter paths ending in `.md`; add an assertion for
that invariant.

Required metadata/contract cases are:

1. a valid two-manifest/two-catalog tree plus compatibility matrix, both root
   bindings, and release-owned metadata fixtures passes;
2. malformed JSON and malformed JSON Schema each fail and name the materialized
   file;
3. missing, unterminated, or invalid YAML frontmatter fails and names the file;
4. unknown frontmatter keys and missing command `description`/agent `name` fail;
5. unknown manifest, catalog, compatibility, or root-binding fields fail through
   an `additionalProperties: false` schema;
6. catalog source escape, symlink escape, or a source resolving to a different
   physical plugin root fails;
7. duplicate manifest/catalog/component names fail;
8. name, exact SemVer, source identity, release provenance, profile mapping, client
   floor, schema version, or binding-reference drift fails;
9. a catalog missing its client manifest, a matrix/root reference to a missing
   file, or a release fixture differing from its live metadata fails; and
10. a dedicated real-tree test invokes `scripts/validate-repository.mjs --metadata`
    at the Git root and passes after implementation, proving tracked negative seeds
    do not poison the production `*.json` gate.

The same suite covers link behavior with temporary `.md` trees:

1. valid relative targets and valid local/cross-file fragments pass;
2. a missing target and a bad fragment fail with source and target;
3. broken links beneath exactly `.docs/evaluations/**` and
   `.docs/slice-plans/archive/**` are ignored, while the same link beneath a
   similarly named or any other directory fails;
4. malformed, duplicate, and stale allowlist records fail; and
5. one exact live broken link may pass only with a nonempty reason, while an
   allowlisted code-block pseudo-link remains stale because code blocks are not
   Markdown link nodes.

Create `scripts/tests/shell-runtime.bats` as the canary. It asserts its own
`BASH_VERSION` equals `LOOM_EXPECTED_BASH_VERSION`, invokes a tiny
`#!/usr/bin/env bash` fixture directly through the controlled PATH, and asserts the
child reports the same interpreter version. Run the new targeted suites before
implementation and record their expected red state. Do not assert 103 or any final
test total.

### 2. Pin the toolchain, schemas, and release-owned static adapter contracts

Add `scripts/check-toolchain.json` as the single machine-readable check contract.
It records:

- the exact tool/dependency versions in Slice decision 2;
- Bash/Git/jq production floors;
- the four CI runner/architecture/shell expectations in Step 8;
- the full `actions/checkout` commit pin
  `11bd71901bbe5b1630ceea73d27597364c9af683`;
- for every downloaded archive/binary, the immutable release URL and SHA-256 for
  each used OS/architecture;
- for every vendored schema and release-owned fixture, its purpose, client/floor or
  local schema version, provenance URL/document, retrieval date, and SHA-256; and
- explicit `kind: upstream` versus `kind: derived-local` provenance so a local
  Codex contract cannot be mistaken for client-supplied validation.

Add an exact-dependency `scripts/check-tools/package.json` and generated lockfile.
Use lockfile installation and disable install scripts unless the exact Claude package
demonstrably requires one. Ignore only the repository-local tool/download/npm caches.

Vendor immutable, closed client/frontmatter schemas in `scripts/schemas/`:

- `claude-plugin-2.1.216.schema.json`;
- `claude-marketplace-2.1.216.schema.json`;
- `codex-plugin-0.144.6.schema.json`;
- `codex-marketplace-0.144.6.schema.json`;
- `command-frontmatter-v1.schema.json`;
- `agent-frontmatter-v1.schema.json`; and
- `skill-frontmatter-v1.schema.json`.

Add release-owned schemas under `plugins/loom/schemas/` for the compatibility matrix
and both root-binding documents. Both use a stable `$id`, exact schema discriminator,
required fields, constrained enums/patterns, and `additionalProperties: false` at
every object boundary.

Create these static release contracts:

- `plugins/loom/adapters/compatibility/v0.2.0.json` records product `0.2.0`, matrix
  schema `loom-compatibility-matrix/v1`, exact client floors 2.1.216/0.144.6, the
  required workflows `run`, `research`, `plan`, `eval-plan`, `develop`, `eval-code`,
  `status`, and `init`; roles `researcher`, `planner`, `plan-evaluator`, `developer`,
  and `code-evaluator`; hook-wire fixture version `hook-wire-v1`; and both installed-
  root binding IDs/paths. Its profile map is literal, not paraphrased:

  | Profile | Consumers | Claude selector | Codex model | Codex effort |
  |---|---|---|---|---|
  | Economy | researcher | `haiku` | `gpt-5.6-terra` | `low` |
  | Standard | developer; orchestrator | `sonnet` | `gpt-5.6` | `medium` |
  | Deep review | planner; plan evaluator; code evaluator | `opus` | `gpt-5.6` | `high` |

  The Claude entries omit reasoning effort. This is a required-surface contract,
  not a passing behavior report; `hook-wire-v1` is an exact future fixture-version
  identifier here, not evidence that the deferred hook adapters already exist.
- `claude-plugin-root-v1.json` declares `claude-plugin-root/v1`, client `claude`,
  injected `CLAUDE_PLUGIN_ROOT`, physical-root/manifest name+version validation,
  direct `bin/` containment, and the current allowlisted helper `loom-coord`.
- `codex-skill-source-v1.json` declares `codex-skill-source/v1`, client `codex`, the
  absolute `skills/<skill>/SKILL.md` suffix/ascend rule, canonical manifest/skill and
  direct-`bin/` checks, forbidden workflow-root guesses (`CLAUDE_PLUGIN_ROOT`,
  `PLUGIN_ROOT`, `CODEX_HOME`, and `PATH`), plus the hook-only `PLUGIN_ROOT` binding
  and `./hooks/hooks.json` path. It does not add bootstrap code.
- `plugins/loom/adapters/fixtures/v0.2.0/metadata/**` contains valid, release-owned
  manifest/catalog/matrix/root-binding fixture inputs. The validator proves these
  fixtures stay schema-valid and semantically equal to the live metadata they model.
  All malformed overlays remain test-only inert seeds under `scripts/tests/fixtures`.

The gate verifies every recorded digest before consuming a schema or fixture.

### 3. Implement repository metadata, contract, frontmatter, and link validation

Create `scripts/validate-repository.mjs`. It accepts `--root` (default: Git root)
and exactly one of `--metadata`, `--links`, or `--all`, prints one deterministic
diagnostic per violation, and returns nonzero if any exists. For the real repository
it obtains the candidate set only from `git ls-files -z`; for temporary non-Git test
roots it performs a deterministic, symlink-safe filesystem walk. In either mode only
the production suffix/location rules below are eligible, so `.json.in`, `.md.in`,
and `.allowlist.in` are inert.

Metadata mode must:

- JSON-parse every tracked real-tree `*.json`;
- YAML-parse frontmatter only in `plugins/loom/commands/*.md`,
  `plugins/loom/agents/*.md`, and `plugins/loom/skills/**/SKILL.md`, then validate it
  with the corresponding pinned schema;
- validate both live manifests, both catalogs, the compatibility matrix, both root
  bindings, and all release-owned fixtures against their pinned schema;
- require product `loom`, exact SemVer `0.2.0`, compatible description/license/
  repository/release identity, exact client floors/profile mapping, unique component
  names, and resolvable matrix-to-binding/schema/fixture references;
- reject wrong catalog locations, path/symlink escapes, and either catalog source
  resolving anywhere except the one physical `plugins/loom/` root; and
- compare each release-owned metadata fixture with its corresponding live semantic
  object so neither can drift unnoticed.

Links mode parses actual Markdown link nodes with markdown-it, derives repeated
GitHub-style heading IDs with github-slugger, percent-decodes fragments safely, and
validates repository-relative files and local/cross-file fragments in every tracked
`*.md` except exactly the two historical trees in Slice decision 8. The allowlist
format is tab-separated source path, exact link target, and nonempty reason. Reject a
new broken link, malformed/duplicate entry, or stale entry. Do not interpret fenced/
inline code or plain URL-like text as links.

### 4. Make the known Claude fix and add dual-client metadata

Apply only these metadata changes:

- Quote the complete existing `argument-hint` scalar in
  `plugins/loom/commands/run.md`; do not change its body.
- Add `"version": "0.2.0"` to the Claude manifest. Add only the release/version
  field supported by the pinned Claude marketplace schema, and require the catalog
  entry to agree with the manifest.
- Create the Codex 0.144.6 manifest with name/version/description/license/repository
  identity and only fields allowed by the pinned local floor contract. It may point
  only at currently existing components; do not fabricate the eight future skills.
- Create the Codex catalog at `.agents/plugins/marketplace.json`, with exact local
  source `./plugins/loom` and schema-supported v0.2.0 provenance. If the client shape
  has no version field, represent version provenance only through the referenced
  manifest/compatibility matrix rather than inventing a field.

The real-tree metadata test, fixture suite, and
`claude plugin validate plugins/loom --strict` must then pass with no error or
warning. Report the Codex result only as a schema-valid metadata scaffold.

### 5. Migrate declarations and test execution to actual Bash

In the three shipped executables, change the first line to
`#!/usr/bin/env bash`; remove `loom-coord`'s SC3043 suppression and obsolete POSIX/
“real sh” justification; make no behavior rewrite.

Mechanically update the three existing Bats suites so every invocation of
`loom-coord`, `git-identity-guard.sh`, or `precompact-write-ahead-backstop.sh` uses
the required absolute `LOOM_TEST_BASH`, including no-jq/PATH-isolation cases. Utility
subshells that are not executing a shipped Loom file may remain `sh`, but no product
test may invoke a shipped file through `sh` or `/bin/sh`. The suite must fail early
if `LOOM_TEST_BASH` is unset, non-absolute, non-executable, or differs from the
expected version.

Create `scripts/run-bats-under`, compatible with Bash 3.2. Given an absolute shell,
expected version regex, and the exact discovered test list, it:

1. resolves the physical shell and rejects a mismatch;
2. creates a temporary `bin/bash` symlink to it and prepends that directory to PATH;
3. exports `LOOM_TEST_BASH`, `LOOM_EXPECTED_BASH_VERSION`, and the physical path;
4. invokes the pinned Bats entrypoint as `"$selected_bash" "$bats_entry" ...`, so
   Bats' `#!/usr/bin/env bash` cannot select Homebrew Bash; and
5. orders the runtime-canary file first and runs the complete discovered list once.

Run the unchanged behavioral assertions before and after the interpreter-only edits.
Any failure requiring product logic changes stops for replanning. Update
`gates/shell.md` and the root `CLAUDE.md` Gate paragraph only enough to declare Bash
3.2+, use `bash -n`, and point to `scripts/check`.

### 6. Add the single ordered local gate

Create executable, Bash-3.2-compatible `scripts/check`. It resolves the repository
from its physical script path, uses strict error handling and a failed-stage trap,
provisions exact tools into an ignored repository cache from the locked URLs, verifies
SHA-256 before extraction/use, and rejects unsupported OS/architecture or below-floor
Bash/Git/jq with actionable diagnostics.

Run these stages in exact order:

1. validate `scripts/check-toolchain.json` and the package lock, then verify every
   schema, fixture, action, and downloaded-tool digest/pin;
2. install the locked JavaScript dependencies and run metadata validation;
3. run `shfmt -i 4 -d -ln bash` over NUL-safe, stable-sorted tracked shipped `.sh`,
   tracked executable extensionless Bash files, and check scripts;
4. run ShellCheck in Bash mode over the same script set;
5. run the selected `LOOM_TEST_BASH -n` over that same set;
6. discover tracked `*.bats` NUL-safely, run pinned `bats --count` on that exact list,
   print `Discovered <n> Bats tests`, then call `scripts/run-bats-under` on the same
   list (the canary proves the actual runtime);
7. run link validation;
8. run the locked Claude 2.1.216 strict validator and fail on warnings or errors; and
9. run working/index `git diff --check` plus range checking when CI supplies
   `LOOM_DIFF_BASE`.

`scripts/check` defaults `LOOM_TEST_BASH` to its own physical interpreter for a local
run. CI always sets it explicitly. Bats files are not passed raw to `bash -n` because
Bats preprocesses their syntax. No stage silently skips a missing client/tool.

### 7. Document the check and support/evidence boundary

Make only these contained documentation edits:

- In `README.md`, add `scripts/check`, both client metadata locations, the
  compatibility matrix, and root bindings to the layout; add a short Development
  check section with the exact pins and one command; and add the approved Ubuntu,
  macOS architecture, Bash/Git/jq, client-floor, and unsupported-Windows boundary.
- Correct the optional Claude validation example to
  `claude plugin validate plugins/loom --strict`.
- State that checked Codex metadata/compatibility/root contracts are static
  scaffolding, not install, hook, role, workflow, or helper evidence.

Do not advertise Codex behavior, refresh milestone history, or broaden the README.

### 8. Add an executable four-host CI matrix

Create `.github/workflows/check.yml` for pull requests and pushes to `main`, with
read-only contents permission, ref-based concurrency cancellation, full-history
checkout, and only `actions/checkout` pinned to the full SHA in Step 2. Use this
explicit matrix:

| Runner label | Asserted host | Selected shell | Runtime evidence |
|---|---|---|---|
| `ubuntu-22.04` | Linux x86-64, Ubuntu 22.04 | `/usr/bin/bash`, major 5 | supported LTS + current Bash line |
| `ubuntu-24.04` | Linux x86-64, Ubuntu 24.04 | `/usr/bin/bash`, major 5 | supported LTS + current Bash line |
| `macos-14` | Darwin arm64, macOS 14 | `/bin/bash`, `3.2.57` | minimum macOS family + Apple silicon + Bash floor |
| `macos-15-intel` | Darwin x86-64, macOS 15 | `/bin/bash`, `3.2.57` | supported macOS Intel + Bash floor |

Each job fails before the gate unless `uname -s`, `uname -m`, OS release, the
selected shell's physical path, and `BASH_VERSION` match its row. It computes a
nonzero event base into `LOOM_DIFF_BASE`, then invokes:

```text
LOOM_TEST_BASH=<absolute row shell> \
LOOM_EXPECTED_BASH_VERSION=<row regex> \
<absolute row shell> scripts/check
```

The logs must show the canary's Bats-shell and executable-child shell versions, not
just `bash --version` or syntax output. The controlled Bats launcher prevents
`#!/usr/bin/env bash` from resolving a Homebrew Bash on macOS.

The labels above are standard hosted labels for this public repository as verified
from GitHub's current official runner table. Because `macos-14` is in deprecation,
if it or `macos-15-intel` is unavailable when implemented, stop and replan against
the then-current official table; do not substitute an unconfigured larger or
self-hosted label and do not mark an absent cell allowed-to-fail.

## Red-to-green proof

The implementation handoff records:

1. **Known Claude red:** the exact strict command reports the current `run.md` YAML
   error and missing-version warning.
2. **Validator red:** targeted new tests fail before validator/contracts exist.
3. **Fixture-isolation green:** all negative cases fail only in their temporary
   roots; `git ls-files '*.json'` contains no malformed fixture; the explicit
   real-tree metadata test is green.
4. **Static adapter green:** both manifests/catalogs, matrix, root bindings, and
   release fixtures pass schema/digest/referential/drift checks; this is not logged
   as client install or behavior success.
5. **Claude green:** strict validation exits zero with no warning.
6. **Link green:** positive/negative target, fragment, exclusion, and allowlist
   tests pass, followed by the real-tree link gate.
7. **Actual-shell green:** logs from macOS show Bats and its child under Bash 3.2.57;
   Ubuntu logs show both under Bash 5.x. All pre-existing behavioral assertions pass.
8. **Unified green:** `scripts/check` succeeds locally, cwd-independently, and in
   all four required CI cells, with dynamic test count and clean range diff check.

## Verification

### Local

From a fresh clone with documented bootstrap/production prerequisites:

```bash
scripts/check
(cd /tmp && /absolute/path/to/loom/scripts/check)
```

Also run the targeted validator suite with one malformed `.json.in` materialized and
show that the subsequent real-root `--metadata` invocation remains green. Before
committing, run `git diff --check`, inspect `git status --short`, and prove the diff
contains only the file set above.

### CI

All four required jobs must be green. Retained logs show host OS/architecture, actual
selected Bash and canary child versions, exact pinned tools, schema/fixture digests,
dynamic Bats count, real-tree metadata/link results, strict Claude validation, and
range-aware whitespace validation. A missing/queued-unavailable architecture cell is
not success.

## Acceptance criteria

- A fresh clone reproduces the complete baseline gate with `scripts/check`.
- Exact build tools, client/frontmatter schemas, product schemas, and release-owned
  fixtures are pinned and digest-checked; runtime floors are enforced.
- Both manifests/catalogs and the v0.2.0 compatibility/root-binding scaffolding are
  schema/path/cross-version/drift validated without overclaiming Codex behavior.
- No tracked malformed JSON/schema/frontmatter input matches production scans, and
  an executable test proves the real-tree metadata gate stays green alongside every
  negative case.
- Link regression tests cover targets, fragments, exact exclusions, and malformed,
  duplicate, live, and stale allowlist entries.
- The shipped scripts declare Bash, and Bats plus every tested Loom script actually
  run under Bash 3.2 on macOS and Bash 5.x on Ubuntu.
- CI is required on Ubuntu 22.04/24.04 x86-64, macOS Apple silicon, and macOS Intel,
  using verified hosted labels with no allowed failure.
- No M1/M3 behavior, frozen authority, status/index artifact, or release publication
  work enters the diff.
- The handoff explicitly leaves M0 incomplete until `client-floor-adapter-smoke`
  supplies the clean install/loading/invocation/role/hook/helper/uninstall evidence
  mandated by ADR 0019 and spec 10.

## Notes

### Implementation gate evidence (2026-07-21)

- Known Claude red reproduced before the fix: `claude plugin validate
  plugins/loom --strict` exited 1 under Claude Code 2.1.216, reporting the
  `commands/run.md` YAML parse error and the missing manifest-version warning.
- Validator red reproduced against base `b28a74754e2ee016a035fa085f0d91de66057f62`
  with the new targeted suite overlaid: the valid dual-client metadata test
  exited 1 because `.agents/plugins/marketplace.json` and the release contracts
  did not exist.
- Fixture isolation: the filtered malformed-JSON test and subsequent real-tree
  metadata test both passed; `scripts/validate-repository.mjs --metadata` then
  passed at the Git root. `git ls-files` shows the four malformed sources only
  with `.json.in`, `.md.in`, or `.allowlist.in` suffixes.
- Floor gate: `LOOM_TEST_BASH=/bin/bash
  LOOM_EXPECTED_BASH_VERSION='^3\.2\.57' /bin/bash scripts/check` exited 0.
  It dynamically discovered 123 Bats tests; the canary logged Bats and its
  executable child at `3.2.57(1)-release`. Metadata, link, pinned Claude strict,
  and working/index diff stages passed.
- Current/cwd-independent gate: from `/tmp`,
  `LOOM_TEST_BASH=/opt/homebrew/bin/bash
  LOOM_EXPECTED_BASH_VERSION='^5\.3\.' /opt/homebrew/bin/bash
  /Users/craig/git/loom-worktrees/ci-baseline/scripts/check` exited 0. The same
  123 tests passed and both canary processes logged `5.3.9(1)-release`.
- Locked strict validation printed `Validation passed` with no warning for
  Claude Code 2.1.216. Static Codex metadata, compatibility, root bindings, and
  release fixtures passed schema, digest, reference, path, and drift checks;
  this is not Codex install or behavior evidence.
- `.github/workflows/check.yml` declares all four required runner cells; the local
  gate now compares every row and field exactly with `check-toolchain.json`, and
  isolated mutations prove deletion or drift fails. Exact-head remote execution
  remains required external evidence and is not claimed by this local handoff.
- M0 remains incomplete until `client-floor-adapter-smoke` supplies the deferred
  clean install, invocation, cold-role, hook, helper, upgrade, and uninstall
  evidence for both exact client floors.

- Required next M0 slice: `client-floor-adapter-smoke`, after the workflow, role,
  hook-wire, and root-bootstrap adapters exist. It runs both exact floor clients in
  isolated homes through clean marketplace/plugin loading, explicit invocation,
  cold-role non-delegation, hook fixtures/trust, effective profiles, absolute helper
  resolution, and uninstall. Neither this plan nor its green gate waives that work.
- Upgrade and fresh-clone release-candidate evidence remains at the spec-10 release
  gate; no v0.2 artifact is published before M0-M7 are green.
- Later slices add spec-08 checks with the artifacts they introduce; this baseline
  does not pretend absent review/evaluation/doctor/landing protocols are validated.

### Developer revision after code-evaluation Round 1 (2026-07-21)

- The revision closes all confirmed Round-1 findings with isolated regressions for
  authenticated private tool extraction/cache publication, cache symlinks, exact
  workflow/toolchain closure, selected-Bash floor and launcher cleanup, rendered
  heading fragments, exhaustive release metadata boundaries/drift, safe contained
  reads, exact root-binding pairs, and CI credential scrubbing.
- The complete local gate passed under `/bin/bash` 3.2.57 and Homebrew Bash 5.3.9,
  with 192 dynamically discovered Bats tests in each lane plus metadata, links,
  formatting, lint, syntax, pinned Claude strict validation, and diff checks.
- Required external handoff: the root orchestrator must push the final exact commit
  and retain successful logs for `ubuntu-22.04`, `ubuntu-24.04`, `macos-14` arm64,
  and `macos-15-intel` x86-64. This developer did not push and does not claim those
  four exact-head CI cells passed.

### Hosted CI attempt 29855001240

- Exact prior head `6c5c77b` ran all four required cells. Every cell passed the
  192-test Bats suite, metadata and link validation, shfmt, ShellCheck, Bash syntax,
  and pinned Claude strict validation, then failed the final range-wide
  `git diff --check` on three pre-existing evaluation-file EOF blank lines.
- This failed attempt is not CI success. The three reported EOF-only defects are
  restored byte-for-byte to slice base `b28a747` and therefore removed from the
  implementation diff. The root orchestrator must retarget the draft PR to that
  remote authority base, and all four required cells must rerun on the new exact
  head before remote CI evidence can be claimed.

### Developer revision after code-evaluation Round 2 (2026-07-21)

- Pull-request and push jobs now checkout, assert, and log the exact event head
  before repository-controlled code. Credential scrubbing remains in front of the
  gate, and isolated workflow mutations cover the ref, expected SHA, assertion,
  log, action pin, and every runner field.
- Every cache hit is copied to a private run-owned snapshot and authenticated there
  before use; fresh-download publication uses a separate inode. Cache ownership,
  modes, symlinks, concurrent rewriting, and cleanup have isolated regressions.
- Metadata equality is object-order-insensitive while retaining array order;
  homepage identity, empty allowlist reasons, cleanup ownership, unique parallel
  sentinels, and every closed toolchain class have direct regression coverage.
- The launcher and toolchain regressions now live only in the two approved test
  files. Both complete local gates passed all 211 dynamically discovered tests on
  Bash 3.2.57 and Bash 5.3.9, with every other ordered stage green.
- Required external handoff: retarget the draft PR to remote base `b28a747`, push
  the final exact head, and retain successful exact-head logs for all four required
  runner cells. This local revision makes no remote CI success claim.

### Developer revision after diagnostic Round 3 (2026-07-21)

- The installed-root documents, shared closed schema, release fixtures, digest
  contract, semantic equality check, and isolated mutations now cover absolute
  inputs/invocations, canonical physical inputs/roots/manifests, the exact Codex
  `skills/<skill>/SKILL.md` suffix and `../..` ascent, manifest/skill identity,
  direct `bin/` containment, the sole `loom-coord` helper, and its regular-file and
  executable requirements. These remain static declarations, not bootstrap code.
- Metadata discovery rejects catalog-shaped tracked JSON outside the two exact live
  paths and two named release fixtures. A distinct JSON-read failure sentinel keeps
  valid `null`, `false`, `0`, and `""` inputs in schema validation, produces
  deterministic file-specific target/schema diagnostics, and prevents semantic
  validation after structural failure.
- The launcher, gate, and workflow assertion completely resolve final and multihop
  relative Bash symlinks with a bounded loop check. Regressions cover terminal and
  multihop links, retargeting/removing the original links after resolution, and
  loop rejection. Bats version probing uses the resolved selected Bash with a
  private selected-shell PATH; a poisoned ambient `bash` is never executed.
- Gate cleanup is attached to `EXIT`; HUP, INT, and TERM have separate handlers
  that deterministically return 129, 130, and 143. Focused process-controlled
  checks verified each status, private-run cleanup, and absence of the success
  marker.
- Both complete local gates passed all 226 dynamically discovered tests: system
  Bash 3.2.57 and resolved Homebrew Bash 5.3.9. Metadata, link validation, shfmt,
  ShellCheck, Bash syntax, pinned Claude strict validation, and diff whitespace
  stages also passed in both lanes.
- Required external handoff: push the final exact commit only after orchestration
  approval and retain successful exact-head logs for `ubuntu-22.04`,
  `ubuntu-24.04`, `macos-14` arm64, and `macos-15-intel` x86-64. This developer did
  not push and makes no remote CI success claim.

### Valid bootstrap merits Round 1 (2026-07-21)

- The protected transition ref was initialized and freshly verified at
  `367584c3b3d0423af04194171e35c827d069a744` before this run. The three earlier
  review/evaluation rounds predated that latch and remain invalid diagnostics; they
  do not authorize publication or consume merits rounds.
- Exact implementation head `c92464aefb6189f40227abd0904d20d2efb7debe`
  and tree `c4573aae54abb81ba524f52c3e93a7e57301ca56` passed both complete local gates
  with 226 tests. GitHub Actions run `29865566135` passed all four required exact-head
  cells with the same count and final success marker.
- Sealed manifest `bfe36caa897196f3995dac8524e987d4c0efa526a3606ba44e550370f093cb65`
  produced aggregate findings
  `e0d404fdcd357e5bfd62c058b8c4026226722d49d4ad4676a59329193717e61d`.
  Independent evaluator verdict
  `8a5afa8f17899fcee81bfb373b5ebfbd7f1612d0a7f9471a836a979024ccb281`
  is `FAIL`, Round 1, requiring Round 2.
- The evaluator's authoritative strictly sequential reruns both passed 226/226 on
  clean unchanged exact trees. Earlier concurrent attempts are retained only as
  infrastructure diagnostics because deterministic global test paths collided.
- Round 2 must close the two confirmed BLOCKERs and six MAJOR gaps: semantic,
  comment-safe workflow validation; fail-closed explicit-root Git/non-Git discovery;
  both exact README client floors; standalone positive allowlist suppression; all
  three unknown-frontmatter-key cases; the complete validator CLI contract; and final
  exact-head cwd-independent gate evidence for both local Bash lanes.

### Developer revision for valid bootstrap merits Round 2 (2026-07-21)

- Explicit-root discovery now compares the canonical requested root with Git's
  canonical top level before using `git ls-files`. A positively non-Git root,
  including an untracked root nested beneath a parent worktree, is walked without
  following symlinks. A root Git marker, canonicalization failure, or tracked-file
  discovery failure fails closed; the forced-failure regression proves an untracked
  malformed JSON canary is never read.
- README states the exact supported floors, Claude Code `2.1.216` and Codex CLI
  `0.144.6`, while retaining the static Codex-scaffolding limitation. Metadata
  validation enforces the exact combined statement, and a direct regression drifts
  each client floor independently.
- Retained tests now include a standalone live allowlist success with no broken-link
  diagnostic; independent unknown-key failures for command, agent, and skill
  frontmatter; and the CLI's nested-cwd default root, valid/failing `--all`, missing
  mode, repeated mode, and mixed-mode exit-2 contracts.
- `scripts/check` no longer greps workflow text. The closed toolchain record carries
  a reviewed exact-workflow SHA-256 plus the checkout action/ref/fetch-depth/
  credential and exact-head execution declarations. The gate accepts only that exact
  byte contract, so inline-comment spoofing, commented-out settings, duplicate YAML
  keys, relocated assertion strings, row deletion, and every retained workflow
  mutation fail before repository code executes. No new dependency or lockfile
  update was needed.
- Focused verification passed all 126 tests in
  `scripts/tests/repository-validation.bats`, including the new trust-boundary,
  README, CLI, allowlist, frontmatter, and workflow mutations.
- Final full-gate commands were run strictly sequentially from cwd `/tmp` using the
  absolute check path and base `b28a74754e2ee016a035fa085f0d91de66057f62`:
  - Bash 3.2 command:
    `env LOOM_DIFF_BASE=b28a74754e2ee016a035fa085f0d91de66057f62 LOOM_TEST_BASH=/bin/bash LOOM_EXPECTED_BASH_VERSION='^3\.2\.57' /bin/bash /Users/craig/git/loom-worktrees/ci-baseline/scripts/check`
    — PASS, selected `/bin/bash` `3.2.57(1)-release`, dynamically discovered and
    passed 243/243 Bats tests, ending `All checks passed`.
  - Bash 5.3 command:
    `env LOOM_DIFF_BASE=b28a74754e2ee016a035fa085f0d91de66057f62 LOOM_TEST_BASH=/opt/homebrew/bin/bash LOOM_EXPECTED_BASH_VERSION='^5\.3' /opt/homebrew/bin/bash /Users/craig/git/loom-worktrees/ci-baseline/scripts/check`
    — PASS, resolved `/opt/homebrew/Cellar/bash/5.3.9/bin/bash`
    `5.3.9(1)-release`, dynamically discovered and passed 243/243 Bats tests,
    ending `All checks passed`.
- Both lanes also passed the exact workflow/toolchain digest, locked JavaScript
  install, metadata and link validation, shfmt, ShellCheck, Bash syntax, Claude
  `2.1.216` strict plugin validation, and diff-whitespace stages. No remote push or
  hosted-CI claim is made by this developer handoff.

### Valid bootstrap merits Round 2 (2026-07-22)

- Exact implementation head `c85cdd6e944473817daae4cdc53dc736ac85d2d5`
  and tree `42b815a416b2bfc807941df1e3f3c5a23fcc3b26` passed both complete
  cwd-independent developer gates with 243 tests. Exact-head GitHub Actions run
  `29871936814` passed all four required cells with the same count and final success
  marker.
- Sealed manifest `556f6ddc89dd0f09a23d5d6d782168567ec9022d925bd0149867fe2d265ed04c`
  and input inventory
  `99ae338fd6eda0772b4af0eac02899da7ab45745984a347622b8a63712cdcafb`
  produced aggregate findings
  `ea9462777cb0de0565470c32eb08fe1c9c30a8415e92beed849b9adf5faae34a`.
  Independent evaluator verdict
  `a3d18bc202c1cc4311c52b7eb237789116bac682baa1b9e3a86b49835468b74e`
  is `FAIL`, Round 2, requiring Round 3.
- A quota interruption stopped the security worker before it produced output. Under
  ADR 0023 section 8, the failure was recorded as infrastructure-only; after limits
  reset, every sealed input reverified hash-identical and only the failed stage
  resumed. Its completed output was clean and did not consume a merits round.
- The evaluator's fresh, strictly sequential Bash 3.2 and Bash 5.3 reruns both passed
  243/243 tests with unchanged exact trees and source inventories.
- Round 3 must replace the newly added client-visible unqualified “blind evaluation”
  wording with ADR 0022's controlled-input independent-evaluation claim and add
  isolated regressions for that wording, below-floor/exact-boundary Git and jq
  versions, and first-failure stage attribution at two stages.

### Developer revision for valid bootstrap merits Round 3 (2026-07-22)

- README, both client manifests and catalogs, and their release-owned metadata
  fixtures now use ADR 0022's exact claim, “independent cold-agent evaluation with
  controlled inputs.” The metadata validator checks README, all four live client
  surfaces, and all seven release-owned metadata fixtures for unqualified `blind`,
  `impartial`, anonymous, or impossible claims. An isolated table-driven regression
  proves every surface rejects one prohibited form, while a narrow legacy term passes
  only when immediately qualified by the exact required claim. Fixture digests were
  refreshed, and README still says the Codex contracts are static scaffolding only.
- Safe test-owned `git` and `jq` shims delegate every operation except `--version`.
  Isolated cases prove Git 2.33 and jq 1.5 fail with the actionable required-floor
  diagnostic, while the exact Git 2.34 and jq 1.6 boundaries pass the runtime gate.
- The gate now has a failure-only test control that stops at a named stage with a
  chosen nonzero status. Regressions fail first at `toolchain contract and pinned
  digests` with status 67 and later at `locked JavaScript dependencies and metadata
  validation` with status 73. Each proves the original status, exact single
  `FAILED stage <stage> (exit <status>)` diagnostic, correct stage advancement, and
  absence of every asserted later-stage marker.
- Focused verification passed all 134 tests in
  `scripts/tests/repository-validation.bats`. Both complete gates then passed all 251
  dynamically discovered tests plus metadata, links, shfmt, ShellCheck, Bash syntax,
  pinned Claude strict validation, and diff-whitespace stages. Final exact-tree
  commands were run strictly sequentially from cwd `/tmp`:
  - Bash 3.2:
    `env LOOM_DIFF_BASE=b28a74754e2ee016a035fa085f0d91de66057f62 LOOM_TEST_BASH=/bin/bash LOOM_EXPECTED_BASH_VERSION='^3\.2\.57' /bin/bash /Users/craig/git/loom-worktrees/ci-baseline/scripts/check`
  - Bash 5.3:
    `env LOOM_DIFF_BASE=b28a74754e2ee016a035fa085f0d91de66057f62 LOOM_TEST_BASH=/opt/homebrew/bin/bash LOOM_EXPECTED_BASH_VERSION='^5\.3' /opt/homebrew/bin/bash /Users/craig/git/loom-worktrees/ci-baseline/scripts/check`
- No tag, release, publication, push, or hosted-CI success is claimed by this
  developer handoff. The root orchestrator must bind and run fresh exact-head hosted
  evidence before the Round-3 bootstrap review/evaluation.

### Valid bootstrap merits Round 3 (2026-07-22)

- Exact head `b6d87a21a7df54b4be6c29b4fa73bf3ef9d971fe` and tree
  `5b1d788ce2d8ae59cd91e3aec5dc39748996db31` passed both local developer gates
  and exact-head GitHub Actions run `29937249418` in all four required cells, with
  251 tests and the final success marker in every lane.
- Sealed manifest `0cbb3cd8b58b2f43f0b98d79d36a5d06cbc022c2ded5943ffe0a45eac42590f0`
  and input inventory
  `ba2af4b2f435451bdc81edec2be6e6278835eadde5360745f03e19e0ec308a5b`
  produced aggregate findings
  `dd4fef582948c2dacf5e6a5e963970f5088de6dccbcf284f060c0ce562452d11`.
  Independent evaluator verdict
  `b32d040ae5c62dada73d2fc7e5622650b2970a0ae9d588bd3c2d19cde8ecce0f`
  is `FAIL`, Round 3, requiring Round 4.
- The evaluator's fresh, strictly sequential Bash 3.2 and Bash 5.3 reruns both passed
  251/251 with clean unchanged exact trees and byte-identical tracked inventories.
- Correctness and security were clean. The sole confirmed MAJOR is missing negative
  coverage for the required unsupported-host rejection. Round 4 must add isolated
  unknown-OS and unsupported-architecture cases that assert the exact diagnostic and
  prove provisioning/download code is not reached.

### Developer revision for valid bootstrap merits Round 4 (2026-07-22)

- Two isolated negative cases now control `uname` through a test-owned shim while
  preserving native OS answers for the gate's preceding cache-safety probes. One
  case supplies the unknown OS `Plan9`; the other supplies the supported native OS
  with unsupported architecture `riscv64`. Both require status 1 and exactly one
  complete `Unsupported check host: <os> <architecture>` diagnostic.
- Selective test-owned `jq` and `curl` shims create a marker if the gate enters the
  download-record lookup or attempts a download. Both cases prove that marker is
  absent and that no pinned-download message is emitted, so rejection precedes
  provisioning. No production seam or `scripts/check` behavior changed.
- Focused verification passed all 136 tests in
  `scripts/tests/repository-validation.bats`. Both complete gates then passed all 253
  dynamically discovered tests plus metadata, links, shfmt, ShellCheck, Bash syntax,
  pinned Claude strict validation, and diff-whitespace stages. Final exact-tree
  commands were run strictly sequentially from cwd `/tmp`:
  - Bash 3.2:
    `env LOOM_DIFF_BASE=b28a74754e2ee016a035fa085f0d91de66057f62 LOOM_TEST_BASH=/bin/bash LOOM_EXPECTED_BASH_VERSION='^3\.2\.57' /bin/bash /Users/craig/git/loom-worktrees/ci-baseline/scripts/check`
  - Bash 5.3:
    `env LOOM_DIFF_BASE=b28a74754e2ee016a035fa085f0d91de66057f62 LOOM_TEST_BASH=/opt/homebrew/bin/bash LOOM_EXPECTED_BASH_VERSION='^5\.3' /opt/homebrew/bin/bash /Users/craig/git/loom-worktrees/ci-baseline/scripts/check`
- No tag, release, publication, push, or hosted-CI success is claimed by this
  developer handoff. The root orchestrator must bind and run fresh exact-head hosted
  evidence before the Round-4 bootstrap review/evaluation.

### Valid bootstrap merits Round 4 (2026-07-22)

- Exact head `df3714f1fa60d3ea41df9c07e821b2204b304979` and tree
  `2697ba389b9b59952279f11f17316d4816e9c88a` passed both developer gates and
  all four exact-head CI cells at 253 tests.
- Manifest `de34b8a93064b5ef2b3bc1c1acc0dbd8ae736c9dcb917377a61bac186aa0bfad`,
  aggregate `f9847c8104dc74af4c54083c58d74d2d1828db79cd7a7fbe95423c531b48ed66`,
  and independent verdict
  `9dfcb9aedcb48961aeeb682a54dab9d036471ac5f832572d8c0af80da993cd9f`
  bind a Round-4 `FAIL` requiring Round 5.
- Round 5 must mechanically enforce all three exact shipped-script Bash shebangs and
  close the unsafe hard-linked cache-entry chmod path with fail-closed metadata checks
  and an outside-sentinel regression.

### Developer revision for valid bootstrap merits Round 5 (2026-07-22)

- The toolchain-contract stage now requires the literal first line
  `#!/usr/bin/env bash` on `plugins/loom/bin/loom-coord`,
  `plugins/loom/hooks/git-identity-guard.sh`, and
  `plugins/loom/hooks/precompact-write-ahead-backstop.sh`. Three isolated mutations
  replace exactly one shipped shebang with `#!/bin/sh` and prove each path fails with
  its own deterministic diagnostic.
- Shared cached downloads are never chmodded or otherwise repaired in place. Before a
  cache entry is copied, the gate requires the current user as owner, mode `600`, and
  hard-link count exactly one using the supported Darwin and Linux `stat` interfaces;
  any mismatch returns explicitly from `fetch`, including under Bash 3.2 command-
  substitution semantics. Only an acceptable entry is copied to the private run
  directory, where the private inode is mode-normalized and digest-authenticated
  before use.
- The cache regression hard-links the cached shfmt artifact to an outside sentinel
  with mode `666`. Provisioning rejects the link count and proves the sentinel's
  SHA-256 and mode are unchanged. The retained symlink, ownership, digest-race, and
  private-provisioning cases remain green. Focused verification passed all 140 tests
  in `scripts/tests/repository-validation.bats`.
- Both complete gates passed all 257 dynamically discovered tests, metadata, links,
  shfmt, ShellCheck, Bash syntax, pinned Claude strict validation, and diff-whitespace
  stages. After this documentation update, the final exact-tree commands were rerun
  strictly sequentially from cwd `/tmp`:
  - Bash 3.2:
    `env LOOM_DIFF_BASE=b28a74754e2ee016a035fa085f0d91de66057f62 LOOM_TEST_BASH=/bin/bash LOOM_EXPECTED_BASH_VERSION='^3\.2\.57' /bin/bash /Users/craig/git/loom-worktrees/ci-baseline/scripts/check`
  - Bash 5.3:
    `env LOOM_DIFF_BASE=b28a74754e2ee016a035fa085f0d91de66057f62 LOOM_TEST_BASH=/opt/homebrew/bin/bash LOOM_EXPECTED_BASH_VERSION='^5\.3' /opt/homebrew/bin/bash /Users/craig/git/loom-worktrees/ci-baseline/scripts/check`
- No tag, release, publication, push, or hosted-CI success is claimed by this
  developer handoff. The root orchestrator must bind and run fresh exact-head hosted
  evidence before the Round-5 bootstrap review/evaluation.

### Valid bootstrap merits Round 5 (2026-07-22)

- Exact implementation head `c52ff8260c90dc4e0961752e9d6fcc8107075d2e` and tree
  `82e6953cd412c5171967d41fb063f97d7512ba15` passed both sealed local gates at
  257 tests and all four exact-head CI cells in run `29948739525`.
- Manifest `1600467825f4a3358b1f81f690fb0a2d785d447d515c9116e2dca1baf7a88ccf`,
  sealed input inventory
  `33aa8ab7e38c3dfecdb81651858fd723aaa4a255591953ae21e36e06e115a8b6`, and
  clean aggregate
  `6b4df9699e178ba8ef31029558ed618e8c9394f9d02efeff7a68b49f62e60909`
  bind three complete cold auxiliary reviews with zero findings.
- Independent verdict
  `3a14a5f254f7798e9642ffb5351b6810ac659fb2bb86696db50c175d0d8a6e73`
  is `PASS`, with zero BLOCKER, MAJOR, or MINOR findings and no next round.
- The evaluator's fresh Bash 3.2 and Bash 5.3 gates ran strictly sequentially,
  passed 257/257 tests, and ended with unchanged exact trees, clean status, and
  matching inventories. The slice advances to `Ready to Publish`; it is not yet
  `Landed`, and no release or tag is authorized by this result.

### Prospective publication finalization (2026-07-23)

- The atomic publication candidate archives this plan and records the `ci-baseline`
  slice as prospectively landed from configured remote base
  `c7bd84d997afb32f6159628eb840a9dd8d2d3dca`.
- The candidate replays the sealed 32-commit prerequisite-authority segment and
  21-commit M0 segment without rewriting, ending at reviewed evidence head
  `cd6b5e17e04168d8e8472b4c55600c6a2aa6a5b9` before finalization.
- These `Archived`/`Landed` statements have no authority while local. They become
  authoritative only after non-force publication, fresh exact remote verification,
  a bound receipt, and protected-transition settlement under ADRs 0020, 0023, and
  0024.
- Publication review round 0 rejected an added link-allowlist policy entry as outside
  ADR 0024's post-merits finalization authority. Round 1 removes that entry and keeps
  the immutable ADR 0023 link resolvable with a non-active pointer at the declared
  plan path; the archived plan remains the sole completed plan artifact.
- Publication review round 1 passed on exact head
  `fbebaa3ce840c4b43931d2a7e96653cef539afe7`: three cold workers returned no
  findings, the distinct evaluator confirmed `COR-001` closed, hosted CI passed all
  four 257-test cells, and fresh Bash 3.2/Bash 5.3 evaluator gates passed 257/257.
  Final evidence recording still requires an exact-candidate gate before guarded
  publication and remote verification.
