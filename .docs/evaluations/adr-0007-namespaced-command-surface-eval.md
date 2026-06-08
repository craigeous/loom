# Evaluation: ADR 0007 — Namespaced Command Surface

Verdict: PASS
Round: 1
Reviewed against: ADR 0001 (plugin architecture), Approved spec 07 (command
surface), Approved spec 10 (packaging), spec 09 OQ-D (resolved), the live
surface in `plugins/loom/commands/*.md` and `plugins/loom/agents/*.md`, the ADR
template, and the supersession changes in commit `ca24d66`.

## Findings

- [MINOR] Spec 10 (`.docs/spec/10-packaging.md`, line 107) still contains a live
  bare `/loom` ("inside any repo, `/loom` operates on that repo's `.docs/`").
  This is a pre-existing Approved-spec wording, not introduced by this ADR, and
  is exactly the kind of stale reference ADR 0007's Consequences directive
  ("must use the namespaced form ... must not introduce a bare `/loom`") would
  catch on the next planning touch of that spec. Out of scope for accepting this
  ADR; flagged for follow-up so the decision-of-record and its own cited spec
  stay aligned.

## Required changes (for FAIL)

None — PASS.

## Notes

Verification performed:

1. **Template / form.** Uses the ADR template (Context / Decision /
   Consequences), correct `Status:` line, correct location and `NNNN-title`
   naming. Decision is stated as directives; Consequences names follow-on work
   (plugin rename = new planning cycle) and what it forecloses. Traceable: cites
   OQ-D resolution, specs 07/10, and ADR 0001.

2. **Surface accuracy — commands.** ADR lists `run, research, plan, eval-plan,
   develop, eval-code, status, init` (8). `plugins/loom/commands/` contains
   exactly `run.md, research.md, plan.md, eval-plan.md, develop.md, eval-code.md,
   status.md, init.md` — exact match, no extras, none missing. `/loom:run` named
   as orchestrator, consistent with spec 07's table.

3. **Surface accuracy — agents.** ADR lists `loom:researcher, loom:planner,
   loom:plan-evaluator, loom:developer, loom:code-evaluator` (5).
   `plugins/loom/agents/` contains exactly `researcher.md, planner.md,
   plan-evaluator.md, developer.md, code-evaluator.md` — exact match. Namespace
   form `loom:<role>` matches spec 07/10.

4. **Supersession scope (immutable-ADR rule).** The 0001 edit in `ca24d66` adds
   ONLY a pointer Note block; the diff touches no line of 0001's Decision or
   reasoning — mark, don't rewrite, satisfied. Scope is correctly narrow: 0007
   supersedes only the bare-`/loom` command-naming; it explicitly preserves
   0001's plugin architecture and orchestrator-spawns-roles decision. "Out of
   scope" enumerates ADR 0001 architecture, ADR 0002 tiers, and spec 10 layout.
   No silent supersession: stated in Context, in Consequences, and surfaced in
   the ADR README. README entry placed under a new "In Review" heading,
   consistent with the ADR's `Plan Review` status at authoring time.

5. **Consistency with authorities.** Matches spec 07, spec 10, and the resolved
   OQ-D verbatim on the surface and namespacing. No contradictions found.

6. **Bare `/loom` scan of the artifact.** Every bare-`/loom` token in the ADR is
   either a deliberate quotation of the superseded form, an explicit negation
   ("There is no bare `/loom`"), a path fragment (`plugins/loom/`), or the
   `loom:<role>` agent form. No accidental live bare-`/loom` directive.
