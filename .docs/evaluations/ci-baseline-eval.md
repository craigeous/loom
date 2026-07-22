# Evaluation: Reproducible local check and dual-platform CI baseline

Verdict: PASS
Round: 1
Reviewed against: approved specs 08 and 10; accepted ADRs 0018 and 0019;
repository improvement plan M0; approved dual-platform architecture research;
the current repository; prior verdict; exact revision diff `8495b84..1d46f27`;
current GitHub-hosted runner architecture labels; plan-evaluation rubric and
severity rules.

> Bootstrap authority correction: the three earlier code-evaluation sections labeled
> bootstrap Round 1 through Round 3 predate the protected transition ref required by
> ADR 0023. They remain auditable diagnostic history, but did not authorize
> publication and do not consume merits rounds. The first valid code evaluation is
> explicitly labeled Valid merits Round 1 below.

## Findings

Round-1 findings — all resolved (confirmed against the revision diff):

- [BLOCKER — RESOLVED] The required M0 static dual-client contract is now in this
  slice. The file scope and Steps 2–4 add both manifests/catalogs, the exact
  v0.2.0 release-owned compatibility matrix, its closed schema, both installed-root
  binding documents/schema, and release-owned metadata fixtures. The matrix records
  both exact client floors, all eight workflows, all five roles, `hook-wire-v1`,
  both root-binding references, and the literal approved profile map. Referential,
  schema, digest, release-provenance, semantic-drift, and real-tree checks make the
  static contract executable without misreporting it as install or behavior proof.

- [BLOCKER — RESOLVED] Malformed negative inputs can no longer poison the production
  scan. Every malformed JSON/JSON-Schema seed uses `.json.in`, malformed frontmatter
  uses `.md.in`, and allowlist overlays use `.allowlist.in`; tests materialize exactly
  one production-suffixed overlay only below a unique `mktemp -d` root and remove it
  in teardown. The plan mechanically asserts that the checked-in negative-source
  directory contains no eligible malformed `*.json` or shipped-frontmatter `*.md`,
  limits the real-tree candidate set to `git ls-files -z`, and requires a dedicated
  real-Git-root `--metadata` green test alongside the negative suite. Red-to-green
  proof and acceptance criteria repeat that coexistence explicitly.

- [BLOCKER — RESOLVED] The host/architecture and actual-shell matrix is now complete
  and reproducible. Step 8 requires Ubuntu 22.04 and 24.04 x86-64, macOS 14 arm64,
  and macOS 15 Intel x86-64, with pre-gate assertions for host, architecture, OS,
  physical shell, and `BASH_VERSION`. The current official hosted-runner table maps
  the chosen public-repository labels exactly that way. `scripts/run-bats-under`
  invokes the pinned Bats entrypoint with the selected absolute shell, controls
  `PATH` for every `#!/usr/bin/env bash` child, and exports the same absolute shell
  to every shipped-script test. A first-running canary verifies both the Bats process
  and an executable child report Bash 3.2.57 on both macOS architectures and Bash 5.x
  on both Ubuntu hosts. Missing or unavailable cells cannot pass or be allowed to
  fail.

- [MAJOR — RESOLVED] Link behavior now has an executable positive/negative regression
  suite. Temporary fixture trees cover valid targets and local/cross-file fragments,
  missing targets, bad fragments, exact historical-tree exclusions versus lookalike
  paths, malformed/duplicate/live/stale allowlist records, and code-block pseudo-links.
  The fixture suite is followed by the real-tree link gate.

No new BLOCKER, MAJOR, or MINOR findings.

## Required changes (for FAIL)

None — all Round-1 findings are resolved.

## Notes

Deferring live client behavior to the named `client-floor-adapter-smoke` slice is
consistent with the authority and does not prevent this baseline from being
independently green. ADR 0019 requires the exact-floor install/behavior matrix during
M0; it does not require every M0 obligation to land in one implementation slice.
Specs 08 and 10 distinguish the reproducible client-neutral/static gate from active
adapter and release-candidate evidence. This plan now makes that boundary unusually
clear: it neither calls M0 complete nor claims schema validity proves installation,
and it makes the later clean install/loading/invocation/cold-role/hook/profile/helper/
uninstall smoke release-blocking before M0 can close. Upgrade and fresh-clone evidence
remain correctly assigned to spec 10's release gate.

The revised slice stays independently executable and single-purpose: it establishes
the pinned local/CI baseline, migrates the existing shipped scripts and their tests to
the declared Bash runtime without product-logic changes, lands the minimum static
dual-client scaffolding needed by later adapters, and supplies mechanical proof for
each previously missing negative or cross-platform case.

---

## Code evaluation — bootstrap Round 1

Verdict: FAIL
Round: 1

- Evidence mode: `loom-repository-bootstrap/v1`
- Conformance: degraded bootstrap; not loom-local-review/v1
- Isolation: not established under ADR 0022
- Run: `ci-baseline-b28a747-8c5effd`
- Base: `b28a74754e2ee016a035fa085f0d91de66057f62`
- Head: `8c5effd0f0ce58d0c4c276abd49b9d6da715cb27`
- Manifest SHA-256: `a67057e53e76db58ad320e372da7b4f4b9a8f05a1fe2bbacc1bb487c4ee9bbfa`
- Aggregate findings SHA-256: `9b381e0860016feb37b2c0076200f0654ff8f78ed59e977814d73277b98f4622`
- Evaluator verdict SHA-256: `7b85e660cb8e8e3ba10cd452df22c0cd6e98dabd779e0b398cd52eb775dcc4f8`

### Gate rerun

- `bash-3.2`: PASS, exit 0, 123 dynamically discovered Bats tests; stdout SHA-256 `3fbd1a5a33c2ece8a4cc2b8a081fcbdae91e67fd495f76ef5c89fe57fedb601f`, stderr SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
- `bash-5`: PASS, exit 0, 123 dynamically discovered Bats tests; stdout SHA-256 `8739717985043beb8d7554b0a088a323d787ebdf45c24adcc079b304d791a5b2`, stderr SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

### Advisory-finding adjudication

- [MAJOR] `COR-1` — confirmed: scripts/check validates tool values and the checkout pin but never compares check-toolchain.json .runners with the workflow matrix, so row deletion or self-consistent row drift remains locally green.
- [BLOCKER] `COR-2` — confirmed: ShellCheck, Node, and Bats extraction is skipped when predictable cached paths exist, and only executable-controlled version text is checked before use; this violates the required digest-before-use contract and permits arbitrary cached code execution.
- [MAJOR] `COR-3` — confirmed: The 3.2 floor is checked against the interpreter running scripts/check, while the separately selected syntax/Bats shell is checked only against a caller-supplied regex and has no independent floor enforcement.
- [MAJOR] `COR-4` — confirmed: headingSlugs passes raw inline Markdown source to github-slugger; a linked heading therefore receives a different slug from its rendered GitHub heading text and valid fragments are rejected.
- [MAJOR] `COR-5` — confirmed: The required command-description, product-name, source-identity, and release-provenance negative cases are not independently exercised; these are explicit plan cases, so the omission is more than a hygiene nit.
- [BLOCKER] `TST-1` — confirmed: The implementation notes explicitly state that the four required workflow cells were not dispatched. The plan's CI verification and acceptance criteria require all four cells green and treat a missing cell as failure.
- [MAJOR] `TST-2` — confirmed: The additionalProperties test mutates only four of seven release contracts, only at top level, and accepts one generic diagnostic, leaving required contracts and nested object boundaries unproved.
- [MAJOR] `TST-3` — confirmed: Composite mutations and a generic drift assertion can remain green when individual invariants regress; required name, provenance, schema, and binding ID/path drift cases lack independent proof.
- [MAJOR] `TST-4` — confirmed: No retained test covers duplicate GitHub heading suffixes, encoded path/fragment values, Unicode encoding, or malformed percent encodings despite the plan explicitly requiring repeated IDs and safe decoding.
- [MAJOR] `TST-5` — confirmed: This independently reports the same mechanical gap as COR-1: no gate or mutation test proves the exact four workflow rows and all row fields agree with the toolchain contract.
- [MAJOR] `TST-6` — confirmed: Repository tests never invoke run-bats-under directly, so its relative/non-executable shell, wrong-version, missing-entrypoint, missing-canary, and canary-first branches can regress undetected.
- [BLOCKER] `SEC-1` — confirmed: The persistent ignored cache is trusted by predictable pathname and self-reported version after its first extraction, allowing a prior branch or process to execute arbitrary code during a trusted check.
- [BLOCKER] `SEC-2` — confirmed: The cache, download, tool, and destination paths receive no lstat/realpath containment checks; curl, cp, and extraction can follow poisoned symlinks and overwrite files outside the repository.
- [BLOCKER] `SEC-3` — confirmed: Schema errors do not stop semanticMetadata, and metadata-controlled root-binding paths are joined and read without containment; schema-invalid input can therefore dereference and potentially disclose an outside file.
- [BLOCKER] `SEC-4` — confirmed: Tracked candidates and non-Git walk symlinks are read with ordinary readFile/stat calls without physical containment, contradicting the plan's symlink-safe validation boundary and allowing outside-root reads.
- [MAJOR] `SEC-5` — confirmed: actions/checkout retains its credential by default while the next step runs PR-controlled dynamically discovered Bats files and other executable tooling; contents:read reduces impact but does not remove the exposed credential.
- [MINOR] `SEC-6` — confirmed: exec replaces run-bats-under before its EXIT trap can execute, so each run leaks its private loom-bash temporary directory; this is confirmed hygiene/resource leakage but does not independently block landing.

### Evaluator-originated findings

- [MAJOR] `EVAL-1` at `scripts/validate-repository.mjs:207` — The validator does not enforce the exact two root-binding IDs and canonical paths required by the compatibility contract. The matrix schema permits any two unique id/path objects matching a broad roots filename pattern, including duplicate IDs with different paths. semanticMetadata only reads each supplied path and compares the referenced file's schema to that supplied ID; it never compares the pair to the required claude-plugin-root-v1.json and codex-skill-source-v1.json mapping. A self-consistent alternate binding file can therefore pass. Required change: Validate the matrix rootBindings as the exact unordered pair of required ID/path objects and add isolated mutations for duplicate ID, swapped ID/path, and alternate same-schema paths.
- [MAJOR] `EVAL-2` at `scripts/check:76` — The toolchain contract validation is not closed over the required download and vendored-asset sets. The jq assertion checks versions, digest shapes, and provenance-kind values but not exact download tuples, exact vendored paths/count, required provenance fields, or completeness. Later loops verify only entries that remain listed, so deleting a required platform archive, schema, or fixture record can silently remove its digest check while the stage passes on an unaffected host. Required change: Validate exact required download platform/tool tuples and exact vendored asset paths plus required provenance fields, and add omission/mutation tests for every class.

### Required changes

- Replace the persistent executable cache trust model with fresh private extraction or independently pinned hashes for every consumed extracted artifact; reject symlinks and prove physical containment before all cache reads/writes and atomic publication.
- Obtain and retain successful logs for the exact head in all four required GitHub Actions cells: ubuntu-22.04, ubuntu-24.04, macos-14 arm64, and macos-15-intel x86_64.
- Mechanically compare the workflow matrix to the exact check-toolchain.json runner set and test row deletion plus mutation of every row field.
- Enforce Bash >=3.2 independently on the selected LOOM_TEST_BASH, add direct launcher rejection/order/cleanup tests, and remove the exec-caused temporary-directory leak.
- Build heading slugs from rendered inline text and add duplicate-heading, encoded path/fragment, Unicode, malformed-encoding, and inline-markup fragment tests.
- Split metadata/schema negative cases into one mutation per invariant, covering every manifest, catalog, matrix, binding, nested additionalProperties boundary, command description, agent name, identity/provenance field, schema version, reference, and fixture drift.
- Stop semantic validation of schema-invalid metadata; reject symlinks and enforce lexical plus physical root containment before every JSON, frontmatter, Markdown, link-target, schema, fixture, and metadata-derived read.
- Set checkout persist-credentials: false and scrub credential-bearing Git configuration/environment before executing repository-controlled tests and tooling.
- Enforce the exact root-binding ID/path pair and make check-toolchain.json validation closed over all required runners, downloads, vendored assets, digests, and provenance fields.

### Assessment

Gate result: both required commands passed all 123 dynamically discovered tests on
Bash 3.2.57 and Bash 5.3.9 with empty stderr and unchanged evaluator-copy source.

Positive evidence: the metadata happy path, pinned tools, Bash declarations,
dynamic test discovery, and Claude strict validation were operational in both local
lanes. The implementation also stated its limitations rather than presenting static
Codex metadata as install or behavior proof.

Negative evidence: four-host exact CI evidence was missing; the persistent cache
could execute unauthenticated tools or overwrite through symlinks; validator-derived
paths could escape the root; and required invariant regressions were absent.

Aggregate findings: 6 BLOCKER, 10 MAJOR, and 1 MINOR confirmed, including 2
evaluator-originated MAJOR findings. Verdict basis: confirmed BLOCKER and MAJOR
findings remained, so Round 1 was FAIL.

---

## Code evaluation — bootstrap Round 2

Verdict: FAIL
Round: 2
Required next round: 3

- Evidence mode: `loom-repository-bootstrap/v1`
- Conformance: degraded bootstrap; not loom-local-review/v1
- Isolation: not established under ADR 0022
- Run: `ci-baseline-b28a747-700a117-r2`
- Base: `b28a74754e2ee016a035fa085f0d91de66057f62`
- Head: `700a1176940fb3f2713113d02816e66b745bc064`
- Manifest SHA-256: `98a5b90538c316940a328edac440205de40217365bf2ea4660df615c2b4f20dc`
- Aggregate findings SHA-256: `8cbd1c76a21c902dc119685659dac769387f06ab141cd6a34b2ffa6207044194`
- Evaluator verdict SHA-256: `ae6d6933c77cb1652338bbeb8d4c5f3eaf677a1953ea8f5d35bffa0a4ddc32b6`

### Gate rerun

- `bash-3.2`: PASS, exit 0, 192/192 Bats; stdout SHA-256 `02e580e669b03aa705c6cee669c208509ddee5a1e37e73ecd3b9884427357382`, stderr SHA-256 `d52ea3298bdfa8ecdbd5eac5823c2e461ab663ebd3a6c112341524cc6c9db918`.
- `bash-5.3`: PASS, exit 0, 192/192 Bats; stdout SHA-256 `1355688259cd6a56b913d9dd8cdc4cd538b11639343420a592e78f0fe254a096`, stderr SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

### Advisory-finding adjudication

- [BLOCKER] `COR-R2-1` — confirmed: All four retained logs execute GitHub's synthetic pull/1/merge commit a8ee9ed, not bound head 700a117; the plan requires exact-head execution and treats absent exact-head cells as failure.
- [BLOCKER] `COR-R2-2` — confirmed: Fixture/live equality and other semantic comparisons use JSON.stringify, so schema-valid objects with reordered keys are rejected despite semantic equality. This is incorrect behavior against an explicit plan requirement, so the severity rubric makes it a blocker.
- [BLOCKER] `COR-R2-3` — confirmed: The exact diff changes three unrelated pre-existing evaluation records that are absent from the closed implementation allowlist and explicitly out of scope; cosmetic EOF edits remain scope violations under the rubric.
- [MINOR] `COR-R2-4` — confirmed: The durable Round-1 code-evaluation Assessment is literally '[object Object]', an incomplete serialization artifact. The substantive verdict remains readable, so this is non-blocking record hygiene.
- [BLOCKER] `TST-R2-1` — confirmed: The real-tree test assigns the repository root to teardown-owned TEST_ROOT and clears it only after the success assertion; any validator regression transfers to teardown and recursively removes the checkout.
- [BLOCKER] `TST-R2-2` — confirmed: Multiple tests create, truncate, and delete predictable files in the shared parent of their mktemp root. This can overwrite or remove unrelated data and is unsafe to land, which is blocker severity under the rubric.
- [BLOCKER] `TST-R2-3` — confirmed: Both manifest schemas require and support homepage, but semantic identity compares only name, version, description, license, and repository. A fixture-matched, schema-valid Codex homepage drift passes contrary to spec 10's shared metadata contract.
- [MAJOR] `TST-R2-4` — confirmed: The implementation currently rejects empty fields, but no isolated three-column empty-reason case proves the explicit nonempty-reason contract or that the broken link remains unallowlisted if that check regresses.
- [MAJOR] `TST-R2-5` — confirmed: The gate currently closes the contract, but the mutation suite omits independent changes or omissions for exact tool versions, runtime floors, checkout pin, package-lock digest, and unexpected top-level fields, leaving stated closure insufficiently regression-tested.
- [BLOCKER] `SEC-R2-001` — confirmed: A cache hit is hashed at a shared predictable pathname and later copied or extracted from that same mutable file. No authenticated private snapshot or immediate private recheck closes the race, and existing cache directories receive no ownership or mode validation.
- [BLOCKER] `SEC-R2-002` — confirmed: Independently from COR-R2-1, the workflow lacks a pull-request head ref and a pre-code exact-SHA assertion, so green status can depend on target-branch content absent from the reviewed head and cannot attest the manifest revision.

### Evaluator-originated findings

- [BLOCKER] `EVAL-R2-1` at `scripts/tests/run-bats-under.bats:1` — The implementation adds two developer test files outside the approved plan's closed path allowlist. changed-paths.txt and the exact diff add scripts/tests/run-bats-under.bats and scripts/tests/toolchain-contract.bats. The approved plan permits only scripts/tests/repository-validation.bats, scripts/tests/shell-runtime.bats, and scripts/tests/fixtures/** under scripts/tests; neither added file is listed. The plan states developers may add or edit only the enumerated paths. The severity authority defines an out-of-scope change as BLOCKER. These useful regressions must be moved into allowed paths or authorized by a reviewed plan change before implementation.

### Required changes

- For pull_request, checkout github.event.pull_request.head.sha; for push, bind github.sha. Before any repository-controlled code, assert git rev-parse HEAD equals the expected full SHA, then rerun and retain all four required exact-head cells.
- Replace JSON.stringify equality with order-insensitive structural JSON equality that preserves array order, and add reordered-object regressions.
- Enforce all supported shared manifest identity fields, including homepage, with isolated schema-valid drift tests.
- Remove the unrelated edits to the three pre-existing evaluation files.
- Resolve the out-of-allowlist additions scripts/tests/run-bats-under.bats and scripts/tests/toolchain-contract.bats by moving their coverage into authorized test paths or obtaining an approved plan revision before implementation.
- Make teardown delete only explicitly owned mktemp roots; never assign the real repository to the cleanup-owned variable. Add a forced-failure regression proving the repository survives.
- Use unique teardown-owned outside-root directories for containment sentinels so parallel tests cannot overwrite, delete, or leak shared predictable files.
- Add isolated negative tests for an empty allowlist reason and for every closed toolchain class: tools, runtime floors, checkout action pin, package-lock digest, and unexpected top-level fields.
- On every cache hit, copy into a newly created private run file, verify that private snapshot, and consume only it; publish fresh downloads separately. Reject or safely repair cache directories with unexpected ownership or permissions and add a cache-rewrite race regression.
- Replace the '[object Object]' durable assessment with meaningful structured or textual assessment output and reject such serialization placeholders when recording.

### Assessment

The two required local gates are green with 192 tests each and the evaluator-copy source inventory remains hash-identical, but green local execution is insufficient for PASS.

Confirmed advisory findings: 11; rejected: 0; evaluator-originated: 1.

- The required remote evidence does not execute the bound exact head.
- The cache trust model has a digest-before-use race that can lead to unauthenticated code execution.
- The test suite contains destructive cleanup and shared-sentinel hazards.
- Semantic metadata validation violates required equality and shared-homepage contracts.
- The exact diff contains both unrelated evaluation edits and two developer test paths outside the approved allowlist.

Round rule: One prior durable code-evaluation FAIL counts as failure 1; this valid FAIL is Round 2 and requires Round 3.

---

## Code evaluation — bootstrap Round 3

Verdict: FAIL
Round: 3
Required next round: 4

- Evidence mode: `loom-repository-bootstrap/v1`
- Conformance: degraded bootstrap; not loom-local-review/v1
- Isolation: not established under ADR 0022
- Run: `ci-baseline-b28a747-89b7679-r3`
- Base: `b28a74754e2ee016a035fa085f0d91de66057f62`
- Head: `89b7679ce52832fa00bc2513c059ce4aae73cbbe`
- Manifest SHA-256: `fea4f5dcc0e5a28761266156645735f01d8f854db5c815045a50939a4abd0fe5`
- Aggregate findings SHA-256: `d47c3cfedabc581e8ccdd7f02ad81f08bd647baa4efccd8bac89a3b922141276`
- Evaluator verdict SHA-256: `c9d075d40c95a00b30aab76cfafd2cc98eb75177e4c2eb234192623375290f41`

### Gate rerun

- `bash-3.2`: PASS, exit 0, 211/211 Bats; stdout SHA-256 `74708a23a12bd796e9e107d731d1f977165c0a3626ecab3f80261ede5481a1a6`, stderr SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
- `bash-5.3`: PASS, exit 0, 211/211 Bats; stdout SHA-256 `4f10754916c64b7581c363c75a1b45cd279455eacfcc2224316f6767ef00d6cd`, stderr SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

### Advisory-finding adjudication

- [BLOCKER] `COR-R3-1` — confirmed: Plan step 2 and spec 10 require the release-owned bindings to declare physical/canonical root and skill checks, exact Codex ascent, helper allowlisting, direct-bin containment, and regular executable enforcement. The Codex object and the closed schema cannot represent most of these guarantees; the Claude object likewise omits several required declarations. This is a required static contract, not deferred bootstrap implementation.
- [BLOCKER] `COR-R3-2` — confirmed: The plan explicitly requires wrong catalog locations to fail. Validation parses arbitrary tracked JSON but schema-binds and semantically inspects only the two expected catalog paths, so an additional catalog-shaped JSON at a wrong path is accepted. No regression covers this required case.
- [BLOCKER] `COR-R3-3` — confirmed: run-bats-under canonicalizes only the parent directory and retains a terminal executable symlink. It then reports and exports that unresolved path as physical, contrary to plan step 5, and permits retargeting between the version check and execution.
- [BLOCKER] `TST-R3-001` — confirmed: readJson uses null for both valid JSON null and errors; validateJson silently returns false for every falsy value; structurallyValid then suppresses semantic validation while process failure depends only on diagnostics. Required metadata or schemas replaced by null, false, zero, or an empty string can therefore produce no diagnostic and a zero exit.
- [BLOCKER] `TST-R3-002` — confirmed: scripts/check line 423 executes the pinned Bats entrypoint through bare PATH-resolved bash before the controlled launcher and canary. This contradicts the selected absolute Bash contract and permits an ambient PATH shim to run and spoof the probe.
- [BLOCKER] `TST-R3-003` — confirmed: The final Bash path component is not canonicalized in the launcher, check, or workflow assertion, and the tests do not exercise terminal-symlink resolution or retargeting.
- [BLOCKER] `TST-R3-004` — confirmed: Schema validity and fixture equality only prove consistency of an under-specified installed-root object. Required absolute-source, physical/canonical, helper allowlist, direct-containment, regular-file, executable, and absolute-invocation declarations are missing.
- [BLOCKER] `SEC-R3-001` — confirmed: scripts/check installs cleanup directly for EXIT, HUP, INT, and TERM; cleanup exits with the prior command status. A signal arriving after a successful command can therefore stop later stages and exit 0.

### Evaluator corroboration

- [BLOCKER] `EV-R3-001` at `plugins/loom/adapters/roots/codex-skill-source-v1.json:4` — The release-owned installed-root binding schema and documents omit required safety semantics.
- [BLOCKER] `EV-R3-002` at `scripts/validate-repository.mjs:178` — Catalog-shaped JSON at a wrong repository location is not rejected.
- [BLOCKER] `EV-R3-003` at `scripts/run-bats-under:30` — Selected Bash resolution does not canonicalize the terminal executable symlink.
- [BLOCKER] `EV-R3-004` at `scripts/validate-repository.mjs:133` — Well-formed falsy JSON can suppress semantic validation and still exit successfully.
- [BLOCKER] `EV-R3-005` at `scripts/check:423` — The Bats version probe executes ambient PATH bash outside the selected-shell contract.
- [BLOCKER] `EV-R3-006` at `scripts/check:25` — Gate signal traps can convert an interrupted, incomplete run into exit 0.

### Required changes

- Extend both installed-root binding documents, their closed schema, release fixtures, pinned digests, semantic validation, and isolated mutation tests to encode every required absolute-input, exact-ascent, physical/canonical manifest and skill, helper allowlist, direct-bin containment, regular-file, executable, and absolute-invocation guarantee.
- Detect and reject catalog-shaped tracked JSON outside the two live catalog paths and their specifically authorized release-fixture paths; add wrong-location regressions for both client catalog shapes.
- Use an explicit parse-failure sentinel and always emit file-specific diagnostics for valid falsy JSON and invalid/falsy schemas or targets; add independent null, false, zero, and empty-string mutations for required metadata classes and referenced schemas.
- Resolve the complete selected Bash executable, including terminal and multi-hop symlinks, before version checking, exporting, linking, or invocation; reuse that portable resolver in scripts/check and CI and add terminal-symlink/retarget regressions.
- Run the Bats version probe as the selected absolute Bash, and add a poisoned-PATH regression proving a fake bash is never executed.
- Separate cleanup-only EXIT handling from HUP, INT, and TERM handlers with fixed nonzero statuses; test each signal at a deterministic gate sentinel and require cleanup plus absence of the success marker.

### Assessment

Exact-head CI, scope, documentation, both evaluator gate reruns, and the transparent retained harness note passed. Authority, correctness, security, portability, and test sufficiency failed because uncovered blockers remain.

Harness note: The retained exit-128 run completed all 211 tests and product validation, then failed only at the optional LOOM_DIFF_BASE object check because the synthetic one-commit evidence copy intentionally omitted the real base object. The documented no-override developer gates passed, both evaluator reruns passed, and the sealed four-job CI evidence executed the real b28a74754e2ee016a035fa085f0d91de66057f62 to 89b7679ce52832fa00bc2513c059ce4aae73cbbe range successfully. The retained failure is honest provenance and does not weaken the exact-head or real-range evidence.

---

## Code evaluation — valid bootstrap merits Round 1

Verdict: FAIL
Round: 1
Required next round: 2

- Evidence mode: `loom-repository-bootstrap/v1`
- Conformance: degraded bootstrap; not loom-local-review/v1
- Isolation: not established under ADR 0022
- Run: `ci-baseline-b28a747-c92464a-valid-r1`
- Base: `b28a74754e2ee016a035fa085f0d91de66057f62`
- Head: `c92464aefb6189f40227abd0904d20d2efb7debe`
- Head tree: `c4573aae54abb81ba524f52c3e93a7e57301ca56`
- Transition-state tip: `367584c3b3d0423af04194171e35c827d069a744`
- Manifest SHA-256: `bfe36caa897196f3995dac8524e987d4c0efa526a3606ba44e550370f093cb65`
- Aggregate findings SHA-256: `e0d404fdcd357e5bfd62c058b8c4026226722d49d4ad4676a59329193717e61d`
- Evaluator verdict SHA-256: `8a5afa8f17899fcee81bfb373b5ebfbd7f1612d0a7f9471a836a979024ccb281`
- Exact-head CI run: `29865566135`, all four required jobs successful with
  `1..226` and `All checks passed`.

### Authoritative evaluator gate rerun

The evaluator retained two infrastructure-only attempts as invalid diagnostics: one
shared-copy concurrency attempt, then one separate-copy attempt whose concurrently
running coordinator tests collided through deterministic global temporary paths.
ADR 0023 section 8 permits a failed infrastructure stage to restart when every input
remains hash-identical. The authoritative rerun therefore used fresh lane-specific
copies strictly sequentially:

- Bash 3.2: PASS, exit 0, 226/226 tests, clean exact tree before and after; stdout
  SHA-256 `7cb6e690a23f5bb78966c5dfa56c08a8579002d77f31a78e9a5726b552e843e8`,
  stderr SHA-256 `958b4ca21249222452fa0d36f3d1301f753e482c91b98a0d3ceaddba921ca653`.
- Bash 5.3: PASS, exit 0, 226/226 tests, clean exact tree before and after; stdout
  SHA-256 `72397d8782160cf9344729443054eae3fa8195e276f37dbbb02c131210dae79d`,
  stderr SHA-256 `d9c1d388c5ceb720b1ce546a2f966e98c7d1eecc0a4d2c45233ca328a1796e28`.

### Advisory-finding adjudication

- [MAJOR] `COR-R1-1` — confirmed: an explicit non-Git root nested in a worktree can
  inherit the ancestor Git root and silently discover no inputs instead of using the
  required filesystem walk.
- [MAJOR] `COR-R1-2` — confirmed: README names Claude Code `2.1.216` but omits the
  exact Codex CLI `0.144.6` floor required by ADR 0019/spec 10.
- [MAJOR] `TEST-001` — confirmed: the composite allowlist test does not prove that a
  lone exact live entry suppresses the underlying broken-link diagnostic and passes.
- [MAJOR] `TEST-002` — confirmed: unknown-key coverage proves command closure only,
  not the required agent and skill frontmatter boundaries.
- [MAJOR] `TEST-003` — confirmed: no retained tests cover default-root discovery,
  `--all`, missing mode, or repeated/mixed modes.
- [MAJOR] `EVIDENCE-001` — confirmed: cwd-independent evidence predates the final
  226-test exact tree.
- [BLOCKER] `SEC-R1-001` — confirmed: workflow security and revision invariants are
  checked with comment-spoofable literal searches rather than YAML semantics.
- [BLOCKER] `SEC-R1-002` — confirmed: a real-repository Git discovery error falls
  back to untracked filesystem input instead of failing closed.

No evaluator-originated finding was added.

### Required changes

- Distinguish an explicit canonical Git root from a non-Git root before discovery;
  use tracked files only for the former, walk only a positively established non-Git
  root, and fail closed on Git errors without reading untracked canaries.
- State and mechanically test both exact client floors in README.
- Add a standalone positive live-allowlist test that requires exit zero and no
  broken-link diagnostic.
- Add independent unknown-key cases for command, agent, and skill frontmatter.
- Cover default-root resolution, `--all`, missing mode, and repeated/mixed modes with
  deterministic CLI diagnostics.
- Replace literal workflow searches with pinned semantic YAML validation or an exact
  verified workflow contract, including comment, duplicate-key, and relocation
  attacks.
- Retain final exact-head cwd-independent full-gate evidence under both local Bash
  lanes.

### Assessment

The transition latch, exact revision bindings, hosted matrix, and authoritative
sequential gate reruns are valid and green. They are necessary but insufficient:
two confirmed trust-boundary BLOCKERs and six confirmed MAJOR gaps require merits
Round 2, so the slice returns to `In Progress`.

---

## Code evaluation — valid bootstrap merits Round 2

Verdict: FAIL
Round: 2
Required next round: 3

- Evidence mode: `loom-repository-bootstrap/v1`
- Conformance: degraded bootstrap; not loom-local-review/v1
- Isolation: not established under ADR 0022
- Run: `ci-baseline-b28a747-c85cdd6-valid-r2`
- Base: `b28a74754e2ee016a035fa085f0d91de66057f62`
- Head: `c85cdd6e944473817daae4cdc53dc736ac85d2d5`
- Head tree: `42b815a416b2bfc807941df1e3f3c5a23fcc3b26`
- Manifest SHA-256: `556f6ddc89dd0f09a23d5d6d782168567ec9022d925bd0149867fe2d265ed04c`
- Aggregate findings SHA-256: `ea9462777cb0de0565470c32eb08fe1c9c30a8415e92beed849b9adf5faae34a`
- Evaluator verdict SHA-256: `a3d18bc202c1cc4311c52b7eb237789116bac682baa1b9e3a86b49835468b74e`
- Exact-head CI run: `29871936814`; all four required jobs succeeded with
  `1..243`, `All checks passed`, and exact head
  `c85cdd6e944473817daae4cdc53dc736ac85d2d5`.

### Evaluator gate rerun

The evaluator used two fresh synthetic one-commit copies whose starting tree was the
exact head tree and ran the lanes strictly sequentially:

- Bash 3.2: PASS, exit 0, 243/243 tests, unchanged tree and source inventory; stdout
  SHA-256 `5a5170c36376d7651d22dda8fb35a437a87c8c39e309fad186613c22f789ce61`,
  stderr SHA-256 `2d8d1cc547e8e6ad58464a6f32ffd7c26217df34219b4db53f26e828b1dd32fa`.
- Bash 5.3: PASS, exit 0, 243/243 tests, unchanged tree and source inventory; stdout
  SHA-256 `7ef90289df1d9bfbcd38e85b16fb4ffce0eacb7c74bedde7d5673ef2e51fd896`,
  stderr SHA-256 `4f1e36c6526a193763f26140a88878687a4a68745a60405dba1059b1d4371326`.

### Advisory-finding adjudication

- [BLOCKER] `R2-001` — confirmed: the new Codex catalog, manifest, and release
  fixtures use unqualified “blind evaluation” claims. ADR 0022 makes the exact
  controlled-input independent-evaluation wording a user-facing SHALL.
- [MAJOR] `R2-002` — confirmed: no test exercises below-floor or exact-boundary Git
  and jq versions even though their rejection is part of the approved gate contract.
- [MAJOR] `R2-003` — confirmed: no test exercises the required failed-stage
  diagnostic, original status preservation, stage attribution, or later-stage stop.

No evaluator-originated finding was added. The resumed security stage was clean; its
pre-output quota interruption was recorded as an infrastructure failure and resumed
only after every input reverified hash-identical, so it did not consume a merits round.

### Required changes

- Replace prohibited evaluation wording consistently in both client manifests,
  catalogs, README, and release fixtures; update pinned digests and add an isolated
  rejection regression for the unqualified claims.
- Add Git and jq shims proving immediately-below-floor rejection and exact-boundary
  acceptance with actionable diagnostics.
- Add deterministic failures at two gate stages proving the exact first-failure
  diagnostic, preserved exit status, correct stage advancement, and non-execution of
  later stages.

### Assessment

All developer, hosted, and evaluator gates are exact-head, source-preserving, and
green. They remain insufficient for PASS because one confirmed authority BLOCKER and
two confirmed test-sufficiency MAJOR findings remain. The slice returns to
`In Progress` for valid bootstrap merits Round 3.

---

## Code evaluation — valid bootstrap merits Round 3

Verdict: FAIL
Round: 3
Required next round: 4

- Evidence mode: `loom-repository-bootstrap/v1`
- Conformance: degraded bootstrap; not loom-local-review/v1
- Isolation: not established under ADR 0022
- Run: `ci-baseline-b28a747-b6d87a2-valid-r3`
- Base: `b28a74754e2ee016a035fa085f0d91de66057f62`
- Head: `b6d87a21a7df54b4be6c29b4fa73bf3ef9d971fe`
- Head tree: `5b1d788ce2d8ae59cd91e3aec5dc39748996db31`
- Manifest SHA-256: `0cbb3cd8b58b2f43f0b98d79d36a5d06cbc022c2ded5943ffe0a45eac42590f0`
- Aggregate findings SHA-256: `dd4fef582948c2dacf5e6a5e963970f5088de6dccbcf284f060c0ce562452d11`
- Evaluator verdict SHA-256: `b32d040ae5c62dada73d2fc7e5622650b2970a0ae9d588bd3c2d19cde8ecce0f`
- Exact-head CI run: `29937249418`; all four required cells passed 251 tests and
  ended `All checks passed` at
  `b6d87a21a7df54b4be6c29b4fa73bf3ef9d971fe`.

### Evaluator gate rerun

The evaluator used separate fresh synthetic exact-tree copies and ran them strictly
sequentially:

- Bash 3.2: PASS, exit 0, 251/251 tests, unchanged tree and byte-identical tracked
  inventory; stdout SHA-256
  `b1f2751a713458df7a493973161648f64e49addc3ad604dd08e86194f44878cf`,
  stderr SHA-256 `be4d3a935422dca8d851085248f7d193eb2bef8eb533ecd2a84d55af83bd2351`.
- Bash 5.3: PASS, exit 0, 251/251 tests, unchanged tree and byte-identical tracked
  inventory; stdout SHA-256
  `fc0f61ee684b49f0a860d20a49f954230cb0530bf328d9c0a40366c1ccb8dabc`,
  stderr SHA-256 `ac6bcca2eecca12893b520a2df20eda1445162e34a28e7b3fca8a8c53b7b6231`.

### Advisory-finding adjudication

- [MAJOR] `R3-001` — confirmed: unsupported-host rejection is an explicit approved
  gate behavior, but no test controls `uname` to prove an unknown OS or unsupported
  architecture fails before provisioning with the actionable diagnostic.

No evaluator-originated finding was added.

### Required changes

- Add isolated unknown-OS and supported-OS/unsupported-architecture gate tests using
  safe test-owned `uname` control.
- Assert nonzero status, exact `Unsupported check host` text, and a marker proving no
  provisioning or download path was reached.

### Assessment

The wording contract, runtime-floor boundaries, first-failure attribution, exact-head
CI, and both evaluator gates are green. One required portability boundary remains
untested, so the confirmed MAJOR requires valid bootstrap merits Round 4 and returns
the slice to `In Progress`.
