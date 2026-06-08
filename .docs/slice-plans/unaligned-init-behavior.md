# Unaligned Init Behavior — the align-an-existing-project body

Status: Plan Review
Target specs: 06-init-modes.md, 08-playbook.md, 04-orchestrator.md

## Context

M2 is "init modes & gate learning." The **detection** classifier landed (slice
`init-mode-detection`, commit 5fef2ed): `init-detection.md` returns Greenfield /
Unaligned / Initialized and is read-only — acting on the mode is the caller's job.
The **Greenfield** behavior body then landed (slice `greenfield-init-behavior`,
commit a58ff7e) as the single authoritative scaffold/seed/CLAUDE.md/gate body in
`plugins/loom/skills/loom-playbook/references/greenfield.md`, with the call sites
(`run.md`, `init.md`, `orchestration.md`) repointed at it.

This slice writes the **second** per-mode behavior body: **Unaligned**. Per
`init-detection.md`, Unaligned is returned when `.docs/` is absent (or present but
not loom-shaped) in an **existing / non-empty** repo. Spec `06-init-modes.md §2`
defines Unaligned as an **alignment/migration pass**, not a config interview: study
the repo, scaffold + apply the playbook, establish the gate, and **descriptively
back-fill** `spec/` — then leave the project loom-shaped and ready to resume as
Initialized.

Today Unaligned exists only as forward-pointing prose at the call sites:

- `plugins/loom/commands/init.md` step 2 — "Unaligned: scaffold per `greenfield.md`
  **plus** descriptive back-fill … forward pointer to the forthcoming M2 slice
  *unaligned-init-behavior*; do not author the back-fill body here."
- `plugins/loom/commands/run.md` step 1 — "unaligned → alignment pass" (terse).
- `plugins/loom/skills/loom-playbook/references/orchestration.md` *Init-mode
  detection* — "Unaligned → behavior body forthcoming (follow-up M2 slice
  *unaligned-init-behavior*) …". This is the dangling pointer this slice resolves.

**This slice writes the Unaligned behavior body** as one authoritative playbook
reference (`references/unaligned.md`), mirroring exactly how Greenfield was
single-sourced and how its call sites were repointed, then repoints the three call
sites at it. Crucially, Unaligned **reuses** the Greenfield body for the shared
scaffold/seed/CLAUDE.md/gate primitives — it does **not** restate them (single-source
discipline). `unaligned.md` references `greenfield.md` and then describes only the
**Unaligned delta**: the study-the-repo step, the descriptive `spec/` back-fill
rules and the no-decisions boundary, and the "ready to resume as Initialized"
handoff.

### Why a reference file (mirror the Greenfield pattern)

The detection and Greenfield slices established the pattern: behavior the command
surface invokes lives in `references/`, single-sourced; `commands/` +
`orchestration.md` point at it rather than restating it. Unaligned is invoked from
the same two call sites (`run.md` step 1, `init.md` step 2) and the
`orchestration.md` Init-mode section, and it layers on the Greenfield body, so it
must be its own single-sourced reference. Inlining it would recreate the divergence
the earlier slices removed.

### Out of scope (explicit non-goals — deferred follow-up slices)

Named here so nothing is lost; each is its own later M2 slice:

- **Initialized resume menu** (spec `06 §3`): derive a menu from `.docs/` + git
  state and continue. Deferred — *follow-up slice "initialized-init-behavior"*.
  Leave its call-site pointers untouched.
- **Gate-learning for unknown stacks** (spec `06` *Gate establishment*, 2nd bullet):
  inspecting tooling, proposing commands, confirming with the owner, running green
  once, and recording a new `gates/<stack>.md` back into the playbook. Unaligned
  **reuses** Greenfield's Step E gate establishment, which already wires the
  Rust-verified path and **references** the learn-a-new-gate procedure as deferred.
  This slice does **not** author the learn-and-record mechanism — it points at the
  forthcoming *gate-learning* slice, same as Greenfield. Deferred.
- **Idempotent playbook re-application** (spec `06` last section): auto-apply clean
  merges, recommend for conflicts. The Greenfield idempotence note already covers
  the safety invariant; the full re-application machinery folds into
  *"initialized-init-behavior"*. This slice does not implement it.
- Authoring real **ADRs** or **proposed changes** during back-fill — spec `06 §2`
  forbids decisions in the alignment pass; back-fill is descriptive only and
  requires a later real planning phase. This boundary is a content requirement of
  `unaligned.md` (Step 1), not something this slice produces.
- Any change to `.docs/spec/` or `.docs/ADR/` — frozen/immutable; this slice works
  within spec `06`.
- Any change to the canonical tree in `docs-layout.md` or to `greenfield.md`'s
  scaffold steps — those are sources this body points *at*, not files this slice
  edits.

## Steps

1. **Create `plugins/loom/skills/loom-playbook/references/unaligned.md`** — the
   single authoritative Unaligned behavior body. The author must keep every step and
   ordering consistent with spec `06-init-modes.md §2`, and must **reference**
   `greenfield.md` for the shared scaffold/seed/CLAUDE.md/gate work rather than
   restating it (single-source discipline — no divergent re-listing of the tree or
   the Step A–F bodies). Required content:

   - **Header + authority line.** `# Unaligned Init` and a one-line purpose: "The
     behavior the orchestrator runs when `init-detection.md` returns **Unaligned**
     — an existing / non-empty repo whose `.docs/` is absent or not loom-shaped." State
     the authority is `.docs/spec/06-init-modes.md §2` (use the same relative path
     style Greenfield uses: `../../../../../.docs/spec/06-init-modes.md`) and "spec
     `06` wins on any conflict." Note the precondition: detection already classified
     Unaligned; this body **writes** files (unlike read-only detection). State up
     front that Unaligned = an **alignment/migration pass**, not a config interview
     (spec `06 §2`).

   - **Step 1 — Study the repo (Unaligned-specific, runs first).** Before scaffolding,
     inspect the existing project read-only: languages, build/test/lint tooling
     (config files, scripts, CI), existing docs, and directory structure (spec `06 §2`
     first bullet). This survey feeds two later steps: gate detection (which
     toolchain → which gate) and the descriptive back-fill (what specs to map). State
     this is a *survey*, producing notes/understanding — it does not yet write project
     files.

   - **Step 2 — Scaffold + apply the playbook + establish the gate (REUSE
     Greenfield).** Run the Greenfield body in
     [`greenfield.md`](greenfield.md) for the shared work: scaffold the `.docs/`
     tree, seed `spec/README.md` and `status/`, write/update the project `CLAUDE.md`,
     and establish the gate (Steps A–E of `greenfield.md`). Reference it; do **not**
     restate those steps. Then call out the Unaligned **deltas** to that shared body:
     - **Existing files are common, not the exception.** Unaligned runs in a populated
       repo, so a pre-existing `CLAUDE.md` and existing docs are expected; honor
       Greenfield's "update, never clobber" rule for `CLAUDE.md` (Greenfield Step D),
       and never overwrite existing project content while scaffolding.
     - **Gate detection uses the Step 1 survey.** Feed the toolchain found in Step 1
       into Greenfield's Step E: a verified Rust toolchain (`Cargo.toml` at
       repo/workspace root) adopts the verified gate in [`../gates/rust.md`](../gates/rust.md);
       an unknown stack takes the **learn-a-new-gate** path, which is a **deferred**
       slice — record the proposed commands in `CLAUDE.md` marked unverified and
       point at the forthcoming *gate-learning* slice (spec `06` Gate establishment,
       2nd bullet). Do **not** implement gate-learning here — reference it exactly as
       `greenfield.md` does.
     - **Status seeds reflect alignment, not greenfield.** Where `greenfield.md`
       seeds `progress.md` with "Phase: init / Greenfield scaffold complete," the
       Unaligned pass seeds with an alignment-phase marker (e.g. "Phase: init /
       Unaligned alignment in progress") — see Step 4 for the full status seed.

   - **Step 3 — Descriptive back-fill of `spec/`.** This is the heart of the Unaligned
     delta (spec `06 §2`, "Descriptive back-fill only"). Draft initial `spec/` bodies
     that **describe what the project currently is** — a map of the existing system so
     future loops have authoritative context. The body must make these rules explicit:
     - **What to map.** Use the Step 1 survey to draft specs describing the system as
       it exists: its components/modules, how it is built/tested/run, its existing
       conventions and structure. State that these specs are *descriptive* — a
       snapshot of current reality.
     - **No-decisions boundary (hard rule).** Back-fill makes **no decisions and
       proposes no changes**. It records what *is*, never what *should be*. Any new
       decision, ADR, or proposed change requires a **real planning phase** (the
       normal owner-driven research → ADR → spec loop), not the alignment pass. State
       this boundary in the body verbatim in intent: no ADRs are authored during
       back-fill; no spec text prescribes a change.
     - **Back-filled specs still follow the normal lifecycle.** Each back-filled spec
       is authored at `Status: Draft` and passes through the normal
       `Draft → Plan Review → Approved` flow (spec `06 §2`; lifecycle per
       [`../../../../../.docs/spec/03-artifact-lifecycle.md`](../../../../../.docs/spec/03-artifact-lifecycle.md)).
       Back-fill does not get to skip evaluation. State that as the orchestrator drives
       this, the planner authors the descriptive specs and the plan evaluator reviews
       them blind, exactly like any other spec.
     - **`spec/README.md` reading order.** After back-fill, populate the
       `spec/README.md` reading order (which Greenfield seeded empty) with the
       back-filled specs in a sensible reading order, so future loops have an entry
       map. Non-negotiables stay empty (none are decided in an alignment pass).

   - **Step 4 — Seed `status/` with current state + initial roadmap.** Beyond
     Greenfield's status seeds, the Unaligned pass records the *actual* current state
     of the surveyed project:
     - `progress.md` — alignment-phase marker plus a decision index that points at the
       back-filled descriptive specs (no decisions recorded, since back-fill makes
       none).
     - `roadmap.md` — an **initial roadmap** seeded from the survey: the milestones
       implied by the project's current state, framed so the owner can refine them.
       (Spec `06 §2`: "Seed `status/` with current state and an initial roadmap.")
     - `handoff.md` — "start here each session" pointing at `spec/README.md` and
       `progress.md`, with the immediate next step being to resume as **Initialized**
       (declare scope with the owner and run `/loom:run`).

   - **Step 5 — Hand back: ready to resume as Initialized.** State the goal (spec
     `06 §2`): the project is now loom-shaped — `.docs/` scaffolded, gate established,
     `spec/` descriptively back-filled and passing through approval, `status/`
     seeded — so the **next** loom run detects it as **Initialized** (its `.docs/` is
     now loom-shaped per `init-detection.md`) and resumes from the menu. The commit(s)
     are author-neutral per [`commit-convention.md`](commit-convention.md). Note that
     Unaligned's design output is **only the descriptive back-fill** — it authors no
     ADRs and no decision-bearing specs (that begins as a real planning phase once
     Initialized).

   - **Idempotence note (one line).** Re-running Unaligned re-applies the current
     playbook; it never clobbers existing project content (auto-apply clean merges,
     recommend for conflicts — spec `06` Playbook re-application). Full idempotent
     re-application is the Initialized slice; this is just the safety note, mirroring
     Greenfield's idempotence note.

2. **Repoint `orchestration.md` at the new body.** In
   `plugins/loom/skills/loom-playbook/references/orchestration.md`, *Init-mode
   detection* section, the **Unaligned** bullet (currently "behavior body
   forthcoming … *unaligned-init-behavior* …"): change it to link the body, e.g.
   "Unaligned → [`unaligned.md`](unaligned.md) — alignment pass: study the repo,
   scaffold + gate (per `greenfield.md`), descriptive `spec/` back-fill, resume as
   Initialized." Leave the **Initialized** bullet as its forthcoming-slice pointer
   unchanged. Do not restate the Unaligned steps here — the reference owns them.

3. **Repoint `commands/run.md` step 1.** Change the Unaligned branch from "unaligned →
   alignment pass" to point at the body: "unaligned → alignment pass per
   `${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/references/unaligned.md`" (mirroring
   the Greenfield branch's `${CLAUDE_PLUGIN_ROOT}` reference style). Leave the
   Initialized branch terse/unchanged, and leave steps 2–4 (scope/gates, driver
   loop, break) intact.

4. **Repoint `commands/init.md` step 2.** The current step 2 has the Greenfield path
   pointing at `greenfield.md` and the Unaligned path as a forward pointer. Replace
   the Unaligned forward pointer with a reference to the body: "**Unaligned:** run the
   alignment body in
   `${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/references/unaligned.md` — study the
   repo, scaffold + gate (per `greenfield.md`), descriptively back-fill `spec/` (no
   decisions), seed `status/`; leaves the repo ready to resume as Initialized. Commit
   author-neutral." Leave the Greenfield path (step 2) unchanged, leave step 3
   (Initialized) as its forward pointer, and leave steps 1 and 4 unchanged.

5. **Add `unaligned.md` to the playbook skill index.** In
   `plugins/loom/skills/loom-playbook/SKILL.md`, the References (`references/`) list,
   add a bullet: "`unaligned.md` — the Unaligned init behavior body (alignment pass:
   reuse Greenfield scaffold + gate, then descriptive `spec/` back-fill)." Place it
   immediately **after** the `greenfield.md` bullet.

6. **Update root `CLAUDE.md` "Repo layout (M2 in progress)" section.** Add a short
   line noting the Unaligned behavior body now lives in `references/unaligned.md`
   (paralleling the existing `init-detection.md` and `greenfield.md` lines), and
   adjust the trailing "Unaligned and Initialized bodies are forthcoming M2 slices"
   note on the Greenfield line to read that only the **Initialized** body remains
   forthcoming. Per the user's workflow rule, keep `CLAUDE.md` current when
   committing. (Do not touch `.docs/spec/` or `.docs/ADR/`.)

## Verification

loom is markdown; **there is no compiled gate on loom's own repo** (root
`CLAUDE.md`: "This repo has no compiled code yet, so it has no concrete gate to
run"). Acceptance is by **review against the specs**, not format/lint/test. Per the
mechanical-check discipline (`references/tooling.md`), the single-source and link
claims below are checked with `rg`/grep, not by eye. The blind plan/code evaluator
confirms:

- **Spec fidelity (06 §2) — every obligation maps to a step.** Each `06 §2`
  obligation appears as a concrete step in `unaligned.md`:
  - "Study the repo" → **Step 1**.
  - "Create `.docs/` and apply the playbook" + "Establish the gate" → **Step 2**
    (reuses `greenfield.md`).
  - "Descriptive back-fill only … does **not** make decisions … back-filled specs
    still pass through `Draft → Plan Review → Approved`" → **Step 3**.
  - "Seed `status/` with current state and an initial roadmap" → **Step 4**.
  - "leave the project loom-shaped and ready to resume as Initialized" → **Step 5**.
  No new behavior or decision beyond spec `06` is introduced.
- **No-decisions boundary explicit.** Step 3 states verbatim-in-intent that back-fill
  records what *is*, never what *should be*; authors **no ADRs** and **no
  decision-bearing spec text**; and that any decision/change requires a real planning
  phase. The boundary is unmissable, not implied.
- **Back-fill lifecycle correct.** Step 3 states back-filled specs are authored
  `Status: Draft` and pass through `Draft → Plan Review → Approved` (no skipping
  evaluation), cross-linking spec `03-artifact-lifecycle.md`.
- **Greenfield reuse is by reference (single-source, no divergent restatement).**
  `unaligned.md` references `greenfield.md` for the scaffold/seed/CLAUDE.md/gate work
  and does **not** restate the `.docs/` tree or the Step A–F bodies. Mechanical check:
  `rg -n "research/README|ADR/README|cargo fmt --check|cargo clippy" plugins/loom/skills/loom-playbook/references/unaligned.md`
  returns **nothing** (those concrete scaffold/gate details live only in
  `greenfield.md`/`gates/rust.md`); and
  `rg -n "greenfield.md" plugins/loom/skills/loom-playbook/references/unaligned.md`
  shows `unaligned.md` pointing at the Greenfield body for the shared work.
- **Gate-learning correctly deferred.** Step 2's gate delta reuses Greenfield's Step E
  (Rust verified path + reference to the learn-a-new-gate procedure) and does **not**
  author the inspect/propose/confirm/learn-and-record mechanism. Mechanical check:
  `rg -n "gate-learning" plugins/loom/skills/loom-playbook/references/unaligned.md`
  shows it referenced as forthcoming, not implemented.
- **Initialized untouched (forward pointer only).** `orchestration.md`'s Initialized
  bullet, `init.md` step 3, and `run.md`'s Initialized branch remain forward
  pointers — Unaligned does not flesh out Initialized.
- **Steps are concrete, ordered, single-purpose.** An independent agent following
  `unaligned.md` top to bottom runs the same alignment pass every time: survey →
  scaffold/gate (reuse) → descriptive back-fill → seed status → hand back. No
  ambiguous ordering.
- **Single source of truth at the call sites.** The Unaligned *behavior* lives only
  in `unaligned.md`; `run.md`, `init.md`, and `orchestration.md` reference it. Check:
  `rg -n "unaligned" plugins/loom/commands plugins/loom/skills/loom-playbook/references`
  shows the call sites pointing at `unaligned.md`, with the step bodies only in
  `unaligned.md`.
- **No spec/ADR edits.** `git diff --name-only` touches only
  `plugins/loom/skills/loom-playbook/references/unaligned.md`,
  `.../references/orchestration.md`, `plugins/loom/commands/run.md`,
  `plugins/loom/commands/init.md`, `plugins/loom/skills/loom-playbook/SKILL.md`,
  `CLAUDE.md`, and `.docs/slice-plans/`. Mechanical check:
  `git diff --name-only HEAD | rg "spec/|ADR/"` returns empty.
- **Links resolve.** Every relative / `${CLAUDE_PLUGIN_ROOT}` path added points at a
  real file: `greenfield.md`, `../gates/rust.md`, `commit-convention.md`, the spec
  path `../../../../../.docs/spec/06-init-modes.md`, the lifecycle path
  `../../../../../.docs/spec/03-artifact-lifecycle.md`, and `unaligned.md` from each
  call site — each confirmed present in the tree before relying on it.

Regression guard: the repointed call sites keep their surrounding behavior intact —
`run.md` still drives the full loop (steps 2–4 unchanged) and keeps Greenfield/
Initialized branches, `init.md` keeps the Greenfield path (step 2) and Initialized
(step 3) and reports (step 4) intact, and `orchestration.md` keeps its
Greenfield bullet, the idempotent-re-application sentence, and the Initialized
forward pointer. Only the Unaligned wiring changes.

## Notes

<Clarification requests between roles, dated. A role asks here and sets status to
Needs Clarification; the answering role replies here and the status is restored.
Resolutions are marked, not deleted. (Formal verdicts live in evaluations/, not
here.)>
