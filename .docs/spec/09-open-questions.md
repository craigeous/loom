# 09 — Open Questions

Status: Living

Resolved items remain summarized for traceability; accepted ADRs and approved specs,
not this index, are authoritative.

## Resolved

- **Product boundary and layout.** One physical Loom distribution has a portable
  skills/protocol/helper core plus separate Claude Code and Codex manifests, catalogs,
  launch, hook-output, and instruction adapters. → ADR 0018; specs 07, 08, 10.
- **Invocation.** Claude uses explicit `/loom:*`; Codex uses explicit `$loom-*`.
  Behavioral intent is shared and textual syntax is not. → ADR 0018; spec 07.
- **Roles and hierarchy.** Exactly five lifecycle roles remain. The orchestrator is
  not a role; local-review finders are auxiliary advisory workers. Only the root
  orchestrator delegates, and Codex uses generic cold children rather than generated
  project agent TOML. → ADRs 0018, 0021; specs 02, 04.
- **Model policy.** Shared policy is Economy/Standard/Deep review; adapters own tested
  mappings. Researcher is Economy, developer/orchestrator Standard, and planner plus
  both evaluators Deep review. → ADR 0018; spec 02.
- **Instruction files.** `.docs/status/project-instructions.md` is canonical;
  `CLAUDE.md` and `AGENTS.md` contain generated hash-bound Loom blocks and preserve
  owner text. → ADR 0018; specs 06, 08.
- **Helper discovery.** Workflows resolve the active installed plugin root and invoke
  explicit absolute helper paths. Bare `PATH` names are convenience only. → ADR 0018;
  specs 08, 10.
- **Hook boundary.** Both adapters normalize current `PreCompact.trigger`; each emits
  its client-documented blocking result and reports trust/activity. → ADR 0018; spec
  08.
- **Review mechanism.** Exact-SHA, network-silent `loom-local-review/v1` with three
  complete finder results replaces external reviewer commands. The code evaluator
  alone determines PASS/FAIL. → ADR 0021; specs 02–05, 08.
- **Evaluation claim and isolation.** Loom claims independent cold-agent evaluation
  with controlled inputs. Sanitized exports, disposable writable gate copies, and a
  deterministic recorder replace prompt-only blindness and evaluator checkout writes.
  → ADR 0022; specs 02–05.
- **Landing authority and finalize ownership.** A deterministic landing flow prepares
  finalization in a remote-based disposable candidate. Only verified configured remote
  publication makes it `Landed`; local `main` is a cache. → ADR 0020; specs 03, 04.
- **Runtime and release.** Bash 3.2+, Ubuntu/macOS, explicit dependencies and client
  floors, atomic SemVer surfaces, and `v0.2.0` gates are fixed. → ADR 0019; specs 08,
  10.
- **Specs and migration.** Approved specs are frozen; Unaligned-bare creates reviewed
  descriptive specs, while Unaligned-migrate preserves prior status behind a named
  owner gate. → ADRs 0005, 0009; specs 01, 03, 06.
- **Round, escalation, and gate rules.** Five lifetime merits FAILs escalate; infra
  blocks do not consume rounds; every red/unerunnable gate blocks advancement. → ADRs
  0013, 0017, 0022; specs 03–05.

## Evidence-dependent questions (not frozen design; after M7)

- **Workflow proportionality.** Post-M7 benchmark evidence must precede any Light/Standard/
  Strict profile decision, including whether a cheaper research-evaluation mapping or
  reduced finder set is acceptable.
- **Landing history shape.** Post-M7 benchmark and repository-usage evidence must precede a
  choice among granular, squash, or retained audit-ref target history.

Until that evidence and a later accepted decision exist, Loom uses the single rigorous
lifecycle in specs 02–05 and makes no profile or history-shape promise.
