# 08 — Shared Playbook, Instructions, Hooks, and Helpers

Status: Plan Review

## Authority

ADRs [0003](../ADR/0003-cold-handoffs-commit-per-handoff.md),
[0005](../ADR/0005-specs-frozen-after-approval.md),
[0013](../ADR/0013-starvation-loop-guards-cold-restart.md),
[0018](../ADR/0018-shared-core-and-client-adapters.md),
[0019](../ADR/0019-supported-runtime-and-release-contract.md),
[0020](../ADR/0020-remote-publication-is-the-landing-authority.md),
[0021](../ADR/0021-loom-owned-local-review-protocol.md), and
[0022](../ADR/0022-controlled-input-independent-evaluation.md).

## Portable core

The playbook is Loom's client-neutral source of conventions and reusable workflow
assets. It ships inside the plugin and is not copied wholesale into managed projects.
It includes:

- `.docs/` layout, artifact templates, status machine, rubrics, and severity policy;
- canonical lifecycle role contracts and auxiliary finder prompts;
- Agent Skills-compatible workflow bodies;
- local-review, evaluation-export, gate-runner, recorder, coordination, landing, and
  doctor protocol contracts;
- hook policy logic independent of wire response format;
- supported gate definitions and gate-learning policy; and
- the canonical project-instructions schema and renderer.

Client command names, native agent frontmatter, Codex launch configuration, vendor
model selectors, catalog/manifest schemas, hook blocking output, plugin-root variables,
and implicit `PATH` behavior are adapter concerns, not shared policy.

## Canonical project instruction digest

Every managed project tracks `.docs/status/project-instructions.md` with this exact
top-level sequence:

| Element | Required value/content |
|---|---|
| H1 | `Project Instructions` |
| `Status` field | `Living` |
| `Schema` field | `loom-project-instructions/v1` |
| H2 1 | `Read first`: ordered repository-relative pointers |
| H2 2 | `Core invariants`: concise client-neutral rules already authorized by specs/playbook |
| H2 3 | `Gate`: state, ordered commands, environment/tool references |
| H2 4 | `Repository map`: stable layout facts and concise pointers |
| H2 5 | `Reference index`: one-clause links to detailed authority |

Required headings and fields appear exactly once and in that order. Paths are
repository-relative and links resolve. Content uses no client invocation syntax or
client-specific root variable. Per-slice history, milestone narration, model-specific
instructions, secrets, and duplicated reference bodies are forbidden.

The digest hash is lowercase SHA-256 of the file's exact UTF-8 bytes after normalizing
line endings to LF and requiring one trailing LF. The hash is not stored inside the
canonical file, avoiding self-reference.

## `CLAUDE.md` and `AGENTS.md` adapters

Initialization and candidate finalization render a Loom-owned block into both root
files while preserving all owner-controlled content outside the block:

```text
<!-- loom:project-instructions begin schema=loom-project-instructions/v1 sha256=<64-hex> -->
<deterministic client-facing rendering of the canonical digest>
<!-- loom:project-instructions end -->
```

There is exactly one Loom-owned block per file. Rendering may adapt invocation and
root-resolution examples for the target client but must preserve the canonical
sections' meaning. Renderer fixtures define the only permitted client-specific
differences. Validation recomputes the canonical hash, renders both blocks, and
requires byte-for-byte equality with expected output. Missing files, duplicate blocks,
wrong hashes, semantic conflict, or manual block edits are errors.

Neither derived file is authority over the canonical digest or frozen specs. A digest
change occurs only when authorized durable conventions, repository layout, gate, or
read-first/reference pointers change. Per-slice history remains in `progress.md`.

Both adapters remain lean maps: point to detailed authority instead of restating it.
The Loom repository's derived root files target 80–100 lines; managed-project files
must remain under roughly 200 lines unless owner content outside Loom's block alone
exceeds that bound. The renderer never deletes owner content to satisfy a Loom-block
size check.

## Gate policy

The gate is format → lint → test and must be runnable by both the developer and the
isolated evaluator runner. Rust's verified definition is:

| Step | Command |
|---|---|
| format | `cargo fmt --check` |
| lint | `cargo clippy --all-targets -- -D warnings` |
| test | `cargo test` |

Unknown stacks use inspect → propose → owner-confirm → run-green-once → record. Gate
definitions include pinned/reproducible tools, environment, and offline dependency
preparation required for evaluator reruns. `UNVERIFIED` gates cannot authorize
`Implemented`.

## Bash and helper contracts

All shipped executables use `#!/usr/bin/env bash`, support Bash 3.2+, and avoid newer
features until the runtime floor changes through planning. Production helpers require
Git 2.34+ and jq 1.6+; JSON parsing/emission has no regex fallback. Bats, ShellCheck,
shfmt, and schema/link validators are pinned build/test dependencies.

Shared helpers include coordination, review, evaluation export/evidence collection,
gate execution, verdict recording, landing/publication, and doctor. Their CLI/schema
behavior is client-neutral. Every workflow resolves the active installed plugin root
through its adapter and invokes helpers by explicit absolute path. Bare helper names
may be documented as Claude convenience but are never correctness dependencies.

Persisted states and interchange protocols carry explicit versions. Readers reject an
unknown major/schema version and provide migration or cleanup guidance; they never
best-effort reinterpret it.

## Hook normalization and output adapters

Hook policy receives a normalized internal event. Both clients' current `PreCompact`
adapters read `trigger` with the only accepted values `manual` and `auto`; the obsolete
`compaction_trigger` field is not recognized as current input. Client-only supplemental
fields may be recorded in adapter fixtures but cannot alter shared state transitions.

The only supported `PreToolUse` target is the shell tool named `Bash`, with a string at
`tool_input.command`. A policy block produces one UTF-8, control-character-free,
single-line reason of at most 512 bytes. Adapters emit exactly these command-hook wire
results; `<reason-json>` means that same reason encoded as a JSON string value:

| Client/event | Policy allows | Policy blocks |
|---|---|---|
| Claude `PreToolUse` | exit 0; empty stdout and stderr | exit 2; empty stdout; stderr `<reason>\n` |
| Claude `PreCompact` | exit 0; empty stdout and stderr | exit 2; empty stdout; stderr `<reason>\n` |
| Codex `PreToolUse` | exit 0; empty stdout and stderr | exit 0; stderr empty; stdout `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":<reason-json>}}\n` |
| Codex `PreCompact` | exit 0; empty stdout and stderr | exit 0; stderr empty; stdout `{"continue":false,"stopReason":<reason-json>}\n` |

No adapter may substitute another documented encoding. In particular, Claude does not
emit block JSON, Codex `PreToolUse` does not use the older top-level
`decision: "block"` shape or `continue: false`, and Codex `PreCompact` does not use
exit 2. Missing/wrong-typed required fields, an unknown `trigger`, invalid JSON, or a
reason that violates the bound fails closed through the same client/event block result;
the fixed reason is `Loom hook input invalid for <event>.` or
`Loom hook policy returned an invalid reason.` as applicable.

The versioned fixtures are
`plugins/loom/hooks/fixtures/hook-wire-v1/<client>/<event>/<case>.{input.json,stdout,stderr,exit}`
and validate against
`plugins/loom/schemas/loom-hook-wire-fixture-v1.schema.json`. The `.stdout` and
`.stderr` files are exact bytes, including the one required trailing LF for nonempty
output; `.exit` contains the decimal status plus LF. The only path values are clients
`claude` and `codex`, events `pre-tool-use` and `pre-compact`, and cases `allow`,
`block`, and `malformed`. Conformance runs the same policy outcome through both
adapters and byte-compares all three outputs.

Identity policy fails closed on recognized mutation tokens and a post-command verifier
detects any advanced HEAD with wrong author/committer identity. This is defense in
depth, not a complete shell parser or security boundary.

PreCompact write-ahead state is per validated session under
`.git/loom/precompact/<session-id>/`, atomic, concurrency-safe, and bound to actual
checkpoint advancement. Logs are bounded and injection-safe. One session's checkpoint
never authorizes another's manual compaction.

Hook installation is not proof of enforcement. Codex trust/activation and Claude hook
loading are checked separately; `loom doctor` reports inactive/skipped hooks as errors
for supported mode. Exact current-event fixtures and blocking outputs are contract-
tested at each minimum client version.

## `loom-local-review/v1`

`loom-review prepare|validate|assemble|status|clean` operates on exact full
`base_sha` and `head_sha`, with no network or remote dependency. The canonical JSON
manifest and finder results use UTF-8 and stable key ordering for hashing. The manifest
contains at least: `protocol`, unique `run_id`, slice ID, product/helper version; exact
`base_sha`, `head_sha`, head tree, canonical diff SHA-256, and changed-path inventory
with add/delete/rename/mode/binary metadata; approved plan, relevant authority, and
gate-evidence paths/hashes; required finder IDs, prompt versions/content hashes,
expected output paths, and adapter/model provenance; source-export manifest/hash,
creation time, and canonical manifest hash.

Each finder result repeats protocol, run/manifest hash, finder and prompt identity,
exact base/head/diff identity, one legal finder state, execution provenance, and its
finding list. Each finding has a run-stable ID, finder ID, confidence, proposed
severity, changed file and line/range, claim, concrete evidence, and suggested
verification/reproduction. The primary location must intersect the reviewed diff;
unchanged context may support but cannot solely locate a finding.

Required finders are `review-correctness/v1`, `review-tests/v1`, and
`review-security/v1`. Prompt major names are immutable; meaningful prompt changes
create a new version and all changes record a content hash. Protocol/schema validity,
isolation, and failure handling are deterministic release gates. Detection rate and
cost are benchmark evidence, not brittle exact-wording CI assertions.

## Evaluation utilities

Exporter, cited-source collector, gate runner, and recorder are deterministic shared
helpers with versioned schemas. They implement spec 05's allowlist, hashing,
permissions, exact-revision evidence, unconditional private-copy gate rerun, output
confinement, and recording contract. Adapter launch code never duplicates or weakens
those policies.

## Mechanical invariants

The local `scripts/check` entry point and CI validate at least:

- JSON/frontmatter/schema validity and both manifests/catalogs;
- allowed statuses/transitions, round counters, artifact naming, authority headings,
  one active plan per slice, archive status, and relative links;
- living-doc ownership/shape (`handoff` current state, `progress` history, `roadmap`
  future milestones) and README status agreement;
- canonical-digest schema/hash and both instruction renderings;
- Bash syntax at the floor, shfmt, ShellCheck, Bats, and Git diff whitespace;
- every `hook-wire-v1` allow/block/malformed fixture with byte-exact exit, stdout,
  and stderr results for both clients and both supported events;
- local-review/evaluation/recorder protocol fixtures and failure cases; and
- active client adapter install, invocation, role hierarchy, helper resolution, and
  uninstall/upgrade matrix where applicable.

`loom doctor` exposes equivalent environment/repository checks in human and stable
`--json` forms, including selected client/version, supported host/runtime, manifest/
catalog load, skill/role availability, model-profile mapping, hook trust/activity,
instruction parity, helper/dependency resolution, Git identity/cleanliness,
initialization mode, coordination schema/stale claims, review/evaluation capability,
remote landing configuration, and optional OS egress-sandbox status.

## Evolution boundary

Playbook changes are planned, independently evaluated, and released atomically with
both adapters. Workflow-profile selection and target-branch history shape are not
defined here; they remain evidence-dependent future decisions.
### Private dogfood hook and helper evidence

Both client fixtures carry the same normalized event input, including required
`trigger`, for `PreToolUse` and `PreCompact`. Claude and Codex output adapters may use
client-native blocking envelopes, but evidence must prove the same shared allow/block
decision. Codex hook trust and activation are recorded honestly; unavailable or
untrusted activation is not relabeled as success.

Helper execution resolves an absolute physical installed root, proves root/manifest
containment, and invokes the helper from that root. Codex uses the exact skill-source
ascent contract. Shared correctness never depends on bare `PATH`, `CODEX_HOME`,
`CLAUDE_PLUGIN_ROOT`, or another client-only root variable; such inputs are adapter-
scoped fixtures only.

This amendment does not change the canonical digest algorithm: hash the complete
normalized canonical file with one trailing LF, deterministically render both client
blocks, and require each actual block to byte-match its expected rendering.
