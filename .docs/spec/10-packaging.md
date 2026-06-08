# 10 — Packaging & Distribution

Status: Plan Review

loom is a Claude Code **plugin**, distributed as its own single-plugin
**marketplace** (ADR 0001, 0006). Mechanics verified against the official
plugins-reference and plugin-marketplaces docs (June 2026); see
[`../research/2026-06-07-claude-code-plugin-mechanics.md`](../research/2026-06-07-claude-code-plugin-mechanics.md).

## Repository layout

The repo root is **the loom project + its marketplace**; the shippable plugin
lives under `plugins/loom/`.

```
loom/                                  # project repo = marketplace
├── .claude-plugin/
│   └── marketplace.json               # catalog: lists loom at source ./plugins/loom
├── plugins/
│   └── loom/                          # the shippable plugin
│       ├── .claude-plugin/plugin.json # plugin manifest (required, here)
│       ├── commands/                  # /loom:run + one-off /loom:<role> commands
│       ├── agents/                    # the five role agents
│       │   ├── researcher.md  planner.md  plan-evaluator.md
│       │   └── developer.md   code-evaluator.md
│       └── skills/
│           └── loom-playbook/         # the playbook (templates, references, gates)
├── .docs/                             # loom's OWN dev memory (dogfooding) — not shipped
├── README.md
├── CLAUDE.md
└── LICENSE
```

Default component dirs (`commands/`, `agents/`, `skills/`) are auto-discovered
within the plugin. `.docs/` is loom's design memory, not a plugin component — when
loom is installed elsewhere it *creates* a fresh `.docs/` in that project.

## Command surface (OQ-D resolved, empirically)

Plugin components are **namespaced by plugin name** — there is no bare `/loom`. The
surface is **one file per command** (each → `/loom:<filename>`): `run` (the
orchestrator) plus one-off `research`, `plan`, `eval-plan`, `develop`, `eval-code`,
`status`, `init`. The five roles are `agents/` the commands spawn via the Task tool,
namespaced `loom:<role>`. Shared orchestrator rules live in
`skills/loom-playbook/references/orchestration.md` so the thin command files stay
consistent. See [07 — Command Surface](07-command-surface.md).

## plugin.json (`plugins/loom/.claude-plugin/plugin.json`)

```json
{
  "name": "loom",
  "version": "0.1.0",
  "description": "Spec-driven dev loop with five blind-reviewed roles and an orchestrator",
  "author": { "name": "Craig", "email": "craigeous@gmail.com" },
  "homepage": "https://github.com/craigeous/loom",
  "repository": "https://github.com/craigeous/loom",
  "license": "MIT",
  "keywords": ["spec-driven", "agents", "orchestration", "code-review", "workflow"]
}
```

`name` is the only required field; it namespaces components. kebab-case.

## Agent frontmatter (verified fields)

The five shipped agents (`plugins/loom/agents/*.md`) use exactly five frontmatter
fields: `name` (**required** — namespaces the agent `loom:<name>`), `description`,
`model`, `color`, and `tools`. `model` takes a tier
(`inherit`/`sonnet`/`opus`/`haiku`) — ADR 0002.

`isolation: "worktree"` and `background` agents are **not** part of today's
verified manifest — they are loom's *planned M3 parallelism mechanism* (worktree
per slice), described in
[`../../plugins/loom/skills/loom-playbook/references/orchestration.md`](../../plugins/loom/skills/loom-playbook/references/orchestration.md)
(Parallelism section, marked "M3, not yet"). They are forward-looking and must not
be relied on until M3 verifies them.

## marketplace.json (`.claude-plugin/marketplace.json`)

```json
{
  "name": "loom",
  "description": "loom — a spec-driven, multi-agent development loop with blind evaluation",
  "owner": { "name": "Craig", "email": "craigeous@gmail.com" },
  "plugins": [
    {
      "name": "loom",
      "source": "./plugins/loom",
      "description": "Spec-driven multi-agent development loop with blind evaluation",
      "category": "development"
    }
  ]
}
```

A relative `source` must start with `./` and resolves from the marketplace root;
it works when users add the marketplace **via git** (not a direct URL to the JSON).

## Install flow (for any project)

```
/plugin marketplace add craigeous/loom    # or:  /plugin marketplace add ./loom  (local)
/plugin install loom@loom
```

Then, inside any repo, `/loom:run` operates on that repo's `.docs/` (with the
one-off `/loom:<role>` commands also available). For local
development, the `@skills-dir` mechanism (a `plugin.json` under
`~/.claude/skills/<name>/`) also loads a plugin with no marketplace step.

## Versioning & releases

- Semver in `plugin.json`; tag releases with `claude plugin marketplace ... ` /
  git tags. Marketplace entries may pin a `ref` for reproducible installs.
- The playbook evolves with loom; a release bundles the current playbook.
