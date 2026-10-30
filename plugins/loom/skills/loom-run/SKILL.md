---
name: loom-run
description: Run the loom dev loop — detect state, take scope/gates, drive the roles through the full research→plan→eval→develop→eval→land loop.
---

# loom-run — orchestrator workflow

You are the **loom orchestrator** (the client's root/main session), not a role.
Drive the spec-driven loop by launching cold role agents and routing handoffs
through `.docs/`.

**Installed-root bootstrap.** Before reading anything below, resolve your installed
plugin root through your client's adapter contract (spec 10 → *Installed-root and
helper binding*): Claude resolves the physical `CLAUDE_PLUGIN_ROOT`; Codex resolves
the physical root by ascending two directories from its loaded
`skills/loom-run/SKILL.md` source path. Every reference below is root-relative to
that resolved root.

Read first (source of truth):
- `skills/loom-playbook/references/orchestration.md`
- `skills/loom-playbook/references/status-machine.md`
- `skills/loom-playbook/references/parallelism.md`
  (worktree-per-slice parallelism — available, owner opts in)
- `loom-coord` — the multi-session coordination CLI (shipped at `bin/loom-coord`;
  invoke by absolute path resolved from your installed root, or as the bare command
  where your client's adapter places it on `$PATH`): cross-session lock + per-slice
  claims + background renewer, active when the owner opts in to concurrent runs.

Requested scope: the workflow argument (if empty, ask).

## Procedure

1. **Detect init mode** (run the classifier in `init-detection.md` via
   orchestration.md) and act: greenfield → scaffold per
   `skills/loom-playbook/references/greenfield.md`; unaligned → alignment pass per
   `skills/loom-playbook/references/unaligned.md`; initialized → resume per
   `skills/loom-playbook/references/initialized.md` (derive menu from `.docs/` + git
   state, then scope/gates + driver loop).
2. **Confirm scope and claimed gates** with the owner (orchestration.md → Scope &
   claimed gates). Use the workflow argument as the scope if given.
   You run on the **Standard** profile (ADR 0012; your client adapter maps this to
   its native orchestrator selector). Stay **thin**: your context must scale with
   the number of in-flight artifacts, not the size of the work product. Pass roles
   `.docs/` **paths**, never bodies; route on `Status:` lines + the bounded signal
   each role returns, never on pasted diffs/eval prose. See orchestration.md →
   *Context discipline (thin orchestrator)*. Context-aware clients report remaining
   token budget after each tool call; at **~60%** of budget, checkpoint to
   `handoff.md` and cold-restart from the status digest rather than degrading (the
   restart is lossless — all durable state is in `.docs/` + git). **Write-ahead so a
   restart never loops:** commit the next intended action to `handoff.md` *before*
   any large or in-window op (a heavy spawn, code-review), and restart *before* such
   an op when near budget — never start one you can't finish and record within
   budget. If a restart re-derives the *same* action with no new commit since,
   that's a starvation loop → **escalate** (pause + summary), don't re-attempt. See
   orchestration.md → *Restart safely*.
3. **Driver loop:**
   a. Scan `.docs/` **`Status:` lines + git** (the `loom-status` digest, **not**
      artifact bodies) → current state.
   b. Pick the next action from the dispatch table (status-machine.md). If none, or
      the next action is outside scope → **break**.
   c. If the transition is an owner-claimed gate → pause, show the artifact + the
      evaluator's verdict, await the owner's decision.
   d. Launch the dispatched role (right profile; focused input that hands `.docs/`
      **paths, not bodies**; blind inputs for evaluators). Run
      `bin/loom-launch-role <your-client> <role>` — the sole client role
      launcher (spec 10 → *Versioned compatibility and capability mapping*) —
      to derive/validate the exact tier from the tracked compatibility matrix
      and enforce a fresh, one-level, non-delegating cold child (Codex: this
      performs the cold launch itself; Claude: launch natively per
      `roles/<role>.md` / `agents/<role>.md` using its printed configuration).
      Tell the role to return only the **bounded contract** — `{Status:, path(s),
      ≤~150-token summary, the one branch signal}`, no echoed body
      (orchestration.md → *Context discipline*). Independent/disjoint slices may
      run in parallel (worktree-per-slice, owner opts in) — see `parallelism.md`
      for the create→work→land→cleanup flow and the slicer-independence rule. When
      the owner opts into multi-session runs, coordinate via `loom-coord`:
      `session-start` at kickoff, `claim <slice>` (under `lock-acquire`) before
      working a slice, `lock-verify` before landing, `session-end` at exit — per
      `orchestration.md` → *Multi-session coordination* and `parallelism.md` →
      *Multi-session coordination*.
   d2. **When a slice reaches `Implemented`, before dispatching the code-evaluator,
      run the automated review** (orchestration.md → "Automated review before a
      slice lands"). This means a **real tool call**: actually invoke the
      code-review and security-review workflows and transcribe their output into
      the `-review-findings.md` artifact — **never** write the findings from your
      own reading of the diff (that is a hard violation). Skip only for a pure-docs
      diff (`skipped: docs-only`) or a genuinely unavailable workflow
      (`skipped: command-unavailable`). This is the one step that runs review
      output through your window; **write-and-forget** — capture → write the
      artifact → drop it; do not reason over or branch on the findings (the blind
      code-evaluator adjudicates them from the file — ADR 0012). **Before recording
      `ran-clean`**, inspect the workflow result for a finder/sub-agent failure
      indicator: a limit-crashed run (spend/usage/quota, 429, 5xx,
      classifier-unavailable) is **INVALID** — a false-clean, never `ran-clean`;
      treat it as an infra-block escalation (re-run when unblocked, else
      `skipped: command-unavailable`) — see orchestration.md → *Automated review
      before a slice lands*.
   e. On return, verify the recorder/root's author-neutral commit and the new
      status (the evaluator itself never commits — the recorder installs the
      verdict and transitions status). On a code-eval PASS (status now
      `Ready to Publish`), launch the developer's **finalize pass** (update
      `status/`, archive the plan); the finalize/land sequence follows ADR 0020
      (publish → verify remote → receipt → `Landed`).
   f. Honor the round limit (5 **FAIL** cycles per artifact → escalate = pause +
      summary; see spec 03 `## Round limits` for the counting + summary contract).
      **Goalpost-shift early escalation:** if an artifact receives **2 consecutive
      FAILs** where Round >= 1 introduces new `blocking`/`high` findings on paths or
      invariants that were already present in Round 0 (moving the goalposts rather
      than verifying Round 0's `Must Fix` checklist), pause and escalate to the owner
      immediately instead of spinning through additional rounds.
      Also escalate — **same pause + summary, but NOT round-counted** — on an
      **infrastructure block** (spend/usage/quota limit, 429, 5xx,
      classifier-unavailable, or a limit-crashed workflow); detect-on-failure only
      — see spec 03/04 + ADR 0017 → orchestration.md → *Infrastructure-blocked
      escalation*.
   g. Repeat.
4. **On break:** summarize what happened and ensure `.docs/status/handoff.md`
   reflects the next step.

For a single role pass instead of the full loop, use the one-off workflows
(`loom-research`, `loom-plan`, `loom-eval-plan`, `loom-develop`, `loom-eval-code`).
