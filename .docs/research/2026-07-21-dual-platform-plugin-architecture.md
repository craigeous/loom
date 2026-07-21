# Research: Dual-platform plugin architecture

Status: Research Review
Date: 2026-07-21
Topic: Portability boundaries for executing the repository improvement program while supporting both Claude Code and Codex from one Loom codebase.

## Summary

- A shared-core Loom distribution is feasible, but the portable unit is the Agent
  Skills/playbook content plus repository-owned helpers and protocols, not one
  client-identical plugin manifest or invocation surface. Claude and Codex both
  consume `SKILL.md` workflows and plugin-bundled hooks, while their manifests,
  marketplaces, command UX, and custom-agent formats differ. [2][3][7][10]
- The current plugin is Claude-shaped: it has only a Claude manifest and
  marketplace, flat Claude commands, Markdown plugin agents, Claude-specific
  root-variable references, a Claude-only managed-project instruction file, and
  a helper whose bare-command availability relies on Claude's `bin/` behavior.
  [1][2][13]
- Dual-platform work must begin with an ADR and spec amendment before M0 rather
  than waiting for M7 packaging cleanup. The approved architecture, role,
  orchestrator, command-surface, playbook, and packaging specs currently define
  Claude-specific contracts that M0, M3, M4, M6, and M7 would otherwise implement
  against. [1][13]
- The most immediate behavioral incompatibility is Loom's current `PreCompact`
  implementation versus both clients: Claude and Codex now send `trigger`, but
  the hook still reads `compaction_trigger`, so it treats every current manual
  event as `auto` and bypasses Loom's manual no-progress block. Blocking output
  also needs a client adapter: Claude documents exit 2 or `decision: "block"`,
  while Codex documents `continue: false` for `PreCompact`. [2][4][8]

## Findings

### 1. Packaging and marketplace boundary

Claude discovers plugin metadata at `.claude-plugin/plugin.json`; its default
plugin roots include `skills/`, `commands/`, `agents/`, `hooks/`, and `bin/`, and
its marketplace is `.claude-plugin/marketplace.json`. Claude's validator checks
the manifest, marketplace, skill/agent/command frontmatter, and hook schema.
[7][11]

Codex requires `.codex-plugin/plugin.json`. Its documented plugin components are
skills, hooks, apps/connectors, MCP configuration, and assets; its repo marketplace
is `.agents/plugins/marketplace.json`. The desktop app can also read a
legacy-compatible `.claude-plugin/marketplace.json`, but that does not remove the
required Codex plugin manifest. [3]

The evidence therefore supports one physical plugin root containing shared
`skills/`, `hooks/`, helpers, templates, and protocol files, with separate
`.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` adapters. Whether one
marketplace catalog can satisfy both schemas should be treated as unverified;
separate catalogs avoid coupling until an install test proves a combined file.
[2][3][7][11]

Codex plugins are documented for the ChatGPT desktop app and Codex CLI, but not
the Codex IDE extension; standalone/repository skills are available in the IDE.
“Codex support” therefore needs an explicit surface contract, likely distinguishing
the installable plugin on CLI/desktop from a repository-skill fallback in the IDE.
[14][15]

### 2. Commands versus skills

Claude has merged custom commands into skills: legacy flat `commands/*.md` still
create `/name` shortcuts, while new shared workflows are expected to use
`skills/<name>/SKILL.md`. Claude skills follow the Agent Skills standard and can
load supporting files progressively. [10]

Codex documents skills as its authoring format for reusable workflows. Installed
skills are invoked implicitly by description or explicitly with a `$` mention or
skill picker; the Codex plugin and skill documentation does not promise
Claude-style `/loom:<command>` names. [3][15]

Loom's eight flat command files should consequently be regarded as Claude adapters,
not the shared workflow source. A portable layout would place the real workflows
in Agent Skills-compatible directories (for example, distinct run, research,
plan, evaluate, develop, status, and init skills) and keep any Claude slash-command
files thin. Codex documentation and examples would use Codex-native skill
invocation rather than claim slash-command parity. [2][3][10][15]

### 3. Roles, subagents, and orchestration

Claude plugin agents are Markdown files under `agents/` with YAML frontmatter and
are namespaced by the plugin. Since Claude Code 2.1.172, a subagent can spawn
nested subagents; nesting has a fixed maximum depth of five, and the `Agent` tool
is inherited when a definition does not restrict it. A role can disable nesting
by omitting `Agent` from an explicit `tools` allowlist. Every current Loom role
uses such an allowlist without `Agent`, so Loom's plugin roles cannot currently
spawn subagents even though the installed Claude Code 2.1.216 supports it.
[2][7][9][12]

Codex can delegate when a prompt, `AGENTS.md`, or a skill requests subagents.
Its reusable custom agents are standalone TOML files under user
`~/.codex/agents/` or project `.codex/agents/`, and the documentation warns that
the format may evolve. Codex plugin manifests do not currently list custom-agent
files as a packaged component. Codex supports configurable nesting, but
`agents.max_depth` defaults to 1: the root can spawn direct children and those
children cannot spawn descendants unless the setting is raised. [3][5]

The shared role source should therefore be the role behavior/rubric and bounded
handoff contract, with client adapters for launch and model configuration. Claude
can continue loading native plugin agents. For Codex, two documented mechanisms
are available for an ADR to choose between: an orchestrator skill can delegate
generic subagents with the shared role prompt, or Loom can install/generate
project-scoped `.codex/agents/*.toml` and invoke those profiles. The second option
mutates the managed repository and inherits an evolving format. [2][5][7]

The clients do not share a one-level platform default: current Claude permits
nesting through depth five, while Codex defaults to one level and can be
configured deeper. Loom's current hub-and-spoke rule—only the main orchestrator
launches cold roles—remains a valid portable core invariant, but it must be
enforced as Loom policy rather than inferred from the platforms. A preserving
adapter would keep `Agent` out of each Claude role allowlist and keep Codex at
`agents.max_depth = 1`, with tests that child roles cannot delegate. If Loom later
adopts nested delegation, the adapters must instead grant Claude roles `Agent`
and raise Codex's depth explicitly; the hierarchy and cost implications would
then be a new architecture decision. [2][5][9][13]

Model tiers are not portable identifiers. Claude role files select
`haiku`/`sonnet`/`opus`, while Codex custom agents select a model plus
`model_reasoning_effort`; shared role policy should express capability/cost intent,
with separate client mappings and minimum-version tests. [2][5][9][13]

### 4. `CLAUDE.md` versus `AGENTS.md`

Claude-managed projects currently receive and maintain a curated `CLAUDE.md`, and
the approved playbook makes that filename part of initialization and finalize
semantics. [2][13]

Codex reads `AGENTS.md` from global and project scopes, walking from repository
root toward the current working directory, with nearer files taking precedence;
`CLAUDE.md` is not a default Codex instruction filename. [6]

Dual support therefore requires Loom initialization/finalization to produce and
validate both client-facing instruction artifacts, or to generate both from one
canonical digest. Copying the same prose independently would create a new drift
surface, so the documentation validator should check semantic/source parity and
the specs should name the canonical source and conflict rule. [1][6][13]

### 5. Hook portability and enforcement semantics

Both clients support plugin `PreToolUse` and `PreCompact`, consume JSON on stdin,
and provide common fields including `session_id`, `transcript_path`, `cwd`, and
`hook_event_name`. For `PreCompact`, both use `trigger` with `manual` or `auto`;
Claude additionally supplies `custom_instructions`, while Codex supplies a
Codex-specific `turn_id` (and its common input includes a Codex-specific `model`).
Codex exposes plugin-root and data variables and also supplies
`CLAUDE_PLUGIN_ROOT` and `CLAUDE_PLUGIN_DATA` to plugin hook processes for
compatibility. [4][8]

The identity guard's current `PreToolUse` contract is close to portable: both
clients identify shell calls as `Bash`, pass the command in
`tool_input.command`, and support exit code 2 with a stderr reason to block the
call. The M3 parser and post-command verification work is still required because
both platforms describe hooks as guardrails around supported tool paths, not a
complete security boundary. [2][4][8]

The two clients' current `PreCompact` trigger field is wire-compatible, but Loom's
hook is not: it extracts the obsolete `compaction_trigger`, and its missing-field
fallback converts every current event to `auto`. Consequently, a no-progress
manual compaction from either client is logged and allowed instead of taking the
intended manual block path. Output remains client-specific. Claude documents exit
2 with stderr or JSON `{"decision":"block"}` to block compaction; Codex's
`PreCompact` section documents JSON
`{"continue":false,"stopReason":"..."}`. The existing hook only uses Claude's
exit-2 path. A shared policy implementation therefore needs the common `trigger`
parser plus client-correct output adapters, with contract tests that feed each
client's exact event fixture and assert its documented block result. [2][4][8]

Codex also requires explicit trust review for new or changed non-managed/plugin
hooks and skips them until trusted. Installation and doctor documentation must not
equate “plugin installed” with “hook enforcement active.” [4]

### 6. Binaries and helper resolution

Claude explicitly adds executable files in a plugin's `bin/` directory to the
Bash tool `PATH`, which supports Loom's current bare `loom-coord` instructions.
[7]

Codex's documented plugin structure and manifest fields omit a `bin/` component
and make no promise that plugin executables are added to `PATH`; its documented
plugin-root environment variables apply to hook commands. Portable workflow text
must not assume bare-command resolution until a Codex install smoke test proves
it. The safe design space is an explicit plugin-relative helper invocation, a
small hook/skill wrapper, or separately installed executable, chosen by ADR.
[3][4]

The coordinator, landing helper, review helper, and doctor should remain
client-neutral executables with stable CLI/schema contracts. Only their discovery
and invocation should vary by client, so M1/M2/M4 safety tests can run without an
LLM client. [1][2]

### 7. Validation, installation, tests, and CI

Claude provides `claude plugin validate --strict` plus marketplace add/install
commands. The installed Codex CLI provides marketplace add/list/upgrade/remove and
plugin add/list/remove, but no `codex plugin validate` subcommand. Codex's authoring
guide instead emphasizes the required manifest, marketplace wiring, installation,
and testing in a new session. [3][11][12]

M0 should therefore add separate checks: Claude strict validation and install
smoke; JSON/schema/path validation for the Codex manifest/catalog; an isolated
Codex marketplace add + plugin add/list smoke; skill discovery; hook trust and
event-fixture tests; and functional helper invocation. Client versions and test
surfaces should be pinned independently. [1][3][4][11][12]

CI should keep the protocol/helper suite client-neutral, then layer small
client-adapter matrices over it. This limits expensive end-to-end client runs to
manifest loading, skill invocation, role launch, hook block/compaction behavior,
helper discovery, clean install, and upgrade. The program already requires Ubuntu
and macOS, pinned tools, fresh-clone release tests, and one reproducible local gate;
dual support adds a client dimension to those existing requirements. [1]

## Milestone impact

- **Before M0:** add a dual-platform architecture ADR and amend approved specs 02,
  04, 06, 07, 08, and 10 so that role launching, orchestration, initialization,
  invocation, managed instruction files, root-variable use, and packaging have a
  shared core plus explicit client adapters. Current approved text is
  Claude-specific, so deferring this decision to M7 would make earlier slices
  conform to superseded contracts. [1][13]
- **M0:** expand `ci-baseline` to validate/install both package shapes, document
  both minimum client versions and supported surfaces, and create `PreCompact`
  fixtures with the shared `trigger` field, each client's supplemental fields,
  and each client's documented blocking output. Codex lacks the same validator
  command and its plugin is unavailable in the IDE, so a single “plugin validates”
  check is insufficient. [1][3][4][8][12][14]
- **M1:** keep identifier, lock, and schema-CAS work client-neutral; amend helper
  invocation tests so they do not rely solely on Claude's `bin/` PATH behavior.
  [1][3][7]
- **M2:** keep remote publication and coordinator state client-neutral, but define
  client adapters for orchestrator launch, status wording, and recovery prompts;
  no landing invariant itself depends on Claude or Codex. [1][13]
- **M3:** correct the shared `trigger` parser before implementing the two hook
  slices, add client-specific `PreCompact` block-output adapters, and test Claude
  and Codex input/output and Codex trust behavior separately. [1][2][4][8]
- **M4:** define reviewer roles and findings as shared protocol assets before
  binding their launch to Claude plugin agents or Codex subagents; mechanically
  enforce the chosen hub-and-spoke policy through Claude role tool allowlists and
  Codex depth configuration. Local review must remain network-silent and
  client-independent even when orchestration differs. [1][2][5][7][9][13]
- **M5:** the sanitized workspace and deterministic recorder are already
  client-neutral, but the evaluator launcher, permission/read-only setup, and
  inability of evaluator children to delegate need a per-client adapter test.
  [1][2][5][9][13]
- **M6:** `loom doctor` must report the selected client, client version, manifest
  and marketplace load, skill/role availability, hook trust/enabled state,
  instruction-file parity, and helper resolution rather than requiring both
  clients to be installed for every user. [1][4][6][11][12]
- **M7:** release conformance must cover both manifests/catalogs, clean install,
  upgrade, uninstall, changelog/version agreement, surface limitations, and
  platform-specific invocation examples. [1][3][7][11][14]
- **M8:** benchmark client, process profile, and configured delegation depth as
  separate variables; otherwise platform orchestration/model differences can be
  mistaken for workflow overhead. [1][5][9]

## Risks

- **False portability:** a shared directory can load on both clients while a
  command, role, hook, or helper silently does not. Only behavioral install tests
  close this risk. [3][4][7][11]
- **Hook trust gap:** Codex may skip untrusted plugin hooks, so Loom cannot claim
  identity or compaction enforcement solely from manifest presence. [4]
- **Instruction drift:** independently maintained `CLAUDE.md` and `AGENTS.md`
  can disagree about gates or lifecycle rules unless generated or mechanically
  checked against one canonical digest. [1][6][13]
- **Agent-format churn:** Codex documents custom-agent TOML as evolving, so making
  it the shared role source would increase adapter churn. [5]
- **Surface ambiguity:** “works with Codex” can overstate coverage because Codex
  plugins are not available in the IDE even though skills are. [14][15]
- **Release skew:** Claude and Codex update independently; shared hook behavior and
  manifest fields require separate minimum versions and compatibility fixtures.
  Claude's nested-subagent behavior is itself version-gated, so hierarchy tests
  must also run against each declared minimum. [4][7][8][9][12]

## Sources

[1] `.docs/repository-improvement-plan.md` — program ordering, slice contents,
acceptance criteria, release gate, and current Claude-only checks.

[2] `plugins/loom/{.claude-plugin,commands,agents,skills,hooks,bin}/` — current Loom
package shape, workflow prompts, role definitions, hook implementation, and helper.

[3] https://learn.chatgpt.com/docs/build-plugins — required Codex manifest,
documented components, marketplace locations, legacy catalog compatibility, and
local install flow.

[4] https://learn.chatgpt.com/docs/hooks — Codex hook discovery, trust, environment,
wire fields, blocking/output semantics, and tool coverage.

[5] https://learn.chatgpt.com/docs/agent-configuration/subagents — Codex delegation,
custom-agent locations/schema, default depth, permissions, and supported clients.

[6] https://learn.chatgpt.com/docs/agent-configuration/agents-md — Codex instruction
filename, discovery order, precedence, and size limit.

[7] https://code.claude.com/docs/en/plugins-reference — Claude plugin components,
manifest/path variables, `agents/`, `hooks/`, and `bin/` PATH behavior.

[8] https://code.claude.com/docs/en/hooks — Claude hook stdin fields, exit/JSON
blocking semantics, and `PreToolUse` decision contract.

[9] https://code.claude.com/docs/en/sub-agents — Claude agent format, namespace,
cold context, model/tool controls, nested-subagent support since 2.1.172, fixed
depth-five limit, and tool-based nesting restriction.

[10] https://code.claude.com/docs/en/slash-commands — Claude skills, Agent Skills
standard, invocation, and legacy command compatibility.

[11] https://code.claude.com/docs/en/plugin-marketplaces — Claude marketplace,
strict validation, install test, and version-resolution behavior.

[12] Exact local queries on 2026-07-21: `codex --version`,
`codex plugin --help`, `codex plugin marketplace --help`,
`codex plugin add --help`, `codex plugin list --help`, `claude --version`,
`claude plugin --help`, and `claude plugin validate --help` — installed client
versions and currently exposed validation/install commands.

[13] `.docs/spec/{02-roles,04-orchestrator,06-init-modes,07-command-surface,08-playbook,10-packaging}.md`
and `.docs/ADR/{0001-plugin-architecture-and-orchestrator,0006-distribution-self-marketplace,0007-namespaced-command-surface}.md`
— approved Claude-specific architecture and documentation contracts.

[14] https://learn.chatgpt.com/docs/plugins — Codex plugin availability by client
surface and plugin browser/install behavior.

[15] https://learn.chatgpt.com/docs/build-skills — Codex skill availability,
explicit/implicit invocation, progressive disclosure, and plugin packaging.

## Open questions

- Which Codex surfaces are release-blocking: CLI and desktop only, or must the IDE
  work through a repository-skill fallback despite lacking plugin installation?
- Should Codex roles use generic subagent delegation with prompts from shared role
  references, or should Loom generate `.codex/agents/*.toml` into managed repos?
- Can one combined `.claude-plugin/marketplace.json` meet both current marketplace
  schemas without losing strict validation, or should the repository ship separate
  Claude and Codex catalogs?
- Does the supported Codex version add plugin `bin/` to shell `PATH` despite the
  absence of that promise in current documentation? Until tested, Loom should not
  rely on it.
- Should one shared hook policy use thin per-client output wrappers, or can a
  documented and tested platform discriminator select Claude's block output versus
  Codex's without coupling the core policy to incidental wire fields?
- What exact minimum Claude Code and Codex versions first support every selected
  manifest, hook, marketplace, and subagent feature?
