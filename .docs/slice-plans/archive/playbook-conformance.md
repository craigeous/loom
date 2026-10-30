# playbook-conformance

Status: Archived
Slice type: docs-governance
Class: docs-governance/v1
Target specs: 03-artifact-lifecycle.md, 05-blind-evaluation.md (authority only — not edited)
Authority: ADR 0026 §2/§3/§4 (broadened `docs-governance/v1` prose-body path capability +
frontmatter carve-out), ADR 0025 §B.2, ADR 0023 §7, ADR 0020, spec 03, spec 05.

## Context

This is the deferred **remediation-3 (playbook-conformance)** work that ADR 0026 named
("Out of scope, deferred") and authorized a lawful §7 landing path for. It is the first
`docs-governance/v1` §7 slice to exercise ADR 0026's **broadened** class — editing the
**prose bodies** of non-executable Markdown under `plugins/loom/`.

Two things happen here:

1. **Land ADR 0026 into `main`.** ADR 0026 was authored/ratified on a staging branch and
   owner-accepted, but is **not yet in `origin/main`** (this branch — nor `origin/main` —
   contains the ADR file). Per ADR 0026 §5.5 the accepted document reaches `main` as the
   payload of a docs-governance §7 slice — this one. Its blind plan-eval verdict and owner
   acceptance are the two pre-placed records already in the worktree.
2. **Fix three prompt/documentation drifts** the audit's Theme-B findings identified between
   the shipped playbook prose and the accepted specs/ADRs (ADR 0020 remote-first landing;
   spec 03/05 evaluator/recorder separation). These are pure prose corrections.

**In scope:** prose-body edits to the named `plugins/loom/**/*.md` files (and the
cross-scan siblings carrying the identical drift — see Step 5 / Notes); the ADR 0026 file +
ADR/README index; the two pre-placed 0026 evaluation records + the evaluations index; this
plan + the slice-plans index; `.docs/status/{progress,handoff}.md`.

**Explicitly out of scope (do NOT touch):**
- **Any YAML frontmatter** — the `---`-delimited header block of any `plugins/loom/**/*.md`
  file. Per ADR 0026 §3 (frontmatter carve-out) and §4.0, a change to any frontmatter field
  makes the slice code-bearing and the docs code-eval **MUST FAIL**. Only three target files
  carry frontmatter: `plugins/loom/skills/loom-eval-code/SKILL.md`,
  `plugins/loom/skills/loom-eval-plan/SKILL.md`, `plugins/loom/skills/loom-run/SKILL.md` —
  edit **only** their body text below the closing `---`.
- Any executable/test/schema/manifest: `*.sh`, `plugins/loom/bin/*`, `plugins/loom/hooks/**`,
  `*.bats`, any test path/fixture, `*.json` (schemas/manifests/catalogs), `scripts/**`.
- `.docs/spec/**` and any ADR other than `0026-*`.
- The `Land`-workflow *mechanical* redesign to ADR 0020's mode state machine (ADR 0020
  §Consequences defers this to a later spec 03/04 planning amendment) — Step 4 corrects the
  false authority claims in prose and points to ADR 0020, it does **not** invent new procedure.
- The reconciliation `slice-plans/README` Active-region residual and the test-301 flake —
  both are tracked follow-ups recorded by Step 6, not fixed here.

## Steps

### Step 1 — Land ADR 0026 acceptance

1a. **Introduce the ADR 0026 file at Accepted.** The file is absent from HEAD; source its body
byte-for-byte from the accepted content and change **only** the Status line:
```
git show b2614ce:.docs/ADR/0026-docs-governance-plugin-prompt-doc-scope.md \
  > .docs/ADR/0026-docs-governance-plugin-prompt-doc-scope.md
```
(that content is blob `914090db014cb9462d16da9992c73e98fbc1d4c9`, the plan-evaluated/owner-accepted
revision), then edit its line 3 `Status: Plan Review` → `Status: Accepted`. Change nothing else
in the body — it is an accepted, immutable ADR. (The ADR body starts with `# 0026 — …`; it has
**no** YAML frontmatter, so the frontmatter constraint is not implicated for this file.)

1b. **ADR index → Accepted.** In `.docs/ADR/README.md`: add a `0026` entry to the `## Accepted`
list (immediately after the `0025` entry, line 40), summarizing the narrow supersession of
ADR 0025 §B.2's path allowlist (broaden `docs-governance/v1` to admit prose-body Markdown under
`plugins/loom/`; frontmatter categorically out-of-class; capability amendment with
`allowed_slices` UNCHANGED). The staged `## In Review` entry (present at `b2614ce` in
`README.md`, blob context) is the source text — adapt it to Accepted form (drop its trailing
"On acceptance, move to the Accepted list and annotate…" instruction). Leave `## In Review` as
`None.` **Annotate the `0025` entry** to note ADR 0026 narrowly supersedes its §B.2 path
allowlist (per the staged entry's own instruction).

1c. **Include the two pre-placed 0026 records as-is.** `git add` (do not modify):
- `.docs/evaluations/0026-docs-governance-plugin-prompt-doc-scope-eval.md` (blob
  `56d74dfc61c9a8fafcf2627fb61355f4b9f56078` — MUST stay byte-identical)
- `.docs/evaluations/0026-docs-governance-plugin-prompt-doc-scope-acceptance.md` (blob
  `967200c287ad0ad4f5166b4862ac449206e1e337` — MUST stay byte-identical)

1d. **Evaluations index.** In `.docs/evaluations/README.md` `## Current program evaluations`,
add two entries for the 0026 plan-eval verdict and owner acceptance, paralleling the existing
`0025` entries (lines 50-54): plan-eval `bootstrap-ratification: degraded`, PASS round 0 with
the frontmatter-carve-out MINOR folded → resolving PASS (advisory); owner acceptance dispositive,
Accepted 2026-07-25.

### Step 2 — Lifecycle drift: code-eval PASS ≠ `Landed` (audit Theme-B finding 1)

**Reality to conform to** (authority: spec 03 lines 37-38 & §"`Ready to Publish`"/"`Landed` and
cleanup"; ADR 0020 §1 and the `Ready to Publish` state it adds): a code-eval **PASS advances the
slice to `Ready to Publish`** (code evaluation passed; claim and evidence retained pending
publication). **`Landed` is later and stronger** — it requires the configured-remote result to be
independently verified and a publication receipt recorded; it is reached by the orchestrator's
landing helper, not asserted on code-eval PASS. Correct the stale "set `Landed` on PASS" prose at:

- `plugins/loom/skills/loom-eval-code/SKILL.md` line 29 — "(`Landed` on PASS, `In Progress` on
  FAIL — status line only)" → PASS advances to `Ready to Publish` (FAIL → `In Progress`
  unchanged). **Body edit only — this file has frontmatter; do not touch lines 1-4.**
- `plugins/loom/roles/code-evaluator.md` line 59 — "Set the slice-plan status: `Landed` on PASS
  …" → the recorder sets `Ready to Publish` on PASS (see Step 3 for the who-sets/who-commits
  correction that also lands in this sentence). Also correct step-4/line-33's implicit downstream
  wording if it references `Landed` as the PASS target.
- `plugins/loom/skills/loom-run/SKILL.md` line 99 — "On a `Landed` code-eval PASS, launch the
  developer's finalize pass" → dispatch on a **code-eval PASS** (status now `Ready to Publish`);
  the finalize/land sequence follows ADR 0020 (publish → verify remote → receipt → `Landed`).
  **Body edit only — this file has frontmatter.**
- `plugins/loom/skills/loom-playbook/references/status-machine.md` — the status semantics are
  stale here and **missing tokens**. In the `## Statuses` table (lines 8-19) and `## Dispatch
  table` (lines 21-31) and `## Lifecycles` (lines 54-66):
  - Add rows/tokens for **`Ready to Publish`** (code evaluation passed; claim + evidence retained
    pending publication; next actor: orchestrator landing helper), **`Accepted`** (ADR/spec
    approval; the artifact lifecycles at line 56-57 already use it in prose but it is absent from
    the table), and **`Living`** (the perpetual status of the three `status/` docs, the spec
    index, and `09-open-questions.md` — currently used but untabled).
  - Correct the slice-plan lifecycle string (lines 58-59) so **code-eval PASS → `Ready to
    Publish` → (publish/verify/receipt) → `Landed` → `Archived`**, and the `Landed` row/meaning
    (line 16) to "configured remote result independently verified and receipt recorded" (not
    "code approved; finalize underway"). Keep spec 03 as the single-source pointer.

**Cross-scan siblings carrying the identical drift** (Step 5 census; fold the same correction in):
- `plugins/loom/roles/developer.md` line 13 — "A slice's code-eval returned PASS (`Landed`) —
  run the finalize pass" → the PASS target is `Ready to Publish`; correct the `(Landed)`
  equivalence. Do **not** redesign finalize-pass timing beyond this token correction; if the
  precise finalize/land ordering under ADR 0020 is ambiguous in this sentence, correct the stale
  token and NOTE the residual rather than inventing sequence.
- `plugins/loom/skills/loom-playbook/references/commit-convention.md` line 78 — the example
  commit message `Evaluate week-rollover slice: PASS (Landed)` encodes the stale equivalence →
  change the parenthetical to `(Ready to Publish)`.
- `plugins/loom/skills/loom-playbook/SKILL.md` line 38 — **(round-0 miss, added on revision)** the
  playbook's own artifact-table slice-plan lifecycle string is byte-identical stale:
  `Draft → Plan Review → Approved → In Progress → Implemented → (code review) → Landed → Archived`
  (missing `Ready to Publish`). **Insert `Ready to Publish` between `(code review)` and `Landed`**
  so it reads `… → (code review) → Ready to Publish → Landed → Archived`, matching the
  `status-machine.md:58-59` correction. This is **body prose** — the SKILL frontmatter closes at
  line 4; line 38 is far below it. Added to the Path allowlist on revision. (This copy is invisible
  to the Step-2 `set … Landed`/`Landed … PASS` greps because it has no `PASS`/`set` adjacency — the
  revised Verification #1 adds a bare-lifecycle grep that catches it; see Step 5 census.)

### Step 3 — Evaluator self-commit drift (audit Theme-B finding 2)

**Reality to conform to** (authority: spec 03 §"Evaluation-run validity": "The deterministic
recorder installs a valid verdict under `.docs/evaluations/`, makes the allowed status
transition, and the orchestrator commits the handoff. **The evaluator itself never mutates the
checkout.**"; spec 05 §"Fresh per-run workspace" lines 139-152: the evaluator "has no
managed-checkout write path, and may write only to a unique confined output directory and private
scratch"; the **root** re-verifies immutable inputs, performs the spec-03 status transition, and
commits the verdict/status author-neutrally). The shipped role prose wrongly instructs the
**evaluator** to write the eval file into `.docs/evaluations/`, set the status line, and commit.
Correct it so the evaluator **produces its verdict to its confined scratch/output workspace and
returns** — it does **not** write into `.docs/`, does **not** set status, and does **not** commit;
the recorder/root installs the verdict, makes the status transition, and commits.

- `plugins/loom/roles/plan-evaluator.md` — step 2 (line 44, "Write the verdict to
  `.docs/evaluations/…`"), step 3 (line 54, "Set the artifact's status line"), step 4 (lines
  56-58, "Commit … and stop … Verify after committing"), **and** the bounded-return line 63
  ("Your real output is the committed eval file"): rewrite so the evaluator writes its
  verdict to the confined output workspace and returns the bounded verdict; the recorder/root
  installs it, performs the `Approved`-on-PASS / `Draft`-on-FAIL transition, and commits. Reword
  line 63 so the durable record is the **recorder-installed** verdict (not an evaluator commit).
  Keep the round-counting rule and the blind-contract text intact.
- `plugins/loom/roles/code-evaluator.md` — step 4 (line 43, "Write the verdict to
  `.docs/evaluations/…`"), step 5 (line 59, sets status — the same sentence Step 2 corrects for
  the PASS target), step 6 (lines 62-64, "Commit … and stop … Verify after committing"), **and**
  the bounded-return line 69 ("Your real output is the committed eval file"): same
  rewrite — evaluator writes to confined scratch and returns; recorder/root records the verdict,
  transitions to `Ready to Publish` (PASS) / `In Progress` (FAIL), and commits; reword line 69 as
  for plan-evaluator line 63. Preserve the gate-rerun requirement and adjudication text.

*(Step-anchor line numbers above are advisory — the developer trusts the Step 5 census grep, not
the cited line, per the round-0 eval's MINOR on anchor drift.)*

**Cross-scan siblings carrying the identical drift** (Step 5; fold the same correction in):
- `plugins/loom/skills/loom-eval-code/SKILL.md` lines 27-31 — "The role … writes
  `.docs/evaluations/<slice>-eval.md` …, sets status …, and commits author-neutral" +
  "Verify the commit" → the role produces the verdict to scratch and returns; the recorder/root
  records + transitions + commits. **Body edit only (frontmatter present).**
- `plugins/loom/skills/loom-eval-plan/SKILL.md` lines 29-32 — "The role writes
  `.docs/evaluations/<name>-eval.md` …, sets status …, and commits author-neutral" (29-31) **and**
  "Verify the commit; report the verdict and resulting status" (32) → same
  correction: the role produces the verdict to scratch and returns; the recorder/root records +
  transitions + commits. **Body edit only (frontmatter present).**
- `plugins/loom/skills/loom-run/SKILL.md` — the step-e "verify the author-neutral commit and the
  new status" wording (line 98) presumes the evaluator committed; align it to recorder/root
  recording. **Body edit only (frontmatter present).** (Keep this minimal — the orchestrator does
  verify a commit exists; the correction is that the *evaluator* is not the committer.)
- `plugins/loom/skills/loom-playbook/references/orchestration.md` lines 24-25 —
  **(round-0-census addition)** "**Commit per handoff, author-neutral.** Agents commit their own
  work; verify a commit landed …" reads universally and thus wrongly implies the *evaluator*
  commits. Narrow it: **producing** roles commit their own work; **evaluation verdicts are
  installed and committed by the recorder/orchestrator** (spec 03 §"Evaluation-run validity"; the
  evaluator never mutates the checkout). Keep the author-neutral / verify-a-commit-landed doctrine.
  **Body prose (orchestration.md has no frontmatter).**

### Step 4 — Parallelism drift: local-main is not the landing authority (audit Theme-B finding 3)

**Reality to conform to** (authority: ADR 0020 §1 "A configured remote target ref is
authoritative … Local `main` is a disposable mirror/cache and is never part of the landing
transaction, dispatch authority, claim transaction, or recovery source"; ADR 0020 §Consequences
"Partially supersedes ADR 0014" on the shared-local-`main`/no-push model; spec 03 §"Dispatch
rules": "Dispatch never derives landing, claims, or current authority from local `main`").
`plugins/loom/skills/loom-playbook/references/parallelism.md` still asserts the pre-ADR-0020
model. Correct the specific false claims in prose:

- §"Agent-input freshness" (lines 123, 126): "loom commits to local `main` and does not push, so
  `origin/main` lags … The authoritative 'what has landed / what is claimed' read is always
  current local `main` under the lock." → State ADR 0020: landing publishes to the **configured
  remote target**, which is the sole landing authority; local `main` is a **disposable
  mirror/cache**, never the landing/dispatch/claim authority; the authoritative "what has landed"
  read is a fresh read of the configured remote plus the publication receipt. (Worktrees may still
  branch off local `main` as a working base — that mechanic is unchanged; see the LEAVE rows in the
  Step 5 census for lines 78/121/379.)
- **(round-0 misses, added on revision)** the claim/dispatch re-read lines that frame
  **current local `main`** as "the authoritative snapshot" — `parallelism.md:150` ("Re-read
  Active/claim state from **current local `main`** (the authoritative snapshot, now under the
  lock)") and `parallelism.md:402` (table row: "authoritative re-check still done under the lock
  against current local `main`"). Apply the **identical reconciliation given to
  `orchestration.md:340`**: the claim/Active state is still **re-read under the lock** (the
  coordination mechanic is preserved), but the **"authoritative local `main`" framing is removed** —
  claim liveness derives from the `refs/loom/claims/` lease refs via `loom-coord`, and
  landing/current authority is never derived from local `main` (spec 03 §"Dispatch rules" line 326;
  ADR 0020 §1). This resolves the preserve-vs-fix ambiguity the round-0 eval flagged: **keep the
  read-under-the-lock, drop the authoritative-local-`main` wording.**
- The Land subsection (lines 195-235) and §"What stays serial" (line ~342's "loom commits
  directly to local main") describe merge-onto-local-`main` with no push as the landing act. Add a
  concise **superseded-by-ADR-0020 note** at the Land subsection: the landing authority is remote
  publication + fresh remote verification + receipt (ADR 0020, partially superseding ADR 0014);
  `Landed` is established only by that verified remote result and receipt. **Do NOT rewrite the
  merge/mode mechanics** — ADR 0020 §Consequences defers the mode state machine to a later spec
  03/04 amendment; correct the authority claim and point to ADR 0020, and NOTE the deferred
  mechanical reconciliation rather than inventing procedure.
- Preserve the multi-session lock/claim coordination model (ADR 0014/0015/0016 via `loom-coord`) —
  it is orthogonal to landing authority and is **not** superseded by ADR 0020.

**Cross-scan siblings carrying the identical drift** (Step 5 census; fold the same correction in):
- `plugins/loom/skills/loom-playbook/references/orchestration.md` line 340 — "Re-read
  Active/claim state from current local `main` (authoritative under the lock…)" carries the same
  local-main-authoritative claim → reconcile the same way: coordination/claim state is read under
  the lock, but landing/current-authority is never derived from local `main` (spec 03; ADR 0020).
- `plugins/loom/skills/loom-playbook/references/orchestration.md` lines 354 and 373 —
  **(round-0-census additions)** "**Dispatch scan derives from current local `main`**" (354) and
  "the orchestrator dispatches by reading `Status:` lines … **on current local `main`**" (373)
  directly contradict spec 03 line 326 ("Dispatch never derives … claims, or current authority from
  local `main`"). Reconcile with the same bounded touch: dispatch derives current authority from the
  **configured remote (ADR 0020)**; claim liveness from the lease refs under the lock; local `main`
  is a disposable mirror. **Do NOT rewrite the dispatch/mode mechanics** (deferred to the spec 03/04
  amendment per ADR 0020 §Consequences) — correct the authority framing and NOTE the deferred
  mechanical reconciliation.

### Step 5 — EXHAUSTIVE CROSS-SCAN CENSUS (mechanical, zero-miss, reproducible)

The planner ran an **exhaustive whole-tree sweep** over `plugins/loom/**/*.md` prose bodies for
each of the three drift patterns (revised after the round-0 FAIL, which caught three misses). The
**exact grep commands** are baked below so the developer and re-evaluator reproduce the identical
hit set with zero miss. Every hit is enumerated with a **FIX** or **LEAVE** decision and a one-line
reason. Run all six greps at `head_sha`; the counts and file:lines must match this census exactly
(if the live tree differs — a hit already corrected or new text — adjust the affected Step and
record it in `## Notes`; do not fix a non-problem, do not miss a real one).

#### Pattern A — lifecycle: code-eval PASS ≠ `Landed`

```
rg -n 'Landed' plugins/loom --glob '*.md'
rg -n 'Code Review|→ *Landed|set .*Landed' plugins/loom --glob '*.md'
```

Census (9 `Landed` hits; every one FIXED — the drift is treating a code-eval PASS as *reaching*
`Landed`, or a lifecycle string that skips `Ready to Publish`. Note `Landed` itself is a **real
final state**: the fix inserts `Ready to Publish` before it / corrects its meaning, it never
deletes the `Landed → Archived` tail, which is correct):

| file:line | decision | reason |
|---|---|---|
| `skills/loom-eval-code/SKILL.md:29` | FIX (Step 2) | "`Landed` on PASS" — PASS advances to `Ready to Publish`. |
| `skills/loom-playbook/SKILL.md:38` | **FIX (Step 2, round-0 miss)** | artifact-table lifecycle string omits `Ready to Publish`; no `PASS`/`set` adjacency so the old grep missed it. |
| `skills/loom-playbook/references/commit-convention.md:78` | FIX (Step 2) | example commit `PASS (Landed)` → `(Ready to Publish)`. |
| `skills/loom-playbook/references/status-machine.md:16` | FIX (Step 2) | `Landed` row meaning "code approved; finalize underway" → "remote result verified + receipt recorded"; token kept (real state). |
| `skills/loom-playbook/references/status-machine.md:29` | FIX (Step 2) | dispatch table — add a `Ready to Publish` row; keep the `Landed` row (valid final state). |
| `skills/loom-playbook/references/status-machine.md:59` | FIX (Step 2) | lifecycle string — insert `Ready to Publish` before `Landed`. |
| `roles/code-evaluator.md:59` | FIX (Step 2/3) | "Set … `Landed` on PASS" → recorder sets `Ready to Publish`. |
| `skills/loom-run/SKILL.md:99` | FIX (Step 2) | "On a `Landed` code-eval PASS" → on a code-eval PASS (status now `Ready to Publish`). |
| `roles/developer.md:13` | FIX (Step 2) | "PASS (`Landed`)" → PASS target is `Ready to Publish`. |

No LEAVE rows: every `Landed` occurrence is either drift or a state-row/lifecycle-tail whose
meaning the census corrects in place.

#### Pattern B — evaluator self-commit

```
rg -n 'commit' plugins/loom/roles plugins/loom/skills --glob '*.md'
```

Scope the result to **evaluator/eval contexts** (the drift = instructing the *evaluator* to write
into `.docs/evaluations/`, set status, and commit — spec 03 §"Evaluation-run validity", spec 05
§"Fresh per-run workspace": the evaluator never mutates the checkout; the recorder/root installs +
transitions + commits). Producer-role and rubric/orchestrator commits are **correct** and LEFT.

| file:line | decision | reason |
|---|---|---|
| `roles/code-evaluator.md:43` | FIX (Step 3) | "Write the verdict to `.docs/evaluations/…`" → write to confined scratch, return. |
| `roles/code-evaluator.md:59` | FIX (Step 2/3) | "Set … status" → recorder sets status. |
| `roles/code-evaluator.md:62-64` | FIX (Step 3) | "Commit … and stop … Verify after committing" → recorder commits. |
| `roles/code-evaluator.md:69` | **FIX (Step 3, census)** | bounded-return "your real output is the committed eval file" implies evaluator commits → recorder-installed verdict. |
| `roles/plan-evaluator.md:44` | FIX (Step 3) | "Write the verdict to `.docs/evaluations/…`" → confined scratch. |
| `roles/plan-evaluator.md:54` | FIX (Step 3) | "Set the artifact's status line" → recorder transitions. |
| `roles/plan-evaluator.md:56-58` | FIX (Step 3) | "Commit … and stop … Verify after committing" → recorder commits. |
| `roles/plan-evaluator.md:63` | **FIX (Step 3, census)** | bounded-return "committed eval file" — as code-evaluator:69. |
| `skills/loom-eval-code/SKILL.md:28` | FIX (Step 3) | "writes `…-eval.md`, sets status … commits" → recorder records. |
| `skills/loom-eval-code/SKILL.md:31` | FIX (Step 3) | "Verify the commit" presumes evaluator committed. |
| `skills/loom-eval-plan/SKILL.md:29-31` | FIX (Step 3) | "writes `…-eval.md`, sets status … commits author-neutral". |
| `skills/loom-eval-plan/SKILL.md:32` | **FIX (Step 3, census)** | "Verify the commit; report … resulting status" presumes evaluator committed. |
| `skills/loom-run/SKILL.md:98` | FIX (Step 3) | step-e "verify the author-neutral commit and new status" presumes the *evaluator* committed. |
| `references/orchestration.md:24-25` | **FIX (Step 3, census)** | "Agents commit their own work" reads universally → narrow to producing roles; evaluation verdicts recorder-committed. |
| `roles/planner.md:30,32` | LEAVE | producer role — the planner **does** commit its own artifact. |
| `roles/developer.md:40,42,43` | LEAVE | producer role — developer commits its own slice. |
| `roles/researcher.md:34-37` | LEAVE | producer role — researcher commits its own note. |
| `skills/loom-develop/SKILL.md:27,30` | LEAVE | producer wrapper — developer commits. |
| `skills/loom-research/SKILL.md:27-28` | LEAVE | producer wrapper — researcher commits. |
| `references/code-eval-rubric.md:63` | LEAVE | rubric **checks** the developer's commit; not an evaluator self-commit instruction. |
| `references/orchestration.md:159,199-203` | LEAVE | review-findings captured/committed by the **orchestrator** (correct). |
| `references/review-findings.md:3,5,42` | LEAVE | review-findings is an orchestrator-committed record (correct). |
| other `commit-convention.md` / handoff-doctrine hits | LEAVE | general author-neutral convention, not evaluator-scoped. |

#### Pattern C — parallelism: local-`main` is not the landing/dispatch/claim authority

```
rg -n 'local .*main|does not push|authoritative.*main|commit.*to.*main' plugins/loom --glob '*.md'
```

Drift = teaching local-`main`-is-landing/dispatch/claim-authority (contradicts ADR 0020 §1
remote-first and spec 03 line 326). **Correct usage LEFT** = worktrees *branching off* local
`main` as a working base (ADR 0020 preserves this), and the index-bucket coordination model
(ADR 0008/0014, orthogonal to landing authority).

| file:line | decision | reason |
|---|---|---|
| `references/parallelism.md:78` | LEAVE | index-bucket "orchestrator-owned, main-only, serialized" — ADR 0008/0014 coordination, not ADR 0020 landing authority. |
| `references/parallelism.md:121` | LEAVE | "worktrees created from current local `main`" — working base, explicitly preserved by ADR 0020. |
| `references/parallelism.md:123` | FIX (Step 4) | "commits to local `main` and does not push, `origin/main` lags" — the no-push landing model. |
| `references/parallelism.md:126` | FIX (Step 4) | "authoritative … current local `main` under the lock" read framing. |
| `references/parallelism.md:150` | **FIX (Step 4, round-0 miss)** | "the authoritative snapshot … local `main`" — keep read-under-lock, drop authoritative framing. |
| `references/parallelism.md:379` | LEAVE | "worktrees (branched from local `main`)" — working base. |
| `references/parallelism.md:402` | **FIX (Step 4, round-0 miss)** | table row "authoritative re-check … against current local `main`" — same reconciliation. |
| `references/orchestration.md:340` | FIX (Step 4) | "Re-read Active/claim state from current local `main` (authoritative under the lock)". |
| `references/orchestration.md:354` | **FIX (Step 4, census)** | "Dispatch scan derives from current local `main`" contradicts spec 03:326. |
| `references/orchestration.md:373` | **FIX (Step 4, census)** | "dispatches by reading `Status:` lines … on current local `main`" — same; bounded authority-framing fix, mechanics deferred. |

**Exhaustiveness assertion:** the six greps above are the complete detection set. Every hit each
grep returns over `plugins/loom/**/*.md` is enumerated in one of the three census tables with a
FIX/LEAVE decision — there are **no un-triaged hits**. The two ledger-bound 0026 records
(blobs `967200c2`/`56d74dfc`) and all frontmatter blocks are out of the sweep by construction
(census targets prose bodies only).

### Step 6 — Status finalize (record remediation-3; set NEXT ACTION)

In `.docs/status/progress.md` and `.docs/status/handoff.md`:
- Record **remediation-3 (playbook-conformance)**: ADR 0026 landed (Accepted) + the three
  Theme-B prose drifts corrected across the plugin prose bodies; first exercise of ADR 0026's
  broadened `docs-governance/v1` class.
- Set **NEXT ACTION** → after this slice lands, the tracked **code-bearing follow-ups**:
  (1) **test-301 flake stabilization** (the `scripts/check` bats flake unrelated to these md
  edits), (2) the **trivial reconciliation `slice-plans/README` Active-region residual** (the
  `docs-governance-reconciliation` entry still shown under `## Active plans` pointing to
  `archive/`); **then** plan **M1 slice 2 `coord-lock-ownership`** (per
  `.docs/repository-improvement-plan.md` § "M1 — Fix coordinator safety").

*(Index/archival note: this plan's `slice-plans/README` Active-plans entry is added at Plan
Review by the planner; on code-eval settlement the standard docs-governance §7 finalize moves it
Active→Archived and `git mv`s this plan into `archive/` — the orchestrator-owned index step, not
a developer prose edit.)*

## Verification

Named mechanical checks (all run at `head_sha`):

1. **Lifecycle corrected** — `rg -n 'Ready to Publish' plugins/loom/skills/loom-eval-code/SKILL.md
   plugins/loom/roles/code-evaluator.md plugins/loom/skills/loom-run/SKILL.md
   plugins/loom/skills/loom-playbook/references/status-machine.md` shows the corrected target;
   `rg -n 'Landed.*on PASS|PASS \(Landed\)' plugins/loom --glob '*.md'` returns **zero** stale
   "PASS ⇒ Landed" equivalences. **Bare-lifecycle grep (round-0 addition — catches strings with no
   `PASS`/`set` adjacency):** `rg -n '\(code review\) *→ *Landed' plugins/loom --glob '*.md'`
   returns **zero** — every slice-plan lifecycle string now routes `(code review) → Ready to
   Publish → Landed` (this is the check that would have caught `loom-playbook/SKILL.md:38` and
   `status-machine.md:59`). `status-machine.md` now contains `Ready to Publish`, `Accepted`,
   and `Living` tokens (`rg -n 'Ready to Publish|Accepted|Living' status-machine.md`).
2. **Self-commit corrected** — `rg -n 'evaluator .*never mutates|writes .*to .*scratch|recorder .*commits|to its .*(scratch|output) workspace'`
   across `roles/*evaluator.md` + `skills/loom-eval-*/SKILL.md` shows the recorder/root-commits
   model; no remaining instruction telling the evaluator to write into `.docs/evaluations/` and
   commit.
3. **Parallelism corrected** — the Pattern-C census grep
   `rg -n 'local .*main|does not push|authoritative.*main|commit.*to.*main'
   plugins/loom/skills/loom-playbook/references/parallelism.md
   plugins/loom/skills/loom-playbook/references/orchestration.md` shows the three LEAVE lines
   (`parallelism.md:78/121/379` — working-base/index-bucket, unchanged) and **no remaining**
   local-`main`-as-landing/dispatch/claim-**authority** framing at the seven FIX lines
   (`parallelism.md:123/126/150/402`, `orchestration.md:340/354/373`); an ADR 0020 remote-authority
   note is present at the parallelism Land subsection and the orchestration dispatch-scan text.
4. **Frontmatter untouched (ADR 0026 §4.0 gate)** — `git diff <base>..<head>` shows **zero**
   changed lines inside any `---`-delimited frontmatter block of any `plugins/loom/**/*.md`. Only
   three target files carry frontmatter (`loom-eval-code/SKILL.md`, `loom-eval-plan/SKILL.md`,
   `loom-run/SKILL.md`); confirm every hunk in them is strictly below the closing `---`. A single
   frontmatter-line change **disqualifies the slice from the class** and the docs code-eval MUST
   FAIL.
5. **Ledger-blob identity** — `git hash-object` on the two pre-placed 0026 records equals
   `56d74dfc61c9a8fafcf2627fb61355f4b9f56078` (eval) and
   `967200c287ad0ad4f5166b4862ac449206e1e337` (acceptance), byte-identical.
6. **ADR 0026 body identity** — `diff <(git show b2614ce:.docs/ADR/0026-…md)
   .docs/ADR/0026-…md` shows a **single** differing line: `Status: Plan Review` → `Status:
   Accepted`. No other body change.
7. **No out-of-class paths** — `git diff --name-only <base>..<head>` contains **only** allowlist
   paths (see below); no `*.sh`/`bin/*`/hooks/`*.bats`/test/`*.json`/`scripts/**`/`.docs/spec/**`
   and no non-`0026` ADR.
8. **Gate green** — `scripts/check` at `head_sha` (incl. `validate-repository.mjs`). This is a
   pure prose-body docs slice, so the §3 finder package is not required (ADR 0026 §4). **If the
   only failure is the known test-301 bats flake** (unrelated to Markdown edits), record it as a
   pre-existing flake per progress/handoff and treat the gate as green for this slice; any other
   failure is a real gate failure.

Docs-governance §7 evidence (ADR 0026 §4): this slice-plan's **blind plan-eval verdict**; a
**distinct cold docs code-evaluator** verdict over the exact `base..head` diff confirming §4.0
(no behavior-bearing frontmatter change — MUST FAIL otherwise), §4.1 (no behavior/executable
change; pure prose), and §4.2 (`validate-repository.mjs` green); plus the `scripts/check` gate
rerun.

## Path allowlist (exact)

Prose bodies of the following `plugins/loom/**/*.md` files (**body text only — no frontmatter**):
- `plugins/loom/skills/loom-eval-code/SKILL.md` *(frontmatter present — body only)*
- `plugins/loom/skills/loom-eval-plan/SKILL.md` *(frontmatter present — body only)*
- `plugins/loom/skills/loom-run/SKILL.md` *(frontmatter present — body only)*
- `plugins/loom/roles/code-evaluator.md`
- `plugins/loom/roles/plan-evaluator.md`
- `plugins/loom/roles/developer.md`
- `plugins/loom/skills/loom-playbook/references/status-machine.md`
- `plugins/loom/skills/loom-playbook/references/parallelism.md`
- `plugins/loom/skills/loom-playbook/references/orchestration.md`
- `plugins/loom/skills/loom-playbook/references/commit-convention.md`
- `plugins/loom/skills/loom-playbook/SKILL.md` *(round-0 addition — body only; frontmatter closes line 4, line 38 is prose)*

Plus:
- `.docs/ADR/0026-docs-governance-plugin-prompt-doc-scope.md` and `.docs/ADR/README.md`
- `.docs/evaluations/0026-docs-governance-plugin-prompt-doc-scope-eval.md` and
  `…-acceptance.md` (pre-placed, added byte-identical) and `.docs/evaluations/README.md`
- `.docs/slice-plans/playbook-conformance.md` (this plan) and `.docs/slice-plans/README.md`
- `.docs/status/progress.md` and `.docs/status/handoff.md`

**Categorically excluded:** any YAML frontmatter block; `*.sh`, `plugins/loom/bin/*`,
`plugins/loom/hooks/**`, `*.bats`, any test path/fixture; `*.json` schemas/manifests/catalogs;
`scripts/**`; `.docs/spec/**`; any ADR other than `0026-*`.

## Notes

- **Revision (round 0 → round 1).** After the blind plan-eval FAIL
  (`.docs/evaluations/playbook-conformance-plan-eval.md`, round 1: class-eligibility +
  drift-accuracy PASSED, verdict FAIL on **incomplete cross-scan**), this plan was revised to
  (a) add the round-0 misses — `skills/loom-playbook/SKILL.md:38` (lifecycle; added to allowlist +
  Step 2 + a bare-lifecycle Verification grep) and `parallelism.md:150`/`:402` (local-`main`;
  Step 4, preserve-vs-fix ambiguity resolved: keep read-under-lock, drop authoritative framing);
  (b) replace Step 5 with an **exhaustive mechanical census** (six exact greps, every hit triaged
  FIX/LEAVE with a reason); and (c) fold two further same-drift hits the census surfaced —
  `orchestration.md:354`/`:373` (dispatch-derives-from-local-`main`, contra spec 03:326) and the
  universal `orchestration.md:24-25` "agents commit their own work" line. Status stays Plan Review.
- **Scope-expansion flag (for the evaluator/owner).** The task named a specific file set per
  drift. The Step 5 census surfaced the **identical** drift in additional prose bodies beyond the
  named set: lifecycle — `roles/developer.md`, `references/commit-convention.md`,
  `skills/loom-playbook/SKILL.md`; self-commit — `skills/loom-eval-plan/SKILL.md`,
  `skills/loom-run/SKILL.md`, `references/orchestration.md:24-25`; local-`main` —
  `references/orchestration.md:340/354/373`, `parallelism.md:150/402`. Leaving any unfixed would
  ship an internally inconsistent remediation (the exact defect class this slice exists to remove),
  so they are folded into Steps 2-4 and added to the allowlist. This is a deliberate, disclosed
  expansion of the named set for coherence — flagged here for explicit review. The census also
  records the deliberate **LEAVE** set (correct usage that must not be overcorrected):
  `parallelism.md:78/121/379` (working base + index bucket) and every producer-role/rubric/
  orchestrator commit hit under Pattern B.
- **ADR 0026 provenance.** The ADR file is absent from `origin/main` and this branch; it lives on
  the staging branch at commit `b2614ce` (blob `914090db`, Status: Plan Review). This slice both
  carries it into `main` and flips its Status to Accepted — its own landing rides the pre-existing
  `.docs/**` allowlist, so it does not depend on the broadening it enacts (ADR 0026 §5, non-circular).
- **Frontmatter is the disqualifier.** Restated for the developer: `git diff` must touch **no**
  line inside any `---`-delimited frontmatter block of any `plugins/loom/**/*.md` file (ADR 0026
  §4.0). This is the single most likely way to accidentally convert this docs slice into a
  code-bearing one and force a MUST-FAIL.
- **Bounded Step 4.** The Land-workflow mechanical redesign to ADR 0020's mode state machine is
  explicitly deferred (ADR 0020 §Consequences names a later spec 03/04 amendment). Step 4 corrects
  the false authority claims in prose and points to ADR 0020; it does not invent new landing
  procedure.

## Implementation Record

Commits (`main...HEAD`): `a380ef3` (Step 1 — ADR 0026 landed Accepted + indices +
pre-placed records), `56679d5` (Steps 2/3 — Pattern-A lifecycle + Pattern-B
evaluator-self-commit fixes), `38d5b68` (Step 4 — Pattern-C local-`main`-authority
fixes), `05e6340` (fix a mid-token line wrap that defeated the `Ready to Publish`
grep in `loom-run/SKILL.md`), `ebae2ad` (Step 6 — status docs).

Verification performed at this HEAD, matching the plan's Verification section:
1. **Lifecycle** — `Ready to Publish` present in all four named files; the stale
   `Landed.*on PASS|PASS \(Landed\)` grep returns zero; the bare-lifecycle grep
   `\(code review\) *→ *Landed` returns zero; `status-machine.md` carries
   `Ready to Publish`, `Accepted`, `Living` tokens.
2. **Self-commit** — all six named files carry the recorder/root-installs-and-commits
   correction; no remaining instruction telling the evaluator to write into
   `.docs/evaluations/` or commit.
3. **Parallelism** — the Pattern-C census grep over `parallelism.md`/`orchestration.md`
   shows the three LEAVE lines (`parallelism.md:78/121/379`, text unchanged) and no
   remaining local-`main`-as-authority framing at the seven FIX sites; an ADR 0020
   remote-authority note is present at the Land subsection and the dispatch-scan text.
4. **Frontmatter untouched** — `git diff main...HEAD` touches zero lines inside any
   `---`-delimited frontmatter block; all four frontmatter-carrying files
   (`loom-eval-code`, `loom-eval-plan`, `loom-playbook`, `loom-run` `SKILL.md`) close
   `---` at line 4, and every hunk in them starts at line 27+.
5. **Ledger-blob identity** — `git hash-object` on the two pre-placed 0026 records
   returns `56d74dfc61c9a8fafcf2627fb61355f4b9f56078` and
   `967200c287ad0ad4f5166b4862ac449206e1e337`, unchanged.
6. **ADR 0026 body identity** — `diff <(git show b2614ce:...) .docs/ADR/0026-...md`
   shows a single differing line: `Status: Plan Review` → `Status: Accepted`.
7. **No out-of-class paths** — `git diff main...HEAD --name-only` contains only
   allowlist paths; no `*.sh`/`bin`/hooks/`*.bats`/`*.json`/`scripts/**`/`spec/**`/
   non-`0026` ADR.
8. **Gate green** — `LOOM_DIFF_BASE=HEAD scripts/check` at this HEAD: 452/452 Bats,
   repository-validation, link-check, Claude strict plugin validation, and diff
   whitespace all passed; zero `not ok` lines. No test-301 flake observed this run.
