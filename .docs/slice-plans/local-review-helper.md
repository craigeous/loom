# Local Review Helper

Status: Plan Review
Target specs: 04-orchestrator.md, 05-blind-evaluation.md, 08-playbook.md, 10-packaging.md
Target size: <= 700 LOC net change excluding tests/schemas (keep this plan document <= 250 lines)

## Context

ADR 0021 defines `loom-local-review/v1`: exact `base_sha`/`head_sha` inputs, a
hash-bound manifest, per-finder JSON results, finder states, and an aggregate where any
pending/failed/invalid/missing finder makes the run `invalid`. ADR 0022 requires the
code evaluator to receive an evidence-complete workspace with a valid local-review
artifact. No helper implements this today (review uses `/code-review`, ADRs 0010/0011).

This slice adds only `plugins/loom/bin/loom-review`, two JSON Schemas, helper
registration, and Bats tests. Finder prompts/agents (`local-review-agents`) and
orchestration/spec rewiring (`local-review-orchestration`) are separate M4 slices. The
helper never launches a finder: it prepares, validates, assembles, reports, and cleans.

## Out of Scope & Threat-Model Boundary

- No finder prompts, agents, launch adapters, or edits to commands, rubrics, specs
  02/04/05, or ADRs 0010/0011 (later M4 slices).
- No change to the code evaluator's PASS/FAIL ownership, ADR 0022 workspace
  construction, or landing; `assemble` output is advisory evidence only.
- Defense is against accidental or sloppy finder output (spec 00 Non-goals): no hostile
  inode swapping, concurrent tampering mid-command, or monkeypatched helpers. Hash checks
  detect post-`prepare` modification; they are not a sandbox or authentication. The run
  directory is assumed private (`0700`).
- Network-silent: no network command, remote, or `git fetch`; local object access only.
  Docs-only `skipped: docs-only` is orchestrator policy, not helper behavior.

## Steps

Conventions: Bash 3.2+, `set -euo pipefail`, Git 2.34+, jq 1.6+ (no `mapfile`,
associative arrays, `${var,,}`), `shfmt -i 4`, `shellcheck -s bash`; style mirrors
`loom-land`. Exit codes: `0` ok, `1` usage/environment, `2` target/content rejection
(invalid run), `3` run incomplete (status only). Hashing: `shasum -a 256` else
`sha256sum`; canonical JSON is `jq -S -c`.

1. **Schemas** (`plugins/loom/schemas/`), draft 2020-12, `additionalProperties: false`,
   `$id` as siblings:
   - `loom-local-review-manifest-v1.schema.json`. Required: `protocol` (const
     `loom-local-review/v1`), `run_id` (`^[a-z0-9][a-z0-9._-]{0,63}$`), `slice`,
     `loom_version`, `helper_version`, `base_sha`/`head_sha` (`^[0-9a-f]{40}$|^[0-9a-f]{64}$`),
     `head_tree`, `diff_sha256`, `files[]` (`path`, `status` enum `A|M|D|R|C|T`, `old_path`
     required when `R|C`, `binary`, `old_mode`, `new_mode`, `added`/`deleted` counts or
     null when binary, `ranges[]` of `{side,start,end}`: `side` `new` for text
     A/M/R/C/T, `old` for text D, `ranges: []` for binary, via `if/then`), `inputs[]`
     (`kind` enum `plan|spec|adr|gate-evidence`, `path`, `sha256`), `finders[]` (`id`,
     `prompt` `{protocol,version,sha256}`, `output`, `adapter`, `model_profile`),
     `source_export` `{path,sha256,file_count}`, `created_at` (RFC 3339 UTC),
     `manifest_sha256`. `finders` has `minItems: 3`; the three required IDs are enforced
     in code (the schema cannot express "contains all").
   - `loom-local-review-findings-v1.schema.json` (one finder result). Required:
     `protocol`, `run_id`, `manifest_sha256`, `finder` `{id, prompt_version,
     prompt_sha256}`, `base_sha`, `head_sha`, `diff_sha256`, `status` enum
     `ran-with-findings|ran-clean|failed`, `findings[]`, `provenance` `{adapter,
     model_profile, started_at, finished_at, truncated, exit_status}`. Each finding:
     `id` (`^[A-Z]{2,5}-[0-9]+$`), `finder`, `confidence` (0..1), `severity` enum
     `BLOCKER|MAJOR|MINOR|NIT`, `file`, optional `line` (int >= 1) and `line_end`
     (>= `line`; `dependentRequired` `line_end` → `line`), and non-empty `claim`,
     `evidence`, `verification`. Code enforces text → `line` required, binary → both
     omitted (the schema cannot see `binary`). `ran-clean` requires `findings: []`;
     `ran-with-findings` requires `minItems: 1` (`if/then`).
2. **Registration.** Add `loom-review` last to `ALLOWED_HELPERS` in
   `plugins/loom/bin/loom-resolve-helper` and every metadata copy: `adapters/roots/
   {claude-plugin-root-v1,codex-skill-source-v1}.json`, fixtures `adapters/fixtures/
   v0.2.0/metadata/{claude,codex}-root.json`, the `const` array in
   `schemas/loom-installed-root-binding-v1.schema.json` (all under `plugins/loom/`), and
   the two `allowedHelpers` literals in `scripts/validate-repository.mjs` (~lines 517,
   526). Update the order mutation at `scripts/tests/repository-validation.bats:458`; add
   claude and codex resolve cases to `plugins/loom/bin/loom-resolve-helper.bats`
   (mirror `loom-verify-identity`, lines 72-83; stub at line 35). Confirm no copy is
   missed with `grep -rn 'loom-verify-identity' --exclude-dir=.git`.
3. **Run layout.** Runs live under `<git-common-dir>/loom/review/<run_id>/` (untracked,
   like `loom-coord` state); `--run-dir` may override with an absolute path whose parent
   exists. Contents: `manifest.json` (canonical JSON, hash field written last),
   `source/`, `inputs/` (plan/specs/ADRs/gate evidence at recorded hashes), `diff.patch`,
   `results/<finder-id>.json` (written by finders; `/` mapped to `__`), and `state.json`
   (helper-only: verdict, `results_digest`, aggregate, assembled-output hash).
4. **`prepare`** — `loom-review prepare --slice <name> --base <sha> --head <sha> --plan
   <path> [--spec <path>]... [--adr <path>]... --gate-evidence <path> --prompt-hash
   <finder>=<sha256> --finder-profile <finder>=<adapter>:<model-profile> [--run-id <id>]
   [--run-dir <dir>] [--repo <path>]` (`--prompt-hash`/`--finder-profile` repeat; all
   three finders required). Provenance sources: `loom_version` = `version` in
   `plugins/loom/.claude-plugin/plugin.json` via `git show head:` (missing → exit 2);
   `helper_version` = script constant; `head_tree` = `rev-parse head^{tree}`; adapter/
   model profile only from `--finder-profile` (never guessed). Fails closed (exit 2, no
   run directory left: build in a sibling temp dir, then `mv`) when:
   a. `--base`/`--head` is not a full 40/64-hex string, does not resolve via
      `git rev-parse --verify --quiet <sha>^{commit}` to itself, or is ambiguous
      (symbolic, abbreviated, tag/branch name, `A..B` or `^` syntax); base is not an
      ancestor of head (`merge-base --is-ancestor`); base equals head.
   b. The working tree is dirty: any output from `git status --porcelain
      --untracked-files=all --ignore-submodules=none -- . ':(exclude)<evidence-relpath>'`
      (the exclusion applies only to the supplied gate-evidence file when it lies inside
      the repo; every other dirty or untracked path rejects), or HEAD is not `head_sha`
      (the checkout must equal the reviewed head; export reads objects, not the tree).
   c. Any `--plan`/`--spec`/`--adr` path is missing, outside the repo, a symlink, or
      not a regular file; plan/specs/ADRs must be tracked and unmodified at `head_sha`
      (`git diff --quiet`, `git cat-file -e head:path`). `--gate-evidence` must be an
      existing regular non-symlink file, inside or outside the repo, tracked or not; it
      is copied into `inputs/` and hashed (the only input not bound to a git object).
   d. A submodule or gitlink appears in the diff (unsupported in v1; reject rather
      than silently skipping).
   Then: capture `git diff --raw -z --find-renames --find-copies -M -C --no-ext-diff
   base head` into the `files[]` inventory (status, paths, modes; binary = numstat
   `-\t-`), changed-line ranges from `git diff -U0 --no-ext-diff --no-color` hunk headers
   (`side: new`; deleted files `side: old`; binary `[]`), save `diff.patch`, and compute
   `diff_sha256` over `git diff --binary --full-index -M -C --no-ext-diff --no-color base
   head` bytes. Export source from objects, never attributes: `git ls-tree -r -z head`
   (gitlink → reject), write each entry with `git cat-file blob <oid>` (symlinks as links,
   `100755` executable) so `export-ignore`/`export-subst`/eol/filter attributes cannot
   alter the snapshot; re-list `source/` and verify every path, mode and `git hash-object`
   oid equals its `ls-tree` entry and counts match (mismatch → exit 2). Hash the export
   as SHA-256 over the sorted `path\0mode\0blobhash` listing; record `file_count`;
   `chmod -R a-w source/`. Required finders: `review-correctness/v1`, `review-tests/v1`,
   `review-security/v1` (prompt assets belong to `local-review-agents`; prompt version
   recorded `v1`). `manifest_sha256` is SHA-256 of canonical JSON without that field,
   then written. Print the run directory on stdout.
5. **`validate`** — `loom-review validate <run-dir|run-id> [--repo <path>] [--quiet]`.
   Read-only on `source/`, `inputs/`, results. Collects all failures into
   `state.json.errors`, exit 2 on any:
   - Manifest present and structurally schema-valid (jq checks mirroring the schema; no
     `ajv` dependency — the schemas themselves are validated by
     `scripts/validate-repository.mjs` and a Bats test), `protocol` exactly
     `loom-local-review/v1` (other majors rejected, never guessed), `manifest_sha256`
     recomputed equal.
   - Object binding, **fail closed**: needs the repo; an unavailable repo or missing
     base/head/tree object → exit 2 `unverifiable`, never a skip (workspaces without
     objects carry the already-validated artifact). Recompute from git, not the manifest:
     full-hex SHAs resolve to commits, `head_tree == head^{tree}`, base is an ancestor,
     the diff (same command as `prepare`) hashes to `diff_sha256` and equals `diff.patch`,
     `files[]` (with ranges) canonical-equals the git-derived inventory, plan/spec/ADR
     input hashes equal `git show head:<path>` blobs, and the `source/` listing (every
     path/mode/`hash-object` oid; no added/removed/chmod'd files) equals `ls-tree -r head`,
     `source_export.sha256` and `file_count`. `inputs/` hashes match the manifest.
   - Finder set is exactly the three IDs, each with exactly one result file (missing →
     `invalid: missing`; two files mapping to one ID → duplicate; extra files rejected).
   - Each result is valid UTF-8 JSON, schema-valid, and its `protocol`, `run_id`,
     `manifest_sha256`, `base_sha`, `head_sha`, `diff_sha256`, finder ID, prompt
     version/sha, and `provenance.adapter`/`model_profile` match the manifest finder
     entry. Unknown prompt version or protocol → invalid.
   - `status: failed`, `truncated: true`, `exit_status` not integer `0` (even with a
     `ran-*` status), or status inconsistent with finding count → finder `failed`/
     `invalid`; the whole run is `invalid` (no partial assembly).
   - Every finding's `file` is in `files[]`; text findings need `line` intersecting a
     recorded range of the file (`new` side; `old` side for deleted files); binary
     findings must omit `line`/`line_end`. Locations outside the diff and duplicate
     finding IDs → invalid.
   - Aggregate: `ran-with-findings` if any finder has findings, else `ran-clean`, only
     when all three are valid; otherwise `invalid`. Write `state.json` (`validated`,
     `results_digest`, per-finder state, `aggregate`); print one line per finder plus
     `aggregate: <state>`.
6. **`assemble`** — `loom-review assemble <run-dir|run-id> --out <path>` (default
   `.docs/evaluations/<slice>-review-findings.md`). Re-runs `validate`; refuses (exit 2,
   nothing written) unless the aggregate is `ran-clean` or `ran-with-findings`. Output is
   identity-neutral markdown: header (protocol, run ID, aggregate, base/head, diff,
   manifest and findings hashes), provenance table (finder, prompt version/hash, adapter,
   model profile), then findings sorted by (file, line, id) in the existing
   `*-review-findings.md` shape (`## COR-1 — proposed MAJOR`; Worker/Location/Confidence/
   Claim/Evidence/Suggested verification). No names, hostnames, absolute paths, or
   timestamps beyond manifest `created_at`; byte-identical on re-run. Atomic write via
   temp file + `mv`, then record `assembled` (output sha256, `results_digest`) in `state.json`.
7. **`status`** — `loom-review status <run-dir|run-id> [--json]`. Read-only.
   `results_digest` = SHA-256 of sorted result hashes. Precedence (first match wins):
   1. `state.json` has a validation record whose digest equals the current
      `results_digest` (even for zero results): report `validated` with the recorded
      aggregate: `ran-clean`/`ran-with-findings` exit 0, `invalid` exit 2 (an unchanged
      empty set that `validate` recorded `invalid` reports `invalid`, never `prepared`).
      If `assemble` recorded an equal digest and matching output hash: `assembled`, exit 0.
   2. Otherwise (no record or digest differs; stale verdicts are ignored entirely): 0
      result files → `prepared`, >= 1 → `collecting`; both exit 3.
   Per-finder: `pending` when no result, else last validation state (rule 1 only).
   `pending` appears only here; `validate` treats it as `invalid`. Exit 1: usage/unreadable.
8. **`clean`** — `loom-review clean (<run-id>... | --all | --older-than <days>)
   [--repo <path>]`. Removes only directories under `<git-common-dir>/loom/review/` that
   hold a `manifest.json` with the expected protocol (refuse symlinks and paths escaping
   the root after `cd -P`); `chmod -R u+w` then `rm -rf`; prints removed run IDs; never
   touches committed `*-review-findings.md`.
9. **Docs (minimal).** Add a "Helper contract" subsection to
   `plugins/loom/skills/loom-playbook/references/review-findings.md` (subcommands, exit
   codes, run layout; orchestration still uses legacy commands until
   `local-review-orchestration`). No spec/ADR edits.

## Verification
Gate (once, on the candidate commit): `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`
plus `node scripts/validate-repository.mjs --root "$PWD" --all`.
Iteration: `shfmt -i 4 -d`, `shellcheck -s bash` on `plugins/loom/bin/loom-review`, and
`TMPDIR=/private/tmp bats --filter '<pattern>' plugins/loom/bin/loom-review.bats`.

`plugins/loom/bin/loom-review.bats` builds a throwaway repo per test (`setup` makes a
base commit, a head commit exercising modify/add/delete/rename/mode-change/binary
paths, a plan, spec, and gate-evidence file, and no remote). Required tests:

- **prepare accept/record:** records exact SHAs, tree ID, diff hash equal to an
  independently computed `git diff --binary --full-index` hash; inventory marks
  renamed (with `old_path`), binary, added, deleted; changed ranges match hunks;
  export has no `.git` and matches `git ls-tree -r` path/mode/oid, including with tracked
  `.gitattributes` `export-ignore`/`export-subst`/eol rules (nothing omitted or
  substituted); untracked gate evidence inside/outside the repo accepted, other untracked
  file rejects; provenance recorded; inputs hashed; manifest hash recomputes; schema-valid.
- **prepare reject** (each exits 2, no run directory): abbreviated SHA, branch, tag,
  `HEAD`, `A..B`, nonexistent SHA, base == head, base not ancestor, dirty tracked file,
  other untracked file, HEAD != head, missing/symlinked/out-of-repo plan, modified spec,
  gitlink in diff, missing `--prompt-hash` or `--finder-profile`.
- **network-silent:** runs with `GIT_ALLOW_PROTOCOL=none`, a PATH shim for
  `curl`/`wget`/`ssh` that fails the test if invoked, and no remotes configured.
- **validate accept:** fixture results for all three finders (mixed `ran-clean`/
  `ran-with-findings`) → correct aggregate, exit 0; all-clean → `ran-clean`.
- **validate reject** (each → exit 2, aggregate `invalid`, **never** `ran-clean`):
  missing finder; duplicate/extra result; invalid JSON; schema violation; unknown
  protocol (`loom-local-review/v2`); unknown prompt version/hash; manifest hash/run ID
  mismatch; `status: failed`; `truncated: true`; nonzero `exit_status` with `ran-*`;
  `ran-clean` with findings and the converse; provenance adapter/model_profile mismatch;
  result `base_sha`/`head_sha`/`diff_sha256` mismatch; modified source export (edited,
  added, removed, chmod'd, attribute-omitted file); modified diff/input; `head_tree`/
  SHAs/`files[]` swapped for a self-consistently re-hashed manifest/export of another
  commit; repo or object missing (`unverifiable`); invalid `ranges[]` (`side: old` on a
  non-deleted file, missing `side`); locations: unchanged file, line outside ranges,
  nonexistent path, deleted-file finding on a new-side line (old-side range accepted),
  binary finding with `line` (file-level finding accepted), text finding without `line`.
- **assemble:** refuses invalid/pending runs without writing; output identity-neutral
  (grep finds no user name, email, hostname, or absolute path), deterministic across
  two runs, findings sorted, atomic (no partial file on failure injected via read-only
  target directory).
- **status:** exit codes 0/2/3/1 (valid, invalid, pending, missing run); `--json` parses
  with `jq`; phases `prepared` → `collecting` → `validated` → `assembled`; `status` never
  writes. Focused: validate with zero results → status `invalid`, exit 2 (not `prepared`);
  result file changed after a valid verdict → `collecting`, exit 3 (stale verdict ignored).
- **clean:** removes only a named run; `--all`; `--older-than`; refuses paths outside
  the review root, symlinked run dirs, and dirs without a matching manifest; read-only
  `source/` is removed.
- **registration:** `loom-resolve-helper` resolves `loom-review` (claude, codex);
  `validate-repository.mjs --all` passes; the mutation test still catches allowlist drift.
- **Regression:** `loom-resolve-helper.bats`, `repository-validation.bats`, `loom-coord.bats`,
  `loom-verify-identity.bats` pass unchanged except allowlist updates.

## Notes
- `--prompt-hash`/`--finder-profile` are interim; `local-review-agents` may default them (ADR 0021 §5).
- HEAD-must-equal-`head_sha` is stricter than ADR 0021 so the clean-tree check is meaningful.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |
| 1 | Export from `ls-tree`/`cat-file` objects with per-entry verification; gate evidence excluded from clean check; fail-closed git-object binding in `validate`; `side`-tagged ranges and binary/deleted location rules; provenance sources (`--finder-profile`, plugin.json) and matching; derived state transitions; expanded tests |
| 2 | Status precedence: matching validation digest reports recorded verdict (incl. empty `invalid`, exit 2); changed digest ignores stale verdicts (`prepared`/`collecting`, exit 3); focused status tests |
