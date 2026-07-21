# 0018 — Shared Portable Core with Claude Code and Codex Adapters

Status: Accepted
Date: 2026-07-21

## Context

Loom is currently defined and packaged as a Claude Code plugin. ADR
[0001](0001-plugin-architecture-and-orchestrator.md) makes Claude commands and agents
the architecture, ADR [0002](0002-model-selection-by-tier.md) makes Claude's model
tier names portable policy, ADR [0006](0006-distribution-self-marketplace.md) defines
only a Claude marketplace, and ADR [0007](0007-namespaced-command-surface.md) defines
Claude slash commands as Loom's whole invocation surface. Approved specs 02, 04,
06, 07, 08, and 10 carry those assumptions.

The approved [dual-platform architecture research](../research/2026-07-21-dual-platform-plugin-architecture.md)
finds that Claude Code and Codex can share Agent Skills content, protocols, hooks,
and repository-owned helpers, but not manifests, marketplaces, invocation syntax,
custom-agent formats, root-variable assumptions, or model selectors. Deferring this
boundary until packaging work would make earlier improvement-program milestones
implement against contracts already known to be incomplete.

In scope are the shared/adapted boundary, supported client surfaces, workflow and
role invocation, hierarchy, model-policy mapping, helper discovery, hooks, and
managed-project instruction files. Exact manifest schemas, prompt bodies, model IDs,
minimum client versions, and release testing belong to follow-on specs and the
runtime/release contract in ADR 0019. This ADR does not change Loom's five roles,
artifact lifecycle, or mediated handoff model.

## Decision

### 1. One physical distribution has a client-neutral core and two explicit adapters

Loom SHALL ship one physical `plugins/loom/` distribution. Its canonical shared core
is the Agent Skills-compatible workflow content, five role contracts and rubrics,
templates, protocols, hooks' policy logic, and repository-owned helpers. Core
behavior SHALL use Loom terms such as “delegate a cold planner” and “invoke the
plugin helper”; it SHALL NOT make Claude command names, Claude agent files, Codex
agent TOML, a client-specific plugin-root variable, or implicit `PATH` behavior the
source of truth.

Two adapters SHALL bind that core:

- **Claude Code:** `.claude-plugin/plugin.json`, the root Claude marketplace,
  thin `/loom:<name>` command adapters, `agents/*.md` launch adapters, Claude hook
  response encoding, and `CLAUDE_PLUGIN_ROOT` resolution.
- **Codex:** `.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json`,
  skill-native entry points, generic cold-subagent delegation loaded with the shared
  role contract, Codex hook response encoding, and Codex's documented plugin-root
  resolution.

The catalogs remain separate. A combined catalog is not a supported shortcut unless
a later decision is backed by strict validation and clean-install tests on both
clients. Every helper invocation SHALL resolve the installed plugin root through the
active adapter and use an explicit absolute path. Bare helper names are user-facing
convenience only, never a portable correctness dependency.

### 2. Invocation is behaviorally equivalent, not textually identical

The canonical intents and adapter mappings are:

| Intent | Claude Code adapter | Codex adapter |
|---|---|---|
| Run orchestrator | `/loom:run` | `$loom-run` skill |
| Research | `/loom:research` | `$loom-research` skill |
| Plan | `/loom:plan` | `$loom-plan` skill |
| Evaluate plan/research | `/loom:eval-plan` | `$loom-eval-plan` skill |
| Develop | `/loom:develop` | `$loom-develop` skill |
| Evaluate code | `/loom:eval-code` | `$loom-eval-code` skill |
| Report status | `/loom:status` | `$loom-status` skill |
| Initialize/align | `/loom:init` | `$loom-init` skill |

Implicit Codex skill selection MAY be supported, but documentation and conformance
tests SHALL use the explicit `$loom-*` form. Loom SHALL not advertise Claude slash
commands in Codex or promise syntax parity where the clients provide different UX.

Claude Code plugin installation is supported on Claude Code. Codex plugin
installation is supported on Codex CLI and the ChatGPT desktop Codex surface. The
Codex IDE extension, for which plugin installation is not documented, is not a
release-blocking supported plugin surface. Repository-installed skills may work there
as a documented fallback, but that fallback SHALL not be called full Loom plugin
support and receives no release guarantee until the platform exposes and Loom tests
the required plugin facilities.

### 3. Role contracts are shared; launch files and model selectors are adapters

There remain exactly five logical roles: researcher, planner, plan evaluator,
developer, and code evaluator. Each canonical role contract SHALL state its reads,
writes, authority, tools/capabilities, bounded return, and prohibition on delegation.
Claude `agents/*.md` files SHALL be thin launch adapters for those contracts. Codex
SHALL use the orchestrator skill to launch a generic cold subagent with the selected
shared role contract; Loom SHALL NOT generate or install project-scoped
`.codex/agents/*.toml`, because that would mutate managed repositories and bind the
core to an evolving platform format.

The hub-and-spoke invariant is Loom policy: only the top-level orchestrator delegates;
role agents never delegate. The Claude adapter enforces it by excluding `Agent` from
role tool allowlists. The Codex adapter enforces it with one-level delegation and
child permissions that omit delegation. Adapter tests SHALL prove that a role child
cannot launch a descendant. A future nested-role design requires a new ADR.

Model policy is expressed as three logical capability profiles:

| Loom profile | Roles |
|---|---|
| Economy | researcher |
| Standard | developer, orchestrator |
| Deep review | planner, plan evaluator, code evaluator |

The Claude mapping remains `haiku`, `sonnet`, and `opus`, respectively. The Codex
adapter maps each profile to a tested model plus reasoning-effort setting in its
versioned compatibility matrix. Exact Codex model IDs are adapter/release data, not
shared role policy. A release SHALL fail conformance if either client cannot satisfy a
profile; it SHALL not silently fall back to an untested model.

### 4. Shared hook policy has client-specific event and response adapters

Hook policy and state transitions are shared, while each client adapter owns input
normalization and blocking output. In particular, both current clients' `PreCompact`
events normalize the `trigger` field (`manual` or `auto`); the obsolete
`compaction_trigger` field is not part of the shared contract. Claude emits Claude's
documented block result and Codex emits Codex's documented `continue: false` result.
Exact event fixtures and outputs SHALL be contract-tested for both adapters.

Installation does not prove enforcement. The Codex adapter and `loom doctor` SHALL
surface whether hooks are trusted and active; Loom SHALL not claim a guard is enforced
when the client skipped it. `PreToolUse` remains defense in depth rather than a full
shell security boundary on either client.

### 5. One canonical managed-project digest feeds both instruction files

Loom-managed project guidance SHALL have one client-neutral, tracked canonical digest
at `.docs/status/project-instructions.md`; a later spec amendment fixes its schema.
Initialization and finalization render the Loom-owned block from that digest into both
root `CLAUDE.md` and root `AGENTS.md`, preserving owner-controlled content outside
marked blocks. Neither client file is authoritative over the other. Generated blocks
carry the canonical digest hash, and validation/`loom doctor` fail on a missing file,
mismatched hash, semantic conflict, or manually diverged Loom-owned block. This is the
zero-drift rule; editing two independent copies is forbidden.

## Consequences

- **Partially supersedes ADR 0001.** Its mediated hub-and-spoke orchestrator and five
  roles stand. Its definition of Loom as only a Claude plugin comprising Claude
  `commands/` and `agents/`, and its claim that the main session uses Claude's Task
  tool by architectural necessity, are replaced by the shared core plus client
  adapters and the client-neutral “top-level orchestrator delegates” rule.
- **Partially supersedes ADR 0002.** Its Claude tier mapping remains the Claude
  adapter mapping. Its claim that `haiku`/`sonnet`/`opus` are the portable role policy
  and resolve only in the installer's environment is replaced by Loom capability
  profiles plus separately tested client mappings.
- **Partially supersedes ADR 0006.** The single repository and
  `plugins/loom/` source layout stand. “Single-plugin self-marketplace” now means one
  Loom product with separate Claude and Codex catalogs/manifests; the Claude-only
  catalog and install flow are no longer the whole distribution contract.
- **Partially supersedes ADR 0007.** Its `/loom:<name>` and `loom:<role>` names remain
  the Claude adapter surface and the prohibition on bare `/loom` still applies there.
  They are no longer Loom's cross-client surface; Codex uses `$loom-*` skills and
  generic cold-role delegation.
- Specs 00, 01, 02, 03, 04, 06, 07, 08, and 10 require a later planner-authored
  amendment where affected. That pass must define the canonical digest schema and exact
  adapter file layout. No spec or product file changes in this decision pass.
- Platform divergence becomes explicit testable adapter work. False parity, generated
  Codex agent files, implicit helper `PATH` assumptions, independently edited
  `CLAUDE.md`/`AGENTS.md`, and claims of Codex IDE plugin support are foreclosed.
