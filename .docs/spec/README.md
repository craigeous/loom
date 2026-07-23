# loom Specs

Status: Living

These documents are Loom's authoritative intended design. Read this index first,
then the spec for the area being changed.

## Reading order

1. [Overview & Goals](00-overview.md)
2. [Concepts & `.docs/` Layout](01-concepts.md)
3. [Roles](02-roles.md)
4. [Artifact Lifecycle & Status State Machine](03-artifact-lifecycle.md)
5. [Orchestrator](04-orchestrator.md)
6. [Controlled-Input Independent Evaluation](05-blind-evaluation.md)
7. [Init Modes](06-init-modes.md)
8. [Client Invocation Surface](07-command-surface.md)
9. [Shared Playbook, Instructions, Hooks, and Helpers](08-playbook.md)
10. [Packaging & Distribution](10-packaging.md)
11. [Open Questions](09-open-questions.md)

## Authority and lifecycle

- `.docs/spec/` is intended design. An approved spec is frozen and changes only
  through planner → plan-evaluator review (ADR 0005). On conflict, the spec wins.
- `.docs/ADR/` is immutable decision history. A later accepted ADR may supersede
  an earlier decision without rewriting it.
- `.docs/slice-plans/` is transient implementation planning. Landing archives a
  plan and updates living status; it does not silently edit a frozen spec.
- `.docs/status/` is living operational state, not architectural authority.

The current amendment derives principally from accepted ADRs
[0018](../ADR/0018-shared-core-and-client-adapters.md),
[0019](../ADR/0019-supported-runtime-and-release-contract.md),
[0020](../ADR/0020-remote-publication-is-the-landing-authority.md),
[0021](../ADR/0021-loom-owned-local-review-protocol.md), and
[0022](../ADR/0022-controlled-input-independent-evaluation.md). Where their
decisions conflict with earlier approved text, the later accepted ADR controls.
Accepted ADR [0024](../ADR/0024-macos-first-dual-client-dogfood-bootstrap-amendment.md)
also authorizes one private Apple-silicon dual-client dogfood checkpoint before M1.
That checkpoint does not change ADR 0019's full v0.2 release matrix or M0–M7 gate.

## Non-negotiable design

- Loom is one product and physical distribution with a client-neutral shared core
  and thin Claude Code and Codex adapters. Neither client is the portable source of
  truth.
- The lifecycle has exactly five logical roles: researcher, planner, plan
  evaluator, developer, and code evaluator. The orchestrator is not a sixth role.
  The three local-review finder workers are auxiliary, advisory procedures—not
  lifecycle roles—and only the root orchestrator may delegate.
- Role work is cold and mediated through committed artifacts. Evaluation is an
  independent cold invocation with controlled inputs; Loom does not claim
  cryptographic anonymity, impartiality, or a hostile-code sandbox.
- Shared role policy uses Economy, Standard, and Deep review capability profiles.
  Each client maps those profiles to tested client-specific model settings.
- Managed projects have one canonical digest at
  `.docs/status/project-instructions.md`; `CLAUDE.md` and `AGENTS.md` are generated
  instruction adapters and must not drift.
- Local review is the network-silent, exact-SHA `loom-local-review/v1` protocol.
  No external review command is a current dependency; superseded history remains in
  the ADR record.
- `Landed` is established only by verified publication to the configured remote
  target. Local `main` is a disposable mirror, never landing authority.
- Shipped executables target Bash 3.2+, require Git 2.34+ and jq 1.6+, and support
  the host/client matrix in spec 10. All product surfaces release atomically under
  SemVer.
- Workflow profiles and target-branch history shape remain outside frozen design
  until the improvement program's benchmark supplies evidence.
- “Dogfood-ready” is a private Darwin `arm64` behavior result, not public support,
  release conformance, a tag, or permission to skip Ubuntu/macOS-Intel release proof.

## Decision records

Accepted ADRs are indexed in [`../ADR/README.md`](../ADR/README.md).
