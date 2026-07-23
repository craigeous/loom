# 07 — Client Invocation Surface

Status: Approved

## Authority

ADRs [0007](../ADR/0007-namespaced-command-surface.md) and
[0018](../ADR/0018-shared-core-and-client-adapters.md).

The canonical surface is eight workflow intents backed by shared skills. Invocation
syntax is adapter-specific and behaviorally equivalent, not textually identical.

## Explicit intent mapping

| Intent | Shared workflow asset | Claude Code | Codex |
|---|---|---|---|
| Run orchestrator | `loom-run` | `/loom:run` | `$loom-run` |
| Research | `loom-research` | `/loom:research` | `$loom-research` |
| Plan | `loom-plan` | `/loom:plan` | `$loom-plan` |
| Evaluate research/plan | `loom-eval-plan` | `/loom:eval-plan` | `$loom-eval-plan` |
| Develop | `loom-develop` | `/loom:develop` | `$loom-develop` |
| Evaluate code | `loom-eval-code` | `/loom:eval-code` | `$loom-eval-code` |
| Report status | `loom-status` | `/loom:status` | `$loom-status` |
| Initialize/align | `loom-init` | `/loom:init` | `$loom-init` |

Documentation and conformance tests use explicit forms. Codex may also select a skill
implicitly, but implicit selection is convenience and not the tested contract. Claude
has no bare `/loom`; its plugin namespace remains `loom:<name>`. Loom does not
advertise Claude slash commands as Codex syntax.

## Shared workflows and thin adapters

Canonical workflow bodies live under `plugins/loom/skills/loom-*/SKILL.md` and call
shared role/protocol/playbook references. Claude `commands/*.md` files are thin launch
adapters that route the slash command to the matching shared skill. Codex discovers
and invokes the shared skills natively. Duplicating full workflow policy in a command
adapter is a conformance defect.

All eight forms use the same status machine, controlled-input evaluation, local-review
protocol, helper contracts, and bounded returns. A one-off command/skill performs one
cold pass and stops; it does not weaken any required preparation, validation, or
recording step.

## Role launch mapping

Claude launches one of five namespaced native role adapters:
`loom:researcher`, `loom:planner`, `loom:plan-evaluator`, `loom:developer`, or
`loom:code-evaluator`. Codex launches a generic cold subagent loaded with the matching
shared role contract. Neither surface exposes auxiliary finder workers as lifecycle
commands; the orchestrator launches them only within `loom-local-review/v1`.

## Supported surfaces

- Claude Code plugin support is release-tested at the declared CLI floor.
- Codex plugin support is release-tested for Codex CLI. ChatGPT desktop is supported
  only for a release whose embedded Codex plugin API passes the same matrix.
- Codex IDE plugin installation is not a v0.2 supported surface. Repository skills
  may be documented as an unguaranteed fallback and must not be labeled full plugin
  support.

## Private dogfood workflow and role mapping

The ADR 0024 code slice must prove these exact client-native workflow pairs:

| Shared workflow | Claude Code | Codex CLI |
|---|---|---|
| `run` | `/loom:run` | `$loom-run` |
| `research` | `/loom:research` | `$loom-research` |
| `plan` | `/loom:plan` | `$loom-plan` |
| `eval-plan` | `/loom:eval-plan` | `$loom-eval-plan` |
| `develop` | `/loom:develop` | `$loom-develop` |
| `eval-code` | `/loom:eval-code` | `$loom-eval-code` |
| `status` | `/loom:status` | `$loom-status` |
| `init` | `/loom:init` | `$loom-init` |

The role adapter table is exactly:

| Shared role | Claude Code | Codex CLI |
|---|---|---|
| `researcher` | `loom:researcher` | `loom-researcher` |
| `planner` | `loom:planner` | `loom-planner` |
| `plan-evaluator` | `loom:plan-evaluator` | `loom-plan-evaluator` |
| `developer` | `loom:developer` | `loom-developer` |
| `code-evaluator` | `loom:code-evaluator` | `loom-code-evaluator` |

These are intended mappings. Codex behavior is pending until the exact-candidate
dogfood evaluation passes; ChatGPT desktop and Codex IDE are outside this checkpoint.
