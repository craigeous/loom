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
