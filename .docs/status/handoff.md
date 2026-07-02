# Session Handoff

Status: Living

Restart instructions and compact current context. `progress.md` is the status
source of truth; `roadmap.md` is milestone order.

## Start here each session

1. Confirm repo:
   ```sh
   cd /Users/craig/git/loom
   git status --short
   ```
2. Read `.docs/spec/README.md`, then `.docs/status/progress.md` and this file.

## Where things stand

- **Post-M4: Thin orchestrator + context management (ADR 0012 + ADR 0013) — COMPLETE;
  mechanical backstop hook now live.** Owner-directed: make `sonnet` the default
  orchestrator and keep its context flat so it drives long sessions without filling up.
  **ADR 0012** Accepted (orchestrator → `sonnet` tier via `model:` on `/loom:run`; thin-
  orchestrator invariant: pass references-not-bodies + bounded role-return contract + route
  on the signal; compaction = lossless **cold self-restart at ~60%** of Sonnet 4.6's
  context-awareness budget, not a lossy summary; the `/code-review` step is write-and-forget).
  **ADR 0013** Accepted (starvation-loop guards on the cold-restart: **write-ahead checkpoint**
  — commit next intended action to `handoff.md` *before* a big/in-window op; **restart-before-
  big-op** when near budget; **forward-progress guard** — a restart re-deriving the same action
  with no new commit → escalate, never loop; **lossless beats lossy** — 60% self-restart stays
  below the harness's ~80% auto-compact backstop). Both wired into specs 02/04 + playbook
  (`orchestration.md`, `run.md`, all 5 agents, `SKILL.md`) + root `CLAUDE.md`. Done directly
  (owner-directed), not via the full role loop. **ADR 0013 §Decision 5 (PreCompact hook) —
  LANDED** (commit 347e0d3, code-eval PASS round 0, shell gate green 11/11 + 28/28 bats):
  `plugins/loom/hooks/precompact-write-ahead-backstop.sh` is now live — loom's 2nd executable
  hook, registered in `hooks.json` as a `PreCompact` event. The mechanical write-ahead backstop
  is operational. **Three non-blocking MINOR follow-ups carried:**
  (a) `manual`-block remediation text says "re-run /compact if spurious" but re-running blocks
  identically — the only escape is committing a `.docs/` change; wording should be corrected or
  a real override added; (b) unsanitized `session_id` in log line; (c) unbounded `precompact.log`.
- **Post-M4: ADR 0010 (automated review in the code-review phase) — COMPLETE end to end
  (decision + specs + playbook).** Owner-directed feature: insert Claude Code's built-in
  `/review` + `/security-review` into loom's code-review phase. **Decision/specs** (earlier):
  research note `2026-06-10-review-security-review-in-code-eval.md` (Approved), **ADR 0010**
  Accepted (01ff88b), specs 04 + 02 re-approved (4d9ba2e). **Playbook** (this session, 3
  slices, `implement` scope, evaluator-driven, worktree parallelism): Slice A
  `references/review-findings.md` + SKILL.md bullet (solo, 13d62c2); then parallel wave —
  Slice B `orchestration.md` run step (beaa531) ∥ Slice C `code-eval-rubric.md` adjudication +
  `code-evaluator.md` inputs (5941bea). Two worktrees, two developers concurrent, landed
  `--no-ff` serially with **zero conflicts**; Slice C's first code-eval **FAILed round 1 on a
  real broken cross-link** (fixed → PASS). CLAUDE.md curated digest updated. **The mechanism is
  now live:** at `Implemented`, the **orchestrator** (only legal spawner, ADR 0001) runs the
  two commands on a code-bearing diff in **local mode** (blind contract intact, ADR 0004),
  writes a committed identity-neutral `.docs/evaluations/<slice>-review-findings.md`, and hands
  it to the **blind code-evaluator** as **advisory input** (it adjudicates + owns the verdict
  via `severity.md`); pure-docs slices skip-with-a-note; not part of the `format → lint → test`
  gate.
- **Post-M4: ADR 0011 — command corrected `/review` → `/code-review` — COMPLETE.** The owner
  caught that ADR 0010 named the wrong command: the built-in **`/review` is PR-bound** ("Review
  a pull request"), so its "local diff mode" premise was false. **Empirically verified** the fix
  — ran `/code-review` on a local staged diff (throwaway, 3 planted bugs); it ran with no PR,
  no GitHub round-trip, from the orchestrator session, and caught all three. Drove the correction
  (`implement` scope, evaluator-driven): **ADR 0011** Accepted (supersedes 0010 *only* on the
  command + adds the commit-range invocation detail; rest of 0010 stands) → **specs 04/02
  re-approved** → **playbook conformance slice** (63e6d01) swapped `/review` → `/code-review`
  across 4 files (`SKILL.md`, `orchestration.md`, `code-eval-rubric.md`, `review-findings.md`)
  + commit-range detail; CLAUDE.md digest corrected. Blind plan-eval caught a real 4th-file scope
  miss (FAIL r1 → fixed → PASS). `rg '/review\b' plugins/loom/` = zero. **Net mechanism (current):**
  orchestrator runs **`/code-review` + `/security-review`** locally on the slice's **commit range**
  (`git diff <base>...<slice-HEAD>`) at `Implemented`, feeds identity-neutral findings to the blind
  evaluator. **Remaining non-blocking follow-ups:** (a) spec 04 prose `skipped: command unavailable`
  (space) vs the playbook's hyphenated `skipped: command-unavailable` — frozen-spec planner cycle to
  align if desired; (b) ADR 0010 Notes' open questions (empirically confirm built-in spawn behavior;
  whether to tune `/code-review`'s confidence threshold for loom); (c) **FIRED LIVE for the first
  time** on the `precompact-write-ahead-backstop` code slice (this session): `/code-review`
  ran-with-findings on the committed diff; `/security-review` ran-clean. Operational finding:
  `/security-review` resolves its base from `origin/HEAD` (reviews branch changes vs the default
  branch — **no PR needed**), and a clone with `origin/HEAD` unset errors resolving it because loom
  commits directly on `main`. Fix is a one-time `git remote set-head origin -a` — now documented in
  `orchestration.md` ("Ensure `origin/HEAD` is set"). With the slice unpushed, `origin/HEAD..HEAD`
  is exactly the slice.
- **Post-M4: ADR 0009 (Unaligned-migrate) thread — COMPLETE.** All 3 slices landed
  (ballboy field report → ADR 0009 Accepted → spec 06 amended + Approved → slice 1
  init-detection spine signal c96fd90 → slice 2 migration-recipe a34d726/da21d2c/fdbbb60
  → slice 3 unaligned-bare-migrate-split 61bc6e9). `unaligned.md` now presents both
  Unaligned-bare and Unaligned-migrate sub-modes. No remaining slices in this thread.
- **M4 COMPLETE — all M0–M4 milestones done.** Owner-gates/round-limit escalation
  (polished + live-tested) ✓, CLAUDE.md auto-propagation ✓, identity-verification hardening
  (emergent) ✓, `claude -p` evaluated & closed ✓ (reserve in spec 04), resume across
  machines ✓, and the holistic "loom manages its own development end to end" ✓ (this whole
  session is the evidence — every change ran the full blind loop via the orchestrator with
  real defects caught pre-merge). **No planned milestones remain.** Future work is
  owner-directed: new ADR/spec-driven features or a packaging/release pass. The loom plugin
  is built, installed, validated, dogfooded end-to-end, and on GitHub (`craigeous/loom`,
  branch `main`).
- **M4 CLAUDE.md auto-propagation — COMPLETE** (both cycles landed). Cycle 1: specs 03 + 08
  amended + Approved (commit 56e1a8d). Cycle 2: playbook conformance landed (commit b661f7a,
  code-eval PASS round 0) — the developer finalize pass now has an explicit step to maintain
  `CLAUDE.md` as a **curated digest** (spec 03 finalize step 2; boundary in spec 08
  *Evolving the playbook → CLAUDE.md auto-propagation*): update only when the slice changed
  a durable convention / repo-layout fact / gate definition / read-first pointer; per-slice
  history stays in `progress.md`; covers root and managed-project CLAUDE.md. Five playbook
  files updated to reflect and point to spec 08. Slice `claude-md-autopropagation-conformance`
  archived. Non-blocking MINOR (spec 08 template bullet lacks forward-link to the
  auto-propagation subsection) is carried — requires its own spec-amendment planning cycle.
- **M4 escalation thread — COMPLETE** (roadmap item "owner approval gates, round
  limits/escalation polished" ✓). Cycle 1: spec 03 `## Round limits` amended + Approved
  (commits 5de67fd → df72df0); `Round:` counts FAIL cycles only, one cross-phase counter
  per artifact, escalation pause+summary contract defined. Cycle 2: playbook conformance
  landed (commit f161fa0, code-eval PASS Round 0) — `status-machine.md`,
  `orchestration.md`, eval template, and both evaluator prompts match the amended spec
  (evaluators no longer number PASSes as new rounds). Slice `round-limit-conformance`
  archived. **Live 5-round stress-test passed** (throwaway fixture, since removed): real
  blind evals continued the counter 3→4→5 on a recurring BLOCKER, and the orchestrator
  halted at the 5th FAIL with the full escalation summary (thrashing classification +
  owner options) instead of dispatching a 6th revision.
  **M4 finding (identity-guard gap) — ADDRESSED:** the recurring `loom@localhost` fallback
  identity issue (M1 + M4, planner commit d008bc3) is now closed structurally by the
  `identity-verification-hardening` slice (commit a816979, code-eval PASS round 0): init
  verifies a real identity is configured and stops if absent (Greenfield Step F, pointed at
  by Unaligned/Initialized); agents verify the commit identity after committing (single-sourced
  in `commit-convention.md`; all five agent prompts carry a pointer). A separate one-off
  environment mitigation (repo-local git identity set by orchestrator) is also in place.
  **Remaining M4 threads:** CLAUDE.md auto-propagation; resume-across-machines; `claude -p`
  deep-nesting fallback.
- **M4 (Dogfooding & hardening) in progress.** `shell-gate` slice landed (commit
  34de27c, code-eval PASS Round 3, gate green 28/28): first end-to-end exercise of
  the gate-learning mechanism on real code. Delivered: 28-case bats suite for
  `git-identity-guard.sh`, `gates/shell.md` (Status: Verified), root `CLAUDE.md`
  Shell gate section. Plan-eval caught a real BLOCKER (jq-absent recipe), fixed
  Round 2. Deferred M2 follow-up `gates/shell.md` is **DONE**. Also landed: ADR
  0008 folded into frozen specs 04 + 08 (commit c3cd354, plan-eval PASS,
  owner-approved) — driven through loom's own loop in strict route-only mode with
  zero orchestrator intervention. Spec 04's Parallelism section now states ADR 0008's
  coordination model; spec 08 records the slice-plans-index ownership change.
  M0–M3 all complete.
- **M3 (Parallelism) is complete**, including the live parallel demonstration.
  `references/parallelism.md` (ADR 0008) is the single authoritative
  worktree-per-slice operational body. The model was proven end-to-end: 2 developer
  agents ran in parallel worktrees (`slice-casing` / `slice-reverse`), each isolated
  to a disjoint module, each gate-green independently (commits f66aeca, fb71dad);
  serial land → master with no conflicts; integrated gate green (21 unit + 2
  doc-tests); worktrees and branches cleaned up cleanly. ADR 0008's
  conflict-free-by-construction model is confirmed in practice. **M2 and M3 are
  both complete.**
- **M1 is complete.** The loom plugin under `plugins/loom/` is built, installed,
  validated, and **run end-to-end**: command surface is split into namespaced
  `/loom:<name>` commands; agents are `loom:<role>`; the full slice loop works
  (planner → blind plan-eval → developer+gate → blind code-eval → finalize/archive).
- **M2 slice 1 landed (5fef2ed).** Init-mode detection is now single-sourced in
  `plugins/loom/skills/loom-playbook/references/init-detection.md` — concrete
  classifier with defined "loom-shaped" and "empty/near-empty" tests; four call
  sites repointed. Both plan and code evals: PASS (blind, independent).
- **M2 slice 2 landed (a58ff7e).** Greenfield init behavior is now single-sourced in
  `plugins/loom/skills/loom-playbook/references/greenfield.md` — concrete ordered
  steps: scaffold `.docs/`, seed `status/`, write project `CLAUDE.md`, establish
  the gate, commit + hand back. Three call sites (`orchestration.md`, `run.md`,
  `init.md`) repointed at it. Both plan and code evals: PASS (blind, independent;
  one MINOR on status file seeding — non-blocking). Deferred follow-up slices:
  unaligned-init-behavior, initialized-init-behavior, gate-learning.
- **`author-identity-enforcement-guard` landed (a47bf95).** PreToolUse hook
  (`plugins/loom/hooks/hooks.json` + `git-identity-guard.sh`) and hardened
  `commit-convention.md` now block all identity-override paths (`--author=`,
  `-c user.*`, `GIT_AUTHOR_*`/`GIT_COMMITTER_*`). 26-case acceptance matrix
  passed; jq-absent grep-fallback verified; code-eval Round 4 PASS (independent
  re-verification). Slice archived. The commit-identity guard gap follow-up is
  resolved. One new Open item: `--author` detection is not scoped to
  commit-creating subcommands, so read-only commands like `git log --author=` are
  also blocked — a usability refinement candidate for a future slice.
- **`retire-code-review-status-token` landed (a85885f).** The obsolete `Code Review`
  status token removed repo-wide from `SKILL.md`, `status-machine.md`,
  `developer.md`, and the slice-plans README `Lifecycle:` string. All lifecycle
  strings now match spec 03: `… → Implemented → (code review) → Landed → Archived`.
  Slice archived.
- **`gate-learning` landed (b2463c4). M2 complete.** Gate-learning for unknown
  stacks is now single-sourced in
  `plugins/loom/skills/loom-playbook/references/gate-learning.md` — the authoritative
  mechanism: inspect toolchain → propose `format → lint → test` → owner-confirm →
  run-green-once → record `gates/<stack>.md` + project `CLAUDE.md`; UNVERIFIED until
  green; idempotent for known stacks. The three init bodies had their stale
  "forthcoming/deferred" forward pointers replaced with live links. `SKILL.md` +
  root `CLAUDE.md` updated. Code-eval Round 2 PASS (blind, independent). Slice
  archived. **M2 (Init modes & gate learning) is now complete** — all four items
  delivered: Detection classifier, per-mode trio (Greenfield/Unaligned/Initialized),
  idempotent re-application, gate-learning.
- **`initialized-init-behavior` landed (b0bd3e9).** Initialized init behavior is now
  single-sourced in `plugins/loom/skills/loom-playbook/references/initialized.md` —
  resume: state-derived menu from `.docs/` + git state mapped to the dispatch table
  in `status-machine.md`; scope + gates + driver-loop handoff; Q10 idempotent
  playbook re-application single-sourced here (auto-apply clean, recommend for
  conflicts, never clobber). Three call sites (`orchestration.md`, `run.md`,
  `init.md`) repointed. Code-eval Round 2 PASS (blind, independent). Slice archived.
  The per-mode behavior trio (Greenfield + Unaligned + Initialized) is complete.
- **`unaligned-init-behavior` landed (e83e219).** Unaligned init behavior is now
  single-sourced in `plugins/loom/skills/loom-playbook/references/unaligned.md` —
  alignment pass: study the repo, scaffold + gate (reusing `greenfield.md` Steps
  A–E), descriptive `spec/` back-fill with explicit no-decisions boundary, seed
  `status/`, leave project ready to resume as Initialized. Three call sites
  (`orchestration.md`, `run.md`, `init.md`) repointed. Code-eval Round 2 PASS
  (blind, independent). Slice archived.
- **`recommended-tooling-and-mechanical-checks` landed (db39d44).** New
  `plugins/loom/skills/loom-playbook/references/tooling.md` (recommended CLI/LSP
  toolkit by role, all optional with fallback). "Invariants verified mechanically"
  rule added to both eval rubrics (`plan-eval-rubric.md`, `code-eval-rubric.md`);
  cross-links in `SKILL.md` and three agent files. Root cause of prior eval misses
  (eyeballing invariants) is now addressed. Slice archived.
- **`scope-identity-guard-to-commit-subcommands` ABANDONED (commit d35b565).** Guard
  scoping was attempted across two code-eval rounds; the blind evaluator caught a
  real security regression each time (override reaching exit 0, author=Evil
  confirmed). Owner reverted to unconditional `--author` blocking. The read-filter
  false-positive (`git log --author=alice` blocked) is now an ACCEPTED, DOCUMENTED
  limitation in `commit-convention.md`. Slice archived as Abandoned.
- **Published:** GitHub repo `craigeous/loom` (public), default branch `main`.
- **All ten content specs (00–08, 10) are `Status: Approved`** after a retroactive
  blind plan-eval pass (eval records in `.docs/evaluations/spec-*-eval.md`). Several
  FAILed round 1 and were fixed (00/01/02/03/10) — see `progress.md` for the
  findings. Spec `09-open-questions.md` and the spec `README.md` are now
  `Status: Living` (09 is a live OQ tracker; README is the index).
- Design + decisions stable in `.docs/spec/` (00–10) and `.docs/ADR/` (0001–0006).
- **Deferred follow-ups from the spec pass** (in `progress.md` Open, for a future
  slice / owner decision): bare `/loom` in ADR 0001 needs a superseding ADR or
  erratum (ADRs are immutable — no rewrite). ~~The "Code Review" phase-label string~~
  is **resolved** (commit a85885f — token retired repo-wide). ~~The commit-identity
  guard gap~~ is **resolved** (commit a47bf95 — hook + doc hardening).
  ~~Eval-miss root cause (eyeballing invariants)~~ is **resolved** (commit db39d44 —
  mechanical-check rule in both rubrics + `tooling.md`).
- **Open items:** (a) spec-10 line-107 bare-`/loom` — frozen-spec planner cycle
  required; (b) guard `--author` not scoped to commit-creating subcommands —
  **RESOLVED by decision** (scoping abandoned, unconditional blocking retained,
  read-filter false-positive documented as accepted limitation in
  `commit-convention.md`, commit d35b565).

## Immediate next steps

0. **ACTIVE THREAD (this session) — multi-session worktree coordination (new ADR 0014, extends
   immutable ADR 0008).** Owner-reported: running **multiple independent top-level `/loom:run`
   sessions** against the same repo causes collisions. ADR 0008 only makes *one* orchestrator's
   sub-agent worktrees conflict-free; "living docs main-only, **serialized**" assumes a single
   orchestrator. With N sessions they race at four points: the shared `main` working tree (file
   clobber + `index.lock`); the driver-loop dispatch (both pick the **same** next action → same
   slice twice); main's living-doc + `slice-plans/README.md` writes; and concurrent merge+finalize
   on `main`. **Scope: full thread. Gates: none** (evaluator approval advances; stop only on
   5-FAIL escalation or blocking ambiguity). **Design to record (per-slice granularity):**
   (1) **session-owned slice worktrees** — a session never does slice work in the shared `main`
   checkout; it `git worktree add`s per slice off fresh `origin/main` and runs roles there;
   (2) a **cross-session lock** on main's critical section `{claim, merge+finalize}` (atomic
   `mkdir`/ref-CAS + the ADR 0008 §3 exponential backoff) — makes "serialized" true *across*
   sessions; (3) **slice claiming/leasing** in the slice-plans index (session id + lease TTL,
   stale-claim reclaim) so two sessions don't grab the same slice.
   ADR 0014 authored + at `Plan Review`. **Owner raised 3 must-fix gaps (pre-approval, authoritative):**
   (i) **BLOCKER — crashed lock-holder → global deadlock.** The §3 lease TTL covers a stale
   *claim/lease* but NOT a stale *lock*: a session dying mid-critical-section still holding
   `.git/loom-main.lock/` wedges every other session in §2 backoff forever (`mkdir` never frees).
   The lock needs its OWN liveness/TTL — lock dir carries `{session-id, pid, timestamp}`; a contender
   past a short **lock-TTL** verifies the holder is dead (worktree list / PID) and force-clears.
   Distinct from the slice lease TTL. (ii) **MAJOR — scan source / read-consistency unspecified.**
   A session works off a snapshot worktree, but the driver loop must derive "next action" from
   **current `main`** (fetch/read live main) to see freshly-landed slices + live claims — pin the
   per-loop scan to a fresh main view, never the session's stale worktree, else it re-picks
   claimed/landed slices. (iii) **MAJOR — claim TOCTOU.** The scan isn't under the lock, so two
   sessions can both see slice X free and both proceed. After acquiring the lock the session must
   **re-read the lease and abort/re-select if X was claimed in between** (explicit check-then-act);
   the lock currently serializes the write, not the decision.
   Owner gaps (i)-(iii) RESOLVED by planner + confirmed sound by blind plan-eval. **Blind plan-eval
   then FAILed `Round: 1`** (`.docs/evaluations/0014-multi-session-worktree-coordination-eval.md`)
   with 3 new findings: **BLOCKER** — the ADR-0013 write-ahead `handoff.md` checkpoint is a `main`
   write that recurs OUTSIDE the `{claim, merge+finalize}` lock (a 3rd unguarded main-write moment),
   and a **shared** `handoff.md` lets a restart resume *another* session's action → "two moments /
   four races closed" is false; **MAJOR** — cold-restart lease recovery unspecified: a restarted
   session is a new process (new pid), so its old `{session-id,pid}` claim looks dead → stranded/
   wrongly-reclaimed lease; needs durable `{session-id, held-claims}` persistence the restart re-reads
   to renew; **MINOR** — pin the under-lock authoritative read to shared **local `main`** (loom commits
   directly to local main), not `origin/main` which can lag.
   Round-1 revision (`0cbcdf9`) relocated the write-ahead anchor off `main` to per-session
   `.git/loom-session-<id>/` state (every shared-`main` write — claim, renew, land — now under the §2
   lock; a restart reads only its own anchor; shared human-facing `handoff.md` written only at land
   under lock) + durable session-id-keyed claim persistence (re-adopt/renew across cold restart).
   **Blind plan-eval re-review PASS `Round: 1`** (`7f36196`) → **ADR 0014 APPROVED** (Accepted/immutable;
   README moved In Review → Accepted). **3 non-blocking MINORs CARRIED** to fix in the *living* layer
   (spec 04 amendment + playbook/helper-contract, since the ADR is now immutable): (a) "exactly two
   shared-`main` writes" undercounts — it's **three** locked writes (claim / lease-renew / land);
   (b) reconcile the liveness wording ("and/or" vs "session-id-primary"); (c) add **session-end cleanup
   of `.git/loom-session-<id>/`** to the helper contract + crash-cleanup (`git worktree prune` path).
   **Spec 04 amendment DONE** — `### Multi-session coordination (ADR 0014)` subsection added (ADR 0008
   prose intact); MINORs (a) three locked writes [claim/lease-renew/land] + (b) session-id-primary
   liveness fixed in living prose. **Blind plan-eval PASS `Round: 0`, no findings**
   (`adr-0014-spec-amendment-eval.md`); spec 04 re-Approved/re-frozen. **spec-08 follow-up FLAGGED**
   (ADR 0014 §Consequences names playbook bodies; spec 08 guidance touch deferred to a later planning
   pass). Durable-design layer COMPLETE (ADR 0014 Accepted + spec 04 carries the model).
   **IMPLEMENTATION = 2 sequenced slices** (dependent — bodies cite the helper CLI, so NOT parallel per
   the slicer-independence rule): **Slice H (code)** = POSIX-sh lock/claim helper + bats + shell gate
   green (the ONLY code-bearing slice → first real `/code-review` + `/security-review` run on actual
   loom code); **Slice W (docs)** = wire `parallelism.md` + `orchestration.md` + `run.md` against H's
   landed CLI (pure-docs → auto-review skip). MINOR (c) session-end `.git/loom-session-<id>/` cleanup
   lands in H (helper + crash-cleanup/`git worktree prune`).
   **Slice-plan H authored** (`multi-session-lock-helper-plan.md`): helper `plugins/loom/lib/loom-coord.sh`
   (+ `loom-coord.bats`), a CLI (not a hook), state under `<git-dir>/loom/`, fails-closed.
   **Blind plan-eval FAILed `Round: 1`** (`multi-session-lock-helper-eval.md`): **2 BLOCKERs** — (1) the
   stale-lock force-clear is `rm -rf`+re-`mkdir`, which is racy: two contenders seeing one dead holder
   can BOTH acquire (B clears+owns, C's `rm -rf` then deletes B's fresh lock + C owns) → needs **atomic
   clear-and-own (rename-capture/CAS)**; compounded because land is a raw `git merge` with no holder
   re-check (reopens race point 4); (2) **no bats case proves mutual exclusion under concurrent stale
   reclaim** (2 contenders, 1 dead holder → exactly one winner). **MAJOR** — add a `lock-verify --session`
   holder-assertion primitive so W's land write can re-check ownership before the raw merge. **MINOR** —
   pin registry↔README write-ordering/fail-closed + state the W precondition that worktree paths embed
   the session-id. Plan otherwise faithful/thorough (lock-TTL≠lease-TTL kept distinct; key negatives
   tested; fails-closed correct; ADR 0003 untouched; scope clean).
   **Slice-plan H revised (round 1)** — racy force-clear replaced with atomic **rename-capture CAS**
   (`mkdir` the sole ownership gate; ABA-guarded; invariants: single-valued holder + re-assert
   holder==self before every locked act incl. land `git merge`); real 2-contender concurrency bats case;
   `lock-verify --session` land precondition; MINORs fixed. **Blind plan-eval re-review PASS `Round: 1`
   → slice-plan H APPROVED** (`multi-session-lock-helper-eval.md`). 3 residual advisory MINORs (orphaned
   `$CAP` not swept by `cleanup`; `$CAP` same-second name-collision edge; the irreducible
   `lock-verify`→raw-`git merge` TOCTOU = W's unmediated-land scope) — non-blocking; fold the `$CAP`
   sweep into `cleanup` if cheap.
   **Slice H IMPLEMENTED** — `plugins/loom/lib/loom-coord.sh` + `loom-coord.bats` (commit `8f28b59`),
   shell gate GREEN (shfmt clean / shellcheck clean / **bats 30/30** incl. L5 concurrent 10× race;
   hooks regression 39/39). Slice H code = the single commit `8f28b59` (base `4bb64b9`); diff range
   **`4bb64b9..8f28b59`**, sole code = the helper (+ bats); all else unpushed is `.docs/` markdown.
   `origin/HEAD`→`origin/main` set; HEAD is 19 ahead of `origin/main` (thread unpushed — do NOT push).
   **Automated review DONE (real Skill runs, transcribed)** →
   `.docs/evaluations/multi-session-lock-helper-review-findings.md`. **`/code-review` = ran-with-findings**
   (high-effort; 20 verified → **9 distinct defects**, several **CONFIRMED correctness bugs that defeat the
   helper's purpose**: F1 unanchored `grep -F "${slice}\t"` claim match → wrong-row edit/double-grant; F2
   `cleanup` rewrites CLAIMS even when `got_lock=0` → clobbers a concurrent claim; F3 stale-reclaim gated on
   holder-file → a crash between `mkdir LOCK_DIR` and `stamp_holder` deadlocks all sessions; F4 unanchored
   `is_alive` substring probe; F5 PLAUSIBLE holder-liveness-needs-sid-worktree; F6 broken orphan-cleanup awk
   (dead code); F7 session-end `rm -rf` when `got_lock=0` orphans claims; F8/F9 cleanups). **`/security-review`
   = ran-clean** (all sinks quoted + trusted-caller-fed; no untrusted flow). **The gate (30/30) + blind
   plan-eval did NOT catch these — this is the automated-review dimension earning its place.**
   **Blind code-eval FAILed `Round: 2`** (`multi-session-lock-helper-eval.md`). Gate independently
   re-verified green (shfmt/shellcheck/bats 30/30) **but happy-path-only — safety negatives untested**.
   Adjudicated the 9 `/code-review` findings → **8 CONFIRMED, 1 REJECTED** (F5 by-design session-id-primary,
   a documented W precondition); F1/F2/F3/F6 reproduced empirically. **BLOCKERs:** F1 unanchored
   `grep -F "${slice}\t"` deletes sibling rows (`v2` drops `auth-v2`) → double-grant; F2 `cleanup` rewrites
   `claims` off the `got_lock` guard → lost claim under contention; F3 holderless lock dir (crash between
   `mkdir LOCK_DIR` and `stamp_holder`) is permanently un-reclaimable incl. by `cleanup` → deadlock; F6
   orphan-worktree awk is dead code → `worktree remove -f` never fires (CU1 masks it). **MAJORs:** F4
   substring `is_alive` probe; F7 `session-end` `rm -rf` without releasing claims when `got_lock=0`.
   **MINORs:** F8 dead `SUBCOMMAND` dance, F9 redundant `worktree list`. Slice-plan set `In Progress`.
   **NEXT ACTION:** developer fixes F1-F4, F6, F7 (+ F8/F9 while there) per the eval AND **adds the missing
   negative bats cases** proving each safety fix (sibling-row preserved; cleanup-under-contention no clobber;
   holderless-lock reclaimed; orphan worktree actually removed; substring-collision liveness; session-end
   releases before rm) — green tests that don't exercise the path are not acceptable. Re-run shell gate GREEN
   → `Implemented`. Then orchestrator **re-runs automated review** on the new diff → blind code-eval
   (resolving PASS closes Round 2; another FAIL → Round 3; escalation at 5). Then land → finalize → slice W.
   **RETRY NOTE:** first developer-fix attempt crashed on the 32k output-token cap (no commit, clean tree,
   no edits landed — verified) — a mechanical output-limit failure, NOT a starvation loop (work hadn't
   started; round counter unchanged at 2). Re-spawning the developer with **incremental-Edit + terse-return**
   discipline (no full-file Writes, never paste file bodies/gate logs) to avoid recurrence.
   **Retry SUCCEEDED — fix landed `692bb14`** (slice `Implemented`, tree clean): F1 unanchored grep→exact
   `awk -F'\t' '$1==slice'`; F2 claims sweep guarded behind `got_lock`; F3 holderless lock dir reclaimable
   via `clear_and_own`; F4 `is_alive` anchored `grep -qE "${sid}(/|$)"`; F6 awk→`/^worktree /{print $2}`
   + pid+TTL on-disk-stale handling; F7 `session-end` guards `rm -rf`; F8/F9 done. Gate green
   **bats 37/37** (30+7 new negatives), shfmt/shellcheck clean, hooks 39/39. New slice diff range
   `8f28b59..692bb14` (fix commit `692bb14`). **NEXT ACTION:** orchestrator **re-runs `/code-review` +
   `/security-review`** on the fixed helper (slice reached `Implemented` again → ADR 0010/0011), refreshes
   the identity-neutral review-findings artifact, then blind code-eval (resolving PASS closes Round 2;
   new FAIL → Round 3; escalate at 5). Watch the fix's new constructs (F4 `grep -E` with interpolated
   `$sid`; F6 awk; F3 reclaim) — the blind code-eval adjudicates, orchestrator does not pre-judge.
   **Re-review DONE — the fixes introduced REGRESSIONS.** `/code-review` = ran-with-findings (17 verified
   → **7 distinct NEW defects**, several CONFIRMED, several demonstrated): R1 cleanup override gates on the
   ephemeral claim-time `$$` pid (always dead) → collapses to lease-age → reaps a LIVE >TTL-unrenewed
   session's worktree (`rm -f` uncommitted work) + double-grant; R2 F4 `grep -qE "${sid}(/|$)"` unanchored
   at the LEADING boundary (dead `bar` matches live `wt-foo-bar`); R3 F4 interpolates `$sid` unescaped into
   an ERE (`run[1]`→grep error→live session reported dead); R4 new holderless reclaim races the
   `mkdir`→`stamp_holder` window → lock double-grant (dup at cleanup/session-end); R5 `session-bootstrap`
   inline acquire missing the holderless branch → cold-restart wedges; R6 F6 awk `{print $2}` truncates
   space-containing worktree paths; R7 missing empty-sid guard. `/security-review` = ran-clean.
   Findings artifact refreshed for this round. **NEXT ACTION:** blind code-eval adjudicates → almost
   certainly FAIL `Round: 3` (the fix regressed) → developer round-3 fix. **META-WATCH:** fix-introduced-
   regressions = the thrashing pattern the 5-FAIL round limit guards; at round 5 escalate (pause+summary,
   incl. whether hand-rolled POSIX-sh concurrency is the right mechanism). Currently round 2→3 of 5.
   **Code-eval FAILed `Round: 3`** (7 CONFIRMED, 0 rejected, all reproduced; round-2 F1/F2/F7 held; new
   negatives NEG-F3/F4/F6 MASK the regressions). Gate re-verified 37/37 green but insufficient. Confirmed:
   **4 BLOCKER** (R1 remove cleanup recovery-override — ephemeral `$$` pid reaps LIVE worktrees, violates
   session-id-primary; R2 anchor the worktree-list match at BOTH boundaries, literal segment; R4 age-gate
   the holderless reclaim + reverify ownership in `stamp_holder`; R5 apply R4 fix to `session-bootstrap`
   too), **2 MAJOR** (R3 match `$sid` literally not via unescaped ERE; R6 awk handles spaced worktree
   paths), **1 MINOR** (R7 empty-sid guard). Slice `In Progress`. **NEXT ACTION:** developer round-3 fix
   per the eval, with 3 force-multipliers: (1) **parse `git worktree list --porcelain` records properly
   and compare the path/branch field by EXACT string equality** — stop substring/regex-grepping session-ids
   (root cause of R2/R3/R6); (2) **red-green tests** — each negative must FAIL before the fix, PASS after
   (the masking ones don't); (3) incremental-Edit + terse-return (avoid the 32k-output crash). Re-gate →
   `Implemented` → re-run automated review → code-eval (resolving PASS carries Round 3; FAIL → Round 4;
   escalate at 5). **META: 2 fix attempts left before the 5-FAIL escalation** (which would surface the
   mechanism question: hand-rolled POSIX-sh liveness is the recurring fault line).
   **⛔ BLOCKED — monthly spend limit hit (raise at claude.ai/settings/usage); opus classifier also down.**
   The round-3 developer fix was **cut off mid-work**: `plugins/loom/lib/loom-coord.sh` has **UNCOMMITTED
   partial edits** in the working tree (889→1006 lines), **NO red-green tests added** (bats unchanged),
   **gate NOT run**, **nothing committed**, slice still `In Progress`, round counter still 3 (no new FAIL).
   The WIP is **unverified and possibly mid-edit** — do NOT trust or commit it as-is. **RESUME:** once the
   spend limit is raised, prefer **discard the WIP** (`git checkout -- plugins/loom/lib/loom-coord.sh`) and
   re-run the round-3 developer from the last green commit `692bb14` with the crisp eval guidance
   (root-cause: proper `git worktree list --porcelain` parsing + exact field compare; remove the R1
   recovery-override; age-gate + ownership-reverify holderless reclaim consistently incl. `session-bootstrap`;
   red-green tests). Only pop-and-continue the WIP if a quick read shows it's coherent and worth salvaging.
   **UPDATE (owner: discard+retry):** WIP discarded (`git checkout -- plugins/loom/lib/loom-coord.sh`),
   tree clean at green `692bb14`; re-spawning the round-3 developer with the root-cause directive (porcelain
   parse + exact field compare; remove R1 override; age-gate + ownership-reverify reclaim incl.
   `session-bootstrap`; red-green tests). Round counter still 3 (no new FAIL from the aborted attempt).
   **Round-3 fix LANDED `21f9970`** (slice `Implemented`, tree clean): `wt_sid_match` awk helper (exact
   `wt-<sid>` last-segment equality, space-safe) replaces every `grep -qE "${sid}(/|$)"` → dissolves
   R2/R3/R6; R1 recovery-override REMOVED (liveness = pure worktree-list membership); holderless reclaim
   age-gated everywhere incl. `session-bootstrap`'s internal fn (R4/R5); empty-sid guard (R7). Gate green
   **bats 44/44** (7 new negatives, 6 verified red→green; NEG-R4/R6 already passed on old code with sound
   rationale — durable fixes covered by NEG-R4b + `wt_sid_match`). New range `692bb14..21f9970`.
   **NEXT ACTION:** re-run `/code-review` + `/security-review` on the fixed helper → refresh
   review-findings → blind code-eval (resolving PASS carries **Round 3** and **LANDS slice H**; FAIL → Round
   4). Then finalize (archive plan, progress/CLAUDE.md) → **log the deferred `.docs/` infra-blocked-escalation
   follow-up** (owner idea, saved to memory `loom-infra-blocked-escalation`) → slice W (playbook wiring).
   **⚠️ ESCALATED TO OWNER (pause on blocking design ambiguity — NOT a round FAIL; round counter stays 3).**
   Re-review of the round-3 fix (`692bb14..21f9970`): `/code-review` = ran-with-findings, **7 more CONFIRMED
   regressions** (T1 `dir_mtime_epoch` BSD-first `stat` → **Linux-only crash**, masked by macOS bats; T2
   membership-only liveness → **crashed session with lingering `wt-<sid>` dir seen alive forever → slice
   wedged**; T3 `awk -v sid` escape-processing mangles backslash → double-grant; T4 age-gate 30s > backoff
   6.2s → crash-in-window lock blocks 30s; T5 skipped-count; T6 orphan-removal now unreachable dead code;
   T7 4× copy-paste drift). `/security-review` = ran-clean. **DIAGNOSIS:** 3 fix rounds, each trading one
   liveness failure mode for another — too-aggressive (ephemeral pid always dead → reaps live) ↔ too-lenient
   (membership-only → never reclaims crashed). **Root cause is architectural: worktree-membership alone
   can't distinguish a live session from a crashed one with a leftover worktree dir, and the ephemeral CLI
   pid is useless as a liveness signal — a gap in ADR 0014's §F5 membership-primary liveness model surfaced
   only in implementation.** Chose to pause BEFORE spending a round-4 code-eval + dev cycle (which would
   re-trade the same tension) and present the owner an A/B/C fork: (A) keep patching; (B) refine the
   liveness model to a **lease-renewal heartbeat** (staleness = lease older than TTL; live sessions renew,
   crashed ones don't → resolves the oscillation) via a spec-04 amendment / new ADR, then re-implement;
   (C) simplify the mechanism (lean on git's own atomic ref/branch ops instead of bespoke lock+liveness).
   **NEXT ACTION: await owner's A/B/C decision.** Recommend **B** (targeted root-cause; keeps ADR 0014
   architecture). Slice still `In Progress` at `21f9970` (gate green 44/44 but T1 means Linux-broken).
   **OWNER CHOSE B (lease-renewal heartbeat).** Liveness = **lease freshness**: a live session renews its
   lease on a cadence << TTL; a holder/claim is live iff its lease timestamp is within TTL, else reclaimable.
   Worktree-dir presence is NOT a liveness signal (fixes T2/T6); the ephemeral pid is dropped as a liveness
   signal (fixes the round-2 reap). Resolves the too-aggressive↔too-lenient oscillation. ADR 0014 §F5
   (membership-primary liveness) is immutable → record via a **new ADR 0015 that supersedes ADR 0014 on the
   liveness-signal point ONLY** (worktrees/lock/claim/per-session-state/cold-restart all stand). **NEXT
   ACTION:** planner authors `.docs/ADR/0015-lease-renewal-heartbeat-liveness.md` (`Plan Review`) → blind
   plan-eval → spec-04 amendment (fold the new liveness model + the session's renew-cadence obligation into
   the driver loop) → blind plan-eval → developer RE-IMPLEMENTS the helper's liveness (lease-freshness
   replaces membership/pid; also fix mechanical T1 Linux `stat` portability [+ gate/tests must exercise the
   Linux path, not mask it], T3 awk-escape, T5 skipped-count, T7 dedup into a shared acquire helper) →
   automated review → blind code-eval → land → finalize → slice W. Round counter still 3.
   **ADR 0015 authored (`Plan Review`) → blind plan-eval FAILed `Round: 1`**
   (`0015-lease-renewal-heartbeat-liveness-eval.md`). **BLOCKER:** the thin orchestrator is single-threaded
   and **suspended inside its long (20-40+min) sub-agent calls**, so a ~TTL/3 driver-loop `renew` can't fire
   mid-op → a live-but-blocked holder's lease goes stale → peer reclaims + `git worktree remove -f`s its
   in-progress slice = **self-inflicted double-grant, worse than round-2.** ADR gives no mitigation.
   **MINORs:** dangling `§F5` ref (ADR 0014 liveness is in §3, no F5 anchor); mechanical carry-forward omits
   T4 (holderless age-gate vs backoff window). Sound: supersession scope, deferrals, T2/T6 closure, README.
   **NEXT ACTION:** planner **revises ADR 0015 (round 1)** to resolve the blocking-op renewal gap. Design
   space (planner picks + records mechanism/cleanup/crash semantics): (a) **background renewer process gated
   on the STABLE orchestrator-session pid** (`while kill -0 $SESSION_PID; do renew; sleep TTL/3; done` as a
   detached child) — survives long tool calls (process alive-but-busy) AND fixes round-2 by using the stable
   session pid, NOT the ephemeral per-invocation CLI pid the round-2 reap used [key distinction]; dies →
   lease stale → reclaimable; (b) TTL > longest blocking op (crude, slow crash-recovery); (c) block-surviving
   fallback. Fix the 2 MINORs (§3 not §F5; add T4). Re-emit `Plan Review` → blind plan-eval re-review. Then
   spec-04 amendment → re-implement → land. (Resolvable within owner-chosen B; no re-escalation needed.)
   **ADR 0015 round-1 revision (background renewer gated on stable session pid) → blind re-review closed the
   round-1 items but FAILed `Round: 2`** (ADR 0015's own counter): **BLOCKER pid-reuse** — a bare
   `kill -0 $SESSION_PID` gate is fooled after the OS recycles the dead session's pid → orphaned renewer
   keeps a dead lease fresh forever → permanent wedge (T2 re-regression). Round-1 items confirmed closed
   (renewer heartbeats through long blocking calls; cross-session purity clean; §3 + T4 fixed).
   **NEXT ACTION:** planner **revises ADR 0015 (round 2)** — fix pid-reuse at principle level via
   **pid + process-start-time identity** (record `{session-pid, start-time}`; renewer gate = pid alive AND
   start-time matches → recycled pid fails → renewer exits → lease stale); soften the "closes T2 / dead
   session can't keep its lease" claim to hold only under the reuse-robust gate; flag start-time capture as
   another cross-platform-sensitive item for the re-impl (like T1 `stat`). Re-emit `Plan Review` → blind
   plan-eval re-review. Then spec-04 amendment → re-implement → land. (ADR 0015 at Round 2 of 5; slice H
   code-eval counter separately at 3.)
   **ADR 0015 APPROVED** (blind plan-eval PASS `Round: 2`; `{session-pid, start-time}` identity gate closes
   pid-reuse; background renewer heartbeats through long blocking ops; peers read lease freshness only).
   README moved In Review → Accepted. **NEXT ACTION:** planner authors the **spec-04 amendment** folding
   ADR 0015 into the `### Multi-session coordination` subsection — REPLACE the now-superseded ADR-0014
   "membership-primary liveness (presence in git worktree list)" prose with: **liveness = lease freshness**;
   the **background renewer gated on `{session-pid, start-time}`** (survives long blocking sub-agent calls;
   pid gate is local-only, peers read lease freshness); the **session's renew obligation** (renew < TTL while
   holding a lock/claim; stop renewing → reclaimable, incl. after an ADR-0013 escalate-and-stop wedge);
   membership/pid demoted as liveness signals → `Plan Review` → blind plan-eval. Then developer
   RE-IMPLEMENTS the helper's liveness against the new model + fixes mechanical T1(Linux `stat`)/T3(`awk -v`
   escape)/T4(age-gate vs backoff)/T5(skipped-count)/T7(shared acquire helper) + start-time portability,
   with tests that exercise the Linux path (don't mask) → automated review → blind code-eval → land →
   finalize → slice W.
   **Spec-04 amendment DONE** (`adr-0015-spec-amendment-eval.md` PASS `Round: 0`, no findings; spec 04
   re-Approved) — liveness prose now lease-freshness; non-liveness invariants intact; `rg` zero residual
   membership-as-liveness. Liveness-refinement design layer COMPLETE (ADR 0015 Accepted + spec 04 updated).
   **NEXT ACTION:** developer **re-implements `loom-coord.sh` liveness** against spec-04/ADR-0015: peer
   liveness = **lease freshness** (staleness by lease-timestamp vs TTL; remove membership/pid as the peer
   liveness signal); add the **background renewer** subcommands (capture `{session-pid, start-time}`; detached
   `while identity-ok; do renew; sleep ~TTL/3; done`; start/stop; identity = `alive(pid) && starttime==recorded`);
   + mechanical **T1** (Linux-portable `stat` for mtime AND start-time — feature-detect, not BSD-first),
   **T3** (`awk -v` escape), **T4** (holderless age-gate vs backoff — recover within one invocation),
   **T5** (skipped-count), **T7** (single shared acquire helper, dedup the 4 copies). Tests: red-green +
   **exercise the Linux path (don't mask with BSD `stat`)**. Strict OUTPUT discipline + **incremental
   commits** (blast-radius lever). Gate green → `Implemented`. Then re-run automated review → blind code-eval
   → land → finalize → slice W (fold lease-freshness into `parallelism.md`/`orchestration.md`/`run.md`).
   **Re-impl LANDED `eedfc43`** (slice `Implemented`, tree clean, **bats 52/52** = 44+8 new): lease-freshness
   liveness replaces membership/pid; `renewer-start`/`renewer-stop` with `{pid, starttime}` identity gate +
   fd-close detach; T1 (GNU-stat-first), T3 (ENVIRON awk — sid via environ, no escape), T4
   (`LOOM_HOLDERLESS_TTL=2s`), T5 (skipped counter), T7 (factored `try_acquire_holderless`); NEG-R1/NEG-F6
   inverted to verify stale-lease orphan reclaim. Code delta range `21f9970..eedfc43`.
   **NEXT ACTION:** re-run `/code-review` + `/security-review` on the re-implemented helper → refresh
   review-findings → blind code-eval (resolving PASS carries the slice's Round 3 and LANDS slice H; FAIL →
   Round 4, 1 attempt left before its 5-FAIL escalation). Then finalize → slice W. Watch: renewer detach
   correctness, lease-freshness reclaim windows, T1/T4 portability.
   **⚠️ ESCALATED TO OWNER AGAIN (mechanism decision — not a round FAIL; slice counter stays 3).**
   Re-review of the ADR-0015 re-impl (`21f9970..eedfc43`): `/code-review` = ran-with-findings, **~6-8
   CONFIRMED concurrency defects** (U1 `clear_and_own` **CAS ABA/TOCTOU** → fresh lock reclaimed → 2 holders,
   at all 4 call sites; U2 `claim_is_fresh` **fail-OPEN on empty epoch** → live peer double-granted; U3 the
   **lock is never heartbeat** (renewer refreshes the lease not the lock) → long `land` >LOCK_TTL stolen;
   U4 the T4 30s→2s narrowing **widened** the mkdir→stamp double-grant window; U5 `renewer-stop` kills a
   recycled pid when start-time empty; U6 cleanup sweeps live claims + rm-rf session dir). `/security-review`
   = ran-clean. **DIAGNOSIS SHIFT: the DESIGN (ADR 0015) is now sound + stable; the persistent fault is the
   HAND-ROLLED POSIX-sh MECHANISM itself** (mkdir-CAS ABA races, fail-open arithmetic, un-renewed lock,
   narrowed windows) — 4th impl round of subtle concurrency bugs. This is exactly the class **git-native
   atomic primitives (option C)** eliminate. Paused before a round-4 code-eval+dev cycle to put the
   mechanism choice to the owner: **(A)** one more sh patch of U1-U6 (fixable but high subtle-bug rate) vs
   **(C)** pivot the lock/claim mechanism to **git's atomic `update-ref` CAS** (new ADR superseding ADR 0014's
   mkdir-lock mechanism; removes the whole hand-rolled-CAS bug class) — recommend leaning C given 4 rounds.
   **NEXT ACTION: await owner A/C decision.** Slice still `In Progress` at `eedfc43`.
   **OWNER CHOSE C (git-native atomic CAS).** Pivot the lock/claim MECHANISM to git's atomic
   `git update-ref <ref> <new> <old>` CAS: lock = a ref (e.g. `refs/loom/lock`) whose value is an object
   encoding holder + lease-ts; acquire/steal/release via CAS (git's old-SHA compare is **ABA-safe by
   construction** → U1 gone); claims = `refs/loom/claims/<slice>`. git owns the ref-locking atomicity →
   the hand-rolled mkdir-CAS / rename-capture / clear_and_own machinery is DELETED (U1/U3/U4 vanish). The
   renewer also CAS-renews the LOCK ref's lease-ts while held → fixes U3 (long `land` not stolen). KEEP:
   ADR 0014 coordination model + ADR 0015 lease-freshness liveness + `{pid,start-time}` renewer. refs/loom/*
   live in the shared common ref store (all worktrees see them) = natural cross-session medium.
   **NEXT ACTION:** planner authors `.docs/ADR/0016-git-native-ref-cas-lock-mechanism.md` (`Plan Review`) —
   supersede ONLY the lock/claim mechanism/substrate wherever recorded (determine exact scope from ADR 0014
   + spec-04 prose + slice-plan H's mkdir/rename-capture choice); carry forward the non-CAS bugs still to fix
   in the re-impl (U2 fail-open empty epoch, U5 recycled-pid kill, U6 cleanup-sweeps-live, secondary:
   non-atomic pid write / `/proc` field-22 parse) + the T-series portability items → blind plan-eval →
   spec-04 amendment → blind plan-eval → developer RE-IMPLEMENTS with git-CAS → automated review → blind
   code-eval → land → finalize → slice W. Slice `In Progress` at `eedfc43`; slice counter stays 3.
   **ADR 0016 APPROVED** (blind plan-eval PASS `Round: 0`; evaluator empirically verified `git update-ref`
   create-only/value-CAS/delete-CAS in a scratch repo; U1/U4 eliminated, U3 fixed, ABA-safe). README moved
   In Review → Accepted. **3 non-blocking MINORs**, 2 carried to the living layer: (a) **loose-blob cleanup
   story** (per-CAS holder blobs become unreferenced → rely on `git gc`; note it) and (b) **renewer↔release
   known-SHA coordination** (the renewer CAS-renews the lock ref, changing its SHA, so the main thread's
   release/land must CAS on the CURRENT ref value, not a remembered stale SHA); (c) README-timing note now
   moot. **NEXT ACTION:** planner authors the **spec-04 amendment** folding ADR 0016 into the `### Multi-session
   coordination` subsection — REPLACE the mkdir/rename-capture-CAS lock prose with git `update-ref` CAS on
   `refs/loom/lock` + `refs/loom/claims/*` (holder = blob; ABA-safe; common ref store; losing CAS = clean
   retry-with-backoff), note the renewer heartbeats the lock ref (U3), and add MINORs (a)/(b) as re-impl
   notes; keep ADR 0014 coordination + ADR 0015 liveness prose intact → `Plan Review` → blind plan-eval.
   Then developer RE-IMPLEMENTS `loom-coord.sh` on git-CAS (delete the mkdir-CAS/clear_and_own/rename-capture
   + TSV registry; refs substrate; keep lease-freshness + renewer) + fix carried U2(fail-closed epoch)/
   U5(recycled-pid kill guard)/U6(no-sweep-live) + secondary (atomic pid write, `/proc` field-22 parse,
   Linux-exercised start-time/`stat`) → automated review → blind code-eval → land → finalize → slice W.
   **Spec-04 ADR-0016 amendment DONE** (`adr-0016-spec-amendment-eval.md` PASS `Round: 0`; spec 04
   re-Approved; no leftover mkdir/rename-capture/TSV prose; coordination + liveness intact; 1 non-blocking
   MINOR carried). **git-CAS design layer COMPLETE** (ADR 0016 Accepted + spec 04 updated).
   **NEXT ACTION:** developer **re-implements `loom-coord.sh` on git-CAS**: DELETE the mkdir-lock +
   rename-capture CAS + `clear_and_own` + TSV claims registry; lock = `refs/loom/lock` (blob holder record
   via `hash-object -w`), claims = `refs/loom/claims/<slice>`; acquire=create-only CAS (null OID), steal=
   value-CAS on exact read SHA, release=delete-CAS; all `git update-ref` (common shared ref store; losing
   CAS = clean retry-with-backoff). KEEP ADR-0015 lease-freshness + `{pid,start-time}` renewer; renewer also
   CAS-renews the LOCK ref (U3). FIX carried **U2** (fail-CLOSED on empty/non-numeric epoch), **U5** (guard
   `renewer-stop` recycled-pid kill), **U6** (don't sweep live claims / rm-rf live session dir) + secondary
   (atomic `session.pid` write, `/proc/<pid>/stat` field-22 parse robust to spaces/parens, Linux-exercised
   start-time/`stat`) + MINOR notes (loose-blob `git gc`; renewer↔release CAS-on-current-value). Tests: bats
   in a real scratch git repo, red-green, exercise real CAS races (2 contenders → 1 wins). Strict output
   discipline + incremental commits. Gate green → `Implemented` → automated review → blind code-eval → land
   → finalize → slice W. Slice `In Progress` at `eedfc43`; slice counter stays 3.
   **git-CAS re-impl attempt 1 CRASHED on the 32k output cap (3rd infra interruption; NO progress — tree
   clean, no commits, helper still has zero `refs/loom`/`update-ref`, verified).** The single-agent rewrite
   is too large for one response. **NEW APPROACH: split into 3 smaller gate-green developer passes** (each
   commits before the next, so a crash can't wipe it): **Pass 1** lock → `refs/loom/lock` `update-ref` CAS
   (create-only acquire / value-CAS stale-steal / delete-CAS release; holder blob `{sid,lease-ts,pid,start}`;
   DELETE mkdir-lock/`clear_and_own`/rename-capture/holderless-age-gate/`$CAP`/holder-file); keep claims TSV +
   liveness working; gate green → commit. **Pass 2** claims → `refs/loom/claims/<slice>` CAS (delete TSV);
   renewer CAS-renews claim(s) + LOCK ref (U3). **Pass 3** fix carried U2(fail-closed epoch)/U5(recycled-pid
   kill guard)/U6(no-sweep-live) + secondary (atomic pid write, `/proc` field-22 parse) → `Implemented`.
   MAX incremental discipline (one tiny edit per step; no long prose in responses; commit each coherent
   chunk). **NEXT ACTION:** developer Pass 1.
   **Pass 1 DONE `e0699f2`** (gate green bats 47/47): lock = `refs/loom/lock` git-blob + `update-ref` CAS;
   mkdir/`clear_and_own`/rename-capture/holderless/`$CAP` machinery DELETED (verified: 17 refs/loom uses, 0
   old machinery). Claims TSV + renewer + session dirs untouched. Split approach avoided the crash (42 small
   tool calls). **NEXT ACTION: developer Pass 2** — claims TSV → `refs/loom/claims/<slice>` CAS (create-only
   claim / value-CAS renew / delete-CAS release / stale-lease reclaim); renewer CAS-renews claim(s) **+ the
   LOCK ref** (U3 fix); keep lease-freshness liveness. Gate green → commit, stay `In Progress`. Then Pass 3
   (U2/U5/U6 + secondary → `Implemented`).
   **Pass 2 DONE `d342a77`** (gate green bats 51/51): claims TSV → `refs/loom/claims/<percent-encoded-slice>`
   refs; `cmd_renew` lock-free; renewer heartbeats lock + claim refs (U3 fixed). Pass-1 lock tests still pass.
   **NEXT ACTION: developer Pass 3 (final)** — fix carried **U2** (lease-freshness fail-CLOSED on empty/
   non-numeric epoch), **U5** (guard `renewer-stop` recycled-pid kill when start-time empty), **U6**
   (cleanup/reclaim must not remove a LIVE holder's claim / `rm -rf` a live session dir) + secondary (atomic
   `session.pid` write via temp+`mv`; `/proc/<pid>/stat` start-time parse robust to comm spaces/parens —
   split on LAST `)`; Linux-exercised). Red-green tests. Gate green → set `Status: Implemented`. Then re-run
   automated review → blind code-eval (resolving PASS carries the slice's Round 3 and LANDS slice H) →
   finalize → slice W.
   **git-CAS RE-IMPL COMPLETE — 3 gate-green passes, NO crash:** Pass 1 `e0699f2` (lock→`refs/loom/lock`
   CAS), Pass 2 `d342a77` (claims→`refs/loom/claims/*` + renewer heartbeats lock, U3), Pass 3 `9fa9b63`
   (U2 fail-closed epoch / U5 recycled-pid-kill guard / U6 no-sweep-live / secondary: atomic pid write +
   `/proc` last-`)` field-22 parse). Slice `Implemented`, bats **55/55**, shfmt/shellcheck clean. Full
   re-impl code delta = `eedfc43..9fa9b63`. **NEXT ACTION:** re-run `/code-review` + `/security-review` on
   the git-CAS helper → refresh review-findings → blind code-eval. **Resolving PASS carries the slice's
   Round 3 → LANDS slice H at last**; FAIL → Round 4. The git-CAS substrate should finally break the
   fix-introduces-regressions cycle (git owns atomicity). Then finalize → slice W.
1. **DONE — mechanical write-ahead backstop slice (ADR 0013 §Decision 5).** Landed commit
   347e0d3 (code-eval PASS round 0; shell gate green 11/11 + 28/28 bats).
   `plugins/loom/hooks/precompact-write-ahead-backstop.sh` is live — loom's 2nd executable
   hook. **Three non-blocking MINOR follow-ups:** (a) `manual`-block remediation text should
   not suggest "re-run /compact" (re-running blocks identically) — correct wording or add a
   real override; (b) sanitize `session_id` in log line; (c) add rotation/size-cap to
   `precompact.log`.
1. **DONE — automated review in the code-review phase (ADR 0010 + ADR 0011 correction).** The
   ADR 0010 playbook slices landed via worktree parallelism (Slice A `review-findings.md`
   13d62c2; Slice B `orchestration.md` beaa531 ∥ Slice C `code-eval-rubric.md` +
   `code-evaluator.md` 5941bea); then **ADR 0011** corrected the command `/review` → `/code-review`
   (PR-bound → local-diff, empirically verified) across ADR + specs 04/02 + a 4-file playbook
   conformance slice (63e6d01). CLAUDE.md digest current. Remaining non-blocking follow-ups:
   (a) align spec 04's `skipped: command unavailable` prose with the playbook's hyphenated
   token (frozen-spec planner cycle); (b) ADR 0010 Notes open questions (empirically confirm
   built-in spawn behavior; tune `/code-review` confidence threshold). **Worth doing on the very
   next code-bearing slice:** exercise the new step live (the orchestrator actually runs
   `/code-review` + `/security-review` on the slice's **commit range** `git diff
   <base>...<slice-HEAD>`) — every slice so far has been pure-docs, so it has only taken the
   docs-only skip path and never fired in anger.
2. **M4 — Dogfooding & hardening:** remaining threads:
   - **CLAUDE.md auto-propagation:** best practices propagated into root/project
     `CLAUDE.md` automatically.
   - **Escalation/round-limit stress-test:** owner approval gates, round
     limits/escalation polished.
   - **Resume-across-machines:** resume-after-interruption verified across machines.
   - **`claude -p` evaluate-and-close:** `claude -p` fallback evaluated if deeper
     nesting is needed.
2. **DONE — fold ADR 0008 into spec 04 (and spec 08):** completed as M4 dogfood
   run #1 (commit c3cd354, plan-eval PASS, owner-approved). Both specs re-Approved;
   spec 04's Parallelism section now carries ADR 0008's coordination model and spec
   08 records the slice-plans-index ownership change.
3. **DONE — `gates/shell.md`:** produced as M4 dogfooding via the gate-learning
   mechanism on loom's own hook (shell-gate slice, commit 34de27c, gate green 28/28).
   `gates/shell.md` is Status: Verified; 28-case bats suite committed.
4. **Spec-10 line-107 bare-`/loom` fix:** spec 10 still contains a bare `/loom`
   reference at line 107. This is a frozen-spec planner cycle (propose an amendment,
   plan-eval, amend via planning — not a direct edit). The mechanical-check rule now
   in the rubrics ensures this kind of miss is caught earlier in future reviews.

## Notes for the next agent

- Commits are **author-neutral** AND under a **single uniform git identity** —
  roles must not set/override `user.*` (commit-convention; learned from the M1
  first run, where an agent strayed to `loom@localhost`).
- Command surface is `/loom:run` + one-off `/loom:<role>`; agents spawn via Task
  `subagent_type: loom:<role>` (verified).
