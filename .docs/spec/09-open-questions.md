# 09 — Open Questions

Status: Living

Resolved items are kept for traceability; settled ones became ADRs or spec text.

## Resolved

- **Q1 — Skill layout.** loom is a **plugin**: `commands/` (orchestrator + one-offs)
  + `agents/` (5 roles) + `skills/loom-playbook/`. → ADR 0001, spec 10.
- **Q2 — Agent definitions.** `agents/*.md` with frontmatter; orchestrator (main
  session) spawns via the Task tool; no peer-to-peer. → ADR 0001, spec 02/04.
- **Q3 — Model pinning.** Tier only (`haiku`/`sonnet`/`opus`/`inherit`); no exact
  version. → ADR 0002.
- **Q5 — Owner gate declaration.** At kickoff the owner claims `all` or a named
  list of gates. → spec 03/04.
- **Q6 — Round limit & escalation.** Default **5**; escalation = pause + summary.
  → spec 03.
- **Q7 — Living-doc updates.** Done by the role completing the work (developer or
  planner). On evaluator approval, that role runs a **finalize pass** (cold) to
  update the living docs and archive. → spec 02/03.
- **Q8 — Spec landing.** Specs are **frozen** after approval; they change only via
  a planning cycle, never at slice landing, never by a developer. → ADR 0005.
- **Q9 — Alignment back-fill.** Descriptive only (map what the project is);
  decisions/changes require a planning phase. → spec 06.
- **Q10 — Idempotent re-application.** Auto-apply clean merges; recommend for the
  rest; owner decides. → spec 06.
- **Q11 — Gate commands.** Rust only, verified. Other stacks: gate creation is an
  init responsibility (identify → create → confirm → run green → record). → spec
  06/08.
- **Q12 — Re-eval.** Code → diff the commits; plan → re-read + diff. Every handoff
  commits, so there's always a diff. → ADR 0003, spec 05.
- **Q13 — Research gating.** Research is lightly gated: mandatory citations; the
  plan evaluator checks sources support the summary. → spec 02/05.
- **Q14 — Bootstrap order.** Build minimum orchestration by hand first, then
  dogfood. `claude -p` (`Bash(claude:*)`) is the reserve mechanism for
  agent-spawns-agent / deep nesting. → spec 04, roadmap M1.

## Open

- **OQ-B. Research-review tier.** Is the sources-match-claims check cheap enough to
  run on `sonnet`/`haiku` rather than `opus`? Decide empirically.
  - _Owner guidance (M2), to be worked next:_ owner leans **haiku is sufficient** —
    research review is just checking that the cited sources support the claims
    (source-vs-claims matching), which haiku can do. Decide empirically, but bias
    toward haiku.
- **OQ-C. Finalize pass owner.** Confirm the finalize doc-update is best as a
  re-spawned cold role pass vs. the orchestrator doing it directly. (Current
  design: re-spawned role, per Q7.)
  - _Owner guidance (M2), to be worked next:_ owner is **undecided** and wants a
    compare-and-contrast of the two options (re-spawned cold role pass vs. the
    orchestrator doing the finalize directly) before choosing.
- ~~**OQ-A. Parallel `.docs/` coordination.**~~ **RESOLVED (M3):** hybrid model —
  the three living docs (`roadmap.md`/`progress.md`/`handoff.md`) **and the
  slice-plans index (`slice-plans/README.md`)** live on **main only**, written
  **solely by the orchestrator** and serialized; each slice's uniquely-named
  plan file, eval file, and code live on its **slice branch**; landing is a
  serial merge+finalize from the main worktree, so concurrent slices write
  disjoint paths and never conflict on a `.docs/` file. Worktrees are created
  from fresh `origin/main` (input freshness at spawn); concurrency safety via
  `index.lock` backoff retry, `git worktree remove -f`/`prune` cleanup, and the
  stateless identity-guard hook. → ADR 0008.
- ~~**OQ-D. Command namespacing.**~~ **RESOLVED (M1, empirically):** plugin
  components are namespaced — there is no bare `/loom`. Surface is one file per
  command: `/loom:run` (orchestrator) + one-off `/loom:research|plan|eval-plan|
  develop|eval-code|status|init`; agents are `loom:<role>`. → spec 07, 10.
- ~~**OQ-E. marketplace `source: "."`.**~~ **RESOLVED (M1):** root plugin is
  undocumented; use `plugins/loom/` with `source: "./plugins/loom"`. → ADR 0006,
  spec 10.
- ~~**OQ-F. Plugin helper code.**~~ **RESOLVED (M1):** no compiled helpers; agents
  do detection/parsing with their own tools (portable, no toolchain forced on
  installers).
