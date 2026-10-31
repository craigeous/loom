# Session Handoff

Status: Living

Restart instructions and compact current context. `progress.md` is the status
source of truth; `roadmap.md` is milestone order.

## Start here each session

1. Confirm repo:
   ```sh
   cd /Users/craig/git/loom
   git status --short
   ```
2. Read `.docs/spec/README.md`, then `.docs/status/progress.md` and this file.

## Where things stand

- **M3 slice 1 `identity-guard-contract` LANDED on `main` (2026-10-30) — Milestone M3 COMPLETE:**
  Recognized identity-mutation hook guard (`git-identity-guard.sh`) scanning raw text without stripping
  quotes, blocking git config writes and author overrides across wrappers (`sh -c`, `bash -c`, `env`),
  post-command verifier (`loom-verify-identity`), allowlist registration across root metadata, fixtures,
  and schema, and developer workflow wiring (641 Bats tests passing). Milestone M3 fully landed.
- **M2 slice 2 `coordination-state-separation` LANDED on `main` (2026-10-30):**
  ADR 0020 coordination state separation: removed tracked-main mutation from claim/work-start,
  candidate-time deterministic living doc finalization (`loom-land --finalize`), untracked
  session manifest, unlocked build/gate with short publish lock, and positive rejection
  recovery (51 Bats tests in suite, 597 total repository Bats tests passing).
- **M2 slice 1 `remote-first-integration-candidate` LANDED on `main` (2026-10-30):**
  ADR 0020 landing authority helper (`plugins/loom/bin/loom-land`) and Bats suite
  (`plugins/loom/bin/loom-land.bats`, 37 tests). Enforces candidate preparation against
  remote target refs, exact push-destination verification, full receipt bindings,
  fail-closed exit 10 on uncertain push, and competing separate-clone contention recovery (583 Bats tests).
- **`role-governance-guard` LANDED on `main` (2026-10-30):**
  Pre-tool role governance hook (`role-governance-guard.sh`), `hooks.json` PreToolUse
  registration, `LOOM_ROLE` export, evaluator git mutation guard, and orchestrator test
  runner block with `LOOM_ALLOW_ORCHESTRATOR_GATE=1` override (545 Bats tests passing).
- **`model-matrix-and-dynamic-discovery` LANDED on `main` (2026-10-30):**
  Compatibility matrix `v0.3.0.json`, launch schemas for `gpt-6*` and Antigravity, 4-tier
  precedence, 24h `agy models` cache, and `--model`/`--effort` validation (527 Bats tests).
- **M3 slice 2 `precompact-per-session` LANDED on `main` (2026-10-30):**
  Per-session write-ahead backstops, coordinated checkpoints, and atomic markers (45 Bats tests).
- **Remediation Workstreams 1–3 complete on `main` (2026-10-30):**
  1. **Spec/Doc Governance, Agent Tuning & Anti-Wheel-Spinning Guards:** Tuned all
     five `plugins/loom/roles/*.md`, evaluation rubrics/templates, `CLAUDE.md`,
     `gates/shell.md`, `loom-develop/SKILL.md`, `loom-eval-code/SKILL.md`,
     `loom-run/SKILL.md`, and `orchestration.md` with Round 0 `Must Fix` freeze,
     Round >= 1 non-expansion locks, 2-consecutive-FAIL goalpost-shift early
     escalation, and fast targeted inner-loop test discipline (`bats --filter`,
     `TMPDIR=/private/tmp`, `LOOM_BATS_JOBS=4`). Compacted `handoff.md` (`<= 120`
     lines) and `progress.md` (`<= 400` lines) into `.docs/status/archive/` and
     reconciled `.docs/slice-plans/README.md`.
  2. **`loom-coord` Hardening, Hook Unification & Gate Speedup:** Landed physical
     symlink containment (`_with_session_dir`), centralized lock ownership
     (`lock_acquire`, `lock_verify_self`, `lock_heartbeat`, `lock_release_if_self`),
     and fail-closed null-SHA CAS schema initialization (`_check_or_set_schema`) in
     `plugins/loom/bin/loom-coord` (94/94 Bats tests); unified
     `_loom_hook_select_client` in `plugins/loom/hooks/precompact-write-ahead-backstop.sh`
     (32/32 Bats tests); and added optional `LOOM_BATS_JOBS` parallel execution to
     `scripts/run-bats-under`.
  3. **Lean `dogfood-301-stabilize` Fix:** Added `_wait_for_release_or_writer_death`
     and final release reread to `_reconcile_gate` in `scripts/macos-dual-client-dogfood`
     plus `mutate_direct` and the opt-in two-file stub barrier in
     `scripts/tests/macos-dual-client-dogfood.bats`, eliminating the test-301 flake
     while keeping the suite at 41 fast tests.
- **Remediation-3 `playbook-conformance` LANDED (prior `origin/main` `bc801de`).**
  ADR 0026 carried to `main` at `Status: Accepted` alongside its plan-eval +
  owner-acceptance records; corrected the three Theme-B prose drifts (`Ready to Publish`
  vs `Landed`, evaluator scratch return vs recorder commit, and remote landing
  authority).
- **M1 slice 1 `coord-identifier-boundaries` SETTLED (`00582aa`)** and
  **`macos-dual-client-dogfood` SETTLED (`2a4700d`).**
- **Earlier M1–M4 and post-M4 session history:** archived in
  [`archive/handoff-history.md`](archive/handoff-history.md) so this handoff stays
  within the `<= 120`-line cold-start budget.

## Notes for the next agent

- Commits are **author-neutral** AND under a **single uniform git identity** —
  roles must not set/override `user.*` (commit-convention; learned from the M1
  first run, where an agent strayed to `loom@localhost`).
- Command surface is `/loom:run` + one-off `/loom:<role>`; agents spawn via Task
  `subagent_type: loom:<role>` (verified).
