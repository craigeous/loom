# Round-Limit Conformance

Status: Plan Review
Target specs: 03-artifact-lifecycle.md

## Context

Spec 03 `## Round limits` was just amended and re-Approved (M4 escalation thread,
Cycle 1). It now defines a **FAIL-only** round counter:

- `Round:` counts **reject→revise cycles only** — a **FAIL increments** the round;
  a **PASS does not** start a new round. A PASS that resolves a prior FAIL is
  recorded with the **same** round number as the FAIL it resolves.
- The **first** clean review of a fresh artifact is **round 0** (not yet counted);
  only a FAIL moves it to round 1. Counted rounds run **1..N**.
- **One counter per artifact**, in its single eval file
  (`.docs/evaluations/<artifact-name>-eval.md`), spanning **both** plan-review and
  code-review phases (plan FAILs + code FAILs accumulate toward the same 5).
- **Threshold 5**; reset only owner-driven on materially-new direction at an
  escalation.
- The escalation **pause + summary contract** (stuck artifact + status; per-round
  findings 1..N; recurring-vs-new classification; owner options).

loom's playbook implementation does **not** yet match this. The current playbook
text says "a reject→revise cycle increments `Round:`" without the FAIL-only /
PASS-shares-number / round-0 / cross-phase nuance, and the two evaluator agent
prompts instruct writing `Round: n` with no rule for *when* `n` advances. That
gap produced the observed bug where evaluators numbered every eval pass
sequentially (shell-gate: R1 FAIL → R2 PASS → R3 PASS) instead of treating the
resolving PASS as the same round.

This slice brings the playbook into conformance with the amended spec. **The key
behavioral fix is in the two evaluator prompts** (they are the actor that writes
`Round:`); the orchestrator/template/run-command changes are supporting
consistency.

**Single-source discipline.** Spec 03 remains the canonical definition. Playbook
files state the **operational rule concisely** and **point to spec 03** as the
authority. Do **not** paste a divergent full restatement of the rule (the
escalation contract, reset rule, etc.) into each file.

**Out of scope:**

- Editing spec 03 or any other `spec/` or `ADR/` file (the authority is already
  set and frozen).
- Changing the threshold (it stays **5**).
- The pointer references in `parallelism.md` (line 13, a "see also") and
  `initialized.md` (line 38, "surface round-limit/escalation states") — these
  point at the rule, they do not define it, so they need no change.
- `status-machine.md` / `orchestration.md` reporting prose beyond their
  `## Round limit` sections; the rest of those files is unaffected.

## Steps

1. **`plugins/loom/skills/loom-playbook/references/status-machine.md`** — replace
   the body of the `## Round limit` section (currently lines 41–43:
   "A reject→revise cycle increments `Round:` in the eval file. After **5** rounds
   on one artifact, the orchestrator stops and escalates = **pause + summary** to
   the owner."). Keep the `## Round limit` heading. New body must state, concisely:
   - A **FAIL** increments `Round:`; a **PASS does not**. A resolving PASS carries
     the **same** round number as the FAIL it closes.
   - A fresh artifact's first review is **round 0** (not yet counted); the first
     FAIL moves it to round 1; counted rounds run **1..N**.
   - **One** counter per artifact in its single eval file, spanning **both**
     plan-review and code-review phases (FAILs from both accumulate toward the
     same limit).
   - After **5** rounds (the 5th FAIL) the orchestrator stops and escalates =
     **pause + summary**.
   - A link to spec 03 (`../../../../../.docs/spec/03-artifact-lifecycle.md`) as
     the authority for the full counting / reset / escalation-summary contract.
     Verify this relative depth resolves before relying on it (the file already
     references that path depth from peers — `orchestration.md` uses
     `../../../../../.docs/ADR/...`).
   - Do **not** restate the reset rule or the four-part escalation-summary
     contract in full here — point to spec 03 for those.

2. **`plugins/loom/skills/loom-playbook/references/orchestration.md`** — replace
   the body of the `## Round limit` section (currently lines 70–71: "Track
   reject→revise rounds per artifact (the `Round:` line in its eval file). After
   **5** rounds, stop and escalate = pause + summary to the owner."). Keep the
   heading. New body must state, concisely, framed from the **orchestrator's**
   point of view (it is the actor that counts FAIL-cycles and produces the
   escalation summary):
   - The orchestrator counts **FAIL** cycles per artifact via the `Round:` line in
     its single eval file — a PASS does not advance the count; a resolving PASS
     shares the FAIL's round number; a fresh artifact's first review is round 0.
   - **One** counter per artifact across **both** review phases (plan + code FAILs
     accumulate toward the same 5).
   - At **5** FAILs the orchestrator **stops and escalates = pause + summary**.
   - A link to spec 03's `## Round limits` (esp. the **Escalation contract
     (pause + summary)** subsection) for **what the summary must contain** and the
     **owner-driven reset rule**. Use the same relative path as Step 1.
   - Do **not** enumerate the four summary parts or restate the reset rule here —
     point to spec 03.

3. **`plugins/loom/skills/loom-playbook/templates/evaluation.md`** — annotate the
   `Round: <n>` line (line 4). Add concise inline guidance so an evaluator filling
   the template knows how to set `<n>`. Two acceptable forms (pick the cleaner):
   either an HTML comment on/after line 4, or fold a sentence into the existing
   `<!-- Rules … -->` block at lines 23–29. The guidance must say:
   - `<n>` is the count of **FAIL→revise cycles** for this artifact.
   - A **PASS that resolves a FAIL repeats** that FAIL's round number (it does not
     advance).
   - The **first clean review** of a fresh artifact is **round 0**.
   - Reference spec 03 `## Round limits` (or `references/status-machine.md`) for
     the full rule.
   - Keep it short — this is a template; do not paste the whole counting rule.

4. **`plugins/loom/agents/plan-evaluator.md`** — in step 2 of `## How you work`
   (line 48–51, where it instructs `Round: n`), make the counting rule explicit
   (**the key behavioral fix**). The instruction must direct the evaluator to:
   - **Increment `Round:` only on a FAIL.**
   - When the verdict is a **PASS that resolves a prior FAIL**, write the **same**
     round number as that FAIL (do not advance).
   - Treat a **fresh artifact's first review** (no prior FAIL in the eval file) as
     **round 0**.
   - This stops numbering PASSes sequentially. Point to spec 03 `## Round limits` /
     `references/status-machine.md` for the authority rather than restating the
     reset/escalation contract.
   - Keep concise. The re-review instruction already tells the evaluator to read
     the prior eval file (line 43–47), which is where the prior `Round:` /
     FAIL-vs-PASS history is read from.

5. **`plugins/loom/agents/code-evaluator.md`** — in step 4 of `## How you work`
   (line 42–47, where it instructs `Round: n`), apply the **same** counting-rule
   instruction as Step 4 (FAIL-only increment / PASS-resolving-a-FAIL reuses the
   number / first review of a fresh artifact is round 0; point to spec 03 /
   `status-machine.md`). Emphasize that because the counter is **one per artifact
   across both phases** (spec 03 Counter scope), the code evaluator reads the same
   eval file the plan evaluator wrote and **continues** the count — plan-review
   FAILs already recorded there are part of the running total; a code-review FAIL
   increments from wherever the count stands. Keep concise.

6. **`plugins/loom/commands/run.md`** — light touch on the round-limit driver-loop
   line (line 44: "Honor the round limit (5 → escalate = pause + summary)."). Make
   clear it counts **FAIL cycles** and point at spec 03's escalation contract for
   what the summary contains. One line, e.g. "Honor the round limit (5 **FAIL**
   cycles per artifact → escalate = pause + summary; see spec 03 `## Round limits`
   for the counting + summary contract)." Change only if it reads as inconsistent
   after Steps 1–5; if a one-clause addition suffices, keep it minimal.

7. **`.docs/slice-plans/README.md`** — add an `## Active plans` entry for this
   slice (replacing the `_(none)_` placeholder), in the same commit as the plan
   file (M1 sequential-slice habit; parallelism not in play). Entry:
   `[round-limit-conformance-plan.md](round-limit-conformance-plan.md)` —
   `Plan Review` — one line summarizing the slice (bring the playbook's round-limit
   text + both evaluator prompts into conformance with the amended spec 03
   FAIL-only counting rule).

## Verification

This repo's only executable code is the shell hook; **the files changed by this
slice are all markdown prose/prompts**, so there is **no fmt / lint / test gate**
for this slice. Acceptance is **review-against-spec-03**. The code evaluator runs
these mechanical checks (all from repo root):

1. **Scope guard.** `git diff --name-only <base>..HEAD` lists **only**:
   - `plugins/loom/skills/loom-playbook/references/status-machine.md`
   - `plugins/loom/skills/loom-playbook/references/orchestration.md`
   - `plugins/loom/skills/loom-playbook/templates/evaluation.md`
   - `plugins/loom/agents/plan-evaluator.md`
   - `plugins/loom/agents/code-evaluator.md`
   - `plugins/loom/commands/run.md` (only if Step 6 was needed)
   - `.docs/slice-plans/round-limit-conformance-plan.md`
   - `.docs/slice-plans/README.md`

   No `spec/` or `ADR/` file appears:
   `git diff --name-only <base>..HEAD | rg '\.docs/(spec|ADR)/'` returns **nothing**.

2. **Each evaluator prompt now encodes FAIL-only counting.** For **both**
   `plugins/loom/agents/plan-evaluator.md` and
   `plugins/loom/agents/code-evaluator.md`:
   - `rg -i 'only on a FAIL|FAIL.*increment|increment.*FAIL' <file>` matches
     (FAIL-only increment present).
   - `rg -i 'same.*round|repeat.*round|resolv' <file>` matches (PASS-resolving-a-FAIL
     reuses the number).
   - `rg -i 'round 0|round zero|first review' <file>` matches (round-0 fresh-artifact
     rule present).
   - `rg '03-artifact-lifecycle\.md|status-machine\.md' <file>` matches (points to
     authority).

3. **Template carries the guidance.**
   `rg -i 'FAIL.*cycle|round 0|resolv' plugins/loom/skills/loom-playbook/templates/evaluation.md`
   matches, and the `Round: <n>` line is still present
   (`rg '^Round: <n>' plugins/loom/skills/loom-playbook/templates/evaluation.md`).

4. **status-machine.md + orchestration.md match spec 03 and point to it.** For
   **both** `references/status-machine.md` and `references/orchestration.md`:
   - The `## Round limit` heading is intact
     (`rg '^## Round limit' <file>`).
   - FAIL-only counting is stated: `rg -i 'FAIL' <file>` matches inside that
     section, and the old bare phrasing
     "A reject→revise cycle increments `Round:`" / "Track reject→revise rounds"
     no longer carries the misleading every-cycle meaning (manual read confirms
     PASS-does-not-increment is stated).
   - Cross-phase scope is stated:
     `rg -i 'both.*phase|plan.*code|across.*review' <file>` matches.
   - Points to spec 03:
     `rg '03-artifact-lifecycle\.md' <file>` matches.
   - Threshold unchanged: `rg '\b5\b' <file>` still matches in the section.

5. **Single-source discipline — no divergent full restatement.** The four-part
   escalation-summary contract and the owner-reset rule are **not** re-pasted into
   the playbook files. Confirm the changed playbook files do **not** enumerate the
   summary parts: `rg -i 'recurring-vs-new|recurring vs new|per-round findings'`
   across the five playbook files returns **nothing** (those phrasings belong only
   to spec 03). Each playbook mention instead links to spec 03.

6. **Threshold untouched.** No changed file lowers/raises the 5:
   `rg -n 'round' plugins/loom/skills/loom-playbook/references/status-machine.md plugins/loom/skills/loom-playbook/references/orchestration.md plugins/loom/commands/run.md`
   shows the threshold still reads 5.

7. **Plan-commit hygiene.** `git show --stat <plan-commit>` touches **only**
   `.docs/slice-plans/round-limit-conformance-plan.md` and
   `.docs/slice-plans/README.md`, and `git show <plan-commit>` carries **no**
   author/role identity and **no** `Co-Authored-By` trailer.

**Intentionally untouched (call-outs, not defects):**

- `references/parallelism.md:13` — a "see also" pointer to orchestration.md's Round
  limit section; a pointer, not a definition.
- `references/initialized.md:38` — "surface round-limit/escalation states"; a
  reporting instruction that references the state, not the counting rule.
- `references/status.md` — does not exist (the status reference is
  `status-machine.md`, covered above); no separate reporting file to touch.

## Notes

<none yet>
