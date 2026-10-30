# docs-governance/reconciliation — Remediation-2 reconciliation edits under ADR 0025

Status: Archived
Slice type: docs-governance
Class: docs-governance/v1
Target specs: 03-artifact-lifecycle.md, 04-orchestrator.md
Target ADRs: 0006, 0014, 0015, 0016, 0017, 0025 (+ ADR README)

## Context

ADR 0025 (`Accepted-by-owner`; acceptance and cold plan-eval records are already
placed in `.docs/evaluations/`) DECIDES the reconciliation rules and DEFERS the
concrete edits to "the first `docs-governance/v1` §7 slice, which also carries this
accepted ADR to `main`" (ADR 0025 Consequences → *Deferred to the reconciliation
implementation step*). **This is that slice.** It implements exactly the eight
deferred, docs-only reconciliation edits below and carries ADR 0025's
`Status: Accepted` disposition to the target.

This slice is the first member of the persistent `docs-governance/v1` class ADR 0025
§B.1 authorizes. It is eligible under ADR 0025 §B.2: it declares class membership
(fields above), its path allowlist is confined to `.docs/**` + root
`README.md`/`CLAUDE.md`/`AGENTS.md`, and it introduces **no** product/executable/test
change. Its §7 evidence is blind plan-eval + a distinct cold docs code-eval over the
`base..head` diff + `scripts/check` green (no §3 three-finder package), per ADR 0025
§B.2.

**Two ledger-bound files are already present in the worktree and MUST NOT be modified
by this slice** — their blobs are bound into the accepted ADR-0025 ledger successor
(`adr-0025-no-bypass-target-landing/v1`) and must stay byte-identical:

- `.docs/evaluations/0025-reconciliation-authority-acceptance.md`
  (blob `0a91d3ca33b9a00d6da995596b42c28528e16d01`)
- `.docs/evaluations/0025-reconciliation-authority-eval.md`
  (blob `0e1c4d6604e2831d256b02844b3504e5a4581334`)

The slice includes them as-is (they are already staged for this branch); it adds only
a pointer entry to `evaluations/README.md` for them (Step 1), never edits their bodies.

**Out of scope.** No change under `plugins/loom/**`, `scripts/**`, `bin/**`, hooks, or
any test path. No new ADR decision, no re-opening of ADR 0025's decided rules, no
rewrite of any accepted ADR's *decision prose* (only the explicitly-authorized Status-
token correction, the ADR-0025-directed 0006 body restoration, and additive forward/
errata notes). History is not rewritten; prior direct pushes stay recorded deviations.

## Path allowlist (docs-governance-confined; declare exactly)

Every edit MUST fall inside this set; a candidate touching any other path is not a
docs-governance slice (ADR 0025 §B.2 item 3):

- `.docs/ADR/0006-distribution-self-marketplace.md`
- `.docs/ADR/0014-multi-session-worktree-coordination.md`
- `.docs/ADR/0015-lease-renewal-heartbeat-liveness.md`
- `.docs/ADR/0016-git-native-ref-cas-lock-mechanism.md`
- `.docs/ADR/0017-infrastructure-blocked-escalation.md`
- `.docs/ADR/0025-reconciliation-authority-plugin-root-no-bypass-landing.md`
- `.docs/ADR/README.md`
- `.docs/spec/03-artifact-lifecycle.md`
- `.docs/spec/04-orchestrator.md`
- `.docs/evaluations/README.md`
- `.docs/evaluations/0025-reconciliation-authority-acceptance.md` *(include as-is; do NOT edit)*
- `.docs/evaluations/0025-reconciliation-authority-eval.md` *(include as-is; do NOT edit)*
- `.docs/slice-plans/docs-governance-reconciliation.md` *(this plan)*
- `.docs/slice-plans/README.md`
- `.docs/repository-improvement-plan.md`
- `.docs/status/progress.md`
- `.docs/status/handoff.md`
- `.docs/status/roadmap.md`
- root `README.md`, `CLAUDE.md`, `AGENTS.md` — **only if** a corrected reference below
  actually appears there (verify with `rg` first; do not touch otherwise)

**Explicitly NOT touched:** `plugins/loom/**`, `scripts/**`, `bin/**`, any hook,
helper, or test. There is no product/executable change in this slice.

## Steps

Each step is docs-only and file-scoped.

### 1. Accept ADR 0025 and index its acceptance

- In `.docs/ADR/0025-…-no-bypass-landing.md`, change line 3 `Status: Plan Review` →
  `Status: Accepted`. Change nothing else in the ADR body (it is now immutable; its
  round-0 MINORs were already folded in before acceptance).
- In `.docs/ADR/README.md`, move the ADR 0025 entry from the `## In Review` section
  (currently the sole entry there) into the `## Accepted` list, appended after the
  ADR 0024 entry, preserving its descriptive one-liner. Leave `## In Review` present
  but empty (or remove it if that matches the file's prior convention for an empty
  section — verify how the file handled this before).
- In `.docs/evaluations/README.md`, add two pointer bullets (matching the existing
  bullet style) for the two pre-placed 0025 records: the cold plan-eval
  (`0025-reconciliation-authority-eval.md` — `bootstrap-ratification: degraded`,
  PASS round 0 with three MINOR folded, resolving PASS; advisory) and the owner
  acceptance (`0025-reconciliation-authority-acceptance.md` — dispositive owner gate,
  Accepted 2026-07-25). Do NOT edit the two record files themselves.

### 2. Restore ADR 0006's body and record the supersession

- Restore the **body** of `.docs/ADR/0006-distribution-self-marketplace.md` to its
  exact pre-rewrite text. The authoritative source is:
  `git show 5e0b178^:.docs/ADR/0006-distribution-self-marketplace.md`
  (the parent of the in-place rewrite commit `5e0b178`). Verify that command's output
  first; the restored Context/Decision/Consequences prose must match it byte-for-byte
  (root `source: "."`, both manifests at repo root, `plugins/loom/` named only as the
  OQ-E fallback).
- Keep 0006's original header line, `Status: Accepted`, and `Date: 2026-06-08` — the
  original decision's identity is preserved; it is NOT re-dated or re-statused.
- Add exactly **one** forward-pointer blockquote note directly under the header, in the
  exact style ADR 0001 already uses for its ADR-0007 supersession (see
  `.docs/ADR/0001-…` lines 6–8). Suggested text:
  `> Note: the repo-root plugin-root decision below is superseded by ADR 0025 on the`
  `> plugin-root location; the implemented reality is the ./plugins/loom subdir.`
  This note points forward only and does not alter the decision prose, so immutability
  is preserved (0006 reads as originally written plus a supersession pointer, exactly
  as 0001 does). Make no other change to 0006.
- In `.docs/ADR/README.md`, update the ADR 0006 `## Accepted` entry to note
  "plugin-root location superseded by 0025" (append a trailing clause to its bullet in
  the same style the file uses for other supersession notes, e.g. the 0007/0011/0016
  entries).

### 3. Correct the ADR status token on 0014–0017 and the README lifecycle text

- In each of `.docs/ADR/0014-…`, `0015-…`, `0016-…`, `0017-…`, change line 3
  `Status: Approved` → `Status: Accepted`. This is the spec-03 lifecycle token
  correction ADR 0025 Consequences directs (spec 03 reserves `Accepted` for ADRs;
  `Approved` is for research/spec/plan). Change nothing else in those ADR bodies.
- In `.docs/ADR/README.md` line 10, correct the ADR lifecycle string
  `Draft → Plan Review → Approved` → `Draft → Plan Review → Accepted` so it matches
  spec 03's `ADR: Draft -> Plan Review -> Accepted`. (README is a Living index; this
  is a correction, not a spec change.)

### 4. Harmonize specs 03 and 04 (owner-authorized reconciliation of frozen specs)

Frozen-spec edits are legitimate here as the ADR-0025 owner-authorized reconciliation.
Follow the ADR-0024 amendment precedent (each spec already carries an appended
`### ADR 0024 …` subsection): make the minimal corrections, then record this
reconciliation in an appended `### ADR 0025 reconciliation` subsection in each spec.

- **`.docs/spec/03-artifact-lifecycle.md`:**
  - `## Authority` (lines 7–15): add ADR 0024 and ADR 0025 to the cited list (0024 is
    the dogfood-amendment authority already exercised in this spec; 0025 is the
    reconciliation authority). Keep link style consistent with existing entries.
  - Reconcile the closed-list / "only M0, M1, and `remote-first-integration-candidate`"
    statements (the eligible-slice table lines 111–118, the closed-list prose lines
    108–126, and the landing-procedure statement line ~174) with the ADR-0024 dogfood
    append (the `### ADR 0024 dogfood slice eligibility` subsection) and the ADR-0025
    `docs-governance/v1` class. The audit flagged that the ADR-0024 dogfood slices and
    now the ADR-0025 docs class were added without reconciling the "only M0/M1/remote-
    first" absolutes. The fix is minimal and additive: where the spec says the eligible
    set / landing-eligible set is closed to "only" those milestones, note that it is
    further extended, by accepted ADR only, to the ADR-0024 named dogfood slices and to
    the persistent ADR-0025 `docs-governance/v1` class (each still individually planned,
    blind-evaluated, path-confined, gated, and settled). Do NOT weaken any invariant
    (still: closed set, changeable only by accepted ADR; no force; non-force remote-
    direct; local status never establishes `Landed`).
  - Append a `### ADR 0025 reconciliation` subsection recording this amendment
    (authority added; closed-list/landing statements harmonized with the 0024 dogfood
    slices and the 0025 docs-governance class; owner-authorized per accepted ADR 0025).
- **`.docs/spec/04-orchestrator.md`:**
  - `## Authority` (lines 7–12): add ADR 0024 and ADR 0025 (0024 is currently missing;
    the range presently ends at 0023). Keep the range/link style.
  - Reconcile the parallel closed-set prose (the eligible-slice list ~lines 92–99) and
    the "For only M0, M1, and `remote-first-integration-candidate`" landing statement
    (line ~278) with the `### ADR 0024 dogfood bootstrap dispatch` subsection (line
    ~437) and the ADR-0025 `docs-governance/v1` class, the same additive way as spec 03.
  - Append a `### ADR 0025 reconciliation` subsection recording the amendment.

### 5. ADR path and cross-reference errata (do NOT rewrite decision bodies)

Append **one** consolidated `## Path and cross-reference errata (ADR 0025 reconciliation)`
subsection to `.docs/ADR/README.md` (a Living index — this keeps the immutable ADR
decision bodies untouched). Record each correction with the stale text, the shipped
reality, and a verification command:

- **Helper path.** ADRs 0015 (lines 17, 309) and 0016 (line 255) reference
  `plugins/loom/lib/loom-coord.sh`; the shipped helper is `plugins/loom/bin/loom-coord`
  (verify: `rg -n "loom/bin/loom-coord" plugins/loom/`).
- **Per-session state dir.** ADRs 0014 (line 105), 0015 (lines 108, 250), and 0016
  (lines 176, 258) reference `.git/loom-session-<id>/`; the shipped layout is
  `.git/loom/session-<id>/`. (Task named 0014/0016; note 0015 carries it too — record
  all occurrences.)
- **0016 misquotes 0015.** ADR 0016 line 187 attributes to ADR 0015 the phrase
  "the lock must be heartbeat too"; that phrase does not appear in ADR 0015 (verify:
  `rg -n "lock must be heartbeat" .docs/ADR/0015-*.md` → no match). Record it as a
  misattribution erratum (the substance — heartbeating the lock ref — is 0016's own
  contribution, not a 0015 quote).
- **Stale living-index pointer.** `.docs/slice-plans/README.md` line ~102 (the archived
  `multi-session-lock-helper-plan` entry) names loom's "first non-hook CLI helper" as
  `plugins/loom/lib/loom-coord.sh`; correct it in place to the shipped
  `plugins/loom/bin/loom-coord` (README is a Living index, so this pointer is corrected
  directly, not via an errata note). Scan for any sibling stale `lib/loom-coord.sh`
  pointer in that file and fix each (`rg -n "lib/loom-coord.sh" .docs/`).

### 6. Fold the deferred §7/M2 items into the improvement plan's M2 section

The two deferred items are tracked in `progress.md` (lines 58–60) and `handoff.md`
(lines 50–51) but absent from the improvement plan's M2 text. Add them to
`.docs/repository-improvement-plan.md` under `## M2 …`, as a short "Deferred bootstrap
inputs" note attached to the `### Slice: remote-first-integration-candidate` subsection
(line ~328) or immediately under the `## M2` heading:

- **ADR 0023 §7 single-session publication precondition.** The bootstrap remote-direct
  procedure assumes a single active session; M2's production landing helper must supply
  the multi-session publication coordination that §7 does not (`publication-intent`
  blocking is bootstrap-scoped). Name it as an explicit M2 design input.
- **§7 / M2 duplication.** ADR 0023 §7's bootstrap remote-direct ceremony duplicates
  the production landing helper M2 builds; at `remote-first-integration-candidate`
  settlement, §7 bootstrap landing retires and every later publication uses the
  production helper (spec 03 line ~177 / spec 04 line ~290). Record that M2 subsumes
  and retires the bootstrap path so the duplication is intentional and time-bounded.

Do not restate the whole thread — a concise pointer-style note referencing progress.md
is sufficient.

### 7. Append a reconciliation errata subsection to progress.md

Append to `.docs/status/progress.md` (after the "Remediation-1 audit errata"
subsection, in the same record-keeping-only, history-immutable style) a
`## Remediation-2 reconciliation errata (2026-07-25)` subsection recording:

- **This reconciliation slice itself** — the first `docs-governance/v1` §7 slice under
  accepted ADR 0025, carrying ADR 0025's `Status: Accepted` disposition plus the eight
  deferred reconciliation edits to the target; blind plan-eval + cold docs code-eval +
  `scripts/check` as its §7 evidence (no §3 finder package).
- **The CI-window deviation** — commits `87b72c9` / `9aa60e8` left `main` red on hosted
  CI for ~1 cycle via a dangling-index-link regression introduced by the errata-slice
  finalize, fixed at `fe9aca2`. Record it as a factual deviation; nothing is rewritten.
- **Two additional pre-rule direct pushes now closed by ADR 0025** — `b1ba112`
  (ADR-0025 Plan-Review authoring) and `fe9aca2` (the dangling-link hotfix), both
  docs-only pushes that predate Decision B and are B.3-class recorded pre-rule
  deviations, closed going forward by ADR 0025's no-bypass rule.

### 8. Update handoff.md NEXT ACTION

In `.docs/status/handoff.md`, update the NEXT ACTION (item `0.` near line 327 and the
"Where things stand" NEXT ACTION near line 34) to: **after this reconciliation slice
lands, remediation-3 (playbook-conformance), then M1 slice 2 `coord-lock-ownership`.**
Keep the existing `coord-lock-ownership` → `coord-schema-cas` M1 sequencing intact
after remediation-3. Update `roadmap.md` only if it carries a stale next-action pointer
that now contradicts this (verify with `rg`; the roadmap M1 bullet may not need a
change).

## Verification

Named mechanical checks (run from the worktree root):

1. **0006 body restoration exact match.** Extract 0006's restored body (header +
   forward note stripped) and diff it against the pre-rewrite source:
   `git show 5e0b178^:.docs/ADR/0006-distribution-self-marketplace.md` — the
   Context/Decision/Consequences prose must be byte-identical (only the one added
   forward-pointer blockquote and the unchanged `Status: Accepted`/`Date: 2026-06-08`
   header differ).
2. **Status tokens corrected.** `rg -n "^Status: Accepted" .docs/ADR/0014-*.md
   .docs/ADR/0015-*.md .docs/ADR/0016-*.md .docs/ADR/0017-*.md
   .docs/ADR/0025-*.md` → each present; `rg -n "^Status: Approved" .docs/ADR/` → no
   match among 0014–0017/0025.
3. **README lifecycle + index.** `rg -n "Plan Review → Accepted" .docs/ADR/README.md`
   present; ADR 0025 appears under `## Accepted`, not `## In Review`; 0006 entry notes
   the 0025 supersession.
4. **Authority headings.** `rg -n "0024|0025" .docs/spec/03-artifact-lifecycle.md
   .docs/spec/04-orchestrator.md` shows both ADRs in each `## Authority` block; each
   spec carries an `### ADR 0025 reconciliation` subsection.
5. **Path errata applied.** `rg -n "lib/loom-coord.sh" .docs/` → no remaining live
   pointers in `slice-plans/README.md` (occurrences inside historical
   progress/handoff narrative may remain as recorded history; the consolidated errata
   note documents them); `rg -n "loom-session" .docs/ADR/README.md` shows the corrected
   `.git/loom/session-<id>/` form recorded; `rg -n "lock must be heartbeat"
   .docs/ADR/0015-*.md` → no match (confirms the misquote finding).
6. **Ledger-bound files unchanged (blob identity).**
   `git hash-object .docs/evaluations/0025-reconciliation-authority-acceptance.md
   .docs/evaluations/0025-reconciliation-authority-eval.md` →
   `0a91d3ca33b9a00d6da995596b42c28528e16d01` and
   `0e1c4d6604e2831d256b02844b3504e5a4581334` respectively (must be unchanged).
7. **No product/executable/test change (path confinement).** `git diff --name-only`
   against the base shows only paths in the declared allowlist; nothing under
   `plugins/loom/**`, `scripts/**`, `bin/**`, or any hook/test path.
8. **Gate green.** `scripts/check` exits 0 — in particular its "relative links",
   "diff whitespace", and "Claude strict plugin validation" stages (the mechanical gate
   for docs per ADR 0025 §B.2). This is the docs `format → lint → test` equivalent and
   is rerun by the cold docs code-evaluator against a fresh copy.

## Notes

- **Audit items found already-resolved / non-actions:** the ADR-0025 round-0 MINORs
  were already folded into the accepted ADR before acceptance (see its
  `## Notes — History`), so this slice does NOT touch ADR 0025's body beyond the Status
  flip. The `remote-first-integration-candidate`/§7-landing invariants and spec
  landing-procedure retirements already exist in spec 03/04 and only need the additive
  0024/0025 harmonization, not a rewrite.
- **Decision left to the plan evaluator / owner:** whether the path errata (Step 5)
  belong consolidated in `ADR/README.md` (chosen here, to keep immutable ADR bodies
  untouched) or as per-ADR `## Notes — Errata` forward-notes in the ADR-0001 style. The
  plan chooses the README-consolidated form; flag if the reviewer prefers per-ADR notes.

## Gate evidence (developer, 2026-07-25)

All eight steps implemented across incremental commits on
`slice/docs-governance-reconciliation`. Verification re-run at the final head:

1. 0006 body restoration: `diff` of the restored body (header + forward-note stripped)
   against `git show 5e0b178^:.docs/ADR/0006-distribution-self-marketplace.md` →
   byte-identical match.
2. Status tokens: `Status: Accepted` present in `0014-0017` and `0025`; no
   `Status: Approved` remains among them.
3. README lifecycle corrected to `Draft → Plan Review → Accepted`; ADR 0025 moved to
   `## Accepted`; `## In Review` is `None.`; 0006 entry notes the 0025 supersession.
4. Both specs' `## Authority` cite 0024/0025; each carries an appended
   `### ADR 0025 reconciliation` subsection.
5. `rg -n "lib/loom-coord.sh" .docs/slice-plans/README.md` → no match; consolidated
   errata subsection added to `ADR/README.md`; `lock must be heartbeat` absent from
   0015.
6. Deferred §7/M2 items folded into `repository-improvement-plan.md`'s M2 section.
7. `progress.md` carries the Remediation-2 reconciliation errata subsection.
8. `handoff.md` NEXT ACTION updated (both locations) to remediation-3 → M1 slice 2.
9. Ledger-bound blobs unchanged: `git hash-object` on both 0025 evaluation records
   still returns `0a91d3ca…`/`0e1c4d66…`.
10. Path confinement: `git diff --name-only main...HEAD` shows only allowlisted
    `.docs/**` paths — nothing under `plugins/loom/**`, `scripts/**`, `bin/**`, or any
    hook/test path.
11. Gate: `LOOM_DIFF_BASE=main scripts/check` → `All checks passed` (452/452 Bats,
    format/lint/link/whitespace/plugin-validation stages green), reproduced at the
    final head SHA `6012f4b` in an independent detached worktree checked out from
    that exact commit. Several runs *inside the `loom-worktrees/recon` linked
    worktree specifically* hit intermittent failures on one pre-existing,
    untouched-by-this-diff timing-sensitive test
    (`scripts/tests/macos-dual-client-dogfood.bats:701`, "injection
    before:native-release" — polls for a file with a 4s budget, then asserts an
    exact journal-record count). Diagnosis: isolated reruns of that single test
    (`bats --filter`) were flaky (~50%) only in the `recon` worktree; the identical
    commit content run from the primary worktree (`/Users/craig/git/loom`, `main`,
    unrelated content but same test file) and from a fresh detached worktree checked
    out at `6012f4b` both passed **every** full-suite and isolated run (4/4 and
    4/4). This isolates the flakiness to the `recon` worktree's local environment/
    timing margins, not to this slice's diff or to the test's code on `main`. No
    file in `scripts/**` is touched by this slice (confirmed by item 10's path
    confinement). Gate evidence stands as green for this slice's content.

Status: Implemented.
