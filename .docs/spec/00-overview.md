# 00 — Overview & Goals

Status: Plan Review

## Authority

ADRs [0001](../ADR/0001-plugin-architecture-and-orchestrator.md) through
[0017](../ADR/0017-infrastructure-blocked-escalation.md), as superseded or extended
by accepted ADRs [0018](../ADR/0018-shared-core-and-client-adapters.md) through
[0022](../ADR/0022-controlled-input-independent-evaluation.md).

## What Loom is

Loom is a dual-client, spec-driven development system. One physical distribution
contains a portable Agent Skills-compatible core plus thin adapters for Claude Code
and Codex. The core owns workflows, role contracts, evaluation and review protocols,
templates, policy, and client-neutral helpers. Adapters own manifests, catalogs,
invocation syntax, cold-agent launch, model selectors, plugin-root resolution, hook
wire formats, and managed-project instruction filenames.

The owner interacts with a thin top-level orchestrator. The orchestrator routes work
among exactly five cold lifecycle roles through repository artifacts and commits:

```text
owner -> researcher -> research evidence -> planner -> ADR/spec/slice-plan
                                            |                 |
                                            +-> plan evaluator+

approved slice-plan -> developer -> gate -> local review finders
                                    -> code evaluator -> Ready to Publish
                                    -> integration candidate -> verified remote Landed
```

The correctness, tests, and security finder workers are auxiliary advisory workers.
They generate structured findings under `loom-local-review/v1`; they are not roles,
cannot delegate, cannot edit product code, and cannot decide PASS/FAIL.

## Problems Loom solves

1. **Context drift.** Durable decisions live in `.docs/ADR/` and `.docs/spec/`;
   working and operational state lives in the remaining `.docs/` areas and Git.
   Cold invocations reconstruct context from controlled files instead of transcripts.
2. **Unreviewed self-approval.** Producing and evaluating invocations are separate.
   Evaluators receive sanitized, allowlisted evidence and cannot mutate the managed
   checkout. This is separation of duties, not a claim of model impartiality.
3. **Unreproducible review.** Review operates locally on exact commits with pinned
   protocol/prompt assets, complete finder states, deterministic validation, and no
   network dependency.
4. **Ambiguous landing.** One configured remote target and mode define publication.
   A verified remote result plus a bound receipt—not a local merge or push exit—makes
   a slice `Landed`.
5. **Client drift.** Shared behavior is client-neutral while Claude Code and Codex
   differences are explicit, versioned, and tested.

## Goals for v0.2

- Equivalent explicit workflows on supported Claude Code and Codex surfaces.
- Exactly five lifecycle roles with tested non-delegation and capability-profile
  mappings on both clients.
- A committed `.docs/` spine, canonical project-instructions digest, and derived
  `CLAUDE.md`/`AGENTS.md` blocks with zero-drift validation.
- Reproducible Bash, host, dependency, client, manifest, hook, helper, and install
  matrices from one local check and CI.
- Safe same-clone coordination, exact-SHA local review, sanitized evaluation, and
  deterministic recording.
- Remote-first publication with recoverable `Ready to Publish` state.
- `loom doctor` and CI checks that mechanically enforce declared invariants.
- One atomic SemVer `v0.2.0` release after improvement milestones M0–M7 pass.

## Non-goals

- Native Windows, PowerShell, Git Bash/MSYS2, Cygwin, or WSL support in v0.2.
- Release-guaranteed Codex IDE plugin installation. Repository skills may be
  documented as an unguaranteed fallback, not full plugin support.
- Peer-to-peer or nested lifecycle-role delegation.
- OS-level hostile-code containment, cryptographic anonymity, remote attestation,
  or proof that two model invocations reason independently.
- Cross-clone claim exclusion without a configured remote-claim or provider-queue
  adapter. Remote publication CAS prevents overwrite, not duplicated work.
- A frozen workflow-profile policy or target-branch squash/granular-history choice
  before benchmark evidence exists.
- Replacing owner judgment over intent, scope, claimed approval gates, or escalation.

## Glossary

- **Owner:** human who supplies intent, scope, and claimed gates.
- **Orchestrator:** top-level interactive workflow driver; not a lifecycle role.
- **Lifecycle role:** one of researcher, planner, plan evaluator, developer, code
  evaluator.
- **Auxiliary review worker:** cold non-delegating correctness/tests/security finder.
- **Cold invocation:** fresh client invocation without a producer transcript.
- **Controlled inputs:** a hashed allowlist exported for one evaluation run.
- **Shared core:** portable skills, contracts, protocols, templates, policies, and
  helpers beneath client adapters.
- **Adapter:** client-specific manifest, invocation, launch, model, hook-output,
  root-resolution, or instruction-file binding.
- **Gate:** configured format → lint → test sequence.
- **Landing:** verified publication through the configured remote mode.
## Private macOS dual-client checkpoint

Accepted ADR 0024 inserts one pre-M1 private checkpoint on the owner's Darwin
`arm64` host. It may establish dogfood readiness only after exact-candidate Claude
Code 2.1.216 and Codex CLI 0.144.6 installation and behavior evidence passes. It is
not public support, release conformance, a release candidate, tag, or distribution
publication.

The client-neutral shared core remains portable. Darwin paths, Apple tools, Homebrew,
one client's root variable, or implicit `PATH` behavior may appear only in explicit
host/client adapters. ADR 0019's Ubuntu and macOS Intel obligations and M0–M7 release
gate remain unchanged.
