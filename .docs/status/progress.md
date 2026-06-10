# Progress

Status: Living

The status source of truth and decision index for building loom.

## Current state

- **Phase:** **M4 (Dogfooding & hardening) in progress.** M0–M3 complete.
- **Last action:** **CLAUDE.md auto-propagation — Cycle 1 (spec) Approved** (specs 03 + 08
  amended, commit 56e1a8d, plan-eval `claude-md-autopropagation-amendment-eval.md` PASS
  round 0, owner-approved). Spec 03's finalize pass now includes a step where the developer
  updates the relevant `CLAUDE.md` **only when the landed slice changed something in the
  curated-digest scope** (durable conventions, repo-layout facts, gate definitions,
  read-first pointers) — explicitly a derived non-spec digest, so the "no spec edit at
  landing" rule + ADR 0005 stay intact. Spec 08 defines the curated-digest boundary
  (incl. per-slice history stays in `progress.md`; covers root + managed-project CLAUDE.md;
  specs win on conflict). One non-blocking MINOR recorded (spec 08 template bullet lacks a
  forward-link to the new subsection). **Next:** Cycle 2 — playbook-conformance slice
  (developer.md finalize step + Greenfield managed-project CLAUDE.md guidance).
- **Prior action:** **`identity-verification-hardening` slice landed** (commit a816979,
  code-eval PASS round 0). Closed two structural gaps that allowed agents to commit under
  a forged/fallback identity: (A) `greenfield.md` now has a new "Ensure a git identity is
  configured" step (establish-or-stop, renumbered Step F; Unaligned and Initialized resume
  paths carry verify-only pointer to it) — making `commit-convention.md`'s "init ensures
  an identity exists before any role commits" claim structurally true; (B) a "Verify after
  committing" sub-point added to `commit-convention.md` (`git show -s --format='%an <%ae>'`
  + conditional `--amend --reset-author` as the one sanctioned self-correction; last-line
  stop if no identity configured) — all five agent prompts (`researcher.md`, `planner.md`,
  `plan-evaluator.md`, `developer.md`, `code-evaluator.md`) carry a one-line pointer to it.
  Single-source discipline: full procedure once in each location; no agent re-pastes it.
  **This addresses the recurring `loom@localhost` M4 finding** — the identity fallback gap
  is now closed structurally. (The orchestrator also set a repo-local git identity as a
  separate one-off environment mitigation; that is independent of this slice's code change.)
  Slice `identity-verification-hardening` archived.
- **Prior action:** **M4 escalation thread COMPLETE — live 5-round stress-test passed.**
  Roadmap item "owner approval gates, round limits/escalation polished" is now done.
  The test used a throwaway fixture outside loom's repo (`/Users/craig/git/loom-escalation-test/`,
  since removed): a slice-plan whose goal (developer edits the frozen spec at landing)
  inherently violates ADR 0005 / spec 03, with a seeded 3-FAIL history. Two **live blind
  plan-eval** passes then ran on cosmetic revisions: each FAILed on the same recurring
  BLOCKER and **continued the counter (3 → 4 → 5, not restarting)** — confirming the
  Cycle-2 evaluator-prompt fix works in real agents. At the 5th FAIL the orchestrator
  **halted instead of dispatching a 6th revision** and produced the full spec-03
  escalation summary (stuck artifact + Draft status; per-round findings history 1..5;
  **recurring/thrashing** classification; four owner options). End-to-end the corrected
  machinery fired correctly. This closes Cycles 1 (spec 03 amendment) + 2 (playbook
  conformance) + the live test.
- **Prior action:** **Playbook conformance landed — Cycle 2 of the M4 escalation
  thread** (`round-limit-conformance` slice, commit f161fa0, code-eval PASS Round 0).
  The playbook now matches spec 03's amended FAIL-only round-counting rule across all
  five files: `status-machine.md`, `orchestration.md`, the eval template, and — the
  key behavioral fix — both evaluator agent prompts (`plan-evaluator.md`,
  `code-evaluator.md`). The evaluator prompts previously numbered every eval pass
  sequentially (FAIL→PASS→PASS = R1→R2→R3); they now increment `Round:` **only on a
  FAIL**, a resolving PASS repeats the FAIL's round number, and a fresh artifact's
  first review is round 0. `run.md` updated to name FAIL cycles explicitly. All files
  link to spec 03 as single-source authority; no divergent restatements. Slice
  archived. **M4 finding (identity-guard gap, recurrence):** during this slice the
  planner's first commit was forged as `loom <loom@localhost>` (the M1 identity bug,
  recurred). Corrected via `git commit --amend --reset-author` (→ d008bc3). Root
  cause: the identity-guard hook does not protect loom's own dev session — it only
  fires where loom is installed as an active plugin, and only catches override flags;
  it does not verify that the configured identity is the correct one. **Candidate
  hardening item:** (a) clarify "author-neutral" in `agents/*.md` and
  `commit-convention.md` to mean "use the repo's configured identity — never invent
  one"; (b) optionally activate the guard hook in loom's own dev worktree. **Next in
  this thread:** live 5-round stress-test against the corrected machinery.
- **Prior action:** **Round-limit/escalation spec hardened — Cycle 1 of the M4
  escalation thread** (spec 03 amendment, plan-eval `spec-03-round-limit-amendment-eval.md`
  PASS Round 1 + confirming re-review PASS, owner-approved; commits 5de67fd → df72df0
  → Approved). The `## Round limits` section now defines: **`Round:` counts
  reject→revise cycles ONLY** (a FAIL increments; a PASS that resolves a FAIL shares
  that round's number — correcting the prior practice of numbering every eval pass,
  e.g. shell-gate's R1-FAIL→PASS history is **1 round**, not 3); **one cross-phase
  counter per artifact** (plan FAILs + code FAILs accumulate toward the same 5);
  **reset** only owner-driven on materially-new direction at an escalation; and an
  **escalation pause+summary contract** (stuck artifact+status, per-round findings
  history, recurring-vs-new/thrashing classification, four owner options:
  redirect/abandon/override-and-accept/adjust-authority-or-rubric). The new rule got
  its **first live demonstration** in its own approval: the confirming re-review after
  the MINOR-fold was recorded at **round 0** (no FAIL ever opened a round).
- **Prior action:** **`shell-gate` slice landed** (commit 34de27c, code-eval PASS
  Round 3, gate green 28/28). First end-to-end exercise of the gate-learning
  mechanism on real code. Delivered: `plugins/loom/hooks/git-identity-guard.bats`
  (28-case bats suite covering 11 BLOCK / 14 ALLOW / 3 jq-fallback cases),
  `plugins/loom/skills/loom-playbook/gates/shell.md` (Status: Verified, mirrors
  rust.md shape), root `CLAUDE.md` Shell gate section (three concrete
  format/lint/test commands). Gate green: shfmt -i 4 -d exit 0, shellcheck exit 0,
  bats 28/28 pass. Plan-eval caught a real BLOCKER in Round 1 (jq-absent fallback
  recipe used a bare `sh` against a jq-free PATH — the interpreter itself would exit
  127); fixed Round 2 (absolute `/bin/sh` invocation). B10/B11 rows added to prove
  the documented read over-block explicitly. The deferred M2 follow-up `gates/shell.md`
  is now **DONE**. Slice archived.
- **Prior action:** **M4 dogfood run #1 — folded ADR 0008 into frozen specs 04 + 08**
  (commit c3cd354, plan-eval `adr0008-spec-fold-eval.md` PASS Round 1, approved by
  owner). Driven entirely through loom's own loop in **strict route-only** mode: the
  orchestrator only spawned roles and verified commits — the planner authored the
  amendment, a blind plan-evaluator PASSed it (one non-blocking MINOR: the
  concurrent-planning-stays-serial boundary is left to ADR 0008 + ADR 0005 rather
  than restated in spec 04), the owner signed off the frozen-spec change, and the
  orchestrator flipped both specs Plan Review → Approved and finalized living docs.
  Spec 04's Parallelism section now carries ADR 0008's coordination model (no longer
  an open question); spec 08 records the slice-plans-index ownership change. **First
  end-to-end M4 dogfood pass ran with zero orchestrator intervention into role work.**
- **Prior action:** **M3 live parallel demonstration** — 2 developer agents ran in
  parallel in separate worktrees (`slice-casing` on branch `slice-casing`,
  `slice-reverse` on branch `slice-reverse`), each isolated to its own disjoint
  module (`src/casing.rs` / `src/reverse.rs`), each running the full cargo gate
  green independently (slice commits f66aeca, fb71dad). Orchestrator serially
  landed both branches → master with no merge conflicts (disjoint-file invariant
  held). Integrated gate green: 21 unit tests + 2 doc-tests. Worktrees and
  branches cleaned up without stale entries. ADR 0008's conflict-free-by-
  construction model and the `references/parallelism.md` workflow are confirmed
  in practice. **M3 is complete.** Deferred follow-ups (non-blocking, carry
  forward): fold ADR 0008 into frozen spec 04/08 (deliberate spec-revision
  planning cycle); `gates/shell.md` (first concrete learned gate for
  shell-stack projects).
- **Prior action:** **`parallelism-behavior-body` slice landed** (commit c6ec48e,
  code-eval Round 2 PASS). Shipped: new
  `plugins/loom/skills/loom-playbook/references/parallelism.md` — the single
  authoritative worktree-per-slice operational body (ADR 0008): create→work→land→
  cleanup workflow, the `.docs/` coordination model (living docs + slice-plans index
  orchestrator-owned/main-only/serialized; slice branches carry only disjoint
  uniquely-named plan/eval/code; disjoint-by-construction invariant; fresh-origin/main
  freshness at spawn), concurrency safety (`index.lock` exponential-backoff retry,
  crash cleanup via `git worktree remove -f`/`prune`, one-branch-per-slice, stateless
  identity-guard hook), and the slicer-independence rule (disjoint source files +
  disjoint per-slice `.docs/` filenames; shared-source files → sequence, not
  parallelize). Guards in `orchestration.md` relaxed; `commands/run.md` updated;
  `SKILL.md` References list entry added; root `CLAUDE.md` updated. Slice archived.
- **Prior action:** **ADR 0008 — Parallel `.docs/` Coordination for
  Worktree-per-Slice — Accepted** (resolves OQ-A). This kicked off **M3
  (Parallelism)**. The decision: a hybrid coordination model — the three living
  docs (`roadmap.md`/`progress.md`/`handoff.md`) **and the slice-plans index
  (`slice-plans/README.md`)** live on **main only**, written **solely by the
  orchestrator** and serialized; each slice's uniquely-named plan file, eval file,
  and code live on its **slice branch**; landing is a serial merge+finalize from
  the main worktree, so concurrent independent slices write disjoint paths and
  cannot conflict on a `.docs/` file. Worktrees are created from fresh
  `origin/main` (input freshness at spawn — agents are cold and get focused
  inputs, no mid-flight status polling); concurrency safety via `index.lock`
  exponential-backoff retry, mandatory `git worktree remove -f`/`prune` cleanup,
  and the confirmed-stateless identity-guard hook. Builds on ADR 0003
  (author-neutral uniform identity) and ADR 0001 (orchestrator-only spawning),
  supersedes neither. OQ-A moved to Resolved in `09-open-questions.md`; grounding
  research note `2026-06-08-git-worktree-parallel-slices.md` set to
  `Status: Approved` (validated through the ADR's two review rounds). **Deferred
  follow-up:** fold this model into the frozen spec 04 Parallelism section (and
  spec 08 playbook guidance) via a deliberate planning cycle — see Open.
- **Prior action:** `gate-learning` slice landed (commit b2463c4, code-eval Round 2
  PASS). Shipped: new
  `plugins/loom/skills/loom-playbook/references/gate-learning.md` — the single
  authoritative body for the unknown-stack gate-learning mechanism (inspect toolchain
  → propose `format → lint → test` → owner-confirm → run-green-once → record
  `gates/<stack>.md` + project `CLAUDE.md`; UNVERIFIED until green; idempotent for
  stacks that already have a recorded gate). The three init bodies
  (`greenfield.md`, `unaligned.md`, `initialized.md`) had their stale
  "forthcoming/deferred" forward pointers replaced with live links to
  `gate-learning.md`. `SKILL.md` References list + Gates section updated; root
  `CLAUDE.md` Gate section + Repo layout updated. **M2 is now complete**: all four
  items done — Detection classifier (5fef2ed), Greenfield/Unaligned/Initialized per-
  mode behaviors (a58ff7e/e83e219/b0bd3e9), idempotent re-application (b0bd3e9), gate-
  learning (b2463c4). Slice archived.
- ~~**Deferred follow-up (M2, non-blocking):** `gates/shell.md`~~ **DONE** —
  produced as M4 dogfooding via the gate-learning mechanism on loom's own hook
  (shell-gate slice, commit 34de27c, gate green 28/28). See Last action above.
- **Prior action:** `initialized-init-behavior` slice landed (commit b0bd3e9, code-eval
  Round 2 PASS). Shipped: new
  `plugins/loom/skills/loom-playbook/references/initialized.md` — the single
  authoritative Initialized init behavior body (resume: state-derived menu derived
  from `.docs/` + git state mapped to the dispatch table in `status-machine.md`;
  scope + gates + driver-loop handoff; Q10 idempotent playbook re-application
  single-sourced here — auto-apply clean, recommend for conflicts, never clobber).
  Three call sites (`orchestration.md`, `run.md`, `init.md`) repointed at it;
  `SKILL.md` references list updated; `CLAUDE.md` updated. Slice archived. The
  **per-mode behavior trio** (Greenfield + Unaligned + Initialized) is now
  complete.
- **Prior action:** `unaligned-init-behavior` slice landed (commit e83e219, code-eval
  Round 2 PASS). Shipped: new
  `plugins/loom/skills/loom-playbook/references/unaligned.md` — the single
  authoritative Unaligned init behavior body (alignment pass: study repo, scaffold +
  gate by reusing `greenfield.md` Steps A–E, descriptive `spec/` back-fill with
  explicit no-decisions boundary, seed `status/`, leave project ready to resume as
  Initialized). Three call sites (`orchestration.md`, `run.md`, `init.md`) repointed
  at it; `SKILL.md` references list updated; `CLAUDE.md` updated. Slice archived.
- **Prior action:** `recommended-tooling-and-mechanical-checks` slice landed (commit
  db39d44, code-eval Round 2 PASS). Shipped: new
  `plugins/loom/skills/loom-playbook/references/tooling.md` (recommended CLI/LSP
  toolkit by role, all optional with fallback); "Invariants verified mechanically"
  bullet added to both `plan-eval-rubric.md` and `code-eval-rubric.md`; cross-links
  added to `SKILL.md` and the three agent files (`developer.md`,
  `plan-evaluator.md`, `code-evaluator.md`). Root cause of the two prior eval misses
  (eyeballing invariants — bare `/loom` and wrapped `Code\nReview` survived a read)
  is now addressed: the mechanical-check rule in both rubrics + `tooling.md`
  mandate `rg -U`/`yq`/`ast-grep`/LSP for any invariant assertion. Slice archived.
- **Prior action:** `author-identity-enforcement-guard` slice landed (commit a47bf95,
  code-eval Round 4 PASS, independently re-verified). Shipped:
  `plugins/loom/hooks/hooks.json` (PreToolUse hook config) +
  `plugins/loom/hooks/git-identity-guard.sh` (POSIX sh guard script, executable) +
  `plugins/loom/skills/loom-playbook/references/commit-convention.md` hardened to
  forbid all identity-override paths. 26-case acceptance matrix (6 BLOCK + 20 ALLOW)
  passed; jq-absent grep-fallback path re-verified. The deferred follow-up tracking
  the commit-identity guard gap (`--author=` / `GIT_AUTHOR_*` env vars) is now
  resolved (see Resolved below).
- **Prior action:** `retire-code-review-status-token` slice landed (commit a85885f,
  code-eval PASS). The obsolete `Code Review` status token has been removed repo-wide
  from `SKILL.md`, `status-machine.md`, `developer.md`, and the slice-plans README
  `Lifecycle:` string. All four lifecycle strings now read
  `… → Implemented → (code review) → Landed → Archived`, matching spec 03.
  The deferred follow-up tracking this work is now resolved (see Resolved below).
- **Prior action:** retroactive spec-approval pass completed. All ten content specs
  (00–08, 10) ran through blind plan-eval and are now `Status: Approved`, each with
  an eval record in `.docs/evaluations/spec-*-eval.md`. Several FAILed round 1 and
  were fixed before approval — evidence the blind review caught real drift:
  - **00** — loom called a "skill" not a "plugin"; bare `/loom` instead of
    `/loom:run`; stale status labels.
  - **01** — old "specs change at landing / fold back into specs" model corrected to
    the frozen-spec model (ADR 0005).
  - **02** — bare `/loom` → `/loom:run` plus 3 minors.
  - **03** — `Code Review` was a phantom first-class status; reconciled so the code
    evaluator dispatches off `Implemented`.
  - **10** — agent-frontmatter verified-fields list corrected to
    `name,description,model,color,tools`; M3 isolation/background reframed as
    forward-looking.
  - 04, 05, 07, 08 passed round 1.
  Spec `09-open-questions.md` and the spec `README.md` are not frozen designs and are
  now `Status: Living` (09 is a live OQ tracker; README is the spec index).
- **Prior action:** resolved the spec 06 §1 "empty" vs scaffold-metadata
  clarification: spec `06 §1` was amended and re-approved (blind plan-eval PASS,
  commit 86fa7d1, eval `spec-06-status-seed-clarification-eval.md`) to define
  "empty" as no design content — authorizing the scaffold metadata
  `greenfield.md` seeds. The prior code-eval MINOR is now closed.
- **Earlier:** M2 slice 2 (Greenfield init behavior body) landed.
  Both plan-eval and code-eval ran blind and independently: both PASS (code-eval
  Round 2 PASS at commit a58ff7e; the one MINOR — spec 06 §1 "empty" vs
  `greenfield.md` phase metadata — has since been resolved, see Prior action).
  Deliverable: `plugins/loom/skills/loom-playbook/references/greenfield.md` —
  the single authoritative Greenfield behavior body (scaffold + seed + CLAUDE.md +
  gate). Three call sites (`orchestration.md`, `run.md`, `init.md`) repointed at
  it; the Greenfield branch wired to the body. Slice archived.
- **M2 slice 1 (previously landed):** init-mode detection classifier in
  `plugins/loom/skills/loom-playbook/references/init-detection.md`. Four call
  sites repointed at it; divergent restatements removed. Archived at commit 5fef2ed.
- **Evaluator hardening (dogfooding):** a planted-defect battery (plan/spec
  contradiction, green-but-wrong code, misleading tests, scope creep) confirmed
  blind evaluators catch gate-invisible defects — all FAILed for the right reason.
  Added `references/severity.md` (single-source BLOCKER/MAJOR/MINOR → PASS/FAIL),
  repointed both rubrics + the evaluation template at it, and anchored the
  code-evaluator's verdict vocabulary on the template regardless of phrasing.
- **Red-gate discipline (dogfooding, fixed):** with a pre-existing out-of-scope
  test failure (red gate), the developer implemented its slice correctly but
  marked it `Implemented` anyway, rationalizing "pre-existing / out of scope" —
  violating the gate rule. The blind code-evaluator caught it (red gate = auto
  BLOCKER → FAIL), so a red slice can't land, but the developer shouldn't hand one
  off. Hardened `agents/developer.md`: a red gate blocks `Implemented` regardless of
  cause; if the red is out-of-scope, escalate (`Needs Clarification`) instead of
  proceeding.
- **First-run finding (fixed, M1):** the code-eval agent committed under a stray
  git identity `loom <loom@localhost>`, violating ADR 0003's uniform-identity rule.
  Fixed the playbook commit-convention: roles must not set/override git `user.*`.
- **Prior action:** `scope-identity-guard-to-commit-subcommands` slice **ABANDONED**
  (commit d35b565). Two code-eval-caught false-negative classes made shell-parse
  scoping untenable: (1) the original subcommand-parser failed OPEN on any pre-`git`
  token (`export GIT_*=…; git commit`, `env …`, `cd … &&`, `sudo`, `true;` — each
  was verified to reach exit 0 and record the override author), and (2) fixing that
  required a compound-command parser that would only add new fragility classes. The
  blind code-evaluator caught a real security regression before it could land — an
  `--author=Evil` commit reached exit 0 and was confirmed in the author field.
  Owner chose simple fail-closed: block `--author` unconditionally. The
  read-filter false-positive (`git log --author=alice` blocked) is an ACCEPTED,
  DOCUMENTED limitation recorded in `commit-convention.md`. Slice archived as
  Abandoned.
- **Next:** continue M4 — Dogfooding & hardening. Remaining M4 items: best practices
  propagated into root/project `CLAUDE.md` automatically; owner approval gates +
  round-limit/escalation polished; resume-after-interruption verified across
  machines; `claude -p` deep-nesting fallback evaluated.

## Accepted decisions (ADRs)

0001 plugin/orchestrator · 0002 model tiers · 0003 commit-per-handoff · 0004 blind
eval + role separation · 0005 frozen specs · 0006 self-marketplace (subdir layout) ·
0007 namespaced command surface (supersedes bare `/loom` in 0001) ·
0008 parallel `.docs/` coordination (worktree-per-slice; resolves OQ-A).

## Resolved build-time questions (M1)

- OQ-D — command surface is split into namespaced `/loom:<name>` commands
  (`/loom:run` + one-off role commands); roles are `agents/` (`loom:<role>`).
- OQ-E — plugin under `plugins/loom/`, `source: "./plugins/loom"` (root undocumented).
- OQ-F — no compiled helpers; agents do detection/parsing with their own tools.

## Resolved build-time questions (M2)

- Spec 06 §1 "empty" vs scaffold-metadata (was a code-eval MINOR on
  greenfield-init-behavior): spec `06 §1` was amended and re-approved (commit
  86fa7d1, eval `spec-06-status-seed-clarification-eval.md`) to define "empty" as
  no design content, authorizing the scaffold/phase metadata `greenfield.md` seeds.
- Commit-identity guard gap (`--author=` / `GIT_AUTHOR_*` env vars not blocked):
  closed by `author-identity-enforcement-guard` slice (commit a47bf95). The
  PreToolUse hook + `commit-convention.md` hardening cover all override paths.
- **Eval-miss root cause (eyeballing invariants):** two prior spec-review rounds each
  missed a defect that a mechanical check would have caught (bare `/loom` at spec 10
  line 107; wrapped `Code\nReview` a line-based grep can't see). Root cause addressed
  by the `recommended-tooling-and-mechanical-checks` slice (commit db39d44): the
  "Invariants verified mechanically" rule in both eval rubrics now requires
  `rg -U`/`yq`/`ast-grep`/LSP for any invariant assertion; `tooling.md` documents
  the discipline and per-role guidance. The two motivating defects themselves remain
  as separate follow-up items (spec-10 line-107 bare-`/loom` fix; the
  wrapped-token was retired in commit a85885f).

## Open

~~OQ-A (parallel `.docs/` coordination)~~ **RESOLVED by ADR 0008** (hybrid model;
living docs + slice-plans index main-only/orchestrator-serialized, per-slice
plan/eval/code branch-local, serial merge+finalize). Still deferred: OQ-B
(research-review tier — owner leans haiku-sufficient, decide empirically), OQ-C
(finalize-pass owner — owner undecided, wants a compare-and-contrast of re-spawned
cold role vs. orchestrator-direct before choosing). Owner guidance is recorded
inline in [`../spec/09-open-questions.md`](../spec/09-open-questions.md).

Deferred follow-ups discovered while accepting ADR 0008:

- ~~**Fold ADR 0008 into the frozen spec 04 Parallelism section** (and spec 08
  playbook guidance).~~ **DONE (M4 dogfood run #1, commit c3cd354, approved).** The
  spec-revision planning cycle ran through loom's loop: spec 04's Parallelism section
  now carries ADR 0008's coordination model (the "`.docs/` coordination across
  branches" open question is resolved in-text) and spec 08 records the
  slice-plans-index ownership change (planner/developer no longer touch
  `slice-plans/README.md` once parallelism is on). Both specs re-Approved.

Deferred follow-ups discovered during the retroactive spec-approval pass (flagged
for a future slice / owner decision):

- **Bare `/loom` in ADR 0001 (and possibly the spec README history)** still appears.
  ADRs are immutable (ADR 0005 / 0004 discipline), so this needs a **superseding ADR
  or an erratum note, not a rewrite**. Owner decision.
- ~~**The "Code Review" phase-label string**~~ **Resolved (commit a85885f).** The
  `Code Review` status token has been retired repo-wide. All four lifecycle strings
  (`SKILL.md`, `status-machine.md`, `developer.md`, slice-plans `README.md`) now
  match spec 03: `… → Implemented → (code review) → Landed → Archived`. Only
  legitimate action-phrasing and historical eval/status records remain.
- ~~**Commit-identity guard gap.**~~ **Resolved (commit a47bf95).** The
  `author-identity-enforcement-guard` slice closed this: `commit-convention.md` now
  explicitly forbids `--author=`, `-c user.*`, and `GIT_AUTHOR_*`/`GIT_COMMITTER_*`
  env vars; the PreToolUse hook (`plugins/loom/hooks/git-identity-guard.sh`) enforces
  it as best-effort defense-in-depth (26-case matrix, jq-absent fallback verified).
- ~~**Guard `--author` pattern not scoped to commit-creating subcommands.**~~
  **Resolved by decision (commit d35b565).** Scoping was attempted
  (`scope-identity-guard-to-commit-subcommands`); the blind code-evaluator caught
  two false-negative classes (pre-`git` prefix fail-open; compound-command
  shadowing) — a real `--author=Evil` override reached exit 0 and was confirmed in
  the author field. Owner chose unconditional `--author` blocking (fail-closed).
  The read-filter false-positive (`git log --author=alice` blocked) is now an
  ACCEPTED, DOCUMENTED limitation in `commit-convention.md`. Dogfooding value
  confirmed: the blind evaluator caught a real security regression before it landed.

## Verified at first install (M1)

- Local marketplace add + `source: "./plugins/loom"` installs cleanly; `/plugin
  validate ./loom` passes.
- Plugin components are **namespaced** — no bare `/loom`. Command surface split into
  one file per command (`/loom:run` + one-off `/loom:<role>`); agents are
  `loom:<role>`. `${CLAUDE_PLUGIN_ROOT}` resolves correctly.
- **Rung 1 passed:** `/loom:run` (status) loads, reads `.docs/` + git, and reports.

## Verified at rung 2 (first agent spawn)

- `subagent_type: loom:researcher` resolves — the orchestrator spawns a namespaced
  plugin agent via the Task tool. The haiku researcher wrote a cited note
  (`Status: Research Review`, sources + citations) and committed author-neutral;
  the orchestrator verified it. The full spawn → work → commit → verify pipeline
  works for one role.
- Remaining for M1: rung 3 — first full slice (plan → eval → develop → eval → land)
  on a throwaway target.
