# Architecture Decision Records

Numbered, durable decision records. Authored by the **planner**, approved by the
**plan evaluator** (or owner).

An accepted ADR is **immutable**: if a decision becomes wrong, write a new ADR that
marks the old one *superseded* — never rewrite history. Living architecture text
belongs in `../spec/`, not here.

Naming: `NNNN-short-title.md`. Lifecycle: `Draft → Plan Review → Accepted` (see
[../spec/03-artifact-lifecycle.md](../spec/03-artifact-lifecycle.md)).

## Accepted

- [0001 — Plugin Architecture & Orchestrator Model](0001-plugin-architecture-and-orchestrator.md)
- [0002 — Model Selection by Tier](0002-model-selection-by-tier.md)
- [0003 — File-Based Cold Handoffs with a Commit per Handoff](0003-cold-handoffs-commit-per-handoff.md)
- [0004 — Blind Evaluation by Controlled Inputs & Role Separation](0004-blind-evaluation-role-separation.md)
- [0005 — Specs Frozen After Approval; Change Only via Planning](0005-specs-frozen-after-approval.md)
- [0006 — Distribution as a Single-Plugin Self-Marketplace](0006-distribution-self-marketplace.md) — plugin-root location superseded by 0025 (implemented reality is the `./plugins/loom` subdir); rest of 0006 stands
- [0007 — Namespaced Command Surface](0007-namespaced-command-surface.md) — supersedes the bare-`/loom` command-naming in 0001
- [0008 — Parallel `.docs/` Coordination for Worktree-per-Slice](0008-parallel-docs-coordination-worktree-per-slice.md) — resolves OQ-A; builds on ADR 0003/0001
- [0009 — Unaligned-migrate Sub-mode](0009-unaligned-migrate-sub-mode.md) — refines spec 06 §2 Unaligned; builds on ADR 0001/0005
- [0010 — Orchestrator-Run Automated Review Feeds the Blind Code-Evaluator](0010-orchestrator-run-automated-review-in-code-eval.md) — adds automated review to the code-review phase; builds on ADR 0001/0004/0002/0003/0008 — **command identification corrected by 0011** (`/review` → `/code-review`)
- [0011 — Correct the Automated-Review Command to `/code-review`](0011-correct-automated-review-command-to-code-review.md) — supersedes ADR 0010 **only** on the command (`/review` is PR-bound → use the local-diff `/code-review`) and adds the commit-range invocation detail; rest of 0010 stands
- [0012 — Thin Orchestrator: `sonnet` Default + Bounded Role-Return Contract](0012-thin-orchestrator-sonnet-default-bounded-return.md) — **extends** ADR 0002 (adds the orchestrator tier row) and builds on ADR 0001/0003/0004/0010/0011; keeps the orchestrator's context flat via pass-references-not-bodies + a bounded return contract
- [0013 — Starvation-Loop Guards for the Orchestrator Cold-Restart](0013-starvation-loop-guards-cold-restart.md) — builds on ADR 0012/0003/0010/0011; write-ahead checkpoint + restart-before-big-op + forward-progress escalation + lossless-beats-lossy, plus a follow-on PreCompact mechanical-backstop slice
- [0014 — Multi-Session Worktree Coordination](0014-multi-session-worktree-coordination.md) — **extends** ADR 0008 (single-orchestrator "serialized on main" → cross-session lock + slice-lease for N concurrent `/loom:run` sessions); builds on ADR 0001/0003/0012/0013 (relocates ADR 0013's write-ahead cold-restart anchor to off-`main` per-session state) — **liveness signal superseded by 0015** (worktree-membership/pid → lease-renewal heartbeat); **lock/claim *mechanism* superseded by 0016** (mkdir-CAS → git `update-ref` CAS); rest of 0014 stands
- [0015 — Lease-Renewal Heartbeat as the Liveness Signal](0015-lease-renewal-heartbeat-liveness.md) — supersedes ADR 0014 on the **liveness signal only** (worktree-list membership / ephemeral pid → lease-freshness heartbeat within the TTL; a session that stops renewing becomes reclaimable); rest of 0014 stands; builds on ADR 0014/0001/0003
- [0016 — Git-Native Ref Compare-and-Swap as the Lock/Claim Substrate](0016-git-native-ref-cas-lock-mechanism.md) — supersedes ADR 0014's lock/claim **mechanism** only (mkdir-CAS + rename-capture + TSV registry → git `update-ref` CAS on `refs/loom/lock` + `refs/loom/claims/*`); keeps ADR 0014 coordination model + ADR 0015 lease-freshness liveness; builds on ADR 0014/0015/0001/0003. Eliminates review defects U1/U4 and fixes U3 by heartbeating the lock ref; carries U2/U5/U6 + secondary forward as re-implementation obligations.

- [0017 — Infrastructure-Blocked Escalation, Degraded-Review Honesty, and Incremental-Commit Discipline](0017-infrastructure-blocked-escalation.md) — builds on ADR 0013 (write-ahead checkpoint + pause+summary escalation machinery), 0010/0011 (review faithfulness invariant), and 0012 (bounded return); adds a third escalation *type* for account-level infrastructure blocks (spend/usage/quota, 429, 5xx, classifier-unavailable, limit-crashed sub-agents) — detect-on-failure + graceful-pause, **not** round-counted — plus degraded-review honesty (a limit-killed review is INVALID, never `ran-clean`) and developer incremental-commit discipline. Supersedes none.
- [0018 — Shared Portable Core with Claude Code and Codex Adapters](0018-shared-core-and-client-adapters.md) — partially supersedes Claude-only architecture/surface assumptions in ADRs 0001, 0002, 0006, and 0007
- [0019 — Supported Runtime, Platforms, Compatibility, and Release Contract](0019-supported-runtime-and-release-contract.md) — chooses Bash, Ubuntu/macOS support, pinned client compatibility, and SemVer *Superseded in part by ADR 0032: §2 and §5 (CI clause) for v0.2.0/v0.3.0; body unchanged.*
- [0020 — Remote Publication Is the Landing Authority](0020-remote-publication-is-the-landing-authority.md) — partially supersedes ADR 0014's shared-local-`main`, no-push landing model
- [0021 — Loom-Owned Local Review Protocol](0021-loom-owned-local-review-protocol.md) — replaces ADR 0010/0011's external review-command dependency while preserving evaluator verdict authority
- [0022 — Controlled-Input Independent Evaluation and Its Isolation Boundary](0022-controlled-input-independent-evaluation.md) — corrects ADR 0004's overbroad blind-evaluation claim and defines the sanitized boundary
- [0023 — Repository Self-Hosting Bootstrap Transition](0023-repository-self-hosting-bootstrap-transition.md) — authorizes the protected, append-only transition used while Loom's review, evaluation, and remote-publication machinery becomes self-hosting
- [0024 — macOS-First Dual-Client Dogfood Bootstrap Amendment](0024-macos-first-dual-client-dogfood-bootstrap-amendment.md) — authorizes one exact transition amendment and two named Apple-silicon macOS dogfood slices without changing the v0.2 release gate *Superseded in part by ADR 0032: §1 status vocabulary; and by ADR 0033: §6/§7 ongoing obligations; body unchanged.*
- [0025 — Reconciliation Authority: Plugin-Root Supersession and No-Bypass §7 Target Landing](0025-reconciliation-authority-plugin-root-no-bypass-landing.md) — **supersedes ADR 0006** on the plugin-root location (re-decides the implemented `./plugins/loom` subdir; directs restoring 0006's pre-rewrite body); establishes that every commit advancing `origin/main` lands through ADR 0023 §7 with no direct-push bypass class, and **narrowly amends ADR 0023 §1/§6/§7** to add a persistent `docs-governance/v1` slice class (blind plan-eval + cold docs code-eval + gate as its §7 evidence, no finder package); self-bootstraps via cold plan-eval + owner acceptance gate. **Narrowly superseded by ADR 0026** on the `docs-governance/v1` path allowlist only (§B.2) — everything else in this ADR stands.
- [0026 — Broaden `docs-governance/v1` to Cover Plugin Prompt/Documentation Markdown](0026-docs-governance-plugin-prompt-doc-scope.md) — **narrowly supersedes ADR 0025 §B.2's path allowlist only** (everything else in 0025 stands): broadens the `docs-governance/v1` class's path capability to admit non-executable prompt/doc Markdown under `plugins/loom/` (`plugins/loom/**/*.md` — skills/roles/agents/commands/references), preserving all hard exclusions (no `*.sh`/`bin/*`/hooks/`*.bats`/`*.json`/`scripts/**`/behavior). Strengthens the docs code-eval to confirm no behavior/executable change and that `scripts/validate-repository.mjs` passes; self-bootstraps via cold plan-eval + owner acceptance + one §6 successor recording a **capability** amendment (`allowed_slices` UNCHANGED — no new token).
- [0027 — Ambient Model Inheritance, Model Matrix Modernization, and Dogfood Antigravity Adapter](0027-client-model-matrix-modernization-and-ambient-inheritance.md) — **partially supersedes ADR 0002 and ADR 0018 §3**: authorizes ambient model inheritance as default with optional pinning; role-profile reasoning effort policy; ratifies Antigravity as private dogfood runtime adapter; schedules spec 02/10 amendments. *Superseded in part by ADR 0032: §4 (Antigravity dogfood status); body unchanged.*
- [0028 — Landing History Policy](0028-landing-history-policy.md) — `Accepted`; extends ADR 0020: squash on the target with granular slice commits and tracked `.docs/` evidence as a provisional default to test; integration and cleanup by checked-tree equivalence and receipt binding, not slice-head ancestry.
- [0029 — Herdr Client Adapter and Native App Support](0029-herdr-client-adapter-and-native-app-support.md) — `Accepted`; extends ADR 0018 and ADR 0027: authorizes Herdr as supported client adapter, defining manifest, root binding, matrix, and launch integration.
- [0030 — Herdr Native App Lifecycle and Event Hooks](0030-herdr-native-app-hooks.md) — `Accepted`; extends ADR 0003, ADR 0013, ADR 0018, and ADR 0029: authorizes Herdr native app lifecycle and event hook contracts, manifest hook discovery, multi-client dispatcher resolution, and provisional block wire envelope.
- [0031 — Herdr as an hc-Driven Client](0031-herdr-as-an-hc-driven-client.md) — `Accepted`; supersedes in part ADR 0029 and ADR 0030, extends ADR 0018 and ADR 0027: Herdr is a launch host driven through `hc` (no plugin, marketplace, root binding or Herdr-installed hooks); retires the Herdr files; blind-review requirement blocks `hc` evaluators; M9 reopened.
- [0032 — Release Client Mapping and Retirement of the Dogfood Support Tier](0032-release-client-mapping-and-retirement-of-dogfood-tier.md) — `Accepted`; v0.2.0 = macOS + Claude Code + Codex, v0.3.0 = Antigravity + Orca + Herdr (`hc`) on macOS, v0.4.0 = Ubuntu and other OSes; retires dogfood tier; per-(platform, harness) supported definition and evidence; supersedes ADR 0019 Ubuntu matrix clauses; supersedes ADR 0019 §2 and §5 (CI clause) for v0.2.0/v0.3.0, ADR 0027 §4, and ADR 0024 §1 status vocabulary (those ADR bodies are unchanged).
- [0033 — Narrow the v0.3.0 Scope, Prioritize v0.2.0 Live Proof, and Retire the macOS Checkpoint Tooling](0033-narrow-v0.3-scope-and-retire-macos-checkpoint-tooling.md) — `Accepted`; supersedes ADR 0032 §1 (five-pair v0.3.0 set) and §6 (rotation text only where it depends on it) and ADR 0024 §6/§7 ongoing obligations; v0.3.0 becomes evidence-admitted pairs only; Antigravity, Orca, Herdr deferred; retires the macOS checkpoint harness.

## Path and cross-reference errata (ADR 0025 reconciliation)

Living-index corrections to stale paths/quotes cited by accepted (immutable) ADR
bodies. The ADR decision prose is left untouched; the shipped reality is recorded
here instead.

- **Helper path.** ADRs 0015 (lines 17, 309) and 0016 (line 255) reference
  `plugins/loom/lib/loom-coord.sh`; the shipped helper is
  `plugins/loom/bin/loom-coord` (verify: `rg -n "loom/bin/loom-coord"
  plugins/loom/`).
- **Per-session state dir.** ADRs 0014 (line 105), 0015 (lines 108, 250), and 0016
  (lines 176, 258) reference `.git/loom-session-<id>/`; the shipped layout is
  `.git/loom/session-<id>/`.
- **0016 misquotes 0015.** ADR 0016 line 187 attributes to ADR 0015 the phrase "the
  lock must be heartbeat too"; that phrase does not appear in ADR 0015 (verify:
  `rg -n "lock must be heartbeat" 0015-*.md` → no match). The substance —
  heartbeating the lock ref — is 0016's own contribution, not a 0015 quote; this is
  a misattribution erratum, not a substantive defect.
