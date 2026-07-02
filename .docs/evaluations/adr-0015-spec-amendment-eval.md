# Evaluation: ADR 0015 spec amendment (spec 04 Multi-session liveness)

Verdict: PASS
Round: 0
Reviewed against: ADR 0015 (Approved/immutable) — the decision folded in; ADR 0014 (immutable) — its non-liveness invariants that must survive; ADR 0005 (frozen-spec amendment discipline), ADR 0013, ADR 0003, ADR 0001, ADR 0012; references/plan-eval-rubric.md, references/severity.md; the surrounding spec 04 and the `adr-0014-spec-amendment-eval.md` precedent (consistency)

## Findings

No BLOCKER, MAJOR, or MINOR findings.

Scope of review: the ADR-0015 fold, i.e. the diff `bf881c9..82dd7fe` on
`.docs/spec/04-orchestrator.md` (the only file the amendment commit touches — no ADR
or spec-08 edits). The change is confined to the liveness prose of the
`### Multi-session coordination (ADR 0014, ADR 0015)` subsection; every non-liveness
clause carried over from the (already-PASSed) ADR-0014 version is unchanged. Verified
mechanically (`rg`, `git diff`, `git show --stat`), not by eye.

### Faithfulness to ADR 0015 — all four required points present and accurate

1. **Liveness = lease freshness** (lines 258-261): "alive iff its lease timestamp is
   fresh — renewed within the TTL; a lease older than the TTL is stale → reclaimable,"
   the "sole and sufficient" cross-session signal gating **both** force-clear paths
   (stale lock + stale slice lease). Matches ADR §1.
2. **Membership and pid are NOT cross-session liveness signals; peer decides by lease
   freshness alone** (lines 263-273, restated 200-201 and invariant 387-392): the
   crashed-`wt-<sid>`-persists and ephemeral-pid-already-gone rationales are both
   reproduced; "a peer … never probes a peer's pid and never consults `git worktree
   list` for liveness"; retained pid is "advisory diagnostics only." Matches ADR §4.
3. **Renew obligation via a detached out-of-band background renewer** (lines 275-304):
   ~TTL/3 cadence; must-not-be-loop-driven rationale (single-threaded orchestrator
   suspended 20-40+ min inside sub-agent Task calls → zero loop heartbeats); launched
   exactly once on first acquire (check-then-launch, never duplicated); beats
   independently through a multi-hour sub-agent call; gated on the reuse-robust
   `{session-pid, session-pid-start-time}` pair (`alive(session-pid) && starttime ==
   recorded`); self-terminates on death/kill/pid-recycle so the lease goes stale and the
   work is reclaimable by design; live-but-busy holder never reclaimed; stopped on clean
   session-end. Matches ADR §2/§3.
4. **The pid/start-time gate is local / intra-session only** (lines 291-294, invariant
   399-401): explicitly "the renewer's own honesty check on whether to keep beating its
   own leases … never used as a cross-session liveness signal (doing so would reintroduce
   the stale-pid failure the liveness rule above forecloses)." Matches ADR §4's sharp
   intra- vs cross-session line.

### No regression of the ADR 0014 non-liveness prose

`git diff bf881c9..82dd7fe` confirms the following are untouched in substance (edits fall
only on liveness-bearing clauses):

- **The three locked shared-`main` writes** (lines 366-380; invariant 384-386) — claim,
  lease-renew, land+finalize, all inside the lock; `rg` finds "three" everywhere and no
  residual "two locked writes." The only edit inside this block is write #2's parenthetical
  ("performed by the out-of-band background renewer on the ~TTL/3 cadence"), which is the
  intended fold, not a regression.
- **Cross-session lock / CAS / `lock-TTL`** (lines 219-256) — per-repo mutex under `.git/`
  (mkdir-dir or ref-CAS), ADR 0008 backoff reused, held only for a short bounded op never
  across a role spawn, own short `lock-TTL` distinct from the lease TTL. Intact. The only
  change is that the stale-lock force-clear is now gated on **stamp freshness** (timestamp
  older than `lock-TTL`) instead of a membership/pid probe — the faithful ADR-0015
  application (§1 lease-freshness applied to the lock).
- **Claim check-then-act under the lock** (lines 306-319) — acquire lock, re-read
  lease/Active from current local `main`, abort+reselect if claimed/landed in the interim,
  else write the marker, commit, release, then create the worktree; skip live claims.
  Unchanged.
- **Per-session `.git/` state + off-`main` write-ahead anchor** (lines 335-380) and
  **cold-restart re-adoption/renew** (lines 354-364) — intact; the only edit is that
  bootstrap now refreshes `{session-pid, session-pid-start-time}` and relaunches the
  renewer only if the recorded one did not survive (the ADR-0015 renewer wiring), not the
  superseded "overwrite the recorded pid" liveness rationale.
- **Authoritative read = fresh local `main` under the lock** (lines 205-217) and the
  **session-owned worktrees off fresh local `main`** (lines 203-213) — unchanged.

### No leftover superseded claim

`rg` for `session-id-primary`, `primary, restart-safe`, "alive iff its session-id",
membership-as-primary-liveness: **zero hits.** The two surviving `git worktree list`
mentions (lines 269, 271) are the required demotions ("never consults … for liveness,"
"no longer proves it alive"), not liveness assertions. The claim marker still lists
`pid` (line 314) — consistent, because the liveness rule blanket-declares any pid in a
lease stamp "advisory diagnostics only," and the claim bullet no longer ascribes any
liveness-probe role to it.

### Scope hygiene / consistency

- Immutable ADRs not edited; `git show --stat 82dd7fe` = spec 04 only. Spec 08 untouched
  (correctly deferred — ADR 0015 Consequences wires the playbook/spec-08 fold only after
  this amendment is approved, per ADR 0005).
- Mechanical impl details kept out of the spec: the **portable** process-start-time
  capture is named as **deferred to the POSIX-sh helper slice** (lines 408-413), not
  specified — the spec records the contract (`{session-pid, session-pid-start-time}`
  identity), not the `stat`/`ps -o lstart` mechanism. Correct scope boundary.
- Cross-links resolve: ADR 0015 (Approved), ADR 0013 references present and valid.
- No new `Status:` token; spec 03 unchanged (line 402-405). Consistent with ADR
  §Consequences.
- Frozen-spec discipline (ADR 0005): the artifact sits at `Status: Plan Review` for owner
  re-approval — the deliberate later planning pass ADR 0015 Consequences require, not a
  landing side effect.

## Required changes (for FAIL)

None — this is a PASS.

## Notes

- This is a targeted correction of the previously-approved ADR-0014 liveness prose. The
  ADR-0014 amendment eval flagged the (then-correct) "session-id-primary" liveness rule as
  a deliberate hardening; ADR 0015 supersedes exactly that rule, and this amendment
  replaces it cleanly with lease-freshness while leaving all other ADR-0014 content that
  the prior eval verified intact.
- The subsection is dense, but every clause traces to an ADR 0015 §1-§4 decision or a
  preserved ADR 0014 invariant; length is not a rubric defect.
