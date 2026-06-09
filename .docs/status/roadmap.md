# Roadmap

Status: Living

Milestone order for building loom. "What's next and why"; detailed status in
`progress.md`, restart context in `handoff.md`.

## M0 — Design (complete)

- [x] Foundational design conversation with the owner.
- [x] Scaffold the loom repo and `.docs/`.
- [x] Draft the spec spine (`.docs/spec/00`–`10`).
- [x] Research plugin/agent/marketplace mechanics; resolve Q1–Q3, Q14.
- [x] Promote firm decisions to ADRs 0001–0006.
- [x] Owner final review of revised spec + ADRs — all 10 specs blind-reviewed
  Draft→Approved (5 fixed for real drift), `09`/`README` set Living; ADRs 0007
  (namespaced surface) + 0008 (parallel-docs coordination) authored and Accepted.

**M0 complete.** Design spine reviewed and frozen; ADR set through 0008 Accepted.

## M1 — Minimum loop (hand-built, sequential)

- [x] Resolve build-time questions: OQ-D (namespacing), OQ-E (marketplace root),
  OQ-F (helper portability).
- [x] Plugin scaffolding: `marketplace.json` + `plugins/loom/.claude-plugin/plugin.json`,
  `commands/`, `agents/`, `skills/loom-playbook/`.
- [x] Five role agents (`agents/*.md`) with tier + tools per ADR 0002 / spec 02.
- [x] `/loom` orchestrator command: init detection, scope + gate prompts, driver
  loop, dispatch table, commit-per-handoff.
- [x] Playbook: `.docs/` templates, status machine, role rubrics, Rust gate.
- [x] Blind-evaluation input contract enforced in evaluator prompts.
- [x] Install + `/plugin validate`; confirm command/agents load (namespaced
  `/loom:<name>`, `loom:<role>`).
- [x] One end-to-end sequential slice on a throwaway target (slugify sandbox):
  plan → blind plan-eval (PASS) → develop+gate → blind code-eval (PASS) → finalize.

**M1 complete.** First-run finding: agents could set a stray git identity
(`loom@localhost`) — fixed in the playbook commit-convention (roles must not
override `user.*`). Next: M2 (init modes / gate learning).

## M2 — Init modes & gate learning

- [x] **Detection classifier** — `init-detection.md` added as the single
      authoritative source; concrete "loom-shaped" and "empty/near-empty"
      definitions; all four call sites repointed (5fef2ed). Detection is done.
- [x] **Per-mode behaviors** — Greenfield (a58ff7e), Unaligned (e83e219),
      Initialized (b0bd3e9) behavior bodies all landed; classifier consumed by all
      three; per-mode trio complete.
- [x] **Gate establishment** — Rust verified gate in `gates/rust.md`; unknown-stack
      gate-learning mechanism in `references/gate-learning.md` (inspect → propose →
      owner-confirm → run-green-once → record `gates/<stack>.md` + project
      `CLAUDE.md`; UNVERIFIED until green; landed b2463c4).
- [x] **Idempotent playbook re-application** — auto-apply clean, recommend for
      conflicts, never clobber; single-sourced in `initialized.md` Step 3 (b0bd3e9).

**M2 complete.** All four items delivered. Deferred follow-up: `gates/shell.md`
(a first concrete learned gate for shell-stack projects — mechanism is in place;
`gates/shell.md` should be produced by running the mechanism on a real shell
project). Next: M3 (parallelism).

## M3 — Parallelism (complete)

- [x] **OQ-A resolved** — ADR 0008 Accepted: `.docs/` coordination model for
      worktree-per-slice decided (living docs + slice-plans index orchestrator-owned/
      main-only/serialized; per-slice plan/eval/code branch-local + uniquely named;
      serial merge+finalize on main; `index.lock` backoff; stateless identity-guard hook).
- [x] **Parallelism behavior specified and landed** — `references/parallelism.md`
      authored (single authoritative operational body per ADR 0008: create→work→land→
      cleanup workflow, `.docs/` coordination model, concurrency safety, slicer-
      independence rule); guards in `orchestration.md` + `run.md` relaxed (M1 absolute
      "one slice in flight" → available/owner-opts-in); `SKILL.md` + root `CLAUDE.md`
      updated (landed c6ec48e).
- [x] **Live demonstration** — 2 developer agents ran in parallel worktrees
      (`slice-casing` / `slice-reverse`), each touching a disjoint module, each
      running the full cargo gate green independently (commits f66aeca, fb71dad);
      serial land → master with no conflicts; integrated gate green (21 unit +
      2 doc-tests). Disjoint-file invariant and conflict-free-by-construction model
      confirmed in practice.

**M3 complete.** ADR 0008 + `references/parallelism.md` worktree-per-slice model
proven end-to-end. Next: M4 (Dogfooding & hardening).

## M4 — Dogfooding & hardening

- [ ] loom manages its own development end to end.
- [ ] Best practices propagated into root/project `CLAUDE.md` automatically.
- [ ] Owner approval gates, round limits/escalation polished.
- [ ] Resume-after-interruption verified across machines.
- [ ] `claude -p` fallback evaluated if deeper nesting is needed.
