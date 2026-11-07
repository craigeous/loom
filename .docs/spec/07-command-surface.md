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

## Host surfaces (Orca, Herdr `hc`)

**Status (ADR 0033 §1).** Orca and Herdr (`hc`) are deferred: the text below is design for a future admission, with no v0.2.0 status or matrix entry.

A **host** runs a role's inner client (`claude` or `codex`) in a persistent terminal;
it is not a model client, plugin root or hook runtime. `loom-launch-role` emits the
inner-client descriptor; a host adapter turns descriptor, worktree and brief into host
commands. Host adapters are thin and add no policy.

Herdr is driven only through the `hc` CLI (herdr-core; observed 0.1.16, with herdr-app
0.1.11, not called by loom). Loom does not call `herdr-app do`, write Herdr config, ship a
Herdr manifest, marketplace or mod, or install hooks through Herdr. The mapping is:

| Loom input | `hc` form |
|---|---|
| role | `--name <role>-<opaque id>` (1–32 chars `a-z 0-9 - _`) |
| inner client, model, effort | the program and flags in the command string; `codex` needs `--no-daemon` |
| worktree | `--cwd <worktree>` |
| `LOOM_ROLE` | `env LOOM_ROLE=<role> <program> …` |
| brief | its own argv token, or `hc wait` then `hc send` |
| readiness / completion | `hc wait` with a timeout, then read the committed artifact |
| end of role | `hc kill` then `hc rm` |

Behaviors identical on every host: cold fresh session (never `--resume`/`--continue`),
only root delegates, no delegation capability, `LOOM_ROLE` set, handoff only through
committed artifacts, bounded return, uniform commit identity. The artifact `Status:`
is the dispatcher; terminal status (OSC 7501) and `hc wait` results are hints, and a
wait timeout is reported as degraded, never as completion.

Role support on `hc` is gated per role and client on owner-run live probes (ADR 0031
§6) and is unsupported until recorded. Codex roles are not supported on `hc`: the
current Codex launch is one-shot and read-only. Evaluator roles are not supported on
`hc` until the blind-review requirement in spec 05 §Host isolation is resolved.


## Supported surfaces

- Claude Code plugin support is release-tested at the declared CLI floor.
- Codex plugin support is release-tested for Codex CLI. ChatGPT desktop is supported
  only for a release whose embedded Codex plugin API passes the same matrix.
- Codex IDE plugin installation is not a v0.2 supported surface. Repository skills
  may be documented as an unguaranteed fallback and must not be labeled full plugin
  support.

## v0.2.0 release conformance workflow and role mapping

The v0.2.0 release conformance run (spec 10, Release conformance evidence; ADR 0032 §3 E4) must
prove these exact client-native workflow pairs for each required pair, Claude Code CLI and Codex CLI:

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

These are the v0.2.0 mappings. Each client's behavior counts as supported only when the
v0.2.0 record verifies for its pair. ChatGPT desktop and Codex IDE are not v0.2.0 surfaces,
and Antigravity, Orca and Herdr (`hc`) have no mapping in v0.2.0.
