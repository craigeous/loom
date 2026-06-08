# Evaluation: spec/00-overview.md

Verdict: FAIL
Round: 1
Reviewed against: ADR 0001–0006 (Accepted authority); sibling specs 02-roles,
03-artifact-lifecycle, 06-init-modes (Approved), 07-command-surface, README; and
the built plugin tree under `plugins/loom/` (commands/, agents/, skills/).

## Findings

- [BLOCKER] Misidentifies the product as a "skill." Line 7: "loom is a Claude
  Code **skill**." The governing accepted ADR 0001 states "loom is a **Claude
  Code plugin**," and every sibling artifact agrees — spec README ("loom is a
  Claude Code plugin"), spec 07 ("loom is a Claude Code plugin"), and the
  implementation itself (`plugins/loom/.claude-plugin/plugin.json` with name
  "loom", a `commands/` + `agents/` + `skills/` layout). In Claude Code, "skill"
  is a *distinct* component type — loom *bundles* one skill (`loom-playbook`) but
  *is* a plugin. This is the load-bearing identity statement of the foundational
  overview and it contradicts the spec's authority (ADR 0001) and the built
  system. Per severity.md, a spec-fidelity violation against the authority is a
  BLOCKER, not a wording nit.

- [MAJOR] Names a command that does not exist: `/loom`. Lines 59 ("a working
  `/loom` orchestrated loop") and 82 ("the main interactive session running the
  `/loom` command"). The shipped orchestrator command is `/loom:run`
  (`plugins/loom/commands/run.md`); there is no bare `/loom` command file. Sibling
  spec 07 is explicit: "there is no bare `/loom`; commands are `/loom:<name>`...
  confirmed empirically at M1 install." An overview that tells a reader to invoke
  `/loom` directs them at a non-existent command. NOTE: the staleness is shared
  upstream — ADR 0001 and the spec README also still say `/loom` — so 00 does not
  contradict its ADR authority on this point; the drift is against the built
  system and spec 07. Tagged MAJOR (real, reader-actionable defect) rather than
  BLOCKER for that reason; fixing it here should be paired with correcting the
  same stale `/loom` references in ADR 0001/README via the proper channel.

- [MINOR] Loop diagram uses informal status labels that don't match the canonical
  state machine. The diagram (lines 15–39) uses "status: ready for review" and
  "status: implemented"; spec 03's authoritative status set has no "ready for
  review" status (it is `Research Review` / `Plan Review`), and "implemented" is
  capitalized `Implemented`. As a conceptual sketch this is tolerable, but the
  paraphrase invites confusion against the dispatcher's real status names.

- [MINOR] Glossary "Role — one of the five specialist cold agents" and the body
  are consistent and accurate; no defect. (Recorded only to confirm the five-role
  / orchestrator-not-a-role framing matches ADR 0001 and specs 02/04.)

## Required changes (for FAIL)

1. Change line 7 from "loom is a Claude Code **skill**" to "loom is a Claude Code
   **plugin**" (matching ADR 0001 and the implementation). Adjust any downstream
   wording in the paragraph so the playbook is described as a *bundled skill*
   within the plugin, not as what loom *is*.
2. Replace the bare `/loom` references (lines 59 and 82) with `/loom:run` to match
   the shipped command and spec 07. (Recommend also flagging the same stale
   `/loom` text in ADR 0001 and the spec README for correction through the
   planning channel, since ADRs are immutable except by supersession.)
3. Optional (MINOR): align the loop-diagram status labels with spec 03's canonical
   names (`Plan Review`, `Implemented`, etc.) or mark them explicitly as informal.

## Notes

The overview is otherwise coherent, well-scoped, and consistent with the ADRs on
the substantive design: the three problems (drift / impartial review / token
cost) map cleanly onto ADRs 0003–0005, 0004, and 0002 respectively; the goals and
non-goals (sequential-before-parallel, no peer-to-peer, owner keeps product
judgment) match ADR 0001's orchestrator model and the README's non-negotiables.
The two blocking/major issues are both identity-and-naming drift: the artifact
describes an earlier conception ("skill", bare `/loom`) that the accepted ADR and
the built plugin have since moved past. Because this is the *entry-point* spec a
cold agent reads first, those two terms must be correct before approval.

---

# Round 2

Verdict: PASS
Round: 2
Reviewed against: revision commit `14ade9d`; ADR 0001 (Accepted,
`0001-plugin-architecture-and-orchestrator.md`); sibling specs
03-artifact-lifecycle and 07-command-surface; and the built plugin tree under
`plugins/loom/` (`.claude-plugin/plugin.json`, `commands/`, `skills/loom-playbook/`).

## Disposition of Round 1 findings

- [BLOCKER → RESOLVED] Plugin identity. Line 7 now reads "loom is a Claude Code
  plugin," with a parenthetical clarifying that loom *bundles* a skill
  (`loom-playbook`) but *is* a plugin. This matches ADR 0001 ("loom is a **Claude
  Code plugin** comprising `commands/`... `agents/`... `skills/loom-playbook/`")
  and the built tree (`plugin.json` name "loom"; `skills/loom-playbook/` present).
  The bundled-skill framing is accurate and introduces no new contradiction —
  `skills/` and the playbook both exist on disk.

- [MAJOR → RESOLVED] Command name. The two bare `/loom` references are now
  `/loom:run` (line 61 goals, line 83 glossary). This matches the shipped command
  (`plugins/loom/commands/run.md`) and spec 07's explicit "no bare `/loom`" rule.
  The upstream ADR 0001 still uses bare `/loom`, but that is ADR staleness to be
  fixed through the planning channel (ADRs are immutable except by supersession);
  spec 00 no longer drifts from the built system or spec 07. No new contradiction.

- [MINOR → RESOLVED] Status labels. The loop diagram now uses "status: Plan
  Review" (line 26) and "status: Implemented" (line 36), the canonical names from
  spec 03's status table. The earlier informal "ready for review"/"implemented"
  paraphrases are gone.

## New findings

None. The fix touched only the four flagged lines plus the identity paragraph; the
substantive design (three problems, goals, non-goals, glossary) is unchanged and
remains consistent with ADRs 0001–0006. No regression or new inconsistency
introduced by the revision.

All Round 1 issues are resolved; no blockers and no unaddressed majors remain.

<!--
Rules (full definitions in references/severity.md):
- Any unresolved [BLOCKER], or any unaddressed [MAJOR] ⇒ Verdict: FAIL.
- PASS means no blockers and no unaddressed majors; [MINOR]s don't block.
-->
