# Roadmap

Status: Living

Milestone order for building loom. "What's next and why"; detailed status in
`progress.md`, restart context in `handoff.md`.

## M0 — Design (nearly complete)

- [x] Foundational design conversation with the owner.
- [x] Scaffold the loom repo and `.docs/`.
- [x] Draft the spec spine (`.docs/spec/00`–`10`).
- [x] Research plugin/agent/marketplace mechanics; resolve Q1–Q3, Q14.
- [x] Promote firm decisions to ADRs 0001–0006.
- [ ] Owner final review of revised spec + ADRs.

## M1 — Minimum loop (hand-built, sequential)

- [ ] Plugin scaffolding: `.claude-plugin/plugin.json` + `marketplace.json`,
  `commands/`, `agents/`, `skills/loom-playbook/`.
- [ ] Five role agents (`agents/*.md`) with tier + tools per ADR 0002 / spec 02.
- [ ] `/loom` orchestrator command: init detection, scope + gate prompts, driver
  loop, dispatch table, commit-per-handoff.
- [ ] Playbook: `.docs/` templates, status machine, role rubrics, Rust gate.
- [ ] Blind-evaluation input contract enforced in evaluator prompts.
- [ ] Resolve build-time questions: OQ-D (namespacing), OQ-E (marketplace root),
  OQ-F (helper portability).
- [ ] One end-to-end sequential slice on a throwaway target.

## M2 — Init modes & gate learning

- [ ] Greenfield / unaligned-alignment / initialized detection + behavior.
- [ ] Descriptive back-fill for unaligned projects.
- [ ] Gate establishment: Rust verified; create-and-record for new stacks.
- [ ] Idempotent playbook re-application (clean-merge + recommend-rest).

## M3 — Parallelism

- [ ] Worktree-per-slice; orchestrator launches parallel background role agents.
- [ ] Resolve OQ-A (`.docs/` coordination across branches; landing = merge).

## M4 — Dogfooding & hardening

- [ ] loom manages its own development end to end.
- [ ] Best practices propagated into root/project `CLAUDE.md` automatically.
- [ ] Owner approval gates, round limits/escalation polished.
- [ ] Resume-after-interruption verified across machines.
- [ ] `claude -p` fallback evaluated if deeper nesting is needed.
