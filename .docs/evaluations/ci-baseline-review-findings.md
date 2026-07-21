# Review findings — ci-baseline

Identity-neutral capture of the three cold advisory workers run against the sealed
bootstrap export for the exact implementation commit. The code evaluator adjudicates
these findings in the companion evaluation record.

- Evidence mode: `loom-repository-bootstrap/v1`
- Conformance: degraded bootstrap; not loom-local-review/v1
- Isolation: not established under ADR 0022
- Aggregate state: `bootstrap-ran-with-findings`
- Run: `ci-baseline-b28a747-8c5effd`
- Base: `b28a74754e2ee016a035fa085f0d91de66057f62`
- Head: `8c5effd0f0ce58d0c4c276abd49b9d6da715cb27`
- Manifest SHA-256: `a67057e53e76db58ad320e372da7b4f4b9a8f05a1fe2bbacc1bb487c4ee9bbfa`
- Aggregate findings SHA-256: `9b381e0860016feb37b2c0076200f0654ff8f78ed59e977814d73277b98f4622`

## COR-1 — proposed MAJOR

- Worker: `correctness`
- Location: `scripts/check:76`
- Confidence: `0.99`
- Claim: The gate does not validate the required four-row CI matrix against the machine-readable toolchain contract, so required host coverage can silently disappear or drift while the gate remains green.
- Evidence: The contract check at lines 76-85 validates tool versions, runtimeFloors, the checkout SHA, and digest shapes, but never reads `.runners`. Lines 87-88 compare only the checkout action pin with the workflow. The workflow's host, architecture, release, shell, and version assertions all consume values from that same workflow row, so deleting the macOS Intel row (or changing a row and its self-consistent expected values) is not caught by `scripts/check`. This contradicts the plan's designation of `scripts/check-toolchain.json` as the single machine-readable check contract and its requirement that all four cells remain required.
- Suggested verification: In a disposable copy, remove the `macos-15-intel` include entry or change one row's shell/architecture while leaving the checkout pin intact; run the toolchain-contract stage and confirm it still passes. Then add a mechanical comparison between `.runners` and the workflow matrix, including exact row count and values, and make both mutations fail.

## COR-2 — proposed MAJOR

- Worker: `correctness`
- Location: `scripts/check:150`
- Confidence: `0.99`
- Claim: Previously extracted cached tools are used without being re-derived from or hash-verified against the pinned archives, allowing the reproducible gate's lint/test stages to be bypassed by stale or modified cache contents.
- Evidence: `fetch` verifies each downloaded archive, but lines 150-152 skip extraction whenever the expected shellcheck, Node, or Bats path already exists. The subsequent checks verify only self-reported version strings. For example, after one successful run, a cached `shellcheck-v0.11.0/shellcheck` replacement can print a `version: 0.11.0` line for `--version` and exit 0 for lint; the archive remains valid, extraction is skipped, and line 192 executes the replacement. The plan requires SHA-256 verification before extraction/use and an exact reproducible toolchain.
- Suggested verification: In a disposable gate copy after priming the cache, replace the extracted ShellCheck executable with a wrapper that reports 0.11.0 and otherwise exits 0, introduce a known ShellCheck violation, and rerun the gate. Fix by atomically re-extracting verified archives each run or by validating extracted artifacts against pinned hashes, then confirm the tampering is rejected.

## COR-3 — proposed MAJOR

- Worker: `correctness`
- Location: `scripts/check:104`
- Confidence: `0.97`
- Claim: The Bash 3.2 floor is enforced for the shell running `scripts/check`, not for the separately selected shell that performs syntax checking and runs the entire Bats suite.
- Evidence: Lines 104-109 compare the current process's `BASH_VERSION` with the floor before `selected_bash` is chosen at lines 194-202. The selected shell is checked only against caller-controlled `LOOM_EXPECTED_BASH_VERSION` in `run-bats-under`; no independent 3.2 minimum is applied. Thus a Bash 5 process can launch the gate with an absolute below-floor `LOOM_TEST_BASH` and matching below-floor regex without an explicit floor rejection, undermining the plan/ADR 0019 requirement that the gate reject below-floor Bash and that the selected runtime provide compatibility evidence.
- Suggested verification: Run a disposable copy under Bash 5 with `LOOM_TEST_BASH` set to an absolute Bash 3.1 executable and `LOOM_EXPECTED_BASH_VERSION` matching 3.1; assert the gate fails at an explicit selected-shell floor check before syntax/Bats. Add the selected shell's actual version to the floor test independently of the caller regex.

## COR-4 — proposed MINOR

- Worker: `correctness`
- Location: `scripts/validate-repository.mjs:290`
- Confidence: `0.98`
- Claim: Markdown fragment validation computes slugs from raw inline Markdown source instead of rendered heading text, rejecting valid GitHub-style anchors for headings containing links.
- Evidence: `headingSlugs` passes `tokens[index + 1].content` directly to github-slugger. For `# [Foo](target.md)`, markdown-it reports inline content `[Foo](target.md)`, so this implementation produces `footargetmd`; the rendered heading text is `Foo`, whose GitHub-style ID is `foo`. Consequently `[jump](#foo)` is reported as a missing fragment even though it is valid. The required positive tests cover only plain headings and do not exercise inline link markup.
- Suggested verification: Add a link fixture containing `# [Foo](target.md)` and `[jump](#foo)` and require it to pass. Build the slug input from the inline token's rendered textual children (including code/image text as appropriate), then retain duplicate-heading coverage with github-slugger.

## COR-5 — proposed MINOR

- Worker: `correctness`
- Location: `scripts/tests/repository-validation.bats:101`
- Confidence: `0.96`
- Claim: The required metadata negative-case matrix is incomplete: it does not exercise a command missing `description`, and its drift case does not exercise name or catalog-source identity drift despite the plan explicitly requiring those cases.
- Evidence: The test at lines 101-109 gives the command a valid `description` and checks an unknown key plus an agent missing `name`. The drift test at lines 159-165 mutates manifest version, client floor, profile effort, and binding version only. No test removes command `description` or mutates product/catalog name or catalog source identity. The plan's Step 1 explicitly requires missing command `description`/agent `name` and name/source identity/release-provenance drift cases, so future schema/semantic regressions in those branches would not be demonstrated by the promised suite.
- Suggested verification: Add separate disposable-root cases that remove command `description`, alter manifest/catalog product name, and alter catalog source identity/release provenance; assert nonzero status and filename-specific diagnostics for each.

## TST-1 — proposed BLOCKER

- Worker: `tests`
- Location: `.docs/slice-plans/ci-baseline.md:523`
- Confidence: `high`
- Claim: The required four-host CI execution evidence is absent, so the slice has not demonstrated its CI acceptance criterion.
- Evidence: The changed implementation notes explicitly say the workflow was not remotely dispatched and its jobs remain future required evidence. The retained gate.stdout contains one selected-shell run under /bin/bash 3.2.57 on the Darwin/arm64 gate copy; it contains no successful ubuntu-22.04, ubuntu-24.04, or macos-15-intel job logs. This conflicts with the same plan's lines 462-468 and 484-485, which require all four jobs green and state that a missing cell is not success.
- Suggested verification: Publish the exact head, retain the four GitHub Actions job logs, and verify each log shows its asserted OS/architecture, selected Bash, Bats-process and executable-child versions, dynamic test count, and a zero gate exit for this head SHA.

## TST-2 — proposed MAJOR

- Worker: `tests`
- Location: `scripts/tests/repository-validation.bats:111`
- Confidence: `high`
- Claim: The additionalProperties regression test does not exercise each release contract or each object boundary despite claiming that it does.
- Evidence: Lines 113-117 inject a top-level unknown field into only the Claude manifest, Codex catalog, compatibility matrix, and Claude root binding. They omit the Claude catalog, Codex manifest, and Codex root binding, never inject an unknown field into a nested object, and line 120 requires only one generic 'must NOT have additional properties' diagnostic. The test therefore remains green if any unmutated contract or any nested additionalProperties boundary becomes permissive, contrary to the plan's explicit manifest/catalog/compatibility/root-binding negative case and its requirement for additionalProperties:false at every object boundary.
- Suggested verification: Use one isolated mutation/test per manifest, per catalog, the matrix, and both bindings, including representative nested objects, and assert the diagnostic names the exact mutated file and instance path.

## TST-3 — proposed MAJOR

- Worker: `tests`
- Location: `scripts/tests/repository-validation.bats:159`
- Confidence: `high`
- Claim: The semantic-drift negative test is a composite false-green path and leaves several required drift checks without independent proof.
- Evidence: Lines 161-164 simultaneously alter a manifest version, a client floor, a profile effort, and a root expectedVersion, then assert only that output contains the word 'drift'. Detection of the manifest version alone is sufficient for the test to pass even if floor, profile, or binding validation is removed. It does not independently mutate or verify name, source identity, release provenance, matrix schema version, or binding ID/path, all named by the required negative-case list. The adjacent missing-reference test similarly bundles multiple failures, so one surviving diagnostic can mask another lost check.
- Suggested verification: Split every semantic invariant into a fresh-root test with exactly one mutation and an exact file-specific diagnostic; include name, SemVer, catalog source/release provenance, each floor/profile field, matrix schema, binding ID/path, missing referenced schema/file, and live-versus-fixture drift.

## TST-4 — proposed MAJOR

- Worker: `tests`
- Location: `scripts/tests/repository-validation.bats:185`
- Confidence: `high`
- Claim: The link tests do not cover repeated GitHub heading slugs or percent-decoding behavior introduced by the validator.
- Evidence: The only positive fragment fixture at lines 187-188 uses unique ASCII headings '# Alpha' and '# Beta'; the negative fragment fixture is only a plain '#nope'. No test data in this suite contains repeated headings or percent-encoded paths/fragments. Consequently regressions in validate-repository.mjs headingSlugs duplicate suffixing (lines 288-291) or decodeURIComponent/error handling (lines 268-274) would leave all 123 retained tests green, despite the plan explicitly requiring repeated GitHub-style IDs and safe percent decoding.
- Suggested verification: Add fixtures for duplicate headings resolving to the suffixed slug, encoded spaces and encoded Unicode in file/fragment targets, and malformed percent encodings that must fail with source and target.

## TST-5 — proposed MAJOR

- Worker: `tests`
- Location: `scripts/check:76`
- Confidence: `high`
- Claim: The local gate does not mechanically validate the four-row CI matrix recorded in the toolchain contract, allowing matrix regressions to pass locally.
- Evidence: The jq contract assertion at lines 76-85 validates tools, floors, the checkout pin, digests, and provenance kinds but never reads .runners. Lines 86-88 inspect the workflow only for a single uses: line and the checkout SHA. No Bats test invokes scripts/check or parses check.yml. Deleting a runner row or changing its host, architecture, release, selected shell, or Bash regex therefore leaves this entire toolchain stage green even though check-toolchain.json lines 11-16 declares the exact matrix and the plan requires all four cells.
- Suggested verification: Add a locked YAML parser check that compares workflow matrix rows exactly to check-toolchain.json, plus a mutation test that removes or alters each row field and proves the gate fails before execution.

## TST-6 — proposed MAJOR

- Worker: `tests`
- Location: `scripts/run-bats-under:14`
- Confidence: `high`
- Claim: The Bash launcher rejection and canary-order contracts have no regression tests; only its successful invocation is evidenced.
- Evidence: run-bats-under adds distinct failure branches for a relative shell (lines 14-20), non-executable shell (21-24), missing Bats entrypoint (25-28), version mismatch (30-37), and missing runtime canary (39-50), plus canary-first reordering. Repository-wide search of changed *.bats files finds no invocation of scripts/run-bats-under or scripts/check. gate.stdout proves the happy path under /bin/bash 3.2.57, but any of these fail-closed branches or the ordering rule could regress while the retained test suite remains green.
- Suggested verification: Add a dedicated Bats suite that invokes run-bats-under with a relative path, non-executable file, wrong version regex, missing Bats entrypoint, missing canary, and a two-file probe that records and asserts canary-first ordering; retain the existing real Bash 3.2 happy-path log.

## SEC-1 — proposed BLOCKER

- Worker: `security`
- Location: `scripts/check:150`
- Confidence: `high`
- Claim: The persistent ignored tool cache is trusted by pathname and a self-reported version, allowing a cache poisoned by an earlier branch or process to execute arbitrary code during a later trusted check.
- Evidence: The new gate stores tools under .check-cache (lines 7-9). Although fetch verifies the downloaded archives, lines 150-152 skip extraction whenever the expected ShellCheck/Node/Bats path already exists, without hashing or comparing the extracted artifact to the archive. Lines 157-161 then execute those cached paths and accept version text produced by the same untrusted executable/script; the cached Node is subsequently used for npm and repository validation. A wrapper can print the pinned version for the probe and run attacker-controlled behavior on the next invocation, so the archive digest does not authenticate what is actually executed after cache reuse.
- Suggested verification: In an isolated copy, pre-seed each expected .check-cache/tools path with a wrapper that returns the required version for the probe and records execution otherwise, while leaving the pinned archives valid; confirm the current gate runs it. Fix by extracting into a fresh private staging directory on every verification (or hashing every consumed extracted file against an independently pinned digest), rejecting pre-existing/symlinked targets, and atomically publishing only verified tool trees.

## SEC-2 — proposed BLOCKER

- Worker: `security`
- Location: `scripts/check:63`
- Confidence: `high`
- Claim: Unchecked symlinks in the ignored cache can redirect gate downloads and tool installation outside the repository, causing arbitrary file overwrite under the invoking user's permissions.
- Evidence: CACHE, DOWNLOADS, and TOOLS are constructed lexically (lines 7-9) and mkdir -p is used without lstat/realpath containment checks (line 75). fetch writes directly to a predictable destination with curl -o at line 63; curl follows a destination symlink. The verified shfmt payload is then copied to another predictable path at line 148, where cp can likewise follow an existing destination symlink, and tar extracts into TOOLS at lines 150-152 without proving that the destination tree contains no symlinked parents. Because .check-cache is deliberately persistent and ignored, a poisoned cache survives checkout/branch changes.
- Suggested verification: In a disposable repository copy, make a cache download or tools/bin destination a symlink to a sentinel file outside the repository, run the relevant provisioning path, and verify the sentinel is currently overwritten. Reject any symlink/non-directory component with lstat, prove the physical cache remains below the repository, download to a mode-0700 fresh directory with exclusive temporary files, and rename only after digest verification.

## SEC-3 — proposed MAJOR

- Worker: `security`
- Location: `scripts/validate-repository.mjs:209`
- Confidence: `high`
- Claim: An invalid root-binding path is dereferenced before it is treated as trusted, permitting repository-controlled JSON to read files outside the validation root.
- Evidence: Schema errors are accumulated but do not stop semanticMetadata. Lines 207-209 iterate matrix.rootBindings and pass binding.path to exists/readJson even when it failed the schema pattern. absolute() at line 35 is only path.join(root, relative), with no isInside or realpath check, so a value such as ../../outside.json escapes the root. readJson then reads and parses that file at line 76, and its parse error is emitted; Node 22 JSON parse diagnostics include a snippet of the rejected input, creating a potential disclosure channel in CI logs.
- Suggested verification: Create a temporary validation root whose compatibility matrix contains a syntactically valid but schema-invalid ../../ path to an outside sentinel JSON/non-JSON file; instrument or inspect output to prove the outside file is not opened and no sentinel bytes appear. Short-circuit semantic checks for schema-invalid objects and apply lexical plus physical containment before every metadata-derived file access.

## SEC-4 — proposed MAJOR

- Worker: `security`
- Location: `scripts/validate-repository.mjs:76`
- Confidence: `high`
- Claim: Tracked and filesystem-discovered JSON/Markdown inputs can be symlinks to files outside the repository, and the validator follows them during parsing.
- Evidence: Git discovery at lines 48-51 returns paths without checking their file type. The non-Git walk explicitly adds symlinks to the candidate list at line 60. readJson uses readFileSync directly at line 76, frontmatter and source Markdown do the same at lines 164 and 236, and link targets use statSync/readFileSync at lines 278-284; none canonicalize the candidate and prove it remains under root. The catalog-source-only symlink check at lines 216-226 does not protect these generic reads. Thus a tracked foo.json symlink, frontmatter symlink, or Markdown target symlink can make CI read outside-root content, with JSON/YAML diagnostics potentially echoing it.
- Suggested verification: Add negative tests for a tracked-style JSON symlink, a frontmatter symlink, and a Markdown target symlink pointing to an outside sentinel; require deterministic rejection before parsing and assert the sentinel never appears in diagnostics. For every candidate and resolved link target, use lstat to reject symlinks (including intermediate components), realpath the regular file, and enforce isInside(root, physicalPath) before reading.

## SEC-5 — proposed MAJOR

- Worker: `security`
- Location: `.github/workflows/check.yml:48`
- Confidence: `high`
- Claim: The workflow leaves the checkout credential persisted while executing PR-controlled repository tests and network-capable third-party tooling.
- Evidence: The pinned actions/checkout step sets only fetch-depth (lines 48-50), so checkout's persist-credentials default leaves its token-backed authentication in local Git configuration until post-job cleanup. The next step executes scripts/check from the pull-request tree. That gate dynamically runs every tracked *.bats file (scripts/check lines 207-216), runs npm lifecycle scripts because npm ci lacks --ignore-scripts (line 164; the lock marks @anthropic-ai/claude-code hasInstallScript: true), downloads tools, and executes the Claude binary. permissions: contents: read limits the token but does not prevent its disclosure or unauthorized use while the job is running.
- Suggested verification: Before the gate, inspect git config --show-origin --get-regexp 'http.*extraheader' and demonstrate that no checkout credential remains. Set persist-credentials: false, remove any credential-bearing Git configuration before executing repository or dependency code, and run the validator/dependency steps with a scrubbed credential environment and isolated HOME where feasible.

## SEC-6 — proposed MINOR

- Worker: `security`
- Location: `scripts/run-bats-under:63`
- Confidence: `high`
- Claim: The Bash-selection temporary directory is leaked on every test run because exec replaces the shell before its EXIT cleanup trap can run.
- Evidence: Lines 52-55 create a private temporary directory and install an EXIT/HUP/INT/TERM trap to remove it. Line 63 uses exec for Bats, permanently replacing the shell; successful or failed Bats completion returns directly from the replacement process, so the original shell never executes its EXIT trap. Gate evidence confirms this path runs once per complete check.
- Suggested verification: Count ${TMPDIR:-/tmp}/loom-bash.* directories before and after one gate invocation and confirm the current count increases. Invoke Bats without exec, capture its status, remove the exact mktemp directory, clear traps, and return that status; add a regression test that the directory is gone on success, failure, and signal handling.
