# Research: CLAUDE.md Digest Discipline — Lean Maps vs. Restatement Mirrors

Status: Research Review
Date: 2026-07-03
Topic: How loom should enforce "point-don't-restate" discipline and size bounds for CLAUDE.md, an always-loaded entry point

## Summary

loom's root `CLAUDE.md` has drifted from a lean entry-point map into a bloated reference mirror that violates Anthropic's official guidance and buries critical navigation under restatement. A concrete target structure and spec-08 amendment can enforce the discipline loom's own playbook already prescribes.

### Diagnosis (quantified)

- **Current size**: 197 lines (at Anthropic's < 200 target, but bloated internally)
- **Repo layout section** (lines 27–158): 132 lines = **67% of entire file**
- **Buried signal**: "Read first" (4 lines) and "Gate" (21 lines)—the essential navigation—lie buried under restatement
- **The restatement pattern**: Each "Repo layout" bullet restates—in full paragraph form—the very reference file it names (examples: `init-detection.md` logic repeated in 3 lines; `parallelism.md` entire ADR 0008 + multi-session coordination story expanded to 9 lines; `orchestration.md` context-discipline + cold-restart rule elaborated to 22 lines). [1][2]
- **The cost**: Every agent session loads this 197-line file into context, consuming tokens that compete with actual work. Anthropic's guidance is explicit: "If your CLAUDE.md is too long, Claude ignores half of it because important rules get lost in the noise." [3]

### Prior Art: Anthropic Official Guidance

- **code.claude.com (best practices)**: "Keep it concise. For each line, ask: 'Would removing this cause Claude to make mistakes?' If not, cut it." → "Bloated CLAUDE.md files cause Claude to ignore your actual instructions!" [4]
- **claude.com blog (using-claude-md-files)**: "The over-specified CLAUDE.md is a problem… If your CLAUDE.md is too long, Claude ignores half of it because important rules get lost in the noise. **Fix: Ruthlessly prune. Be sure to keep your file small (less than 200 lines). Some teams go as low as 60 lines.**" [3]
- **Principle**: An always-loaded entry point should be a **lean map that routes to on-demand detail** (reference files, skills, links), not a mirror of that detail. [4]
- **Inclusion test** (Anthropic): Include things Claude can't infer from code; non-obvious behaviors; links to authoritative detail; durable working rules. **Exclude**: information that changes frequently; file-by-file descriptions; detailed tutorials; duplication of linked docs. [4]

### Target Shape (Concrete)

**Goal: 80–100 lines (vs. current 197)**

Three-zone structure:
1. **Stable top** (30 lines): read-first, what-is-loom (one paragraph), core invariants (4 core non-negotiable rules), gate (unchanged)
2. **Pointer index** (25–30 lines): one-clause pointers per reference file, not restatement
3. **Project conventions** (5 lines): shortened version of current

**Compression examples:**
- Current: "The **shippable plugin** lives in `plugins/loom/` (`commands/` — `/loom:run` plus one-off `/loom:<role>` commands; `agents/`; `skills/loom-playbook/`; `hooks/` — PreToolUse guard scripts…" (4 lines)
  → Target: "**`plugins/loom/`** — shippable plugin (commands, agents, skills, hooks); components namespaced `loom:<name>`." (1 line)

- Current: 9-line paragraph restating ADR 0008 + 0014–0016 multi-session coordination
  → Target: "**`references/parallelism.md`** — worktree-per-slice ops + multi-session coordination (ADR 0008, 0014–0016)." (1 line)

- Current: 22-line paragraph restating context discipline + cold restart + write-ahead + ADR 0012 and ADR 0013
  → Target: "**`orchestration.md`** — orchestrator context discipline + cold restart + ~60% trigger (ADR 0012, ADR 0013)." (1 line)

**Result**: Repo layout collapses from 132 → ~25 lines; total file: 197 → ~90 lines. High-value navigation now visible; entry point becomes a map, not a reference mirror. [1][2]

### New Spec-08 Boundary Rule (Recommendation for Amendment)

Current spec 08 (*Evolving the playbook* § *CLAUDE.md auto-propagation*) defines **what goes in** (four inclusion categories: durable conventions, repo-layout facts, gate definitions, read-first pointers) and **explicit exclusion** (per-slice history), but **has no shape/size discipline** and **no "point-don't-restate" enforcement**. [5][6]

**Recommended amendment—add subsection "Shape and Concision Discipline":**

```
CLAUDE.md is an always-loaded entry point and competes for context budget. 
It must stay a lean map, not a reference mirror:

1. Point, don't restate: When CLAUDE.md names a reference file 
   (e.g. "init-detection.md"), a single-clause pointer (purpose + link) 
   replaces a paragraph that restates the file's content.

2. Bounded size: Finalize pass must keep CLAUDE.md < 100 lines 
   (target 80–100 for loom; < 200 for managed projects). 
   If a slice lands and would exceed this, the detail stays 
   in a reference file and CLAUDE.md points to it.

3. Stable top, compact index: CLAUDE.md has two zones:
   - Stable top: read-first, what-is-loom, core invariants, gate.
   - Pointer index: names + one-clause purpose + link per authoritative file.

4. Scope test: For each added/changed bullet: "Would a reader need 
   the details, or just know where to find them?" If the latter, 
   it's a pointer. If the former, either the detail belongs in CLAUDE.md 
   (rare, must fit the shape), or stays in a reference file 
   that CLAUDE.md points to.
```

This enforces the always-loaded discipline that Anthropic's guidance prescribes. ADR 0012 establishes the thin-orchestrator context-budget discipline and cold-restart-as-answer decision; ADR 0013 operationalizes the ~60% cold-restart trigger and starvation-loop guards. Together, they form loom's answer to context pressure and align with the shape constraints proposed here. [4][5][6][7][8]

### Trade-offs & Open Questions

1. **Split stable top from index?** The stable top (read-first, what-is-loom, invariants, gate) could live in a never-changing template; the pointer index could be generated fresh at each finalize pass. Pro: stable top is truly stable. Con: extra file, more complex hand-off. Recommendation: keep unified, apply 80–100-line discipline to whole file.

2. **Prevent re-bloating?** Three mechanisms: (a) pre-finalize diff check to catch creeping restatement; (b) code the shape into template (`name | clause | link`); (c) evaluator (blind review on finalize) rejects bloat. Recommendation: spec rule + developer discipline + evaluator check.

3. **Same target for managed-project CLAUDE.md?** Yes. spec 08 applies the curated-digest boundary to both loom's root and managed projects. Managed projects' CLAUDE.md should stay < 200 lines and use point-don't-restate rule. Managed projects typically have fewer features to index, so this is naturally easier. [5][6]

4. **How to enforce "always-loaded" constraint?** Sonnet is context-aware (token signal after each call); loom's orchestrator monitors this via ADR 0013's ~60% cold-restart trigger. For managed projects, CLAUDE.md is checked into git, so discipline is developer-side hygiene. This is not a technical constraint to solve; spec rule + culture solves it. [8]

## Sources

[1] Measurement of `/Users/craig/git/loom/CLAUDE.md` (lines 27–158 = Repo layout section = 132 lines; total file = 197 lines; 132/197 = 67%)

[2] Current `/Users/craig/git/loom/CLAUDE.md` — specific restatement examples:
   - `init-detection.md` bullet (lines 57–59): restates Greenfield/Unaligned/Initialized classifier logic
   - `parallelism.md` bullet (lines 82–90): restates ADR 0008 + ADR 0014–0016 coordination across 9 lines
   - `orchestration.md` bullet (lines 122–143): restates context discipline + cold restart + ADR 0012 and ADR 0013 across 22 lines
   - `infrastructure-blocked-escalation` bullet (lines 144–156): restates degraded-review + ADR 0017 across 13 lines
   - Plus 6 similar full-paragraph restatement bullets

[3] Claude blog: "Using CLAUDE.MD files: Customizing Claude Code for your codebase" (https://claude.com/blog/using-claude-md-files) — "The over-specified CLAUDE.md is a problem… If your CLAUDE.md is too long, Claude ignores half of it because important rules get lost in the noise. Fix: Ruthlessly prune. Be sure to keep your file small (less than 200 lines). Some teams go as low as 60 lines."

[4] Anthropic Claude Code best practices (https://code.claude.com/docs/en/best-practices) — section "Write an effective CLAUDE.md": "Keep it concise. For each line, ask: 'Would removing this cause Claude to make mistakes?' If not, cut it." → "Bloated CLAUDE.md files cause Claude to ignore your actual instructions!" Also covers inclusion test (what to include vs. exclude).

[5] loom spec 08 — Playbook, section "CLAUDE.md auto-propagation (the curated digest)" (`.docs/spec/08-playbook.md` lines 69–105): defines inclusion categories (durable conventions, repo-layout facts, gate definitions, read-first pointers) and explicit exclusion (per-slice history), but contains no shape/size discipline or "point-don't-restate" rule.

[6] loom spec 03 — Artifact Lifecycle & Status State Machine, finalize pass step 2 (`.docs/spec/03-artifact-lifecycle.md` lines 69–96): curation boundary definition and CLAUDE.md update rule; also silent on shape discipline.

[7] ADR 0012 — Thin Orchestrator: `sonnet` Default + Bounded Role-Return Contract (`.docs/ADR/0012-thin-orchestrator-sonnet-default-bounded-return.md`): establishes context-budget discipline and the cold-restart-as-answer decision.

[8] ADR 0013 — Starvation-Loop Guards for the Orchestrator Cold-Restart (`.docs/ADR/0013-starvation-loop-guards-cold-restart.md`): operationalizes the ~60% cold-restart trigger and write-ahead backstop.

## Open Questions

- Should spec 08 be amended as part of a broader playbook-evolution slice, or is this a standalone spec change? (Out of scope for research; planner decides.)
- How will evaluators detect restatement vs. pointer on blind review of finalize CLAUDE.md diffs? (Possible rubric detail for plan-eval or code-eval to scope.)
- If a managed project's CLAUDE.md grows past < 200 lines (e.g., many custom stacks, many gate definitions), what is the right escalation path? (Not addressed; open for future planning.)
