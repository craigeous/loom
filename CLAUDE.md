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
- loom's content is primarily markdown (prompts/templates). Its executable code is
  POSIX-sh, split across two directories and all shell-gated (`shfmt` → `shellcheck` →
  `bats`):
  - **`plugins/loom/hooks/`** — two PreToolUse/PreCompact guard hooks, auto-discovered via
    `hooks/hooks.json`: `git-identity-guard.sh` (PreToolUse identity guard, ADR 0003) and
    `precompact-write-ahead-backstop.sh` (PreCompact write-ahead backstop, ADR 0013 §Decision 5
    — blocks `manual` compaction when `.docs/` has not advanced since the last compaction marker;
    never-wedge on `auto`).
  - **`plugins/loom/lib/`** — loom's **first non-hook CLI helper**: `loom-coord.sh` — the
    multi-session coordination mechanism (ADR 0014/0015/0016). **Not a hook** (not in
    `hooks.json`); the orchestrator/session calls it directly. Mechanism: git-`update-ref` CAS
    lock on `refs/loom/lock` + per-slice claim refs on `refs/loom/claims/<sha1>` (ABA-safe by
    construction; git owns atomicity — ADR 0016); lease-freshness liveness + `{pid,start-time}`-gated
    background renewer (ADR 0015); fails **closed** (inverse of the guard hooks). Subcommands:
    `lock-acquire`/`lock-release`/`lock-verify`; `claim`/`renew`/`release-claim`/`reclaim`/`list-claims`;
    `session-start`/`session-bootstrap`/`session-end`; `cleanup`. The shell gate now covers
    `plugins/loom/lib/` as well as `plugins/loom/hooks/`. Operational playbook-body wiring
    (`parallelism.md`/`orchestration.md`/`run.md`) lands in **slice W** (pending).
  - The Rust gate loom *imposes on managed projects* is in
    `plugins/loom/skills/loom-playbook/gates/rust.md`.
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
- **Automated review in the code-review phase** (ADR 0010, command corrected by ADR 0011):
  `plugins/loom/skills/loom-playbook/references/review-findings.md`
  is the single-source definition of the review-findings artifact (path
  `.docs/evaluations/<slice>-review-findings.md`; identity-neutral; four distinguishable
  statuses `ran-with-findings` / `ran-clean` / `skipped: docs-only` /
  `skipped: command-unavailable`). At `Implemented`, the **orchestrator** (only it may
  spawn — ADR 0001) runs **`/code-review`** + **`/security-review`** on the slice's
  diff in **local mode** — `/code-review`, not the PR-bound `/review` (ADR 0011);
  since the slice is already committed, target its **commit range / branch**
  (`git diff <base>...<slice-HEAD>`), not the empty working tree. It writes that
  artifact and hands it to the **blind code-evaluator** as **advisory** input (the
  evaluator adjudicates and owns the verdict via `severity.md`). **"Run" means a real
  tool call** — the orchestrator must actually invoke the `code-review` /
  `security-review` skills (Skill tool / slash command) and transcribe their emitted
  output; authoring findings from its own reading of the diff is a hard violation, and
  the only honest non-run outcomes are the two `skipped:` tokens (the
  *Actually invoke — never simulate* rule in `orchestration.md` + the faithfulness
  invariant in `review-findings.md`). Runs on code-bearing
  diffs only (pure-docs slices skip-with-a-note); a **separate review dimension, NOT
  part of the** `format → lint → test` **gate**. Wired across
  `references/orchestration.md` (run step), `references/code-eval-rubric.md`
  (adjudication), and `agents/code-evaluator.md` (inputs); specs 04 §"Automated review
  before a slice lands" + 02 (Code Evaluator) are the frozen authority.
- **Thin orchestrator** (ADR 0012): the orchestrator (the `/loom:run` main session)
  defaults to the **`sonnet` tier** (`model: sonnet` in `commands/run.md`; extends
  ADR 0002's tier table — `opus` stays reserved for planner + both evaluators). Its
  context must scale with the number of in-flight artifacts, not the size of the work
  product. Four rules (single source: `references/orchestration.md` → *Context
  discipline*; spec 04 → *Thin-orchestrator invariant*): **pass references, never
  bodies** (hand roles `.docs/` paths); **bounded role-return contract** (every role
  replies with only `{Status:, path(s), ≤~150-token summary, the one branch signal}`,
  never its body — enforced in all five `agents/*.md` + spec 02 *Bounded return*);
  **route on the signal, not the prose**; and **compaction = cold self-restart** from
  the status digest (checkpoint to `handoff.md`, re-bootstrap), not a lossy summary —
  loom's answer to context pressure in place of a numeric auto-compact threshold.
  Sonnet 4.6 is **context-aware** (it gets a running `Token usage … remaining` signal
  after each tool call), so the orchestrator self-triggers the restart at **~60%** of
  budget (operational default). Restart safety is **write-ahead** (ADR 0013): commit
  the next intended action to `handoff.md` *before* a large/in-window op and restart *before*
  such an op when near budget; a restart that re-derives the same action with no new
  commit since is a **starvation loop** → escalate, never re-attempt. The 60%
  lossless self-restart stays *below* the harness's lossy auto-compact (~80% default),
  which is only a backstop — don't lower it to 60% (`orchestration.md` → *Restart
  safely*). The
  automated-review run step is the one in-window exception and is **write-and-forget**.
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

**Shell gate** (`gates/shell.md`) — the first *learned* gate, covers all POSIX-sh in
`plugins/loom/hooks/` and `plugins/loom/lib/` (path-generic). Example invocation on a file:
- format: `shfmt -i 4 -d <file.sh>`
- lint: `shellcheck <file.sh>`
- test: `bats <file.bats>`

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
