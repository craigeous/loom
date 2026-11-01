# Progress

Status: Living

The status source of truth and decision index for building loom.

Current milestone: M9

## Action history

- 2026-11-01 — M9 slice 1 `herdr-client-adapter` landed.
- 2026-11-01 — M8 completed with `landing-history-policy` landed.
- 2026-11-01 — M8 slice 2 `workflow-profiles` landed.
- 2026-11-01 — M8 slice 1 `workflow-benchmark` landed.
- 2026-10-31 — M7 completed with `readme-refresh` landed.
- 2026-10-31 — M7 slice 1 `packaging-conformance` landed.
- 2026-10-31 — M6 completed with `living-doc-shape` landed.
- 2026-10-31 — M6 `docs-state-validator` landed (see Current state for detail).
- 2026-10-31 — M6 `loom-doctor-foundation` landed (see Current state for detail).
- 2026-10-31 — M5 completed with `evaluation-output-recorder`.
- 2026-10-31 — `living-doc-shape` plan approved after plan-eval Round 0 PASS.

## Current state

- **Last action (2026-11-01) — M9 slice 1 (`herdr-client-adapter`) Landed:**
  Landed Herdr client adapter support: manifests (`.herdr-plugin/marketplace.json`, `plugins/loom/.herdr-plugin/plugin.json`),
  root binding `plugins/loom/adapters/roots/herdr-plugin-root-v1.json`, v0.3.0 compatibility matrix updates, `loom-resolve-helper`
  resolution case, `loom-launch-role` launcher descriptors, schema updates, discovery metadata validation in `scripts/validate-repository.mjs`,
  and 140 targeted Bats tests (923 total repository Bats tests passing). Completed local review under `loom-local-review/v1` (`ran-clean`).
  Evaluated blind cross-family by Codex (`gpt-6.1-terra`) on Orca run `run_95d038fdc54e` with Verdict: PASS (Round: 0).
  Milestone M9 is now active and in progress.

- **Prior action (2026-11-01) — M8 slice 3 (`landing-history-policy`) Landed (Milestone M8 Complete):**
  Landed decision and specification of the authoritative landing history policy in `.docs/ADR/0028-landing-history-policy.md` (Accepted),
  registered in `.docs/ADR/README.md`, and amended `.docs/spec/00-overview.md` (authority, non-goal clarification) and
  `.docs/spec/04-orchestrator.md` (authority, provisional landing history contract, fetched base as sole parent,
  receipt-bound candidate, target-movement rebuild, verified checked-tree equivalence for integration and idempotent cleanup,
  and mode conformance table for `remote-direct`, `pr-per-slice`, and `merge-queue`). Pure-docs slice with review findings recorded as
  `skipped: docs-only` (advisory, non-blocking). Evaluated blind cross-family by Codex (`gpt-6.1-terra`) on Orca run `run_aa90ff0566ff`
  with Verdict: PASS (Round: 0). Milestone M8 is now complete; advancing to Milestone M9.

- **Prior action (2026-11-01) — M8 slice 2 (`workflow-profiles`) Landed:**
  Landed owner-selected workflow profiles and recommendation helper `plugins/loom/bin/loom-profile`,
  documentation in `plugins/loom/skills/loom-playbook/references/orchestration.md` and `plugins/loom/skills/loom-run/SKILL.md`,
  and 12 automated integration tests in `scripts/tests/loom-profile.bats` (911 total repository Bats tests passing).
  Provides `resolve` subcommand with CLI-over-file-over-default precedence, risk recommendations (low, normal, high),
  JSON output, and strict preservation of spec-required lifecycle stages. Evaluated blind cross-family by Codex (`gpt-6.1-terra`)
  on Orca run `run_597335f40df5` with Verdict: PASS (Round: 0). Milestone M8 is now in progress.

- **Prior action (2026-11-01) — M8 slice 1 (`workflow-benchmark`) Landed:**
  Landed benchmark harness and paired measurement protocol for Loom and single-agent baselines in `scripts/workflow-benchmark.sh`,
  operator documentation in `docs/workflow-benchmark.md`, and 13 automated tests in `scripts/tests/workflow-benchmark.bats`
  (899 total repository Bats tests passing). Implemented in Bash 3.2+ with jq 1.6+ (161 lines of code, well under the 250 LOC budget)
  providing `init`, `validate`, and `summarize` subcommands with strict ISO 8601 calendar round-trip validation. Evaluated blind
  cross-family by Codex (`gpt-6.1-terra`) on Orca run `run_99a404744d3d` with Verdict: PASS (Round: 0). Milestone M8 is now in progress.

- **Prior action (2026-10-31) — M7 slice 2 (`readme-refresh`) Landed (Milestone M7 Complete):**
  Landed README refresh for multi-client installation and upgrade across Claude Code, Codex CLI, and Antigravity,
  an end-to-end usage walkthrough, managed repository artifacts guide, role tier expectations table, and snapshot test count updates (886 total repository Bats tests passing).
  Evaluated blind cross-family by Codex (`gpt-6.1-terra`) on Orca run `run_f98dae490f9f` with Verdict: PASS (Round: 0). Milestone M7 is now complete; advancing to M8.

- **Prior action (2026-10-31) — M7 slice 1 (`packaging-conformance`) Landed:**
  Landed packaging, versioning, and repository conformance checks in `scripts/validate-repository.mjs` and `scripts/tests/repository-validation.bats`.
  Enforces MIT license canonical text with 'Copyright (c) 2026 Craig Pfeiffer', CHANGELOG.md version [0.2.0] heading and release item requirement,
  CommonMark code-fence delimiter char and length matching, and README supported platforms and prerequisites documentation.
  Added 11 new Bats tests (886 total repository Bats tests passing). Evaluated blind cross-family by Codex (`gpt-6.1-terra`) on Orca run `run_f98dae490f9f` with Verdict: PASS (Round: 0). Milestone M7 is now in progress.

- **Prior action (2026-10-31) — M6 slice 3 (`living-doc-shape`) Landed (Milestone M6 Complete):**
  Landed living document shape and ownership rules in `scripts/validate-repository.mjs` and `scripts/tests/repository-validation.bats`.
  Enforces line budget (<= 150 lines) on `handoff.md`, required living doc headings uniqueness, `## Action history` with standard dated entries in `progress.md`,
  roadmap milestone structure, and synchronized `Current milestone: M6` markers across `README.md`, `handoff.md`, `progress.md`, and `roadmap.md`.
  Added 8 new Bats tests (875 total repository Bats tests passing). Evaluated blind cross-family by Codex (`gpt-6.1-terra`) on Orca run `run_0067ed9dc16c` with Verdict: PASS (Round: 0). Milestone M6 is now complete.

- **Prior action (2026-10-31) — M6 slice 2 (`docs-state-validator`) Landed:**
  Landed mechanical documentation state validation in `scripts/validate-repository.mjs` and `scripts/tests/repository-validation.bats`.
  Enforces active slice plan uniqueness, documentation lifecycle status transitions with baseline verification,
  clean owner reset validation, interval-bounded FAIL return evidence, authority reference resolution to applicable files,
  allowlist staleness enforcement under `--all`, and 13 new comprehensive Bats tests (867 total repository Bats tests passing).
  Evaluated blind cross-family by Codex (`gpt-6.1-terra`) on Orca run `run_7d824f09e44d` with Verdict: PASS (Round: 2).

- **Prior action (2026-10-31) — M6 slice 1 (`loom-doctor-foundation`) Landed:**
  Landed read-only foundation diagnostics helper `plugins/loom/bin/loom-doctor` and top-level CLI `plugins/loom/bin/loom`.
  Implements read-only diagnostics across host and OS (macOS/Linux), required tools (Bash >= 3.2, Git >= 2.34, jq >= 1.6),
  effective Git author identity (`git var GIT_AUTHOR_IDENT`), repository root discovery and `.docs` layout, init mode
  detection (Greenfield, Initialized, Unaligned-bare, Unaligned-migrate), coordination state and lock freshness, and
  protocol assets. Exposed through human-readable CLI summary and `--json` machine-readable output format. Updated allowlists
  across 9 repository locations. Added 39 comprehensive Bats tests (833 total repository Bats tests passing). Evaluated
  blind cross-family by Codex (`gpt-6.1-terra`) on Orca run `run_6d33d4fca5d6` with Verdict: PASS (Round: 0). M6 is now in progress.

- **Prior action (2026-10-31) — M5 slice 3 (`evaluation-output-recorder`) Landed (Milestone M5 Complete):**
  Landed ADR 0022 / spec 03 / spec 04 / spec 05 evaluation output recorder `plugins/loom/bin/loom-eval-workspace record`.
  Separates analysis from repository mutation by recording schema-valid verdicts from the sanitized workspace into the
  repository's `.docs/evaluations/` directory, updating the target artifact's lifecycle status (`Approved`, `Accepted`,
  `Ready to Publish`, `In Progress`, `Draft`), validating evidence integrity against the workspace manifest and gate rerun
  record, binding repository eligibility to Loom immutable root commit ancestry (`523cc013`) and canonical ADR 0023 blob
  (`ae4bdb4a`), and settling bootstrap retirement. Added JSON Schema `loom-evaluation-output-v1.schema.json` and 40 new
  comprehensive Bats tests (792 total repository Bats tests passing). Evaluated blind cross-family by Codex (`gpt-6.1-terra`)
  on Orca run `run_2e75df916e11` with Verdict: PASS (Round: 3). Milestone M5 is now fully landed.

- **Prior action (2026-10-31) — M5 slice 2 (`evaluation-gate-runner`) Landed:**
  Landed ADR 0022 / spec 04 / spec 05 evaluation gate runner `plugins/loom/bin/loom-eval-workspace gate-rerun`.
  Provides bounded, deterministic gate reruns in an isolated execution copy (`0700` scratch workspace), environment
  scrubbing, timeout enforcement, process group termination on signals, pre/post attempt immutable run and checkout
  verification, failure detection for input tampering, no-checkout and bare-repository support, and comprehensive evidence
  emission adhering to `loom-eval-workspace-rerun-evidence-v1.schema.json`. 17 new comprehensive Bats tests (752 total
  repository Bats tests passing). Evaluated blind cross-family by Codex (`gpt-6.1-terra`) on Orca run `run_80b776529117`
  with Verdict: PASS (Round: 1).

- **Prior action (2026-10-31) — M5 slice 1 (`sanitized-evaluation-workspace`) Landed:**
  Landed ADR 0022 sanitized evaluation workspace exporter helper `plugins/loom/bin/loom-eval-workspace`
  with four subcommands (`prepare`, `verify`, `status`, `clean`), JSON Schema
  `loom-eval-workspace-manifest-v1.schema.json`, and Ajv Draft 2020-12 schema validation with `ajv-formats`.
  Enforces immutable, object-derived `.git`-free exports for cold-agent evaluations, exact Git object and tree bindings,
  strict SHA256 integrity verification, fail-closed permission checks (0700 private directory modes), capture freshness
  verification, and exclusion of living status and evaluation records. Gate runner split out into follow-on `evaluation-gate-runner`
  slice. 32 new comprehensive Bats tests (735 total repository Bats tests passing). Evaluated blind cross-family by
  Codex (`gpt-6.1-terra`) on Orca run `run_782d51a778d0` with Verdict: PASS (Round: 2).

- **Prior action (2026-10-31) — M4 slice 4 (`local-review-orchestration`) Landed (Milestone M4 Complete):**
  Landed ADR 0021 / ADR 0022 Loom-owned local review orchestration workflow across `plugins/loom/skills/loom-run/SKILL.md`,
  `plugins/loom/skills/loom-playbook/references/orchestration.md`, `plugins/loom/skills/loom-playbook/references/review-findings.md`,
  `plugins/loom/skills/loom-playbook/references/code-eval-rubric.md`, and `plugins/loom/skills/loom-playbook/SKILL.md`.
  Replaced legacy external slash commands (`/code-review`, `/security-review`) with `loom-review` (`prepare`, launch 3 required
  finders with manifest-pinned prompts, `validate`, `assemble --out`, `clean`). Eliminated all operational dependencies on
  GitHub, PR numbers, `origin/HEAD`, remote branch state, and external slash command plugins. Enforced whole-run invalidation
  and preserved explicit `skipped: docs-only` skip for pure documentation diffs. 702 total repository Bats tests passing.
  Evaluated blind cross-family by Codex (`gpt-6.1-terra`) on Orca run `run_735a9227ba0e` with Verdict: PASS (Round: 0).
  Milestone M4 is now fully landed.

- **Prior action (2026-10-30) — M4 slice 3 (`local-review-agents`) Landed:**
  Landed ADR 0021 versioned immutable Loom-owned finder prompts under `plugins/loom/finders/`
  (`review-correctness-v1.md`, `review-tests-v1.md`, `review-security-v1.md`) with explicit
  boundary enforcement (procedural boundaries, read-only inputs/source, assigned single output
  result file, untrusted code handling, advisory findings, evaluator-only verdict). Updated
  `plugins/loom/bin/loom-review` with script-relative physical root asset lookup, pinned prompt hash
  defaulting and strict override validation (rejecting unknown finders/versions, empty values,
  duplicates, and hash mismatches with exit 2), and `claude:sonnet` default profile. Added repository
  packaging validation in `scripts/validate-repository.mjs` and expanded `plugins/loom/bin/loom-review.bats`
  to 57 Bats tests including controlled per-finder defect fixtures with verified location and concrete
  evidence (702 total repository Bats tests passing). Evaluated blind cross-family by Codex
  (`gpt-6.1-terra`) on Orca run `run_735a9227ba0e` with Verdict: PASS (Round: 0).

- **Prior action (2026-10-30) — M4 slice 2 (`local-review-helper`) Landed:**
  Landed ADR 0021 local review helper `plugins/loom/bin/loom-review` with five subcommands
  (`prepare`, `validate`, `assemble`, `status`, `clean`), exact git commit object and tree
  binding, object-derived `.git`-free source snapshot, diff hash calculation, fail-closed
  validation against corrupt/missing objects and malformed/truncated results, deterministic
  identity-neutral findings assembly (`*-review-findings.md`), derived lifecycle status
  transitions, and safe run cleanup. Added JSON Schemas `loom-local-review-manifest-v1.schema.json`
  and `loom-local-review-findings-v1.schema.json`, registered `loom-review` across all helper
  allowlists, and added 48 comprehensive Bats tests (691 total repository Bats tests passing).
  Evaluated blind cross-family by Codex (`gpt-6.1-terra`) on Orca run `run_735a9227ba0e` with
  Verdict: PASS (Round: 1).

- **Prior action (2026-10-30) — M3 slice 1 (`identity-guard-contract`) Landed (Milestone M3 Complete):**
  Landed recognized identity-mutation guard and post-command verification: `plugins/loom/hooks/git-identity-guard.sh`
  scans command text without stripping quoted segments, blocking `git config` identity writes across all scopes
  (`--local`, `--global`, `--system`, `--file`), bare and quoted `--author` overrides, `-c` user/author/committer overrides,
  and `GIT_AUTHOR_*`/`GIT_COMMITTER_*` assignments across wrappers (`sh -c`, `bash -c`, `env`) while preserving safe bare reads.
  Landed portable post-command verifier `plugins/loom/bin/loom-verify-identity <baseline-sha|unborn>` (exits 0 valid/no-op, 1
  usage/config/corrupt history error, 2 identity violation with remediation on stderr), registered across all allowlists
  (`loom-resolve-helper`, Claude & Codex installed roots, fixtures, schema `$defs.allowedHelpers.const`, and validator).
  Wired baseline capture and verification into `plugins/loom/roles/developer.md`, `plugins/loom/skills/loom-developer/SKILL.md`,
  and `plugins/loom/skills/loom-playbook/references/commit-convention.md`. 641 total repository Bats tests passing. Evaluated
  blind cross-family by Codex (`gpt-6.1-terra`) on Orca run `run_735a9227ba0e` with Verdict: PASS (Round: 2). Milestone M3
  is now fully landed.

- **Prior action (2026-10-30) — M2 slice 2 (`coordination-state-separation`) Landed:**
  Landed ADR 0020 coordination state separation: removed tracked-main mutation
  from claim/work-start paths in playbook, candidate-time deterministic living
  document finalization (`loom-land --finalize`), untracked candidate manifest in
  session dir, unlocked build and gate execution with short publish lock, and
  distinguished positive rejection recovery (exit 3 with attempt reset) from
  containment recovery (exit 0) and uncertain push (exit 10). Bats suite expanded
  to 51 tests (597 repository Bats tests passing). Evaluated blind cross-family
  by Codex (`gpt-6.1-terra`) on Orca run `run_735a9227ba0e` with Verdict: PASS (Round: 1).

- **Prior action (2026-10-30) — M2 slice 1 (`remote-first-integration-candidate`) Landed:**
  Landed ADR 0020 remote publication landing authority helper (`plugins/loom/bin/loom-land`)
  and Bats suite (`plugins/loom/bin/loom-land.bats`, 37 tests). Enforces candidate
  preparation against the configured remote target ref, atomic verification against
  the exact push destination (`remote.<name>.pushurl` / `url`), full receipt binding
  checks against `loom-receipt/v1`, `publishAttempt` preservation across push attempts,
  uncontained uncertain push fail-closed exit 10 (`stopping for owner action`), and
  separate-clone multi-publisher contention recovery with rebuilt candidates and claim
  preservation (583 repository Bats tests passing). Evaluated blind cross-family by
  Codex (`gpt-6.1-terra`) on Orca run `run_735a9227ba0e` with Verdict: PASS (Round: 2).

- **Prior action (2026-10-30) — `role-governance-guard` Landed:**
  Landed mechanical pre-tool role governance hook (`role-governance-guard.sh`),
  second-hook registration in `hooks.json` under `PreToolUse` for `Bash`,
  `LOOM_ROLE` export across Codex, Antigravity (`loom-role-launch-v1` schema
  `environment.LOOM_ROLE`), and orchestrator sessions (`loom-run`), evaluator
  git-mutation block, and orchestrator test-suite execution block with
  `LOOM_ALLOW_ORCHESTRATOR_GATE=1` exception (545 Bats tests passing).
  Evaluated blind cross-family by Codex (`gpt-6.1-terra`) on Orca run
  `run_735a9227ba0e` with Verdict: PASS (Round: 2).

- **Prior action (2026-10-30) — `model-matrix-and-dynamic-discovery` Landed:**
  Landed compatibility matrix `v0.3.0.json`, updated launch schemas for `gpt-6*`
  and Antigravity variants, implemented 4-tier model resolution precedence
  (CLI > repo > ambient > matrix fallback), 24h atomic `agy models` discovery
  caching, and fail-closed `--model`/`--effort` validation (527 Bats tests passing).
  Evaluated blind by Codex (`gpt-6.1-terra`) on Orca run `run_735a9227ba0e` with
  Verdict: PASS (Round: 1).

- **Prior action (2026-10-30) — M3 slice 2 (`precompact-per-session`) Landed:**
  Landed per-session PreCompact write-ahead backstop under
  `<git-common-dir>/loom/precompact/<session-id>/{marker,log}` with coordinated
  session checkpoint integration (`loom-coord checkpoint-write`), atomic marker
  writes, control-char-stripped log capping, and cross-session compaction isolation
  (45/45 Bats tests, 508 total repo Bats tests passing). Evaluated blind by Codex
  (`gpt-6.1-terra`) on Orca run `run_735a9227ba0e` with Verdict: PASS (Round: 0).

- **Prior action (2026-10-30) — Remediation Workstreams 1–3 (`docs-and-agent-tuning`,
  `coord-and-hook-hardening`, and lean `dogfood-301-stabilize` fix):**
  1. **Spec/Doc Governance, Agent Tuning & Anti-Wheel-Spinning Guards:** Tuned all
     five `plugins/loom/roles/*.md`, evaluation rubrics/templates, `CLAUDE.md`,
     `gates/shell.md`, `loom-develop/SKILL.md`, `loom-eval-code/SKILL.md`,
     `loom-run/SKILL.md`, and `orchestration.md` with Round 0 `Must Fix` freeze,
     Round >= 1 non-expansion locks, 2-consecutive-FAIL goalpost-shift early
     escalation, and fast targeted inner-loop test discipline (`bats --filter`,
     `TMPDIR=/private/tmp`, `LOOM_BATS_JOBS=4`). Compacted `handoff.md` and
     `progress.md` into `.docs/status/archive/` and reconciled
     `.docs/slice-plans/README.md`.
  2. **`loom-coord` Hardening, Hook Unification & Gate Speedup:** Landed physical
     symlink containment (`_with_session_dir`), centralized lock ownership
     (`lock_acquire`, `lock_verify_self`, `lock_heartbeat`, `lock_release_if_self`),
     and fail-closed null-SHA CAS schema initialization (`_check_or_set_schema`) in
     `plugins/loom/bin/loom-coord` (94/94 Bats tests); unified
     `_loom_hook_select_client` in
     `plugins/loom/hooks/precompact-write-ahead-backstop.sh` (32/32 Bats tests); and
     added optional `LOOM_BATS_JOBS` parallel execution to `scripts/run-bats-under`.
  3. **Lean `dogfood-301-stabilize` Fix:** Added `_wait_for_release_or_writer_death`
     and final release reread to `_reconcile_gate` in
     `scripts/macos-dual-client-dogfood` plus `mutate_direct` and the opt-in two-file
     stub barrier in `scripts/tests/macos-dual-client-dogfood.bats`, eliminating the
     test-301 flake while keeping the dogfood suite at 41 fast tests (464 total
     repository Bats tests).
- **Prior action — remediation-3 `playbook-conformance` (first exercise of ADR
  0026's broadened `docs-governance/v1` class).** Two things landed: (1) **ADR
  0026 carried to `main` at `Status: Accepted`** — broadens `docs-governance/v1`
  to admit the **prose body** of `plugins/loom/**/*.md` (skills/roles/agents/
  commands/references), with behavior-bearing YAML frontmatter categorically
  out of class (§3 carve-out); the two pre-placed cold plan-eval + owner-acceptance
  records and the ADR/evaluations indices were landed alongside it. (2) The
  audit's three **Theme-B playbook/prose drifts** were corrected across an
  exhaustive whole-tree census (mechanical `rg` sweep, every hit triaged
  FIX/LEAVE, zero un-triaged): (a) **lifecycle** — a code-eval PASS advances a
  slice to `Ready to Publish`, not `Landed` (`Landed` is later/stronger: a
  verified remote result + publication receipt) — fixed in
  `loom-eval-code/SKILL.md`, `code-evaluator.md`, `loom-run/SKILL.md`,
  `status-machine.md` (adds `Ready to Publish`/`Accepted`/`Living` tokens),
  `developer.md`, `commit-convention.md`, and `loom-playbook/SKILL.md`'s
  lifecycle table; (b) **evaluator self-commit** — the evaluator never mutates
  the checkout; it produces its verdict to confined scratch and returns, and the
  recorder/root installs the verdict, transitions status, and commits — fixed
  in `code-evaluator.md`, `plan-evaluator.md`, `loom-eval-code/SKILL.md`,
  `loom-eval-plan/SKILL.md`, `loom-run/SKILL.md`, and `orchestration.md`'s core
  commit doctrine; (c) **local-`main` is not the landing authority** (ADR 0020
  §1) — corrected the false authoritative-local-`main` framing in
  `parallelism.md` and `orchestration.md` while preserving the read-under-the-lock
  coordination mechanic (ADR 0014/0015/0016) and the working-base use of local
  `main`. Pure prose-body edits; zero frontmatter lines touched (verified by
  diff); `scripts/check` green. Slice-plan archived to
  `.docs/slice-plans/archive/playbook-conformance.md`.
- **Last action — M1 slice 1 `coord-identifier-boundaries` SETTLED (ADR-0023
  receipt; result main 00582aa).** Centralized identifier validation landed in
  `plugins/loom/bin/loom-coord`: a two-grammar split — strict `_valid_identifier`
  (session ids, decoded-blob sids, PIDs: no `/`, no `..`, no whitespace/control
  bytes) and narrow `_valid_slice_name` (held-claims line format only, preserving
  the tested `:`/`..` freeform-slice-name capability); decoded-blob sids validated
  before path use in `cmd_cleanup`/`cmd_reclaim`; `_remove_session_dir` replaces
  `rm -rf` of computed session dirs with known-file deletion + `rmdir` quarantine;
  `cmd_cleanup`'s `T3` sweep case flips to quarantine on a malformed decoded sid
  (plan-authorized). 18 new `NEG-ID` negatives (64 pre-existing unchanged + `T3`
  flip + 18 new = 82/82); `LOOM_DIFF_BASE=HEAD scripts/check` green, 452/452 Bats.
  Plan-eval FAILed round 0 (slice-name grammar over-restriction breaking two
  existing tests `SC1`/`V5b`) → revised to the two-grammar split → Approved.
  Bootstrap review — three cold auxiliary workers (correctness/tests/security),
  loom-repository-bootstrap/v1 degraded, not loom-local-review/v1 (ADR 0023 §3) —
  clean at 4 MINOR (T1-T3 secondary-call-site test-coverage gaps — `cmd_session_bootstrap`/
  `cmd_session_end` quarantine-skip path, `cleanup --session` negative,
  `cmd_release_claim`/`cmd_reclaim` bad-slice-name negative — plus T4 a NEG-ID
  count doc miscount in the plan's Implementation Record, 17 vs actual 18); no
  BLOCKER/MAJOR. Code-eval PASS round 0; `Status: Landed/Archived — settled on
  remote main at 00582aa (ADR-0023 publication receipt)`. The four MINORs are an
  optional future pass, not a blocking follow-up. Slice-plan archived to
  `.docs/slice-plans/archive/coord-identifier-boundaries.md`.
  **Also landed on `main` during this slice (separate commit, not part of the
  slice diff):** `0ae81c1` — a Linux CI portability fix for `dir_mtime_epoch`'s
  GNU-vs-BSD `stat -f` divergence (T1 from the earlier multi-session-lock-helper
  thread, see `handoff.md`); hosted CI is green on both lanes.
- **Next action:** after remediation-3 `playbook-conformance` lands (above), two
  tracked **code-bearing follow-ups**: (1) **test-301 flake stabilization** (the
  `scripts/check` bats flake unrelated to md edits), (2) the **trivial
  reconciliation `slice-plans/README` Active-region residual** (the
  `docs-governance-reconciliation` entry still shown under `## Active plans`
  pointing to `archive/`); **then** plan the M1 slice 2 `coord-lock-ownership`
  slice (per `.docs/repository-improvement-plan.md` § "M1 — Fix coordinator
  safety").
- **Last action (owner decisions, 2026-07-24 — governance deferred-decisions
  resolved).** Two owner decisions were recorded and the governance slice's two
  deferred owner questions are now settled:
  1. **SCHEDULE `client-floor-adapter-smoke` (do not retire).** ADR 0023 §1 already
     authorizes it as `ci-baseline`'s required M0 follow-up (and §7 grants it
     bootstrap `remote-direct` landing); it remains in the transition
     `allowed_slices`. Scheduling it restores the plan text to match existing
     authority, so **no new ADR is needed** — in contrast to the rejected retirement
     the governance draft attempted, which would have required an accepted ADR. The
     improvement plan now carries a restored `### Slice: client-floor-adapter-smoke`
     entry under M0 (the remaining M0 follow-up, scheduled after governance, runnable
     before or alongside M1) stating what it owes beyond the dogfood evidence: a
     **real authenticated Codex cold role launch** (the leg the D0 dogfood run could
     not prove — its isolated `CODEX_HOME` was credential-less by design) plus the
     §7 cross-client floor checks, with an **open owner-input precondition on the
     Codex credential strategy** for isolated homes (short-lived injected credential
     vs. read-only sandboxed real `CODEX_HOME`; owner picks at plan time).
  2. **`loom/bootstrap-authority-b28a747` remote branch DELETED** after the
     zero-reference scan (see M0 errata → Branch/PR hygiene).
  The governance slice's second deferred item — the ADR 0023 §7 single-session
  publication precondition / M2 duplication — is **not** part of these decisions and
  remains deferred to M2 planning, as the governance plan noted.
  (Superseded — next action above: M1 slice 1 is now complete; proceed to slice 2
  `coord-lock-ownership`.)
- **Phase:** **Private Apple-silicon dual-client dogfood checkpoint reached.**
  `macos-dual-client-dogfood` is settled (ADR-0023 publication receipt; result
  `2a4700d`, `verified_target_ref refs/heads/main`). No further slice work is queued.
- **Last action:** **`macos-dual-client-dogfood` slice settled**
  (code-eval resolving PASS round 0, head `a000cef`; ADR-0023 publication receipt,
  result `2a4700d`, `verified_target_ref refs/heads/main`). Full loop: plan Approved round
  0 → five implementation/live-run developer passes (Steps 2-10) → orchestrator-run
  bootstrap review — three cold auxiliary workers (correctness/tests/security),
  loom-repository-bootstrap/v1 degraded, not loom-local-review/v1 (ADR 0023 §3) —
  FAILed round 0 on the
  fail-closed dogfood harness's untested injection-recovery branches and quarantine
  cleanup hardening → developer fix (6 new load-bearing Bats injection cases proven
  by break/observe-red/restore-green, plus C1 containment + S1 `runId`-charset
  hardening) → resolving code-eval PASS round 0 (`LOOM_DIFF_BASE=HEAD scripts/check`
  exit 0, 434/434 Bats). Delivered: shared `loom-*` Agent Skill workflow bodies +
  canonical `roles/*.md` contracts with thin Claude/Codex adapters; `loom-resolve-
  helper` (installed-root helper resolution for both clients); one shared
  `hooks.json` with policy/wire split at the executable boundary (12-case
  hook-wire-v1 product, 2 clients × 2 events × 3 outcomes; 48 fixture files at
  4/case); `loom-launch-role` (sole,
  compatibility-matrix-driven client role launcher); and a fail-closed macOS dogfood
  harness (hash-chained supervisor/worker journal; prepare/exercise/uninstall/clean;
  resume/quarantine/cleanup reconciliation). **Live evidence** (five real-run
  attempts against Claude 2.1.218 and Codex 0.144.6, isolated homes) fixed five real
  product bugs found only at real scale and completed the full native
  marketplace-add/install/reinstall/uninstall/marketplace-remove lifecycle for both
  clients, plus a successful Claude cold role launch. The Codex cold role-launch leg
  hit a live `401 Unauthorized` from the isolated, credential-less `CODEX_HOME` by
  design (never seeded from the owner's real credentials) — recorded honestly as
  `infrastructure-blocked`, not a product defect, in
  `.docs/evaluations/macos-dual-client-dogfood-evidence.json`. This slice makes loom
  **privately Apple-silicon dual-client dogfood-ready**; it is **not** a public
  release, does **not** claim public Codex support, and does **not** reduce the
  mandatory Linux/macOS-Intel v0.2 release obligations. Per ADR 0023 §4 the slice is
  settled (ADR-0023 publication receipt; result `2a4700d`, `verified_target_ref
  refs/heads/main`).
- **Last action:** accepted ADR 0024 was integrated without rewriting; the improvement
  plan, spec index and eight frozen specs, canonical project instructions, CLAUDE/AGENTS
  adapters, README, and indexes were synchronized. The exact `ee37a20` review candidate
  passed 257/257 under Bash 3.2 and 5.3. Cold reevaluation resolved all six round-0
  findings with no current finding; raw verdict SHA-256 is
  `a723530e2a1ebbb7e7f7fee5366ab5df74d549f9cd57c8a30dd9caa0ed75f79c`.
- **Earlier M1–M4 and post-M4 slice history:** archived in
  [`archive/progress-history.md`](archive/progress-history.md).

## M0 errata

Record-keeping only (`governance-baseline-reconciliation` slice, 2026-07-24); no history
is rewritten and no commit is re-authored. See also the pointer line in
[`../evaluations/README.md`](../evaluations/README.md).

**M0 Landed — precise scope.** M0 covers a static reproducible local-gate baseline plus a
macOS-arm64 (Apple silicon) behavioral dogfood pass (`macos-dual-client-dogfood`); the
Codex cold-launch role-invocation leg is `infrastructure-blocked` (a live 401 from an
isolated, credential-less `CODEX_HOME` by design), not a product defect. Ubuntu/Intel
release obligations and public Codex support are **not** covered by M0 — they remain owed
by ADR 0019 at release.

**Early-stretch process deviations (2026-07-24 reviews).** Two independent post-M0
reviews (program-design review and implementation audit) found the dogfood slice's
record clean but the earlier ci-baseline/amendment stretch carries four unrecorded
deviations from the intended process. History is immutable; nothing below is rewritten
or re-authored — this is a factual record of what happened:

(a) **Non-uniform commit identity (ADR 0003 violation).** 13 commits in the
`c7bd84d..a3cb007` range (69 commits total) carry non-uniform author/committer
identities — `loom@localhost`, `loom-recorder@invalid`, and `loom@local` — instead of
the single configured owner identity ADR 0003 requires. Verified: `git log
--format='%ae' c7bd84d..a3cb007 | grep -Ec 'loom@localhost|loom-recorder@invalid|
loom@local'` → `13`.

(b) **Merge commit breaks the linear direct-push model.** `44f16a4` ("Integrate accepted
ADR 0024 authority") is a two-parent merge commit, not a direct linear commit,
departing from loom's normal fast-forward/direct-push discipline.

(c) **ci-baseline publication-mode mismatch.** ci-baseline landed via GitHub **PR #3**
(rebase-merge), while its own settlement record states `publication_mode: remote-direct`
— the recorded mode and the actual landing mechanism disagree.

(d) **ci-baseline evidence set incomplete.** ci-baseline's in-tree evidence set is
missing a plan-eval record and an evidence JSON, an incomplete instance of the evidence
package the program otherwise expects.

**Branch/PR hygiene (performed 2026-07-24).** PR #1 and PR #2 were closed and four
redundant remote branches were deleted on 2026-07-24. A fifth candidate,
`loom/bootstrap-authority-b28a747`, was scanned rather than deleted at that time: it
still existed on the remote (`git ls-remote --heads origin
loom/bootstrap-authority-b28a747` → `b28a747…`), and a reference scan (`git grep -n
bootstrap-authority-b28a747` over `.docs/`, plus a full scan of the protected
transition `state.json` history at `origin/loom/bootstrap-transition` tip `32c5315`)
found **zero** anchoring references — no living-doc, evaluation, or transition-state
record depended on it. **Owner decision (2026-07-24): DELETE.** On the strength of
that zero-reference scan the owner directed deletion of
`loom/bootstrap-authority-b28a747`; the remote branch is deleted. This closes the
keep-vs-delete question the governance slice deferred to the owner.

**Remediation-1 audit errata (2026-07-24, record-keeping only).** A 2026-07-24
alignment audit surfaced four further integrity/process errata beyond the M0 set
above. History is immutable; nothing below is rewritten or re-authored — this is a
factual record of what happened. Two of these raise DECISIONS (not record-keeping)
deferred to a remediation-2 spec/ADR cycle + owner (see the deferred-decisions note
in `errata-and-settled-record.md`'s Notes):

(a) **ADR 0006 rewritten in place post-acceptance — integrity erratum.** Commit
`5e0b178` ("Build M1 scaffold …") modified the already-accepted
`.docs/ADR/0006-distribution-self-marketplace.md` (26 lines changed; message notes
"updated ADR 0006") without a superseding ADR. This violates ADR immutability
(supersede, never rewrite). The ADR is immutable; this is acknowledged, not
corrected — recording it does not re-open the ADR. Any correction is a new ADR cycle
(deferred). Proof: `git show --stat 5e0b178 | grep 0006`.

(b) **coord-identifier-boundaries published from a rebased, not rebuilt+re-reviewed,
head.** ADR 0023 §7 step 4 requires, on a moved target, discard-and-rebuild from the
new exact base then re-run §3/§4. The reviewed head was `82d689f` (base `c899673`);
the published head `00582aa` is that slice rebased onto `origin/main 0ae81c1` (Linux
CI fix). Instead of a rebuild + fresh review, a byte-identical-diff argument +
re-gate was substituted (loom-coord reviewed diff byte-identical pre/post rebase;
rebased head re-gated green 452/452). This is disclosed honestly in the transition
`state.json` `rebase_note` but was absent from `.docs/`; recorded here for the
durable record. Proof: `git merge-base --is-ancestor 0ae81c1 82d689f` → false;
`... 00582aa` → true; `rebase_note` in `state.json` at
`origin/loom/bootstrap-transition`.

(c) **Code-bearing Linux CI fix direct-pushed to `main` outside the
slice/review/settlement path.** `0ae81c1` ("Fix Linux CI: GNU stat -f …") is a code
change that landed directly on `main` (single-parent linear commit) with no slice
plan, no bootstrap review, and no publication settlement; per the audit, hosted
`main` stayed red ~6h and the macOS dogfood settlement `32c5315` was recorded while
hosted CI was failing. The CI-timing detail is an audit finding (not locally
reconstructable); the direct-push and single-parent shape are verifiable. Proof:
`git log -1 --format='%P' 0ae81c1` (one parent `c8996731`); `git merge-base
--is-ancestor 0ae81c1 origin/main` → true.

(d) **Four additional non-uniform-identity commits on the transition branch
itself.** Beyond the 13 counted in erratum (a) above of the `c7bd84d..a3cb007`
range, four commits on `origin/loom/bootstrap-transition` carry `Loom
<loom@localhost>` (ADR 0003 non-uniform identity), and each is outside that earlier
range: `367584c` ("Initialize protected Loom bootstrap transition state"),
`e2248d8` ("Authorize macOS dual-client dogfood slices"), `099c4f4` ("Prepare ci
baseline publication intent"), `4189c02` ("Settle ci baseline publication"). Proof:
for each SHA, `git log -1 --format='%ae'` → `loom@localhost`, and `git merge-base
--is-ancestor <sha> origin/loom/bootstrap-transition` → true while the SHA is not in
`git rev-list c7bd84d..a3cb007`.

**Remediation-2 reconciliation errata (2026-07-25, record-keeping only).** History is
immutable; nothing below is rewritten or re-authored — this is a factual record.

- **This reconciliation slice itself.** `docs-governance-reconciliation` is the first
  `docs-governance/v1` §7 slice landed under accepted ADR 0025. It carries ADR 0025's
  `Status: Accepted` disposition to `main` and implements the eight deferred
  reconciliation edits ADR 0025 Consequences named (accept ADR 0025 + index it;
  restore ADR 0006's pre-rewrite body + forward-pointer note; correct 0014-0017
  `Status: Approved` → `Accepted`; harmonize specs 03/04 `## Authority` and
  closed-list/landing prose; consolidate ADR path/cross-reference errata; fold the
  deferred §7/M2 items into the improvement plan; record this errata subsection;
  update `handoff.md`'s NEXT ACTION). Its §7 evidence is blind plan-eval + a distinct
  cold docs code-eval over the `base..head` diff + `scripts/check` green — no §3
  three-finder package, per ADR 0025 §B.2 (docs-governance class, no
  product/executable/test change).
- **The CI-window deviation.** Commits `87b72c9` and `9aa60e8` (the errata-slice
  finalize's archive + plan-approval record) left `main` red on hosted CI for
  approximately one cycle via a dangling-index-link regression introduced by that
  finalize. It was fixed at `fe9aca2` ("Fix dangling errata index link + stale
  status (regression from 87b72c9 finalize)"). Recorded as a factual deviation;
  nothing is rewritten.
- **Two additional pre-rule direct pushes now closed by ADR 0025.** `b1ba112`
  ("Author ADR 0025 reconciliation-authority-plugin-root-no-bypass-landing (Plan
  Review)") and `fe9aca2` (the dangling-link hotfix above) are both docs-only direct
  pushes to `main` that predate ADR 0025 Decision B (the no-direct-push-bypass rule).
  Both are B.3-class recorded pre-rule deviations — historical facts, not violations
  of a rule not yet in force — and are closed going forward by ADR 0025's no-bypass
  rule: every later commit advancing `origin/main` lands through ADR 0023 §7 (or its
  M2 successor), with no direct-push bypass class remaining.

## Accepted decisions (ADRs)

0001 plugin/orchestrator · 0002 model tiers · 0003 commit-per-handoff · 0004 blind
eval + role separation · 0005 frozen specs · 0006 self-marketplace (subdir layout) ·
0007 namespaced command surface (supersedes bare `/loom` in 0001) ·
0008 parallel `.docs/` coordination (worktree-per-slice; resolves OQ-A) ·
0009 Unaligned-migrate sub-mode · 0010 automated review in code-review phase ·
0011 `/code-review` command correction · 0012 thin orchestrator · 0013 write-ahead backstop ·
0014 multi-session worktree coordination · 0015 lease-renewal heartbeat liveness ·
0016 git-native `update-ref` CAS lock mechanism ·
0017 infrastructure-blocked escalation (third escalation type; detect-on-failure; not round-counted;
degraded-review honesty; developer incremental-commit discipline).

## Resolved build-time questions (M1)

- OQ-D — command surface is split into namespaced `/loom:<name>` commands
  (`/loom:run` + one-off role commands); roles are `agents/` (`loom:<role>`).
- OQ-E — plugin under `plugins/loom/`, `source: "./plugins/loom"` (root undocumented).
- OQ-F — no compiled helpers; agents do detection/parsing with their own tools.

## Resolved build-time questions (M2)

- Spec 06 §1 "empty" vs scaffold-metadata (was a code-eval MINOR on
  greenfield-init-behavior): spec `06 §1` was amended and re-approved (commit
  86fa7d1, eval `spec-06-status-seed-clarification-eval.md`) to define "empty" as
  no design content, authorizing the scaffold/phase metadata `greenfield.md` seeds.
- Commit-identity guard gap (`--author=` / `GIT_AUTHOR_*` env vars not blocked):
  closed by `author-identity-enforcement-guard` slice (commit a47bf95). The
  PreToolUse hook + `commit-convention.md` hardening cover all override paths.
- **Eval-miss root cause (eyeballing invariants):** two prior spec-review rounds each
  missed a defect that a mechanical check would have caught (bare `/loom` at spec 10
  line 107; wrapped `Code\nReview` a line-based grep can't see). Root cause addressed
  by the `recommended-tooling-and-mechanical-checks` slice (commit db39d44): the
  "Invariants verified mechanically" rule in both eval rubrics now requires
  `rg -U`/`yq`/`ast-grep`/LSP for any invariant assertion; `tooling.md` documents
  the discipline and per-role guidance. The two motivating defects themselves remain
  as separate follow-up items (spec-10 line-107 bare-`/loom` fix; the
  wrapped-token was retired in commit a85885f).

## Open

~~**Infra-blocked escalation (follow-up, no ADR yet)**~~ **RESOLVED.** ADR 0017 Accepted;
spec 03 § "Infrastructure-blocked escalation" + spec 04 §§ "Human checkpoints" / "Automated
review before a slice lands" re-frozen; playbook wired via `infra-blocked-escalation-wiring`
slice (pure-docs, code-eval PASS). All four bodies updated: `orchestration.md` (new escalation
section + degraded-run/false-clean bullets), `developer.md` (incremental-commit SHOULD),
`review-findings.md` (degraded-run note + broadened gloss; four tokens preserved),
`commands/run.md` (driver-loop pointers). The deferred follow-up from the multi-session
coordination thread is now fully delivered.

~~OQ-A (parallel `.docs/` coordination)~~ **RESOLVED by ADR 0008** (hybrid model;
living docs + slice-plans index main-only/orchestrator-serialized, per-slice
plan/eval/code branch-local, serial merge+finalize). Still deferred: OQ-B
(research-review tier — owner leans haiku-sufficient, decide empirically), OQ-C
(finalize-pass owner — owner undecided, wants a compare-and-contrast of re-spawned
cold role vs. orchestrator-direct before choosing). Owner guidance is recorded
inline in [`../spec/09-open-questions.md`](../spec/09-open-questions.md).

Deferred follow-ups discovered while accepting ADR 0008:

- ~~**Fold ADR 0008 into the frozen spec 04 Parallelism section** (and spec 08
  playbook guidance).~~ **DONE (M4 dogfood run #1, commit c3cd354, approved).** The
  spec-revision planning cycle ran through loom's loop: spec 04's Parallelism section
  now carries ADR 0008's coordination model (the "`.docs/` coordination across
  branches" open question is resolved in-text) and spec 08 records the
  slice-plans-index ownership change (planner/developer no longer touch
  `slice-plans/README.md` once parallelism is on). Both specs re-Approved.

Deferred follow-ups discovered during the retroactive spec-approval pass (flagged
for a future slice / owner decision):

- **Bare `/loom` in ADR 0001 (and possibly the spec README history)** still appears.
  ADRs are immutable (ADR 0005 / 0004 discipline), so this needs a **superseding ADR
  or an erratum note, not a rewrite**. Owner decision.
- ~~**The "Code Review" phase-label string**~~ **Resolved (commit a85885f).** The
  `Code Review` status token has been retired repo-wide. All four lifecycle strings
  (`SKILL.md`, `status-machine.md`, `developer.md`, slice-plans `README.md`) now
  match spec 03: `… → Implemented → (code review) → Landed → Archived`. Only
  legitimate action-phrasing and historical eval/status records remain.
- ~~**Commit-identity guard gap.**~~ **Resolved (commit a47bf95).** The
  `author-identity-enforcement-guard` slice closed this: `commit-convention.md` now
  explicitly forbids `--author=`, `-c user.*`, and `GIT_AUTHOR_*`/`GIT_COMMITTER_*`
  env vars; the PreToolUse hook (`plugins/loom/hooks/git-identity-guard.sh`) enforces
  it as best-effort defense-in-depth (26-case matrix, jq-absent fallback verified).
- ~~**Guard `--author` pattern not scoped to commit-creating subcommands.**~~
  **Resolved by decision (commit d35b565).** Scoping was attempted
  (`scope-identity-guard-to-commit-subcommands`); the blind code-evaluator caught
  two false-negative classes (pre-`git` prefix fail-open; compound-command
  shadowing) — a real `--author=Evil` override reached exit 0 and was confirmed in
  the author field. Owner chose unconditional `--author` blocking (fail-closed).
  The read-filter false-positive (`git log --author=alice` blocked) is now an
  ACCEPTED, DOCUMENTED limitation in `commit-convention.md`. Dogfooding value
  confirmed: the blind evaluator caught a real security regression before it landed.

## Verified at first install (M1)

- Local marketplace add + `source: "./plugins/loom"` installs cleanly; `/plugin
  validate ./loom` passes.
- Plugin components are **namespaced** — no bare `/loom`. Command surface split into
  one file per command (`/loom:run` + one-off `/loom:<role>`); agents are
  `loom:<role>`. `${CLAUDE_PLUGIN_ROOT}` resolves correctly.
- **Rung 1 passed:** `/loom:run` (status) loads, reads `.docs/` + git, and reports.

## Verified at rung 2 (first agent spawn)

- `subagent_type: loom:researcher` resolves — the orchestrator spawns a namespaced
  plugin agent via the Task tool. The haiku researcher wrote a cited note
  (`Status: Research Review`, sources + citations) and committed author-neutral;
  the orchestrator verified it. The full spawn → work → commit → verify pipeline
  works for one role.
- Remaining for M1: rung 3 — first full slice (plan → eval → develop → eval → land)
  on a throwaway target.
