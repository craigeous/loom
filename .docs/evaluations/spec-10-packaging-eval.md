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

---

# Evaluation: 10 — Packaging & Distribution (Round 3)

Verdict: PASS
Round: 3
Reviewed against: ADR 0007 (`0007-namespaced-command-surface.md`), the Approved
spec 07 (`07-command-surface.md`), spec 10's own line-40 "no bare `/loom`" rule,
plus `git show a9967bb` (the revision under review) and the current file. This is
a narrow re-review of a single fix to a previously-Approved spec.

## Scope of the revision

`git show a9967bb --numstat` reports a single touched file (`.docs/spec/10-packaging.md`,
+3/-2). The diff is exactly two hunks: (1) `Status: Approved` → `Status: Plan
Review`, and (2) line 107's reword. Nothing else changed; the body Approved in
Round 2 is otherwise byte-identical. Confirmed no regression outside the intended
fix.

## Findings

- Line 107 fix — **CORRECT.** The old text `Then, inside any repo, \`/loom\`
  operates on that repo's \`.docs/\`` used a bare command-style `/loom`,
  contradicting line 40's rule and ADR 0007 §"no bare `/loom` command." The new
  text reads `\`/loom:run\` operates on that repo's \`.docs/\` (with the one-off
  \`/loom:<role>\` commands also available)`. This matches ADR 0007 lines 30–36
  (orchestrator is `/loom:run`; one-off `/loom:<name>` commands) and spec 07 lines
  16–23 (`/loom:run [scope]` + the one-off table). Internally consistent with line
  40–41's own statement of the surface. No new error introduced.

- Mechanical-check dogfood (`rg -nP '/loom' .docs/spec/10-packaging.md`) —
  **CLEAN.** Every non-namespaced `/loom` occurrence is legitimate: line 40 is the
  rule statement itself ("there is no bare `/loom`"); lines 13, 18, 22, 45, 48, 67,
  75, 89 are file/dir paths (`plugins/loom/`, `skills/loom-playbook/`,
  `./plugins/loom`); lines 56–57 are GitHub URLs (`github.com/craigeous/loom`);
  line 103 is the repo path `craigeous/loom` and the local `./loom`. The only
  command-style `/loom` occurrences are now namespaced: line 22 (`/loom:run` +
  `/loom:<role>`), line 41 (`/loom:<filename>`), line 107 (`/loom:run`,
  `/loom:<role>`). No remaining bare command-style `/loom`.

## New findings

None.

## Verdict

The targeted fix is correct and internally consistent; ADR 0007 and spec 07 are
satisfied; the line-40 rule is honored throughout; and the diff is limited to the
intended fix with no regression to the rest of the Round-2-Approved spec. PASS.

Grep result (`rg -nP '/loom' .docs/spec/10-packaging.md`):

```
13:lives under `plugins/loom/`.
18:│   └── marketplace.json               # catalog: lists loom at source ./plugins/loom
22:│       ├── commands/                  # /loom:run + one-off /loom:<role> commands
40:Plugin components are **namespaced by plugin name** — there is no bare `/loom`. The
41:surface is **one file per command** (each → `/loom:<filename>`): `run` (the
45:`skills/loom-playbook/references/orchestration.md` so the thin command files stay
48:## plugin.json (`plugins/loom/.claude-plugin/plugin.json`)
56:  "homepage": "https://github.com/craigeous/loom",
57:  "repository": "https://github.com/craigeous/loom",
67:The five shipped agents (`plugins/loom/agents/*.md`) use exactly five frontmatter
75:[`../../plugins/loom/skills/loom-playbook/references/orchestration.md`](../../plugins/loom/skills/loom-playbook/references/orchestration.md)
89:      "source": "./plugins/loom",
103:/plugin marketplace add craigeous/loom    # or:  /plugin marketplace add ./loom  (local)
107:Then, inside any repo, `/loom:run` operates on that repo's `.docs/` (with the
108:one-off `/loom:<role>` commands also available). For local
```
