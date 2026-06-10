# CLAUDE.md auto-propagation — playbook conformance

Status: Landed
Target specs: 03-artifact-lifecycle.md, 08-playbook.md

## Context

The spec amendment for **`CLAUDE.md` auto-propagation (the curated digest)** is now
Approved in two spec files:

- `.docs/spec/03-artifact-lifecycle.md` — the developer's **finalize pass** (on
  code-eval PASS / `Landed`) now has a step (step 2 in the spec) to update the
  relevant `CLAUDE.md` **only when the landed slice changed something in the
  curated-digest scope** (durable convention / repo-layout fact / gate definition /
  read-first pointer). It is a **derived, non-spec digest** update — the "no spec
  edit at landing" rule and ADR 0005 stay fully intact; specs win on conflict;
  per-slice history stays in `progress.md`.
- `.docs/spec/08-playbook.md` — *Evolving the playbook* → "`CLAUDE.md`
  auto-propagation (the curated digest)" is the **authoritative definition** of the
  curated-digest boundary: the four inclusion categories, the explicit exclusion of
  per-slice history, coverage of both root and managed-project `CLAUDE.md`, and the
  derived/specs-win-on-conflict framing.

The playbook *implementation* (agent prompts + reference docs) does not yet reflect
this. This slice brings the implementation into conformance.

**Single-source discipline (the governing constraint of this slice):** spec 08 owns
the four-category boundary definition. Every playbook file that touches this topic
states the operational step **concisely** and **points to spec 08** — the full
four-category boundary is **not** pasted into more than one place. The developer
agent prompt may name the four categories tersely as the trigger condition (parallel
to how spec 03 step 2 names them), but it does not restate spec 08's full
sub-bullets; the reference docs only point.

**In scope:** edits to the five implementation files listed in Steps; this plan
file; the `slice-plans/README.md` Active entry (this is a sequential slice in loom's
own repo, so the planner writes the Active entry in this same plan commit per the
pre-parallelism habit still in force here).

**Out of scope:** any edit to `.docs/spec/` or `.docs/ADR/` (frozen-Approved — see
Notes for a known non-blocking MINOR that is deliberately NOT fixed here); any
project-specific / hardcoded `CLAUDE.md` content; the incidental finalize references
in `commands/run.md`, `commands/eval-code.md`, `agents/code-evaluator.md`, and
`agents/planner.md` (see Step 6 — intentionally untouched).

## Steps

1. **`plugins/loom/agents/developer.md` — add the CLAUDE.md curated-digest step to
   the `## Finalize pass` section** (currently lines ~47–54, three numbered steps:
   1 = progress/handoff/roadmap; 2 = `git mv`/archive/land; 3 = commit).

   Insert a new **step 2** between the current step 1 and the current step 2
   (renumber `git mv`/archive to 3 and commit to 4). The new step reads concisely
   and points to spec 08:

   > 2. Update the relevant `CLAUDE.md` **only if the landed slice changed something
   >    in the curated-digest scope** — i.e. it introduced or altered a durable
   >    convention, a repo-layout fact, a gate definition, or a "read-first" pointer.
   >    **Per-slice history does NOT go into `CLAUDE.md`** — it stays in
   >    `progress.md`. If the slice changed nothing in that scope, make **no**
   >    `CLAUDE.md` edit. This applies to loom's own root `CLAUDE.md` and, in a
   >    managed project, to that project's `CLAUDE.md`. `CLAUDE.md` is a **derived,
   >    non-spec digest** — never edit `.docs/spec/` or `.docs/ADR/`; on conflict the
   >    specs win and `CLAUDE.md` is corrected to match. See
   >    [`spec 08`](`08-playbook.md`) (*Evolving the playbook → `CLAUDE.md`
   >    auto-propagation*) for the authoritative boundary.

   Keep the existing "**Do not edit any spec.**" emphasis on the progress/handoff
   step. Match the file's existing markdown link style for spec pointers (the file
   uses prose references like "spec 08" rather than relative links; use a plain
   `spec 08` reference consistent with the surrounding text rather than inventing a
   relative path — confirm the file's existing convention when editing and follow
   it). Do not paste spec 08's full four sub-bullets; the terse category list above
   is the trigger condition, not a restatement of the boundary.

2. **`plugins/loom/skills/loom-playbook/references/status-machine.md` — add the
   CLAUDE.md finalize step to the slice-plan lifecycle mention.** This file's
   `## Lifecycles` section (lines ~54–60) describes the slice-plan lifecycle in one
   compressed line and does **not** enumerate the finalize sub-steps, so a full
   step list is not warranted here. Add a single concise sentence to the slice-plan
   bullet (or immediately after it) noting that the finalize pass, on PASS, also
   updates the relevant `CLAUDE.md` when the slice touched the curated-digest scope,
   and **point to spec 08** for the boundary and to spec 03 for the finalize step.
   Example addition to the slice-plan lifecycle bullet:

   > The finalize pass that runs after code-eval PASS also updates the relevant
   > `CLAUDE.md` when the landed slice changed something in the curated-digest scope
   > (a derived non-spec digest; per-slice history stays in `progress.md`) — see
   > [spec 03](.../03-artifact-lifecycle.md) (*finalize pass*) and
   > [spec 08](.../08-playbook.md) (the curated-digest boundary).

   Use this file's existing relative-link convention for spec pointers (it already
   links to `../../../../../.docs/spec/03-artifact-lifecycle.md` — match that exact
   relative depth). Do NOT restate the four categories here — pointer only.

3. **`plugins/loom/skills/loom-playbook/references/parallelism.md` — add a brief
   consistency note that the finalize `CLAUDE.md` update is part of the serialized
   finalize-on-main.** The "Land (orchestrator, from the main worktree —
   serialized…)" section (lines ~135–155) lists the finalize-pass steps 1–5 run on
   main. Add the `CLAUDE.md` update as a finalize sub-step there (e.g. a new step
   after the living-doc/roadmap updates, before the `git mv` archive), worded
   concisely and **pointing to spec 08** for the boundary:

   > Update the relevant `CLAUDE.md` if the landed slice changed something in the
   > curated-digest scope (derived non-spec digest; per-slice history stays in
   > `progress.md`; see [spec 08](.../08-playbook.md)).

   Then add one sentence tying it to this file's existing concurrency model:
   `CLAUDE.md` is a **shared single-instance content file**, so concurrent slices
   that touch it are **sequenced, not parallelized** (slicer-independence rule,
   already stated in this file's *When to parallelize* section and *What stays
   serial*), and its finalize update is serialized on main with the living docs
   (ADR 0008's serialized finalize). Do **not** over-state: `CLAUDE.md` is already
   named in this file as a shared-content file under the slicer-independence rule
   (lines ~25, ~238); this note connects the finalize update to that existing rule
   rather than introducing a new mechanism. Use this file's existing relative-link
   convention for the spec 08 pointer (`../../../../../.docs/spec/08-playbook.md`).

4. **`plugins/loom/skills/loom-playbook/references/greenfield.md` — frame the
   initial project `CLAUDE.md` write as establishing a curated digest.** Step D
   (lines ~76–88) writes the project `CLAUDE.md`. Add a light-touch sentence that
   the managed-project `CLAUDE.md` is a **curated digest** the developer's finalize
   pass keeps current as slices land (so this initial write *establishes* the
   curated digest rather than being a one-time dump), and **point to spec 08** for
   the boundary. Example addition after the existing bullets in Step D:

   > This `CLAUDE.md` is a **curated digest** — a stable, agent-facing map of the
   > project, not a changelog. The developer's finalize pass keeps it current as
   > slices land (the curated-digest boundary is defined in
   > [spec 08](../../../../../.docs/spec/08-playbook.md) — *Evolving the playbook*;
   > per-slice history stays in `progress.md`). Greenfield's job is to **establish**
   > it, not to dump everything into it.

   Match greenfield.md's existing relative-link convention for spec pointers (it
   links to `../../../../../.docs/spec/06-init-modes.md`; use the same depth for
   spec 08). Pointer only — do not restate the four categories.

5. **`plugins/loom/skills/loom-playbook/references/docs-layout.md` — reflect the
   curated-digest framing in the *Project `CLAUDE.md`* guidance.** The *Project
   `CLAUDE.md`* section (lines ~27–32) says init writes a project `CLAUDE.md` and
   "Long-term, loom keeps best practices in root- and project-level `CLAUDE.md`."
   Add a concise sentence that this `CLAUDE.md` is a **curated digest** kept current
   by the developer finalize pass per spec 08, and that per-slice history stays in
   `progress.md` (not `CLAUDE.md`). Example addition:

   > Both root- and project-level `CLAUDE.md` are **curated digests** (stable maps,
   > not changelogs); the developer's finalize pass keeps them current as slices land
   > — see [spec 08](../../../../../.docs/spec/08-playbook.md) (*Evolving the
   > playbook → `CLAUDE.md` auto-propagation*) for the boundary, and note per-slice
   > history stays in `status/progress.md`.

   Confirm docs-layout.md's relative-link convention when editing (it uses relative
   links like `../gates/`; use the `../../../../../.docs/spec/08-playbook.md` depth
   for the spec pointer, matching the sibling reference files). Pointer only.

6. **Confirm the deliberately-untouched finalize references.** Verify (read, do not
   edit) that the finalize mentions in these files are incidental — they dispatch to
   or name the finalize pass without enumerating the developer's finalize sub-steps,
   so they do not drift from the amended spec and need no change:
   - `plugins/loom/commands/run.md` (~line 42: "spawn the developer's **finalize
     pass** (update `status/`, archive …)") — orchestration dispatch, incidental.
   - `plugins/loom/commands/eval-code.md` (~lines 21–22: hands to the finalize pass)
     — dispatch, incidental.
   - `plugins/loom/agents/code-evaluator.md` (~line 57: sets `Landed` for the
     developer's finalize pass) — status reference, incidental.
   - `plugins/loom/agents/planner.md` (~line 42: planner's *own* status-doc finalize
     on planning-artifact approval) — a different finalize, incidental.

   Leave all four unchanged. (This step produces no edit; it is the scope guard for
   the diff.)

7. **Write the `slice-plans/README.md` Active entry in this same plan commit.** Add
   an Active-plans entry under `## Active plans` linking
   `claude-md-autopropagation-conformance-plan.md` with a one-line summary (this is
   a sequential slice in loom's own repo; the planner writes the Active entry in the
   same plan commit per the pre-parallelism M1 habit still in force for loom's repo).

## Verification

loom's own repo has **no compiled gate** (its content is markdown). Acceptance is
**review-against-spec**, proven with mechanical `rg` checks plus a `git diff` scope
guard. Run from the repo root.

1. **Developer finalize now includes the CLAUDE.md step pointing to spec 08:**

   ```
   rg -n -i "CLAUDE\.md" plugins/loom/agents/developer.md
   rg -n -i "curated[- ]digest|08-playbook|spec 08" plugins/loom/agents/developer.md
   ```
   Expect the `## Finalize pass` section to contain a `CLAUDE.md` step that names the
   curated-digest trigger and points to spec 08, and that the archive/commit steps
   are renumbered (3, 4).

2. **Per-slice-history exclusion stated where the digest is discussed:**

   ```
   rg -n -i "per-slice history|history (does not|stays|never)|progress\.md" \
     plugins/loom/agents/developer.md \
     plugins/loom/skills/loom-playbook/references/status-machine.md \
     plugins/loom/skills/loom-playbook/references/parallelism.md \
     plugins/loom/skills/loom-playbook/references/greenfield.md \
     plugins/loom/skills/loom-playbook/references/docs-layout.md
   ```
   Expect each edited file's new text to keep per-slice history in `progress.md`,
   not `CLAUDE.md`.

3. **Managed-project `CLAUDE.md` framed as a curated digest in init guidance:**

   ```
   rg -n -i "curated digest" \
     plugins/loom/skills/loom-playbook/references/greenfield.md \
     plugins/loom/skills/loom-playbook/references/docs-layout.md
   ```
   Expect both to describe the project `CLAUDE.md` as a curated digest kept current
   by the finalize pass, pointing to spec 08.

4. **Single-source guard — the four-category boundary is NOT re-pasted across
   files.** Spec 08 is the only place that enumerates all four categories as a list.
   Confirm no reference/agent file restates the full four-category list:

   ```
   rg -n -i "durable convention" plugins/loom/agents plugins/loom/skills plugins/loom/commands
   ```
   Expect matches only where the four are named **tersely as a trigger condition**
   (the developer agent's finalize step, parallel to spec 03 step 2) — NOT a second
   copy of spec 08's full four-sub-bullet definition. The reference docs
   (status-machine / parallelism / greenfield / docs-layout) must contain a
   **pointer to spec 08**, not the enumerated list. Manually confirm each match is a
   pointer or a one-line trigger, not a boundary restatement.

5. **Spec-pointer present in every edited reference file:**

   ```
   rg -n "08-playbook\.md" \
     plugins/loom/skills/loom-playbook/references/status-machine.md \
     plugins/loom/skills/loom-playbook/references/parallelism.md \
     plugins/loom/skills/loom-playbook/references/greenfield.md \
     plugins/loom/skills/loom-playbook/references/docs-layout.md
   ```
   Expect each to point to spec 08. (developer.md may use the prose "spec 08"
   convention — verify per its existing style.)

6. **Scope guard — NO frozen-artifact edits.** Specs 03/08 and all ADRs are
   frozen-Approved; this slice must not touch them:

   ```
   git diff --name-only HEAD | rg "^\.docs/(spec|ADR)/" && echo "VIOLATION" || echo "scope OK"
   ```
   Expect `scope OK` (no match). The only `.docs/` paths in the diff are this plan
   file and `slice-plans/README.md` (the Active entry).

7. **Untouched-finalize guard.** Confirm the four incidental files are unchanged:

   ```
   git diff --name-only HEAD | rg "commands/run\.md|commands/eval-code\.md|agents/code-evaluator\.md|agents/planner\.md" \
     && echo "unexpected edit" || echo "incidental finalize refs untouched"
   ```
   Expect `incidental finalize refs untouched`.

The regression proof for this doc-only slice is the scope guard (checks 6–7): the
frozen specs/ADRs and the incidental finalize references are provably unchanged,
while checks 1–5 prove the new conformance text is present and single-sourced.

## Notes

- **Known non-blocking MINOR, deliberately NOT fixed here:** spec 08's `CLAUDE.md`
  template bullet (the "What the playbook contains" list, line ~40–41) lacks a
  forward-link to the new "`CLAUDE.md` auto-propagation" subsection. spec 08 is a
  frozen-Approved artifact (ADR 0005); adding that forward-link would be a spec edit
  and is therefore out of scope for this playbook-conformance slice. It would need
  its own planning cycle / spec amendment. Left intentionally.
- This slice is **doc/markdown only** — no executable code, no compiled gate in
  loom's own repo. The "gate" is review-against-spec, mechanized by the `rg` /
  `git diff` checks in Verification.
- All five edited files point to spec 08 (single source) rather than restating the
  four-category boundary; the developer agent may name the categories tersely as the
  finalize trigger condition (mirroring spec 03 step 2), which is the trigger, not a
  boundary restatement — the single-source check (Verification 4) guards this line.

## Verification results (gate evidence)

Check 1 (developer.md finalize includes CLAUDE.md step + spec 08 pointer): PASS
  - `rg -n -i "CLAUDE\.md" plugins/loom/agents/developer.md` → finalize step 2
    at lines 52-61 includes the CLAUDE.md update rule with spec 08 pointer.
  - `rg -n -i "curated[- ]digest|08-playbook|spec 08" plugins/loom/agents/developer.md`
    → "curated-digest scope" (line 53) + "spec 08" (line 60): present.
  - Archive/commit steps renumbered to 3 and 4: confirmed.

Check 2 (per-slice-history exclusion in all five edited files): PASS
  - All five files contain "per-slice history stays in progress.md" or equivalent.

Check 3 (managed-project CLAUDE.md framed as curated digest): PASS
  - greenfield.md line 89: "This `CLAUDE.md` is a **curated digest**"
  - docs-layout.md line 32: "Both root- and project-level `CLAUDE.md` are **curated digests**"

Check 4 (single-source guard — "durable convention" only in spec 08 and developer.md trigger): PASS
  - `grep -rn "durable convention" plugins/loom/` → no matches in reference docs
    (parallelism/status-machine/greenfield/docs-layout all use pointer-only).
  - developer.md line 53: "durable convention" as the one-line trigger condition only.
  - spec 08 line 83: "Durable conventions" — the authoritative four-sub-bullet definition.

Check 5 (spec 08 pointer in all four reference files): PASS
  - status-machine.md line 65, parallelism.md line 151, greenfield.md line 92,
    docs-layout.md line 34 — all point to `../../../../../.docs/spec/08-playbook.md`.
  - developer.md uses prose "spec 08" reference consistent with the file's convention.

Check 6 (scope guard — no spec/ADR edits): PASS
  - `git diff --name-only HEAD | grep "^\.docs/(spec|ADR)/"` → scope OK (no match)
  - Only `.docs/` path in diff: this plan file. All five implementation edits are
    in `plugins/loom/`.

Check 7 (incidental finalize refs untouched): PASS
  - `git diff --name-only HEAD | grep ...` → "incidental finalize refs untouched"
  - run.md, eval-code.md, code-evaluator.md, planner.md unchanged.

Diff name-only: 5 implementation files + 1 plan file (status changes + evidence).
No spec/ADR files in diff. Parallelism.md wording keeps CLAUDE.md update in the
orchestrator's serialized finalize-on-main, not attributed to the developer under
parallelism (per Minor 1 from plan review). Developer.md uses "spec 08" prose
reference consistent with the file's existing style (per Minor 2 from plan review).
