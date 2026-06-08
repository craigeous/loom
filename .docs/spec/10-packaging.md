# 10 — Packaging & Distribution

Status: Draft

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
│       ├── commands/loom.md           # /loom — orchestrator (dispatches on $ARGUMENTS)
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

## Command surface (OQ-D resolved)

A **single `/loom` command dispatches on its first argument** rather than shipping
one command file per role:

- `/loom` / `/loom <scope>` → orchestrated driver loop.
- `/loom research|plan|eval-plan|develop|eval-code|status|init [...]` → one-off
  single-role pass.

This is the `feature-dev` pattern and avoids per-command namespacing questions.
The five roles are `agents/` the command spawns via the Task tool; they appear as
`loom:researcher` etc. (plugin name namespaces components).

## plugin.json (`plugins/loom/.claude-plugin/plugin.json`)

```json
{
  "name": "loom",
  "version": "0.1.0",
  "description": "Spec-driven dev loop with five blind-reviewed roles and an orchestrator",
  "author": { "name": "Craig", "email": "craigeous@gmail.com" },
  "homepage": "https://github.com/<owner>/loom",
  "repository": "https://github.com/<owner>/loom",
  "license": "MIT",
  "keywords": ["spec-driven", "agents", "orchestration", "code-review", "workflow"]
}
```

`name` is the only required field; it namespaces components. kebab-case.

## Agent frontmatter (verified fields)

Plugin agents support: `name`, `description`, `model`, `effort`, `maxTurns`,
`tools`, `disallowedTools`, `skills`, `memory`, `background`, and `isolation`
(only `"worktree"`). `hooks`/`mcpServers`/`permissionMode` are **not** allowed in
plugin agents. `model` takes a tier (`inherit`/`sonnet`/`opus`/`haiku`) — ADR
0002. `isolation: "worktree"` and `background` are the built-ins loom's M3
parallelism uses.

## marketplace.json (`.claude-plugin/marketplace.json`)

```json
{
  "name": "loom",
  "owner": { "name": "Craig", "email": "craigeous@gmail.com" },
  "plugins": [
    {
      "name": "loom",
      "source": "./plugins/loom",
      "description": "Spec-driven multi-agent development loop",
      "category": "development"
    }
  ]
}
```

A relative `source` must start with `./` and resolves from the marketplace root;
it works when users add the marketplace **via git** (not a direct URL to the JSON).

## Install flow (for any project)

```
/plugin marketplace add <owner>/loom      # or:  /plugin marketplace add ./loom  (local)
/plugin install loom@loom
```

Then, inside any repo, `/loom` operates on that repo's `.docs/`. For local
development, the `@skills-dir` mechanism (a `plugin.json` under
`~/.claude/skills/<name>/`) also loads a plugin with no marketplace step.

## Versioning & releases

- Semver in `plugin.json`; tag releases with `claude plugin marketplace ... ` /
  git tags. Marketplace entries may pin a `ref` for reproducible installs.
- The playbook evolves with loom; a release bundles the current playbook.
