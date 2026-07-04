# Infrastructure-blocked escalation — playbook wiring (ADR 0017)

Status: Implemented
Lifecycle: Draft → Plan Review → Approved → In Progress → Implemented → (code review) → Landed → Archived
Target specs: 03-artifact-lifecycle.md (§ "Infrastructure-blocked escalation"), 04-orchestrator.md (§ "Human checkpoints", § "Automated review before a slice lands")
Target ADR: 0017-infrastructure-blocked-escalation.md (Approved)

## Context

**Goal.** Wire the three-part decision of [ADR 0017](../ADR/0017-infrastructure-blocked-escalation.md)
— now already re-frozen into spec [03](../spec/03-artifact-lifecycle.md) (§ "Infrastructure-blocked
escalation") and spec [04](../spec/04-orchestrator.md) (§ "Human checkpoints" + the degraded-review
rule in § "Automated review before a slice lands") — into loom's **operational playbook** so the
orchestrator and developer actually execute it. The specs are the frozen authority; this slice makes
the playbook bodies conform. **Pure-docs, no code.**

The three parts to land in the playbook:

1. **Infrastructure-blocked escalation** — a third escalation type (sibling to the round-limit and
   starvation-loop escalations), fired by an infrastructure-failure signature, that is **not**
   round-counted, halts rather than retry-loops, write-ahead checkpoints (ADR 0013), and pauses +
   summarizes to the owner. Detect-on-failure only (loom cannot poll limits).
2. **Degraded-review honesty** — a `/code-review` / `/security-review` run whose finder/verify
   sub-agents crashed on an infrastructure limit is **INVALID**, never `ran-clean`; the orchestrator
   must **detect the false-clean** before trusting a "no findings" result, re-run once unblocked, or
   record the existing `skipped: command-unavailable` token — never a fabricated clean.
3. **Incremental-commit developer discipline** — a SHOULD: commit each gate-green / coherent sub-step
   (not one big final commit) so a mid-work kill leaves committed progress; prefer small targeted
   `Edit`s + terse returns over a whole-file `Write` (which is the operation most likely to blow the
   per-response 32k output-token cap mid-edit).

**In scope (files this slice edits):**
- `plugins/loom/skills/loom-playbook/references/orchestration.md` — new *Infrastructure-blocked
  escalation* section + two bullets in the automated-review run step (degraded-run + false-clean
  detection).
- `plugins/loom/agents/developer.md` — new *Incremental-commit discipline* subsection (Part 3, a SHOULD).
- `plugins/loom/skills/loom-playbook/references/review-findings.md` — new degraded-run subsection +
  broaden the `skipped: command-unavailable` gloss (still exactly four tokens).
- `plugins/loom/commands/run.md` — two short pointers in the driver loop (a false-clean reminder at
  step d2; an infra-block sibling note at the round-limit step f) so the driver checklist stays
  consistent with the new `orchestration.md` section.
- `.docs/slice-plans/README.md` — add this plan to the Active-plans index (committed together with
  the plan, sequential M1 habit).

**Out of scope (explicit non-scope):**
- **All code.** No hook, no `loom-coord.sh`, no `.sh`/`.bats` changes. ADR 0017 § Scope guard fixes
  this as an **orchestration rule, not a hook** (hooks are tool-event driven, cannot see account
  state); there is nothing executable to add.
- **Any spec or ADR edit.** Specs 03/04 are already re-frozen with the ADR 0017 contract and ADRs are
  immutable — this slice only conforms the playbook to them (spec 03 § "No spec edit happens at
  landing"; ADR 0005).
- **A new `Status:` token.** The degraded/limit-crashed review **reuses** the existing four-token
  contract (maps to `skipped: command-unavailable`); this slice must not add a fifth token.
- **`SKILL.md`.** Considered and excluded: SKILL.md's References index does not enumerate
  `orchestration.md`'s escalation subsections, and its one-line `review-findings.md` entry summarizes
  the artifact's purpose without listing the tokens or run-side rules — adding the infra-block detail
  there would duplicate the single-source bodies without adding a navigable pointer. Left untouched.
- **`references/parallelism.md`, both eval rubrics, other agents.** The escalation is an
  orchestrator-side driver rule and a developer intra-role discipline; no evaluator rubric or
  parallelism rule changes.

## Steps

Edit in this order (references body first, then the pointer files that cite it).

### 1. `plugins/loom/skills/loom-playbook/references/orchestration.md` — new escalation section

Insert a new `## Infrastructure-blocked escalation` section **immediately after** the `## Round
limit` section (which ends with the "See [spec 03 `## Round limits`] … reset rule." paragraph) and
**before** `## Parallelism`. This places it as a visible sibling to the round-limit escalation; the
starvation-loop escalation already lives in *Restart safely → Forward-progress guard* above. The
section must:

- **Cite authority** up top: spec [04](../../../../../.docs/spec/04-orchestrator.md) § "Human
  checkpoints" + § "Automated review before a slice lands", spec
  [03](../../../../../.docs/spec/03-artifact-lifecycle.md) § "Infrastructure-blocked escalation" (the
  canonical contract), and [ADR 0017](../../../../../.docs/ADR/0017-infrastructure-blocked-escalation.md).
  Use the same relative-link depth as the existing sections in this file (`../../../../../.docs/…`).
- **State the infra-failure signature set**, mirroring spec 03/04 wording exactly for terminology
  parity: an account **spend / usage / quota limit** reached; a **rate-limit / HTTP 429**; a **5xx** /
  transient upstream error; a **safety-classifier-unavailable** error; or a **partial workflow
  failure** — a multi-agent workflow (e.g. `/code-review`) whose sub-agents crashed on one of the
  above, even if it returns a plausible summary.
- **State the on-detection rule** as an ordered list matching spec 03's four MUSTs: (1) **not a valid
  result** — not a blind-eval FAIL, not `ran-clean`, not a genuine finding set, and **no round
  consumed** (never increments `Round:` toward the 5-FAIL threshold; never fabricates/attributes
  findings); (2) **halt, do not retry-loop** into the same limit (the block clears by owner action —
  raise the limit, wait out a 429 — not by re-attempting); (3) **write-ahead checkpoint** to
  `status/handoff.md` per ADR 0013 rule 1 so resume is lossless; (4) **pause + summarize to the
  owner**, naming (a) the specific block, (b) where it fired (role/command, artifact + `Status:`), and
  (c) how to resume.
- **State that it is detect-on-failure only** — loom has no interface to account limit state and
  cannot poll or predict a limit; it always takes one hit before it can pause. It is an orchestration
  rule, **not a hook**.
- **Name it a sibling** of the round-limit (spec 03) and starvation-loop (ADR 0013) escalations —
  **same pause + summary shape, different trigger**, but explicitly **NOT round-counted** because the
  trigger reflects account state, not artifact quality.

### 2. `plugins/loom/skills/loom-playbook/references/orchestration.md` — automated-review run step

In `## Automated review before a slice lands`, insert **two new bullets after the `- **Degradation.**`
bullet** (the `skipped: command-unavailable` one) and **before `- **Not the gate.**`**:

- **`- **Degraded runs are invalid, never clean.**`** A `/code-review` / `/security-review` run whose
  **finder or verify sub-agents failed on an infrastructure limit** (spend/usage/quota, 429, 5xx,
  safety-classifier-unavailable) is **INVALID** — a "no findings" result from finders that never
  executed is a **false-clean**, not a clean review. Such a run is **never recorded `ran-clean`** and
  **never fed to the blind code-evaluator**; it is an instance of the infrastructure-blocked
  escalation above → same pause + summary. **Re-run** the command once unblocked; if it genuinely
  cannot be re-run, record the existing **`skipped: command-unavailable`** token (never a fifth token,
  never `ran-clean`). Cite ADR 0017 + spec 04 § "Automated review before a slice lands".
- **`- **False-clean detection — how.**`** Before trusting any "no findings" (or "no findings survived
  verification") result as `ran-clean`, **inspect the workflow result for a sub-agent / finder failure
  indicator**: a non-empty failures list, error signatures matching the infrastructure set
  (spend/usage/quota, 429, 5xx, classifier-unavailable), or a **finder count of 0 with failures
  present**. Any such indicator → treat as a degraded run (above), **INVALID**, not `ran-clean`. Only a
  "no findings" result from finders that **actually executed and completed** is recorded `ran-clean`.

Keep wording aligned with spec 04's two bullets of the same names so the playbook is a faithful
restatement, not a divergent one.

### 3. `plugins/loom/agents/developer.md` — incremental-commit discipline (Part 3, a SHOULD)

Add a new `## Incremental-commit discipline (ADR 0017)` subsection **after `## How you work`** (after
its step 5, which ends "…fix or stop if it is a fallback. Stop.") and **before `## Finalize pass`**.
It must, framed as a **SHOULD**:

- Commit each **gate-green or coherent sub-step** rather than accumulating one big final commit, so a
  **mid-work kill** (an output-cap crash, an account limit) leaves **committed progress** on the
  branch instead of throwaway uncommitted WIP.
- Prefer **small, targeted `Edit`s and terse returns** over emitting a whole file through a single
  `Write` — the `Write` is the operation most likely to blow the per-response **32k output-token cap**
  mid-edit.
- **Reconcile with step 5's "clean, single-slice commit":** this does not conflict — the slice remains
  **one single-purpose unit** on one branch; the code evaluator reads the slice's **commit range**
  (`git diff <base>...<slice-HEAD>`, per spec 04 / ADR 0011), so several incremental commits on the
  slice branch are reviewed together. It tightens *intra*-role commit granularity **without changing
  the handoff boundary**.
- Cite ADR 0017 (Part 3) and note it reinforces ADR 0003 (commit-per-handoff) + the ADR 0012
  bounded-return contract.

### 4. `plugins/loom/skills/loom-playbook/references/review-findings.md` — degraded-run note + broadened gloss

Two edits, **preserving the exactly-four-token contract** (no new row):

- **Broaden the `skipped: command-unavailable` table gloss** (the fourth row of the status-token
  table): change its meaning cell from "Built-in not available in this environment (ADR 0010 §7)." to
  also cover the limit-crashed case — e.g. "Built-in not available in this environment, **or the
  command could not complete (e.g. limit-crashed)** (ADR 0010 §7 / ADR 0017)." The token string
  itself is unchanged.
- **Add a new subsection** — `## Degraded runs are not clean — an infrastructure block (ADR 0017)` —
  **after** the `## Findings come from real command output — a hard invariant` section and **before**
  `## Required status field — per command`. It must state: a run whose **finder/verify sub-agents
  failed on an infrastructure limit** (spend/usage/quota, 429, 5xx, safety-classifier-unavailable) is
  **INVALID**, not clean; a "no findings" result from finders that never executed is a **false-clean**,
  **never recorded `ran-clean`** and **never fed to the blind code-evaluator**; it is an instance of
  the infrastructure-blocked escalation (pointer to
  [`orchestration.md`](orchestration.md) § "Infrastructure-blocked escalation" + § "Automated review
  before a slice lands", and spec 03/04). Re-run once unblocked, **or** record the **existing**
  `skipped: command-unavailable` token — this **reuses** the four-token contract, **adds no fifth
  token**. Cross-reference the "Findings come from real command output" invariant it extends.

### 5. `plugins/loom/commands/run.md` — driver-loop pointers

Two short additions so the driver checklist matches the new `orchestration.md` section:

- **Step d2** (the automated-review step): append a sentence — a review whose **finders crashed on an
  infrastructure limit** is **INVALID** (a false-clean), **never `ran-clean`**; inspect the workflow
  result for a finder-failure indicator before trusting "no findings", treat a limit-crashed run as an
  **infra-block escalation** (re-run when unblocked, else `skipped: command-unavailable`) — pointer to
  orchestration.md → *Automated review before a slice lands*.
- **Step f** (the round-limit line): append a sibling note — **also escalate (same pause + summary,
  but NOT round-counted)** on an **infrastructure block** (spend/usage/quota limit, 429, 5xx,
  classifier-unavailable, or a limit-crashed workflow); detect-on-failure only — pointer to spec
  03/04 + ADR 0017 → orchestration.md → *Infrastructure-blocked escalation*.

### 6. `.docs/slice-plans/README.md` — Active-plans index

Replace the `## Active plans` `(none)` line with an entry for
`infra-blocked-escalation-wiring-plan.md` describing this pure-docs slice (ADR 0017 playbook wiring:
`orchestration.md` new escalation section + degraded/false-clean bullets, `developer.md` incremental-
commit SHOULD, `review-findings.md` degraded note + broadened gloss, `run.md` pointers). Commit this
in the **same commit** as the plan.

## Verification

Automated review for the implementing slice: **`skipped: docs-only`** (no code file in the diff).
Acceptance is **doc consistency**, checked mechanically with `rg` (not by eye), all from repo root:

1. **Exactly four tokens preserved.**
   `rg -c '^\| `(ran-with-findings|ran-clean|skipped: docs-only|skipped: command-unavailable)`' plugins/loom/skills/loom-playbook/references/review-findings.md`
   must print `4`. No new token string appears anywhere:
   `rg -n 'skipped: (limit|degraded|infra)' plugins/loom/skills/loom-playbook plugins/loom/agents plugins/loom/commands`
   returns nothing.
2. **New escalation section exists and is a sibling, not round-counted.**
   `rg -n '^## Infrastructure-blocked escalation' plugins/loom/skills/loom-playbook/references/orchestration.md`
   matches once; `rg -n -i 'not.*round-count|not round-counted|detect-on-failure' …/orchestration.md`
   confirms both properties are stated.
3. **Terminology parity with specs 03/04.** Each signature term appears in the new orchestration.md
   section and matches spec wording:
   `rg -n -i 'spend ?/ ?usage ?/ ?quota|429|5xx|classifier-unavailable|partial workflow failure' plugins/loom/skills/loom-playbook/references/orchestration.md`
   returns the full set; and the false-clean bullet contains "finder count of 0 with failures present"
   (`rg -n 'finder count of 0' …/orchestration.md`).
4. **Degraded-run wiring present in review-findings.md.**
   `rg -n 'Degraded runs are not clean|false-clean|INVALID' plugins/loom/skills/loom-playbook/references/review-findings.md`
   matches; the broadened gloss mentions limit-crashed
   (`rg -n 'limit-crashed' …/review-findings.md`).
5. **Developer discipline present as a SHOULD.**
   `rg -n 'Incremental-commit discipline|SHOULD|32k' plugins/loom/agents/developer.md`
   matches; it references ADR 0017 (`rg -n 'ADR 0017' …/developer.md`).
6. **run.md pointers present.**
   `rg -n -i 'infrastructure block|false-clean|infra-block' plugins/loom/commands/run.md` matches at
   both d2 and f.
7. **Cross-links resolve.** For every relative markdown link introduced in the four edited files,
   verify the target path exists (resolve each `../…` against the file's own directory, e.g. with a
   `while read` loop over `rg -o '\]\(([^)]+\.md)[^)]*\)'` captures, `test -f` each). No broken link.
8. **No frozen-artifact or code edit.** `git diff --name-only <base>...<slice-HEAD>` lists only:
   the four playbook files above, `.docs/slice-plans/README.md`, and this plan — **no** file under
   `.docs/spec/` or `.docs/ADR/`, and **no** `*.sh`/`*.bats`/`hooks.json`.

## Notes

**Gate evidence (pure-docs; automated review: skipped: docs-only):**

1. Token count: `rg -c '...' review-findings.md` → `4`. No fifth token (`rg -n 'skipped: (limit|degraded|infra)' ...` → empty).
2. New section: `rg -n '^## Infrastructure-blocked escalation' orchestration.md` → line 255. NOT round-counted + detect-on-failure: confirmed (lines 291, 296).
3. Terminology parity: spend/usage/quota, 429, 5xx, classifier-unavailable, partial workflow failure — all present (lines 215, 226, 227, 266–271, 283). `finder count of 0 with failures present` — line 227.
4. Degraded-run wiring: `Degraded runs are not clean` + `false-clean` + `INVALID` in review-findings.md lines 87/90/92. `limit-crashed` gloss — line 128.
5. Developer discipline: `Incremental-commit discipline` + `SHOULD` + `32k` + `ADR 0017` — all present in developer.md.
6. run.md pointers: `false-clean` at line 82 (d2), `infrastructure block` at line 91 (f).
7. Cross-links: all relative `.md` links in the four edited files resolve (python3 verification → OK).
8. No frozen-artifact or code file touched: `git diff --name-only` lists only the 4 playbook bodies + the slice-plan. No `.docs/spec/`, no `.docs/ADR/`, no `.sh`/`.bats`.
