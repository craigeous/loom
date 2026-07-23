# 06 — Init Modes

Status: Plan Review

## Authority

ADRs [0005](../ADR/0005-specs-frozen-after-approval.md),
[0009](../ADR/0009-unaligned-migrate-sub-mode.md),
[0018](../ADR/0018-shared-core-and-client-adapters.md),
[0019](../ADR/0019-supported-runtime-and-release-contract.md), and
[0020](../ADR/0020-remote-publication-is-the-landing-authority.md).

Initialization is a shared workflow invoked through the active client adapter. It
detects before mutating, validates the selected client/host, creates the canonical
project digest, renders both instruction adapters, establishes the gate, and records
remote publication configuration.

## Detection

```text
no .docs + empty/near-empty repository       -> Greenfield
no Loom-shaped .docs + existing repository   -> Unaligned
  no pre-existing docs spine                 -> Unaligned-bare
  pre-existing docs spine                    -> Unaligned-migrate
Loom-shaped .docs                            -> Initialized
```

A pre-existing docs spine is an established non-`.docs/` methodology under `docs/`,
`doc/`, `documentation/`, or a detected equivalent. Detection is read-only and reports
its evidence. Exact heuristics are versioned playbook policy.

Before supported-mode operation, initialization/doctor verifies Bash 3.2+, Git 2.34+,
jq 1.6+, supported OS/architecture, active client/version, adapter components, helper
resolution, and hook trust/activity. Unknown or below-minimum clients are errors, not
silent compatibility mode.

## Common configured outputs

Every successful Greenfield or alignment flow establishes:

- the `.docs/` layout from spec 01;
- `.docs/status/project-instructions.md` in schema
  `loom-project-instructions/v1`;
- a generated Loom-owned block in both root `CLAUDE.md` and root `AGENTS.md`,
  preserving owner content outside marked blocks;
- one verified or explicitly `UNVERIFIED` format → lint → test gate;
- remote name, full target ref, and explicit landing mode;
- supported active-client adapter state without requiring the other client to be
  locally installed; and
- initialized coordination/protocol schema versions.

Neither instruction adapter is authoritative. Missing files, mismatched hashes,
semantic conflict, or manual divergence of a Loom-owned block fails validation and
`loom doctor` until regenerated from the canonical digest.

## 1. Greenfield

- Create the `.docs/` skeleton with status files containing scaffold metadata and the
  first owner action, but no invented product decisions.
- Create the canonical digest and both instruction adapters.
- Learn/verify the gate and publication configuration with the owner.
- Begin owner-directed research → ADR → spec → slice planning within declared scope.

## 2a. Unaligned-bare

For an existing repository without a docs spine:

- inspect languages, structure, tooling, CI, and existing documentation;
- create the common configured outputs;
- draft **descriptive** initial specs mapping what exists, without smuggling in design
  changes or new decisions;
- route those new specs through `Draft → Plan Review → Approved`; and
- seed roadmap/progress/handoff from verified current state.

Any desired change discovered during back-fill requires normal planning authority.

## 2b. Unaligned-migrate

For an existing methodology spine, initialization presents a mandatory owner gate:

- **Migrate:** move/reconcile into `.docs/`, rewrite links, preserve prior statuses,
  establish common configured outputs, and become Initialized.
- **Thin-pointer:** leave the old spine authoritative; future runs continue to detect
  Unaligned because Loom does not treat the pointer as initialized authority.
- **Abort:** make no changes and remain Unaligned.

Loom never chooses on the owner's behalf. A migration is a mechanical relocation, not
a planning re-review: pre-existing artifact statuses are preserved. It runs inline in
the init workflow with the ordered idempotent migration recipe; no planner/evaluator is
spawned merely to move already-authoritative files.

Migration preconditions include a safe worktree state, explicit treatment of untracked
files, NUL-safe path traversal, specific-before-generic link rewrites, two-directional
link validation, living-versus-archived boundaries, and no destructive action outside
validated roots.

## 3. Initialized

Initialization becomes a resume/realignment check. It derives a menu from actual
statuses, exact Git/coordination state, configured remote target/mode, publication
receipts, and `Ready to Publish` recovery—not from local `main` history alone. Options
include pending research/planning evaluation, an in-flight slice, local-review or
evaluation recovery, publication recovery, a new roadmap slice, and status.

It re-applies compatible playbook changes idempotently and regenerates both instruction
blocks from the canonical digest. Clean derived changes apply automatically; conflicts
or ambiguous owner content produce a recommendation and owner decision. Loom never
overwrites owner-controlled text outside marked blocks.

## Gate establishment

The gate is ordered format → lint → test. Rust is the only initially verified bundled
gate. For another stack, init inspects repository tooling/CI, proposes exact commands,
gets owner confirmation, runs them green once, records them in the canonical digest,
and adds the reusable definition to the playbook through Loom's own reviewed change
process. Until the first green run the gate is `UNVERIFIED` and blocks `Implemented`.

The chosen gate must also be reproducible by the isolated evaluation runner with pinned
environment/tool versions and prepared offline dependencies. A developer-only command
that the evaluator cannot rerun is not a valid supported gate.

## Publication configuration

Initialization records a remote name and full target ref (normally `origin` and
`refs/heads/main`) plus exactly one of `remote-direct`, `pr-per-slice`, or
`merge-queue`. `remote-direct` is available only for an eligible target; provider
modes require an installed conforming adapter. Missing credentials/protection do not
authorize mode fallback. Offline work may progress through `Ready to Publish`, but
cannot be called `Landed`.
## Isolated dogfood homes and project roots

ADR 0024 dogfood tests create disposable, inventory-tracked Claude and Codex client
homes plus a disposable project root. Clean install and second reinstall may write
only inside those owned roots and explicitly documented client caches. Invocation
from inside and outside the project must resolve the same intended project root,
without writing elsewhere.

Uninstall removes Loom marketplace/plugin discovery and Loom-owned residue from the
isolated roots. Before/after filesystem inventories and relevant structured-output
hashes are evidence. Existing owner configuration/cache is never an input, and the
checkpoint does not alter normal Greenfield/Unaligned/Initialized semantics.
