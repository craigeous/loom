# Init-Mode Detection — one authoritative procedure

Status: Plan Review
Target specs: 06-init-modes.md, 04-orchestrator.md, 08-playbook.md

## Context

M2 is "init modes & gate learning." Spec `06-init-modes.md` defines three modes
(Greenfield / Unaligned / Initialized) and a one-line detection sketch:

```
if no .docs/ and repo is empty/near-empty   → Greenfield
elif no .docs/ (or .docs/ not loom-shaped)  → Unaligned
else                                        → Initialized
```

Today that sketch is restated, **divergently and imprecisely**, in four runtime
places:

- `plugins/loom/commands/run.md` step 1 — "greenfield → scaffold; unaligned →
  alignment pass; initialized → ...".
- `plugins/loom/commands/init.md` step 1 — "Detect init mode: Greenfield /
  Unaligned / Initialized."
- `plugins/loom/commands/status.md` step 1 — "Determine init mode (is there a
  loom-shaped `.docs/`?)."
- `plugins/loom/skills/loom-playbook/references/orchestration.md` →
  *Init-mode detection* — "empty/near-empty", "No/incomplete `.docs/`", "loom-shaped
  `.docs/` exists".

The terms **"empty/near-empty," "incomplete," and "loom-shaped" are undefined**, so
two agents can classify the same repo differently. Every other M2 item runs *inside*
a mode (back-fill is Unaligned-only; gate creation runs in Greenfield/Unaligned;
idempotent re-application is Initialized-only), so an ambiguous classifier is the
shared defect blocking all three.

**This slice makes detection precise, authoritative, and single-sourced.** It adds
one detection reference with a concrete, executable classification procedure and a
defined "loom-shaped" test, then points all four runtime sites at it (removing the
divergent restatements). It does **not** implement the per-mode *behaviors*
(scaffold, back-fill, gate creation, re-application) — those are later M2 slices that
will consume this classifier.

**Out of scope (explicit non-goals):**
- Any change to the per-mode behavior bodies (scaffolding, descriptive back-fill,
  gate establishment, idempotent re-application). Those are separate M2 slices.
- Any change to `.docs/spec/` — specs are frozen; this plan works within `06`.
- New ADRs or design decisions.
- Editing `docs-layout.md`'s canonical tree (it is the source the "loom-shaped"
  test points *at*, not something this slice changes).

## Steps

1. **Create `plugins/loom/skills/loom-playbook/references/init-detection.md`** — the
   single authoritative detection procedure. Content:

   - **Header:** `# Init-Mode Detection` and a one-line purpose ("The classifier
     every `/loom:*` command runs first; the spec is `../../../../.docs/spec/...`
     — here, point to the managed-project equivalent `.docs/spec/06-init-modes.md`").
     Note "Spec `06-init-modes.md` wins on any conflict."

   - **Inputs to inspect** (read-only; no writes during detection):
     - presence of a `.docs/` directory at repo root;
     - whether that `.docs/` is **loom-shaped** (definition below);
     - whether the repo is **empty/near-empty** (definition below).

   - **Definition — "loom-shaped `.docs/`":** a `.docs/` that contains the canonical
     marker set from `docs-layout.md`. Concretely, ALL of:
     - `.docs/spec/README.md` exists, and
     - `.docs/status/` exists with `roadmap.md`, `progress.md`, and `handoff.md`.
     If `.docs/` exists but is missing any of these markers, it is **present but not
     loom-shaped** (treated as Unaligned, not Initialized).

   - **Definition — "empty/near-empty repo":** no tracked source/content beyond
     incidental scaffolding. Concretely, classify as empty/near-empty when
     `git ls-files` returns only files in this allowlist (and nothing else):
     `.git*` (e.g. `.gitignore`, `.gitattributes`), `README*`, `LICENSE*`,
     `.editorconfig`, and an empty-or-near-empty `CLAUDE.md`. Any tracked
     build manifest, source file, or substantive doc means **not** empty/near-empty.
     If the repo has no commits yet, treat the working tree the same way against the
     allowlist.

   - **Classification procedure** (exact order; first match wins):
     ```
     1. loom-shaped .docs/ present?            → Initialized
     2. .docs/ absent AND repo empty/near-empty → Greenfield
     3. otherwise                               → Unaligned
        (covers: no .docs/ in a non-empty repo,
         AND .docs/ present but not loom-shaped)
     ```
     This is a faithful, disambiguated form of the spec-06 sketch: a present-but-not-
     loom-shaped `.docs/` resolves to Unaligned (the spec's "`.docs/` not loom-shaped"
     branch), and Initialized requires the full marker set.

   - **Edge cases** (one line each):
     - `.docs/` present + loom-shaped + repo otherwise empty → **Initialized**
       (loom markers outrank emptiness; rule 1 precedes rule 2).
     - Partial loom scaffold (e.g. `.docs/spec/` exists but `status/` markers
       missing) → **Unaligned**; re-running init/align will complete it.
     - Detection is **read-only**: it never creates or mutates files; acting on the
       mode is the caller's job.

   - **What each mode dispatches to** (pointer only, no behavior bodies): a short
     table — Greenfield → scaffold + apply playbook + establish gate; Unaligned →
     alignment pass (scaffold + playbook + gate + descriptive back-fill); Initialized
     → summarize state and continue — each row linking to `06-init-modes.md` and
     noting "behavior detailed in its own M2 slice; this reference only classifies."

2. **Repoint `orchestration.md` at the new reference.** In
   `plugins/loom/skills/loom-playbook/references/orchestration.md`, replace the body
   of the **"Init-mode detection"** section's per-mode prose with a pointer:
   "Run the classifier in [`init-detection.md`](init-detection.md) first; it returns
   Greenfield / Unaligned / Initialized. Then act per that mode (behaviors per
   `06-init-modes.md` and the relevant M2 slice)." Keep the trailing idempotent-
   re-application sentence. Do not duplicate the classification rules here — the
   reference owns them.

3. **Repoint `commands/init.md` step 1.** Change "Detect init mode: Greenfield /
   Unaligned / Initialized." to "Detect init mode by running the classifier in
   `${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/references/init-detection.md`
   (Greenfield / Unaligned / Initialized)." Leave steps 2–4 (the behavior) unchanged.

4. **Repoint `commands/run.md` step 1.** Change the parenthetical "(see
   orchestration.md)" so it reads "(run the classifier in `init-detection.md` via
   orchestration.md)". Keep the rest of the step's branch list as-is.

5. **Repoint `commands/status.md` step 1.** Change "Determine init mode (is there a
   loom-shaped `.docs/`?)." to "Determine init mode via the classifier in
   `${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/references/init-detection.md`
   (read-only)."

6. **Cross-link from the playbook skill index if one lists references.** Check
   `plugins/loom/skills/loom-playbook/SKILL.md`; if it enumerates the `references/`
   files, add `init-detection.md` to that list. If it does not enumerate them, make
   no change.

## Verification

loom is markdown; **there is no compiled gate on loom's own repo** (CLAUDE.md:
"This repo has no compiled code yet, so it has no concrete gate to run").
Acceptance is by **review against the specs**, not format/lint/test. The reviewing
plan/code evaluator should confirm:

- **Spec fidelity:** the classification procedure in `init-detection.md` is a
  faithful, unambiguous expansion of the `06-init-modes.md` detection sketch — same
  three modes, same precedence, with the previously-vague terms now defined. No new
  behavior or decision is introduced beyond spec 06.
- **Single source of truth:** after this slice, the classification *rules* live only
  in `init-detection.md`; `orchestration.md`, `init.md`, `run.md`, and `status.md`
  reference it rather than restating divergent criteria. Confirm by
  `grep -rn "near-empty\|loom-shaped\|empty/near-empty" plugins/loom/` returning
  matches **only** in `init-detection.md` (and any spec-quote it deliberately keeps).
- **No spec/ADR edits:** `git diff --name-only` touches only files under
  `plugins/loom/skills/loom-playbook/references/`,
  `plugins/loom/commands/`, and `.docs/slice-plans/`. Nothing under `.docs/spec/`
  or `.docs/ADR/`.
- **Links resolve:** every relative/`${CLAUDE_PLUGIN_ROOT}` path added points at a
  file that exists in the tree.
- **Read-only guarantee stated:** `init-detection.md` explicitly says detection
  performs no writes (so `/loom:status`, which must not mutate, can call it safely).

Regression guard: the four repointed call sites must keep their surrounding
behavior steps intact (init still scaffolds/aligns; run still drives the loop;
status still only reports) — only the detection wording changes.

## Notes

<Clarification requests between roles go here, dated. Formal verdicts live in
`.docs/evaluations/`.>
