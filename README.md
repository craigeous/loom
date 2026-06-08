# loom

**loom** weaves a development loop out of five specialist roles —
*researcher, planner, plan evaluator, developer, code evaluator* — and drives
them through a file-based, spec-driven process so that work survives context
resets and is reviewed with blind, impartial rigor.

loom is a Claude Code **skill**. You invoke it inside any repository; it detects
how aligned that repo is with loom's conventions and either bootstraps,
migrates, or resumes work. A thin orchestrator spawns each role as a **cold
agent** on the model best suited to its job, hands off work through files in
`.docs/`, and stops at the scope boundary or human checkpoint you declared.

## Why

- **Context drift** — long sessions lose the thread. loom keeps durable memory in
  `.docs/` so any cold agent can resume from files alone.
- **Blind rigor** — evaluators judge work without knowing who produced it, so
  review stays critical and free of self-approval.
- **Token-smart automation** — each role runs on the cheapest model that can do
  its job well; only judgment-heavy roles use the strongest model.

## Status

**M1 — minimum sequential loop (in progress).** The plugin is scaffolded: the
`/loom` orchestrator command, the five role agents, and the playbook all exist.
Not yet run end-to-end. The authoritative design lives in
[`.docs/spec/`](.docs/spec/README.md) — start with
[`00-overview.md`](.docs/spec/00-overview.md); decisions are in
[`.docs/ADR/`](.docs/ADR/README.md).

## Repository layout

```
loom/                          # this repo = the loom project + its marketplace
├── .claude-plugin/marketplace.json   # lists the loom plugin (source ./plugins/loom)
├── plugins/loom/              # the shippable plugin
│   ├── .claude-plugin/plugin.json
│   ├── commands/              # /loom:run + one-off /loom:research, :plan, :eval-plan, :develop, :eval-code, :status, :init
│   ├── agents/                # researcher · planner · plan-evaluator · developer · code-evaluator
│   └── skills/loom-playbook/  # templates, rubrics, conventions, gates
└── .docs/                     # loom's OWN design memory (dogfooding) — not shipped
```

## Install

```sh
/plugin marketplace add Craigeous/loom     # or: /plugin marketplace add ./loom (local)
/plugin install loom@loom
/plugin validate ./loom                     # optional: check manifests + frontmatter
```

Then, inside any repo, run the orchestrated loop or a single role pass. Plugin
commands are namespaced as `/loom:<name>`:

| Command | What it does |
|---|---|
| `/loom:run [scope]` | the orchestrator — detect state, take scope/gates, drive the roles |
| `/loom:research <topic>` | one-off researcher pass |
| `/loom:plan` | one-off planner pass |
| `/loom:eval-plan [artifact]` | one-off blind plan/research review |
| `/loom:develop [slice]` | one-off developer pass |
| `/loom:eval-code [slice]` | one-off blind code review |
| `/loom:status` | print `.docs/` state |
| `/loom:init` | initialize/align this repo to loom |

loom operates on the current repo's `.docs/`.

loom **dogfoods its own structure**: this repository is managed by the very
process loom implements.
