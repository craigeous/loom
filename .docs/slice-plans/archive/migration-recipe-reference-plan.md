# migration-recipe-reference

Status: Archived
Target specs: 06-init-modes.md

## Context

[ADR 0009](../ADR/0009-unaligned-migrate-sub-mode.md) (Accepted) splits Unaligned
into **Unaligned-bare** (descriptive back-fill, unchanged) and **Unaligned-migrate**
(reconcile/move an existing docs spine into `.docs/`). Spec
[`06-init-modes.md`](../spec/06-init-modes.md) §2b is Approved and frozen (ADR 0005)
and defers the mechanical detail to the playbook: *"The migration recipe lives in the
playbook … The recipe **text** is a playbook reference authored in a follow-on slice,
**not** spec text."* ADR 0009 §5 fixes that a reusable migration-recipe reference
**must exist** and names its load-bearing properties; §7 makes three operational
hazards **required preconditions** of that recipe.

This is **slice 2 of 3** of the ADR-0009 playbook thread:

- **Slice 1 — `init-detection.md` spine signal** — *landed* (`c96fd90`,
  `archive/init-detection-spine-signal-plan.md`): detection now sub-classifies
  Unaligned into bare vs migrate.
- **This slice (2 of 3) — migration-recipe reference** — author the reusable,
  ordered, idempotent migration recipe (ADR 0009 §5 + §7) as a new playbook
  reference, and make it discoverable in `SKILL.md`.
- **Slice 3 — split `unaligned.md`** — *not yet started*: separate the bare
  back-fill flow from the Unaligned-migrate flow (owner gate, status preservation,
  init-inline-vs-role-spawn). **Out of scope here.**

The concrete, battle-tested content for the recipe comes from the field report
[`../research/2026-06-09-unaligned-init-migration-field-report.md`](../research/2026-06-09-unaligned-init-migration-field-report.md)
(§4, §5, and "Operational failures") — the real `/loom:init` migration of `ballboy`
(`docs/` → `.docs/`, ballboy commit `564d8a4`) that this recipe must let future runs
follow without reinventing.

Today the playbook has **no** migration recipe. `references/` holds the per-mode
behavior bodies and mechanism references; the closest structural model is
[`../../plugins/loom/skills/loom-playbook/references/gate-learning.md`](../../plugins/loom/skills/loom-playbook/references/gate-learning.md)
— a numbered, concrete "mechanism" reference with an authority pointer, a
precondition, ordered steps, and an idempotence note. This slice mirrors that shape.

**This slice delivers exactly two file edits** (plus the plan + README, per the
sequential-slice rule):

1. **Create** `plugins/loom/skills/loom-playbook/references/migration-recipe.md` —
   the concrete, reusable recipe.
2. **Edit** `plugins/loom/skills/loom-playbook/SKILL.md` — add the new reference to
   the References list (discoverability), matching the existing entry style.

**Reference filename — chosen: `migration-recipe.md`.** It is the noun spec 06 §2b
and ADR 0009 §5 use ("the migration recipe"), it is concise and verb-free like its
sibling `gate-learning.md`, and it slots cleanly into the existing References list.

**Out of scope — do NOT touch in this slice (BLOCKER if edited):**

- **`.docs/spec/`** — spec 06 is the **authority** and is Approved/frozen (ADR 0005).
  This slice realizes the deferred playbook detail; it does not edit the spec.
- **`.docs/ADR/`** — ADR 0009 is Accepted/immutable. Cited, never edited.
- **`references/unaligned.md`** — splitting the behavior body is **slice 3**.
- **`references/init-detection.md`** — already landed in slice 1.
- The recipe does **not** restate the owner gate, the migrate/thin-pointer/abort
  decision, the status-preservation *policy*, or the init-inline-vs-spawn division
  as its own rules — those are spec 06 §2b / ADR 0009 §3/§4/§6 and (for the gate
  and division) slice 3's `unaligned.md`. The recipe is the **mechanical "how"** the
  migrate path executes once the owner has chosen migrate; it **points to** spec 06
  §2b / ADR 0009 for the policy (esp. status preservation, §4) rather than
  re-deriving it.

## Steps

### Step 1 — Create the migration-recipe reference

Create a new file
`plugins/loom/skills/loom-playbook/references/migration-recipe.md`, mirroring the
shape of `references/gate-learning.md` (title; one-line "what this is"; an
**Authority** pointer with "spec wins on conflict"; a **Precondition**; numbered
ordered steps; an idempotence/scope note). Use the relative-link form the other
references use to reach `.docs/`: `../../../../../.docs/...` (verified against
`init-detection.md` line 4 and `gate-learning.md` line 6).

The file must contain the following sections and content. (Wording may be the
author's; the **load-bearing facts** below are required and are what the verification
in this plan checks.)

**Header block:**

- Title: `# Migration Recipe (Unaligned-migrate)`.
- One-line description: the reusable, ordered, idempotent procedure for migrating an
  existing un-dotted docs spine into `.docs/`, run inline by `/loom:init` on the
  Unaligned-migrate path **after** the owner has chosen *migrate*.
- **Authority** line pointing to
  [`06-init-modes.md`](../../../../../.docs/spec/06-init-modes.md) **§2b** and
  [`0009-unaligned-migrate-sub-mode.md`](../../../../../.docs/ADR/0009-unaligned-migrate-sub-mode.md)
  **§5 (load-bearing properties)** and **§7 (operational preconditions)**, with the
  standard "Spec `06-init-modes.md` wins on any conflict" line.
- **Precondition:** detection (`init-detection.md`) classified the repo
  **Unaligned-migrate** (a pre-existing docs spine exists at `<path>`) **and** the
  owner answered the migrate/thin-pointer/abort gate with **migrate** (spec 06 §2b /
  ADR 0009 §3 — the gate itself is not part of this recipe; it gates entry to it).
  This body **writes/moves** files.

**Step A — Preconditions before any move (ADR 0009 §7).** A required, ordered
pre-flight that runs before a single file moves. Three named checks:

1. **Dirty-tree check first.** Run `git status` (e.g. `git status --porcelain`); if
   the working tree is dirty, **stash or flag** the pre-existing uncommitted edits
   **before** moving anything, so they are not bundled into the alignment commit
   (ADR 0009 §7; field report Operational failure 3). Show a concrete sketch, e.g.:
   ```sh
   # refuse-or-stash a dirty tree before migrating
   if [ -n "$(git status --porcelain)" ]; then
     # stash (or stop and tell the owner) — do not bundle pre-existing edits
     git stash push -u -m "pre-migration WIP"
   fi
   ```
2. **Detect untracked files in the source tree.** `git mv` **silently skips
   untracked files** (field report Operational failure 1: ballboy's untracked
   `18-python-parity-analysis.md` was left behind). The recipe must enumerate
   untracked content under the source spine and move it with `mv` + `git add`
   **separately** from the `git mv` of tracked files. Sketch using
   `git ls-files --others --exclude-standard` so the two sets are handled distinctly.
3. **Build all bulk file lists NUL-delimited.** Every bulk list (for moves and for
   the rewrite passes) is built `find … -print0 | xargs -0 …`, **never** via
   word-splitting `$(find …)` (field report Operational failure 2: space/newline
   splitting silently glued and skipped files). State this as a hard rule and show
   the `-print0 | xargs -0` form; explicitly call out `$(find …)` as the
   anti-pattern.

**Step B — The numbered-spine → `spec/` + `status/` split (ADR 0009 §5 fourth
bullet; field report §4).** The procedure that pulls the living docs out of a
numbered spine:

- **Extract the living docs into `.docs/status/`:** the spine's
  roadmap/progress/handoff-equivalents (field report: ballboy's
  `08-roadmap.md` → `status/roadmap.md`, `09-session-handoff.md` →
  `status/handoff.md`, `10-progress.md` → `status/progress.md`). Everything else in
  the spine goes to `.docs/spec/`.
- **Numbering gaps are expected and accepted.** Extracting 08/09/10 leaves
  `spec/` with gaps (e.g. 00–07, 11–18); the recipe states the gaps are left as-is
  (renumbering is not part of migration) so existing inbound references stay valid.
- **Two-directional link rewrite.** Pulling files across directory boundaries breaks
  links **in both directions**, and the recipe must rewrite both:
  - **same-directory links *to* the extracted files** (other spine files that
    referenced `08-roadmap.md` as a sibling) become `../status/...`;
  - **outbound links *from* the extracted files** to the rest of the spine become
    `../spec/...`.

**Step C — Ordered cross-reference rewrite rules (ADR 0009 §5 first bullet; field
report §5).** State the **specific-before-generic** ordering as a hard requirement:
the living-doc renames (the spine's roadmap/handoff/progress →
`.docs/status/...`, and any other specific rename) run **before** the generic
`docs/...` → `.docs/...` (or `docs/specs/...` → `.docs/spec/...`) rule — otherwise
08/09/10-type living docs wrongly land in `spec/`. Show the rules as an explicitly
**ordered** list (specific renames first, generic catch-all last).

**Step D — Idempotency / the self-match hazard (ADR 0009 §5 second bullet; field
report §5).** The recipe must be safe to re-run. State the **self-match hazard**
concretely: a naive `docs/...` → `.docs/...` rule **re-matches its own output**,
producing `..docs/...`. Guard against re-matching already-rewritten paths — the
field report used a **negative lookbehind `(?<!\.)`** so an existing leading dot is
not re-prefixed. Show the guarded pattern and state explicitly: **re-running the
recipe must be a no-op on already-migrated paths.**

**Step E — Three reference forms, handled separately (ADR 0009 §5 third bullet;
field report §5).** Each of the three forms gets its **own** rewrite rule;
collapsing them loses cases:

- **(a) path-form mentions** — e.g. `docs/specs/X` in prose or paths;
- **(b) bare markdown link targets** — e.g. `](X.md)` — these resolve **relative to
  the file's NEW location**, so the rewrite must account for the file having moved
  (this is why Step B's two-directional rewrite is needed);
- **(c) prose / backtick mentions** — e.g. `` `docs/...` `` inline.

State that each is matched and rewritten by its own rule.

**Step F — Living-rewritten vs archived-snapshot boundary (ADR 0009 §5 fifth bullet;
field report §5).** State the boundary explicitly: **living docs** are migrated and
their refs rewritten; **archived slice-plans** are left as **historical snapshots**
(consistent with loom's "archived plans are history") and their **internal refs are
NOT rewritten**. The rewrite passes (Steps C–E) must therefore **exclude** the
archive from the rewrite file list (built NUL-delimited per Step A.3).

**Step G — Status preservation (point to policy, do not re-derive).** State that
migrated specs **retain their prior status** and that migration is **not** a
re-review trigger — and **cross-reference** spec 06 §2b ("Status preservation") and
ADR 0009 §4 for the policy. Do **not** restate or re-derive the policy here; one or
two sentences plus the pointer. (This keeps the durable policy single-sourced in the
frozen spec / Accepted ADR.)

**Step H — Link validation (final step).** As the **last** step, validate links:
re-scan the migrated tree for any remaining un-rewritten `docs/...` references and
for self-match artifacts (`..docs/...`), and confirm moved-file relative links
resolve. Show concrete `rg` checks, e.g.:
```sh
# no un-rewritten source-tree refs remain (outside the left-as-history archive)
rg -n --glob '!**/slice-plans/archive/**' '(?<!\.)\bdocs/' .docs/ && echo "FAIL: unrewritten refs" || echo "OK"
# no self-match artifacts
rg -n '\.\.docs/' .docs/ && echo "FAIL: self-match artifact" || echo "OK"
```

**Idempotence / scope note (mirror `gate-learning.md`'s closing note).** Re-running
the recipe on an already-migrated repo is a no-op (Step D guard + the dirty-tree
check). The recipe never touches archived history (Step F) and never edits the spec
or ADR — it relocates and re-references existing artifacts only.

### Step 2 — Add the reference to `SKILL.md`'s References list

Edit `plugins/loom/skills/loom-playbook/SKILL.md`. In the
`## References (`references/`)` bulleted list, add an entry for the new reference,
**matching the existing entry style** (`` `name.md` `` — one-line description, no
markdown link, same dash-bullet form as the surrounding entries such as the
`init-detection.md` / `unaligned.md` lines). Place it adjacent to the other init/
Unaligned references (e.g. after the `unaligned.md` line) so related references are
grouped. Suggested entry:

> - `migration-recipe.md` — the reusable Unaligned-migrate recipe (ADR 0009 §5/§7):
>   ordered, idempotent cross-reference rewrite (specific-before-generic; negative
>   lookbehind against self-match), the numbered-spine → `spec/` + `status/` split
>   with two-directional link rewrite, the three reference forms, the
>   living-rewritten vs archived-snapshot boundary, the operational preconditions
>   (dirty-tree check, untracked-file handling, NUL-delimited lists), status
>   preservation (per spec 06 §2b), and final link validation.

Do not alter any other `SKILL.md` content.

### Step 3 — Sequential-slice bookkeeping (same plan commit)

This is a sequential slice, so the plan file and the `slice-plans/README.md` Active
entry are written in the **same plan commit** as this plan:

- This plan file exists at `.docs/slice-plans/migration-recipe-reference-plan.md`
  with `Status: Plan Review`.
- Add an **Active plans** entry in
  [`README.md`](README.md) for this slice (replacing the `(none)` placeholder),
  matching the existing Active/Archived entry style.

## Verification

loom's own repo is markdown — there is **no compiled gate**. Acceptance is
**review against spec 06 §2b + ADR 0009 §5/§7** (the plan evaluator, blind). The
mechanical `rg` checks below let the developer and evaluator confirm the new
reference covers each required property and that scope is clean. Run from repo root.
Target file abbreviated as `REF` =
`plugins/loom/skills/loom-playbook/references/migration-recipe.md`.

**A. File exists with the expected header + authority.**
```sh
test -f plugins/loom/skills/loom-playbook/references/migration-recipe.md && echo OK
rg -n 'Migration Recipe' plugins/loom/skills/loom-playbook/references/migration-recipe.md
rg -n '06-init-modes\.md|0009-unaligned-migrate-sub-mode\.md' \
  plugins/loom/skills/loom-playbook/references/migration-recipe.md
```
Expect: file present; title and both authority pointers (spec 06 §2b + ADR 0009)
present.

**B. Preconditions (ADR 0009 §7) all three present.**
```sh
rg -ni 'git status|dirty|stash' plugins/loom/skills/loom-playbook/references/migration-recipe.md   # dirty-tree check
rg -ni 'untracked|git mv .*skip|ls-files --others' plugins/loom/skills/loom-playbook/references/migration-recipe.md  # untracked handling
rg -nF -- '-print0' plugins/loom/skills/loom-playbook/references/migration-recipe.md               # NUL-delimited
rg -nF -- 'xargs -0' plugins/loom/skills/loom-playbook/references/migration-recipe.md
rg -nF -- '$(find' plugins/loom/skills/loom-playbook/references/migration-recipe.md                # called out as anti-pattern
```
Expect: dirty-tree/stash language; untracked-file (`git mv` skips) language; both
`-print0` and `xargs -0`; the `$(find …)` anti-pattern named.

**C. Numbered-spine → spec/ + status/ split, two-directional rewrite.**
```sh
rg -ni 'spine|roadmap|progress|handoff' plugins/loom/skills/loom-playbook/references/migration-recipe.md
rg -nF '../status/' plugins/loom/skills/loom-playbook/references/migration-recipe.md
rg -nF '../spec/'   plugins/loom/skills/loom-playbook/references/migration-recipe.md
rg -ni 'both direction|two-direction|same-directory|outbound|numbering gap' \
  plugins/loom/skills/loom-playbook/references/migration-recipe.md
```
Expect: living-doc extraction to `status/`, rest to `spec/`; **both** `../status/`
and `../spec/` rewrite targets; both-direction + numbering-gap language.

**D. Ordered rules — specific before generic.**
```sh
rg -ni 'specific.*before.*generic|order' plugins/loom/skills/loom-playbook/references/migration-recipe.md
```
Expect: the specific-before-generic ordering stated as a requirement.

**E. Idempotency / self-match / negative lookbehind.**
```sh
rg -ni 'idempoten|re-run|self-match' plugins/loom/skills/loom-playbook/references/migration-recipe.md
rg -nF -- '(?<!\.)' plugins/loom/skills/loom-playbook/references/migration-recipe.md   # negative lookbehind
rg -nF -- '..docs/' plugins/loom/skills/loom-playbook/references/migration-recipe.md   # the artifact it guards against
```
Expect: idempotency/re-run-safe language; the literal `(?<!\.)` lookbehind; the
`..docs/` self-match artifact named.

**F. Three reference forms handled separately.**
```sh
rg -ni 'path-form|markdown link target|prose|backtick' \
  plugins/loom/skills/loom-playbook/references/migration-recipe.md
rg -nF -- '](X.md)' plugins/loom/skills/loom-playbook/references/migration-recipe.md
rg -ni 'relative to.*new location|new location' plugins/loom/skills/loom-playbook/references/migration-recipe.md
```
Expect: all three forms named; the `](X.md)` bare-target example; the "resolves
relative to the new location" note.

**G. Archived-snapshot boundary.**
```sh
rg -ni 'archiv.*snapshot|historical snapshot|not.*rewrit|archive' \
  plugins/loom/skills/loom-playbook/references/migration-recipe.md
```
Expect: living-rewritten vs archived-left-as-history boundary stated; archive
excluded from the rewrite passes.

**H. Status-preservation pointer (not re-derived).**
```sh
rg -ni 'retain.*status|prior status|not a re-review|status preservation' \
  plugins/loom/skills/loom-playbook/references/migration-recipe.md
rg -n '06-init-modes\.md §2b|ADR 0009 §4|§4' \
  plugins/loom/skills/loom-playbook/references/migration-recipe.md
```
Expect: status retained + "not a re-review" + an explicit **pointer** to spec 06 §2b
/ ADR 0009 §4 (policy single-sourced, not restated as the recipe's own rule).

**I. Link validation is the final step.**
```sh
rg -ni 'link validation|validate.*link|final step|last step' \
  plugins/loom/skills/loom-playbook/references/migration-recipe.md
```
Expect: a final link-validation step.

**J. SKILL.md References entry present.**
```sh
rg -n 'migration-recipe\.md' plugins/loom/skills/loom-playbook/SKILL.md
```
Expect: the new reference appears in the `## References` list, matching the existing
backtick-name + dash-description style.

**K. Sequential-slice bookkeeping.**
```sh
rg -n 'migration-recipe-reference' .docs/slice-plans/README.md
rg -n '^Status: Plan Review' .docs/slice-plans/migration-recipe-reference-plan.md
```
Expect: an Active entry in the README; the plan carries `Status: Plan Review`.

**L. Scope guard — only the four allowed paths; NO spec/ADR/unaligned/detection
edits.**
```sh
git diff --name-only HEAD
git status --porcelain
```
Expect exactly these paths and nothing else:

- `plugins/loom/skills/loom-playbook/references/migration-recipe.md`
- `plugins/loom/skills/loom-playbook/SKILL.md`
- `.docs/slice-plans/migration-recipe-reference-plan.md`
- `.docs/slice-plans/README.md`

Hard fail if any out-of-scope path appears:
```sh
git diff --name-only HEAD | rg -n '\.docs/spec/|\.docs/ADR/|references/unaligned\.md|references/init-detection\.md' \
  && echo "FAIL: out-of-scope edit" || echo "OK: scope clean"
```
Expect: `OK: scope clean`.

## Verification Evidence

Gate: loom is markdown-only — no compiled gate. Acceptance is review against spec
06 §2b + ADR 0009 §5/§7.

All mechanical `rg` checks passed:

- **A** — file present; `Migration Recipe` title on line 1; both authority pointers
  (`06-init-modes.md` and `0009-unaligned-migrate-sub-mode.md`) present.
- **B** — dirty-tree/stash language (A.1, lines 27–38); `git ls-files --others`
  untracked handling (A.2, lines 52–53); `-print0` and `xargs -0` present (lines
  66–72/193); `$(find …)` named as anti-pattern (line 75/67).
- **C** — spine/roadmap/progress/handoff all present; `../status/` and `../spec/`
  rewrite targets both present; two-directional rewrite and numbering-gap language
  present.
- **D** — `specific-before-generic` stated as hard requirement (line 123); ordering
  noted as load-bearing (line 133).
- **E** — idempotency/re-run/self-match language present; `(?<!\.)` literal present
  (lines 144/148/219/239); `..docs/` artifact named (lines 140/153/215/223).
- **F** — path-form, markdown link target, backtick/prose all named; `](X.md)` bare
  target example present (line 166); "new location" language present (lines
  114/167).
- **G** — "historical snapshots" boundary stated (lines 182–183); archive excluded
  from rewrite file list (lines 190–193); `archive/` subtree exclusion stated.
- **H** — "retain their prior status" (line 202); "not a re-review" (line 202);
  explicit pointer to `06-init-modes.md §2b` (line 204) and `ADR 0009 §4` (line
  206).
- **I** — "final step" in Step H title (line 211); "last step" stated (line 213).
- **J** — `migration-recipe.md` entry present in `SKILL.md` References list (line 54).
- **K** — Active entry in README present; plan Status updated to Implemented.
- **L** — Scope guard: `OK: scope clean`; only
  `plugins/loom/skills/loom-playbook/references/migration-recipe.md`,
  `plugins/loom/skills/loom-playbook/SKILL.md`, and
  `.docs/slice-plans/migration-recipe-reference-plan.md` modified; no spec/ADR/
  unaligned/init-detection edits.

## Notes

- This is **slice 2 of 3** of the ADR-0009 playbook thread (slice 1 landed
  `c96fd90`; slice 3 — `unaligned.md` split — is **not** part of this slice).
- The recipe is the **mechanical "how"** of the migrate path; the **policy** (owner
  gate, status preservation, init-inline-vs-spawn division) stays single-sourced in
  spec 06 §2b and ADR 0009 §3/§4/§6. The recipe **points to** that policy (esp.
  status preservation per §4) rather than re-deriving it, keeping the frozen spec /
  Accepted ADR authoritative (ADR 0005).
- All recipe content is grounded in the field report's real ballboy migration
  (§4, §5, "Operational failures"); the `(?<!\.)` lookbehind, the `-print0 |
  xargs -0` rule, the `git mv` untracked-skip, and the 08/09/10 living-doc
  extraction are the concrete, battle-tested facts that report records.
- Filename `migration-recipe.md` chosen to match the spec/ADR noun and the
  verb-free, concise style of its sibling `gate-learning.md`.
- **Round-1 FAIL fix (code-eval):** Root `CLAUDE.md` was edited in the original
  implement commit (`a34d726`) — out of scope (the plan authorizes only
  `migration-recipe.md`, `SKILL.md`, the plan, and README) and wrong step (per spec
  03 finalize-pass step 2 + spec 08, `CLAUDE.md` curated-digest maintenance is done
  by the developer's finalize pass *after* code-eval PASS, not in the implement
  commit). `CLAUDE.md` has been restored to its pre-slice baseline (`448898e`).
  `migration-recipe.md` and the `SKILL.md` References entry are correct and
  unchanged. The `CLAUDE.md` curated-digest update will be made by the finalize pass
  after code-eval PASS, per spec 03/08.
