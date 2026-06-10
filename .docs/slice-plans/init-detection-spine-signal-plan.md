# init-detection-spine-signal

Status: Implemented
Target specs: 06-init-modes.md

## Context

Spec [`06-init-modes.md`](../spec/06-init-modes.md) is now **Approved** with the
amended *Detection* block: within the Unaligned branch, detection must
sub-classify by whether a **pre-existing docs spine** is present —
spine present → **Unaligned-migrate**, else → **Unaligned-bare** (spec 06
Detection block + §2a/§2b). The split's authority is
[ADR 0009](../ADR/0009-unaligned-migrate-sub-mode.md); its §2 fixes that the
classifier must signal an existing-but-undotted docs spine and steer toward
Unaligned-migrate, while leaving the **exact heuristics** (which paths, what
counts as a spine) to "the follow-on `init-detection.md` slice" — i.e. **this
slice**.

Today the playbook classifier
[`references/init-detection.md`](../../plugins/loom/skills/loom-playbook/references/init-detection.md)
classifies only **Greenfield / Unaligned / Initialized** (rule 3 is a flat
Unaligned catch-all). It has no concept of a pre-existing docs spine and does not
sub-classify Unaligned. The dispatch table lists a single `Unaligned` row
pointing at `06-init-modes.md §2`.

**This slice** brings `init-detection.md` into conformance with the amended spec
06 Detection block:

- add a concrete, defensible **"pre-existing docs spine"** definition (mirroring
  the existing concrete "loom-shaped `.docs/`" and "empty/near-empty" marker-set
  definitions);
- extend the **classification procedure** so the Unaligned branch sub-classifies
  into **Unaligned-bare** vs **Unaligned-migrate**, keeping first-match-wins and
  the Initialized + Greenfield rules intact;
- update the **dispatch table** to reflect the two sub-modes (cite §2a / §2b);
- keep the read-only statement and add a spec-06 pointer for the split.

**Out of scope (other slices / authority — do NOT touch in this slice):**

- **No spec/ADR edits.** Spec 06 and ADR 0009 are the authority and are already
  Approved/Accepted (frozen — ADR 0005). This slice only conforms the playbook.
- **`unaligned.md` is untouched** — splitting the behavior body (bare back-fill
  vs migrate flow with the owner gate, status preservation, init-inline-vs-spawn)
  is **slice 3** of this thread (ADR 0009 Consequences, follow-on slice 2 in its
  numbering).
- **No migration-recipe reference** — the reusable ordered/idempotent rewrite +
  spine-split recipe is **slice 2** (ADR 0009 Consequences, follow-on slice 3).
  This slice adds only the **detection signal**; it does not describe what the
  acting body does with it beyond steering to a sub-mode.
- No changes to Greenfield, Initialized, the empty/near-empty allowlist, or the
  loom-shaped definition.

This slice is **sequential** (the first of the three ADR-0009 playbook slices), so
the plan file and the `slice-plans/README.md` Active entry are written in the same
plan commit.

## Steps

All edits are to a single file:
`plugins/loom/skills/loom-playbook/references/init-detection.md`.

1. **Add the "pre-existing docs spine" input.** In the *Inputs to inspect
   (read-only)* list (currently the three bullets: `.docs/` presence,
   loom-shaped, empty/near-empty), add a fourth bullet:

   > - Whether a **pre-existing docs spine** exists outside `.docs/` (definition
   >   below) — used only to sub-classify Unaligned; read-only.

2. **Add a "pre-existing docs spine" definition section.** After the existing
   *Definition — "empty/near-empty repo"* section (it ends with the blockquote at
   lines 49–51) and before the `---` that precedes *Classification procedure*,
   insert a new `## Definition — "pre-existing docs spine"` section. It must be
   concrete and marker-set-shaped, mirroring the two existing definitions. Use
   this content (heuristic chosen to be defensible and to match the spec-06 /
   ADR-0009 spine examples — `docs/`, `doc/`, `documentation/`, methodology-shaped
   docs, not just any docs folder):

   > A **non-`.docs/` methodology tree** at repo root — a docs directory that
   > looks like a project methodology, not just stray notes. Detect it read-only:
   >
   > A candidate root is a tracked directory named one of `docs/`, `doc/`, or
   > `documentation/` (case-insensitive). A candidate is a **pre-existing docs
   > spine** when it contains **at least one** of these methodology markers
   > (matched by directory or filename, case-insensitive):
   >
   > - a **specs** grouping — a `spec`/`specs` subdirectory, OR numbered
   >   spec-spine files (e.g. `00-*.md`, `01-*.md`, … — two or more);
   > - a **decision-record** grouping — an `adr`/`adrs`/`decisions` subdirectory,
   >   OR `adr`/`decision`-named records;
   > - a **roadmap / progress / handoff**-style living doc — a file whose name
   >   contains `roadmap`, `progress`, or `handoff`;
   > - a **slice-plan / plan lifecycle** grouping — a `slice-plans`/`plans`
   >   subdirectory.
   >
   > A directory with only a `README` or a few loose, unstructured notes is **not**
   > a spine. Record the matched path for the observation below. The distinguishing
   > fact is the presence of a methodology tree, **not** the repo's language or
   > size.
   >
   > > This is loom's operative expansion of the spec-06 term "pre-existing docs
   > > spine." Spec 06 introduces the term and example paths but does not enumerate
   > > the markers; the set above is the playbook's concrete expansion. Spec 06
   > > wins on any conflict.

3. **Sub-classify the Unaligned branch in the classification procedure.** In the
   *Classification procedure* fenced block (currently rules 1–3 with rule 3
   "otherwise → Unaligned"), replace the flat rule 3 with a sub-classifying rule.
   First match wins is preserved — Initialized (rule 1) and Greenfield (rule 2)
   are unchanged and still precede. New block:

   ```
   1. loom-shaped .docs/ present?             → Initialized
   2. .docs/ absent AND repo empty/near-empty → Greenfield
   3. otherwise                               → Unaligned
        (covers: no .docs/ in a non-empty repo,
         AND .docs/ present but not loom-shaped)
        then sub-classify Unaligned:
          a. pre-existing docs spine present?  → Unaligned-migrate
          b. else                             → Unaligned-bare
   ```

   Update the prose paragraph that follows the block so it (a) states the Unaligned
   sub-classification observation — when a spine is present, detection records "a
   non-loom docs spine exists at `<path>`" and steers the acting body toward
   Unaligned-migrate rather than back-fill — and (b) still affirms that rule order
   means a loom-shaped `.docs/` always wins. Add a sentence: the sub-classification
   is **read-only** — it observes the spine and steers; it mutates nothing. Point
   to spec 06 §2a / §2b and ADR 0009 §2 as the authority for the split.

4. **Update the dispatch table.** In *What each mode dispatches to*, replace the
   single `Unaligned` row with two rows — one per sub-mode — citing the correct
   spec section. Greenfield and Initialized rows are unchanged. New rows:

   | Mode | Action | Spec reference |
   |---|---|---|
   | Unaligned-bare | Alignment pass: scaffold + playbook + gate + descriptive back-fill | [`06-init-modes.md §2a`](../../../../../.docs/spec/06-init-modes.md) |
   | Unaligned-migrate | Reconcile/migrate the pre-existing docs spine into `.docs/` (owner gate; status-preserving); resume Initialized | [`06-init-modes.md §2b`](../../../../../.docs/spec/06-init-modes.md) |

   (Keep the relative link form already used by the file's other rows, the
   `../../../../../.docs/spec/...` style.)

5. **Affirm read-only.** Confirm the file's existing read-only statements (intro
   line ~7 and the *Edge cases* bullet) remain intact; do not remove them. The new
   spine-detection text added in steps 2–3 must explicitly say it observes only and
   mutates nothing (covered by step 2's "Detect it read-only" and step 3's added
   read-only sentence). No new mutation is introduced.

6. **No other files** are edited by this slice except this plan file and the
   `slice-plans/README.md` Active entry (added in the same plan commit, per the
   sequential-slice rule). Do **not** edit spec 06, ADR 0009, `unaligned.md`, or
   create any migration-recipe reference.

## Verification

loom's own repo is markdown — there is **no compiled gate**; acceptance is
**review against spec 06** (the plan evaluator, blind). The mechanical checks below
let the developer and evaluator confirm the edit is repo-correct. Run from repo
root.

**A. Spine definition present and concrete.**

```sh
rg -n 'Definition — "pre-existing docs spine"' \
  plugins/loom/skills/loom-playbook/references/init-detection.md
rg -nU 'docs/.*doc/.*documentation/|methodology marker' \
  plugins/loom/skills/loom-playbook/references/init-detection.md
```
Expect: the new section heading matches, and the path set / marker language is
present.

**B. Unaligned sub-classification present.**

```sh
rg -n 'Unaligned-migrate|Unaligned-bare' \
  plugins/loom/skills/loom-playbook/references/init-detection.md
```
Expect: **both** tokens appear (in the classification block, the prose, and the
dispatch table) — at minimum one occurrence each in the procedure and the table.

**C. Dispatch table updated (no stale flat `Unaligned` row).**

```sh
rg -n '\| Unaligned-bare \|' \
  plugins/loom/skills/loom-playbook/references/init-detection.md
rg -n '\| Unaligned-migrate \|' \
  plugins/loom/skills/loom-playbook/references/init-detection.md
rg -n '06-init-modes.md §2a|06-init-modes.md §2b' \
  plugins/loom/skills/loom-playbook/references/init-detection.md
# guard: no bare "| Unaligned |" row remains in the table
rg -n '^\| Unaligned \|' \
  plugins/loom/skills/loom-playbook/references/init-detection.md && \
  echo "FAIL: stale flat Unaligned dispatch row" || echo "OK: no flat Unaligned row"
```
Expect: both sub-mode rows present with §2a/§2b citations; the guard prints `OK`.

**D. Read-only statement intact.**

```sh
rg -ni 'read-only|mutates nothing|never creates or mutates' \
  plugins/loom/skills/loom-playbook/references/init-detection.md
```
Expect: the original read-only statements (intro + Edge cases) are still present,
plus the new spine-detection read-only assertion.

**E. Spec-06 split pointer present.**

```sh
rg -n '06-init-modes.md|ADR 0009|0009-unaligned-migrate-sub-mode' \
  plugins/loom/skills/loom-playbook/references/init-detection.md
```
Expect: spec 06 is cited as authority for the split (and ADR 0009 §2 referenced as
the decision input).

**F. Scope guard — only the three allowed files changed; NO spec/ADR edits.**

```sh
git diff --name-only HEAD
git status --porcelain
```
Expect exactly these paths and nothing else:

- `plugins/loom/skills/loom-playbook/references/init-detection.md`
- `.docs/slice-plans/init-detection-spine-signal-plan.md`
- `.docs/slice-plans/README.md`

Hard fail if `git diff --name-only HEAD` lists anything under `.docs/spec/`,
`.docs/ADR/`, `references/unaligned.md`, or any new migration-recipe file:

```sh
git diff --name-only HEAD | rg -n '\.docs/spec/|\.docs/ADR/|references/unaligned\.md|migration' \
  && echo "FAIL: out-of-scope edit" || echo "OK: scope clean"
```
Expect: `OK: scope clean`.

## Verification Evidence

Mechanical checks run against
`plugins/loom/skills/loom-playbook/references/init-detection.md` (literal-token
`rg` per plan):

- **A (spine definition):** `Definition — "pre-existing docs spine"` heading
  present at line 57; `methodology markers` language present at line 64.
- **B (sub-classification tokens):** `Unaligned-migrate` at lines 99, 112, 135;
  `Unaligned-bare` at lines 100, 134. Both appear in the classification block,
  prose, and dispatch table.
- **C (dispatch table):** `| Unaligned-bare |` at line 134 with `§2a` citation;
  `| Unaligned-migrate |` at line 135 with `§2b` citation. Guard: `OK: no flat
  Unaligned row`.
- **D (read-only):** Six occurrences: intro (line 7), inputs heading (line 12),
  new input bullet (line 18), spine definition "Detect it read-only" (line 60),
  new sub-classification prose "mutates nothing" (line 113), Edge cases (line
  125).
- **E (spec-06 / ADR 0009 pointers):** `06-init-modes.md` cited throughout
  including §2a/§2b in the dispatch table; `ADR 0009 §2` in the classification
  prose; `0009-unaligned-migrate-sub-mode.md` linked at line 115.
- **F (scope guard):** Only two files modified —
  `plugins/loom/skills/loom-playbook/references/init-detection.md` and
  `.docs/slice-plans/init-detection-spine-signal-plan.md`. No spec/, ADR/,
  `unaligned.md`, or migration-recipe edits. Guard: `OK: scope clean`.

## Notes

- This is **slice 1 of 3** of the ADR-0009 playbook thread. The other two are
  **separate** slices, sequenced after this one:
  - **Slice 2 — migration-recipe reference** (ADR 0009 §5/§7): a new playbook
    reference holding the ordered/idempotent cross-reference rewrite, the
    numbered-spine → `spec/` + `status/` split, and the operational preconditions.
    This slice only *signals* a spine; it does not author the recipe.
  - **Slice 3 — split `unaligned.md`** (ADR 0009 §3/§4/§6): separate the bare
    back-fill flow from the Unaligned-migrate flow (owner gate, status
    preservation, init-inline-vs-role-spawn division). This slice does not change
    behavior bodies.
- Heuristic choice (step 2) is the playbook's concrete expansion of spec 06's
  spine concept; **spec 06 wins on conflict** and is cited as authority. The
  marker set is deliberately conservative (a `README`-only or notes-only docs
  folder is not a spine) to avoid false-positive migration steers.
