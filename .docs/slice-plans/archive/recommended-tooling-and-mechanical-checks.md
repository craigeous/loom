# Recommended Tooling Reference + Mechanical-Invariant-Check Rubric

Status: Archived
Target specs: 08-playbook.md

## Context

Two retroactive spec reviews this session each missed a defect that an eyeball
pass should not be trusted with:

- a **bare `/loom`** left in prose (spec 10, line 107) — the convention is the
  namespaced `loom:<name>` / `/loom:<name>`, never bare `/loom`; and
- a **line-wrapped `Code\nReview`** status token that a line-based `grep` could
  not see because the token spanned a line break.

The lesson is general: invariants must be checked **mechanically** (e.g.
`rg -U` for multiline/wrapped text, `yq`/`jq` for config facts, `ast-grep` or LSP
find-references for code symbols), not by reading. The owner has approved adding a
recommended-toolkit reference to the playbook plus a rubric rule that makes
mechanical verification of invariants explicit for both evaluators.

The playbook (spec [08-playbook.md](../spec/08-playbook.md)) is loom's evolving
conventions; `references/` holds convention docs and the evaluator rubrics. This
slice adds one new reference and extends the two rubrics — squarely within spec
08's scope. It changes **no** behavior contract: every tool is framed
**RECOMMENDED, not required**, with detect-and-prefer and a named graceful
fallback, the same discipline loom already applies to gates (a tool is never
hard-required).

**Out of scope:**
- Editing `.docs/spec/` or `.docs/ADR/` (frozen; this is a playbook/convention
  change, not a spec change). No new ADR is needed — no decision is being reversed
  or constrained beyond what spec 08 already authorizes.
- Fixing the two motivating defects themselves (the bare `/loom` and the wrapped
  token) — those are separate corrective slices; this slice only adds the tooling
  reference and the check discipline.
- Adding tool *installation* steps or any hard dependency. loom must run with none
  of these tools present.
- A `gates/shell.md` definition — this slice only adds an optional `shellcheck`
  pointer note where it fits cleanly (see step 5); a full shell gate is a
  follow-up.

## Steps

### 1. Create `references/tooling.md`

Create
`plugins/loom/skills/loom-playbook/references/tooling.md` with the structure
below. Authorship target is concrete, role-organized guidance with a fallback for
every tool. Use exactly these sections:

**Title + policy header (top, must be unambiguous):**

- `# Recommended Tooling`
- A `> ` policy callout stating verbatim the discipline: *all tools here are
  **RECOMMENDED, not required**; loom never hard-requires a tool (same rule as
  gates). Detect-and-prefer: if the tool is on `PATH` (or the language server is
  available), use it; otherwise fall back to the named alternative. A missing tool
  is never a blocker.*
- One sentence distinguishing scope: most of these help on **managed CODE
  projects**; loom's **own markdown repo** benefits mainly from `rg -U`,
  `yq`/`jq`, and the mechanical-check discipline.

**The mechanical-check principle (short section):** state the lesson — invariants
are verified mechanically, not by reading; cite the two motivating misses
(bare `/loom`; wrapped `Code\nReview` a line-based grep can't see) as the reason.
This is the prose the rubric rule (steps 3–4) points back to.

**Task → preferred tool → fallback table.** A compact table. Rows (at minimum):

| Task | Preferred | Fallback |
|------|-----------|----------|
| Multiline / wrapped-token text invariant | `rg -U` | `grep` + `tr -d '\n'`, or careful read |
| Config fact in YAML/JSON/TOML | `yq` / `jq` | careful manual read |
| Structural code search / refactor | `ast-grep` (`sg`) | `rg` |
| Structural search/replace ast-grep can't express | `comby` | manual edit |
| Syntax-aware diff of a commit | `difft` (difftastic) | `git diff` |
| "Did this change break callers?" / jump-to-def / type errors | LSP / code-intelligence find-references | read + `rg` for the symbol |
| Lint generated shell | `shellcheck` | manual review |
| Language / LOC detection at init | `scc` | `rg --files` + extension counting |

**By-role guidance.** One short subsection per role, each naming the concrete
tool, the concrete moment to reach for it, and the fallback. Cover:

- **Researcher** — mostly reads/cites; `rg -U` to confirm a claimed string truly
  exists (and isn't line-wrapped past a line-based grep) before citing it.
- **Planner** — when a plan asserts an invariant ("no bare `/loom`", "manifest
  key X = Y"), verify it with `rg -U` / `yq` against the real tree before writing
  it as fact, rather than trusting a read. (This is the same "verify references
  against the real tree" discipline already in the planner's rules.)
- **Developer** — on managed CODE projects: `ast-grep` / LSP find-references to
  verify signatures, types, and callers against the tree (makes developer.md
  step 3 "don't code from memory" deterministic); `shellcheck` on generated
  shell. On loom's markdown repo: `rg -U` to confirm cross-links and tokens.
- **Plan-evaluator** — verify any invariant the plan claims with `rg -U` / `yq`
  rather than eyeballing the artifact (a wrapped token or a bare `/loom` survives
  a read).
- **Code-evaluator** — `difft` for a syntax-aware view of the commit diff;
  `ast-grep` / LSP find-references to answer "did this diff break callers?";
  `rg -U` over the diff/tree for text invariants. Still re-runs the gate — these
  augment, never replace, the gate.

**Nice-to-have (not correctness-relevant):** one line noting `hyperfine`,
`watchexec`, `delta` exist but are out of scope for invariant-checking.

**Provenance line:** note that the LSP / code-intelligence guidance derives from
Claude Code's code-intelligence capability (jump-to-definition,
find-references, post-edit type errors).

Keep every tool entry in the form "prefer X; fall back to Y" so no entry reads as
a requirement.

### 2. Add `tooling.md` to the playbook index (`SKILL.md`)

In `plugins/loom/skills/loom-playbook/SKILL.md`, in the
**References (`references/`)** bullet list (currently ending with the `greenfield.md`
bullet at line 52), append one bullet:

```
- `tooling.md` — **recommended** CLI/LSP toolkit by role, and the mechanical
  invariant-check discipline (verify with `rg -U`/`yq`/`ast-grep`/LSP, not by eye).
  All tools optional with graceful fallback.
```

Do not reorder or alter the other bullets.

### 3. Add the mechanical-check rule to `plan-eval-rubric.md`

In `plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md`, under the
**## Slice-plans** section, append a new bullet after the existing
`Verification named` bullet (the last bullet in that section, line 40–41):

```
- **Invariants verified mechanically** — any invariant the plan asserts (e.g.
  "no bare `/loom`", a config key's value, a symbol's callers) must be checkable
  with a tool, not by eye: `rg -U` for text/wrapped-token invariants, `yq`/`jq`
  for config facts, `ast-grep`/LSP find-references for code-symbol invariants.
  Do not approve (or assert) an invariant established by reading alone. See
  [`tooling.md`](tooling.md).
```

### 4. Add the mechanical-check rule to `code-eval-rubric.md`

In `plugins/loom/skills/loom-playbook/references/code-eval-rubric.md`, under the
**## Correctness** section, append a new bullet after the `Tests prove behavior`
bullet (the last bullet in that section, line 28–30):

```
- **Invariants verified mechanically** — check invariants with a tool, never by
  eye: `rg -U` for text/wrapped-token invariants (a line-based grep cannot see
  `Code\nReview`), `yq`/`jq` for config facts, `ast-grep`/LSP find-references for
  code-symbol invariants and "did this diff break callers?". Never assert an
  invariant (e.g. "no bare `/loom`") from reading alone. See
  [`tooling.md`](tooling.md).
```

### 5. Cross-link `tooling.md` from the agent files

Add one short pointer line to each of the three agents (use the
`${CLAUDE_PLUGIN_ROOT}` path form, matching how the agents already reference the
playbook, e.g. plan-evaluator.md line 37):

- **`plugins/loom/agents/developer.md`** — in `## How you work` step 3 (the
  "Verify signatures/types against the tree — don't code from memory" sentence,
  lines 23–24), append: *Prefer `ast-grep`/LSP find-references over reading where
  available (see `${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/references/tooling.md`);
  all such tools are optional with fallback.*

- **`plugins/loom/agents/plan-evaluator.md`** — in `## How you work` step 1
  (lines 43–45), append a sentence: *Verify any invariant the artifact asserts
  mechanically (`rg -U`/`yq`), not by eye — see
  `${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/references/tooling.md`.*

- **`plugins/loom/agents/code-evaluator.md`** — in `## How you work` step 1
  (lines 27–29), append a sentence: *Check text/config/symbol invariants
  mechanically (`rg -U`/`yq`/`ast-grep`/LSP), not by eye — see
  `${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/references/tooling.md`; all optional
  with fallback.*

Each is a single appended pointer; do not restructure the steps.

### 6. Optional `shellcheck` pointer in `gates/` (include only if clean)

The only shipped gate is `gates/rust.md`; there is no shell gate to attach to.
Therefore do **not** invent a `gates/shell.md` in this slice. `shellcheck`
already appears in `tooling.md` (developer guidance + the task table) framed as
the optional lint for generated shell — that is sufficient. Record in this plan's
`## Notes` that a verified `gates/shell.md` (with `shellcheck` as its lint step)
is a clean follow-up slice when a shell-stack project is first encountered.

### 7. Update the slice-plans active index

In `.docs/slice-plans/README.md`, replace the `## Active plans` body (currently
`(none)`, line 20) with a one-line entry for this plan:

```
- [recommended-tooling-and-mechanical-checks.md](recommended-tooling-and-mechanical-checks.md) — `Plan Review` —
  add a recommended CLI/LSP toolkit reference (`references/tooling.md`) + a
  mechanical-invariant-check rule in both eval rubrics; cross-link from SKILL.md
  and the three relevant agents.
```

## Verification

This repo is markdown (prompts/conventions); the gate is **review-against-spec**,
not a compile/test gate (CLAUDE.md: "No compiled code… this repo has no gate to
run"). The reviewer confirms, **mechanically where possible** (dogfooding the very
rule this slice adds):

1. **New file present & policy correct** — `tooling.md` exists; its top states
   "RECOMMENDED, not required" + detect-and-prefer + per-tool fallback. Confirm no
   tool is framed as required:
   `rg -Ui 'must install|requires? .*(ast-grep|yq|difft|shellcheck|comby|scc)|hard.?require' plugins/loom/skills/loom-playbook/references/tooling.md`
   returns nothing.
2. **Every tool has a fallback** — each row of the task table and each role entry
   names a fallback; no orphan tool. (Read against the step-1 spec.)
3. **Rule present in BOTH rubrics** — exactly one mechanical-check bullet in each:
   `rg -l 'mechanically' plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md plugins/loom/skills/loom-playbook/references/code-eval-rubric.md`
   lists both files.
4. **Cross-links resolve** — every `tooling.md` link target exists.
   `rg -n 'tooling\.md' plugins/loom/skills/loom-playbook/SKILL.md plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md plugins/loom/skills/loom-playbook/references/code-eval-rubric.md plugins/loom/agents/developer.md plugins/loom/agents/plan-evaluator.md plugins/loom/agents/code-evaluator.md`
   shows a reference in each of the six files, and the referenced
   `references/tooling.md` exists on disk.
5. **Internal consistency** — the tool set, fallbacks, and the two motivating
   examples are stated identically across `tooling.md` and both rubric bullets (no
   tool named in a rubric that is absent from `tooling.md`).
6. **Scope discipline** — `git diff --stat` touches only: the new
   `references/tooling.md`, `SKILL.md`, both rubric files, the three named agent
   files, and `.docs/slice-plans/README.md`. **No** change under `.docs/spec/` or
   `.docs/ADR/`, and **no** new `gates/` file.

There is no behavior to regression-test; the guard against regression is scope
discipline (check 6) — nothing outside the listed files changes.

## Notes

- Follow-up (not this slice): when loom first manages a shell-stack project, add a
  verified `gates/shell.md` whose lint step is `shellcheck`, learned and recorded
  per the init gate-learning flow (spec 06 / 08). `shellcheck` is already
  referenced from `tooling.md` so the follow-up only formalizes it as a gate step.
- Kept as a **single slice**: although it touches seven files, it is one coherent
  goal — "adopt the recommended toolkit + mechanical-check discipline" — and each
  edit is a small additive pointer/rule/entry off the one new reference. There is
  no second independent goal to split out.
- Step 7 (slice-plans README active entry) was already present on disk (committed
  with the plan at 9e567ab per the eval MINOR finding); treated as already-satisfied.

## Gate Evidence (review-against-spec; dogfooding rg -U/grep per the slice's own rule)

This repo has no compiled gate. Verification is review-against-spec.

**Check 1 — No "must install" / hard-require phrasing in tooling.md:**
`rg -Ui 'must install|requires? .*(ast-grep|yq|difft|shellcheck|comby|scc)' plugins/loom/skills/loom-playbook/references/tooling.md`
→ exit 1 (no matches). Policy header says "RECOMMENDED, not required … never
hard-requires … A missing tool is never a blocker". PASS.

**Check 2 — Every tool has a fallback:**
Task table has 8 rows; each has a non-empty Fallback column. Each role subsection
names a fallback. No orphan tool. PASS.

**Check 3 — Mechanical-check rule in BOTH rubrics:**
`rg -l 'mechanically' plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md plugins/loom/skills/loom-playbook/references/code-eval-rubric.md`
→ lists both files. PASS.

**Check 4 — Cross-links resolve in all six files:**
`rg -n 'tooling\.md' SKILL.md plan-eval-rubric.md code-eval-rubric.md developer.md plan-evaluator.md code-evaluator.md`
→ one match in each of the six files. Target file
`plugins/loom/skills/loom-playbook/references/tooling.md` exists on disk. PASS.

**Check 5 — Internal consistency:**
Both rubric bullets name `rg -U`, `yq`/`jq`, `ast-grep`/LSP — all present in
tooling.md's task table and per-role sections. The two motivating misses (bare
`/loom`, wrapped `Code\nReview`) appear in tooling.md's mechanical-check section
and in the code-eval rubric bullet. PASS.

**Check 6 — Scope discipline:**
`git diff --name-only HEAD` (after staging) shows only:
  - `plugins/loom/skills/loom-playbook/references/tooling.md` (new)
  - `plugins/loom/skills/loom-playbook/SKILL.md`
  - `plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md`
  - `plugins/loom/skills/loom-playbook/references/code-eval-rubric.md`
  - `plugins/loom/agents/developer.md`
  - `plugins/loom/agents/plan-evaluator.md`
  - `plugins/loom/agents/code-evaluator.md`
  - `CLAUDE.md` (update-before-commit rule)
  - `.docs/slice-plans/recommended-tooling-and-mechanical-checks.md` (this file)
No `.docs/spec/` or `.docs/ADR/` edits. No new `gates/` file. PASS.
