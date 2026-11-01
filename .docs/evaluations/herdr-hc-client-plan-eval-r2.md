# Evaluation: herdr-hc-client

Verdict: PASS
Round: 1
Reviewed against: ADR 0031, amended specs 07, 08, 10, both named research notes, and the plan-evaluation rubric.

## Findings

No BLOCKER or MAJOR findings.

## Notes

- The 247-line plan satisfies the 250-line target. Exact command: `wc -l .docs/slice-plans/herdr-hc-client.md`.
- Acceptance commit eaf1374 accepts ADR 0031 and amends specs 07, 08 and 10. Exact command: `git show --stat --oneline eaf1374`.
- The deny applies to all hc invocations, including all verbs in `hc --help` and the research table, including `templates` and `schema`; it has no role-session allowlist. Exact commands: `hc --help` and `rg -n '^\| `' .docs/research/2026-11-01-hc-agent-runtime-reference.md`.
- Retirement, 12 cases / 48 files, open blindness, unsupported Codex and evaluator roles, exact gate, and CLI-only probe with cleanup are specified at .docs/slice-plans/herdr-hc-client.md:24, :81, :95, :153, :181 and :223. New files are marked new; the named existing files and fixture count were checked with `rg --files | rg '(loom-host-hc|role-governance-guard.bats|loom-launch-role.bats|loom-resolve-helper.bats|herdr-verification|hook-wire-v1/herdr)'`. The live probe and gate were not run.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 1 | plan | FAIL | The revision fixes wrapper assignments, forbids role launch, reconciles the retained history link, specifies the model, and narrows Q1 claims. Verified with `git diff 54bbde4^ HEAD -- .docs/slice-plans/herdr-hc-client.md`; the three assignment examples match the revised expression using `printf '%s\n' 'env A=1 hc get t1' 'A=1 env B=2 hc ls' 'env -i hc ls' \| rg -n '(^\|[;&\|(])[[:space:]]*(([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*\|-[^[:space:]]+\|env\|command\|exec\|nohup\|time)[[:space:]]+)*([^[:space:]]*/)?hc([[:space:]]\|$)'`. |
