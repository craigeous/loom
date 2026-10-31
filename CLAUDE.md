# CLAUDE.md — loom

loom is a Claude Code plugin that automates a spec-driven development loop with
five blind-reviewed roles. This file is the entry point for any agent working in
this repo.
<!-- loom:project-instructions begin schema=loom-project-instructions/v1 sha256=025e848ae610480a69d54967c9cafb87effe278464130d9cf421ca7100b2b2bf -->
## Loom project instructions

- Read `.docs/spec/README.md`, `.docs/status/handoff.md`, progress, then roadmap.
- Five cold roles use committed artifacts; no self-review; only root delegates.
- Specs change only through planner + cold plan evaluation. Remote verification and
  receipt establish `Landed`; never force-push a target.
- Keep shared policy portable and client adapters thin. Private macOS dogfood is not
  public support or release conformance.
- Run `scripts/check`; runtime floors are Bash 3.2+, Git 2.34+, and jq 1.6+.
- Claude workflows use `/loom:<name>` and installed helpers resolve from the physical
  Claude plugin root; see specs 03, 04, 07, 08, and 10 for authority.
<!-- loom:project-instructions end -->

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

## Map (where authoritative things live)

- **`plugins/loom/`** — commands/agents (thin Claude adapters), `roles/*.md` (canonical role contracts), `skills/loom-*` (shared client-neutral workflow bodies), hooks, and separate Claude/Codex manifests; catalogs are `.claude-plugin/marketplace.json` and `.agents/plugins/marketplace.json`.
- **`plugins/loom/adapters/`** — the v0.2.0 compatibility matrix, installed-root bindings, and release-owned static metadata fixtures.
- **`.docs/`** — loom's own design memory (dogfooding); not a plugin component.
- **`plugins/loom/hooks/`** — `git-identity-guard.sh` (ADR 0003) + `precompact-write-ahead-backstop.sh` (ADR 0013 §Decision 5); one shared `hooks.json` for both clients (policy/wire split at the executable boundary, spec 08; 12-case (2 clients × 2 events × 3 outcomes; 48 fixture files at 4/case) `hooks/fixtures/hook-wire-v1/` product); shell-gated.
- **`plugins/loom/bin/`** — `loom-coord` (multi-session coordination CLI; ADR 0014/0015/0016), `loom-resolve-helper` (installed-root helper resolution, both clients), `loom-launch-role` (sole client role launcher, compatibility-matrix-driven), `loom-verify-identity` (post-commit identity check); on `$PATH`.
- **`scripts/macos-dual-client-dogfood`** — private Apple-silicon dual-client dogfood harness (fail-closed supervisor/worker journal); private evidence only, not public Codex support (ADR 0024).
- **`gates/rust.md`** — Rust gate loom imposes on managed projects.
- **`references/init-detection.md`** — Greenfield/Unaligned/Initialized classifier; all `/loom:*` run this first (M2).
- **`references/greenfield.md`** — Greenfield init body (scaffold + seed + CLAUDE.md + gate).
- **`references/unaligned.md`** — Unaligned init body: bare (back-fill) + migrate (owner gate) (ADR 0009).
- **`references/initialized.md`** — Initialized init body (resume: state-derived menu → driver loop; idempotent re-apply).
- **`references/gate-learning.md`** — unknown-stack gate learning (inspect → propose → confirm → green-once → record).
- **`references/tooling.md`** — recommended CLI/LSP toolkit + verify-mechanically-not-by-eye discipline.
- **`references/parallelism.md`** — worktree-per-slice ops + multi-session coordination (ADR 0008, 0014/0015/0016).
- **`references/migration-recipe.md`** — reusable Unaligned-migrate recipe (ADR 0009 §5/§7).
- **`references/review-findings.md`** — review-findings artifact + orchestrator-runs-`/code-review`+`/security-review` at `Implemented` (ADR 0010, 0011).
- **`references/orchestration.md`** — context discipline + cold restart + ~60% trigger + bounded return (ADR 0012, 0013); infra-blocked escalation + degraded-review honesty + incremental-commit (ADR 0017).

When editing the playbook/agents, keep them consistent with `.docs/spec/` + ADRs.

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

**Shell gate** (`gates/shell.md`) — Bash 3.2+ with pinned format, lint, syntax,
runtime, metadata, link, and client-validation stages. During iteration, run targeted
checks (`shfmt -i 4 -d`, `shellcheck -s bash`, `bats --filter <pattern> <file>` with
`TMPDIR=/private/tmp` on macOS); run the full repository gate once on the candidate
commit (`TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`).

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
corrected to match. See spec 08 (*§ Shape and Concision Discipline*) — this file stays ≤ ~100 lines; point, don't restate.
