# 10 — Packaging, Compatibility & Release

Status: Draft

## Authority

ADRs [0006](../ADR/0006-distribution-self-marketplace.md),
[0007](../ADR/0007-namespaced-command-surface.md),
[0018](../ADR/0018-shared-core-and-client-adapters.md), and
[0019](../ADR/0019-supported-runtime-and-release-contract.md), informed by the
[approved dual-platform research](../research/2026-07-21-dual-platform-plugin-architecture.md).

## One distribution, two catalogs

Loom ships from one repository and one physical `plugins/loom/` plugin root. The
shared core is installed once; Claude Code and Codex consume explicit separate
adapter metadata. A combined catalog is not supported in v0.2.

```text
loom/
├── .claude-plugin/marketplace.json          # Claude catalog
├── .agents/plugins/marketplace.json         # Codex catalog
├── plugins/loom/
│   ├── .claude-plugin/plugin.json           # Claude manifest
│   ├── .codex-plugin/plugin.json            # Codex manifest
│   ├── commands/                            # thin Claude /loom:* adapters
│   ├── agents/                              # five thin Claude lifecycle-role adapters
│   ├── skills/
│   │   ├── loom-run/SKILL.md
│   │   ├── loom-research/SKILL.md
│   │   ├── loom-plan/SKILL.md
│   │   ├── loom-eval-plan/SKILL.md
│   │   ├── loom-develop/SKILL.md
│   │   ├── loom-eval-code/SKILL.md
│   │   ├── loom-status/SKILL.md
│   │   ├── loom-init/SKILL.md
│   │   └── loom-playbook/
│   ├── roles/                               # canonical five role contracts
│   ├── reviewers/                           # three auxiliary finder prompts/schemas
│   ├── hooks/                               # shared policy + client wire adapters
│   ├── bin/                                 # Bash client-neutral helpers
│   └── schemas/                             # protocol/manifest/output schemas
├── .docs/                                   # Loom's own development memory; not shipped
├── AGENTS.md                                # Loom's Codex instruction adapter
├── CLAUDE.md                                # Loom's Claude instruction adapter
├── README.md
├── CHANGELOG.md
└── LICENSE
```

The shared workflow/role/reviewer content is canonical. `commands/` and `agents/`
must remain thin and cannot become a divergent second implementation. Codex does not
receive generated project `.codex/agents/*.toml`.

## Manifest and catalog contract

- `plugins/loom/.claude-plugin/plugin.json` validates against the pinned Claude
  schema; `plugins/loom/.codex-plugin/plugin.json` validates against the pinned Codex
  schema.
- Each manifest declares the same product name `loom`, exact SemVer, description,
  license, repository/homepage metadata where supported, and only fields valid for
  that client schema.
- `.claude-plugin/marketplace.json` points its `loom` entry to
  `./plugins/loom` using Claude's schema.
- `.agents/plugins/marketplace.json` points its `loom` entry to the same physical
  plugin root using Codex's schema.
- Catalog entries carry the same product SemVer/release provenance as both manifests.
- Client-only metadata may differ only where its pinned schema requires it. Shared
  name, version, source identity, and release provenance may not drift.
- Unknown fields, wrong catalog location, path escape, duplicate component names, or
  version disagreement fail validation.

Manifest/catalog fixtures are release assets. Schema changes from either client are
absorbed in that adapter and do not alter shared protocol behavior without planning.

## Installation and invocation contracts

Claude Code installation uses the Claude marketplace-add and
`/plugin install loom@loom` flow; successful installation must expose the eight
`/loom:*` forms and exactly five namespaced lifecycle-role adapters.

Codex CLI installation uses its native marketplace-add and `plugin add` flow from
`.agents/plugins/marketplace.json`; successful installation must expose the eight
explicit `$loom-*` skills, load hooks after required trust, resolve helpers, and allow
root-only cold subagent delegation. Exact CLI syntax is pinned in the compatibility
fixture for the supported Codex version rather than copied into shared workflow text.

ChatGPT desktop is supported only when its embedded Codex plugin API passes the same
clean-install and behavioral matrix. Codex IDE plugin installation is outside v0.2
support. Neither client's install success alone proves hooks active or workflows
functional.

Upgrade preserves compatible tracked project state and applies explicit protocol/
coordination migrations. Uninstall removes plugin-owned installed assets without
deleting a project's `.docs/`, owner instruction content, branches, or unresolved
publication evidence. Destructive cleanup requires exact validated targets.

## Supported runtime and platforms

The v0.2 support matrix is:

- Ubuntu 22.04 LTS and 24.04 LTS on x86-64;
- macOS 14+ on Apple silicon and x86-64 where the selected client supports it;
- Bash 3.2+, Git 2.34+, jq 1.6+; and
- one supported client at or above the exact tested floor: Claude Code 2.1.216 or
  Codex CLI 0.144.6.

Tests run Bash 3.2 and current Bash 5.x. Native Windows, PowerShell, Git Bash/MSYS2,
Cygwin, and WSL are unsupported in v0.2. Documentation may identify an unverified
community path but must not imply release support.

An unknown, below-floor, or merely newer-but-untested client is not automatically
supported. Newer versions become supported only after CI or release-candidate
compatibility evidence passes. `loom doctor` blocks supported-mode claims it cannot
substantiate.

## Validation matrix

One documented local `scripts/check` reproduces all client-neutral checks and any
locally available adapter checks. CI and release candidates cover:

- JSON/frontmatter/schema, docs/instruction invariants, shell formatting/lint/syntax,
  Bash tests, link checks, and `git diff --check`;
- Claude strict manifest/catalog validation plus isolated marketplace add, install,
  explicit workflow discovery/invocation, five-role launch/non-delegation, hook
  fixtures, absolute helper resolution, upgrade, and uninstall;
- Codex JSON/schema/path validation plus isolated marketplace add, plugin add/list,
  explicit skill discovery/invocation, generic cold-role launch/non-delegation, hook
  trust and fixtures, absolute helper resolution, upgrade, and uninstall; and
- client-neutral coordination, local-review, isolated-evaluation, recorder, landing,
  doctor, and protocol compatibility suites.

Codex has no assumed equivalent of `claude plugin validate`; schema validation plus a
clean isolated install/behavior smoke is mandatory. Both floor versions are tested.
Failure in either required adapter blocks release; no silent minimum-version increase
or model fallback is allowed.

## SemVer and protocol versions

The authoritative product version is `X.Y.Z` and appears identically in both
manifests, both catalogs/release metadata, helper `--version` output, documentation,
and changelog; Git tag is `vX.Y.Z`. Build SHAs are provenance, not user-facing
versions.

Before 1.0, incompatible product change increments minor, compatible fix increments
patch, and compatible functionality increments minor. The improvement program releases
as `v0.2.0`.

Every persisted schema and interchange protocol has its own explicit version. Readers
reject unknown major/schema versions. Incompatible changes require a new protocol/
schema and migration or cleanup path. Product SemVer and protocol versions are recorded
together but are not numerically coupled.

## Release gate

A release is immutable tested source at a tag, not a manifest edit. From a clean clone
at the proposed tag, all of these must pass:

- the full local check;
- Ubuntu and macOS CI, Bash floor/current lanes, and both required client-floor
  adapter matrices;
- clean install, upgrade, uninstall, and fresh-clone end-to-end tests;
- local-review exact-SHA/network-silent and evaluation isolation/gate-runner/recorder
  conformance;
- remote-direct publication/recovery without local-main contamination or force push;
- `loom doctor` human/JSON output and document/instruction invariants;
- migration notes for existing `.git/loom` state;
- actual MIT `LICENSE`, versioned `CHANGELOG.md`, accurate README limitations and
  support/install/recovery guidance;
- agreement of manifests, catalogs, helpers, schemas, docs, and release metadata; and
- proof the `vX.Y.Z` tag resolves to the exact tested commit.

No v0.2 artifact is published until improvement milestones M0–M7 are green on the
declared matrix. Release assets derive from that tag and are never edited afterward.

Workflow-profile policy and target-branch history shape are deliberately not release
contracts here. They require benchmark evidence and a later accepted decision.
