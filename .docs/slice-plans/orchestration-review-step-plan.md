# Orchestration automated-review step (ADR 0010 Slice B)

Status: Approved
Target specs: 04-orchestrator.md (§ "Automated review before a slice lands")

## Context

ADR 0010 (Accepted) added orchestrator-run automated review to loom's code-review
phase: when a slice reaches `Implemented`, the orchestrator runs Claude Code's
built-in `/review` and `/security-review` on the slice's commit **diff**, captures
the output into a committed, identity-neutral, per-slice **findings artifact**, and
hands it to the blind code-evaluator as an additional input. Spec
[`04-orchestrator.md`](../spec/04-orchestrator.md) § "Automated review before a slice
lands" is Approved and frozen and now describes this orchestrator step. The playbook's
orchestration body — [`references/orchestration.md`](../../plugins/loom/skills/loom-playbook/references/orchestration.md),
the shared operating rules for every `/loom:*` command — does **not** yet reflect that
step. This slice adds it, faithful to spec 04.

This is **Slice B** of three ADR 0010 follow-on playbook slices. The other two:

- **Slice A** (landed): `references/review-findings.md` — the single authoritative
  definition of the findings artifact's **format** (path, identity-neutral invariant,
  the four per-command status tokens, finding-entry fields). This slice **points to**
  that file for the artifact; it does **not** restate the format.
- **Slice C** (runs in **parallel** with this slice): `agents/code-evaluator.md` +
  `references/code-eval-rubric.md` — the code-evaluator's *reads* and *adjudication
  procedure*. Because Slice C runs concurrently on its own branch, this slice **must
  not touch those two files** — the two slices' file sets must stay disjoint per
  [`parallelism.md`](../../plugins/loom/skills/loom-playbook/references/parallelism.md)
  (slicer-independence: parallel slices touch disjoint files).

**Single-source boundary (load-bearing).** Spec 04 § "Automated review before a slice
lands" is the **authority** for the orchestrator's run step — point to it, do not
restate it as new policy. `references/review-findings.md` is the authority for the
artifact **format/path/status tokens** — point to it, do not duplicate it. This slice
adds the operational *playbook* reflection of spec 04's step into the orchestrator's
operating rules, in `orchestration.md`'s existing voice.

### In scope

- **`plugins/loom/skills/loom-playbook/references/orchestration.md` ONLY** — add the
  orchestrator's automated-review step to its operating rules, faithful to spec 04,
  pointing to spec 04 (authority) and `review-findings.md` (artifact format).

### Out of scope (do not touch in this slice)

- `agents/code-evaluator.md` and `references/code-eval-rubric.md` — **Slice C**, which
  runs in **parallel** with this slice. Touching them would overlap Slice C's file set
  and break the disjoint-files rule. Do **not** edit them.
- `references/review-findings.md` — **Slice A** (landed); **reference only**, never
  edit, never restate its format.
- Any `spec/` or `ADR/` file (frozen; changed only by planning).
- `SKILL.md` (it has no `orchestration.md` bullet today and gains none here),
  `commands/run.md`, `references/status-machine.md`, and any other playbook file.
- `.docs/slice-plans/README.md` (the slice-plans index — orchestrator-owned).
- Any `.docs/status/` living doc (roadmap/progress/handoff — orchestrator-owned) and
  `CLAUDE.md` (developer finalize pass, not this plan).
- **Restating** spec 04's run policy or `review-findings.md`'s artifact format — point,
  don't restate.

## Steps

### Step 1 — Add an "Automated review before a slice lands" section to `orchestration.md`

In `plugins/loom/skills/loom-playbook/references/orchestration.md`, add a **new titled
section** that reflects spec 04's step into the orchestrator's operating rules. Mirror
spec 04's heading for traceability: use the section heading **`## Automated review
before a slice lands`**. Place it **after** the `## Init-mode detection ...` section
and **before** `## Scope & claimed gates (for /loom:run)` (i.e. in the operating-rules
flow, where a reader scanning the orchestrator's per-slice duties will find it), or
alternatively immediately after `## Core rules (always)` — the developer picks the
cleaner of these two so it reads naturally; do not interleave it inside an existing
section. Match the file's existing voice: terse bulleted rules, relative-path links to
authority, no restating of policy that lives elsewhere.

The section must convey exactly the following, no more (each maps to spec 04 / ADR
0010 — cite, do not re-argue):

1. **What & when.** When a slice reaches **`Implemented`**, **before (or while)**
   dispatching the code-evaluator and **before the slice can land**, the orchestrator
   runs Claude Code's built-in **`/review`** and **`/security-review`** on the slice's
   commit **diff**. Point to spec
   [04](../../../../../.docs/spec/04-orchestrator.md) § "Automated review before a
   slice lands" as the authority and cite
   [ADR 0010](../../../../../.docs/ADR/0010-orchestrator-run-automated-review-in-code-eval.md)
   (§1).

2. **Why the orchestrator (not the evaluator) runs it.** State in one sentence: only
   the orchestrator may spawn and a sub-agent cannot safely run a command that may
   spawn, so the orchestrator runs these commands — never the code-evaluator. Cite
   [ADR 0001](../../../../../.docs/ADR/0001-plugin-architecture-and-orchestrator.md).
   (This reinforces the file's existing "You spawn; roles never spawn" core rule —
   keep it consistent with that, do not contradict it.)

3. **Local diff mode only.** The commands run in **local diff mode only** on the
   slice's commit diff — **never** PR / `--comment` / `--fix` mode (no GitHub
   round-trip, no PR metadata, no posting, no working-tree mutation), so the input
   stays identity-neutral and network-silent and the blind contract holds (ADR 0010
   §1/§3). One line; do not re-derive the blind-contract argument — cite it.

4. **Capture into the findings artifact (point, don't restate).** The orchestrator
   captures the output into the committed, identity-neutral, per-slice findings
   artifact **per
   [`review-findings.md`](review-findings.md)** — point there for path, format, and
   the status tokens; do **not** restate them. State only that it is committed
   author-neutral (per [`commit-convention.md`](commit-convention.md)) and handed to
   the **blind code-evaluator** as an **additional input** alongside the commit diff,
   slice-plan, specs, and gate evidence.

5. **Applicability — run on code diffs, skip-with-a-note for pure-docs.** Run the
   review **only when the slice's diff touches at least one code (non-docs) file**; a
   **pure-docs slice skips with a note**, recording the **`skipped: docs-only`** status
   in the artifact (never "ran clean"). Cite ADR 0010 §5. Use the token verbatim:
   `skipped: docs-only`.

6. **Degradation — never silently claim clean.** If a command is **unavailable** in
   the environment, the orchestrator **skips it and records** the
   **`skipped: command-unavailable`** status — it must **never silently claim a clean
   review**. Cite ADR 0010 §7. Use the token verbatim: `skipped: command-unavailable`
   (note the hyphen).

7. **Not the gate.** State explicitly that this is a **new, separate review
   dimension** — **not** part of the `format → lint → test` gate, which is
   **unchanged**. Cite ADR 0010 §8.

When referencing the four status outcomes, use the canonical tokens **verbatim** as
fixed in `review-findings.md`: `ran-with-findings`, `ran-clean`, `skipped: docs-only`,
`skipped: command-unavailable`. Do **not** invent variants (e.g. not "skipped:
command unavailable" without the hyphen, not "skipped-docs-only"). If the section names
the full set, name all four; otherwise it need only name the two skip tokens it uses
(items 5–6) and may point to `review-findings.md` for the complete set.

### Step 2 — Add a pointer from the dispatch/driver-loop area (optional, if it reads cleanly)

Optionally, add a **one-line pointer** in the existing operating-rules flow so a reader
at the dispatch/handoff rules is routed to the new section — e.g. a short bullet near
the `## Round limit` / `## Parallelism` area or at the end of `## Core rules (always)`
reading roughly *"Before a slice can land, run the automated review — see [Automated
review before a slice lands](#automated-review-before-a-slice-lands)."* Keep it to one
line and only if it improves navigation; do not duplicate the section's content. The
developer may omit this if the section's placement (Step 1) already makes it
discoverable.

## Verification

This is a **pure-markdown slice** — the `format → lint → test` gate does **not**
apply. The acceptance check is the **blind code-evaluator's fidelity/consistency
review**, performed **mechanically** (not by eye) with `rg`-style cross-reference and
`test -e` link checks:

1. **Exactly one file changes; Slice C's files untouched.** Only
   `plugins/loom/skills/loom-playbook/references/orchestration.md` changes. No
   `agents/code-evaluator.md`, `references/code-eval-rubric.md`,
   `references/review-findings.md`, `SKILL.md`, `commands/run.md`, `status-machine.md`,
   any `spec/`/`ADR/`, `slice-plans/README.md`, `status/`, or `CLAUDE.md` edits.
   - Mechanical check: `git diff --name-only` against the pre-slice commit lists only
     `plugins/loom/skills/loom-playbook/references/orchestration.md`.

2. **Section present and mirrors spec 04's heading.** The new
   `## Automated review before a slice lands` section exists.
   - Mechanical check:
     `rg -n "## Automated review before a slice lands" plugins/loom/skills/loom-playbook/references/orchestration.md`
     returns the heading.

3. **Canonical status tokens used verbatim.** The two skip tokens appear with exact
   spelling/hyphenation, and no variant spellings are introduced.
   - Mechanical check:
     `rg -n "skipped: docs-only|skipped: command-unavailable" plugins/loom/skills/loom-playbook/references/orchestration.md`
     surfaces both tokens; `rg -n "skipped: command unavailable|skipped-docs-only|skipped-command"`
     returns **nothing** (no variant spellings).

4. **Fidelity to spec 04 / ADR 0010, no contradiction.** The section conveys: run at
   `Implemented` before land; `/review` + `/security-review` on the commit diff; local
   diff mode only (never PR/`--comment`/`--fix`); orchestrator-runs-because-only-it-
   spawns; capture to the findings artifact handed to the blind evaluator;
   code-diff applicability with docs-only skip; command-unavailable degradation; and
   "not the gate". It does **not** contradict spec 04's § "Automated review before a
   slice lands" or the file's existing "You spawn; roles never spawn" core rule.
   - Mechanical check:
     `rg -n "/review|/security-review|local diff|Implemented|format → lint → test|diff" plugins/loom/skills/loom-playbook/references/orchestration.md`
     surfaces each element in the new section.

5. **Single-source boundary held — points, does not restate.** The section **points
   to** spec 04 (run authority) and `review-findings.md` (artifact format), and does
   **not** restate the artifact format (no status-token table copied in, no
   finding-entry field list) nor the evaluator's adjudication procedure (Slice C's
   home — no confirm/reject/discard steps, no severity mapping).
   - Mechanical check:
     `rg -n "04-orchestrator|review-findings.md" plugins/loom/skills/loom-playbook/references/orchestration.md`
     confirms both pointers present;
     `rg -n "confirm/reject|severity mapping|finding entry|source command" plugins/loom/skills/loom-playbook/references/orchestration.md`
     returns nothing (adjudication/format not restated).

6. **Authority links resolve.** ADR 0001 and ADR 0010, spec 04, `review-findings.md`,
   and `commit-convention.md` are cited and every relative link resolves from
   `references/`.
   - Mechanical check: resolve each `](...)` target with `test -e` relative to the
     file's directory; `.docs/` targets use the `../../../../../.docs/...` depth, and
     sibling references use the bare `name.md` form — match the file's existing
     convention.

## Notes

<Clarification requests between roles, dated. Resolutions are marked, not deleted.
Formal verdicts live in evaluations/, not here.>
