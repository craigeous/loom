# Local Review Helper

Status: Plan Review
Target specs: 04-orchestrator.md, 05-blind-evaluation.md, 08-playbook.md, 10-packaging.md
Target size: <= 700 LOC net change excluding tests/schemas (keep this plan document <= 250 lines)

## Context

ADR 0021 defines `loom-local-review/v1`: exact `base_sha`/`head_sha` inputs, a
hash-bound manifest, per-finder JSON results, finder states, and an aggregate result
where any pending/failed/invalid/missing finder makes the whole run `invalid`. ADR 0022
requires the code evaluator to receive a sanitized, evidence-complete workspace that
includes a valid local-review artifact. Today no helper implements any of this; review
still depends on external `/code-review` and `/security-review` (ADRs 0010/0011).

This slice adds only the deterministic helper, `plugins/loom/bin/loom-review`, its two
JSON Schemas, helper registration, and Bats tests. Finder prompts/agents
(`local-review-agents`) and orchestration/command/spec rewiring
(`local-review-orchestration`) are separate M4 slices. The helper never launches a
finder; it prepares inputs, validates results, assembles the companion artifact,
reports status, and cleans scratch runs.

## Out of Scope & Threat-Model Boundary

- No finder prompts, review agents, client launch adapters, or edits to commands,
  playbook, rubrics, specs 02/04/05, or ADRs 0010/0011 (later M4 slices). The
  ADR 0021 consequence that specs 02/04/05 need amendment stays pending there.
- No change to the code evaluator's sole PASS/FAIL ownership, ADR 0022 workspace
  construction, or landing logic. `assemble` output is advisory evidence only.
- Defense is against accidental or sloppy finder output (spec 00 Non-goals): no hostile
  local inode swapping, concurrent filesystem tampering mid-command, or monkeypatched
  helpers. Hash checks detect modification of exports/results after `prepare`; they are
  not a sandbox and not authentication. The run directory is assumed private (`0700`).
- Network-silent: the helper never invokes a network command, remote, or `git fetch`;
  all git use is local object access. Tests assert this with a remote-less clone.
- Docs-only slices keep the aggregate `skipped: docs-only` result; deciding that is
  orchestrator policy, not helper behavior (the helper does not classify slices).

## Steps

Conventions: Bash 3.2+, `set -euo pipefail`, Git 2.34+, jq 1.6+ (no `mapfile`,
associative arrays, or `${var,,}`), `shfmt -i 4`, `shellcheck -s bash` clean. Style
mirrors `loom-land`/`loom-verify-identity`: `_usage`, `_die`, per-subcommand
functions, exit codes `0` ok, `1` usage/environment error, `2` target/content
rejection (invalid run), `3` run state not complete (status only). Hashing uses
`shasum -a 256` (macOS) falling back to `sha256sum`; canonical JSON is `jq -S -c`.

1. **Schemas** (`plugins/loom/schemas/`), draft 2020-12, `additionalProperties: false`,
   `$id` pattern as sibling schemas:
   - `loom-local-review-manifest-v1.schema.json`. Required: `protocol` (const
     `loom-local-review/v1`), `run_id` (`^[a-z0-9][a-z0-9._-]{0,63}$`), `slice`,
     `loom_version`, `helper_version`, `base_sha`/`head_sha` (`^[0-9a-f]{40}$|^[0-9a-f]{64}$`),
     `head_tree`, `diff_sha256`, `files[]` (`path`, `status` enum `A|M|D|R|C|T`,
     `old_path` required when `R|C`, `binary` bool, `old_mode`, `new_mode`,
     `added`/`deleted` line counts or null when binary, `ranges[]` of
     `{start,end}` new-side changed line ranges), `inputs[]` (`kind` enum
     `plan|spec|adr|gate-evidence`, `path`, `sha256`), `finders[]` (`id`, `prompt`
     `{protocol,version,sha256}`, `output` relative path, `adapter`, `model_profile`),
     `source_export` `{path,sha256,file_count}`, `created_at` (RFC 3339 UTC),
     `manifest_sha256`. `finders` has `minItems: 3` and the three required IDs below
     are enforced in code (schema cannot express "contains all").
   - `loom-local-review-findings-v1.schema.json` (one finder result). Required:
     `protocol`, `run_id`, `manifest_sha256`, `finder` `{id, prompt_version,
     prompt_sha256}`, `base_sha`, `head_sha`, `diff_sha256`, `status` enum
     `ran-with-findings|ran-clean|failed`, `findings[]`, `provenance` `{adapter,
     model_profile, started_at, finished_at, truncated: bool, exit_status}`. Each
     finding: `id` (`^[A-Z]{2,5}-[0-9]+$`), `finder`, `confidence` (0..1),
     `severity` enum `BLOCKER|MAJOR|MINOR|NIT`, `file`, `line` or `line_end`,
     `claim`, `evidence`, `verification` (non-empty strings). `ran-clean` requires
     `findings: []`; `ran-with-findings` requires `minItems: 1` (via `if/then`).
2. **Registration.** Add `loom-review` to `ALLOWED_HELPERS` in
   `plugins/loom/bin/loom-resolve-helper` and to the allowlist in every metadata copy,
   keeping the existing order plus the new name last:
   `plugins/loom/adapters/roots/claude-plugin-root-v1.json`,
   `plugins/loom/adapters/roots/codex-skill-source-v1.json`, both fixtures
   `plugins/loom/adapters/fixtures/v0.2.0/metadata/{claude,codex}-root.json`, the
   `const` array in `plugins/loom/schemas/loom-installed-root-binding-v1.schema.json`,
   and the two `allowedHelpers` literals in `scripts/validate-repository.mjs`
   (~lines 517, 526). Update the order-sensitivity mutation at
   `scripts/tests/repository-validation.bats:458` and add resolve cases for
   `loom-review` to `plugins/loom/bin/loom-resolve-helper.bats` (claude and codex,
   mirroring the `loom-verify-identity` cases at lines 72-83; stub helper at line 35).
   Re-check with `grep -rn 'loom-verify-identity' --exclude-dir=.git` that no copy is missed.
3. **Run layout.** Runs live under `<git-common-dir>/loom/review/<run_id>/` (never
   tracked; the same untracked-state home as `loom-coord`). `--run-dir` may override
   with an absolute path whose parent exists (used by tests and by ADR 0022 workspace
   export). Contents: `manifest.json` (canonical JSON, final key ordering, hash field
   last-written), `source/` (export), `inputs/` (copies of plan/specs/gate evidence
   at recorded hashes), `diff.patch`, `results/<finder-id-sanitized>.json` (written
   by finders, not the helper), and `state.json` (helper-only: `phase`, `validated`
   verdict, `aggregate`). `/` in finder IDs is mapped to `__` in filenames.
4. **`prepare`** — `loom-review prepare --slice <name> --base <sha> --head <sha>
   --plan <path> [--spec <path>]... [--adr <path>]... --gate-evidence <path>
   [--run-id <id>] [--run-dir <dir>] [--repo <path>]`. Fails closed (exit 2, no run
   directory left behind: build in a sibling temp dir, then `mv` into place) when:
   a. `--base`/`--head` is not a full 40/64-hex string, does not resolve via
      `git rev-parse --verify --quiet <sha>^{commit}` to itself, or is ambiguous
      (symbolic, abbreviated, tag/branch name, `A..B` or `^` syntax); base is not an
      ancestor of head (`merge-base --is-ancestor`); base equals head.
   b. The working tree is dirty: any output from `git status --porcelain
      --untracked-files=all --ignore-submodules=none`, or HEAD is not `head_sha`
      (the checkout must equal the reviewed head — the current checkout is not
      itself a target, so the helper requires equality and exports from objects).
   c. Any `--plan`/`--spec`/`--adr`/`--gate-evidence` path is missing, outside the
      repo, a symlink, or not a regular file. Plan and specs are read from the
      working tree and must be tracked and unmodified at `head_sha` (`git diff
      --quiet`, `git cat-file -e head:path`). Gate evidence may be untracked
      (it lives in scratch); it is copied into `inputs/` and hashed.
   d. A submodule or gitlink appears in the diff (unsupported in v1; reject rather
      than silently skipping).
   Then: capture `git diff --raw -z --find-renames --find-copies -M -C
   --no-ext-diff base head` into the `files[]` inventory (status, old/new paths,
   modes, `--numstat -z` for binary detection where numstat is `-\t-`), changed-line
   ranges from `git diff -U0 --no-ext-diff --no-color` hunk headers (new-side; deleted
   files use old-side ranges flagged `side: old`), save `diff.patch`, and compute
   `diff_sha256` over the exact patch bytes (`git diff --binary --full-index -M -C
   --no-ext-diff --no-color base head`). Export source with `git archive --format=tar
   head | tar -x -C source/` (no `.git`; run with `-c core.attributesFile=/dev/null`
   so export-ignore/export-subst attributes do not alter the snapshot). Hash the export as SHA-256 over a sorted
   `path\0mode\0blobhash` listing (mode + content; stable across tar timestamps) and
   record `file_count`. Mark `source/` read-only (`chmod -R a-w`; remove on `clean`
   after `chmod -R u+w`). Declare the required finders `review-correctness/v1`, `review-tests/v1`, `review-security/v1`; because prompt assets belong to `local-review-agents`, `prepare` takes `--prompt-hash <finder-id>=<sha256>` (repeatable, required for all three) and records it with prompt version `v1`. Compute `manifest_sha256` as SHA-256 of canonical JSON with that field
   omitted, then write it. Print the run directory path on stdout.
5. **`validate`** — `loom-review validate <run-dir|run-id> [--quiet]`. Pure local
   read; never modifies `source/`, `inputs/`, or results. Checks, collecting all
   failures into `state.json.errors` and exiting 2 on any:
   - manifest present, schema-valid (jq structural checks mirroring the schema; if
     `check-jsonschema`/`ajv` is unavailable the helper does not depend on it — the
     JSON Schemas are validated by `scripts/validate-repository.mjs` and by a Bats
     test using the repo's validator), `protocol` exactly `loom-local-review/v1`
     (unknown protocol or any other major rejected, exit 2, never guessed), and
     recomputed `manifest_sha256` matches.
   - `inputs/` hashes match; `diff.patch` hash equals `diff_sha256`; re-derive the
     diff from `base_sha..head_sha` in the repo when reachable and compare (skipped
     with a recorded note if the repo/objects are absent, e.g. in an exported
     workspace); source export hash recomputed equals `source_export.sha256`
     (**modified source exports** rejected, including added/removed/mode-changed files).
   - Required finder set is exactly the three IDs; every declared finder has exactly
     one result file (missing → `invalid: missing`; two files mapping to one ID →
     duplicate); unknown extra result files rejected.
   - Each result is valid JSON (`jq -e .`, UTF-8), schema-valid, and its `protocol`,
     `run_id`, `manifest_sha256`, `base_sha`, `head_sha`, `diff_sha256`, finder ID,
     `prompt_version`, and `prompt_sha256` match the manifest. Unknown prompt version
     or unknown protocol → invalid.
   - `status: failed`, `provenance.truncated: true`, nonzero `provenance.exit_status`,
     or a status inconsistent with the finding count → finder `failed`/`invalid`;
     whole run `invalid` (no partial assembly).
   - Every finding's `file` is in `files[]` and its `line`/`line_end` intersects a
     recorded changed range (deleted files: old side; binary files: `line` omitted
     and the path must be listed). **Locations outside the reviewed diff** invalid.
     Duplicate finding IDs within a run invalid.
   - Aggregate: `ran-with-findings` if any finder has findings, else `ran-clean`,
     only when all three are valid; otherwise `invalid`. Write `state.json`
     (`validated: true|false`, per-finder state from the ADR vocabulary, `aggregate`)
     and print one line per finder plus `aggregate: <state>`.
6. **`assemble`** — `loom-review assemble <run-dir|run-id> --out <path>`
   (default `.docs/evaluations/<slice>-review-findings.md` under the repo). Refuses
   (exit 2) unless it just re-runs `validate` and the aggregate is `ran-clean` or
   `ran-with-findings`; never assembles from an invalid run and never overwrites a
   `--out` outside the repo's `.docs/evaluations/` unless `--out` is explicit.
   Output is identity-neutral markdown: header (protocol, run ID, aggregate state,
   base/head, diff hash, manifest hash, aggregate-findings hash), provenance table
   (finder, prompt version/hash, adapter, model profile), then findings sorted by
   (file, line, id), each rendered as in existing `*-review-findings.md` artifacts
   (`## COR-1 — proposed MAJOR`; Worker/Location/Confidence/Claim/Evidence/Suggested
   verification). No author names, hostnames, absolute paths, or timestamps beyond
   manifest `created_at`; deterministic output (byte-identical on re-run). Atomic
   write via temp file + `mv`.
7. **`status`** — `loom-review status <run-dir|run-id> [--json]`. Read-only; reports
   phase (`prepared|collecting|validated|invalid|assembled`), per-finder state
   (`pending` when no result, else last recorded validation state), and aggregate.
   Exit 0 when aggregate is valid, 3 when still pending/incomplete, 2 when invalid,
   1 on usage/unreadable run. `pending` here is the only place that state appears; a
   `validate` with a pending finder is `invalid`, per ADR 0021 §3.
8. **`clean`** — `loom-review clean (<run-id>... | --all | --older-than <days>)
   [--repo <path>]`. Removes only directories under `<git-common-dir>/loom/review/`
   that contain a `manifest.json` with the expected protocol (never an arbitrary
   path; refuse symlinks and any path escaping the review root after `cd -P`).
   `chmod -R u+w` before `rm -rf`. Prints removed run IDs. Does not touch committed
   `.docs/evaluations/*-review-findings.md`.
9. **Docs touched in this slice (minimal).** Add a short "Helper contract" subsection
   to `plugins/loom/skills/loom-playbook/references/review-findings.md` listing the
   five subcommands, exit codes, and run layout, stating that orchestration still
   uses the legacy commands until `local-review-orchestration`. No spec/ADR edits;
   spec amendments belong to the orchestration slice.

## Verification

Gate (once, on the candidate commit): `TMPDIR=/private/tmp LOOM_BATS_JOBS=4
scripts/check`, plus `node scripts/validate-repository.mjs --root "$PWD" --all`.
Iteration: `shfmt -i 4 -d plugins/loom/bin/loom-review`, `shellcheck -s bash
plugins/loom/bin/loom-review`, `TMPDIR=/private/tmp bats --filter '<pattern>'
plugins/loom/bin/loom-review.bats`.

`plugins/loom/bin/loom-review.bats` builds a throwaway repo per test (`setup` makes a
base commit, a head commit exercising modify/add/delete/rename/mode-change/binary
paths, a plan, spec, and gate-evidence file, and no remote). Required tests:

- **prepare accept/record:** records exact SHAs, tree ID, diff hash equal to an
  independently computed `git diff --binary --full-index` hash; inventory marks
  renamed (with `old_path`), binary, added, deleted; changed ranges match hunks;
  export has no `.git` and matches `git ls-tree`; inputs hashed; manifest hash
  recomputes; schema-valid against the manifest schema.
- **prepare reject:** abbreviated SHA, branch name, tag, `HEAD`, `A..B`, nonexistent
  SHA, base == head, base not ancestor, dirty tracked file, untracked file, HEAD != head,
  missing/symlinked/out-of-repo plan, tracked-but-modified spec, gitlink in diff,
  missing `--prompt-hash`; each exits 2 and leaves no run directory.
- **network-silent:** runs with `GIT_ALLOW_PROTOCOL=none`, a PATH shim for
  `curl`/`wget`/`ssh` that fails the test if invoked, and no remotes configured.
- **validate accept:** hand-written fixture results for all three finders (mix of
  `ran-clean` and `ran-with-findings`) → aggregate correct, exit 0; all-clean →
  `ran-clean`.
- **validate reject:** missing finder; duplicate/extra result; invalid JSON;
  schema violation; unknown protocol (`loom-local-review/v2`); unknown prompt
  version/hash mismatch; manifest hash/run ID mismatch; `status: failed`;
  `truncated: true`; `ran-clean` with findings and the converse; finding outside diff
  (unchanged file, line outside ranges, nonexistent path); modified source export
  (edited, added, removed, chmod'd file); modified diff/input; each → exit 2, aggregate
  `invalid`, and **never** `ran-clean`.
- **assemble:** refuses invalid/pending runs without writing; output identity-neutral
  (grep finds no user name, email, hostname, or absolute path), deterministic across
  two runs, findings sorted, atomic (no partial file on failure injected via read-only
  target directory).
- **status:** exit codes 0/2/3/1 for valid, invalid, pending, missing run; `--json`
  output parses with `jq`.
- **clean:** removes only a named run; `--all`; `--older-than`; refuses paths outside
  the review root, symlinked run dirs, and dirs without a matching manifest; read-only
  `source/` is removed.
- **registration:** `loom-resolve-helper` resolves `loom-review` for claude and codex;
  `scripts/validate-repository.mjs --all` passes; the root-binding mutation test still
  catches reordered/missing allowlist entries.
- **Regression (unchanged tests):** `loom-resolve-helper.bats`,
  `scripts/tests/repository-validation.bats`, `loom-coord.bats`, and
  `loom-verify-identity.bats` must pass unchanged apart from the explicit allowlist updates.

## Notes

- 2026-10-30 (planner): `--prompt-hash` is a deliberate interim input; the
  `local-review-agents` slice will supply a pinned prompt registry and may make the
  flag optional with registry defaults. Evaluator: confirm this split is acceptable
  against ADR 0021 §5 (helper records, agents own prompt assets).
- 2026-10-30 (planner): HEAD-must-equal-`head_sha` is stricter than ADR 0021's "exact
  commits" wording requires; it is chosen so a clean-tree check is meaningful. Relax
  only via a planner revision if orchestration needs reviewing a non-checked-out head.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |
