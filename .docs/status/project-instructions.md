# Project Instructions

Status: Living
Schema: loom-project-instructions/v1

## Read first

1. [Spec index](../spec/README.md)
2. [Session handoff](handoff.md)
3. [Progress](progress.md)
4. [Roadmap](roadmap.md)

## Core invariants

- Five cold lifecycle roles hand off through committed `.docs/` artifacts; no role
  evaluates its own work and only the root orchestrator delegates.
- Approved specs are frozen and changed only by a planner plus cold plan evaluator.
- The configured remote target and verified receipt establish `Landed`; local `main`
  is not publication authority and target refs are never force-pushed.
- Loom has a portable shared core with thin client/host adapters. Private macOS
  dogfood is not public support or release conformance.
- One canonical instruction digest renders Loom-owned blocks in both root adapters.

## Gate

- Run `scripts/check` from any working directory; it performs the pinned metadata,
  format, lint, syntax, Bash runtime, link, and client-validation stages.
- Shipped scripts require Bash 3.2+, Git 2.34+, and jq 1.6+.
- The v0.2 release gate remains M0–M7 on the complete spec-10 host/client matrix.

## Repository map

- [`plugins/loom/`](../../plugins/loom/) — one distribution, manifests, adapters,
  commands, roles, hooks, helpers, and playbook.
- [Specs](../spec/README.md) and [ADRs](../ADR/README.md) — intended design and
  immutable decision history.
- [Slice plans](../slice-plans/README.md) and [evaluations](../evaluations/README.md)
  — transient work and durable verdicts.
- [`scripts/check`](../../scripts/check) — reproducible repository gate.

## Reference index

- [Artifact lifecycle](../spec/03-artifact-lifecycle.md) — statuses, evaluation, and
  publication boundary.
- [Orchestrator](../spec/04-orchestrator.md) — routing, bootstrap, and recovery.
- [Command surface](../spec/07-command-surface.md) — client workflow/role mapping.
- [Playbook](../spec/08-playbook.md) — digest, hooks, helpers, and gate policy.
- [Packaging](../spec/10-packaging.md) — install behavior and release matrix.
