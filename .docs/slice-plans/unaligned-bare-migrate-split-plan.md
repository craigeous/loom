# Unaligned bare/migrate split

Status: Plan Review
Target specs: 06-init-modes.md

## Context

This is **slice 3 of 3** of the ADR-0009 Unaligned bare/migrate split, and the
final slice of that thread.

- **Slice 1** (`init-detection.md`, landed `c96fd90`) added the pre-existing
  docs-spine signal and the Unaligned sub-classification (spine present →
  Unaligned-migrate, else Unaligned-bare).
- **Slice 2** (`migration-recipe.md`, landed `a34d726`/`da21d2c`/`fdbbb60`) added
  the reusable, ordered, idempotent migration recipe (ADR 0009 §5/§7).

Spec [`06-init-modes.md`](../spec/06-init-modes.md) is **Approved** and now carries
§2a (Unaligned-bare) and §2b (Unaligned-migrate). ADR
[`0009`](../ADR/0009-unaligned-migrate-sub-mode.md) is **Accepted**.

What is **not** yet done: the behavior body
[`plugins/loom/skills/loom-playbook/references/unaligned.md`](../../plugins/loom/skills/loom-playbook/references/unaligned.md)
still describes **one** flow — descriptive back-fill — and its authority line points
at spec 06 **§2** (the old, single-mode section). It does not present the two
sub-modes, the migrate owner gate, status preservation, or the inline/no-spawn
division; and it does not route off the slice-1 sub-classification or point at the
slice-2 recipe.

**This slice** restructures `unaligned.md` so it presents BOTH sub-modes, routed by
the `init-detection.md` sub-classification:

- **Unaligned-bare** = the existing Steps 1–5 (study → scaffold+gate via Greenfield
  → descriptive back-fill → seed status → hand back), scoped to "no pre-existing
  docs spine."
- **Unaligned-migrate** (NEW) = reconciliation, not back-fill: the owner gate
  (migrate / thin-pointer / abort), inline execution of the migration recipe on
  *migrate*, status preservation, and no planner/evaluator role-spawn.

### Single-source discipline (hard rule for the developer)

`unaligned.md` describes the **flow/orchestration only**. It does NOT restate:

- the **recipe mechanics** — those live in
  [`migration-recipe.md`](../../plugins/loom/skills/loom-playbook/references/migration-recipe.md)
  (point AT it; do not duplicate its step content);
- the **owner-gate option semantics** and the **status-preservation policy** — those
  live in spec 06 §2b / ADR 0009 §3–§4 (point AT them; do not re-derive).

### Out of scope (do NOT touch)

- `.docs/spec/06-init-modes.md`, `.docs/ADR/0009-unaligned-migrate-sub-mode.md`,
  `migration-recipe.md`, `init-detection.md` — all landed/frozen; this slice only
  points AT them.
- `CLAUDE.md` and `SKILL.md` are **NOT edited in this implement step.** The
  `unaligned.md` SKILL.md References entry and any CLAUDE.md curated-digest line
  describe only the old single back-fill flow and will be stale after this slice;
  updating them is the **developer's finalize pass** (spec 03 finalize pass step 2;
  boundary in spec 08 *Evolving the playbook → CLAUDE.md auto-propagation*), NOT the
  implement commit. The implement commit touches only `unaligned.md` (+ this plan +
  the slice-plans README). (A prior slice FAILed for editing `CLAUDE.md` at
  implement — do not repeat that.)

## Steps

All steps edit a single file:
`plugins/loom/skills/loom-playbook/references/unaligned.md`.
The plan + README steps (8, 9) are committed together with the `unaligned.md` change.

### 1. Reframe the intro + authority line (lines 1–14)

Replace the title/intro block so the body announces it covers **both** sub-modes and
routes off the slice-1 sub-classification.

- **Authority line:** change the current
  `Authority: [...] §2.` to point at **§2a / §2b** (the new sections), e.g.:
  `Authority: [...06-init-modes.md] §2a (Unaligned-bare) and §2b
  (Unaligned-migrate).` Keep the existing "Spec `06-init-modes.md` wins on any
  conflict." sentence.
- **Routing note:** state that `init-detection.md`'s Unaligned **sub-classification**
  (slice 1) routes between the two flows — *no pre-existing docs spine* →
  Unaligned-bare; *a pre-existing docs spine present* → Unaligned-migrate. Point at
  [`init-detection.md`](init-detection.md) for the sub-classification (do not restate
  its heuristics).
- Keep the existing precondition sentence ("`init-detection.md` has already
  classified this repo as Unaligned. This body **writes** files — unlike the
  read-only detection classifier."), broadened to "as Unaligned (one of the two
  sub-modes)."
- Keep the "alignment/migration pass, not a config interview" framing.

### 2. Add a top-level split section that names the two flows

Immediately after the intro / before the bare Steps, add a short section (e.g.
`## Two sub-modes`) that:

- names **Unaligned-bare** (no pre-existing docs spine → descriptive back-fill, the
  Steps below) and **Unaligned-migrate** (a pre-existing docs spine → reconciliation,
  the migrate flow below);
- states the **identity pre-flight applies to BOTH flows** (the existing identity
  pre-flight currently lives inside bare Step 2 — see step 4 below for how it is made
  shared);
- points at spec 06 §2a/§2b for the canonical sub-mode definitions.

Do **not** re-derive the sub-mode semantics — one sentence each plus the pointer.

### 3. Scope the existing Steps 1–5 as the Unaligned-bare flow

Wrap the EXISTING Steps 1–5 under a clear **Unaligned-bare** heading (e.g.
`## Unaligned-bare flow — no pre-existing docs spine`). Keep the five steps and their
content **as-is** except:

- add a one-line scope statement at the top of the bare flow: this flow runs when
  detection found **no pre-existing docs spine** (loom is the first methodology the
  project has had);
- preserve the **back-fill no-decisions boundary** (current "No-decisions boundary
  (hard rule)") unchanged;
- preserve the **"back-filled specs are Draft → Plan Review → Approved"** rule
  (current "Lifecycle: back-filled specs are not exempt from review"), and make
  explicit that this **Draft → review rule is Unaligned-bare-only** — it does NOT
  apply to migrate (per spec 06 §2a/§2b). Point at spec 06 §2a; do not duplicate the
  policy prose beyond the one-line scope note.

Update any in-step references to "spec `06 §2`" inside the bare flow to "spec
`06 §2a`" so the bare flow cites its own section.

### 4. Make the identity pre-flight shared across both flows

The identity pre-flight currently lives inside bare Step 2 (lines 49–53, "Identity
pre-flight (Greenfield Step F applies here too)"). Both flows commit, so it must
apply to both.

- Either (a) hoist the identity pre-flight into the `## Two sub-modes` section (step
  2) as a shared pre-flight that **both** flows reference, or (b) keep it stated once
  and have the migrate flow explicitly reference it.
- Whichever form: there must be exactly **one** authoritative statement of the
  identity pre-flight, and **both** the bare flow and the migrate flow must be tied
  to it. Do not duplicate the full pre-flight text in two places. Keep the
  `commit-convention.md` rationale pointer.

### 5. Add the Unaligned-migrate flow section (NEW)

Add a new top-level section (e.g.
`## Unaligned-migrate flow — a pre-existing docs spine exists`) after the bare flow.
It describes **orchestration only**. Contents, in order:

1. **Scope line.** This flow runs when detection recorded "a non-loom docs spine
   exists at `<path>`" (slice 1). The job is **reconciliation/migration, NOT
   back-fill** — there is nothing to describe that the existing tree does not already
   describe better. Point at spec 06 §2b.

2. **The owner gate (migrate / thin-pointer / abort).** Present it as an explicit,
   required owner decision surfaced **before any files move** — not the generic
   "ambiguity → ask" fall-through. State that loom does not pick; the owner must
   answer. List the three options with their consequence **named** (one line each):
   - **Migrate** — reconcile/move the spine into `.docs/`; old tree stops being
     authoritative; future runs detect **Initialized**.
   - **Thin-pointer** — leave the old tree authoritative + place a pointer at
     `.docs/`; consequence: **future runs re-detect Unaligned**.
   - **Abort** — make no changes; consequence: **re-detected as Unaligned on every
     run**.
   Then point at **spec 06 §2b / ADR 0009 §3** as the canonical source for the option
   semantics; do not re-derive them beyond the one-line consequence each.

3. **On *migrate* — run the recipe INLINE.** State that `/loom:init` runs the
   migration recipe **inline** (no role-spawn), and point AT
   [`migration-recipe.md`](migration-recipe.md) for the mechanical procedure (move,
   ordered/idempotent cross-reference rewrite, spine-split, preconditions). **Do NOT
   restate any recipe step** (no dirty-tree command, no `git mv`/`mv` split, no
   lookbehind, no NUL-delimited list, no spine→spec/status mechanics) — single-source
   to the recipe.

4. **Status preservation.** State that migrated specs **retain their prior status**
   and that migration is **NOT a re-review trigger** — the bare-flow "new specs enter
   at Draft → review" rule does **not** apply to migrate. Point at **spec 06 §2b /
   ADR 0009 §4**; do not re-derive the policy.

5. **Inline, no role-spawn.** State that a pure migration **authors no specs**, so —
   unlike bare back-fill — there is **no planner/evaluator role-spawn in the
   migration itself** (ADR 0009 §6). Describe the inline `/loom:init` sequence:
   detection → owner gate → (on *migrate*) the recipe → seed/reconcile `status/` →
   hand back **Initialized**. Subsequent design work begins normally via `/loom:run`
   once Initialized.

6. **On *thin-pointer* / *abort*.** State the outcome per spec 06 §2b consequences:
   the repo is **re-detected as Unaligned** on subsequent runs (point at spec 06 §2b
   — do not re-derive).

### 6. Update the hand-back / idempotence to cover both flows

- The current "Step 5 — Hand back: ready to resume as Initialized" lives inside the
  bare flow (kept there per step 3). Add, in the migrate flow's inline sequence (step
  5 above), that the migrate flow **also** hands back ready to resume as
  **Initialized** — both flows leave the repo loom-shaped.
- Keep the **Idempotence note** at the end of the file and broaden it so it explicitly
  applies to **both** flows (bare re-application never clobbers; re-running migrate is
  a no-op per the recipe's own idempotence — point at `migration-recipe.md` for the
  recipe's no-op guarantee rather than restating it).

### 7. Keep the commit-convention pointer

Preserve the existing author-neutral commit note (current lines ~163–164) and ensure
it reads as applying to both flows' commits (it points at `commit-convention.md`;
keep that single-source pointer).

### 8. Add the Active-plan entry to the slice-plans README

In [`.docs/slice-plans/README.md`](README.md) under `## Active plans`, replace
`(none)` with an entry pointing at this plan
(`unaligned-bare-migrate-split-plan.md`), `Plan Review`, summarizing: slice 3 of 3 of
the ADR-0009 split — restructure `unaligned.md` into the Unaligned-bare flow (existing
Steps 1–5) + the new Unaligned-migrate flow (owner gate, inline recipe via
`migration-recipe.md`, status preservation, no role-spawn); points at spec 06 §2a/§2b,
ADR 0009 §3/§4/§6, `init-detection.md`, `migration-recipe.md`; `unaligned.md` only
(no spec/ADR/recipe/detection edits). Target spec 06-init-modes.md.

### 9. Commit (this plan + README + — at implement — `unaligned.md`)

This planning commit lands the plan file (step author) + the README Active entry
together. The implement commit (separate, by the developer) lands the `unaligned.md`
restructure. Both are author-neutral per `commit-convention.md`.

## Verification

`unaligned.md` is markdown — there is **no compiled gate**. Verification is
**review-against-spec** (spec 06 §2a/§2b + ADR 0009 §3/§4/§6) plus the mechanical
checks below. Run from repo root. `U=plugins/loom/skills/loom-playbook/references/unaligned.md`.

### Mechanical content checks (each must match)

1. **Authority line updated to §2a/§2b** (no longer bare `§2`):
   `rg -n '§2a' "$U"` and `rg -n '§2b' "$U"` both return hits in/near the authority
   block. Confirm the authority line no longer cites only `§2`.

2. **Both flows present** — a bare-flow heading and a migrate-flow heading:
   `rg -ni 'unaligned-bare' "$U"` and `rg -ni 'unaligned-migrate' "$U"` each return
   hits.

3. **Owner gate with all three options, consequences named:**
   `rg -ni 'thin-pointer' "$U"`, `rg -ni '\babort\b' "$U"`, and
   `rg -ni '\bmigrate\b' "$U"` all hit; confirm by review that each option states its
   consequence (Initialized / re-detect Unaligned / re-detect Unaligned).

4. **Status-preservation pointer present** (not re-derived): `rg -ni 'status' "$U"`
   hits a statement that migrated specs retain prior status / migration is not a
   re-review trigger, with a pointer to spec 06 §2b / ADR 0009 §4. Confirm by review
   the pointer is present.

5. **Inline / no role-spawn stated:** `rg -ni 'inline' "$U"` and
   `rg -ni 'role-spawn|spawn' "$U"` hit a statement that the migration runs inline in
   `/loom:init` with no planner/evaluator spawn.

6. **Points AT the landed slices:**
   `rg -n 'migration-recipe.md' "$U"` and `rg -n 'init-detection.md' "$U"` each return
   at least one link.

7. **Recipe NOT restated (single-source guard).** The recipe's mechanical step
   content must NOT be duplicated in `unaligned.md`. These must each return **no
   matches**:
   - `rg -n 'print0|xargs -0' "$U"` (NUL-delimited lists — recipe Step A.3)
   - `rg -n 'lookbehind|\(\?<!' "$U"` (self-match guard — recipe Step D)
   - `rg -n 'git mv|git stash|git status --porcelain' "$U"` (recipe Step A)
   - `rg -n '\.\.docs/' "$U"` (self-match artifact discussion — recipe Step D/H)
   If any of these match, the recipe was wrongly restated — fix by replacing with a
   pointer to `migration-recipe.md`.

8. **Bare-only Draft→review rule preserved + scoped:** `rg -ni 'Draft' "$U"` hits the
   bare-flow lifecycle statement; confirm by review it is scoped Unaligned-bare-only
   and the migrate flow does NOT claim a Draft→review pass.

9. **Identity pre-flight present and shared:** `rg -ni 'identity pre-flight|git
   identity' "$U"` hits; confirm by review there is exactly one authoritative
   statement and both flows are tied to it.

### Scope guard (the load-bearing check)

`git diff --name-only` (and `git status --porcelain` for untracked) for the implement
commit must show **only**:

- `plugins/loom/skills/loom-playbook/references/unaligned.md`

and for the planning commit **only**:

- `.docs/slice-plans/unaligned-bare-migrate-split-plan.md`
- `.docs/slice-plans/README.md`

It must show **NONE** of:

- `.docs/spec/06-init-modes.md`
- `.docs/ADR/0009-unaligned-migrate-sub-mode.md`
- `plugins/loom/skills/loom-playbook/references/migration-recipe.md`
- `plugins/loom/skills/loom-playbook/references/init-detection.md`
- `CLAUDE.md`
- `plugins/loom/skills/loom-playbook/SKILL.md`

Concretely:
`git diff --name-only HEAD -- .docs/spec .docs/ADR
plugins/loom/skills/loom-playbook/references/migration-recipe.md
plugins/loom/skills/loom-playbook/references/init-detection.md CLAUDE.md
plugins/loom/skills/loom-playbook/SKILL.md` must return **empty**.

### Process note for the developer (carry forward)

- **CLAUDE.md is NOT edited in the implement step.** If a curated-digest update is
  warranted (the CLAUDE.md unaligned.md line, and the SKILL.md References entry,
  currently describe only the single back-fill flow), it is done in the **finalize
  pass** (spec 03 finalize pass step 2; boundary in spec 08), not the implement
  commit. The implement commit touches only `unaligned.md`.
- Commits are author-neutral per `commit-convention.md` (no co-author trailers, no
  role/author identity in the message); never `--no-verify`; use the
  already-configured git identity (no `--author` / `-c user.*` / `GIT_AUTHOR_*`).

## Notes

(none)
