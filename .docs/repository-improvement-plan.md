# Repository Improvement Plan

Status: Draft

Date: 2026-07-21

## Objective

Move loom from a promising alpha to a production-safe, reproducibly validated
plugin. Address safety and concurrency risks first, replace unstable external
review dependencies with a versioned local mechanism, make remote publication
the authoritative landing boundary, strengthen evaluation isolation, turn prose
invariants into executable checks, reconcile packaging and documentation, and
then optimize the workflow's cost and ceremony.

## Ordering and release policy

Execute the work in this order:

1. Establish a reproducible baseline and CI gate.
2. Fix coordinator filesystem and concurrency safety.
3. Make remote publication authoritative and isolate each slice from local
   `main`.
4. Repair hook enforcement and per-session write-ahead semantics.
5. Replace external review commands with a loom-owned local review pipeline.
6. Make the evaluation trust model accurate and materially isolated.
7. Add `loom doctor` and executable repository invariants.
8. Reconcile packaging and documentation, then publish a release.
9. Benchmark the workflow and introduce proportional process profiles.

Do not publish or recommend a new release until milestones M0 through M7 are
green. Each named slice below should remain independently reviewable; do not
combine coordinator concurrency changes with review-pipeline work.

---

## M0 — Establish a trustworthy baseline

Purpose: make every subsequent change reproducibly testable.

### Slice: `ci-baseline`

Add one documented local entry point, such as `scripts/check`, that runs:

1. JSON and frontmatter validation.
2. `shfmt`.
3. `shellcheck`.
4. Shell syntax checks.
5. All existing Bats tests.
6. Relative-link checking.
7. `claude plugin validate`.
8. `git diff --check`.

Add GitHub Actions for:

- Ubuntu.
- macOS.
- Pinned versions of Bats, ShellCheck, and shfmt.
- A documented minimum Claude Code version.
- Test-count reporting without hard-coding the count.

Decide the shell support contract:

- Either make the coordinator genuinely POSIX and remove non-POSIX `local` use;
  or
- Declare Bash, use a Bash shebang, and test the supported Bash versions.

Explicitly document whether Windows or Git Bash is supported.

#### Acceptance criteria

- A fresh clone can run one documented command and reproduce the full gate.
- CI runs on both supported operating systems.
- Tool versions and installation steps are pinned or reproducible.

---

## M1 — Fix coordinator safety

Purpose: close filesystem escape and lock-ownership defects before feature work.

### Slice: `coord-identifier-boundaries`

Add centralized validation for all externally supplied identifiers:

- Session IDs.
- Slice names.
- PIDs.
- Checkpoint arguments where applicable.

Recommended session grammar:

```text
[A-Za-z0-9][A-Za-z0-9._-]{0,127}
```

Required behavior:

- Reject `/`, `..`, whitespace, tabs, newlines, and control bytes.
- Verify every computed state path remains below `.git/loom`.
- Replace recursive deletion of computed session paths with deletion of known
  files followed by `rmdir` where practical.
- Validate session IDs decoded from claim blobs before using them as paths.
- Define recovery behavior for malformed persisted state: preserve or quarantine
  it rather than following or deleting an unsafe path.

Regression cases:

- `x/../../victim`.
- Absolute paths.
- Empty and overlong identifiers.
- Tabs and newlines.
- Similar-looking Unicode separators.
- Malformed session IDs injected directly into claim blobs.

#### Acceptance criteria

- No accepted identifier can escape `.git/loom`.
- Malformed persisted state cannot cause an out-of-tree write or deletion.
- Every destructive operation has a validated, contained target.

### Slice: `coord-lock-ownership`

Create a single lock abstraction used by every coordinator command:

- `lock_acquire`.
- `lock_verify_self`.
- `lock_heartbeat`.
- `lock_release_if_self`.

Remove duplicated inline acquisition and release implementations.

Before every shared-state mutation:

1. Confirm the lock ref exists.
2. Decode and validate it.
3. Confirm the holder session is the current session.
4. Confirm the lease is fresh.
5. Abort if ownership changed.

At release, never delete a ref merely because its SHA is current. Confirm that
the current ref still belongs to the caller, then perform the delete CAS.

Add forced-race tests where:

- Cleanup holds a two-second lock.
- A peer steals it after expiry.
- The original cleanup attempts to continue and release.
- The peer's lock survives.
- No claim is mutated after ownership loss.

#### Acceptance criteria

- A stale former holder cannot mutate shared state.
- A stale former holder cannot release a successor's lock.
- Long-running critical sections heartbeat or fail closed.

### Slice: `coord-schema-cas`

Make schema initialization genuinely fail closed:

- Create `refs/loom/schema` with a null-SHA CAS.
- If the CAS loses, re-read and verify the winner's version.
- Treat hash, read, parse, or update failure as exit 10.
- Keep teardown and recovery commands usable with an unknown schema.
- Define migration and cleanup behavior for the current schema version.

#### Acceptance criteria

- Concurrent incompatible initializers cannot both proceed.
- A schema write failure cannot silently grant coordination access.
- Unknown schemas do not wedge teardown or recovery.

---

## M2 — Make remote publication the landing boundary

Purpose: prevent unrelated completed slices from accumulating on local `main`
and being pushed as one batch. A session lands only its own reviewed integration
candidate, and remote state—not local `main`—determines whether it is landed.

Git cannot merge directly inside a remote repository. Loom must construct the
candidate commit locally, then atomically update the configured remote branch.

### Decision slice: `landing-authority-and-modes`

Record an ADR that supersedes the current shared-local-`main`, no-push policy in
ADR 0014, the parallelism guide, and spec 04.

Define these invariants:

- The configured remote branch, normally `origin/main`, is authoritative.
- Local `main` is a disposable mirror or cache, never the landing transaction.
- `Landed` means the remote target ref was verified at the published SHA.
- A local merge, successful test, or successful push response alone does not
  make a slice `Landed`.
- Code, final documentation, index updates, and evaluation evidence for a slice
  are published in one candidate ref update.
- Loom never force-pushes the target branch.
- Loom never silently changes landing mode because a remote is unavailable or
  branch protection rejects a push.

Support explicitly configured landing modes:

| Mode | Intended use | Publication boundary |
|---|---|---|
| Remote direct | Solo owner and unprotected target | Non-force fast-forward push of one integration candidate |
| PR per slice | Shared or protected repository | Verified merge of one slice PR |
| Merge queue | High concurrency or required checks | Queue-confirmed merge of one slice candidate |

Remote direct should be the first implementation because it solves the current
same-repository, multi-session batching problem without requiring a hosting
provider API. PR and merge-queue modes should reuse the same candidate-building
and status machinery through provider adapters.

Document the coordination boundary:

- Worktrees in one clone share `refs/loom/*`, so a local publish lock can reduce
  wasted same-clone races.
- Separate clones do not share Loom's local refs. The remote branch's
  fast-forward check is the final publication CAS, but it does not prevent two
  clones from claiming the same slice.
- Cross-clone claim exclusion therefore requires remote claim refs, a provider
  merge queue, or another explicitly configured global coordinator. Do not claim
  cross-clone exclusion until one exists.

#### Acceptance criteria

- Specifications and guides identify one authoritative target ref and one
  precise definition of `Landed`.
- Every supported mode has explicit success, retry, and recovery semantics.
- Documentation distinguishes same-clone coordination from cross-clone
  coordination.

### Slice: `remote-first-integration-candidate`

Add a landing helper, for example `loom-land`, that builds a candidate without
merging into local `main`:

1. Fetch the configured remote and resolve the exact target SHA.
2. Create a disposable integration branch and worktree at that SHA.
3. Merge or replay only the current slice branch into that worktree.
4. Prepare the slice's final tracked status, indexes, and evaluation evidence
   there.
5. Run the integrated gate against the exact candidate SHA.
6. Re-fetch the remote target immediately before publication.
7. If the target moved, rebuild from the new SHA and rerun the applicable
   integrated gate and review checks.
8. Publish with an ordinary non-force push of the candidate SHA to the target
   branch. A racing update must be rejected as non-fast-forward.
9. Verify the remote target ref equals the intended published SHA.
10. Only after verification, record the verified publication receipt in
    coordinator state, release the claim, and run idempotent cleanup.
11. Optionally fast-forward local `main` when it is clean and safe to do so;
    failure to update the mirror must not invalidate a successful publication.

Build, merge, and test outside the publish lock. For sessions sharing one clone,
hold the publish lock only while re-fetching and comparing the base, pushing,
verifying the remote ref, and recording the result. The remote fast-forward
update remains the final concurrency check.

The candidate may contain the final tracked `Landed` status so code and
documentation can arrive in one ref update. That text has no authority while the
candidate is merely local: its meaning becomes true only when the verified
remote target contains the candidate. Runtime status and recovery logic must
therefore derive landing from the remote ref plus the publication receipt, not
from an unpushed worktree file.

The candidate manifest should record:

- Slice and session identifiers.
- Remote name and full target ref.
- Slice head, initial remote base, and candidate SHA.
- Final pre-push remote base.
- Gate and review evidence hashes.
- Landing mode and helper/protocol version.
- Push and verification outcome.

#### Acceptance criteria

- A dirty, ahead, or stale local `main` cannot contaminate a candidate.
- Publishing one slice cannot include unrelated commits accumulated on local
  `main`.
- Two concurrent publishers cannot overwrite one another; the loser rebuilds or
  stops with a recoverable status.
- The remote receives code and finalization evidence for the slice atomically.
- No target-branch force push is possible through the helper.

### Slice: `coordination-state-separation`

Remove tracked-main mutation from the claim and work-start path:

- Keep active claims in `refs/loom/claims/*` and validated per-session state.
- Derive active-session displays from coordination refs and slice artifacts.
- Record in-progress documentation on the slice branch when durable evidence is
  needed; do not commit an `Active` row to local or remote `main` merely to claim
  work.
- Apply final roadmap, progress, archive, and index changes only in the
  integration candidate.
- Release a claim only after verified direct publication, confirmed PR merge, or
  confirmed merge-queue completion.
- Make post-publication cleanup idempotent so a successful remote update can be
  recovered after a local crash.

Add an explicit lifecycle state such as `Ready to Publish` between implementation
approval and `Landed`. A network or concurrency failure leaves the slice in that
recoverable state instead of changing local `main` or falsely marking it landed.

Required failure semantics:

| Condition | Required result |
|---|---|
| Network unavailable | Preserve candidate and claim; remain `Ready to Publish` |
| Remote target advanced | Rebuild from the new remote SHA; never force push |
| Overlapping remote change | Rerun integrated tests and affected review/evaluation checks |
| Push succeeded, local cleanup failed | Treat remote as authoritative and recover cleanup idempotently |
| Local `main` is dirty or ahead | Ignore it; build from the fetched remote target |
| Branch protection rejects direct push | Stop with a mode error or use explicitly configured PR mode |
| Remote publication cannot be verified | Do not mark `Landed` or release the claim |

Add concurrent integration tests that run two sessions from the same remote base
and prove:

- Each successful remote update contains exactly one slice plus its finalization
  artifacts.
- The second session cannot accidentally publish the first session's unrelated
  local-main history.
- A rejected publisher rebuilds against the new remote target.
- Failed or offline publication leaves local `main` unchanged.

#### Acceptance criteria

- Claim acquisition and implementation do not create commits on local `main`.
- Every slice has a durable, recoverable publication state.
- `Landed` and claim release occur only after the configured remote publication
  boundary is confirmed.

---

## M3 — Repair hook enforcement and write-ahead semantics

### Slice: `identity-guard-contract`

First define the actual guarantee. Recommended policy: fail closed on recognized
identity-mutation tokens, accepting documented false positives instead of
claiming complete shell parsing.

Cover at least:

- `git config user.name` and `git config user.email` writes.
- `--local`, `--global`, and `--system` configuration writes.
- `--author`.
- `-c user.*`.
- `GIT_AUTHOR_*` and `GIT_COMMITTER_*`.
- `sh -c`, `bash -c`, `env`, and common wrapper forms.

Add a post-command verifier that detects whether `HEAD` advanced and confirms:

- Author matches the configured identity.
- Committer matches the configured identity.
- No forbidden fallback identity appeared.

If prevention was bypassed, stop the workflow and provide explicit remediation.

Tests must include the known reproductions:

- `git config user.name Evil`.
- `git config user.email evil@example.com`.
- `sh -c 'git commit --author=Evil ...'`.
- Direct `--author`, environment, and `-c user.*` forms.
- Safe identity reads and ordinary commits.

#### Acceptance criteria

- All known bypasses are covered by regression tests.
- Remaining dynamic-shell limitations are stated explicitly.
- The hook documentation no longer claims broader enforcement than exists.

### Slice: `precompact-per-session`

Replace the repository-wide marker with session-specific state:

```text
.git/loom/precompact/<safe-session-id>/marker
```

For coordinated sessions, validate advancement of the actual per-session
checkpoint written by `loom-coord checkpoint-write`.

Also:

- Write markers atomically.
- Sanitize session IDs before logging.
- Rotate or cap `precompact.log`.
- Remove the ineffective "rerun `/compact`" remediation.
- Define first-run behavior explicitly.
- Handle concurrent compactions safely.

Tests must simulate two sessions where only one advances. The non-advancing
session must still be blocked.

#### Acceptance criteria

- One session's progress cannot authorize another session's compaction.
- Manual remediation always provides a real path forward.
- Logging is bounded and injection-safe.

---

## M4 — Replace external review commands

Purpose: make review behavior local, versioned, PR-independent, and testable.

### Slice: `local-review-protocol`

Record an ADR defining `loom-local-review/v1`:

- Exact base and head SHAs.
- Review manifest schema.
- Finder status vocabulary.
- Findings schema.
- Invalid and partial-run behavior.
- Provenance fields.
- Network-silent requirement.
- Protocol and prompt versioning policy.

The code evaluator remains the sole owner of the final PASS/FAIL verdict.

### Slice: `local-review-helper`

Add `bin/loom-review` with these subcommands:

- `prepare`.
- `validate`.
- `assemble`.
- `status`.
- `clean`.

`prepare` must:

- Verify the exact base and head commits.
- Reject ambiguous or dirty review targets.
- Record renamed, binary, added, and deleted files.
- Export the source at `head` without `.git`.
- Calculate and record a diff hash.
- Record the plan, relevant specs, and gate evidence.

`validate` must reject:

- Missing finders.
- Invalid JSON.
- Locations outside the reviewed diff.
- Modified source exports.
- Truncated or failed runs.
- Unknown protocol versions.

### Slice: `local-review-agents`

Add loom-owned review agents:

- `review-correctness` — behavior, edge cases, and plan/spec conformance.
- `review-tests` — test sufficiency and meaningful failure coverage.
- `review-security` — security consequences introduced by changed lines.

Start with correctness and security if cost needs to remain controlled. Review
agents produce structured findings only; they never determine the verdict or edit
product code.

Each finding should include:

- Stable ID.
- Reviewer name.
- Confidence.
- Proposed severity.
- File and line.
- Claim.
- Concrete evidence.
- Suggested verification or reproduction.

### Slice: `local-review-orchestration`

Replace `/code-review` and `/security-review` throughout the commands, playbook,
rubrics, specs, and ADRs.

Remove dependence on:

- GitHub or a PR number.
- `origin/HEAD`.
- External review plugins.
- Hidden slash-command updates.
- Remote branch state.

The orchestrator should run:

```sh
run_id=$(loom-review prepare --slice ... --base ... --head ...)
# Spawn the loom-owned reviewer agents against the prepared run.
loom-review validate --run "$run_id"
loom-review assemble --run "$run_id" \
  --output ".docs/evaluations/<slice>-review-findings.md"
loom-review clean --run "$run_id"
```

Any missing, failed, or malformed finder makes the run invalid, never clean.

#### Acceptance criteria

- A clone with no remote can review a committed slice from two exact SHAs.
- The output is schema-valid and records full provenance.
- No review step uses GitHub, a PR, or the network.
- The code evaluator continues to adjudicate every finding.

### Slice: `local-review-defect-battery`

Create maintained fixtures containing planted examples of:

- Race conditions.
- Incorrect edge handling.
- Misleading tests.
- Authentication and authorization defects.
- Shell injection.
- Scope violations.

Do not assert exact LLM wording in CI. Track detection rates in benchmark reports
and use schema validity and failure handling as deterministic CI assertions.

---

## M5 — Make the evaluation trust model accurate

### Decision slice: `evaluation-trust-model`

Choose and document one of these claims:

1. Independent cold-agent evaluation with controlled inputs; or
2. Strong isolated blind evaluation.

Immediately use the more accurate first wording until stronger isolation is
actually implemented.

### Slice: `sanitized-evaluation-workspace`

Construct evaluator inputs in an exported directory containing only:

- Source at the exact reviewed SHA.
- Exact diff.
- Approved plan.
- Relevant specs and ADRs.
- Gate evidence.
- Local-review findings.

Exclude:

- `.git`.
- Commit author metadata.
- Status history.
- Prior role transcripts.
- Unrelated evaluations.
- Developer scratch material.

Make source files read-only and give every reviewer a separate writable output
directory.

#### Acceptance criteria

- Evaluators can inspect the full source and rerun the gate.
- Evaluators cannot obtain authorship from the supplied workspace.
- The documented trust claim matches the actual boundary.

### Slice: `evaluation-output-recorder`

Separate analysis from repository mutation:

1. The evaluator writes a schema-valid verdict in the sanitized workspace.
2. A deterministic recorder places it under `.docs/evaluations`.
3. The orchestrator verifies and commits it.
4. The evaluator does not receive broad write access to the real checkout.

---

## M6 — Turn prose invariants into executable checks

### Slice: `loom-doctor-foundation`

Add:

```sh
loom doctor
loom doctor --json
```

Checks should cover:

- Required executables.
- Claude Code minimum version.
- Plugin manifest and component loading.
- Git identity.
- Repository cleanliness.
- Loom initialization mode.
- Coordination schema and stale claims.
- Review-protocol availability.
- Supported operating system and shell.

### Slice: `docs-state-validator`

Validate:

- Allowed `Status:` values.
- Legal lifecycle transitions.
- Evaluation naming.
- Round counters.
- One active plan per slice.
- Archive status.
- Required template headings.
- Missing authority references.
- Broken relative links.

Fix the existing broken ADR 0016 link to the archived
`multi-session-lock-helper-plan.md`.

### Slice: `living-doc-shape`

Add mechanical ownership and size rules:

- `handoff.md`: current restart state only; target at most roughly 100–150 lines.
- `progress.md`: chronological project history.
- `roadmap.md`: milestones and future work only.
- README status: derived from or checked against the roadmap.

Move old handoff history to an archive rather than deleting it.

#### Acceptance criteria

- A fresh agent can determine current state and next action without reading old
  session history.
- CI detects illegal statuses, broken links, and living-doc drift.
- `loom doctor --json` is suitable for CI and support diagnostics.

---

## M7 — Reconcile packaging and publish a release

### Slice: `packaging-conformance`

Resolve every disagreement between implementation and spec 10:

- Add an actual MIT `LICENSE`.
- Choose Semver or commit-SHA versioning.
- Update the approved spec through the required planning cycle.
- Add a changelog.
- Declare supported platforms and minimum Claude Code version.
- Document external dependencies; ideally none remain after M4.
- Update Task terminology to Agent, mentioning the compatibility alias only where
  it remains operationally relevant.

Recommended policy: adopt Semver once CI and release discipline exist.

### Slice: `readme-refresh`

The README should contain:

- Accurate status and milestone information.
- Supported environments.
- Prerequisites.
- Installation and upgrade instructions.
- A small end-to-end example.
- Files loom creates in a managed repository.
- Expected time and model/cost characteristics.
- Review and evaluation trust model.
- Known limitations.
- Recovery and uninstall instructions.

### Release: `v0.2.0`

Treat this as a breaking pre-1.0 release because identifier and coordination
schemas change.

Release requirements:

- Migration notes for existing `.git/loom` state.
- Clean-install test.
- Upgrade test.
- Fresh-clone end-to-end test.
- Green CI on all supported platforms.
- Versioned changelog and Git tag.

Do not publish until M0 through M7 are complete.

---

## M8 — Control process cost and repository noise

### Slice: `workflow-benchmark`

Measure representative workloads:

- Trivial documentation correction.
- Small localized bug.
- Normal feature.
- Security-sensitive change.
- Cross-cutting architectural change.

Record:

- Wall-clock time.
- Number of agents.
- Token usage and estimated cost.
- Commits created.
- Review rounds.
- Defects introduced.
- Defects caught before landing.
- Human interventions.

Compare every workload against a simpler single-agent baseline.

### Slice: `workflow-profiles`

Introduce owner-selected profiles:

| Profile | Intended use | Suggested flow |
|---|---|---|
| Light | Trivial, low-risk changes | Developer → gate → code evaluator |
| Standard | Normal features and bugs | Plan → developer → local reviewers → evaluator |
| Strict | Security, architecture, high risk | Research → plan review → developer → all reviewers → evaluator → owner gates |

Loom may recommend a profile, but the owner chooses it.

### Decision slice: `landing-history-policy`

Evaluate:

- Current commit-per-handoff history.
- Squash-on-land while retaining evaluation artifacts.
- Audit refs or per-slice branches retained for a defined period.

A reasonable default to test is granular commits on the slice branch, one squash
commit on the authoritative remote target branch, and durable plan/evaluation
evidence in `.docs`.

#### Acceptance criteria

- Loom can demonstrate where its extra process catches additional defects.
- Low-risk changes do not automatically incur the strict workflow's full cost.
- Main-branch history remains useful without discarding audit evidence.

---

## Milestone gates

- **After M1:** coordinator is safe enough for continued development.
- **After M2:** each slice publishes independently to an authoritative remote
  boundary without contaminating local `main`.
- **After M3:** hook and compaction claims match behavior.
- **After M4:** the core review loop has no unstable external command dependency.
- **After M5:** evaluation claims are accurate and materially isolated.
- **After M6:** repository state is mechanically diagnosable.
- **After M7:** publish `v0.2.0`.
- **After M8:** use benchmark evidence to decide whether loom is ready for beta.

## Definition of done for the program

The improvement program is complete when:

- No user-controlled coordinator identifier can escape its state directory.
- Lock loss is detected before any further mutation or release.
- Schema initialization and corruption fail closed without wedging recovery.
- Local `main` is not part of the landing transaction and cannot batch unrelated
  slices into a later push.
- A slice becomes `Landed` only after its configured remote publication boundary
  is verified.
- Concurrent remote publication uses non-force fast-forward semantics and has a
  tested rebuild path after races.
- Identity-override enforcement matches its documented guarantee.
- Write-ahead checks are session-specific.
- Review runs locally against exact SHAs with a versioned loom-owned protocol.
- Evaluation's documented trust model matches its real isolation boundary.
- CI and `loom doctor` mechanically validate the repository and plugin.
- Packaging, README, specs, manifest, license, and release tags agree.
- Measured workflow profiles make loom's rigor proportional to change risk.
