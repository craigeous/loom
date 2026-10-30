# Evaluation — ADR 0027 Client Model Matrix Modernization, Ambient Inheritance, and Antigravity Ratification

Artifact: `.docs/ADR/0027-client-model-matrix-modernization-and-ambient-inheritance.md`
Authority: spec 00-overview, spec 02-roles, spec 10-packaging, ADR 0002, ADR 0018, plan-eval-rubric.md, severity.md
Round: 0
Verdict: FAIL

## Findings

1. **[BLOCKER] Silent supersession of ADR 0018 / ADR 0002.** The ADR reverses ADR 0018 §3 ("tested model … SHALL not silently fall back to an untested model") and ADR 0002's tier-only policy, but never states that it supersedes or amends either. Only spec 10 is named in Consequences. Rubric: "No silent supersession."
2. **[BLOCKER] Contradicts spec 10 / spec 02 invariants without a spec-change path.** Spec 10 says "inheriting a session model or effort is nonconforming", "A missing, unavailable … selector fails launch", and forbids "model fallback". Spec 02 says a missing or untested mapping is an error and adapters never fall back. ADR 0027 mandates ambient inheritance, hardcoded family-default fallback, and a 24h-cached dynamic discovery. Specs are frozen and change only via planner + cold plan evaluation; the ADR claims spec 10 "is amended" as a Consequence rather than scheduling an explicit spec amendment, and does not reconcile spec 02 at all.
3. **[BLOCKER] Antigravity "first-class client family" conflicts with spec 00/10 and ADR 0024.** Spec 00 defines Loom as dual-client (Claude Code + Codex) with a release-gated two-adapter floor; ADR 0024 / CLAUDE.md say private dogfood is not public support or release conformance. The ADR adds a third family and a `claude -> codex -> antigravity -> claude` cycle with no ADR 0018/0019/0022 reconciliation, no floors, no compatibility-matrix/fixture/release-gate implications, and no mention of the 0dd3db9 adapter's current private status.
4. **[MAJOR] Not traceable.** No research note or cited evidence for the Codex error text, `agy models` behavior, Antigravity model IDs, or quota claims. Rubric requires citing the research/problem resolved.
5. **[MAJOR] Exact model IDs in the Decision.** `gpt-6.1-terra`, `claude-opus-5-5-high`, `gemini-4-argon-*` are release data per ADR 0018/spec 02, and ADR 0002 says speak in tiers. Defaults belong in the matrix, not the ADR.
6. **[MAJOR] Undefined/underspecified mechanisms.** `.docs/loom-models.json` (schema, precedence vs `--model`/ambient/matrix), `--effort` (Claude has no effort control per spec 10), "valid" ambient model, cache location/invalidation, and "open model family patterns" (§4) vs fail-closed schema validation are not defined. Ambient inheritance also undermines the cold, reproducible role invocation and the doctor's ability to substantiate supported mode; not addressed.
7. **[MAJOR] Consequences not honest.** No follow-on work (spec 02/10 amendment, matrix v-bump, schema/fixture/test changes, doctor checks, ADR 0018 status note) and no forecloses/risks (weaker reproducibility, silent model drift affecting blind-review comparability, third-client support burden).
8. **[MINOR]** Status/header fine; "Draft" appropriate. Section 4 "current baseline floors" is vague.

## Required for Round 1
State explicit (partial) supersession of ADR 0002/0018; scope the Antigravity ratification against spec 00/ADR 0024 or defer it to a separate ADR; route spec 02/10 changes through a named planner spec amendment; cite research; move concrete IDs to matrix data; define precedence and pinning/discovery contracts; add honest Consequences.
