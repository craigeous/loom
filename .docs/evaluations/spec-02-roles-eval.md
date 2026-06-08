# Evaluation: 02 — Roles

Verdict: FAIL
Round: 1
Reviewed against: ADR 0001 (orchestrator/plugin), 0002 (model tiers), 0003 (cold
handoffs / commit-per-handoff), 0004 (blind eval / role separation), 0005 (specs
frozen); the five built agents `plugins/loom/agents/{researcher,planner,
plan-evaluator,developer,code-evaluator}.md`; sibling specs 03-artifact-lifecycle,
04-orchestrator, 05-blind-evaluation, 09-open-questions, 10-packaging; the
plan-eval rubric and severity taxonomy.

## Findings

- [MAJOR] Stale command reference — the spec names the orchestrator command as
  bare `/loom`, which contradicts a non-negotiable declared in two sibling specs
  and points readers at a surface that does not exist (artifact line 8: "the
  **orchestrator** (the main session running `/loom`, see [04]...)").
  - Spec 09 line 51: "components are namespaced — there is **no bare `/loom`**."
  - Spec 10 line 40: "Plugin components are **namespaced by plugin name** — there
    is **no bare `/loom`**."
  - The real command surface is `/loom:run` (spec 04 lines 8–9: "the main,
    interactive Claude Code session that runs when you invoke `/loom:run`. The
    `commands/run.md` body is its operating instructions"); the built command file
    is `plugins/loom/commands/run.md`.
  - Because spec 02 is the authority describing the orchestrator-vs-role boundary,
    a reader following it would invoke a command that isn't installed. This is a
    consistency/fidelity defect against the declared naming rule, not a style nit.

## Required changes (for FAIL)

1. Line 8: change "the main session running `/loom`" to "the main session running
   `/loom:run`" (matching spec 04 and the built `commands/run.md`). This is the
   only blocking change.

## Notes

This is a strong, accurate roles spec; the single MAJOR is one stale command
token. Everything load-bearing checks out against the built agents and the
authority:

- **Five roles, no more/fewer, correct tiers.** researcher `haiku`, planner
  `opus`, plan-evaluator `opus`, developer `sonnet`, code-evaluator `opus` —
  matches every agent's frontmatter `model:` field and the ADR 0002 table exactly.
  No renamed/missing/extra roles.
- **Self-approval guarantee / cold-anonymous / orchestrator-is-not-a-role** —
  faithful to ADR 0001 and 0004 and spec 05.
- **Researcher** — citations-mandatory contract, writes a dated note to
  `research/`, sets `Research Review`, commits; reads-list and loop match the
  agent and spec 03's research lifecycle.
- **Planner** — sole writer of `spec/`+`ADR/`, never implements, ADR 0005 freeze,
  ADR immutability, finalize updates `status/`; matches the planner agent and ADR
  0005. "Developers never edit specs" is correctly asserted.
- **Plan evaluator** — reads only artifact + upstream authority + rubric, never
  author identity/reasoning; the four authority pairings (slice-plan→spec/ADR,
  spec→ADR, ADR→research, research→sources) match the agent's "What you judge
  against" and spec 05. The "light research check / may run on a lower tier"
  caveat matches spec 05 and the open question in spec 09.
- **Developer** — implements approved slice-plan, never edits specs/ADRs, stops
  and flags a planning need on a wrong spec, gate format→lint→test, finalize pass
  (cold) updates `status/progress.md`+`handoff.md`, archives the plan, lands the
  branch. Matches the developer agent and ADR 0005.
- **Code evaluator** — reads only the commit diff + slice-plan + specs + gate
  evidence, never identity; "on PASS the orchestrator triggers the finalize pass,
  on FAIL status returns to `In Progress`" is consistent with the agent (sets
  `Landed` on PASS) and spec 03's `Landed → developer finalize` dispatch.
- **Clarification flow** — `## Notes` + `Needs Clarification` + status restoration
  matches spec 03's clarification sub-flow.
- **Tiers-not-versions** correctly cited to ADR 0002; **commit-per-handoff** is
  implied throughout and consistent with ADR 0003.

No other terminology drift was found: no "skill"-as-product misuse, no renamed
dirs, no roles described as editing things their agent forbids. The spec is prose
style (like the approved 01-concepts) rather than the granular `## Authority /
## Design / ## Out of scope` template; consistent with the rest of the spine, so
not flagged.

Non-blocking observations recorded for follow-up (MINOR, do not gate this spec):

- Researcher tool list (line 28) reads "Read, Grep, Glob, WebSearch, WebFetch (+
  available MCP readers)"; the built agent's frontmatter also carries **Bash**
  (used for its commit step) and does not enumerate MCP readers. Slight drift;
  harmless to the role's description.
- Developer finalize (line 92–93) lists `status/progress.md` + `status/handoff.md`
  but omits the "(and `roadmap.md` if a milestone closed)" that the agent and spec
  03 include. Omission, not contradiction.
- The developer loop (lines 88–90) summarizes the gate as "on green, set
  `Implemented`" and does not mention the agent's red-gate escalation rule (a red
  gate — even pre-existing/out-of-scope — blocks `Implemented` and routes to
  `Needs Clarification`). Acceptable elision for an overview spec, but worth a
  one-line mention if revised.

---

# Evaluation: 02 — Roles (Round 2)

Verdict: PASS
Round: 2
Reviewed against: the Round 1 verdict above; `git show 7f53911` (the revision);
the built agents `plugins/loom/agents/{researcher,developer}.md`; sibling specs
04-orchestrator, 09-open-questions, 10-packaging; the plan-eval rubric and
severity taxonomy.

## Re-review of prior findings

All four Round 1 findings are resolved, each verified against the real authority,
and none introduced a new contradiction:

- **[blocking] Bare `/loom` → `/loom:run` (line 8).** Fixed. Now matches spec 04
  line 8 ("invoke `/loom:run`") and the "no bare `/loom`" namespacing rule in
  spec 09 line 51 and spec 10 line 40. A reader following spec 02 now lands on a
  command that exists.
- **[MINOR] Researcher tool list omitted `Bash` (line 28).** Fixed. Now reads
  "Read, Grep, Glob, WebSearch, WebFetch, Bash (+ available MCP readers)",
  matching `researcher.md` frontmatter `tools:` exactly.
- **[MINOR] Finalize omitted `roadmap.md` (lines 98–100).** Fixed. Now reads
  "(and `status/roadmap.md` if a milestone closed)", matching `developer.md`
  finalize step 1.
- **[MINOR] Developer loop omitted the red-gate escalation rule.** Fixed by a new
  bullet (lines 92–96): a red gate blocks `Implemented` regardless of cause, the
  gate is a whole-tree property, pre-existing/out-of-scope failures still route to
  `Needs Clarification` with the red baseline recorded, and "not my code" is never
  an exception. Faithful to `developer.md` step 4 and the quality-bar reminder.

## Findings

None. No `BLOCKER`/`MAJOR` remains. The added red-gate paragraph is internally
consistent with the loop summary that follows it (the loop's "on green, set
`Implemented`" now reads correctly as the happy path qualified by the new rule),
and the finalize/tool-list edits are pure alignment with the built agents. No new
drift was introduced elsewhere in the file.

## Notes

The substantive content confirmed in Round 1 (five roles, correct tiers,
self-approval guarantee, per-role reads/writes/loops, clarification flow) is
unchanged by this revision and still checks out against the agents and ADRs.
Status set to `Approved`.
