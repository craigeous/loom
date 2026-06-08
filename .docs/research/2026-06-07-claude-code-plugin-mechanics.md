# Research: Claude Code plugin/skill/agent mechanics

Status: Approved
Date: 2026-06-07
Topic: How to package loom as a plugin with role-agents + orchestrator commands,
pin a model per role, bundle the playbook, and distribute via a marketplace.
Resolves open questions Q1, Q2, Q3 (and surfaces a model-pinning constraint).

## Sources

- Anthropic official `plugin-dev` plugin (skills: `plugin-structure`,
  `agent-development`, `command-development`, `skill-development`) at
  `~/.claude/plugins/marketplaces/claude-plugins-official/plugins/plugin-dev/`.
- Anthropic official `feature-dev` plugin (a real multi-agent + orchestrator
  command plugin — loom's closest analog).
- The official `marketplace.json` schema (same marketplace dir).

## Headline: feature-dev is loom's template

`feature-dev` is structurally what loom wants to be: **one orchestrator command
that launches several specialized agents in phases.** Its `commands/feature-dev.md`
runs in the main session and, per phase, "launches 2-3 code-explorer agents in
parallel," reads the files they return, then launches `code-architect` and
`code-reviewer` agents. The agents are `agents/*.md` files. This confirms loom's
architecture (orchestrator command + cold role agents) is exactly how Anthropic's
own multi-agent plugins are built — and that **agents are spawned by the
command/main session, not by other agents** (matches our "orchestrator mediates"
design).

## Plugin structure (definitive)

```
loom/                          # plugin repo root
├── .claude-plugin/
│   ├── plugin.json            # REQUIRED manifest, must live in .claude-plugin/
│   └── marketplace.json       # optional: makes this repo its own marketplace
├── commands/                  # auto-discovered slash commands (the invokable surface)
├── agents/                    # auto-discovered agents (the 5 roles)
├── skills/                    # auto-discovered SKILL.md skills (good home for the playbook)
├── hooks/hooks.json           # optional
├── README.md
└── LICENSE
```

- Default dirs (`commands/`, `agents/`, `skills/`, `hooks/`, `.mcp.json`) are
  auto-discovered; manifest can add extra paths but doesn't need to.
- `${CLAUDE_PLUGIN_ROOT}` resolves to the installed plugin's root at runtime —
  this is how a command/agent references bundled files (e.g. playbook templates):
  `${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/templates/spec.md`.

### plugin.json (manifest)

```json
{
  "name": "loom",
  "version": "0.1.0",
  "description": "Spec-driven dev loop with five blind-reviewed roles ...",
  "author": { "name": "Craig", "email": "craigeous@gmail.com" },
  "homepage": "https://github.com/<owner>/loom",
  "repository": "https://github.com/<owner>/loom",
  "license": "MIT",
  "keywords": ["spec-driven", "agents", "code-review", "workflow", "orchestration"]
}
```

- `name`: kebab-case, unique, `^[a-z][a-z0-9]*(-[a-z0-9]+)*$`.
- All component-path fields are optional when using default dirs.

## Agents (`agents/*.md`) — the five roles

Frontmatter fields (from `agent-development` skill):

| Field        | Required | Values / format                                  |
|--------------|----------|--------------------------------------------------|
| `name`       | yes      | lowercase-hyphens, 3–50 chars                    |
| `description`| yes      | triggering conditions + 2–4 prose scenarios      |
| `model`      | yes      | `inherit` \| `sonnet` \| `opus` \| `haiku`       |
| `color`      | yes      | blue, cyan, green, yellow, magenta, red          |
| `tools`      | no       | array, e.g. `["Read","Grep","Glob"]`; omit = all |

Body = the agent's **system prompt** (second person, ≤10k chars). Auto-discovered
from `agents/`. Namespacing: single dir → `agent-name`; subdirs →
`plugin:subdir:agent-name`.

Mapping for loom (tools = least privilege; see model constraint below):

| Role           | file                 | model  | tools (suggested)                          |
|----------------|----------------------|--------|--------------------------------------------|
| researcher     | `researcher.md`      | haiku  | Read, Grep, Glob, WebSearch, WebFetch + MCP|
| planner        | `planner.md`         | opus   | Read, Write, Edit, Grep, Glob              |
| plan-evaluator | `plan-evaluator.md`  | opus   | Read, Grep, Glob (read-only + write eval)  |
| developer      | `developer.md`       | sonnet | Read, Write, Edit, Grep, Glob, Bash        |
| code-evaluator | `code-evaluator.md`  | opus   | Read, Grep, Glob, Bash (run gate/tests)    |

## ⚠️ Constraint: model pinning is by TIER, not exact version

**The `model` field only accepts `inherit` / `sonnet` / `opus` / `haiku`.** There
is no way in agent or command frontmatter to pin an exact version like
`claude-opus-4-8`. The alias resolves to whatever the user's Claude Code maps the
tier to at runtime. Same constraint applies to the Task/Agent tool's `model`
parameter (enum: sonnet/opus/haiku).

**Implication for loom:** our "planner/evaluator = Opus 4.8, developer =
Sonnet 4.6" decision becomes "planner/evaluator = `opus` tier, developer =
`sonnet` tier, researcher = `haiku` tier." Exact minor versions track the user's
environment. This is fine for the design (we want the strongest/cheapest *tier*
per role) but the spec should stop naming exact versions as if we pin them.

## Commands (`commands/*.md`) — the invokable surface

Frontmatter (from `command-development` skill):

| Field                      | Purpose                                            |
|----------------------------|----------------------------------------------------|
| `description`              | shown in `/help` (<60 chars)                        |
| `argument-hint`            | e.g. `[scope]` / `[topic]` for autocomplete        |
| `allowed-tools`            | restrict tools, supports `Bash(git:*)` filters      |
| `model`                    | `sonnet`/`opus`/`haiku` (tier, same constraint)     |
| `disable-model-invocation` | `true` = only a human typing `/cmd` can run it      |

Body = the prompt; `$ARGUMENTS` (or `$1`,`$2`) substitutes args; `!`...`` runs
inline bash. The orchestrator command body is where the driver-loop logic lives
(feature-dev does exactly this).

Proposed loom commands:
- `commands/loom.md` → `/loom [scope]` — the orchestrator (detect init mode, ask
  scope/approval, run driver loop, spawn role agents via the Task tool).
- One-off per role: either separate files (`commands/loom-research.md` →
  `/loom-research`) or a subdir for namespacing. Exact `/loom research` vs
  `/loom-research` vs `/loom:research` invocation string: decide at build (subdir
  namespacing gives `/loom:research`). `disable-model-invocation: true` is worth
  considering for destructive/owner-gate commands.

### Command vs Skill note

The `command-development` skill carries a note that `.claude/commands/` is a
"legacy format" vs `skills/<name>/SKILL.md`, "both loaded identically." But every
current official multi-agent plugin (feature-dev, code-review) still uses
`commands/` for explicit, argument-taking slash commands, and skills are
*description-triggered* rather than explicitly invoked. **Recommendation:** use
`commands/` for loom's explicit `/loom` surface; optionally add a thin top-level
**skill** so "set up the dev loop / run loom" auto-triggers loom by description.

## Playbook packaging

Ship the playbook **inside the plugin** as a skill: `skills/loom-playbook/` with
`SKILL.md` + `references/` (conventions) + `templates/` (artifact skeletons) +
the toolchain-detection table. Commands/agents read it via
`${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/...`. Improving how we work = editing
these bundled files; updating the installed plugin propagates them. This is the
concrete home for spec/08-playbook's "lives in the loom skill bundle."

## Distribution via marketplace (the user's goal)

A **marketplace** is a git repo with `.claude-plugin/marketplace.json` listing
plugins. Each entry has `name`, `description`, `author`, `category`, `source`.
`source` forms:
- `"./plugins/x"` — plugin is a subdir of the marketplace repo.
- `"."` — plugin is at the marketplace repo root (single-plugin self-marketplace).
- `{ "source": "git-subdir", "url", "path", "ref", "sha" }` — subdir of another repo.
- `{ "source": "github"/"url", "url", "sha" }` — a whole external repo.

Install flow for users:
```
/plugin marketplace add <git-url-or-owner/repo>
/plugin install loom@<marketplace-name>
```

**Recommended for loom:** make the loom repo **its own single-plugin
marketplace** — put both `plugin.json` and a `marketplace.json` (with `source: "."`)
under `.claude-plugin/`. One repo, one `marketplace add`, one `install`. Split into
a separate marketplace repo later only if loom grows into a suite.

> Verify the exact `source: "."` root-plugin form and the precise `/plugin`
> install commands against current docs when we build M1 (local examples confirm
> `./plugins/x` and git-subdir/url; root `"."` is inferred and should be
> double-checked).

## Net effect on open questions

- **Q1 (skill layout):** loom is a **plugin**: `commands/` (orchestrator + one-offs)
  + `agents/` (5 roles) + `skills/loom-playbook/` (playbook). Distributed as its
  own single-plugin marketplace.
- **Q2 (agent definitions):** `agents/*.md` with frontmatter; orchestrator command
  spawns them via the Task/Agent tool. No peer-to-peer (confirmed by feature-dev).
- **Q3 (model pinning):** by tier alias only (`opus`/`sonnet`/`haiku`/`inherit`) —
  **cannot pin exact versions.** Update the spec to talk in tiers.
- **New:** packaging deserves its own spec section; add the model-tier constraint
  as a decision/ADR.
