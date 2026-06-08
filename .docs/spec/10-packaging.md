# 10 — Packaging & Distribution

Status: Draft

loom is a Claude Code **plugin**, distributed as its own single-plugin
**marketplace** (ADR 0001, 0006). This section records the concrete on-disk and
distribution shape; mechanics are sourced from
[`../research/2026-06-07-claude-code-plugin-mechanics.md`](../research/2026-06-07-claude-code-plugin-mechanics.md).

## Repository layout

```
loom/
├── .claude-plugin/
│   ├── plugin.json          # plugin manifest (required, must be here)
│   └── marketplace.json     # self-marketplace listing (source: ".")
├── commands/                # /loom + per-role one-off commands
├── agents/                  # researcher, planner, plan-evaluator, developer, code-evaluator
├── skills/
│   └── loom-playbook/       # the playbook (templates, references, gates)
├── .docs/                   # loom's OWN dev memory (dogfooding) — not a plugin component
├── README.md
├── CLAUDE.md
└── LICENSE
```

Default component dirs (`commands/`, `agents/`, `skills/`) are auto-discovered; the
manifest needs no path config. `.docs/` is ordinary repo content (loom's own
design memory), not a plugin component — when loom is installed elsewhere it
*creates* a fresh `.docs/` in that project.

## plugin.json

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

- `name`: kebab-case, `^[a-z][a-z0-9]*(-[a-z0-9]+)*$`.
- `version`: semver; bump on releases.

## marketplace.json (self-marketplace)

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "loom",
  "description": "loom — spec-driven multi-agent development loop",
  "owner": { "name": "Craig", "email": "craigeous@gmail.com" },
  "plugins": [
    { "name": "loom", "description": "...", "author": { "name": "Craig" },
      "category": "development", "source": "." }
  ]
}
```

> `source: "."` (plugin at the marketplace repo root) is inferred from the
> `./plugins/x` and git-subdir forms seen in the official marketplace; **verify
> the exact root-plugin form against current docs at build (M1).** If unsupported,
> fall back to placing the plugin under `plugins/loom/` with `source:
> "./plugins/loom"`.

## Install flow (for any project)

```
/plugin marketplace add <owner>/loom        # or the git URL
/plugin install loom@loom
```

Then, inside any repo, `/loom` is available and operates on that repo's `.docs/`.

## Model-tier note

Agents and commands pin a model **tier** only (`haiku`/`sonnet`/`opus`/`inherit`);
exact versions resolve in the installer's environment (ADR 0002). loom must behave
correctly regardless of which concrete versions a tier maps to.

## Versioning & releases

- Semver in `plugin.json`; tag releases in git.
- The playbook evolves with loom; a release bundles the current playbook.
- Marketplace entries may pin a `ref`/`sha` for reproducible installs.
