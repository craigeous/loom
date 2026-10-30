# Coordination State Separation

Status: Plan Review
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
   artifacts (roadmap, progress, handoff, archived plan, index) inside the candidate,
   so a successful remote update cannot yet be proven to carry "exactly one slice plus
   its finalization artifacts".

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
- Branch-protection rejection remains the existing exit-10 unverified-publication
  result; no mode fallback.

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
   only edit made here): an Active entry is written when a plan is committed on its
   slice branch/candidate, never by claim acquisition. Note this in the "Active plans"
   intro.
4. `plugins/loom/bin/loom-land`: add optional `--finalize <cmd>` (parsed with `--gate`;
   usage header updated). In `build()`, after the merge and before the manifest commit,
   run `(cd "$WT" && bash -c "$FINALIZE")`; fail with exit 10 on nonzero; if it
   changed the tree, `git add -A` excluding `.loom/` and commit
   `Finalize slice $SLICE` as one commit. The finalize string joins the
   candidate-reuse key in `write_state` so a changed command forces a rebuild. The
   candidate is thereby merge(slice) + one finalization commit + manifest. No tracked
   file on local `main` is touched; the existing fast-forward mirror update after
   verified publication is unchanged.
5. `plugins/loom/bin/loom-land` precondition: before `build`, require the slice head's
   plan (`.docs/slice-plans/$SLICE.md`, when present at `$HEAD_SHA`) to carry
   `Status: Ready to Publish`; otherwise `die 1`. A missing plan file is allowed so
   existing tests and non-loom-plan repos keep working. Reads use
   `git show "$HEAD_SHA:…"`, never the working tree or local `main`.
6. `plugins/loom/bin/loom-land` network failure: confirm `fetch_target` failure maps to
   exit 10 with state and claim untouched and no local-main change; adjust only if the
   new test shows a gap (expected: none).
7. `plugins/loom/bin/loom-land.bats`: add a section `# ---- coordination-state
   separation ----` with a helper `slice_commit <clone> <name>` that creates
   `slice-<name>` with a plan at `.docs/slice-plans/<name>.md` (`Status: Ready to
   Publish`) plus `<name>.txt`, claims it for a second session, and a
   `FIN` command that appends a line to `.docs/status/progress.md`. Tests:
   a. *claim and work-start leave tracked main untouched*: after `setup`, local `main`
      SHA and `git status --porcelain` equal their pre-claim values and no
      `refs/heads/main` commit mentions the claim; `list-claims` shows the slice.
   b. *publication carries exactly one slice plus finalization*: publish slice A with
      `--finalize`; `git log --first-parent`/`diff-tree` over base..remote show the
      slice files, the finalization file set only, and `.loom/candidate-manifest.json`
      — no other paths and exactly one merge of `slice-a`.
   c. *second session cannot publish the first session's unrelated local-main
      history*: commit `unrelated.txt` on session 1's local `main` (ahead), publish
      slice B from session 2's clone; remote tree lacks `unrelated.txt`, and session
      1's later publish (after rebuild) still lacks it.
   d. *rejected publisher rebuilds against the new target*: extend the existing
      separate-clone race with `--finalize`; loser exits 3, candidate `baseCommit`
      equals the winner's candidate, finalization is re-applied on the new base
      (progress file contains both slices' lines after the loser's second run with
      fresh evidence).
   e. *offline publication keeps everything*: set the push/fetch URL to a nonexistent
      path; run publish; exit 10, local `main` SHA unchanged, claim present,
      `list-claims` non-empty, plan on slice head still `Ready to Publish`, no receipt.
   f. *plan not Ready to Publish is rejected before mutation* (exit 1, remote untouched).
   g. *post-publication cleanup crash recovers without a second push*: reuse
      `count_hook`; kill cleanup by stubbing `release-claim` to fail once (existing
      `stub_coord`), rerun, assert `pushes` stays 1 and the claim is released.
8. Run the full gate (see Verification); record shell-format fixes only inside the
   files above.

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

New behavior is proven by tests 7a–7g. The 37 existing `loom-land.bats` tests and the
`loom-coord.bats` suite must pass unchanged (regression proof that claim/lock/lease
and receipt semantics are untouched). A mechanical `rg -n "Active region on main|from
current local .main."` over `plugins/loom` must return no hits after steps 1–2. Net
change estimate: ~25 LOC `loom-land`, ~120 LOC bats, ~30 LOC docs.

## Notes

_No clarification requests._ Open design point for plan evaluation: `--finalize` is a
generic command hook (mirrors `--gate`) rather than the helper hard-coding which living
docs to edit; the orchestrator's finalize script owns the file list per spec 03.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |
