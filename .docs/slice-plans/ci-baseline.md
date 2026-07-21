# Reproducible local check and dual-platform CI baseline

Status: Plan Review
Target specs: [08-playbook.md](../spec/08-playbook.md),
[10-packaging.md](../spec/10-packaging.md)
Authority: [ADR 0018](../ADR/0018-shared-core-and-client-adapters.md),
[ADR 0019](../ADR/0019-supported-runtime-and-release-contract.md)
Improvement slice: `ci-baseline` (M0)

## Context

This is the first implementation slice in the repository improvement program. Its
single purpose is to make the repository's present behavior reproducibly checkable
before safety or architecture work changes that behavior.

### Verified starting point

The following facts were checked against the repository and installed floor clients
while planning:

- `shfmt -i 4 -d`, ShellCheck, `sh -n`, and all **103 existing Bats tests** pass.
  The observed build-tool versions are shfmt 3.13.1, ShellCheck 0.11.0, and Bats
  1.13.0. The count is a baseline fact, not a value to encode in the gate.
- `claude --version` is 2.1.216. `claude plugin validate plugins/loom --strict`
  fails because `plugins/loom/commands/run.md` line 3 is not valid YAML; it also
  warns that `plugins/loom/.claude-plugin/plugin.json` has no version.
- `codex --version` is 0.144.6. That CLI exposes install/list/remove operations but
  no `plugin validate` command. Codex metadata therefore needs pinned repository
  schema validation now; clean isolated install and behavioral validation remain a
  later adapter/release slice.
- The tree has no `scripts/check`, no `.github/workflows/`, no Codex manifest at
  `plugins/loom/.codex-plugin/plugin.json`, and no Codex catalog at
  `.agents/plugins/marketplace.json`.
- The three shipped executables (`plugins/loom/bin/loom-coord` and the two
  `plugins/loom/hooks/*.sh` files) still declare `#!/bin/sh`; `loom-coord` suppresses
  SC3043 for its non-POSIX `local` use. ADR 0019 instead requires
  `#!/usr/bin/env bash` and Bash 3.2+.

### Slice decisions

1. `scripts/check` is the only documented local gate entry point. It runs stages in
   a stable order, stops at the first failure, prints the failed stage, and uses
   repository-relative discovery so it works from any current directory.
2. The build/test tool contract is exact: shfmt 3.13.1, ShellCheck 0.11.0, Bats
   1.13.0, Claude Code 2.1.216, Node 22.17.0, Ajv 8.17.1, YAML 2.8.0, and
   markdown-it 14.1.0, plus the schema digests recorded by this slice. Production
   floors remain Bash 3.2, Git 2.34, and jq 1.6; a newer conforming Git or jq is
   allowed because these are runtime floors, not build-tool pins.
3. Product metadata introduced here uses `0.2.0`, the version already decided by
   ADR 0019/spec 10. This does not create a release, tag, changelog, or release asset.
4. Claude's floor CLI is the authoritative strict Claude package validator. Codex
   0.144.6 has no equivalent, so checked-in schemas plus repository cross-checks are
   the M0 authority for Codex JSON shape. Both are run locally and in CI.
5. The link gate checks actual Markdown link nodes in living authority, active
   planning/status, root instructions, README, and shipped plugin Markdown. It
   excludes `.docs/evaluations/**` and `.docs/slice-plans/archive/**`, which are
   historical evidence/snapshots, and records any unavoidable broken link in an
   exact allowlist with a reason. It must not silently ignore a directory outside
   those two exclusions.
6. CI covers Ubuntu 22.04, Ubuntu 24.04, and macOS 14. macOS runs the whole gate with
   system `/bin/bash` (the 3.2 floor); Ubuntu runs it with its Bash 5.x. This provides
   the floor/current shell evidence without making Homebrew Bash a macOS runtime
   dependency.

### Explicitly out of scope

- M1 identifier containment, lock ownership/races, schema CAS, destructive cleanup,
  or any other coordinator/hook safety behavior.
- M3 local-review machinery, reviewer prompts, review isolation, or publication.
- The eight Codex workflow skills, shared-role extraction, hook wire adapters,
  compatibility/profile matrix, installed-root binding, project-instruction renderer,
  or `loom doctor`.
- Claude or Codex marketplace add/install, invocation/role/hook/helper behavior,
  upgrade, uninstall, and fresh-clone end-to-end smoke. The missing Codex validate
  command is not replaced by a false CLI check; these behavioral smokes remain
  mandatory before release.
- Release automation, `LICENSE`, `CHANGELOG.md`, tag/release assets, migration notes,
  or publishing `v0.2.0`.
- Full spec-08 mechanical invariants (status transitions, digest rendering, protocol
  fixtures, doctor, and adapter behavior) and broad documentation/status refresh.
- Editing any `.docs/spec/`, `.docs/ADR/`, `.docs/status/`, `.docs/evaluations/`,
  archived plan, or `.docs/slice-plans/README.md` in this implementation slice.

Only validation blockers required by the stages below may change existing product
files. In particular, changing a hook's input field, output, fail direction, parsing,
or state behavior is forbidden here.

## Files in the implementation diff

The developer may add or edit only these paths (fixture children are grouped):

- `.github/workflows/check.yml`
- `.gitignore`
- `.agents/plugins/marketplace.json` (new)
- `.claude-plugin/marketplace.json`
- `plugins/loom/.codex-plugin/plugin.json` (new)
- `plugins/loom/.claude-plugin/plugin.json`
- `plugins/loom/commands/run.md`
- `plugins/loom/bin/loom-coord`
- `plugins/loom/hooks/git-identity-guard.sh`
- `plugins/loom/hooks/precompact-write-ahead-backstop.sh`
- `plugins/loom/skills/loom-playbook/gates/shell.md`
- `scripts/check` (new)
- `scripts/check-toolchain.json` (new)
- `scripts/check-tools/package.json` and `scripts/check-tools/package-lock.json`
  (new, test-only validator/Claude dependencies)
- `scripts/schemas/*.schema.json` (new pinned schema snapshots)
- `scripts/validate-repository.mjs` (new)
- `scripts/tests/metadata-validation.bats` (new)
- `scripts/tests/fixtures/metadata/**` (new)
- `scripts/validation/relative-link-allowlist.txt` (new)
- `README.md`
- `CLAUDE.md`

If an external schema cannot legally be checked in, replace its schema file with a
small checked-in repository-contract schema derived from the documented floor-client
fields and record the upstream URL/version/digest in `scripts/check-toolchain.json`.
Do not fetch a floating schema during `scripts/check`.

## Steps

### 1. Add red metadata and gate-contract tests first

Create `scripts/tests/metadata-validation.bats` and the minimal fixture trees under
`scripts/tests/fixtures/metadata/`. The tests invoke
`scripts/validate-repository.mjs --root <fixture>` so they do not recursively invoke
the full `scripts/check` gate.

Required cases are:

1. a valid two-manifest/two-catalog tree passes;
2. malformed JSON fails and names the file;
3. missing, unterminated, or invalid YAML frontmatter fails and names the file;
4. an unknown frontmatter key or missing required `description`/agent `name` fails;
5. an unknown manifest/catalog field rejected by the pinned client schema fails;
6. either catalog source escaping the repository or resolving to a different physical
   plugin root fails;
7. duplicate manifest/catalog/component names fail;
8. name, exact SemVer, source identity, or supported shared metadata drift between
   the two manifests/catalogs fails;
9. a catalog referencing a missing client manifest fails; and
10. the real repository initially fails for the known `run.md` frontmatter, missing
    Claude version, and missing Codex metadata, then passes after Steps 3–4.

Run the targeted test once before implementing the validator and record the expected
red result in the implementation handoff. Do not assert `103` or any final Bats count;
the new cases legitimately increase it.

### 2. Pin the validation inputs and tool contract

Add `scripts/check-toolchain.json` as the single machine-readable tool contract. It
must contain:

- exact versions for shfmt 3.13.1, ShellCheck 0.11.0, Bats 1.13.0, Claude Code
  2.1.216, Node 22.17.0, Ajv 8.17.1, YAML 2.8.0, and markdown-it 14.1.0;
- Bash/Git/jq production floors from ADR 0019;
- supported CI OS/shell lanes;
- for every vendored schema: client, floor client version, upstream provenance URL
  or documented local provenance, retrieval date, and SHA-256 of the checked-in
  bytes; and
- release artifact URL and SHA-256 per supported OS/architecture for any tool that
  CI downloads directly.

Add `scripts/check-tools/package.json` and its generated lockfile for only the
test-time JavaScript dependencies needed to parse YAML, apply JSON Schema, and invoke
Claude Code 2.1.216 locally. Every direct dependency is exact (no `^`, `~`, `latest`,
or tag range), the lockfile is committed, and install commands use the lockfile with
install scripts disabled unless the pinned Claude package demonstrably requires its
own install script. Keep the resulting `node_modules/` and repo-local tool cache out
of Git via `.gitignore`.

Vendor these immutable, `additionalProperties: false` schema snapshots:

- `scripts/schemas/claude-plugin-2.1.216.schema.json`;
- `scripts/schemas/claude-marketplace-2.1.216.schema.json`;
- `scripts/schemas/codex-plugin-0.144.6.schema.json`;
- `scripts/schemas/codex-marketplace-0.144.6.schema.json`;
- `scripts/schemas/command-frontmatter-v1.schema.json`;
- `scripts/schemas/agent-frontmatter-v1.schema.json`; and
- `scripts/schemas/skill-frontmatter-v1.schema.json`.

Schema filenames include the client/floor or local schema version. The schemas must
permit client-only differences required by each format, but must not permit unknown
fields. The lockfile and schema digests make the contract reproducible; CI must fail
if a digest no longer matches.

### 3. Implement repository metadata, frontmatter, and link validation

Create `scripts/validate-repository.mjs`. It accepts `--root` (default: Git root)
and exactly one of `--metadata`, `--links`, or `--all`; prints one diagnostic per
violation; and exits nonzero if any violation exists. It must use `git ls-files` for
the real repository so caches and untracked dependencies cannot enter validation.

Its checks are exactly:

- parse every tracked `*.json` as JSON;
- extract and YAML-parse frontmatter only from tracked
  `plugins/loom/commands/*.md`, `plugins/loom/agents/*.md`, and
  `plugins/loom/skills/**/SKILL.md`, then validate the parsed object against the
  matching pinned schema;
- validate both manifests and both catalogs against their pinned schemas;
- require product name `loom`, exact SemVer `0.2.0`, and compatible shared
  description/license/repository identity across manifests and every supported
  catalog release field;
- reject duplicate component names, unknown fields, absent manifest/catalog files,
  wrong catalog locations, source path escape/symlink escape, and any catalog source
  that does not resolve to the one physical `plugins/loom/` root;
- parse Markdown with the pinned Markdown parser and validate repository-relative
  file links (and local fragments when the parser exposes stable heading IDs) in all
  tracked `*.md` except the two historical directories decided above; and
- load exact exceptions from `scripts/validation/relative-link-allowlist.txt`, where
  each non-comment line contains file, line/link target, and reason. Fail on a new
  broken link, a malformed/duplicate exception, or a stale exception that no longer
  matches. Do not populate the allowlist with parser false positives or code-block
  text.

The validator does not inspect status transitions, protocol fixtures, digest parity,
role behavior, or install behavior in this slice.

### 4. Make only the metadata changes needed for a green baseline

Apply these narrowly scoped fixes:

- In `plugins/loom/commands/run.md`, quote the entire `argument-hint` scalar so the
  existing human-readable hint is valid YAML; do not change the command body.
- Add `"version": "0.2.0"` to
  `plugins/loom/.claude-plugin/plugin.json`. Add the schema-supported release field
  to `.claude-plugin/marketplace.json` if Claude's pinned marketplace schema supports
  it; never invent a field the client rejects.
- Create `plugins/loom/.codex-plugin/plugin.json` with the common name/version/
  description/license/repository metadata and only Codex-0.144.6-supported fields.
  Its skills pointer may expose only the currently existing `skills/` tree; this
  slice must not fabricate the eight future workflow skills.
- Create `.agents/plugins/marketplace.json` using the Codex 0.144.6 local-source
  shape and exact `./plugins/loom` path. Keep client-specific policy/interface fields
  minimal. If that schema has no catalog version field, the cross-check obtains the
  version from the referenced manifest rather than adding an invalid field.

After these edits, both the positive real-repository metadata test and
`claude plugin validate plugins/loom --strict` must pass with no error or warning.
The Codex result is correctly described as **schema-valid metadata scaffold**, not a
successful install or functioning adapter.

### 5. Migrate the shipped shell declaration to Bash 3.2 without behavior changes

In `plugins/loom/bin/loom-coord`,
`plugins/loom/hooks/git-identity-guard.sh`, and
`plugins/loom/hooks/precompact-write-ahead-backstop.sh`:

- change only the first line to `#!/usr/bin/env bash`;
- remove `loom-coord`'s SC3043 suppression and its “POSIX”/“real sh” justification;
  and
- make no functional rewrite merely to use newer Bash features.

Run each existing Bats suite before and after the shebang-only change. The same
behavior and exit/output assertions must pass under Bash 3.2 and Bash 5.x. Any test
failure that requires logic changes stops this slice for replanning; it is not license
to fold M1 fixes into M0.

Update `plugins/loom/skills/loom-playbook/gates/shell.md` only enough to declare Bash
3.2+, remove the `/bin/sh` detection/“POSIX-sh” wording, name `bash -n`, and point
Loom's concrete repository gate to `scripts/check`. Update the corresponding Gate
paragraph in `CLAUDE.md` from POSIX shell to Bash 3.2+ and the same one-command
pointer. Do not otherwise refresh the instruction digest or create the future root
`AGENTS.md` renderer output.

### 6. Add the single ordered local gate

Create executable `scripts/check` with `#!/usr/bin/env bash`, Bash-3.2-compatible
syntax, strict error handling, a trap that identifies the failed stage, and root
resolution based on the script's physical repository location. Using only the
documented bootstrap prerequisites (`curl`, `tar`, and a SHA-256 utility), it
self-provisions the exact build tools into an ignored repository cache from the
locked URLs and verifies them before execution. It must reject an unsupported
OS/architecture, a Bash below 3.2, Git below 2.34, jq below 1.6, or an incorrect
pinned/cached build-tool version with an actionable diagnostic.

Run these stages in this exact order:

1. verify `scripts/check-toolchain.json`, package lock, and all schema SHA-256 values;
2. install/use the locked test-only validator/Claude dependencies in the ignored
   repository cache, then run `scripts/validate-repository.mjs --metadata`;
3. run `shfmt -i 4 -d -ln bash` over tracked shipped `.sh` files, tracked executable
   extensionless Bash files, and `scripts/check` (NUL-safe discovery, stable sort);
4. run ShellCheck in Bash mode over the same production/check script set;
5. run the selected lane's Bash with `-n` over that same set;
6. discover every tracked `*.bats` file NUL-safely, run `bats --count` on the exact
   discovered list, print `Discovered <n> Bats tests`, then run the same list once;
7. run `scripts/validate-repository.mjs --links`;
8. run `claude plugin validate plugins/loom --strict` using the locked 2.1.216 binary
   and fail on warnings as well as errors; and
9. run `git diff --check`, `git diff --cached --check`, and, when
   `LOOM_DIFF_BASE` is set by CI, `git diff --check "$LOOM_DIFF_BASE...HEAD"`.

The metadata and link stages are two modes of one validator, not duplicate
implementations. Bats files are executed by Bats but are not sent raw to `bash -n`,
because Bats syntax is preprocessed. No count is hard-coded, and no stage is silently
skipped because a client/tool is missing.

### 7. Document the check and support boundary, without a broad README rewrite

Edit `README.md` in three contained places:

- add `scripts/check` and the two client metadata locations to the repository-layout
  block;
- add a short **Development check** section naming the exact pinned build tools and
  one command, `scripts/check`; and
- add a short **Supported runtime** section: Ubuntu 22.04/24.04 x86-64, macOS 14+
  on Apple silicon and x86-64 where the selected client supports it, Bash 3.2+,
  Git 2.34+, jq 1.6+, Claude Code floor 2.1.216, and Codex CLI floor 0.144.6. State
  explicitly that native Windows, PowerShell, Git Bash/MSYS2, Cygwin, and WSL are
  unsupported in v0.2.

Correct the existing optional validation example to the real CLI form
`claude plugin validate plugins/loom --strict`. Do not advertise Codex install or
workflow behavior until its isolated behavior matrix exists. Do not update milestone
status/history in this slice.

### 8. Add pinned Ubuntu/macOS CI

Create `.github/workflows/check.yml`, triggered for pull requests and pushes to
`main`, with least-privilege read-only contents permissions and concurrency
cancellation by ref. Pin every third-party action to a full commit SHA.

Use an explicit matrix with these required cells:

| Runner | Gate shell | Evidence |
|---|---|---|
| `ubuntu-22.04` | runner `/usr/bin/bash` (5.x) | supported LTS + current Bash line |
| `ubuntu-24.04` | runner `/usr/bin/bash` (5.x) | supported LTS + current Bash line |
| `macos-14` | system `/bin/bash` (3.2) | supported macOS family + Bash floor |

Each cell checks out full history, prints OS/architecture, computes `LOOM_DIFF_BASE`
from the event's nonzero base SHA, and invokes the chosen Bash as `scripts/check`'s
interpreter. `scripts/check` installs the exact locked tools and verifies downloaded
checksums; the workflow must not duplicate that logic or use floating Homebrew/apt
versions or a floating `latest` action/tool tag. The workflow does not install Codex
or run an install smoke in this slice; it validates the pinned Codex metadata schemas
through `scripts/check`.

## Red-to-green proof

The implementation handoff must record these transitions:

1. **Metadata red:** the targeted new Bats suite fails against the initial repository
   for invalid `run.md`, absent Claude version, and missing Codex files.
2. **Claude red:** the exact strict command reports the current YAML error and version
   warning.
3. **Metadata green:** all positive/negative metadata fixtures pass and the real tree
   passes schema/cross/path/frontmatter/link validation.
4. **Claude green:** strict validation exits zero with no warning.
5. **Shell green:** all pre-existing behavioral tests still pass after the three
   shebang changes under the macOS Bash 3.2 lane and Ubuntu Bash 5.x lanes.
6. **Unified green:** `scripts/check` exits zero locally and in every required CI
   cell, prints its discovered Bats count dynamically, and `git diff --check` is
   clean for the implementation range.

## Verification

### Local

From a fresh clone with only the documented bootstrap and production prerequisites:

```bash
scripts/check
```

Also prove cwd independence once:

```bash
(cd /tmp && /absolute/path/to/loom/scripts/check)
```

Expected: identical stages and a zero exit. Before committing, run
`git diff --check` and confirm the diff contains only the file set listed above.

### CI

All three matrix cells must be green and retain logs showing:

- OS/architecture and actual Bash version;
- exact shfmt, ShellCheck, Bats, Claude, Node, Git, and jq versions;
- schema digest verification;
- the dynamic Bats test count and passing result;
- strict Claude validation; and
- range-aware whitespace validation.

The macOS log is the Bash 3.2 floor evidence. At least one Ubuntu log must show Bash
5.x. A green JSON/schema result is not recorded as a Codex install/behavior result.

## Acceptance criteria

- A fresh clone reproduces the complete M0 gate through the one documented
  `scripts/check` command.
- The exact build tools and schemas are pinned/reproducible, while production Git/jq
  are enforced as floors.
- Both client manifests/catalogs are syntactically, schema, path, and cross-version
  validated; Claude strict validation is green; Codex behavior is not overclaimed.
- All shipped executables declare Bash and remain compatible with Bash 3.2; all
  existing Bats behavior remains green.
- Relative links in the declared living/shipped scope are checked with narrow,
  reviewable historical treatment.
- Ubuntu 22.04, Ubuntu 24.04, and macOS 14 CI run the same local gate, including Bash
  floor/current evidence and dynamic test-count reporting.
- The implementation changes no M1/M3 behavior, frozen specs/ADRs, status/index docs,
  release assets, or broad documentation outside the two necessary support/gate
  pointers.

## Notes

- Follow-up required before release: implement the complete Claude and Codex isolated
  install/invocation/role/hook/helper/upgrade/uninstall matrices required by spec 10.
  This plan deliberately provides the stable validation entry point and metadata
  scaffolding they will extend.
- Follow-up mechanical checks from spec 08 must be added incrementally with the slice
  that introduces their underlying artifacts; M0 must not pretend absent review,
  evaluation, digest, doctor, or landing protocols are already validated.
