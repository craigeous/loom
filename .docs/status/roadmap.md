# Roadmap

Status: Living

Milestone order for building loom. "What's next and why"; detailed status in
`progress.md`, restart context in `handoff.md`.

## Repository improvement program (2026)

- [x] M0 `ci-baseline` — prospective atomic publication of the reproducible local
  gate, four-cell hosted CI, and static Claude Code/Codex compatibility contracts.
- [ ] `macos-dogfood-program-amendment` — synchronize the accepted macOS-first
  authority into the improvement plan, frozen specs, indexes, and instruction digest.
- [ ] `macos-dual-client-dogfood` — prove real clean install/reinstall, discovery,
  workflows, roles, hooks/trust, helper-root behavior, and uninstall on Apple silicon.

The first checkbox becomes authoritative only when the configured remote target and
protected transition settlement verify the exact publication candidate. M0 remains
release-incomplete until its required behavioral adapter evidence is green; ADR 0019's
Ubuntu and both macOS architecture release matrix is unchanged.

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

**M2 complete.** All four items delivered. Deferred follow-up: ~~`gates/shell.md`~~
**DONE** — produced as M4 dogfooding via the gate-learning mechanism on loom's own
hook (shell-gate slice, commit 34de27c, gate green 28/28; `gates/shell.md`
Status: Verified). Next: M3 (parallelism).

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

## M4 — Dogfooding & hardening (complete)

- [x] **loom manages its own development end to end** — demonstrated continuously across
      this session: every change (ADR-0008 fold into specs 04/08; shell gate; round-limit
      polish; identity-guard hardening; CLAUDE.md auto-propagation) ran the full blind loop
      — research/plan → blind plan-eval → develop + gate → blind code-eval → finalize →
      archive — through the orchestrator. Real defects were caught pre-merge (a planted
      security regression, an identity-forge, false-claimed verification, recurring spec
      violations), and the round-limit escalation fired correctly at the cap. The
      orchestrator only routed + verified; roles did all authoring/evaluation.
- [x] **Best practices propagated into root/project `CLAUDE.md` automatically** —
      the developer finalize pass now maintains `CLAUDE.md` as a curated digest
      (spec 03 finalize step + spec 08 boundary: durable conventions / repo-layout /
      gates / read-first pointers; per-slice history stays in `progress.md`; root +
      managed-project). Spec amended (Cycle 1) + playbook conformance landed (Cycle 2);
      the Cycle-2 finalize applied the rule to itself.
- [x] **Owner approval gates, round limits/escalation polished** — round-limit
      semantics tightened (FAIL-only counting, one cross-phase counter per artifact,
      reset rule) + escalation pause+summary contract defined in spec 03 (Cycle 1),
      playbook brought into conformance so evaluators stop numbering PASSes (Cycle 2),
      and the machinery verified by a live 5-round stress-test that escalated correctly
      at the 5th FAIL with a full summary.
- [x] **Resume-after-interruption verified across machines** — fresh clone (no local
      state) reconstructs full project state purely from committed `.docs/` + git:
      init-detection → Initialized; `handoff.md`/`progress.md`/`roadmap.md` give
      current status + next step; git log + clean tree + no active slice-plans = a
      clean resume point; git identity correctly falls back to global in a fresh clone
      (and the new init identity-verify step guards a config-less machine). The scan
      surfaced + fixed one latent finalize bug (an archived plan left at `Status:
      Landed` instead of `Archived` — a naive resume could have mistaken it for
      in-flight work).
- [x] **`claude -p` fallback evaluated — not needed; closed.** Across M1–M4
      (sequential and parallel slices, dozens of role spawns) the
      orchestrator-spawns-all + worktree-per-slice model was sufficient; no role
      ever needed to spawn a peer, so deep nesting never arose. `claude -p` remains
      a **documented reserve** in spec 04 (no implementation built). Revisit only if
      a concrete role-spawns-peer need emerges.

**M4 complete.** loom is dogfooded end-to-end and hardened: it builds and reviews its
own changes through the blind loop, keeps `CLAUDE.md` current automatically, enforces a
uniform author-neutral identity, bounds thrashing with a tested escalation, and resumes
from committed state on a fresh machine. An emergent hardening item also landed this
milestone — **identity-verification hardening** (init verifies a real git identity;
agents verify it after committing) — closing the recurring `loom@localhost` fallback.
All M0–M4 milestones are now complete; the spec spine (00–10) is Approved/Living and the
ADR set runs through 0008.
