# Evaluation: role-governance-guard (slice-plan)

Artifact: `.docs/slice-plans/role-governance-guard.md`
Verdict: FAIL
Round: 1
Authority: spec 02, 04, 08; ADR 0004, 0012, 0027; plan-eval-rubric.md; severity.md

## Findings

1. **[BLOCKER] Hook wire output contradicts spec 08.** Step 2 specifies Codex blocking
   as `{ "continue": false, "stopReason": ... }`. Spec 08 (Hook normalization table)
   fixes Codex `PreToolUse` block as exit 0 with
   `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny",...}}`;
   `continue:false` is the `PreCompact` encoding, and "no adapter may substitute another
   encoding". Reasons must also be single-line <= 512 bytes (the stated diagnostics fit,
   but this is not asserted). Fix: reuse the git-identity-guard adapter output verbatim.

2. **[BLOCKER] `LOOM_ROLE` default-to-orchestrator breaks developers and non-loom sessions.**
   Step 1 cannot export an env var for Claude: `_launch_claude` spawns no process (it
   prints a launch record; the sub-agent runs via the client's Agent tool), so Claude
   developer/researcher sub-agents will have `LOOM_ROLE` unset. Step 2 then treats unset
   as `orchestrator` and denies `scripts/check`/`cargo test`/`pytest`, so every Claude
   developer is blocked from running the gate (spec 02 requires the developer to run it).
   The hook is also registered plugin-wide, so ordinary user sessions are blocked.
   "Include LOOM_ROLE guidance in role execution context" is not a producer. Fix: fail
   open when unset; enforce the orchestrator rule only on an explicit `LOOM_ROLE=orchestrator`,
   and state which launch paths actually set it.

3. **[BLOCKER] Orchestrator rule conflicts with spec 04.** Spec 04 (bootstrap-landing /
   remote-direct) has the root run the integrated gate and rerun the publish-candidate
   gate. A blanket deny on `scripts/check` for the orchestrator contradicts a normative
   root duty, and the plan names no exception or spec amendment. The plan also cites
   ADR 0012 as authority, but that ADR bounds role returns and does not prohibit root
   gate runs. A slice cannot edit specs, and none of 02/04/08 currently mandates this
   hook. Fix: route a planner spec amendment (or narrow the rule to a spec-sanctioned
   case) first.

4. **[MAJOR] Hook-wire fixtures and the "12-case product" are not updated.** Spec 08 and
   CLAUDE.md define byte-exact `hook-wire-v1` fixtures per client/event/outcome. Adding a
   second PreToolUse hook requires a decision (shared dispatcher vs. separate fixtures)
   and fixture/doc counts; Step 5 and Verification mention only bats. Also, two commands
   in one `hooks.json` matcher run independently, so ordering and combined-block
   behavior need a statement.

5. **[MAJOR] Matching is under-specified.** "`*bats`", "`bats *`", and "`git commit`
   matches" give no tokenization or quoting rule, so an independent reader could
   implement substring matching that blocks `git log --grep=bats`, `echo pytest`, or
   `cat foo.bats`. Evaluator rule also lists `git commit` but omits `git add`,
   `git checkout`, `git stash`, and redirections, and the plan does not say that is
   intentional. State anchoring (leading command word after de-quote, as
   git-identity-guard does) and add negative tests.

6. **[MAJOR] Bounded-return schema (Step 4) is orphaned and inconsistent.** Spec 02 sets
   the final return as `Status:`, artifact path(s), ~150-token reason; ADR 0012 defines
   the contract. The schema has no consumer, no validator wiring (`validate-repository`
   schema list, doc references), no test, and uses `verdict`/`evalPath` fields that
   don't cover non-evaluator roles. It is a separate purpose from the hook (Single-purpose
   rubric item) and has no authority in the cited specs. Drop it or justify and test it.

7. **[MAJOR] Target size unrealistic.** <= 180 LOC for a hook with two client wires, a
   launcher change across three clients, a schema, and a bats suite covering both wires.

8. **[MINOR]** Codex `exec env` edit omits the antigravity/claude parity detail (record
   `role` already exists in the launch JSON); Verification lacks an `rg`/`jq` mechanical
   check that `hooks.json` registers the guard and that no launcher path leaves
   `LOOM_ROLE` unset.

## Rubric summary

Authority: fail (3). Executable: fail (2, 5). Verified sketches: fail (1, 2).
Single-purpose: fail (6). Structure/size sections present. Verification named: partial (4).

---

# Round 1 re-review (revision d39b55c..fa52014)

Non-expansion rule applied: only Round 0 findings are checked; no new criteria introduced.

| # | Sev | Status | Basis |
|---|---|---|---|
| 1 | BLOCKER | Resolved | Step 2 now specifies Claude exit 2/stderr and Codex `deny` JSON exit 0 per spec 08, with single-line <=512-byte reasons. |
| 2 | BLOCKER | Resolved | Unset `LOOM_ROLE` fails open; enforcement only on explicit role. Claude launch no longer claims an env producer. |
| 3 | BLOCKER | Resolved (accepted) | `LOOM_ALLOW_ORCHESTRATOR_GATE=1` exception preserves spec 04's root gate rerun; plan now cites no ADR 0012 prohibition. |
| 4 | MAJOR | **Unresolved** | Plan still never addresses `hook-wire-v1` fixtures, the "12-case" product/CLAUDE.md counts, or ordering/combined-block behavior of two `PreToolUse` hooks in one matcher. The diff and revision log are silent; Verification adds no fixture check. |
| 5 | MAJOR | Resolved | Stage A/B/C anchoring on the de-quoted leading word plus negative tests (`git log --grep=bats`, `echo bats`). Evaluator mutation list's intentional scope (no `git add`/`checkout`/redirects) remains unstated but is not blocking. |
| 6 | MAJOR | Resolved | Schema dropped and deferred. |
| 7 | MAJOR | Resolved | Scope shrank; 200 LOC is plausible after dropping schema and Claude launcher work. |
| 8 | MINOR | Partial | Orchestrator `LOOM_ROLE=orchestrator` producer is vague ("explicitly exported when driving orchestration workflows"); no `rg`/`jq` mechanical check added. |

## Verdict rationale

Finding 4 is a MAJOR from Round 0 that the revision did not touch. Spec 08 makes the
hook-wire fixtures byte-exact per client/event/outcome, and adding a second PreToolUse
hook changes that product. Required fix (no new criteria): state whether the guard gets
its own fixtures or shares a dispatcher, update fixture/doc counts, and state
hook ordering/combined-block behavior; add a verification step for it. Optionally name the
orchestrator `LOOM_ROLE` producer (Finding 8).

Verdict: FAIL
