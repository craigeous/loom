# Coordination State Separation

Status: Landed
Target specs: 03-artifact-lifecycle.md, 04-orchestrator.md
Target size: <= 250 LOC net change (keep this plan document <= 250 lines)

## Context

ADR 0020 and specs 03/04 already decide that claims and work start write no tracked
state on local or remote `main`, that `Ready to Publish` is the durable state between
approved code evaluation and `Landed`, and that finalization artifacts exist only in the
integration candidate. Roadmap M2 slice 1 landed `plugins/loom/bin/loom-land` (fetch
target, disposable candidate, no-force push, push-destination verification, receipt,
claim release only after verification, idempotent recovery) with 37 Bats tests.

Two gaps remain, both in the helper's callers and contract rather than in the claim
refs themselves:

1. The playbook still instructs the orchestrator to re-read Active/claim state "from
   current local `main`" and to "record the slice in the `slice-plans/README.md` Active
   region on main" during claim registration
   (`references/parallelism.md` Create step 2/4; `references/orchestration.md`
   "Claim before working a slice" step 2). That is a tracked-main mutation in the
   claim/work-start path and contradicts ADR 0020 §4 and spec 04.
2. `loom-land` integrates only the slice head. Nothing builds the finalization
   artifacts (archived plan, index, progress, handoff, roadmap) inside the candidate,
   and the helper builds the candidate (running the gate) while holding the publish
   lock and tracks the candidate manifest, so a successful remote update cannot yet be
   proven to carry "exactly one slice plus its finalization artifacts" with a short lock.

This slice closes both and adds the concurrency tests the improvement plan requires.
Single purpose: separate coordination state (refs + session state) from tracked state,
and make candidate-time finalization the only writer of living docs.

## Out of Scope & Threat-Model Boundary

- No `pr-per-slice` or `merge-queue` adapters; `remote-direct` only (ADR 0020 §3). The
  "confirmed PR merge / queue completion" release conditions are documented as
  contract text and remain a mode error in the helper.
- No cross-clone claim exclusion (spec 00 Non-goals; ADR 0020 §5). Tests show remote
  CAS prevents overwrite, not duplicated work.
- No change to claim/lock/lease semantics or `loom-coord` subcommands (ADRs 0015/0016).
- No spec or ADR edits; specs 03/04 already state the target behavior. Doc changes are
  limited to playbook references that contradict them.
- No target-history shape decision (granular vs squash; M8) and no force-push path.
- Trust boundary is unchanged: private `0700` session state, no hostile local
  inode-swapping, no internal helper monkeypatching; `--finalize` is a
  caller-supplied command run in the disposable worktree with the same trust as
  `--gate` (spec 00 Non-goals: no OS-level hostile-code containment).
- Branch-protection rejection (push failed, remote unchanged) remains the exit-10
  unverified result; no mode fallback.

## Steps

1. `plugins/loom/skills/loom-playbook/references/parallelism.md` (Create, multi-session):
   replace step 2 with "derive active-session state from `loom-coord list-claims`
   plus slice artifacts on the slice branch/fetched remote target; local `main` is not
   read as authority", and delete step 4 (Active-region write on main). Note that
   in-progress documentation, when durable evidence is needed, is committed on the
   slice branch only. Fix the "serialize writes to the shared `main` checkout" intro
   sentence to say the lock serializes claim registration and the short publish
   section only.
2. `plugins/loom/skills/loom-playbook/references/orchestration.md` ("Claim before
   working a slice"): same step-2 rewrite; reword "Claim registration and
   land+finalize are the only locked shared-`main` writes" to "Claim registration
   writes only `refs/loom/*`; the publish section is the only locked remote write".
   Add the release rule: release only after verified direct publication (helper exit
   0), confirmed PR merge, or confirmed queue completion.
3. `.docs/slice-plans/README.md` convention (this slice's own registration is the
   only edit made here): the Active index and every other living doc (progress,
   handoff, roadmap) change only inside the integration candidate, never on a slice
   branch or `main` and never by claim acquisition. Note this in the "Active plans"
   intro; slice-branch plan status edits stay in the plan file itself.
4. `plugins/loom/bin/loom-land` manifest: stop committing `.loom/candidate-manifest.json`.
   Write it to `$SDIR/candidate-manifest.json` (private session dir, untracked recovery
   state per spec 03). The candidate is merge(slice) + one finalization commit; its
   tree contains no `.loom/` path. Recovery reads state from `$SDIR` as today.
5. `plugins/loom/bin/loom-land` finalization (new `--finalize <cmd>`, usage updated).
   Contract: pure function of the candidate tree plus exported `LOOM_SLICE`,
   `LOOM_BASE`, `LOOM_SLICE_HEAD`; no clock, network, or randomness.
   - Precondition (fail-closed, exit 1, before any mutation): if `.docs/slice-plans/
     $SLICE.md` exists at `$HEAD_SHA` (read with `git show`, never the working tree or
     local `main`) it must say `Status: Ready to Publish` AND `--finalize` must be
     given. No plan file keeps non-loom repos and existing tests working.
   - In `build()`, after the merge, run `(cd "$WT" && bash -c "$FINALIZE")`; nonzero
     exit is exit 10 with state, claim, and remote untouched. Commit the result as one
     `Finalize slice $SLICE` commit. Both this commit and the preceding merge commit in
     `build()` export fixed `GIT_AUTHOR_*`/`GIT_COMMITTER_*` name, email, and date taken
     from the slice head commit (`git log -1 --format`), overriding the host identity
     and clock, so identical inputs yield an identical SHA at any time or on any host.
   - Completeness check on a managed slice (exit 1, no push, candidate discarded
     unless gate-green): the active plan path is gone, `.docs/slice-plans/archive/
     $SLICE.md` exists, and `.docs/slice-plans/README.md`, `.docs/status/progress.md`,
     `.docs/status/handoff.md`, `.docs/status/roadmap.md` each differ from `$BASE`.
   - The finalize string joins the reuse key in `write_state`; changing it forces a
     rebuild at a new SHA, so evidence bound to the old candidate is rejected (exit
     3, fresh evidence required). A failed finalize never writes `candidateSha`.
6. `plugins/loom/bin/loom-land` lock scope: rebuild and gate run only outside
   `refs/loom/lock`. Order: build+gate (unlocked) -> acquire lock -> re-fetch/compare
   -> push -> remote verification -> receipt -> unlock. If the re-fetch shows the base
   moved, release the lock and exit 3 (state kept, `publishAttempt` still false, no
   rebuild under the lock); the next run rebuilds and gates unlocked and needs fresh
   evidence for the new candidate SHA.
7. `plugins/loom/bin/loom-land` rejected-push recovery. A push is *positively rejected*
   only when `git push` failed AND `ls-remote` succeeded AND the remote SHA is not
   `$CAND`, does not contain `$CAND` (`merge-base --is-ancestor $CAND <remote>` is false),
   is not contained in the candidate, and descends from `$BASE`. Then reset
   `publishAttempt` to false and exit 3 (rebuild next run, no owner action). If `$CAND`
   is an ancestor of the remote (a failed push the server accepted, then another
   publisher advanced), that is containment recovery as today: keep `publishAttempt`,
   treat as landed, verify, receipt, release. If ancestry cannot be determined (missing
   objects, git error), fail closed as uncertain. Every other outcome (push ok but
   remote differs, `ls-remote` unreadable, remote unrelated to `$BASE`) stays uncertain: `publishAttempt` remains true and exit 10 owner action
   applies unchanged. Network failure in `fetch_target` stays exit 10, state untouched.
8. `plugins/loom/bin/loom-land.bats`: add `# ---- coordination-state separation ----`
   with helper `slice_commit <clone> <name>` (slice branch with a Ready to Publish
   plan at `.docs/slice-plans/<name>.md`, `<name>.txt`, status docs on base) and `FIN`,
   a deterministic script that `git mv`s the plan to `archive/`, and appends the slice
   to README, progress, handoff, and `.docs/status/roadmap.md`. Update only the existing test at
   `loom-land.bats:189` to assert the manifest is in `$SDIR`, not the tree. Tests:
   a. *claim/work-start leave tracked main untouched*: local `main` SHA and
      `git status --porcelain` unchanged after claim; `list-claims` shows the slice.
   b. *publication carries exactly one slice plus finalization*: remote tree base..tip
      shows only slice files and the five finalization paths, one merge of `slice-a`,
      and no `.loom/` path.
   c. *unrelated session-1 local-main history is never published*, also after rebuild.
   d. *missing/incomplete finalization is rejected*: no `--finalize` on a managed
      slice, and a `FIN` that skips handoff each exit 1, remote and claim untouched.
   e. *finalization is repeatable*: delete state and candidate ref, rebuild with
      `--candidate-only` after a different `GIT_*_DATE`/identity (and a sleep past one
      second); both runs give the same SHA, including the merge parent. A failing `FIN` exits 10, writes
      no `candidateSha`, keeps the claim, and leaves the remote unchanged.
   f. *changed finalize command invalidates the candidate*: rerun with an altered
      `FIN`; SHA differs, old evidence is rejected with exit 3, matching new evidence
      publishes.
   g. *lock scope*: a gate/finalize stub records whether `refs/loom/lock` exists;
      it never does at gate time. A target move between build and lock exits 3 without
      running the gate under the lock.
   h. *positive rejection is recoverable*: loser exits 3, `publishAttempt` false, next
      run rebuilds on the winner's base (progress has both slices' lines) with fresh
      evidence and publishes. Uncertain case (stubbed unreadable `ls-remote`) keeps
      `publishAttempt` true and exits 10 on rerun. Containment case: stub `git push` to
      fail after pushing `$CAND`, then advance the remote with a descendant of `$CAND`;
      `publishAttempt` stays true, no second push (`pushes` 1), exit 0 with receipt and
      claim released.
   i. *offline publication keeps everything* (exit 10, `main` SHA unchanged, claim and
      `Ready to Publish` plan present, no receipt).
   j. *post-publication cleanup crash recovers without a second push* (`count_hook`,
      failing `release-claim` once via `stub_coord`; `pushes` stays 1, claim released).
9. Run the full gate (see Verification); shell-format fixes stay inside the files above.

## Verification

Gate (shell, per `gates/shell.md`), run once on the candidate commit:

```
TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check
node scripts/validate-repository.mjs --root . --all
```

Developer iteration:

```
shfmt -i 4 -d plugins/loom/bin/loom-land plugins/loom/bin/loom-land.bats
shellcheck -s bash plugins/loom/bin/loom-land
TMPDIR=/private/tmp bats --filter "coordination-state|finalize|offline|Ready to Publish" plugins/loom/bin/loom-land.bats
```

New behavior is proven by tests 8a–8j. The existing `loom-land.bats` tests (except the
single manifest assertion in step 8) and the `loom-coord.bats` suite must pass unchanged (regression proof that claim/lock/lease
and receipt semantics are untouched). A mechanical `rg -n "Active region on main|from
current local .main."` over `plugins/loom` must return no hits after steps 1–2. Net
change estimate: ~70 LOC `loom-land`, ~150 LOC bats, ~25 LOC docs.

## Implementation Evidence

- Steps 1–8 implemented. `loom-land.bats` now has 50 tests (37 existing + 13 new for 8a–8j;
  8h is three tests, plus a not-Ready-to-Publish precondition test); all pass under
  `/bin/bash` 3.2. `shfmt -i 4`, `shellcheck -s bash`, and `bash -n` are clean.
- Two existing assertions changed because step 7 supersedes them: the manifest test
  (now asserts `$SDIR/candidate-manifest.json` and no `.loom/` in the tree) and the
  separate-clone race test (loser now resets `publishAttempt` to false and the retry exits
  3 instead of 10).
- On target movement detected under the lock, `loom-land` releases the lock, rebuilds and
  gates unlocked, and exits 3 (existing contention tests keep their rebuilt-candidate assertion).
- Full gate: see the Final gate line below.

## Notes

_No clarification requests._ `--finalize` stays a caller-supplied command (mirrors `--gate`), but the helper now enforces its output set; the orchestrator's script owns file contents per spec 03.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |
| 1 | Manifest moved to untracked `$SDIR` (not committed); finalization required and completeness-checked fail-closed for all five artifacts, deterministic and reuse-keyed; rebuild/gate moved outside the publish lock; positive push rejection recovers (exit 3) while uncertain pushes keep exit 10; Active index writes reserved for the candidate; tests 8d–8h added |
| 2 | Rejection recovery now excludes remotes containing the candidate (containment recovery, attempt preserved, fail closed on unknown ancestry; test added); roadmap path corrected to `.docs/status/roadmap.md` in check and test finalizer; merge commit and finalization commit both use deterministic identity/date from the slice head, rebuild tested across times |
