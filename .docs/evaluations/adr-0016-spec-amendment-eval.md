# Evaluation: spec 04 — Multi-session coordination amendment (ADR 0016 fold)

Verdict: PASS
Round: 0
Reviewed against: ADR 0016 (Approved/immutable), ADR 0014 (immutable), ADR 0015
(immutable), ADR 0005 amendment discipline; plan-eval rubric.

## Findings

- [MINOR] Lease-renew remains framed as "locked write #2" (subsection + invariant list,
  lines 310, 425–429) even though a claim-ref CAS is atomic on its own and the
  out-of-band renewer runs independently of the main-critical-section lock. This
  belt-and-suspenders framing is carried forward faithfully from the prior-approved
  ADR-0015 amendment and is explicitly preserved by ADR 0016 §5 ("the three locked
  shared-`main` writes"), so it is not a contradiction — just a slight redundancy the
  helper slice may clarify. No action required.

## Verification performed

Faithfulness of the ADR-0016 substrate fold — all present and accurate:
- lock = `refs/loom/lock`, blob holder record `{session-id, lease-timestamp,
  session-pid, start-time}` via `git hash-object -w` (no author/committer metadata) —
  lines 234–246, matches ADR 0016 §1.
- claims = per-slice `refs/loom/claims/<slice>`, blob `{session-id, lease-timestamp}` —
  line 350, matches ADR 0016 §2.
- acquire = create-only CAS from null OID; stale-steal = value-CAS on exact read SHA
  (staleness-gated); release = delete-CAS on own blob — lines 247–254, 282–284, matches
  ADR 0016 §1.
- claim/renew/reclaim expressed as CAS ops — lines 364–386, matches ADR 0016 §2.
- ABA-safe by construction (old-value = exact prior SHA, checked under git's per-ref
  lock); losing CAS = clean retryable failure — lines 255–263, matches ADR 0016 §1/§4.
- common (shared) ref store, never a per-worktree/`refs/worktree/` namespace — lines
  234–235, 471–472, matches ADR 0016 §4.
- U3 fix — renewer CAS-renews the **lock ref's** own `lease-timestamp` while held, so a
  long `land` is not stolen mid-critical-section — lines 322–327, 428–429, matches
  ADR 0016 §3.
- Both re-implementation review notes carried: (a) loose-blob `git gc` cleanup; (b)
  renewer↔release CAS-on-current-value — lines 327–330, 473–477, matches ADR 0016 §5/Notes.

ADR-0015 open-parameter claim (specifically checked): the amendment states it "resolves
ADR 0015's open inline-vs-sidecar lease-storage parameter to a ref" (line 352). ADR 0015
Notes (lines 362–364) explicitly leave that open ("an ADR 0014 open parameter,
unchanged"). Resolving it via ADR 0016's ref decision is therefore legitimate, not a
contradiction of an immutable ADR.

No leftover superseded primitive prose: `grep -nEi 'mkdir|rename-capture|rename\(2\)|
clear_and_own|\bCAP\b|TSV|registry|main\.lock|holder stamp|holder file|acquired-timestamp|
stamp freshness|rmdir'` — the only `mkdir`/`rename-capture` hits (lines 206–207, 261–262,
470) are supersession framing ("replacing/retiring the hand-rolled X"), mirroring ADR
0016 §1's own retirement language; the mkdir *primitive* as a live mechanism is gone. No
residual holder-stamp / acquired-timestamp / `rm -rf`-lock prose. The one `stamp` hit
(line 304) is "lease stamp" in the unchanged ADR-0015 liveness paragraph — generic
lease-record wording, not the retired holder-stamp.

No regression of non-mechanism prose (diff `git show 71342a1` confirms these hunks are
untouched or mechanism-only): session-owned slice worktrees (214–224), authoritative
read of local `main` under the lock (226–232), the ADR-0015 lease-freshness liveness rule
(290–305, untouched), per-session `.git/` write-ahead anchor off `main` (388–404;
only edit: "alongside the lock dir" → "alongside loom's other under-`.git/` coordination
state", a correct consequence of the lock dir no longer existing), `session-id` stable
across restart (406–417, untouched), and exactly three locked shared-`main` writes
(419–437) all remain stated and correct.

Scope hygiene: `git show --name-only 71342a1` touches only `.docs/spec/04-orchestrator.md`
— no immutable ADR edited, spec 08 untouched. Deferred values (TTLs, cadence fraction,
field encoding, exact ref names, spawn/reap primitive, portable start-time capture,
per-session state location) remain deferred (lines 477–484); the spec records the
contract, not the implementation. All ADR cross-links (0001/0003/0005/0008/0012/0013/
0014/0015/0016) resolve.

## Notes

The fold is faithful and internally consistent, and confines every change to the
`### Multi-session coordination` subsection. The MINOR above is an observation for the
downstream helper slice, not a required change.
