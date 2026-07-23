# Review findings — ci-baseline

Identity-neutral capture of the three cold advisory workers run against the sealed
bootstrap export for the exact implementation commit. The code evaluator adjudicates
these findings in the companion evaluation record.

> Bootstrap authority correction: the three sections labeled Round 1 through Round 3
> below predate the required protected transition ref and are retained only as invalid
> diagnostic history. They did not authorize publication and do not consume merits
> rounds. The first valid bootstrap review is explicitly labeled Valid merits Round 1.

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

---

# Bootstrap review Round 2 — ci-baseline

- Evidence mode: `loom-repository-bootstrap/v1`
- Conformance: degraded bootstrap; not loom-local-review/v1
- Isolation: not established under ADR 0022
- Aggregate state: `bootstrap-ran-with-findings`
- Run: `ci-baseline-b28a747-700a117-r2`
- Base: `b28a74754e2ee016a035fa085f0d91de66057f62`
- Head: `700a1176940fb3f2713113d02816e66b745bc064`
- Manifest SHA-256: `98a5b90538c316940a328edac440205de40217365bf2ea4660df615c2b4f20dc`
- Aggregate findings SHA-256: `8cbd1c76a21c902dc119685659dac769387f06ab141cd6a34b2ffa6207044194`

## COR-R2-1 — proposed BLOCKER

- Worker: `correctness`
- Location: `.github/workflows/check.yml:48`
- Confidence: `0.99`
- Claim: The retained four-host CI run is associated with head 700a117 in run metadata but does not execute the gate at that exact revision, so it cannot supply the plan's required exact-head remote evidence.
- Evidence: The checkout step has no ref input, so the pull_request run uses GitHub's merge ref. Every supplied job log shows checkout of refs/remotes/pull/1/merge and reports HEAD a8ee9ed542c50ff11906a5e9b3bc8fe7c4c0a463 ("Merge 700a1176940fb3f2713113d02816e66b745bc064 into c7bd84d997afb32f6159628eb840a9dd8d2d3dca"), after which scripts/check runs from that checkout. The logs do otherwise prove the four claimed hosts/architectures, Bash 3.2.57 or 5.x, 192 passing Bats tests, nine completed gate stages, and All checks passed, but none executes with HEAD equal to the manifest head. The slice plan requires retained exact-head execution and treats absent exact-head cells as failure.
- Suggested verification: Configure checkout to use the event's exact PR head SHA (and github.sha for push), assert git rev-parse HEAD equals the expected head before repository-controlled code runs, rerun all four cells, and retain logs showing HEAD 700a1176940fb3f2713113d02816e66b745bc064 together with the existing host/shell/test/gate evidence.

## COR-R2-2 — proposed MAJOR

- Worker: `correctness`
- Location: `scripts/validate-repository.mjs:147`
- Confidence: `0.99`
- Claim: Release-fixture drift is compared by JSON serialization rather than semantic JSON equality, so a harmless object-key reorder is incorrectly rejected as release metadata drift.
- Evidence: deepEqual is implemented as JSON.stringify(left) === JSON.stringify(right), and lines 190-197 use it for every fixture/live comparison. JSON object member order is not semantic, while the plan explicitly requires each release-owned fixture to equal its live semantic object. Reordering keys in either otherwise identical manifest, catalog, matrix, or root binding therefore changes JSON.stringify output and makes --metadata fail even though the two JSON values are semantically equal.
- Suggested verification: In a disposable validation root, reorder only object members in one live metadata file while keeping all keys and values unchanged; --metadata should remain green. Replace the serialization comparison with order-insensitive structural equality while retaining array order, then add this regression case.

## COR-R2-3 — proposed BLOCKER

- Worker: `correctness`
- Location: `.docs/evaluations/0018-shared-core-and-client-adapters-eval.md:30`
- Confidence: `0.99`
- Claim: The implementation diff includes unrelated edits to pre-existing evaluation records outside the slice's closed file allowlist.
- Evidence: The exact diff deletes a trailing blank line from this evaluation and makes the same unrelated deletion in .docs/evaluations/0019-supported-runtime-and-release-contract-eval.md and .docs/evaluations/0020-remote-publication-is-the-landing-authority-eval.md. The approved plan explicitly says developers may add or edit only its enumerated paths, does not list these three records, and explicitly places editing evaluation files out of scope. The severity rubric classifies an out-of-scope change as BLOCKER even when the textual effect is cosmetic.
- Suggested verification: Mechanically compare changed-paths.txt with the plan's allowed path set. Remove these three unrelated deltas (or rebuild/rebase the slice so target-branch housekeeping is not part of the reviewed base..head diff), then rerun diff whitespace validation on the exact corrected head.

## COR-R2-4 — proposed MINOR

- Worker: `correctness`
- Location: `.docs/evaluations/ci-baseline-eval.md:138`
- Confidence: `0.99`
- Claim: The newly recorded Round 1 evaluation ends its Assessment section with the serialization artifact '[object Object]' instead of a meaningful assessment, leaving the durable evaluation record internally incomplete.
- Evidence: The changed file contains a complete FAIL verdict, adjudications, and required changes, but the only content under the final '### Assessment' heading is the literal '[object Object]'. This is neither human-readable assessment prose nor a documented status token and is consistent with accidental JavaScript object stringification.
- Suggested verification: Trace the Round 1 verdict recording/serialization path, render the assessment value as intended text or structured fields, and add a recorder check that rejects literal object-stringification placeholders in durable evaluation output.

## TST-R2-1 — proposed BLOCKER

- Worker: `tests`
- Location: `scripts/tests/repository-validation.bats:461`
- Confidence: `high`
- Claim: The real-tree validity regression can recursively delete the repository whenever the validator fails.
- Evidence: The shared teardown at lines 15-18 runs rm -rf on any nonempty TEST_ROOT. This test assigns REPOSITORY_ROOT to TEST_ROOT at line 461, asserts success at line 463, and clears TEST_ROOT only afterward at line 464. Under Bats, a failed assertion transfers control to teardown before line 464, so the very negative condition this test is meant to reveal makes teardown remove the checkout rather than merely report the regression.
- Suggested verification: Keep the real repository out of the teardown-owned variable (or track an explicit mktemp ownership flag), force the real-tree validator to return nonzero in a disposable clone, and verify the test fails while a repository sentinel and the checkout remain intact. Teardown should delete only a path returned by this test's own mktemp call after validating that ownership.

## TST-R2-2 — proposed MAJOR

- Worker: `tests`
- Location: `scripts/tests/repository-validation.bats:397`
- Confidence: `high`
- Claim: The outside-root containment fixtures use predictable shared temporary-parent files and can overwrite or delete unrelated data or collide with another test run.
- Evidence: Line 397 derives outside-sentinel.json from dirname(TEST_ROOT), which is the shared parent of the unique mktemp directory, then line 398 truncates it and line 404 deletes it. The JSON, frontmatter, schema, fixture, Markdown-source, Markdown-target, and allowlist symlink cases repeat the same pattern with fixed sibling names. The uniqueness of TEST_ROOT therefore does not protect these sentinels, and assertion failures before the explicit rm also leak them.
- Suggested verification: Create a second uniquely owned mktemp directory for outside-root sentinels, register it for ownership-checked teardown before assertions, and run two copies of the suite concurrently while pre-creating the old fixed names; verify neither run touches the pre-existing files and both clean only their own roots.

## TST-R2-3 — proposed MAJOR

- Worker: `tests`
- Location: `scripts/tests/repository-validation.bats:269`
- Confidence: `high`
- Claim: The claimed shared-manifest identity regression does not prove all identity fields required by spec 10; schema-valid homepage drift is currently accepted by the validator.
- Evidence: The test mutates only description and updates the release fixture to match. Spec 10 requires both manifests to carry the same repository/homepage metadata where supported. Both pinned manifest schemas support homepage, but validate-repository.mjs lines 284-287 compare only name, version, description, license, and repository. Changing the Codex homepage and its fixture to another valid URI therefore evades fixture drift, passes both schemas, and produces no semantic identity diagnostic, while all current tests remain green.
- Suggested verification: In a fresh metadata root, change only the Codex manifest homepage to a different valid URI and copy that change into its release fixture; require a file-specific shared-identity failure. Add isolated schema-valid mutations for every shared identity/provenance field and make semantic validation compare the complete supported shared set.

## TST-R2-4 — proposed MAJOR

- Worker: `tests`
- Location: `scripts/tests/repository-validation.bats:568`
- Confidence: `high`
- Claim: No negative test independently proves that a live allowlist entry with an empty reason is rejected.
- Evidence: The composite malformed/duplicate/stale fixture at lines 568-577 uses a one-field record as its malformed case; every three-field record has a nonempty reason. The live allowlist test at lines 579-586 proves only that a nonempty reason can suppress the exact broken link. If the parser stopped checking third-field emptiness but retained field-count validation, every current allowlist assertion would still pass, contrary to the plan's explicit nonempty-reason requirement.
- Suggested verification: Add an isolated live broken-link fixture with an exact three-column allowlist record whose third field is empty, assert a malformed-record diagnostic, and also assert that the underlying broken link is not treated as allowlisted.

## TST-R2-5 — proposed MAJOR

- Worker: `tests`
- Location: `scripts/tests/toolchain-contract.bats:88`
- Confidence: `high`
- Claim: The contract mutation suite does not independently prove closure of the exact tool versions, runtime floors, checkout action pin, or package-lock digest fields.
- Evidence: After the workflow-row cases, the negative tests mutate only runners, downloads, and vendored records. There is no mutation or omission case for tools (including the JavaScript parser/validator versions), runtimeFloors, actions.checkout, packageLockSha256, or an unexpected top-level field. The passing baseline test cannot distinguish a closed contract from a future implementation that becomes permissive in any of those unexercised classes, even though exact closure is a stated acceptance requirement.
- Suggested verification: Add table-driven, one-change-per-root tests that mutate and delete a representative field from tools, runtimeFloors, actions.checkout, and packageLockSha256, add an unexpected top-level field, and mutate the workflow checkout SHA; require the contract stage to reject each case with a class-specific diagnostic.

## SEC-R2-001 — proposed BLOCKER

- Worker: `security`
- Location: `scripts/check:127`
- Confidence: `high`
- Claim: A mutable persistent-cache archive can change after its SHA-256 check and before extraction or execution, so the gate does not maintain digest-before-use under the stated local-cache race threat model.
- Evidence: For a cache hit, lines 126-133 hash the shared predictable path and then return that same path. The caller retains four such shared paths at lines 346-349 and only later copies or extracts them at lines 351-355. Nothing snapshots the authenticated bytes into the private RUN_DIR or re-hashes a private copy immediately before use. secure_directory at lines 60-77 also accepts a pre-existing cache directory without checking ownership or mode. A concurrent cache writer can therefore replace or mutate the regular file after line 127; for archives, it can also change the bytes between validate_archive_names at line 166 and tar extraction at lines 168-169. The resulting shfmt/Node/ShellCheck/Bats payload is then executed. The existing cache tests cover a static symlink and stale extracted tree, not this time-of-check/time-of-use race.
- Suggested verification: Make fetch copy each cache hit into a newly created private RUN_DIR file, verify the private copy after copying, and consume only that private file; for fresh downloads, continue consuming the already-private verified temporary file and publish a separate cache copy. Reject or repair pre-existing cache directories with unexpected owner/permissions. Add a race regression that rewrites the shared cache after its first hash and prove extraction/execution either uses the authenticated private snapshot or fails before executing it.

## SEC-R2-002 — proposed BLOCKER

- Worker: `security`
- Location: `.github/workflows/check.yml:48`
- Confidence: `high`
- Claim: Pull-request CI does not attest the exact head commit bound into the bootstrap manifest; it checks GitHub's synthetic merge commit instead, so the supplied green CI evidence is not exact-revision evidence for head 700a1176940fb3f2713113d02816e66b745bc064.
- Evidence: The checkout step at line 48 does not set ref, and the workflow never compares the checked-out HEAD to github.event.pull_request.head.sha. All four supplied job logs state 'HEAD is now at a8ee9ed Merge 700a1176940fb3f2713113d02816e66b745bc064 into c7bd84d997afb32f6159628eb840a9dd8d2d3dca', while manifest.json binds head_sha 700a1176940fb3f2713113d02816e66b745bc064. Thus a passing status can depend on target-branch content absent from the reviewed head, contrary to ADR 0023's exact committed-input/gate-evidence binding and the plan's exact-head remote execution requirement.
- Suggested verification: For pull_request, checkout ref github.event.pull_request.head.sha (and github.sha for push), export the expected full SHA, and fail before repository-controlled code unless git rev-parse HEAD exactly equals it. Rerun all four cells and verify each log records HEAD 700a1176940fb3f2713113d02816e66b745bc064. If merge-candidate coverage is also desired, run it as a separately identified job rather than presenting it as exact-head evidence.

---

# Bootstrap review Round 3 — ci-baseline

- Evidence mode: `loom-repository-bootstrap/v1`
- Conformance: degraded bootstrap; not loom-local-review/v1
- Isolation: not established under ADR 0022
- Aggregate state: `bootstrap-ran-with-findings`
- Run: `ci-baseline-b28a747-89b7679-r3`
- Base: `b28a74754e2ee016a035fa085f0d91de66057f62`
- Head: `89b7679ce52832fa00bc2513c059ce4aae73cbbe`
- Manifest SHA-256: `fea4f5dcc0e5a28761266156645735f01d8f854db5c815045a50939a4abd0fe5`
- Aggregate findings SHA-256: `d47c3cfedabc581e8ccdd7f02ad81f08bd647baa4efccd8bac89a3b922141276`

## COR-R3-1 — proposed BLOCKER

- Worker: `correctness`
- Location: `plugins/loom/adapters/roots/codex-skill-source-v1.json:4`
- Confidence: `0.98`
- Claim: The release-owned installed-root documents do not declare the complete binding semantics required by the approved plan and spec 10, so the static adapter contract is incomplete.
- Evidence: The Codex document records only a skill suffix, a manifest pathname, name/version, helper directory, forbidden environment guesses, and hook fields. It does not declare that the supplied skill path must be absolute, that the skill and plugin root are physically canonicalized, the exact ../.. ascent, canonical skill/manifest checks, an allowlist containing loom-coord, direct-child bin containment, or regular/executable-file checks. The Claude document likewise has no physical-root, absolute-invocation, direct-child-containment, or regular/executable declarations. The closed schema at plugins/loom/schemas/loom-installed-root-binding-v1.schema.json:12 permits exactly these incomplete fields, so those required guarantees cannot be represented. This conflicts with ci-baseline Step 2 and spec 10's installed-root/helper binding contract; this slice's stated purpose is to land that complete static contract even though bootstrap code is deferred.
- Suggested verification: Extend both binding documents and their closed schema to encode every required resolution, canonicalization, containment, manifest/skill, executable, and helper-allowlist rule; update release fixtures and pinned digests; then add isolated schema/semantic mutations proving omission or drift of each rule fails.

## COR-R3-2 — proposed BLOCKER

- Worker: `correctness`
- Location: `scripts/validate-repository.mjs:178`
- Confidence: `0.99`
- Claim: Metadata validation does not reject catalogs placed at a wrong repository location, despite the plan explicitly requiring wrong catalog locations to fail.
- Evidence: discover() includes every tracked JSON file, but the general JSON loop only parses it. schemaBindings validates the two expected live catalog paths and semanticMetadata reads only those same paths; no code classifies and rejects an additional catalog-shaped JSON object elsewhere. Consequently, copying the valid Codex catalog to a wrong location such as .agents/marketplace.json leaves the expected files valid and adds only another parseable JSON file, so --metadata remains green. The required regression suite also has source/path/symlink tests but no wrong-location case. This is an explicit required validator behavior and acceptance case, not merely missing defensive coverage.
- Suggested verification: In a temporary metadata root, copy each valid live catalog to representative wrong locations while retaining the correct catalog and require a deterministic wrong-location diagnostic. Implement an allowlist of the two live catalog paths plus their named release-fixture paths, rejecting any other catalog-shaped tracked JSON object.

## COR-R3-3 — proposed MAJOR

- Worker: `correctness`
- Location: `scripts/run-bats-under:30`
- Confidence: `0.97`
- Claim: The Bash launcher claims to resolve and export a physical shell path but resolves only the containing directory, leaving an executable symlink unresolved.
- Evidence: Lines 30-31 apply pwd -P to dirname(selected_bash) and then append the original basename. pwd -P resolves symlinks in directory components, not a symlink at the executable itself. The resulting physical_bash can therefore still be a symlink; line 80 creates another symlink to it, and lines 83-85 export that unresolved name as LOOM_TEST_BASH and LOOM_TEST_BASH_PHYSICAL. scripts/check:357-359 and the CI assertion use the same directory-only pattern. This violates Step 5's explicit physical-shell resolution requirement and leaves a retarget window between the version probe and Bats/child execution. Existing launcher tests cover relative, non-executable, wrong-version, and cleanup cases but not a selected executable symlink.
- Suggested verification: Add a test selecting a multi-hop symlink to the supported Bash and assert the launcher logs/exports the final regular executable path; retarget or remove the original symlink after resolution and prove Bats plus the env-bash child still use the resolved target. Use the same portable executable-resolution helper in scripts/check and the workflow assertion.

## TST-R3-001 — proposed BLOCKER

- Worker: `tests`
- Location: `scripts/validate-repository.mjs:135`
- Confidence: `high`
- Claim: Well-formed falsy JSON values can make metadata validation skip all semantic checks and still exit successfully.
- Evidence: readJson returns the parsed value directly, using null both for valid JSON null and for parse/read failure (lines 133-145). The initial scan only flips structurallyValid when the value is null and emits no diagnostic (lines 163-166); schema loading likewise treats a falsy schema as invalid without reporting it (lines 170-175); and validateJson returns false without a diagnostic for any falsy target or schema, including null, false, 0, or an empty string (lines 236-247). semanticMetadata is then skipped when structurallyValid is false (line 233), while process failure depends only on diagnostics.length (lines 440-441). Thus replacing a required manifest, catalog, matrix, binding, fixture, or schema with JSON null can leave diagnostics empty and print a passing result. The malformed-JSON tests exercise syntax errors, not well-formed falsy JSON values.
- Suggested verification: In an owned metadata fixture root, replace each required metadata class and a referenced schema independently with null (and representative false/0/empty-string values), require a file-specific schema/type diagnostic and nonzero exit, and use a distinct parse-failure sentinel so parsed JSON null is never conflated with an error.

## TST-R3-002 — proposed BLOCKER

- Worker: `tests`
- Location: `scripts/check:423`
- Confidence: `high`
- Claim: The gate launches the pinned Bats entrypoint through ambient PATH bash before the controlled launcher, contradicting the selected-absolute-Bash contract and leaving that execution outside the canary proof.
- Evidence: Line 423 runs `bash "$BATS" --version`; this is the only bare-shell launch and can resolve a different or attacker-supplied PATH executable. The selected absolute Bash is not used until the count and controlled launcher at lines 478-480, and the runtime canary runs only inside that later launch. A PATH shim can therefore execute and spoof the Bats version before any version/canary check, while all current launcher tests and the four CI canary logs remain green. The plan requires Bats to be launched by the selected absolute Bash and says no stage may silently skip a missing or mismatched tool.
- Suggested verification: Use `"$selected_bash" "$BATS" --version` for the version probe. Add a gate fixture that prepends a marker-writing fake `bash` to PATH, runs provisioning/version verification with a valid absolute selected shell, and proves the fake PATH shell is never executed.

## TST-R3-003 — proposed MAJOR

- Worker: `tests`
- Location: `scripts/run-bats-under:30`
- Confidence: `high`
- Claim: The launcher does not resolve a terminal Bash symlink even though it exports and reports the result as the physical shell path.
- Evidence: Lines 30-31 canonicalize only dirname(selected_bash) with pwd -P and then append the original basename. If the selected executable itself is a symlink, physical_bash is still that symlink. The launcher version-checks it, exports it as LOOM_TEST_BASH_PHYSICAL, and creates another symlink to it (lines 33, 80, and 83-85), so a final-component retarget between the check and launch can select different bytes. scripts/check lines 357-358 and the workflow lines 101-103 use the same parent-only construction. Existing rejection/canary/cleanup tests cover relative, non-executable, below-floor, mismatch, order, failure, and signals, but never a terminal symlink or retarget. This does not invalidate the supplied CI cells because their fixed /bin/bash and /usr/bin/bash paths produced the required versions, but it leaves the documented local launcher contract unproved.
- Suggested verification: Resolve the complete executable path, including the final symlink, into an immutable canonical path before checking or invoking it. Add a test that selects a terminal symlink, verifies the exported/logged physical path is the real target, and retargets the original link after resolution without changing the interpreter used by Bats and its child.

## TST-R3-004 — proposed BLOCKER

- Worker: `tests`
- Location: `plugins/loom/adapters/roots/codex-skill-source-v1.json:4`
- Confidence: `high`
- Claim: The Codex installed-root object and its closed schema omit required safety declarations, so schema/fixture equality cannot prove the planned root-binding contract.
- Evidence: The plan requires codex-skill-source/v1 to declare an absolute selected `skills/<skill>/SKILL.md` input, the exact suffix/ascend rule, canonical skill and manifest checks, canonical direct-bin containment, an allowlisted helper, and regular-executable enforcement. The object contains skillSuffix, ascendToManifest, expected identity, and helperDirectory, but has no absolute-input requirement, explicit canonicalization/containment checks, allowedHelpers value, or regular/executable requirement (lines 4-9). The corresponding schema closes the object to exactly this incomplete key set (loom-installed-root-binding-v1.schema.json lines 11-13), its release fixture merely mirrors it, and semantic validation checks only expectedName/expectedVersion after schema validation (validate-repository.mjs lines 333-335). Consequently the green root-binding, schema, digest, and fixture-drift evidence proves consistency of an under-specified object, not the required contract.
- Suggested verification: Extend the versioned Codex root-binding object and closed schema with explicit absolute-source, suffix/ascend, canonical skill/manifest, helper allowlist, direct-bin containment, regular-file, executable, and absolute-invocation requirements; update the release fixture/digest and add one isolated rejection test per required field or enum. Apply equivalent explicit physical/direct-containment declarations to the Claude binding where the schema currently relies only on field names.

## SEC-R3-001 — proposed medium

- Worker: `security`
- Location: `scripts/check:25`
- Confidence: `high`
- Claim: HUP, INT, or TERM can make an interrupted gate exit successfully, allowing incomplete validation to be represented as a passing command.
- Evidence: The new cleanup handler saves `$?` and exits with that value (lines 12-18), while line 25 installs it directly for EXIT, HUP, INT, and TERM. For a signal delivered after a successful command or between commands, `$?` is 0 rather than a signal-specific failure status. Running the same trap pattern under /bin/bash with `:; kill -TERM $$` printed `cleanup-status=0` and the process exited 0. The handler can therefore terminate before later validation stages without communicating failure through the process status.
- Suggested verification: Use a cleanup-only EXIT trap and separate HUP/INT/TERM handlers that exit with fixed nonzero statuses (for example 129, 130, and 143). Add a regression harness that pauses the gate at a deterministic sentinel, sends each signal, and asserts a nonzero signal-specific status, removal of the private run directory, and absence of the final success marker.

---

# Valid bootstrap review — ci-baseline merits Round 1

- Evidence mode: `loom-repository-bootstrap/v1`
- Conformance: degraded bootstrap; not loom-local-review/v1
- Isolation: not established under ADR 0022
- Aggregate state: `bootstrap-ran-with-findings`
- Run: `ci-baseline-b28a747-c92464a-valid-r1`
- Merits round: `1`
- Base: `b28a74754e2ee016a035fa085f0d91de66057f62`
- Head: `c92464aefb6189f40227abd0904d20d2efb7debe`
- Head tree: `c4573aae54abb81ba524f52c3e93a7e57301ca56`
- Transition-state tip: `367584c3b3d0423af04194171e35c827d069a744`
- Manifest SHA-256: `bfe36caa897196f3995dac8524e987d4c0efa526a3606ba44e550370f093cb65`
- Sealed input-inventory SHA-256: `71e70ce12f7fd9f2cdc0dbf31cafaff94954e008d1b06e13c594083a8d33ce78`
- Aggregate findings SHA-256: `e0d404fdcd357e5bfd62c058b8c4026226722d49d4ad4676a59329193717e61d`

All three required cold workers completed with matching bindings. Their input
inventory remained unchanged and every location below intersects the exact diff.

## COR-R1-1 — proposed MAJOR

- Worker: `correctness`
- Location: `scripts/validate-repository.mjs:111`
- Confidence: `0.99`
- Claim: A non-Git validation root nested inside another Git worktree is misclassified
  as a real Git root, allowing discovery to return an empty tracked set and skip its
  JSON, frontmatter, and Markdown inputs.
- Evidence: `git -C <root> ls-files -z` searches parent directories. A nested,
  untracked fixture directory therefore succeeds with no paths, so the deterministic
  filesystem walk is never selected.
- Suggested verification: Compare the canonical `git rev-parse --show-toplevel` with
  the canonical explicit root before using tracked discovery, and add nested-root
  regressions for malformed metadata, frontmatter, and links.

## COR-R1-2 — proposed MAJOR

- Worker: `correctness`
- Location: `README.md:92`
- Confidence: `0.99`
- Claim: The documented support boundary omits the required exact Codex CLI `0.144.6`
  floor.
- Evidence: The development section names Claude Code `2.1.216` but describes only a
  generic supported Loom client for production. ADR 0019 and spec 10 define both exact
  v0.2 floors.
- Suggested verification: State both exact floors while retaining the static Codex
  scaffolding limitation, and mechanically assert both values in README.

## TEST-001 — proposed MAJOR

- Worker: `tests`
- Location: `scripts/tests/repository-validation.bats:756`
- Confidence: `0.99`
- Claim: The allowlist regression can pass without proving that one exact live entry
  suppresses its broken-link diagnostic.
- Evidence: The existing test expects failure because a second record is stale and
  checks only that the live record is not reported stale. It does not require the live
  allowlisted link by itself to exit zero without a broken-target diagnostic.
- Suggested verification: Split the positive live-entry case from the stale
  code-block case and mutation-test the suppression path.

## TEST-002 — proposed MAJOR

- Worker: `tests`
- Location: `scripts/tests/repository-validation.bats:144`
- Confidence: `0.96`
- Claim: Unknown-key rejection is tested only for command frontmatter, leaving agent
  and skill schema closure unproved.
- Evidence: The agent negative case removes a required name and no skill test injects
  an additional field.
- Suggested verification: Add independent command, agent, and skill unknown-key cases
  with file-specific additional-properties diagnostics.

## TEST-003 — proposed MAJOR

- Worker: `tests`
- Location: `scripts/validate-repository.mjs:18`
- Confidence: `0.98`
- Claim: The validator CLI contract lacks regression coverage for default-root
  resolution, `--all`, and rejection of missing or repeated modes.
- Evidence: Retained tests always pass an explicit root and only exercise
  `--metadata` or `--links`.
- Suggested verification: Add nested-cwd default-root, valid and failing `--all`, no
  mode, and repeated/mixed-mode cases with deterministic exit-2 diagnostics.

## EVIDENCE-001 — proposed MAJOR

- Worker: `tests`
- Location: `.docs/slice-plans/ci-baseline.md:512`
- Confidence: `0.94`
- Claim: Cwd-independent full-gate evidence is stale relative to the reviewed exact
  head.
- Evidence: The retained cwd-independent run covered the earlier 123-test tree. The
  final exact-tree local and hosted gates ran 226 tests from their checkout roots.
- Suggested verification: From an unrelated cwd, run the final exact-head gate by
  absolute path under both supported local Bash lanes and retain command, cwd, trees,
  exit, and logs.

## SEC-R1-001 — proposed BLOCKER

- Worker: `security`
- Location: `scripts/check:325`
- Confidence: `0.99`
- Claim: Security-sensitive workflow settings are validated by substring search, so
  unsafe YAML semantics can pass the toolchain-contract stage.
- Evidence: `persist-credentials: true # persist-credentials: false` enables checkout
  credentials while satisfying the current `grep`; adjacent ref/head assertions are
  similarly comment-spoofable or relocatable.
- Suggested verification: Validate the workflow with a pinned YAML parser or an exact
  verified workflow digest, and add inline-comment, commented-out, duplicate-key, and
  relocated-string mutations.

## SEC-R1-002 — proposed BLOCKER

- Worker: `security`
- Location: `scripts/validate-repository.mjs:110`
- Confidence: `0.97`
- Claim: A Git discovery failure in a real repository silently downgrades to an
  unrestricted filesystem walk and consumes untracked inputs.
- Evidence: Every `git ls-files` failure enters the non-Git fallback without first
  distinguishing a real worktree whose tracked-file trust query failed.
- Suggested verification: Positively establish the explicit root is non-Git before
  walking; fail closed for any Git discovery error in a detected worktree, with an
  unread untracked canary regression.

---

# Valid bootstrap review — ci-baseline merits Round 2

- Evidence mode: `loom-repository-bootstrap/v1`
- Conformance: degraded bootstrap; not loom-local-review/v1
- Isolation: not established under ADR 0022
- Aggregate state: `bootstrap-ran-with-findings`
- Run: `ci-baseline-b28a747-c85cdd6-valid-r2`
- Merits round: `2`
- Base: `b28a74754e2ee016a035fa085f0d91de66057f62`
- Head: `c85cdd6e944473817daae4cdc53dc736ac85d2d5`
- Head tree: `42b815a416b2bfc807941df1e3f3c5a23fcc3b26`
- Transition-state tip: `367584c3b3d0423af04194171e35c827d069a744`
- Manifest SHA-256: `556f6ddc89dd0f09a23d5d6d782168567ec9022d925bd0149867fe2d265ed04c`
- Sealed input-inventory SHA-256: `99ae338fd6eda0772b4af0eac02899da7ab45745984a347622b8a63712cdcafb`
- Aggregate findings SHA-256: `ea9462777cb0de0565470c32eb08fe1c9c30a8415e92beed849b9adf5faae34a`

All three required cold worker outputs completed with matching bindings. The security
stage was interrupted before producing output when its execution quota was exhausted.
ADR 0023 section 8 classified that as infrastructure failure, not a merits round;
after limits were restored, every input reverified hash-identical and only the failed
stage resumed. The resumed security output was clean. The sealed input inventory and
source remained unchanged, finding IDs were unique, and every finding intersects the
exact diff.

## R2-001 — proposed BLOCKER

- Location: `.agents/plugins/marketplace.json:9`, with the same claim in
  `plugins/loom/.codex-plugin/plugin.json:4` and their release fixtures
- Confidence: `0.99`
- Claim: Newly added Codex metadata publishes unqualified “blind evaluation” and
  “blind-reviewed” claims that ADR 0022 expressly forbids in user-facing material.
- Evidence: ADR 0022 requires the exact claim “independent cold-agent evaluation with
  controlled inputs” unless a narrower term is immediately qualified by that
  boundary. The new client-visible catalog, manifest, and fixtures use the stronger
  prohibited wording without qualification.
- Suggested verification: Replace the claims consistently across live metadata,
  release fixtures, and README; refresh pinned digests; and add an isolated validator
  regression that rejects every prohibited unqualified phrase.

## R2-002 — proposed MAJOR

- Location: `scripts/check:356-369`
- Confidence: `0.99`
- Claim: Required Git `2.34` and jq `1.6` runtime-floor rejection has no negative or
  exact-boundary test coverage.
- Evidence: The suite covers a below-floor selected Bash, while its runtime-contract
  mutation exits during contract validation and never exercises installed Git or jq
  version parsing. All retained local and hosted gates use above-floor versions.
- Suggested verification: Add isolated delegating Git and jq shims for values just
  below each floor and exactly at each floor; assert actionable rejection below the
  floor and acceptance at the boundary.

## R2-003 — proposed MAJOR

- Location: `scripts/check:29-43`
- Confidence: `0.98`
- Claim: The required first-failure stage diagnostic and stage advancement are not
  tested.
- Evidence: No retained test asserts `FAILED stage <stage> (exit <status>)`, the
  original exit status, correct stage attribution, or the absence of later-stage
  execution. Successful full-gate logs never exercise this path.
- Suggested verification: Inject deterministic failures at two different stages and
  assert the exact single diagnostic, original status, correct stage, and absence of a
  later-stage marker.

The security worker returned zero findings.

---

# Valid bootstrap review — ci-baseline merits Round 3

- Evidence mode: `loom-repository-bootstrap/v1`
- Conformance: degraded bootstrap; not loom-local-review/v1
- Isolation: not established under ADR 0022
- Aggregate state: `bootstrap-ran-with-findings`
- Run: `ci-baseline-b28a747-b6d87a2-valid-r3`
- Merits round: `3`
- Base: `b28a74754e2ee016a035fa085f0d91de66057f62`
- Head: `b6d87a21a7df54b4be6c29b4fa73bf3ef9d971fe`
- Head tree: `5b1d788ce2d8ae59cd91e3aec5dc39748996db31`
- Transition-state tip: `367584c3b3d0423af04194171e35c827d069a744`
- Manifest SHA-256: `0cbb3cd8b58b2f43f0b98d79d36a5d06cbc022c2ded5943ffe0a45eac42590f0`
- Sealed input-inventory SHA-256: `ba2af4b2f435451bdc81edec2be6e6278835eadde5360745f03e19e0ec308a5b`
- Aggregate findings SHA-256: `dd4fef582948c2dacf5e6a5e963970f5088de6dccbcf284f060c0ce562452d11`

All three cold workers completed with exact bindings; correctness and security were
clean. The source and sealed input inventories remained unchanged and the sole finding
intersects the exact diff. A Bash 3.2 evidence-wrapper attempt completed the gate but
failed to capture exit/end metadata because the wrapper used a zsh-reserved variable.
That incomplete attempt is retained as infrastructure-only evidence. After the exact
clean tree was reverified, only Bash 3.2 was rerun, successfully, under ADR 0023
section 8.

## R3-001 — proposed MAJOR

- Location: `scripts/check:413-429`
- Confidence: `high`
- Claim: The required unsupported OS/architecture rejection has no negative
  regression coverage.
- Evidence: The gate accepts only Darwin arm64/x86_64 and Linux x86_64 and requires
  every other pair to emit `Unsupported check host`. Neither retained Bats suite
  controls `uname -s` or `uname -m` to exercise an unknown OS or unsupported
  architecture. Both local lanes and all four CI cells are supported-host positives.
- Suggested verification: Add isolated negative cases for an unknown OS and a
  supported OS with an unsupported architecture; assert nonzero status, the exact
  actionable diagnostic, and that provisioning/download execution is not reached.

---

# Valid bootstrap review — ci-baseline merits Round 4

- Evidence mode: `loom-repository-bootstrap/v1`
- Conformance: degraded bootstrap; not loom-local-review/v1
- Isolation: not established under ADR 0022
- Run: `ci-baseline-b28a747-df3714f-valid-r4`
- Base: `b28a74754e2ee016a035fa085f0d91de66057f62`
- Head: `df3714f1fa60d3ea41df9c07e821b2204b304979`
- Head tree: `2697ba389b9b59952279f11f17316d4816e9c88a`
- Manifest SHA-256: `de34b8a93064b5ef2b3bc1c1acc0dbd8ae736c9dcb917377a61bac186aa0bfad`
- Input-inventory SHA-256: `833a27cca334479e0d1eacb1bb0acf40b8461a805fbb9a1bf32473e9057383da`
- Aggregate findings SHA-256: `f9847c8104dc74af4c54083c58d74d2d1828db79cd7a7fbe95423c531b48ed66`

Correctness was clean. All worker bindings and inventories validated.

## R4-001 — proposed MAJOR

- Location: `scripts/check:474-501`
- Claim: The gate does not enforce the exact `#!/usr/bin/env bash` first line on the
  three shipped executables; all current checks force Bash independently.
- Suggested verification: Assert each exact first line and independently mutate each
  shebang to `/bin/sh`.

## R4-002 — proposed MAJOR

- Location: `scripts/check:138-157`
- Claim: Cache mode repair can follow a hard link and chmod an unrelated same-UID file
  before authentication because link count is not checked.
- Suggested verification: Never repair an untrusted shared inode in place; require
  safe metadata and link count one, with an outside-sentinel regression.

---

# Valid bootstrap review — ci-baseline merits Round 5

- Evidence mode: `loom-repository-bootstrap/v1`
- Conformance: degraded bootstrap; not loom-local-review/v1
- Isolation: not established under ADR 0022
- Aggregate state: `bootstrap-ran-clean`
- Run: `ci-baseline-b28a747-c52ff82-valid-r5`
- Merits round: `5`
- Base: `b28a74754e2ee016a035fa085f0d91de66057f62`
- Head: `c52ff8260c90dc4e0961752e9d6fcc8107075d2e`
- Head tree: `82e6953cd412c5171967d41fb063f97d7512ba15`
- Transition-state tip: `367584c3b3d0423af04194171e35c827d069a744`
- Manifest SHA-256: `1600467825f4a3358b1f81f690fb0a2d785d447d515c9116e2dca1baf7a88ccf`
- Input-inventory SHA-256: `33aa8ab7e38c3dfecdb81651858fd723aaa4a255591953ae21e36e06e115a8b6`
- Aggregate findings SHA-256: `6b4df9699e178ba8ef31029558ed618e8c9394f9d02efeff7a68b49f62e60909`

Correctness, test-sufficiency, and security workers completed with exact bindings,
unchanged source inventory, and zero findings. The exact shipped-script shebang
enforcement and hard-linked outside-sentinel regression close both Round 4 findings.

---

# Integrated publication review — ci-baseline round 0

- Evidence mode: `loom-repository-bootstrap/v1`
- Conformance: degraded bootstrap; not `loom-local-review/v1`
- Isolation: not established under ADR 0022
- Run: `ci-baseline-publication-c7bd84d-06f9f45-r0`
- Base: `c7bd84d997afb32f6159628eb840a9dd8d2d3dca`
- Head: `06f9f45ef4ba6f5ee838c627ffdca25544863273`
- Head tree: `2e4a6a134a0324d50f91275be94ea0a485931e27`
- Manifest SHA-256: `63e397580ab94dd681daf52a9d23bd0f5d82ecb966edcdb4dde9dfa36bb99cb9`
- Input-inventory SHA-256: `270b9607e6c04a1ac3a087b026b11903a73985d101b56633022bbaae4f12a364`
- Aggregate SHA-256: `c4c44eb32ca6a18465517e6672a9bc058a74cf78c6591a96deabbea02204ae29`

Test sufficiency was clean. Correctness proposed `COR-001`: the post-merits
allowlist edit was outside ADR 0024's permitted finalization path classes. Security
proposed `SEC-PUB-001`: a concurrent same-user path replacement could race the
validator's static containment check and read.

The distinct evaluator confirmed `COR-001` as a BLOCKER and rejected
`SEC-PUB-001` as outside M0's approved trust model. Both fresh exact-candidate gates
passed 257/257 strictly sequentially, but green gates cannot override publication
authority. Round 1 must remove the gate-policy delta and retain link validity using
only authorized declared-plan/archive-index/evaluation/living-status paths.
