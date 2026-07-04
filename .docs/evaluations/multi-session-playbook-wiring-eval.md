# Evaluation: multi-session-playbook-wiring-plan

Verdict: PASS
Round: 0
Reviewed against: `.docs/spec/04-orchestrator.md` § "Multi-session coordination
(ADR 0014, ADR 0015, ADR 0016)"; ADR 0014/0015/0016; the frozen CLI
`plugins/loom/lib/loom-coord.sh`; and the four target bodies
(`references/parallelism.md`, `references/orchestration.md`, `commands/run.md`,
`SKILL.md`). Invariants verified mechanically with `rg`, not by eye.

## Findings

- [MINOR] Line-number anchors in the Steps are approximate (marked `~`) and a few
  are off by a line or two against the current tree (e.g. "What stays serial
  ~229-247" is actually 230-246; "Concurrency safety ~183-226" starts at 182;
  "Agent-input freshness ~103-108" at 102). The plan explicitly instructs the
  implementer to re-verify every reference against the real tree before relying on
  it, and every named section header resolves, so this does not impede execution.
- [MINOR] Mapping row "Launch the renewer" cites the success token
  `renewer-started`; the helper prints `renewer-started pid=<n>`. Prefix match, and
  the plan says the table is phrased-not-verbatim, so harmless — worth noting only
  so the prose does not assert an exact-string equality the CLI does not emit.

## Mechanical verification performed

- **Every subcommand named in the plan exists in the dispatch** (`case
  "$SUBCOMMAND"`, lines 1321-1343): `lock-acquire`, `lock-release`, `lock-holder`,
  `lock-verify`, `claim`, `renew`, `release-claim`, `reclaim`, `list-claims`,
  `session-start`, `session-bootstrap`, `session-end`, `checkpoint-write`,
  `checkpoint-read`, `cleanup`, `renewer-start`, `renewer-stop` — all 17 present. No
  invented subcommand.
- **Every exit code the plan branches on matches the helper**, both the header
  (lines 27-36: `0/1/3/4/5/6/10`) and the per-command bodies: `session-start` 0/10;
  `renewer-start` 0/5/10; `session-bootstrap` 0/3/5; `lock-acquire` 0/3/10;
  `lock-verify` 0/5/10; `claim` 0/4/5/10; `reclaim` 0/4/5/6; `renew` 0/5;
  `release-claim` 0/5; `lock-release` 0/5; `session-end` 0/3 (never `rm` state on
  3, per `cmd_session_end`); `cleanup` 0/3. The action→subcommand→exit-code mapping
  is accurate against the real helper.
- **Faithfulness to spec 04.** The plan folds in the actual model: git-CAS
  lock/claims as `refs/loom/lock` + `refs/loom/claims/<slice>` in the common ref
  store; lease-freshness as the sole cross-session liveness signal; the
  `{session-pid, start-time}`-gated background renewer as an intra-session honesty
  check only; session lifecycle (`session-start` → work → `session-end`,
  `session-bootstrap` on cold-restart); claim-before-work under the lock; the three
  locked shared-`main` writes; and the current-**local**-`main` dispatch scan with
  `origin/main`/`list-claims` as unlocked pre-filters only. Terminology parity is
  called out as a verification check.
- **Correct supersession.** Step 1f replaces the `index.lock`-centric framing of the
  *coordination mechanism* with git-CAS (losing CAS = clean retry, exit 3 backoff)
  while preserving the lower-level `index.lock` object-store note — matching spec 04
  line 263 ("reuses ADR 0008's exponential backoff … now under a git-native
  primitive"). Step 1d correctly flags the existing `origin/main` worktree base
  (parallelism.md lines 104/119/122) as now-contradicting spec 04 and rebases it to
  local `main`. ADR 0008's disjoint-file/worktree-isolation guarantees are preserved,
  not deleted (checks 6).
- **Scope discipline.** `loom-coord.sh`/bats/hooks/spec/ADR correctly out of scope
  (frozen); automated review correctly `skipped: docs-only` (spec 04 lines 118-119,
  ADR 0010); acceptance is `rg`-based doc-consistency, not the shell gate.
- **Cross-refs resolve.** Proposed `../../../../../.docs/ADR/0014…` link depth (5
  levels from `references/`) matches the existing convention in parallelism.md
  (lines 7, 151) and resolves to a real file; ADR 0014/0015/0016 and spec 04 all
  exist; all four target files and their named sections exist.
- **Conformance.** Uses the slice-plan shape, `Status: Plan Review`, correct
  location/name (`<slice>-plan.md`).

## Required changes (for FAIL)

None. The two MINOR items do not block; the author may absorb them at
implementation time.

## Notes

This is an executable, self-contained, single-purpose plan whose highest-risk
element — the normative {orchestrator action → `loom-coord` subcommand + exit code}
mapping — was checked subcommand-by-subcommand and code-by-code against the frozen
helper and matches. The plan reads as an accurate implementation of spec 04's
Multi-session coordination section into the playbook bodies, with supersession of
the stale single-session lock prose handled correctly rather than left contradictory.

---

# Code-review evaluation

Verdict: PASS
Round: 0
Commit reviewed: `217b9a5` (pure-docs). Diff read via `git diff 217b9a5~1 217b9a5`.
Reviewed against the Approved plan, spec 04 § "Multi-session coordination", ADR
0014/0015/0016 (+ preserved ADR 0008 facts), and the frozen CLI
`plugins/loom/lib/loom-coord.sh`. Invariants checked mechanically with `rg`, not by
eye.

**Gate:** pure-docs slice — no shell gate applies; automated review correctly
`skipped: docs-only` in the review-findings artifact (nothing to re-run; ADR 0010 §5).

## Mechanical verification performed

- **Subcommand/exit-code fidelity — the top check — PASSES.** Every `loom-coord`
  subcommand named across the four edited files (`session-start`,
  `session-bootstrap`, `session-end`, `lock-acquire`, `lock-release`, `lock-verify`,
  `claim`, `reclaim`, `release-claim`, `renew`, `list-claims`, `renewer-start`,
  `renewer-stop`, `checkpoint-write`, `checkpoint-read`, `cleanup`) exists in the
  `case "$SUBCOMMAND"` dispatch (lines 1321-1343). No invented subcommand. Every
  exit code cited matches the header (27-36) AND the per-command bodies:
  `session-start` 0/10; `renewer-start` 0/5/10; `session-bootstrap` 0/3/5;
  `lock-acquire` 0/3/10; `lock-verify` 0/5/10; `claim` 0/4/5/10; `reclaim` 0/4/5/6;
  `release-claim` 0/5; `lock-release` 0/5; `session-end` 0/3 (never `rm` on 3, per
  `cmd_session_end`); `cleanup` 0/3; `checkpoint-write` 0/5. Blob-format claims
  (`{sid}\t{ts}\t{pid}\t` for the lock, `{sid}\t{ts}\t{b64-slice}` for claims) match
  `_make_blob_for` / `_make_claim_blob_for`. Checkpoint path
  `.git/loom/session-<id>/checkpoint` matches `STATE_DIR`/`cmd_checkpoint_write`.
- **Faithfulness to spec 04 / ADR 0015-0016 — PASSES.** Liveness is stated as lease
  freshness everywhere; the only pid/worktree-membership mentions are the explicit
  "**never** cross-session liveness signals" / "intra-session honesty check only"
  framing (parallelism.md 181-182, 289-290, 386-387, 414-416) — no forbidden
  assertion remains. Git-CAS lock/claims (`refs/loom/lock`, `refs/loom/claims/<slice>`),
  the `{session-pid,start-time}` renewer, claim-before-work under the lock,
  main-lock critical section, `lock-verify` pre-land guard, current-local-`main`
  dispatch scan with `origin/main`/`list-claims` as unlocked pre-filters, and the
  `session-start`/`session-bootstrap`/`session-end` lifecycle are all present and
  correct. The three locked shared-`main` writes (claim / lease-renew / land+finalize)
  match spec 04 lines 419-425.
- **No stale/contradictory prose — PASSES.** The old `git worktree add … origin/main`
  base is rebased to `main` in both the Create block and the Agent-input-freshness
  prose; remaining `origin/main` mentions are only the correct "unlocked pre-filter,
  never authoritative" framing. The `index.lock`-backoff prose is preserved but
  correctly subordinated to the git-CAS coordination layer. ADR 0008's
  disjoint-file / worktree-isolation guarantees are preserved and presented as
  extended, not replaced.
- **Consistency — PASSES.** All four files reference `loom-coord`; the added
  ADR 0014/0015/0016 + spec-04 relative links resolve to real files; cross-section
  pointers (`orchestration.md` ↔ `parallelism.md` → *Multi-session coordination*)
  resolve; terminology matches spec 04.
- **Scope discipline — PASSES.** Only the four planned files changed; no code, spec,
  ADR, bats, or hook touched.

## Findings

- [MINOR] parallelism.md session-lifecycle table and orchestration.md describe the
  renewer success tokens as `renewer-started` / `renewer-already-running`; the helper
  prints `renewer-started pid=<n>`. Prefix match; the prose does not assert exact
  string equality, so harmless. (Carried forward from the plan-eval MINOR.)

## Required changes (for FAIL)

None.

## Notes

Clean, faithful wiring of the settled multi-session model into the four
orchestrator-facing bodies. The load-bearing {action → subcommand → exit-code}
mapping was verified command-by-command against the frozen helper and is accurate;
the stale single-session lock/`origin/main` prose is superseded, not left
contradictory; ADR 0008 facts are preserved. The one MINOR is cosmetic. PASS.
