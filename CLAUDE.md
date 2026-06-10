# CLAUDE.md — loom

loom is a Claude Code plugin that automates a spec-driven development loop with
five blind-reviewed roles. This file is the entry point for any agent working in
this repo.

## Read first

1. `.docs/spec/README.md` — reading order and non-negotiable decisions.
2. The specific spec for the area you are changing.
3. `.docs/status/handoff.md` — restart instructions and current next step.
4. `.docs/status/progress.md` — status source of truth.

## What loom is (one paragraph)

loom is a Claude Code **plugin**. The **orchestrator is the main session running
the `/loom:run` command**; it spawns five cold role agents — researcher, planner, plan
evaluator, developer, code evaluator — each on a chosen model **tier** (sub-agents
can't spawn sub-agents, so only the orchestrator spawns). Roles never share live
context; they hand off through files in `.docs/`, and **every handoff commits**.
An artifact's **status** is the dispatcher. Evaluators review work **blind** (no
author identity, no author reasoning, diffing commits), and no role ever reviews
work it produced — role separation guarantees no self-approval. Specs are frozen
after approval and change only via planning. Design decisions are in
`.docs/spec/` and `.docs/ADR/`.

## Repo layout (M0–M4 complete)

- The **shippable plugin** lives in `plugins/loom/` (`commands/` — `/loom:run` plus
  one-off `/loom:<role>` commands; `agents/`; `skills/loom-playbook/`;
  `hooks/` — PreToolUse guard scripts, auto-discovered via `hooks/hooks.json`); the
  marketplace catalog is `.claude-plugin/marketplace.json`. Plugin components are
  namespaced `loom:<name>` (no bare `/loom`).
- `.docs/` is loom's **own** design memory (dogfooding) — not a plugin component.
- loom's content is primarily markdown (prompts/templates). Its one piece of
  executable code is the POSIX-sh identity-guard hook
  `plugins/loom/hooks/git-identity-guard.sh`. The Rust gate loom *imposes on
  managed projects* is in `plugins/loom/skills/loom-playbook/gates/rust.md`.
- **Init-mode classifier** (M2): `plugins/loom/skills/loom-playbook/references/init-detection.md`
  is the single authoritative source for Greenfield / Unaligned / Initialized
  detection. All `/loom:*` commands run this classifier first.
- **Greenfield behavior body** (M2): `plugins/loom/skills/loom-playbook/references/greenfield.md`
  is the single authoritative body for Greenfield init (scaffold + seed + CLAUDE.md
  + gate).
- **Unaligned behavior body** (M2 + ADR 0009): `plugins/loom/skills/loom-playbook/references/unaligned.md`
  is the single authoritative body for Unaligned init — covers both sub-modes routed
  by `init-detection.md`: **Unaligned-bare** (no pre-existing docs spine → descriptive
  `spec/` back-fill via `greenfield.md` scaffold + gate, resume as Initialized) and
  **Unaligned-migrate** (pre-existing docs spine → owner gate migrate/thin-pointer/abort,
  inline `migration-recipe.md` recipe, status preserved, no role-spawn).
- **Initialized behavior body** (M2): `plugins/loom/skills/loom-playbook/references/initialized.md`
  is the single authoritative body for Initialized init (resume: derive a menu from
  `.docs/` + git state, hand into scope/gates + the `/loom:run` driver loop;
  idempotent playbook re-application — auto-apply clean, recommend for conflicts,
  never clobber).
- **Gate-learning body** (M2): `plugins/loom/skills/loom-playbook/references/gate-learning.md`
  is the single authoritative body for the unknown-stack gate-learning mechanism
  (inspect toolchain → propose → owner-confirm → run-green-once → record
  `gates/<stack>.md` + project `CLAUDE.md`; UNVERIFIED until green). M2 is now
  complete.
- **Recommended tooling + mechanical-check discipline**: `plugins/loom/skills/loom-playbook/references/tooling.md`
  — CLI/LSP toolkit by role (all optional with fallback); verify invariants with `rg -U`/`yq`/`ast-grep`,
  not by eye. Cross-linked from `SKILL.md`, both eval rubrics, and the three agent files.
- **Parallelism behavior body** (M3): `plugins/loom/skills/loom-playbook/references/parallelism.md`
  is the single authoritative worktree-per-slice operational body (ADR 0008):
  create→work→land→cleanup, the `.docs/` coordination model (living docs +
  slice-plans index orchestrator-owned/main-only/serialized; slice branches carry
  only disjoint plan/eval/code), concurrency safety, and the slicer-independence
  rule.
- **Migration recipe** (ADR 0009): `plugins/loom/skills/loom-playbook/references/migration-recipe.md`
  is the reusable Unaligned-migrate recipe (ADR 0009 §5/§7): ordered, idempotent
  cross-reference rewrite (specific-before-generic; negative lookbehind against
  self-match), the numbered-spine → `spec/` + `status/` split with two-directional
  link rewrite, the three reference forms, the living-rewritten vs archived-snapshot
  boundary, the operational preconditions (dirty-tree check, untracked-file handling,
  NUL-delimited lists), status preservation (per spec 06 §2b), and final link
  validation.
- When editing the playbook/agents, keep them consistent with `.docs/spec/` + ADRs.

## Project conventions

- Durable memory is `.docs/spec/` and `.docs/ADR/`. Specs win over plans on
  conflict. ADRs are immutable after acceptance (supersede, never rewrite).
- Transient working memory is `.docs/slice-plans/`. Plans propose; specs decide.
- Evaluation verdicts live in `.docs/evaluations/<artifact-name>-eval.md`.
- The three living docs in `.docs/status/` (roadmap, progress, handoff) are kept
  separate, each with one job.

## Gate

The standard loom gate is **format → lint → test**, run in that order before any
slice is considered `Implemented`. Verified gates ship in
`plugins/loom/skills/loom-playbook/gates/`.

**Rust gate** (`gates/rust.md`):
`cargo fmt --check` → `cargo clippy --all-targets -- -D warnings` → `cargo test`

**Shell gate** (`gates/shell.md`) — the first *learned* gate, now verified on
loom's own hook `plugins/loom/hooks/git-identity-guard.sh`:
- format: `shfmt -i 4 -d plugins/loom/hooks/git-identity-guard.sh`
- lint: `shellcheck plugins/loom/hooks/git-identity-guard.sh`
- test: `bats plugins/loom/hooks/git-identity-guard.bats`

For other stacks, the unknown-stack path is specified in
`plugins/loom/skills/loom-playbook/references/gate-learning.md` (inspect toolchain
→ propose `format → lint → test` → owner-confirm → run-green-once → record
`gates/<stack>.md` + project `CLAUDE.md`; a gate stays UNVERIFIED until it has run
green at least once). loom imposes this gate on managed projects and on itself.

## Update this file before committing

This file is a **curated digest** — a stable, agent-facing map of durable conventions,
repo-layout facts, gate definitions, and read-first pointers. It is maintained by the
**developer's finalize pass** when a landed slice changes something in that scope (per
spec 03 finalize pass step 2; boundary defined in `.docs/spec/08-playbook.md` —
*Evolving the playbook → CLAUDE.md auto-propagation*). Per-slice history stays in
`.docs/status/progress.md`, not here. On any conflict, the specs win and this file is
corrected to match.
