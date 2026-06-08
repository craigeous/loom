# Initialized init behavior body

Status: Approved
Target specs: 06-init-modes.md

## Context

This is the **third and final per-mode init behavior body** (M2). The Greenfield
and Unaligned bodies already exist as single-sourced references
(`plugins/loom/skills/loom-playbook/references/greenfield.md`,
`.../references/unaligned.md`), each repointed from `orchestration.md`,
`commands/run.md`, `commands/init.md`, listed in `SKILL.md` References, and noted
in root `CLAUDE.md`. The init-mode classifier
(`.../references/init-detection.md`) already returns **Initialized** when a
loom-shaped `.docs/` is present.

**Initialized is still a forward pointer.** Today the behavior lives only as
terse, divergent restatements at the call sites:

- `orchestration.md` Init-mode section, Initialized bullet (lines 47–49): "behavior
  body forthcoming (follow-up M2 slice *initialized-init-behavior*): derive menu
  from `.docs/` + git state and continue."
- `orchestration.md` lines 51–52 already carry the idempotent re-application
  one-liner: "Re-alignment is idempotent: auto-apply clean merges, **recommend**
  for conflicts and let the owner decide. Never clobber project edits."
- `commands/run.md` Step 1 (line 24): "initialized → summarize current state and
  continue."
- `commands/init.md` Step 3 (lines 23–25): "Initialized: re-apply the current
  playbook idempotently — auto-apply clean merges, recommend for conflicts and let
  the owner decide. Never clobber project edits."
- `init-detection.md`'s dispatch table (line 91) already points Initialized at
  spec `06 §3` and notes "Behavior bodies are detailed in `06-init-modes.md` and
  the relevant M2 slice." — this is fine as-is (the classifier only classifies);
  no edit needed there.

This slice writes the single authoritative Initialized body and repoints the call
sites at it (single-source, no duplication), exactly mirroring how
`greenfield.md` / `unaligned.md` were landed.

**What Initialized must do** (authority: `.docs/spec/06-init-modes.md` §3 +
"Playbook re-application (idempotent)", Q10):

1. **Resume.** Present the owner a menu **derived from real `.docs/` + git
   state** (not a static list): continue an in-flight slice-plan, review pending
   research/ADRs/specs, start a new slice from the roadmap, run research on a
   topic, show status. The menu items must map to actual artifact statuses via the
   dispatch table in
   `plugins/loom/skills/loom-playbook/references/status-machine.md`. The owner then
   declares scope + claimed gates and the **driver loop** runs — that loop is
   `/loom:run` Step 3 (`commands/run.md`); the body references it, it does not
   restate it.

2. **Idempotent playbook re-application** (Q10 merge strategy): re-running init on
   a loom-shaped repo re-applies the **current** playbook, picking up improvements
   since the last init. Auto-apply changes that merge cleanly and don't conflict
   with project-specific content; for conflicts/ambiguity, **recommend** and let
   the owner decide; **never clobber** project-specific edits. This must
   **reconcile** with the idempotent one-liner already in `orchestration.md`
   (lines 51–52): the body owns the detail; `orchestration.md` points at the body
   instead of restating, to keep single-source.

**Out of scope (do not implement):**

- **Gate-learning** stays a forward pointer (deferred *gate-learning* slice, per
  spec `06` Gate establishment 2nd bullet, as in `greenfield.md` Step E /
  `unaligned.md` Step 2). The Initialized body does not establish or learn a gate
  on its own; re-application that touches the gate follows the never-clobber merge
  rule and otherwise defers to the gate-learning slice.
- **No edits to `.docs/spec/` or `.docs/ADR/`** (specs frozen, ADRs immutable).
- **Do not restate** the dispatch table, the `/loom:run` driver loop, or the
  scaffold mechanics — reference the single sources.
- **No claim that M2 is fully done** — gate-learning remains after this slice.

## Steps

### Step 1 — Author `references/initialized.md` (the new single authoritative body)

Create `plugins/loom/skills/loom-playbook/references/initialized.md`, mirroring the
header shape and tone of `greenfield.md` / `unaligned.md` (intro paragraph →
Authority line → Precondition → numbered/lettered steps → Idempotence note).

Required content, section by section:

1. **Header + Authority + Precondition** (mirror `greenfield.md` lines 1–11):
   - One-paragraph intro: "The behavior the orchestrator runs when
     `init-detection.md` returns **Initialized** — a repo whose `.docs/` is already
     loom-shaped." Note Initialized is **Resume**, not scaffold (spec `06 §3`).
   - Authority line linking spec 06 §3 with the same relative path the siblings
     use: `[`../../../../../.docs/spec/06-init-modes.md`](../../../../../.docs/spec/06-init-modes.md) §3`,
     and "Spec `06-init-modes.md` wins on any conflict."
   - Precondition: `init-detection.md` has already classified this repo as
     Initialized. Unlike Greenfield/Unaligned, the **resume** half writes nothing
     until the owner picks an action and the driver loop runs; the **idempotent
     re-application** half may write playbook-derived changes under the merge rules
     in the dedicated section below.

2. **Step 1 — Build the state-derived resume menu.** This is the heart of the
   Resume behavior (spec `06 §3`). The menu is **derived from real `.docs/` + git
   state**, not hardcoded:
   - Scan `.docs/` artifact `Status:` lines and git (same inputs the driver loop
     uses), then cross-reference the dispatch table in
     [`status-machine.md`](status-machine.md) so each offered menu item maps to a
     real status / next-actor.
   - Enumerate the menu items from spec `06 §3`, each tied to the status(es) that
     make it appear (so the menu reflects actual state):
     - **Continue an in-flight slice-plan** — when a slice-plan is at
       `Plan Review`, `In Progress`, or `Implemented` (per spec `06 §3`; these map
       to plan evaluator / developer / code evaluator in the dispatch table).
     - **Review pending research / ADRs / specs** — when artifacts sit at
       `Research Review` or `Plan Review` (→ plan evaluator).
     - **Start a new slice from the roadmap** — from `status/roadmap.md` when no
       in-flight slice blocks it.
     - **Run research on a topic** — owner-initiated; seeds a `Draft` research
       note.
     - **Show status** — summarize current `.docs/` + git state.
   - State the hard rule explicitly: **the menu is derived from actual current
     statuses, never a static list divorced from real state.** If no actionable
     artifacts exist, the menu still offers "start a new slice from the roadmap" /
     "run research" / "show status."
   - Also surface `Needs Clarification` and round-limit/escalation states if
     present, since those are real states the dispatch table recognizes (link the
     dispatch table; do not restate it).

3. **Step 2 — Hand off into scope + claimed gates + the driver loop.** After the
   owner picks a menu item:
   - The owner declares **scope + claimed gates** (point at
     [`orchestration.md`](orchestration.md) "Scope & claimed gates"; do not
     restate the scope vocabulary).
   - The **driver loop** then runs. Reference `/loom:run` Step 3 as the single
     source: link `[`../../../commands/run.md`](../../../commands/run.md)` (verify
     this relative path resolves from `references/` — adjust to the correct number
     of `../` so it points at `plugins/loom/commands/run.md`) and state that the
     body does **not** restate the loop — `run.md` Step 3 is authoritative. The
     menu choice simply tells the loop where to start.
   - Make explicit: Initialized's Resume half **writes no files itself**; it routes
     the owner into the existing loop, which drives the roles (each role commits
     its own work author-neutral).

4. **Step 3 — Idempotent playbook re-application (Q10 merge strategy).** This is
   the section that `orchestration.md`'s existing idempotent one-liner will point
   at. Author the full detail here:
   - Re-running init on a loom-shaped repo re-applies the **current** playbook,
     picking up improvements since the last init (spec `06`, "Playbook
     re-application (idempotent)").
   - **Auto-apply** changes that merge cleanly and don't conflict with
     project-specific content.
   - For anything that **conflicts or is ambiguous**, **recommend** an action and
     let the **owner decide** — never silently clobber project-specific edits.
   - Note the relationship to the Greenfield/Unaligned "idempotence note" stubs:
     those carry only the per-mode safety invariant and explicitly defer "full
     idempotent re-application" to **this** body; `initialized.md` is now that full
     statement.
   - Re-application that would touch the **gate** still defers gate *learning* to
     the deferred gate-learning slice — re-application only re-applies what the
     current playbook already knows, under the never-clobber rule.

5. **Idempotence / scope-boundary note** (mirror the siblings' closing note):
   - State plainly that **gate-learning is out of scope** here and remains a
     forward pointer (deferred *gate-learning* slice), so an evaluator doesn't read
     re-application as having absorbed gate-learning.

Verify every relative link in the new file resolves against the real tree before
finishing (see Verification).

### Step 2 — Repoint `orchestration.md` (Init-mode section, single-source the idempotent lines)

In `plugins/loom/skills/loom-playbook/references/orchestration.md`:

- Replace the **Initialized bullet** (current lines 47–49, the "behavior body
  forthcoming…" forward pointer) with a link to the new body, in the same shape as
  the Greenfield/Unaligned bullets above it (lines 42–46):
  - e.g. **Initialized** → [`initialized.md`](initialized.md) — resume: derive the
    menu from `.docs/` + git state (mapped to the dispatch table), then declare
    scope + gates and run the driver loop; re-apply the current playbook
    idempotently.
- **Reconcile the existing idempotent one-liner** (current lines 51–52). Do **not**
  delete the concept, but stop restating the merge strategy inline — repoint it at
  the body to keep single-source. Replace lines 51–52 with a one-line pointer, e.g.:
  "Re-running init re-applies the current playbook idempotently — see
  [`initialized.md`](initialized.md) for the merge strategy (auto-apply clean,
  recommend for conflicts, never clobber)." Keep it to a pointer, not a restated
  rule, so `initialized.md` is the single owner of the detail.

### Step 3 — Repoint `commands/run.md` Step 1 (Initialized branch)

In `plugins/loom/commands/run.md` Step 1 (line 24), replace the terse "initialized
→ summarize current state and continue" with a link to the new body, mirroring how
greenfield/unaligned are linked in the same sentence (lines 21–23):

- "initialized → resume per
  `${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/references/initialized.md` (derive
  menu from `.docs/` + git state, then scope/gates + driver loop)."

Use the `${CLAUDE_PLUGIN_ROOT}/…` path form the sibling links use, **not** a
relative path (run.md is a command, not a reference). Leave Steps 2–4 of run.md
unchanged — the driver loop (Step 3) stays the single source the body references.

### Step 4 — Repoint `commands/init.md` Step 3 (Initialized path)

In `plugins/loom/commands/init.md` Step 3 (lines 23–25), replace the inline
restatement of the idempotent merge strategy with a link to the new body, in the
same shape as the Greenfield/Unaligned entries in Step 2 (lines 15–22):

- "**Initialized:** resume per
  `${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/references/initialized.md` — present
  the state-derived menu, then re-apply the current playbook idempotently
  (auto-apply clean merges, recommend for conflicts, never clobber). Commit
  author-neutral if re-application writes anything."

Keep the merge-strategy detail in the body; init.md gets a pointer + the one-line
summary, matching how Greenfield/Unaligned are summarized-then-linked there.

### Step 5 — Add `initialized.md` to `SKILL.md` References list

In `plugins/loom/skills/loom-playbook/SKILL.md`, in the `References (`references/`)`
list, add a bullet **immediately after** the `unaligned.md` line (line 53),
mirroring its one-line shape:

- `initialized.md` — the Initialized init behavior body (resume: state-derived menu
  mapped to the dispatch table → scope/gates + driver loop; idempotent playbook
  re-application).

### Step 6 — Update root `CLAUDE.md` "Repo layout (M2 in progress)"

In `/Users/craig/git/loom/CLAUDE.md`, the "Repo layout (M2 in progress)" section:

- Add an **Initialized behavior body** bullet after the Unaligned bullet (which
  currently ends "The Initialized body is a forthcoming M2 slice."), mirroring the
  Greenfield/Unaligned bullet shape:
  - **Initialized behavior body** (M2): `plugins/loom/skills/loom-playbook/references/initialized.md`
    is the single authoritative body for Initialized init (resume: derive a menu
    from `.docs/` + git state, hand into scope/gates + the `/loom:run` driver loop;
    idempotent playbook re-application — auto-apply clean, recommend for conflicts,
    never clobber).
- **Edit the Unaligned bullet** to remove the now-false trailing sentence "The
  Initialized body is a forthcoming M2 slice." (it has now landed).
- You **may** note the per-mode trio (Greenfield + Unaligned + Initialized bodies)
  all exist now. **Do NOT** claim M2 is fully done — gate-learning remains a
  forward pointer. The heading stays "Repo layout (M2 in progress)".

### Step 7 — Update the slice-plans README active index

In `.docs/slice-plans/README.md`, under **Active plans** (currently "None."), add
this plan as an active entry mirroring the existing entry shape:

- `[initialized-init-behavior.md](initialized-init-behavior.md)` — `Plan Review` —
  Initialized init behavior body: resume from a state-derived menu (mapped to the
  dispatch table) into scope/gates + the driver loop, plus idempotent playbook
  re-application (final M2 per-mode body).

(On landing, the finalize step moves this to Archived with the landing hash, as the
siblings show.)

## Verification

No compiled gate — loom is markdown. Verification is **review-against-spec, done
mechanically** (`rg`/`grep`, dogfooding the rule). Each check below maps an
obligation to a concrete mechanical test:

1. **New body exists and is single-authoritative.**
   `test -f plugins/loom/skills/loom-playbook/references/initialized.md` — present.

2. **Every spec-06 §3 obligation maps to a concrete step in the body.** Confirm
   `initialized.md` covers: state-derived resume menu, the five menu items
   (continue in-flight slice-plan, review pending research/ADRs/specs, start new
   slice from roadmap, run research, show status), the scope+gates+driver-loop
   handoff, and the Q10 idempotent merge strategy. `rg -i "Plan Review|In
   Progress|Implemented|Research Review|roadmap|show status"
   plugins/loom/skills/loom-playbook/references/initialized.md` returns hits for
   each menu item's status mapping.

3. **Menu is state-derived (references the dispatch table), not a hardcoded list.**
   `rg -i "status-machine|dispatch table"
   plugins/loom/skills/loom-playbook/references/initialized.md` returns a link to
   `status-machine.md`. The body must state the menu derives from real statuses.

4. **Driver-loop handoff references run.md (no divergent restatement).**
   `rg -i "run\.md|driver loop"
   plugins/loom/skills/loom-playbook/references/initialized.md` shows the body
   points at `run.md` Step 3 and does **not** restate the loop's a–g sub-steps.

5. **Idempotent rules reconciled with orchestration.md (single-source, no
   duplication).** `rg -i "initialized\.md"
   plugins/loom/skills/loom-playbook/references/orchestration.md` shows the
   Initialized bullet AND the former idempotent one-liner both now point at
   `initialized.md`; the inline restatement of the full merge strategy is gone
   (the one-liner is a pointer, not a restated rule).

6. **All call sites repointed.**
   `rg -l "initialized\.md" plugins/loom/skills/loom-playbook/references/orchestration.md
   plugins/loom/commands/run.md plugins/loom/commands/init.md
   plugins/loom/skills/loom-playbook/SKILL.md` lists all four files. The old
   forward-pointer phrasings are gone: `rg -i "behavior body forthcoming|forthcoming
   M2 slice|summarize current state and continue"
   plugins/loom/skills/loom-playbook/references/orchestration.md
   plugins/loom/commands/run.md` returns nothing.

7. **`SKILL.md` lists initialized.md after unaligned.md.** In the References list,
   the `initialized.md` bullet immediately follows the `unaligned.md` bullet (line
   order check by eye after `rg -n "unaligned\.md|initialized\.md"
   plugins/loom/skills/loom-playbook/SKILL.md`).

8. **Root `CLAUDE.md` updated, no over-claim.** `rg -i "initialized.md"
   CLAUDE.md` shows the new bullet; `rg -i "forthcoming M2 slice|M2 (in progress|
   complete|done)" CLAUDE.md` confirms the "forthcoming" sentence is gone and the
   heading still says "M2 in progress" (no "M2 done"). Gate-learning still
   described as a forward pointer somewhere in the body.

9. **Links resolve.** Every relative link in `initialized.md` resolves to a real
   file: check the spec-06 path (`../../../../../.docs/spec/06-init-modes.md`),
   `status-machine.md`, `orchestration.md`, and the `run.md` path each exist
   relative to `references/`. `${CLAUDE_PLUGIN_ROOT}/…` paths in run.md/init.md
   point at real files under `plugins/loom/`.

10. **No spec/ADR touched.** `git diff --name-only` (after the developer's changes)
    shows **no** path under `.docs/spec/` or `.docs/ADR/`. This is the hard
    boundary.

11. **Gate-learning untouched.** No new gate logic is implemented; gate-learning
    remains a forward pointer. `rg -i "gate-learning" plugins/loom/skills/loom-playbook/references/initialized.md`
    confirms it is referenced as deferred, not implemented.

## Notes

(none)
