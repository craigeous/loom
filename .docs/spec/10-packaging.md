# 10 — Packaging, Compatibility & Release

Status: Approved

## Authority

ADRs [0006](../ADR/0006-distribution-self-marketplace.md),
[0007](../ADR/0007-namespaced-command-surface.md),
[0018](../ADR/0018-shared-core-and-client-adapters.md),
[0019](../ADR/0019-supported-runtime-and-release-contract.md),
[0020](../ADR/0020-remote-publication-is-the-landing-authority.md),
[0021](../ADR/0021-loom-owned-local-review-protocol.md),
[0022](../ADR/0022-controlled-input-independent-evaluation.md),
[0031](../ADR/0031-herdr-as-an-hc-driven-client.md),
[0032](../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md), and
[0033](../ADR/0033-narrow-v0.3-scope-and-retire-macos-checkpoint-tooling.md), informed by the
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
│   ├── adapters/                             # versioned client bindings/matrix
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

- macOS 14+ on Apple silicon (arm64), where the selected harness itself is supported;
- Bash 3.2+, Git 2.34+, jq 1.6+; and
- one supported client at or above the exact tested floor: Claude Code 2.1.216 or
  Codex CLI 0.144.6.

Bash obligation: CI runs one macOS 14 arm64 lane on `/bin/bash` 3.2.57, the floor; Bash 5.x
is required as recorded evidence (`bashRuns.bash5`). Native Windows, PowerShell, Git
Bash/MSYS2, Cygwin, and WSL are unsupported. Documentation may identify an unverified
community path but must not imply release support.

**Release status (ADR 0032 §1, as amended by ADR 0033 §1).** A pair is *supported* in release R only if it is REQUIRED in R's row and R's record verifies.

| Release | Platform | Harness | Status |
|---|---|---|---|
| v0.2.0 | macOS 14+ arm64 | Claude Code CLI | REQUIRED |
| v0.2.0 | macOS 14+ arm64 | Codex CLI | REQUIRED |
| v0.3.0 | macOS 14+ arm64 | the two v0.2.0 pairs | REQUIRED (carried) |
| v0.3.0 | macOS 14+ arm64 | any other harness | absent unless admitted by a per-harness ADR under ADR 0033 §1 |
| v0.4.0 | Ubuntu 22.04, 24.04 x86-64 | fixed by the v0.4.0 planning ADR | not in v0.2.0 or v0.3.0 |
| any | macOS Intel | any | unsupported |

Antigravity, Orca and Herdr (`hc`) are **deferred** (ADR 0033 §1); a pair in no row is unsupported.
An unknown, below-floor, or merely newer-but-untested client is not automatically
supported. Newer versions become supported only after CI or release-candidate
compatibility evidence passes. `loom doctor` blocks supported-mode claims it cannot
substantiate.

## Versioned compatibility and capability mapping

The release-owned matrix is
`plugins/loom/adapters/compatibility/v0.2.0.json`, validated by
`plugins/loom/schemas/loom-compatibility-matrix-v1.schema.json`. It records product
version, matrix schema, exact client floors, supported surfaces, hook-wire fixture
version, installed-root binding version, and the profile map. For v0.2.0 the effective
map is exactly:

| Loom profile | Consumers | Claude selector | Codex `model` | Codex `model_reasoning_effort` |
|---|---|---|---|---|
| Economy | researcher | `haiku` | `gpt-5.6-terra` | `low` |
| Standard | developer; orchestrator | `sonnet` | `gpt-5.6` | `medium` |
| Deep review | planner; plan evaluator; code evaluator | `opus` | `gpt-5.6` | `high` |

The Claude reasoning field is absent because its adapter exposes tier selectors, not a
portable reasoning-effort control. The Codex launcher must set both TOML keys for every
cold role invocation; inheriting a session model or effort is nonconforming. A missing,
unavailable, renamed, or silently substituted selector fails launch and supported-mode
doctor checks. Changing any table value requires a reviewed matrix change, full floor
revalidation, and a product release; roles and shared skills do not carry duplicate
vendor mappings.

Herdr (`hc`) is deferred under ADR 0033 §1 and has no entry in the v0.2.0 matrix. The `herdr`
entries in `v0.3.0.json` (floor `0.1.10`, `herdr-plugin-root/v1`) are stale under ADR 0031 and
ADR 0032 §6 and are corrected only on admission. A host entry never changes the profile map;
model and effort are carried in the inner client's command string.

## Installed-root and helper binding

The matrix binds Claude to `claude-plugin-root/v1`, defined at
`plugins/loom/adapters/roots/claude-plugin-root-v1.json`, and Codex to
`codex-skill-source/v1`, defined at
`plugins/loom/adapters/roots/codex-skill-source-v1.json`.

- **Claude.** The adapter reads the client-injected `CLAUDE_PLUGIN_ROOT`, resolves its
  physical absolute directory, validates the installed Claude manifest name/version,
  and invokes only an allowlisted executable below its `bin/` by absolute path.
- **Codex workflows.** Codex supplies the absolute source path of the selected
  `skills/<skill>/SKILL.md` when it discovers/loads that skill. The adapter passes that
  path to the bootstrap. The bootstrap requires an absolute path ending in the exact
  selected `skills/<skill>/SKILL.md`, resolves the physical skill directory and then
  its `../..` directory as the installed plugin root, and validates that the same
  canonical skill path and `.codex-plugin/plugin.json` name/version exist beneath that
  root. It then canonicalizes `bin/<allowlisted-helper>`, proves the result remains
  directly below `<root>/bin`, requires a regular executable, and invokes that absolute
  path. It does not read `CLAUDE_PLUGIN_ROOT`, `PLUGIN_ROOT`, `CODEX_HOME`, or `PATH`.
- **Codex hooks.** The manifest uses a root-relative `./hooks/hooks.json`; hook commands
  may use Codex's hook-process-only `PLUGIN_ROOT` to invoke the shared hook dispatcher
  absolutely. That environment binding is not reused by skills or workflow helpers.
- **Herdr (deferred, ADR 0033 §1; no v0.2.0 binding).** Herdr has no installed root, manifest, marketplace or hook binding. It is a
  host driven through `hc` (spec 07 §Host surfaces); roles it launches resolve helpers
  through their own client's root above. Herdr does not install, host or intercept hooks;
  Claude Code and Codex hooks keep running in their own plugin systems under the
  existing wires of spec 08.

There is one physical `bin/`, one set of shared skills, and one helper implementation.
Adapters may contain only binding metadata/bootstrap logic; copying helpers or workflow
bodies into client directories is a conformance failure. Any missing source-path
metadata, containment mismatch, manifest/version mismatch, non-executable helper, or
symlink escape fails closed with a root-resolution error.

## Validation matrix

One documented local `scripts/check` reproduces all client-neutral checks and any
locally available adapter checks. CI and release candidates cover:

- JSON/frontmatter/schema, docs/instruction invariants, shell formatting/lint/syntax,
  Bash tests, link checks, and `git diff --check`;
- Claude strict manifest/catalog validation plus isolated marketplace add, install,
  explicit workflow discovery/invocation, five-role launch/non-delegation, hook
  fixtures, effective tier selection, `claude-plugin-root/v1` absolute helper
  resolution, upgrade, and uninstall;
- Codex JSON/schema/path validation plus isolated marketplace add, plugin add/list,
  explicit skill discovery/invocation, generic cold-role launch/non-delegation, hook
  trust and fixtures, exact model/reasoning selection for every profile,
  `codex-skill-source/v1` resolution from every explicit workflow skill, absolute
  helper invocation, upgrade, and uninstall; and
- client-neutral coordination, local-review, isolated-evaluation, recorder, landing,
  doctor, and protocol compatibility suites.

Codex has no assumed equivalent of `claude plugin validate`; schema validation plus a
clean isolated install/behavior smoke is mandatory. Tests inspect the effective child
launch configuration, not only requested values, and negative fixtures prove missing
models, efforts, skill-source paths, manifests, and escaped helpers fail closed. Both
floor versions are tested. Failure in either required adapter blocks release; no silent
minimum-version increase, model fallback, inherited reasoning setting, environment-only
Codex root guess, or bare helper lookup is allowed.

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
- macOS 14 arm64 CI (`/bin/bash` 3.2.57 lane) and each REQUIRED pair's adapter matrix;
- clean install, upgrade, uninstall, and fresh-clone end-to-end tests;
- local-review exact-SHA/network-silent and evaluation isolation/gate-runner/recorder
  conformance;
- remote-direct publication/recovery without local-main contamination or force push;
- `loom doctor` human/JSON output and document/instruction invariants;
- migration notes for existing `.git/loom` state;
- actual MIT `LICENSE`, versioned `CHANGELOG.md`, accurate README limitations and
  support/install/recovery guidance;
- agreement of manifests, catalogs, helpers, schemas, docs, and release metadata;
- proof the `vX.Y.Z` tag resolves to the exact tested commit; and
- a release conformance record that verifies under Release conformance evidence.

No v0.2.0 artifact is published until improvement milestones M0–M7 are green on the
declared matrix and the v0.2.0 record verifies. Build assets derive from that tag and are
never edited afterward. The sanitized evidence archive is an evidence asset, not a build asset.

## Release conformance evidence

A (platform, harness) pair is supported in release R only when the applicable release row
(ADR 0032 §1 for v0.2.0, or an accepted per-harness admission ADR under ADR 0033 §1) lists
it as REQUIRED for R and every element below verifies. ADR 0024 evidence is historical; one
platform's or harness's evidence is not conformance for another.

Per required pair, the record carries:

- **E1 matrix entry:** the harness in `plugins/loom/adapters/compatibility/vR.json` with its
  pinned floor, profile mapping and platform.
- **E2 binding:** `claude-plugin-root/v1` or `codex-skill-source/v1`, plus manifest and
  catalog loading (manifest and marketplace catalog load; name and version match the release).
- **E3 offline conformance:** Bats tests in `scripts/check` on that platform for the launch
  descriptor from `loom-launch-role`, role contract parity across all five roles, the hook/
  guard behavior the harness exposes, and refusal of unknown and below-floor versions.
- **E4 live conformance** at the pinned floor. Each run records platform, harness floor, result
  and log reference (path and `logSha256`): (a) all five roles launched and returned through the
  harness, each with an output hash; (b) one full loop from research through landing, with blind
  review (ADR 0022) and every handoff committed; (c) `scripts/check` passing on the platform; (d)
  in fresh isolated homes, clean install of the candidate; prior-candidate install, then upgrade
  to the candidate; clean uninstall (ADR 0032 §4–§5). `authSource` names how the isolated client
  was authenticated (never a value).
- **E5 owner acknowledgement:** names each pair, the evidence-set hash and the candidate.

Record-level: `bashRuns.bash32` (`/bin/bash` 3.2.57, the CI lane) and `bashRuns.bash5` (full
`scripts/check` under Bash 5.x) must both pass.

**Record.** `.docs/evaluations/release-evidence/vR.json`, schema `loom-release-evidence/v1`
(`plugins/loom/schemas/loom-release-evidence-v1.schema.json`), bound to release 0.2.0 and its two
pairs. Written after the candidate is tagged, so the candidate never contains its own hash.
Published records are never edited.

**Corrections.** `vR.corr<N>.json`, N = 1, 2, … with no gaps. The current record has the highest N
(compared as an integer), or is `vR.json` if none exists. Each carries `supersedes: {path, sha256}`
naming its predecessor, unbroken back to `vR.json`. A correction never changes the candidate.

**Candidate binding.** A record verifies only if (1) `git rev-parse vR^{commit}` equals `candidate`;
(2) `git merge-base --is-ancestor vR <record-commit>` succeeds and the record is on `main`; (3)
`ownerAck.candidate` equals `candidate` and each `priorCandidate` differs from it; (4) each pair's
E1 and E2 entries match the matrix and binding the record names. Items 1–2 are release-time git
checks; items 3–4, shape, naming, the correction chain and log paths are repo validation. Neither
can prove that a run happened.

**Sanitized archive.** Logs are not committed. `loom-release-evidence-<tag>-<candidate>.tar.gz` is
attached before publication and holds only `MANIFEST.sha256` and `logs/<name>.log` files matching
`^logs/(?!.*\.\.)[a-z0-9][a-z0-9._/-]*$`, sanitized before hashing (no credential values, auth file
content, environment dumps; home becomes `~`). `MANIFEST.sha256` is `find logs -type f | LC_ALL=C
sort | xargs shasum -a 256`. Each run's `logSha256` equals its manifest line; `ownerAck.evidenceSet`
equals `shasum -a 256 MANIFEST.sha256`.

Workflow-profile policy and target-branch history shape are deliberately not release
contracts here. They require benchmark evidence and a later accepted decision.
