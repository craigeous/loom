# Evaluation: 10 — Packaging & Distribution

Verdict: FAIL
Round: 1
Reviewed against: ADRs 0001, 0002, 0006; spec 07 (Approved); the real
`plugins/loom/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`,
the repo tree, the shipped `agents/*.md`, README.md, and the cited research note
`.docs/research/2026-06-07-claude-code-plugin-mechanics.md`.

## Findings

- [BLOCKER] Agent-frontmatter "verified fields" list misstates the manifest
  contract — spec §"Agent frontmatter (verified fields)" (lines 65–72). The spec
  claims plugin agents support `name, description, model, effort, maxTurns,
  tools, disallowedTools, skills, memory, background, isolation`. The only
  authority cited for plugin mechanics (the June-2026 research note, agent table
  at lines 71–84) verifies a *different, smaller* set: `name, description, model,
  color, tools`. (a) The spec **omits `color`**, which that authority marks
  *required* and which all five shipped agents actually carry
  (`researcher.md: color: cyan`, etc.). (b) The spec **adds seven fields**
  (`effort, maxTurns, disallowedTools, skills, memory, background, isolation`)
  that no authority in this repo verifies and that nothing in the built plugin
  uses. Calling them "verified" is not supported. The defect is load-bearing: the
  spec then asserts "`isolation: \"worktree\"` and `background` are the built-ins
  loom's M3 parallelism uses," resting a design dependency on unverified manifest
  fields. For a packaging spec whose job is to describe the manifest format
  accurately, asserting unverified fields as verified and dropping an
  actually-used required field is a spec-fidelity error, not a nit.

- [MINOR] `marketplace.json` example drifts from the real catalog — spec lines
  76–89. The real `.claude-plugin/marketplace.json` carries a top-level
  `description` ("loom — a spec-driven, multi-agent development loop with blind
  evaluation") that the spec's block omits, and the real plugin-entry description
  is "Spec-driven multi-agent development loop **with blind evaluation**" vs the
  spec's "Spec-driven multi-agent development loop". Load-bearing fields (`name`,
  `owner`, `source: "./plugins/loom"`, `category`) all match.

- [MINOR] `<owner>` placeholder is now stale — spec lines 56–57, 97. The owner is
  known (`craigeous`), and the real `plugin.json`, marketplace, and README all use
  `craigeous/loom`. The spec (and ADR 0006) still say `<owner>`. Not drift to a
  wrong/capitalized path — the placeholder is correct in form and matches its ADR
  authority — but the spec could now name the concrete lowercase `craigeous/loom`
  to match the shipped artifacts and README install string.

## Required changes (for FAIL)

1. Correct the agent-frontmatter section to the set the cited authority actually
   verifies: `name, description, model, color, tools` (add `color`; mark it
   required as the research does). Remove `effort, maxTurns, disallowedTools,
   skills, memory, background, isolation` — or, if loom intends to rely on
   `isolation`/`background` for M3 parallelism, cite a real source that verifies
   those fields and drop the unqualified "verified" label until then. Reconcile
   the dependent sentence about M3 parallelism with whatever is actually
   verifiable.

## Notes

Everything the review targeted as likely drift is in fact accurate: `source:
"./plugins/loom"` is correct in spec, ADR 0006, and the real catalog; the
root-plugin (`source: "."`) form the research recommended was correctly rejected
and is not claimed anywhere in the spec; namespacing is correctly stated as
`loom:<name>` with no bare `/loom`; the command surface (`run, research, plan,
eval-plan, develop, eval-code, status, init`) matches spec 07 and the real
`commands/` dir; the GitHub path is lowercase; and the `plugin.json` block matches
the real manifest field-for-field (name, version 0.1.0, identical description,
author, license, keywords) modulo the `<owner>` placeholder. The single blocker is
the agent-frontmatter field list, which is the one place the spec asserts manifest
facts its own cited authority does not support and the shipped plugin contradicts.
-->

---

# Evaluation: 10 — Packaging & Distribution (Round 2)

Verdict: PASS
Round: 2
Reviewed against: the same authorities as Round 1 (ADRs 0001, 0002, 0006; spec 07;
the real `plugin.json`, `.claude-plugin/marketplace.json`, the repo tree, all five
shipped `agents/*.md`, `references/orchestration.md`, README, and the cited
research note `.docs/research/2026-06-07-claude-code-plugin-mechanics.md`), plus
`git show a651107` and the current file.

## Round 1 findings — disposition

- [BLOCKER] Agent-frontmatter "verified fields" — **RESOLVED.** The section now
  states the five shipped agents use "exactly five frontmatter fields:
  `name`, `description`, `model`, `color`, `tools`," with `color` restored and
  `name` marked required. This matches the cited authority's agent table
  (research note lines 73–79: `name/description/model/color` required, `tools`
  optional) field-for-field, and matches all five shipped agents — verified each
  of `code-evaluator.md`, `developer.md`, `plan-evaluator.md`, `planner.md`,
  `researcher.md` carries exactly those five keys (e.g. `researcher.md`:
  `color: cyan`). The seven previously-asserted unverified fields are removed.
  The dependent M3 claim is reframed: `isolation: "worktree"`/`background` are now
  explicitly "**not** part of today's verified manifest" — a "planned M3
  parallelism mechanism" sourced to `references/orchestration.md`, whose
  "Parallelism (M3, not yet)" section (lines 68–73) does name exactly
  `isolation: "worktree"` and `background` agents. The link path (`../../plugins/
  loom/skills/...`) resolves correctly from `.docs/spec/`. No "verified" label now
  rests on an unverified field.

- [MINOR] marketplace.json example mismatch — **RESOLVED.** The spec block now
  carries the top-level `description` and the "with blind evaluation" plugin-entry
  description, matching the real `.claude-plugin/marketplace.json` line-for-line.

- [MINOR] stale `<owner>` placeholder — **RESOLVED.** `plugin.json` homepage/
  repository and the install-flow `marketplace add` line now use the concrete
  lowercase `craigeous/loom`, matching the shipped manifests and README.

## New findings

None. No new contradiction introduced by the revision; the rest of the spec is
unchanged from Round 1, where it was already accurate against its authorities.

## Verdict

All Round 1 findings (the one blocker and both minors) are resolved with no
regressions. The spec describes the manifest format accurately against its cited
authority and the shipped plugin. PASS.
