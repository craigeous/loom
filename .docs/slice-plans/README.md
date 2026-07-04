# Slice Plans

Transient working memory: plans for **in-flight slices** before they land. Authored
by the **planner**, approved by the **plan evaluator** (or owner), implemented by
the **developer**, reviewed by the **code evaluator**.

A **slice** is a small, single-purpose, vertically-shippable unit of work. If a
plan grows multiple unrelated goals, split it.

Plans **propose**; specs **decide**. On any conflict, the spec in `../spec/` wins.
When a slice lands, its outcomes are folded into the durable specs and the plan is
`git mv`'d into [`archive/`](archive/) — **after** code-eval PASS, in the same
landing step.

Lifecycle: `Draft → Plan Review → Approved → In Progress → Implemented → (code review) → Landed → Archived` (see
[../spec/03-artifact-lifecycle.md](../spec/03-artifact-lifecycle.md)).

## Active plans

*(none)*

## Archived plans

- [archive/claude-md-slim-down-plan.md](archive/claude-md-slim-down-plan.md) — `Archived` —
  apply + enforce the Approved spec-08 § "Shape and Concision Discipline": rewrote loom's
  root `CLAUDE.md` 197 → 85 lines (collapsed 132-line Repo-layout to ~25-line one-clause
  pointer index; coverage preserved) and wired enforcement — a "CLAUDE.md shape" Hygiene
  bullet in `references/code-eval-rubric.md` (flags restatement / over-bound / lost coverage
  on finalize diffs) + a spec-08 Shape and Concision pointer in `agents/developer.md` finalize
  step 2. Pure-docs (review `skipped: docs-only`). Completes the CLAUDE.md-digest-discipline
  thread.

- [archive/infra-blocked-escalation-wiring-plan.md](archive/infra-blocked-escalation-wiring-plan.md) — `Archived` —
  ADR 0017 playbook wiring (pure-docs, no code). Wired the infrastructure-blocked escalation into
  the operational bodies: `references/orchestration.md` (new *Infrastructure-blocked escalation*
  section + degraded-run + false-clean-detection bullets in the automated-review step),
  `agents/developer.md` (incremental-commit discipline SHOULD), `references/review-findings.md`
  (degraded-run subsection + broadened `skipped: command-unavailable` gloss; still exactly four
  tokens), and `commands/run.md` (driver-loop pointers). Code-eval PASS; landed.

- [archive/multi-session-playbook-wiring-plan.md](archive/multi-session-playbook-wiring-plan.md) — `Archived` —
  slice W: wired the multi-session coordination model (ADR 0014/0015/0016) into the playbook
  operational bodies. Pure-docs: `references/parallelism.md` (multi-session layer — git-CAS
  lock/claim + renewer + local-`main` worktree base — layered on ADR 0008),
  `references/orchestration.md` (new *Multi-session coordination* driver-loop section +
  cold-restart `session-bootstrap` note), `commands/run.md` + `SKILL.md` (pointers). Carries
  the {orchestrator action → `loom-coord` subcommand + exit-code} mapping. Completes the
  multi-session coordination thread end-to-end.

- [archive/multi-session-lock-helper-plan.md](archive/multi-session-lock-helper-plan.md) — `Archived` —
  ADR 0014/0015/0016: loom's **first non-hook CLI helper** `plugins/loom/lib/loom-coord.sh`
  (+ `loom-coord.bats`) — git-`update-ref` CAS lock on `refs/loom/lock` + per-slice claim refs
  on `refs/loom/claims/<sha1>` (ABA-safe; ADR 0016) + lease-freshness liveness + `{pid,start-time}`
  background renewer (ADR 0015). Fails closed. Shell-gated. Gate green 64/64; code-eval PASS
  round 0 (owner-reset counter). Playbook wiring in slice W (pending).

- [archive/precompact-write-ahead-backstop-plan.md](archive/precompact-write-ahead-backstop-plan.md) — `Archived` —
  ADR 0013 §Decision 5: loom's 2nd executable hook (`plugins/loom/hooks/precompact-write-ahead-backstop.sh`
  + `hooks.json` PreCompact entry + bats suite) making the write-ahead invariant observable.
  `manual`+no-progress → block (exit 2); `auto`+no-progress → never-wedge (exit 0) + log;
  advanced/first-run/tooling-failure → fail-open. Shell-gated; code-eval PASS round 0; landed 347e0d3.

- [archive/adr-0011-playbook-conformance-plan.md](archive/adr-0011-playbook-conformance-plan.md) — `Archived` —
  Playbook conformance for ADR 0011 (`/review` → `/code-review`): swapped the PR-bound
  `/review` for the local-diff `/code-review` (left `/security-review`) across **four**
  files — `SKILL.md`, `references/orchestration.md`, `references/code-eval-rubric.md`,
  `references/review-findings.md` — and added the commit-range invocation detail to
  `orchestration.md` (target `git diff <base>...<slice-HEAD>`, not the empty working tree).
  Pure-markdown. **Plan-eval caught a real scope miss** (a 4th `/review` in `SKILL.md` the
  plan first excluded) — FAIL round 1 → fixed → PASS; code-eval PASS round 1. Landed 63e6d01.

- [archive/code-eval-adjudication-plan.md](archive/code-eval-adjudication-plan.md) — `Archived` —
  Slice C of 3 (ADR 0010 follow-on): amended `references/code-eval-rubric.md` with a
  "Review-findings adjudication" section (advisory not auto-FAIL; confirm/reject each
  finding; map confirmed to `severity.md`; discard false positives with a reason;
  evaluator owns the verdict) + `agents/code-evaluator.md` (review-findings artifact in
  its inputs + pointer to the rubric procedure). Built in parallel worktree
  `slice/code-eval-adjudication`; **code-eval caught a real broken-link MAJOR (round 1),
  fixed → PASS**. Landed 5941bea (merged --no-ff). Completes the ADR 0010 playbook thread.

- [archive/orchestration-review-step-plan.md](archive/orchestration-review-step-plan.md) — `Archived` —
  Slice B of 3 (ADR 0010 follow-on): amended `references/orchestration.md` with a new
  "Automated review before a slice lands" section — orchestrator runs `/review` +
  `/security-review` on the `Implemented` diff (local mode, before land, because only it
  spawns), writes the findings artifact per `review-findings.md`, code-diff-only with
  `skipped: docs-only` / `skipped: command-unavailable`, not the `format → lint → test`
  gate. Built in parallel worktree `slice/orchestration-review-step`; code-eval PASS round 0.
  Landed beaa531 (merged --no-ff).

- [archive/review-findings-format-plan.md](archive/review-findings-format-plan.md) — `Archived` —
  Slice A of 3 (ADR 0010 follow-on): new `references/review-findings.md` — the single-source
  playbook definition of the review-findings artifact (decided path
  `.docs/evaluations/<slice>-review-findings.md`; identity-neutral invariant; the four
  distinguishable per-command status tokens `ran-with-findings` / `ran-clean` /
  `skipped: docs-only` / `skipped: command-unavailable`; finding-entry fields; adjudication
  pointer to `severity.md` + `code-eval-rubric.md`, format-vs-procedure single-source
  boundary) + a `SKILL.md` References entry. Pure-markdown (no gate); code-eval PASS round 0.
  Landed 13d62c2. Slices B (`orchestration.md`) + C (`code-evaluator.md` + `code-eval-rubric.md`)
  reference it.

- [archive/unaligned-bare-migrate-split-plan.md](archive/unaligned-bare-migrate-split-plan.md) — `Archived` —
  slice 3 of 3 (final) of the ADR-0009 Unaligned bare/migrate split: restructured
  `references/unaligned.md` into Unaligned-bare (existing Steps 1–5; bare-only
  Draft→review rule scoped explicitly) + Unaligned-migrate (owner gate
  migrate/thin-pointer/abort; inline `migration-recipe.md` recipe; status
  preservation; no role-spawn); `SKILL.md` References entry updated; CLAUDE.md
  curated-digest bullet updated in finalize. Completes the ADR-0009 thread.
  Landed 61bc6e9.

- [archive/migration-recipe-reference-plan.md](archive/migration-recipe-reference-plan.md) — `Archived` —
  slice 2 of 3 of the ADR-0009 Unaligned bare/migrate split: new playbook reference
  `references/migration-recipe.md` — the reusable, ordered, idempotent Unaligned-migrate
  recipe (ADR 0009 §5/§7): preconditions (dirty-tree check, untracked-file handling,
  NUL-delimited lists), the numbered-spine → `spec/` + `status/` split with
  two-directional link rewrite, specific-before-generic ordering, idempotency via
  negative lookbehind `(?<!\.)` against the `..docs/` self-match, the three reference
  forms handled separately, the living-rewritten vs archived-snapshot boundary,
  status-preservation pointer (spec 06 §2b / ADR 0009 §4), and final link validation;
  plus a `SKILL.md` References entry. Landed a34d726/da21d2c/fdbbb60.

- [archive/init-detection-spine-signal-plan.md](archive/init-detection-spine-signal-plan.md) — `Archived` —
  slice 1 of 3 of the ADR-0009 Unaligned bare/migrate split: added the
  existing-but-undotted **docs-spine detection signal** to `init-detection.md` —
  concrete "pre-existing docs spine" definition, Unaligned sub-classification
  (spine present → Unaligned-migrate, else Unaligned-bare), updated dispatch table
  (§2a/§2b), read-only invariant preserved. `init-detection.md` only; no spec/ADR/
  `unaligned.md`/recipe edits. Target spec 06-init-modes.md. Landed c96fd90.

- [archive/claude-md-autopropagation-conformance-plan.md](archive/claude-md-autopropagation-conformance-plan.md) — `Archived` —
  bring the playbook implementation into conformance with the Approved `CLAUDE.md`
  auto-propagation spec amendment (Cycle 2): developer finalize pass now maintains
  `CLAUDE.md` as a curated digest (spec 03 step 2; boundary in spec 08); five playbook
  files updated to point to spec 08; single-sourced boundary. Completes the CLAUDE.md
  auto-propagation thread (Cycle 1: spec; Cycle 2: playbook). Landed b661f7a.

- [archive/identity-verification-hardening-plan.md](archive/identity-verification-hardening-plan.md) — `Archived` —
  close two structural gaps that let agents commit under a forged/fallback identity: Fix A —
  Greenfield "Ensure a git identity is configured" step (establish-or-stop; Unaligned/Initialized
  reference it verify-only) makes commit-convention's "init ensures an identity" claim true;
  Fix B — single-sourced "Verify after committing" sub-point in `commit-convention.md`
  (`git show -s --format='%an <%ae>'` + conditional `--amend --reset-author`) pointed at by
  all five agent prompts. No spec/ADR/hook edits; no hardcoded identity. Addresses the
  recurring `loom@localhost` M4 finding (code-eval PASS round 0; landed a816979).

- [archive/round-limit-conformance-plan.md](archive/round-limit-conformance-plan.md) — `Archived` —
  bring the playbook's round-limit text + both evaluator prompts into conformance
  with the amended spec 03 `## Round limits` FAIL-only counting rule (FAIL
  increments / PASS-resolving-a-FAIL shares the number / first review is round 0 /
  one counter per artifact across both phases); point to spec 03 as the single
  source, no divergent restatement (M4 escalation thread, Cycle 2; landed f161fa0).
- [archive/shell-gate-plan.md](archive/shell-gate-plan.md) — `Archived` —
  first learned gate: committed 28-case bats suite for git-identity-guard.sh +
  `gates/shell.md` (Status: Verified, mirrors rust.md) + root CLAUDE.md Shell gate
  section; ran the gate-learning mechanism end-to-end green on loom's own hook
  (M4 dogfooding; deferred-from-M2; gate green 28/28; landed 34de27c).
- [archive/parallelism-behavior-body.md](archive/parallelism-behavior-body.md) — `Archived` —
  M3 parallelism behavior body: new `references/parallelism.md` operationalizing
  ADR 0008 (worktree-per-slice create→work→land→cleanup, the `.docs/` coordination
  model, concurrency safety, slicer-independence rule); repoints the
  `orchestration.md` + `run.md` guards (drops "M3, not yet" / absolute "one slice
  in flight"); adds it to `SKILL.md` + root `CLAUDE.md` (M3 in progress; landed c6ec48e).
- [archive/gate-learning.md](archive/gate-learning.md) — `Archived` —
  gate-learning for unknown stacks: new `references/gate-learning.md` defining the
  inspect → propose → owner-confirm → run-green-once → record `gates/<stack>.md` +
  project `CLAUDE.md` lifecycle (UNVERIFIED until green); repoints the
  Greenfield/Unaligned/Initialized forward pointers at it (last M2 behavior;
  `gates/shell.md` deferred; completes M2 — landed b2463c4).
- [archive/initialized-init-behavior.md](archive/initialized-init-behavior.md) — `Archived` —
  Initialized init behavior body: resume from a state-derived menu (mapped to the
  dispatch table) into scope/gates + the driver loop, plus idempotent playbook
  re-application (final M2 per-mode body; per-mode trio complete; landed b0bd3e9).
- [archive/unaligned-init-behavior.md](archive/unaligned-init-behavior.md) — `Archived` —
  Unaligned init behavior body: alignment pass on an existing project — study the
  repo, reuse Greenfield scaffold + gate, descriptive `spec/` back-fill (no
  decisions), seed `status/`, resume as Initialized (third M2 slice; landed e83e219).
- [archive/author-identity-enforcement-guard.md](archive/author-identity-enforcement-guard.md) — `Archived` —
  author-identity enforcement guard: PreToolUse hook (`plugins/loom/hooks/`) +
  `commit-convention.md` hardening; enforces ADR 0003's uniform commit identity
  (landed a47bf95).
- [archive/init-mode-detection.md](archive/init-mode-detection.md) — `Archived` —
  one authoritative, precise init-mode classifier (first M2 slice; landed 5fef2ed).
- [archive/greenfield-init-behavior.md](archive/greenfield-init-behavior.md) — `Archived` —
  Greenfield init behavior body: scaffold `.docs/`, seed `status/`, write project
  `CLAUDE.md`, establish the gate (second M2 slice; landed a58ff7e).
- [archive/retire-code-review-status-token.md](archive/retire-code-review-status-token.md) — `Archived` —
  retired the obsolete `Code Review` status token from `SKILL.md`, `status-machine.md`,
  `developer.md`, and the slice-plans README `Lifecycle:` string; aligned to spec 03
  (landed a85885f).
- [archive/recommended-tooling-and-mechanical-checks.md](archive/recommended-tooling-and-mechanical-checks.md) — `Archived` —
  recommended CLI/LSP toolkit reference (`references/tooling.md`) + mechanical-invariant-check
  rule in both eval rubrics + cross-links in `SKILL.md` and three agent files;
  addresses eval-miss root cause (eyeballing invariants) (landed db39d44).
- [archive/scope-identity-guard-to-commit-subcommands.md](archive/scope-identity-guard-to-commit-subcommands.md) — `Abandoned` —
  reverted — shell-string carve-out leaked overrides; read-filter false-positive
  accepted as documented limitation (commit-convention.md).
