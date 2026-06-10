# Research: /review and /security-review in loom's Code Evaluator

Status: Draft
Date: 2026-06-10
Topic: Feasibility of invoking Claude Code's `/review` and `/security-review` commands from a blind loom code-evaluator sub-agent.

## Summary

### What are `/review` and `/security-review`?

The `/code-review` command (not `/review`) is a built-in Claude Code slash command that performs code review on a local diff or GitHub pull request, returning findings as a structured report [1][2]. It is **not** the same as the marketplace plugin `code-review` or `pr-review-toolkit`. The `/security-review` command is also a built-in Claude Code command that scans code for security vulnerabilities (SQL injection, XSS, auth flaws, insecure data handling, dependency issues) [3][4].

Both built-in commands operate locally (on the current branch or a specified diff) and **do not require a GitHub PR to run** [1][3]. The `/code-review` command can also be invoked with `--comment` to post findings to a PR or `--fix` to apply findings to the working tree [1].

### Do these commands spawn sub-agents?

**Critical finding: yes, internally they do.** The `/code-review` command documentation states that it "launches 5 parallel Sonnet agents to independently code review the change" and each agent performs specialized analysis (CLAUDE.md compliance, bug detection, git history context, code comments, previous PR patterns) [5]. The marketplace `pr-review-toolkit` plugin explicitly defines 6 agents (`code-reviewer`, `comment-analyzer`, `pr-test-analyzer`, `silent-failure-hunter`, `type-design-analyzer`, `code-simplifier`) that run in sequence or parallel [6].

The `/security-review` command implementation details are less fully documented, but the security review GitHub Action (which shares logic with the command) invokes Claude's analysis; no explicit agent spawning is mentioned for the local `/security-review` command itself [3][4].

### Tool availability in loom's code-evaluator

The code-evaluator agent frontmatter specifies `tools: Read, Grep, Glob, Bash, Write, Edit` — **no `Skill` tool and no `Agent` tool** [7]. The Agent tool (formerly Task tool) is the mechanism Claude Code uses to spawn sub-agents. Without it in the frontmatter, the code-evaluator cannot invoke the Agent tool to spawn any sub-agents itself.

**A slash command invocation (e.g., `/code-review`) is not the same as using the Agent tool.** Slash commands are available to all agents and skills as part of the Claude Code environment; they do not require the Agent tool in the `tools` list [8]. However, the critical constraint is **sub-agents cannot spawn other sub-agents** [9][10].

### The nested-spawn blocker

ADR 0001 establishes the fundamental constraint: "Sub-agents cannot spawn other sub-agents — only the orchestrator (main session) spawns" [11]. The `/code-review` command internally spawns parallel Sonnet agents to do the review. If the code-evaluator (a sub-agent spawned by the orchestrator via the Task/Agent tool) attempts to invoke `/code-review`, it would be a sub-agent spawning sub-agents, which violates ADR 0001's architecture.

The Claude Code documentation explicitly confirms: "Subagents cannot spawn other subagents. If your workflow requires nested delegation, use Skills or chain subagents from the main conversation" [9]. This is a hard constraint, not a permission issue — even with all tools available, a sub-agent that internally spawns is forbidden.

### Blind-evaluation contract implications (ADR 0004)

The `/code-review` command targeting a GitHub PR requires a GitHub PR reference (the branch must have an open PR on GitHub) and will post findings as inline PR comments [2]. This introduces author identity into the evaluator's workflow: GitHub PR metadata (PR number, repository owner, commit SHAs) would flow through the command, and the command itself posts to a PR visible to the repository's team. This violates ADR 0004's blind contract — the code-evaluator must review "blind," given only the commit diff, the slice-plan, and specs, with no author identity or identity-revealing network operations [12].

The local `/code-review` command (without `--comment`) avoids the GitHub posting step but would still require the code-evaluator to invoke the command and handle its internal agent spawning, which is architecturally blocked.

The `/security-review` command runs locally and returns findings without posting to GitHub, so the blindness concern is weaker there — but the sub-agent spawning constraint still applies if `/security-review` internally spawns agents (unclear from documentation, but likely given the pattern).

## Sources

[1] https://code.claude.com/docs/en/code-review — Claude Code Code Review documentation; specifies the `/code-review` command, its behavior with GitHub PRs and local diffs, and the `--comment` and `--fix` flags.

[2] https://code.claude.com/docs/en/code-review#review-a-diff-locally — "To review a diff locally in your terminal without installing the GitHub App, run the `/code-review` command"; also documents the ability to target a specific PR or path.

[3] https://support.claude.com/en/articles/11932705-automated-security-reviews-in-claude-code — Automated Security Reviews in Claude Code; describes `/security-review` capabilities and vulnerability types detected.

[4] https://code.claude.com/docs/en/security — Claude Code Security documentation; mentions `/security-review` command and customization options.

[5] `/Users/craig/.claude/plugins/marketplaces/claude-plugins-official/plugins/code-review/commands/code-review.md` — local marketplace plugin code-review command file, lines 1–93; explicitly specifies "launch 5 parallel Sonnet agents" in step 4 and names the agent roles (CLAUDE.md auditors, bug detector, history analyzer, comment auditor, previous-PR analyzer).

[6] `/Users/craig/.claude/plugins/marketplaces/claude-plugins-official/plugins/pr-review-toolkit/README.md` — local marketplace plugin pr-review-toolkit README; lines 1–310 document 6 agents and their roles and explicitly state that the `/review-pr` command runs these agents in parallel or sequentially.

[7] `/Users/craig/git/loom/plugins/loom/agents/code-evaluator.md` — line 6, frontmatter `tools:` field.

[8] https://code.claude.com/docs/en/sub-agents — Claude Code sub-agents documentation; lines 305–360 document the Agent tool and tool restrictions. Slash commands are part of the Claude Code environment and do not depend on the Agent tool being in the `tools` list.

[9] https://code.claude.com/docs/en/sub-agents — lines 62–63: "This prevents infinite nesting (subagents cannot spawn other subagents) while still gathering necessary context"; and line 772: "Subagents cannot spawn other subagents. If your workflow requires nested delegation, use Skills or chain subagents from the main conversation."

[10] https://code.claude.com/docs/en/sub-agents — lines 360–361: "To prevent a subagent from invoking skills entirely, omit `Skill` from the [`tools`](#available-tools) list or add it to `disallowedTools`. This restriction only applies to agents running as the main thread with `claude --agent`. Subagents cannot spawn other subagents, so `Agent(agent_type)` has no effect in subagent definitions."

[11] `/Users/craig/git/loom/.docs/ADR/0001-plugin-architecture-and-orchestrator.md` — lines 13–14: "Claude Code sub-agents **cannot spawn other sub-agents**, so peer-to-peer role calls are impossible."

[12] `/Users/craig/git/loom/.docs/ADR/0004-blind-evaluation-role-separation.md` — lines 13–20: blind evaluator receives only "the artifact (minus identity metadata), the upstream authority it is judged against, the playbook rubric, and — on re-review — the prior eval file and the diff. It never receives author identity or author reasoning."

## Open questions

- **Does `/security-review` internally spawn sub-agents?** The documentation for the local `/security-review` command does not explicitly state whether it spawns agents. The GitHub Action version (which uses the same underlying analysis) does not describe agent spawning. This should be confirmed via empirical test (running `/security-review` from a spawned sub-agent and observing whether it fails with a sub-agent-spawn error).

- **Could the orchestrator invoke `/review` and `/security-review` as a workaround?** Yes — the orchestrator is not a sub-agent and can spawn child agents freely. If the orchestrator runs `/code-review` (accepting that it spawns 5 Sonnet agents internally) and passes the findings to the code-evaluator as a structured input (not PR comments), the blind contract could be preserved. This would require architectural change (adding a new orchestrator capability) but avoids the ADR 0001 blocker. **Unverified: would this require an ADR or a slice-plan?** — likely an ADR if it changes blind-evaluation inputs; likely a slice-plan if it's a local capability-add to the orchestrator.

- **Could a local, non-spawning equivalent be built in loom?** Yes — loom could implement its own read-only code review in the code-evaluator's system prompt or as a skill that does not spawn sub-agents. This trades off breadth (fewer review perspectives) for architectural compliance. **No empirical test is feasible** from a sub-agent role; the orchestrator would need to evaluate whether loom's existing `code-eval-rubric.md` skill + manual gate re-check suffice or whether additional analysis is needed.

## Feasibility Verdict

**The code-evaluator cannot invoke `/review` or `/security-review` as-is.** The `/code-review` command spawns 5 parallel Sonnet agents internally. loom's architecture forbids sub-agents from spawning sub-agents (ADR 0001). Even though the code-evaluator has tools like Read and Bash available, a slash command that internally spawns will fail when invoked from a sub-agent context.

**Viable paths forward:**

1. **Orchestrator-run review (low architectural risk).** The orchestrator (main session) runs `/code-review` or `/security-review` at the start of the code-eval phase and feeds the structured report (findings list) to the blind code-evaluator as a new input artifact. The code-evaluator then incorporates those findings into its rubric evaluation. **Trade-off:** Requires a new orchestrator capability and likely an ADR amendment to spec 04 (code evaluator inputs); does not leak author identity if orchestrator scrubs PR comments and only returns findings.

2. **Non-spawning local review (medium risk, high compatibility cost).** Implement a loom-native code review skill that the code-evaluator can invoke, which does not spawn sub-agents. This could wrap aspects of the `code-eval-rubric.md` or be a new specialized prompt. **Trade-off:** Narrower review than `/code-review` (fewer agents, fewer perspectives); requires building/maintaining new content; likely a slice-plan, not an ADR.

3. **ADR to allow controlled nested spawn (high architectural risk).** Amend ADR 0001 to permit a single orchestrator-managed level of nested spawning (orchestrator → code-evaluator → review agents). This would make the architecture more complex and harder to reason about. **Not recommended** without strong justification; violates the "only the orchestrator spawns" principle.

**Open decision:** Which trade-off is acceptable? — breadth/capability vs. architectural simplicity vs. development cost. The owner should choose between (1), (2), or (3) before an ADR or slice-plan is written.
