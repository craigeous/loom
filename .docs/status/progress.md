# Progress

Status: Living

The status source of truth and decision index for building loom.

## Current state

- **Phase:** M0 — Design (nearly complete).
- **Last action:** researched Claude Code plugin/agent/marketplace mechanics
  (note in `research/`), then revised the full spec spine and promoted the firm
  decisions to ADRs 0001–0006.
- **Next:** owner final review of the revised spec + ADRs, then begin **M1 —
  Minimum loop** (hand-built orchestration), resolving build-time open questions
  (OQ-D namespacing, OQ-E marketplace root form, OQ-F helper portability).

## Accepted decisions (ADRs)

- 0001 — Plugin architecture; orchestrator = main `/loom` session; roles =
  sub-agents; no peer spawning.
- 0002 — Model selection by tier (haiku/sonnet/opus); exact versions not pinnable.
- 0003 — File-based cold handoffs; a commit at every handoff; evaluators diff.
- 0004 — Blind evaluation by controlled inputs + role separation (no self-approval).
- 0005 — Specs frozen after approval; change only via planning; devs touch only
  slices + handoffs.
- 0006 — Distribution as a single-plugin self-marketplace.

## Other settled points (in spec)

- Five roles; researcher requires citations and is lightly gated; plan evaluator
  also does the research source-check.
- Owner declares scope + claimed gates (`all` or a list) at kickoff; otherwise
  evaluator approval advances.
- Round limit 5; escalation = pause + summary.
- On code-eval PASS, the developer runs a cold finalize pass (update living docs,
  archive plan). No spec edit.
- Rust is the only verified gate; other stacks' gates are created during init and
  recorded back into the playbook.
- Parallelism (worktree-per-slice) is designed-for but built after the sequential
  loop.
- loom dogfoods its own structure; living docs kept separate.

## Open

See [`../spec/09-open-questions.md`](../spec/09-open-questions.md): OQ-A (parallel
`.docs/` coordination), OQ-B (research-review tier), OQ-C (finalize-pass owner),
OQ-D (command namespacing), OQ-E (marketplace root form), OQ-F (helper
portability). OQ-D/E/F are the ones blocking M1 build choices.
