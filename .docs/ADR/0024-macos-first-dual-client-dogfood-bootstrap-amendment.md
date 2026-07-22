# 0024 — macOS-First Dual-Client Dogfood Bootstrap Amendment

Status: Draft
Date: 2026-07-22

## Context

The owner wants a usable Loom build on the current Apple-silicon development Mac so
Claude Code and Codex can be exercised against real work before the rest of the
improvement program is complete. This is a dogfood objective, not a request to publish
v0.2.0 or weaken its release contract.

Accepted ADR [0019](0019-supported-runtime-and-release-contract.md) defines the v0.2
release matrix as Ubuntu 22.04/24.04 x86-64 plus macOS 14 or newer on Apple silicon
and Intel, and it forbids release until M0 through M7 are green. The approved
[dual-platform research](../research/2026-07-21-dual-platform-plugin-architecture.md)
shows that most shared-core behavior is portable while installation, discovery,
invocation, role launch, hooks, and helper-root resolution require client-specific
behavioral proof. The current `ci-baseline` result supplies a reproducible static
baseline but explicitly does not supply that proof.

ADR [0023](0023-repository-self-hosting-bootstrap-transition.md) creates the temporary
repository bootstrap needed to build Loom's production review, evaluation, and landing
machinery. Its closed eligibility rules do not admit another ADR or spec amendment,
and its transition-state history may remove but never add an allowed slice. It
therefore cannot authorize the requested pivot. Treating owner intent alone as an
exception, silently editing the improvement plan, or relabeling static Codex metadata
as behavior evidence would violate the very controls the bootstrap was designed to
preserve.

There is also a publication prerequisite. The configured target
`origin:refs/heads/main` is currently
`c7bd84d997afb32f6159628eb840a9dd8d2d3dca`. It predates the exact 32-commit reviewed
planning/authority chain ending at
`b28a74754e2ee016a035fa085f0d91de66057f62`, and the 21-commit `ci-baseline`
implementation/evidence chain ending at
`cd6b5e17e04168d8e8472b4c55600c6a2aa6a5b9`. Calling those authority commits
unrelated hitchhikers would make the reviewed slice impossible to publish; allowing
arbitrary ancestors alongside them would make the slice boundary meaningless.

In scope is one owner-authorized, pre-acceptance ratification of this ADR; one
append-only amendment to the existing protected transition state; exact publication
of `ci-baseline` with its reviewed prerequisite authority; and two named follow-on
slices that establish a macOS Apple-silicon dual-client dogfood path. Linux, macOS
Intel, public release, and any broader bootstrap revival are out of scope.

## Decision

### 1. Define a dogfood target without changing the release claim

The first dogfood target is the owner's current supported development host:

- Darwin on Apple silicon (`arm64`), currently macOS 26.5.2;
- system Bash 3.2.57, Git 2.34 or newer, and jq 1.6 or newer; and
- Claude Code 2.1.216 and Codex CLI 0.144.6, the existing pinned floors.

This target is a private development checkpoint. It is not a new public support
matrix, release candidate, version, tag, distribution publication, or claim about the
ChatGPT desktop or Codex IDE surfaces. “Dogfood-ready” means only that the exact host
and client behavior in section 6 passed.

For this checkpoint, Ubuntu and macOS Intel execution are deferred and MAY remain as
advisory signal where already inexpensive. Their failure or absence does not block the
two dogfood slices, but it also produces no support claim. Shared helpers, protocols,
schemas, paths, and role contracts SHALL retain their client-neutral and portable
boundaries. A dogfood change may branch at an explicit host/client adapter; it SHALL
not make Darwin paths, Apple tools, Homebrew, or one client's root variable the shared
core contract.

ADR 0019's v0.2 release matrix and its M0-through-M7 release gate remain in force.
This ADR does not authorize v0.2.0 publication. Changing that release contract still
requires a later accepted ADR and synchronized spec/program amendment.

### 2. Ratify this otherwise-ineligible ADR exactly once

ADR 0023 cannot grant eligibility to this ADR, and this ADR cannot make its own
acceptance retroactively valid. The following one-time pre-acceptance procedure is the
only exception:

1. The planner commits only this proposed ADR and its ADR-index entry at `Plan Review`.
2. The root constructs an exact-revision planning package bound to that commit, this
   ADR's blob, ADRs 0018–0023, the approved spec index, the improvement-plan blob,
   dual-platform research and verdict, `ci-baseline` plan and verdict, the current
   protected transition-state tip, and the exact remote-target observation. Producer
   conversation, reasoning, credentials, and unrelated status/evaluation history are
   excluded.
3. A fresh cold plan evaluator, distinct from the planner and root, receives only that
   package and the plan-evaluation rubric. It may not delegate or mutate the checkout.
   Its verdict must bind every supplied hash and explicitly assess the seven numbered
   decisions in this ADR.
4. The verdict is recorded without changing its merits and carries exactly:

   ```text
   Evidence mode: loom-repository-bootstrap/v1
   Bootstrap-ratification: degraded ADR 0024 one-time ratification
   Isolation: not established under ADR 0022
   Release conformance: not established
   ```

5. Evaluator `PASS` is necessary but insufficient. After reading the final proposed
   ADR and verdict, the repository owner must explicitly accept it. The acceptance
   record identifies the proposed commit/blob, verdict hash, decision, and UTC time.
   The recorder may then commit the verdict, acceptance record, and `Status: Accepted`
   transition under the configured uniform identity. The evaluator does not approve
   its own work, the planner does not evaluate its own proposal, and owner acceptance
   does not substitute for evaluator `PASS`.

A FAIL returns the ADR to planning. Missing, malformed, hash-mismatched, self-reviewed,
or unrecorded evidence leaves it at `Plan Review`. This exception cannot evaluate a
different ADR, research artifact, spec amendment, or slice plan.

### 3. Add exactly two transition-state permissions, exactly once

No authority in this ADR may be used until its accepted commit and blob, ratification
verdict, and explicit owner-acceptance record are bound into the protected transition
history.

The only permitted state mutation is one ordinary fast-forward successor to exact
transition tip `367584c3b3d0423af04194171e35c827d069a744`. Before constructing it,
the root SHALL freshly verify that:

- the configured transition ref is still
  `refs/heads/loom/bootstrap-transition`, protected against deletion and non-fast-
  forward updates with no bypass;
- its fetched and advertised object IDs equal that exact tip;
- the complete ADR-0023 history is valid, sequence is `0`, phase is `active`, all
  four bootstrap components are `available`, results/evidence maps are empty, and
  full sunset is `not-reached`; and
- the configured target is freshly readable.

The successor increments the sequence to `1`, has the verified tip as its sole parent,
retains every immutable ADR-0023 program/configuration field, and adds one
`authority_amendments` entry identified as `adr-0024-macos-dogfood/v1`. That entry
binds the accepted ADR commit/blob, ratification verdict and package hashes, owner-
acceptance record hash, and the before/after allowed-slice sets. The only set change is
the addition of these exact names:

- `macos-dogfood-program-amendment`
- `macos-dual-client-dogfood`

This narrowly supersedes ADR 0023 section 6's add-never rule for that one successor
only. It also extends ADR 0023 sections 1 and 7 only enough to permit degraded planning
evaluation and repository-only publication of those two exact slices while their
required bootstrap components remain `available`. The first is a documentation-only
planning/spec/program amendment; the second is code-bearing and uses the complete
three-finder plus distinct-evaluator procedure. Both retain ADR 0023's labels,
exact-revision bindings, failure rules, publication intent/settlement ordering, and
component retirement boundaries.

The successor is pushed without force and freshly fetched and validated by exact
object ID before either slice is planned, evaluated, implemented, or published. A
race, changed predecessor, unexpected state, missing protection, or failed fresh read
blocks this amendment; the root does not adapt the mutation to another state. Every
later state validates this amendment entry as immutable. Thereafter the original
remove-only rule resumes: no slice may ever be added, renamed, replaced, or re-added,
and sunset remains monotonic and terminal.

### 4. Publish the exact prerequisite authority with `ci-baseline`, not arbitrary history

The already reviewed `ci-baseline` may be published only through a new integrated
candidate built from a fresh read of the configured remote target under ADR 0023's
publication-intent procedure. Local `main`, the current ADR branch, and an existing
integration worktree are not candidate inputs.

The candidate manifest SHALL separate and exhaustively inventory these two closed
segments:

| Segment | Exact range | Commit count | Purpose |
|---|---|---:|---|
| prerequisite authority | `c7bd84d997afb32f6159628eb840a9dd8d2d3dca..b28a74754e2ee016a035fa085f0d91de66057f62` | 32 | improvement plan, dual-platform research/evaluation, ADRs 0018–0023 and evaluations, frozen-spec amendments/evaluations, and approved `ci-baseline` planning |
| M0 slice | `b28a74754e2ee016a035fa085f0d91de66057f62..cd6b5e17e04168d8e8472b4c55600c6a2aa6a5b9` | 21 | `ci-baseline` implementation, revisions, review findings, and final Round-5 PASS evidence |

The manifest records the three boundary commit/tree IDs, every commit ID in reverse
topological order for each segment, and for every commit its subject plus changed
path, status, old/new mode, and object IDs. It also records the ordered union of 40
paths changed by the authority segment and 52 paths changed by the M0 segment, with a
category and justification for each. A path or commit is related only when it belongs
to one of those exact ranges and categories. No other local commit, side branch,
working-tree edit, status update, or completed slice is a permissible hitchhiker.

If the fresh remote target remains the stated `c7bd84d...` base, those exact chains
are replayed without omission or substitution. If it has advanced by ordinary
fast-forward, the candidate is rebuilt from the new exact remote SHA and integrates
the same two closed segments; it must prove the new base does not already contain a
conflicting or partial version. Ambiguous overlap, changed bytes, conflict resolution
that would alter a reviewed commit, target rewind, or an inability to classify every
result path fails closed.

The integrated candidate must then receive a fresh complete gate, all three cold
auxiliary reviews, and a distinct cold code-evaluator verdict against its exact remote
base and candidate tree. Prior Round-5 evidence is authority and comparison evidence,
not a substitute. All required macOS and Ubuntu cells in the approved `ci-baseline`
plan remain required for this publication because that slice was reviewed under the
original matrix. Generated finalization/evidence commits must be confined to declared
plan, evaluation, archive/index, and living-status paths, followed by a final exact-
candidate gate. Only a valid PASS may proceed to transition intent, non-force target
publication, fresh verification, receipt, settlement, and claim release.

ADR 0024 and its later ratification commits are not part of that `ci-baseline`
candidate. They are published as related authority with the separately reviewed
`macos-dogfood-program-amendment` candidate, preventing the M0 publication from
silently absorbing the pivot itself.

### 5. Require two separate follow-on slices

After `ci-baseline` is verified on the configured target, work proceeds through two
independently planned and reviewed slices:

1. **`macos-dogfood-program-amendment`** updates the frozen specs and program plan
   through the normal planner/plan-evaluator lifecycle, publishes this ADR and its
   ratification evidence as prerequisite authority, inserts the dogfood checkpoint
   without renaming or combining existing M1–M8 slices, and synchronizes every
   document named in section 7. It contains no product code or manifest behavior
   implementation.
2. **`macos-dual-client-dogfood`** is a separately reviewable code-bearing vertical
   slice implementing only the shared-core and thin-adapter behavior needed for the
   macOS checkpoint in section 6. It may not absorb M1 coordinator-safety changes,
   M2 landing-helper work, M4 production local-review machinery, M5 production
   evaluation isolation, or M7 release packaging.

Each slice requires its own approved plan, exact path allowlist, gate evidence,
degraded-bootstrap provenance where still eligible, evaluation verdict, integration
candidate, transition intent/settlement, and remote verification. A PASS for one is
not evidence for the other.

### 6. Define the minimum macOS dual-client dogfood proof

`macos-dual-client-dogfood` is complete only when isolated, disposable client homes on
the target Mac prove all of the following from the exact committed candidate:

- clean local marketplace/plugin installation and a second reinstall for Claude Code
  and Codex CLI, without relying on the owner's existing plugin cache or configuration;
- client-native discovery and explicit invocation of Loom (`/loom:*` for Claude and
  `$loom-*` for Codex), with all eight workflow mappings mechanically present;
- at least one real cold role launch through the shared role contract on each client,
  mechanical validation of all five role mappings, bounded return, and proof that the
  child cannot delegate;
- exact Claude and Codex `PreToolUse` and `PreCompact` fixtures, including the shared
  `trigger` field, client-specific blocking output, and an honest Codex hook-trust/
  activation result;
- helper execution through an absolute installed-root resolution on each client,
  physical-root/manifest containment, the exact Codex skill-source ascent, and no
  correctness dependence on bare `PATH`, `CODEX_HOME`, or a Claude-only root variable;
- invocation from inside and outside the repository root with the same intended
  project-root behavior and no writes outside the isolated project/client homes; and
- clean uninstall for both clients, with marketplace/plugin discovery removed and no
  Loom-owned residue outside explicitly documented caches or test evidence.

The evidence records OS/architecture, exact client and runtime versions, commands,
exit status, relevant structured output hashes, installed roots, fixture hashes, and
before/after filesystem inventories. Static schema validation, manifest presence,
mock-only invocation, one client's success, or installation without functional use is
not sufficient. The code evaluator remains the sole PASS/FAIL authority.

### 7. Synchronize documentation and define restoration criteria

The `macos-dogfood-program-amendment` plan SHALL enumerate and update, in one reviewed
candidate, every affected authority or user-facing surface:

- `.docs/repository-improvement-plan.md` for checkpoint ordering, scope, named slices,
  and the distinction between dogfood and release completion;
- `.docs/spec/README.md` and affected specs 00, 02, 03, 04, 06, 07, 08, and 10 for
  lifecycle authority, client adapters, invocation, hook/root behavior, dogfood
  evidence, and the unchanged release gate;
- `.docs/ADR/README.md`, the new slice-plan/evaluation indexes and artifacts, and
  living roadmap/progress/handoff state at their normal finalization boundary; and
- `README.md` and `CLAUDE.md` so installation, support, limitations, gate guidance,
  and agent-facing architecture do not imply Linux/Intel dogfood proof or public
  Codex support before the behavioral slice passes.

The code-bearing slice SHALL update both manifests/catalogs, compatibility and root-
binding data, hook/workflow/role/helper documentation, tests, and release-owned
fixtures together whenever its implementation changes those surfaces. A mechanical
documentation check must reject conflicting platform status, client floors,
invocation names, version values, or “supported” claims across those files. Historical
ADRs and evaluations remain immutable and are linked rather than rewritten.

Linux and macOS Intel may return to a public support claim only after a later accepted
planning decision names the restored matrix and a clean candidate passes, for every
claimed host/architecture: the full local gate; exact floor and current Bash lanes;
both pinned-client clean install/reinstall, discovery/invocation, cold-role, hook,
helper/root, and uninstall matrix; fresh-clone release testing; and synchronized
spec, compatibility, README, changelog, and release evidence. Current official runner
labels may replace retired labels only through that reviewed amendment. Advisory jobs
and old M0 logs do not satisfy restoration.

### 8. Preserve review integrity, release gates, and fail-closed recovery

Every artifact produced through this amendment uses the degraded labels from sections
2 and 3, a producing role distinct from its evaluator, no self-approval, and no claim
of `loom-local-review/v1`, ADR-0022 isolation conformance, or release conformance.
Owner decisions authorize scope and acceptance; they do not convert invalid evidence
to PASS.

No command under this ADR may create a v0.2.0 tag, publish a marketplace release,
recommend a public release, or mark M0–M7 release conformance complete. The existing
release gate remains until a later formal decision changes it.

On a ratification, state amendment, candidate inventory, review/evaluation, client
smoke, publication, or settlement failure, preserve the exact evidence and claim,
make no advancing transition, and follow ADR 0017 and ADR 0023 section 8. Hash-identical
infrastructure stages may resume; changed inputs require a new run. A partially
written transition amendment is resolved only by fresh reads of the protected ref.
An existing valid amendment successor is reused; an absent successor may be created
only from the exact predecessor; any other state blocks. No recovery path force-pushes,
deletes, rewinds, recreates, or forks the transition ref, re-adds a removed slice,
revives a retired component, or weakens target publication verification.

## Consequences

- The owner gets the shortest honest path to real Claude Code and Codex dogfooding on
  the current Mac without representing that checkpoint as a release.
- ADR 0019's public v0.2 platform and release contract remains unchanged. Linux and
  macOS Intel work can be resumed later against explicit restoration evidence instead
  of being silently abandoned.
- ADR 0023 is superseded only for one pre-acceptance ADR-0024 ratification, one exact
  transition successor that adds two names, and those names' planning/publication
  eligibility. Its append-only protection, progressive retirement, failure handling,
  and terminal sunset otherwise remain intact.
- Publishing `ci-baseline` requires a fresh integrated review rather than trusting
  local ancestry. The 32 authority commits are admitted as necessary reviewed
  prerequisites, while exhaustive commit/path inventory prevents unrelated work from
  riding with them.
- The planning amendment and behavioral implementation remain separate, so the
  support-language change can be reviewed before code and M1 safety work does not get
  hidden in a client-adapter slice.
- The cost is one additional ratification and state transition plus later restoration
  work. If the exact state predecessor or publication ancestry no longer holds, this
  narrowly written exception fails closed and a new owner-reviewed decision is
  required.
