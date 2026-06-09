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

- [round-limit-conformance-plan.md](round-limit-conformance-plan.md) — `Implemented` —
  bring the playbook's round-limit text + both evaluator prompts into conformance
  with the amended spec 03 `## Round limits` FAIL-only counting rule (FAIL
  increments / PASS-resolving-a-FAIL shares the number / first review is round 0 /
  one counter per artifact across both phases); point to spec 03 as the single
  source, no divergent restatement (M4 escalation thread, Cycle 2).

## Archived plans

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
