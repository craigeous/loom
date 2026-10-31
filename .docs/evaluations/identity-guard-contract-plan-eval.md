# Evaluation: identity-guard-contract (slice-plan)

Verdict: FAIL
Round: 0
Reviewed against: plan-eval-rubric.md, severity.md, repository-improvement-plan.md (M3 `identity-guard-contract`), ADR 0003, spec 00 (Non-goals), spec 08 (identity policy paragraph), spec 10, current `git-identity-guard.sh`/`.bats`, `commit-convention.md`, `loom-resolve-helper`, templates/evaluation.md

## Findings

- [MAJOR] Verifier is not resolvable/invocable as specified — Step 2 adds a new helper under `plugins/loom/bin/` but never names it, defines its CLI (args: baseline SHA; exit codes; stdout/stderr contract), or addresses how installed roles reach it. `loom-resolve-helper` has `ALLOWED_HELPERS=(loom-coord)` and CLAUDE.md requires installed helpers to resolve from the physical plugin root; a new helper not added to that allowlist (and its bats) cannot be invoked from an installed plugin. An independent developer would have to invent the interface and could omit the resolver wiring.
- [MAJOR] Step 2/4 "role workflow guidance" / "relevant role workflow instructions" are unnamed — the invocation boundary is the core of the post-command guarantee, yet no file-scoped edit list exists (e.g., `plugins/loom/roles/*.md`, which roles commit, playbook references). Ambiguity an independent reader could implement wrongly (verifier documented but never actually wired into a commit path).
- [MINOR] "Ambiguous recognized mutation forms" and "other wrappers" (Step 1) are undefined; define the smallest rule (e.g., any `user.name`/`user.email` token with a `git config` word that is not a bare read/`--get`/`--list`), and say whether `--unset`/`--replace-all`/`--add`/`--edit` count as writes (they should be blocked).
- [MINOR] Git also honors `author.name|email` / `committer.name|email` config (`-c author.name=…`); not in the required list but cheap to include in the same regex or to state as a documented limitation.
- [MINOR] `Target size: <= 200 LOC net` looks unrealistic for a new verifier + hook rewrite + ~20 bats cases + docs; restate the budget (or exclude tests/docs explicitly) so the developer is not forced into a post-hoc overrun.
- [MINOR] Doc-accuracy claims (hook header, `hooks.json` description, commit-convention "Known limitation", the old "fail-open on odd quotes" text) have no mechanical check; add an `rg -U` verification step for stale "Stage A/B/C", "fail-open", and broader-than-actual enforcement wording.
- [MINOR] Remediation text says to "restore identity through the owner" while `commit-convention.md` sanctions `git commit --amend --reset-author --no-edit` for unpublished commits; state the plan reconciles these (the verifier itself never mutates history).

## Required changes (for FAIL)

1. Name the verifier file and state its minimal interface (`<name> <baseline-sha|unborn>`; exit 0 ok/no-op, nonzero on any failure; offending SHA + remediation on stderr), and add the steps to register it in `loom-resolve-helper` `ALLOWED_HELPERS` (+ its bats) or state the explicit alternative resolution path.
2. List the exact role/playbook files that gain the baseline-capture + verifier-invocation instruction (file-scoped), and add an `rg` check that each such file contains it.

## Notes

Strengths: template conformant, 83 lines (<= 250), has `Target size`, threat-model section aligned with spec 00 non-goals, single-purpose, fail-closed on unbalanced quotes, wrappers/config scopes/`--file`/safe reads/ordinary commits/both client wires and verifier edge cases (unborn, amended, multiple commits, invalid baseline) all covered and matching the improvement-plan acceptance criteria. No spec/ADR edits proposed. Note the plan's wrapper coverage (sh -c, bash -c, env) and config-write blocking are adequately specified; the remaining defects are limited to the verifier's interface/wiring, which is why the fixes are small.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| — | — | — | First review; no prior rounds. |
