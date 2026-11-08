# Roadmap

Status: Living

Milestone order for building loom. "What's next and why"; detailed status in
`progress.md`, restart context in `handoff.md`.

Current milestone: M9

## Repository improvement program (2026)

- [x] **M0 — Establish a trustworthy baseline** (complete):
  `ci-baseline`, `client-floor-adapter-smoke`, `macos-dogfood-program-amendment`, and
  `macos-dual-client-dogfood` (settled publication of reproducible local gate, four-cell
  hosted CI, static Claude Code/Codex compatibility contracts, Apple silicon dogfooding).
- [x] **M1 — Fix coordinator safety** (complete):
  `coord-identifier-boundaries` (centralized identifier validation — session IDs, decoded-blob
  sids, PIDs, slice names; settled at `00582aa`), `coord-lock-ownership` (centralized ownership,
  re-adoption, forced-race recovery), and `coord-schema-cas` (fail-closed null-SHA CAS schema init).
- [x] **M2 — Make remote publication the landing boundary** (complete):
  `landing-authority-and-modes` (ADR 0020), `remote-first-integration-candidate` (`plugins/loom/bin/loom-land`,
  push-destination verification, receipt binding), and `coordination-state-separation` (clean tracked main,
  untracked session manifest, candidate finalization).
- [x] **M3 — Repair hook enforcement and write-ahead semantics** (complete):
  `identity-guard-contract` (`git-identity-guard.sh` raw-command scanning, `loom-verify-identity` post-command
  verifier), and `precompact-per-session` (per-session write-ahead markers, checkpoint digests, atomic logging).
- [x] **M4 — Replace external review commands** (complete):
  `local-review-protocol` (ADR 0021 / ADR 0022), `local-review-helper` (`plugins/loom/bin/loom-review`),
  `local-review-agents` (versioned immutable finder prompts under `plugins/loom/finders/`), and
  `local-review-orchestration` (operationalized `loom-review` in `loom-run`, `orchestration.md`,
  `review-findings.md`, `code-eval-rubric.md`, and `SKILL.md`, removing GitHub/PR/remote dependencies).
- [x] **M5 — Make the evaluation trust model accurate** (complete):
  `[x] evaluation-trust-model` (ADR 0022 accepted claim "independent cold-agent evaluation with controlled inputs");
  `[x] sanitized-evaluation-workspace`; `[x] evaluation-gate-runner`; `[x] evaluation-output-recorder`.
- [x] **M6 — Turn prose invariants into executable checks** (complete):
  `[x] loom-doctor-foundation`; `[x] docs-state-validator`; `[x] living-doc-shape`.
- [x] **M7 — Reconcile packaging and publish a release** (complete):
  `[x] packaging-conformance`; `[x] readme-refresh`.
- [x] **M8 — Control process cost and repository noise** (complete):
  `[x] workflow-benchmark`; `[x] workflow-profiles`; `[x] landing-history-policy`.
- [ ] **M9 — Client compatibility: Herdr and native app integration** (in progress):
  - Landed 2026-11-08: M9 / v0.3.0 Slice 2: `hc-live-probe` (generic live probe script `scripts/hc-live-probe`, offline Bats suite `scripts/tests/hc-live-probe.bats`, 20/20 tests passing under Bash 3.2, 260 LOC budget respected); passed plan evaluation Round 3 (PASS) and blind code evaluation Round 5 (PASS via OpenAI Codex `gpt-6.1-terra`); live probe executed with scratch evidence recorded; plan archived.
  - Landed 2026-11-08: M9 / v0.3.0 Slice 1: `hc-host-adapter` (`loom-host-hc` observation/cleanup helper, v0.3.0 matrix `hostFloors` registration, `loom-host-binding-v1` schema, fixture, and repository validator); passed plan evaluation Round 3 (PASS) and blind code evaluation Round 4 (PASS via OpenAI Codex `gpt-6.1-terra`); plan archived.
  - Accepted 2026-11-08: ADR 0034 (Admit Antigravity, Orca, and Herdr (`hc`) to v0.3.0 scope and settle evaluator governance): admits Antigravity, Orca, and Herdr to v0.3.0 scope under ADR 0033 §1; settles host evaluator governance by restricting `hc`/Orca to authoring/interactive host roles and delegating evaluation to cold, isolated workspaces with certified model clients; un-shelves `hc-host-adapter` and `hc-live-probe`.
  - Landed 2026-11-07: `codex-launch-schema-fix` (v0.2.1 preparation): removed `--output-schema` from `codex exec` in `loom-launch-role`, allowing native unwrapped role execution; plan archived.
  - Landed 2026-11-07: v0.2.0 live proof complete; release tag `v0.2.0` and evidence record published to `origin/main` (ADR 0032 E1–E5, ADR 0033 D3).
  - Landed 2026-11-07: `release-conformance-and-evidence-schema`: v0.2.0 release-evidence schema (`loom-release-evidence/v1`) and chain validator, macOS-only CI runner/docs alignment (G4, G5; ADR 0032 §3, §8); plan archived.
  - Landed 2026-11-06: `launcher-matrix-and-rotation-fix`: `loom-launch-role` binds the release compatibility matrix (0.2.0 default) and the default rotation is two clients (claude ↔ codex), without Antigravity; plan archived.
  - Landed 2026-11-06: `instruction-adapter-sync`: instruction digest and derived blocks aligned with ADR 0032 §2; drift now fails `--all`.
  - Landed 2026-11-05: `dogfood-retirement` (ADR 0033 D1): macOS checkpoint tooling retired.
  - Landed 2026-11-05: `herdr-surface-retirement` (4 of 4): Herdr plugin surfaces retired.
  - Landed 2026-11-02: `hc-guard-deny-policy` (1 of 4). `hc-host-adapter` and `hc-live-probe` un-shelved per ADR 0034.
  - **ADR 0034 Implementation Order:** (1) `hc-host-adapter`, (2) `hc-live-probe`, (3) `orca-host-adapter`, (4) `antigravity-model-adapter`. Slices 1–3 use certified CLI evaluators per ADR 0034 §2.
  `[x] herdr-client-adapter`, `[x] herdr-native-app-hooks`, and `[x] herdr-verification` (add support
  for Herdr and its new native application: client adapter contracts, root bindings, role launch
  mappings, event hooks, and integration verification). All three slices landed (offline fixture verification only); live Herdr and native-app execution evidence is separate owner-run work and remains outstanding.

## Next: v0.3.0 Harness Delivery (ADR 0034, Accepted 2026-11-08)

Order of work: (1) `hc-host-adapter` (`plugins/loom/bin/loom-host-hc` and `.docs/slice-plans/hc-host-adapter.md`), (2) `hc-live-probe`, (3) `orca-host-adapter`, (4) `antigravity-model-adapter`. Evaluator governance is settled by ADR 0034 §2: host harnesses run interactive roles, while evaluators execute in cold, isolated POSIX workspaces using certified model CLI clients (`codex` or `claude`). Conformance is verified for Claude Code CLI and Codex CLI on macOS 14+ Apple silicon under ADR 0032 E1–E5. The next action is to implement `hc-host-adapter`.

M0 is authoritative at settled remote result `51b249e`. The program-amendment
checkbox is prospective until its configured remote target and protected transition
settlement verify the exact publication; `macos-dual-client-dogfood` is now settled
(ADR-0023 receipt; result `2a4700d`, target `main`). ADR 0019's Ubuntu and both macOS
architecture release matrix remains unchanged and mandatory; this checkpoint is a
private Apple-silicon dogfood milestone only, not a public release or public Codex
support.

**M0 Landed — precise scope.** M0 covers a static reproducible local-gate baseline plus
a macOS-arm64 behavioral dogfood pass; the Codex cold-launch leg is
`infrastructure-blocked` (a credential-less isolated `CODEX_HOME` by design), not a
product defect. Ubuntu/Intel release obligations and public Codex support are **not**
covered by M0 — they remain owed by ADR 0019 at release. See `.docs/status/progress.md`
§ "M0 errata" for the full early-stretch process record.

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
