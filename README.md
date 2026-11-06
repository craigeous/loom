# loom

**loom** weaves a development loop out of five specialist roles —
*researcher, planner, plan evaluator, developer, code evaluator* — and drives
them through a file-based, spec-driven process so that work survives context
resets and is reviewed through independent cold-agent evaluation with controlled
inputs.

loom provides its behavioral workflow across multiple client environments:
- **Claude Code** (`plugins/loom`, `.claude-plugin/marketplace.json`)
- **Codex CLI** (`plugins/loom`, `.agents/plugins/marketplace.json`)
- **Antigravity / Gemini CLI** (`.agents/skills/`, `.gemini/skills/`)

Inside a repository, loom detects how aligned that repo is with loom's conventions
and either bootstraps, migrates, or resumes work. A thin orchestrator spawns each
role as a **cold agent** on the model best suited to its job, enforces
cross-family evaluation routing so evaluators never approve their own model family's
work, hands off work through durable files in `.docs/`, and stops at the scope boundary
or human checkpoint you declare.

## Why

- **Context drift** — long sessions lose the thread. loom keeps durable memory in
  `.docs/` so any cold agent can resume from files alone.
- **Controlled evaluation** — independent cold-agent evaluation with controlled,
  sanitized inputs separates producing and evaluating invocations and prohibits
  self-approval.
- **Token-smart automation** — each role runs on the model best suited to its job;
  judgment-heavy evaluation roles use the strongest model from an independent family.
- **Fail-closed safety** — strict identity guards, per-session write-ahead backstops,
  and atomic git-ref coordination prevent repo corruption and accidental commits.

## Status

Current milestone: M9

**Milestones M0 through M8 complete; M9 in progress.**

- **M0 — Baseline & Multi-Client Proof**: Reproducible local gate (`scripts/check`),
  four-cell hosted CI, static Claude Code / Codex packaging contracts, and verified
  native lifecycle (install, hook wire, helper resolution, uninstall).
- **M1 — Coordinator Safety**: Centralized identifier validation, ABA-safe git-ref CAS
  locking (`refs/loom/lock`), atomic claims (`refs/loom/claims/<sha1>`), ownership
  re-adoption, and background lease renewal (`plugins/loom/bin/loom-coord`).
- **M2 — Remote Publication Landing Boundary**: Remote publication as the sole landing
  authority via `plugins/loom/bin/loom-land`, atomic push-destination verification,
  receipt binding, and untracked session coordination state.
- **M3 — Identity Guards & PreCompact Backstop**: Raw-command identity scanning
  (`git-identity-guard.sh`), post-command verification (`loom-verify-identity`), and
  per-session write-ahead PreCompact backstops (`precompact-write-ahead-backstop.sh`).
- **M4 — Local Review Orchestration**: Loom-owned review finders, deterministic findings
  assembly (`loom-review`), and complete local review loop without external plugins.
- **M5 — Evaluation Trust Model**: Sanitized evaluation workspaces, bounded gate reruns in
  isolated scratch workspaces, and schema-valid evaluation recording (`loom-eval-workspace`).
- **M6 — Executable Checks & Living Document Shape**: Foundation diagnostics (`loom doctor`),
  mechanical documentation state validation (`validate-repository.mjs --all`), and living
  document shape and milestone synchronization rules.
- **M7 — Packaging Conformance & README Refresh**: Canonical MIT license, version [0.2.0] CHANGELOG,
  CommonMark code fence tracking, supported platforms/prerequisites, multi-client installation/upgrade
  guides, end-to-end example, tier expectations table, and 886 Bats tests snapshot.
- **M8 — Process Cost & Repository Noise**: Paired workflow benchmark harness (`scripts/workflow-benchmark.sh`),
  owner-selected workflow profiles and recommendations (`plugins/loom/bin/loom-profile`), and provisional
  landing history policy with squash publication and durable tracked evidence (ADR 0028).

Authoritative design lives in [`.docs/spec/`](.docs/spec/README.md) — start with
[`00-overview.md`](.docs/spec/00-overview.md); architecture decisions are in
[`.docs/ADR/`](.docs/ADR/README.md); active progress is recorded in
[`.docs/status/progress.md`](.docs/status/progress.md) and
[`.docs/status/roadmap.md`](.docs/status/roadmap.md).

## Supported Platforms & Prerequisites

- **Hosts:** Ubuntu 22.04 and 24.04 (x86-64); macOS 14+ (arm64 and x86-64), where the
  selected client is supported. Native Windows, PowerShell, Git Bash/MSYS2, Cygwin, and
  WSL are unsupported.
- **Runtime tools:** Bash 3.2+, Git 2.34+, jq 1.6+.
- **Clients:** Claude Code >= 2.1.216; Codex CLI >= 0.144.6. Newer client versions
  require release evidence per spec 10.
- **Plugin dependencies:** none. loom declares no external plugin dependencies in its
  manifests or catalogs; Bash, Git, and jq are system tools, and Claude Code and Codex
  CLI are the host clients.

## Repository layout

```
loom/                                    # this repo = loom core + client bindings
├── .claude-plugin/marketplace.json      # Claude plugin marketplace catalog
├── .agents/                             # Codex catalog and Antigravity client skills
│   ├── plugins/marketplace.json
│   └── skills/                          # Antigravity skill adapters
├── .gemini/skills/                      # Gemini CLI skill adapters
├── plugins/loom/                        # the shippable plugin
│   ├── .claude-plugin/plugin.json
│   ├── .codex-plugin/plugin.json
│   ├── adapters/                        # compatibility matrices and installed-root bindings
│   ├── commands/                        # /loom:run, /loom:doctor, /loom:plan, etc.
│   ├── agents/                          # thin client adapters over roles/*.md contracts
│   ├── roles/                           # canonical role contracts
│   ├── finders/                         # local review finders (correctness, tests, security)
│   ├── bin/                             # unified CLI and helpers
│   │   ├── loom                         # top-level CLI entry point
│   │   ├── loom-doctor                  # read-only diagnostics helper
│   │   ├── loom-coord                   # multi-session coordination CLI
│   │   ├── loom-land                    # remote-first landing helper
│   │   ├── loom-review                  # local review protocol runner
│   │   ├── loom-eval-workspace          # sanitized evaluation workspace helper
│   │   ├── loom-launch-role             # cross-family client role launcher
│   │   ├── loom-resolve-helper          # installed-root helper resolution
│   │   └── loom-verify-identity         # post-commit author identity verifier
│   ├── hooks/                           # git-identity-guard.sh, precompact-write-ahead-backstop.sh
│   ├── schemas/                         # JSON Schemas for manifests, reviews, outputs
│   └── skills/loom-playbook/            # templates, rubrics, conventions, gates
├── scripts/check                        # pinned, reproducible local gate (886 Bats tests, a snapshot count)
└── .docs/                               # loom's own design memory (dogfooding)
```

## CLI & Helper Usage

Loom provides a unified CLI entry point at `plugins/loom/bin/loom` (accessible directly
or through client commands):

```sh
# Run repository and environment diagnostics
loom doctor [--json] [--repo <path>]

# Multi-session coordination
loom coord lock-acquire
loom coord claim-acquire <slice-name>
loom coord checkpoint-write --session <id>
loom coord lock-release

# Local 3-finder code review
loom review prepare --base <commit> --head <commit>
loom review validate
loom review assemble --out <path>

# Sanitized evaluation workspace
loom eval-workspace prepare --manifest <manifest.json> --out-dir <scratch>
loom eval-workspace gate-rerun --manifest <manifest.json>
loom eval-workspace record --output <eval-output.json>
```

## Installation & Upgrade

### Claude Code

```sh
/plugin marketplace add craigeous/loom     # or: /plugin marketplace add ./loom (local checkout)
/plugin install loom@loom
```

To upgrade, refresh the marketplace from the matching checkout or remote and
reinstall: `/plugin uninstall loom@loom` then `/plugin install loom@loom`.
Tracked project state under `.docs/` is untouched by upgrades.

### Codex CLI

Run these from a shell, pointing at a local checkout (or the remote repo):

```sh
codex plugin marketplace add /absolute/path/to/loom
codex plugin add loom@loom
```

To upgrade, `codex plugin remove loom@loom` and add it again from the updated
checkout. Invoke workflows as `$loom-<name>` (for example `$loom-init`,
`$loom-run`). Syntax follows the checked-in compatibility fixtures
(`plugins/loom/adapters/fixtures/v0.2.0/release-install/`); migration and
unsupported-surface limits are in [spec 10](.docs/spec/10-packaging.md).

### Antigravity (unverified)

Antigravity discovers the repository's `.agents/skills/` adapters (Gemini CLI uses
`.gemini/skills/`); see [ADR 0027](.docs/ADR/0027-client-model-matrix-modernization-and-ambient-inheritance.md).
Refresh by updating the checkout so the adapters match the canonical files under
`plugins/loom/`, which they depend on. This integration is **unverified**: there is
no public release evidence for it, and it is not release conformance.

Slash commands (Claude Code):

| Command | What it does |
|---|---|
| `/loom:run [scope]` | the orchestrator — detect state, take scope/gates, drive the roles |
| `/loom:doctor` | run environment and repository diagnostics |
| `/loom:research <topic>` | one-off researcher pass |
| `/loom:plan` | one-off planner pass |
| `/loom:eval-plan [artifact]` | one-off independent cold-agent evaluation with controlled inputs |
| `/loom:develop [slice]` | one-off developer pass |
| `/loom:eval-code [slice]` | one-off independent cold-agent evaluation with controlled inputs |
| `/loom:status` | print `.docs/` state |
| `/loom:init` | initialize/align this repo to loom |

## Example

In a Git repository:

```text
/loom:init                      # classify repo, scaffold .docs/, confirm the gate
/loom:run add-login-form        # scope = slice "add-login-form"; confirm gate (format → lint → test)
```

In Codex the same flow is `$loom-init` then `$loom-run add-login-form`. The
orchestrator asks for scope and gate, then drives planning, independent plan
evaluation, development, the gate, independent code evaluation, and remote
publication. Checkpoints and failures can pause the sequence; resume by running
`/loom:run` (or `$loom-run`) again.

## Artifacts

Tracked, durable project history lives in `.docs/`: `spec/`, `ADR/`, `research/`,
`slice-plans/`, `evaluations/`, and `status/`, plus generated instruction adapters.
Transient local coordination state (claims, checkpoints, locks) lives under
`<git-common-dir>/loom/` (normally `.git/loom/`) and is never committed.

## Expectations

| Tier | Roles | Relative capability and cost |
|---|---|---|
| Economy | researcher | smallest/cheapest model |
| Standard | developer, orchestrator | mid-tier model |
| Deep review | planner, plan evaluator, code evaluator | strongest model, highest cost |

Models vary by client and are resolved in your environment (ADR 0002, 0027). No
reliable time or cost estimate is established: elapsed time and tokens depend on the
slice size, client and model, gate duration, and retries and review rounds, which
each add time and tokens.

## Development Check

Run the complete gate from any working directory with:

```sh
/absolute/path/to/loom/scripts/check
```

The check pins shfmt 3.13.1, ShellCheck 0.11.0, Bats 1.13.0, Node 22.17.0,
Claude Code 2.1.216, Ajv 8.17.1, YAML 2.8.0, markdown-it 14.1.0, and
github-slugger 2.0.0. Bootstrap prerequisites are `curl` and `tar`; production
requires Bash 3.2+, Git 2.34+, and jq 1.6+. The exact supported client floors are
Claude Code 2.1.216 and Codex CLI 0.144.6. 886 Bats tests (a snapshot count, not a permanent guarantee) verify end-to-end
coordination, evaluation workspaces, review finders, identity guards, and role
routing.

The v0.2 host baseline is Ubuntu 22.04/24.04 x86-64 and macOS 14+ on Apple
silicon or Intel where the selected client is supported. Native Windows,
PowerShell, Git Bash/MSYS2, Cygwin, and WSL are unsupported. CI covers both Ubuntu
LTS releases, macOS Apple silicon, macOS Intel, Bash 3.2.57, and Bash 5.x.

The checked Codex manifest/catalog, compatibility matrix, and installed-root
bindings are static scaffolding only. The evidence file
[`.docs/evaluations/macos-dual-client-dogfood-evidence.json`](.docs/evaluations/macos-dual-client-dogfood-evidence.json)
records a blocked historical checkpoint (Codex role launch `infrastructure-blocked`)
and confers no support status.
