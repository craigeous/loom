# loom

**loom** weaves a development loop out of five specialist roles —
*researcher, planner, plan evaluator, developer, code evaluator* — and drives
them through a file-based, spec-driven process so that work survives context
resets and is reviewed through independent cold-agent evaluation with controlled
inputs.

loom currently provides its proven behavioral workflow through a Claude Code
**plugin**. The same distribution contains validated static Codex packaging contracts;
Codex CLI install and behavior remain pending the private Apple-silicon dogfood slice.
Inside a repository, loom detects
how aligned that repo is with loom's conventions and either bootstraps,
migrates, or resumes work. A thin orchestrator spawns each role as a **cold
agent** on the model best suited to its job, hands off work through files in
`.docs/`, and stops at the scope boundary or human checkpoint you declared.

## Why

- **Context drift** — long sessions lose the thread. loom keeps durable memory in
  `.docs/` so any cold agent can resume from files alone.
- **Controlled evaluation** — independent cold-agent evaluation with controlled
  inputs separates producing and evaluating invocations and prohibits self-approval.
- **Token-smart automation** — each role runs on the cheapest model that can do
  its job well; only judgment-heavy roles use the strongest model.

## Status

**M0 baseline landed; private macOS dual-client dogfood is next.** The reproducible
257-test gate and static Claude Code/Codex packaging contracts are on remote `main`.
Claude Code behavior exists; Codex CLI behavior is not yet claimed. Accepted ADR 0024
inserts a private Darwin `arm64` checkpoint before M1 without changing the v0.2
Ubuntu/macOS-Intel release obligations or its M0 through M7 release gate. The
authoritative design lives in
[`.docs/spec/`](.docs/spec/README.md) — start with
[`00-overview.md`](.docs/spec/00-overview.md); decisions are in
[`.docs/ADR/`](.docs/ADR/README.md).

## Repository layout

```
loom/                          # this repo = the loom project + its marketplace
├── .claude-plugin/marketplace.json   # lists the loom plugin (source ./plugins/loom)
├── .agents/plugins/marketplace.json  # Codex static catalog scaffold
├── plugins/loom/              # the shippable plugin
│   ├── .claude-plugin/plugin.json
│   ├── .codex-plugin/plugin.json
│   ├── adapters/compatibility/v0.2.0.json
│   ├── adapters/roots/        # Claude/Codex installed-root contracts
│   ├── commands/              # /loom:run + one-off /loom:research, :plan, :eval-plan, :develop, :eval-code, :status, :init
│   ├── agents/                # researcher · planner · plan-evaluator · developer · code-evaluator
│   └── skills/loom-playbook/  # templates, rubrics, conventions, gates
├── scripts/check              # pinned, reproducible local gate
└── .docs/                     # loom's OWN design memory (dogfooding) — not shipped
```

## Install

Claude Code's currently proven local plugin path is:

```sh
/plugin marketplace add craigeous/loom     # or: /plugin marketplace add ./loom (local)
/plugin install loom@loom
claude plugin validate plugins/loom --strict # optional: check Claude metadata
```

Codex CLI installation, `$loom-*` discovery, hooks, roles, helpers, and uninstall are
deliberately not documented as supported behavior until `macos-dual-client-dogfood`
passes. The intended mapping is specified in
[`07-command-surface.md`](.docs/spec/07-command-surface.md), not established by the
static manifest alone.

Then, inside any repo, run the orchestrated loop or a single role pass. Plugin
commands are namespaced as `/loom:<name>`:

| Command | What it does |
|---|---|
| `/loom:run [scope]` | the orchestrator — detect state, take scope/gates, drive the roles |
| `/loom:research <topic>` | one-off researcher pass |
| `/loom:plan` | one-off planner pass |
| `/loom:eval-plan [artifact]` | one-off independent cold-agent evaluation with controlled inputs |
| `/loom:develop [slice]` | one-off developer pass |
| `/loom:eval-code [slice]` | one-off independent cold-agent evaluation with controlled inputs |
| `/loom:status` | print `.docs/` state |
| `/loom:init` | initialize/align this repo to loom |

loom operates on the current repo's `.docs/`.

loom **dogfoods its own structure**: this repository is managed by the very
process loom implements.

## Development check

Run the complete gate from any working directory with:

```sh
/absolute/path/to/loom/scripts/check
```

The check pins shfmt 3.13.1, ShellCheck 0.11.0, Bats 1.13.0, Node 22.17.0,
Claude Code 2.1.216, Ajv 8.17.1, YAML 2.8.0, markdown-it 14.1.0, and
github-slugger 2.0.0. Bootstrap prerequisites are `curl` and `tar`; production
requires Bash 3.2+, Git 2.34+, and jq 1.6+. The exact supported client floors are
Claude Code 2.1.216 and Codex CLI 0.144.6.

The v0.2 host baseline is Ubuntu 22.04/24.04 x86-64 and macOS 14+ on Apple
silicon or Intel where the selected client is supported. Native Windows,
PowerShell, Git Bash/MSYS2, Cygwin, and WSL are unsupported. CI covers both Ubuntu
LTS releases, macOS Apple silicon, macOS Intel, Bash 3.2.57, and Bash 5.x.

The checked Codex manifest/catalog, compatibility matrix, and installed-root
bindings are static scaffolding only. They are not evidence of Codex installation,
hook activation, role or workflow invocation, helper resolution, or uninstall.
