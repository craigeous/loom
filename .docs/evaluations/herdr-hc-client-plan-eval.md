# Evaluation: herdr-hc-client

Verdict: FAIL
Round: 0
Commit: 8d33cfb946d7f7cb7963e326ae08ec5d0294eb4c
Reviewed against: ADR 0031; amended specs 07, 08, 10; named research notes; plan-evaluation rubric.

## Summary

FAIL. The `hc` guard missed assignments after `env`, role launches were not gated on
the probes, one acceptance criterion contradicted a retained link, and the probe left
its model and a Q1 claim unsupported.

## Findings

- [BLOCKER] The prescribed guard misses its own `env A=1 hc get t1` test and violates the deny-by-default invariant: the expression at .docs/slice-plans/herdr-hc-client.md:91 permits assignments before `env`, but not after it; spec 08:164 requires every invocation refused. Exact command: `printf '%s\n' 'env A=1 hc get t1' | rg -n '(^|[;&|(])[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*((env|command|exec|nohup|time)[[:space:]]+)*([^[:space:]]*/)?hc([[:space:]]|$)'` (no match).
- [BLOCKER] The acknowledgement at .docs/slice-plans/herdr-hc-client.md:35 and :52 allows actual role launches before Q4 proves agent definition and non-delegation; ADR 0031: required gates before any role runs, and spec 07:79 require those probes before support. The planned command at :59 has no role definition or tool restriction. An environment acknowledgement does not establish the required properties. Exact command: `rg -n 'unsupported|UNVERIFIED|model|hc run|role.*agent' .docs/spec/07-command-surface.md .docs/ADR/0031-herdr-as-an-hc-driven-client.md .docs/slice-plans/herdr-hc-client.md .docs/research/2026-11-01-hc-agent-runtime-reference.md`.
- [BLOCKER] Acceptance criterion 4 at .docs/slice-plans/herdr-hc-client.md:194 cannot pass while the same plan explicitly retains the history link at :129: `scripts/validation/relative-link-allowlist.txt:56` contains `herdr`. Exact command: `rg -n -i 'herdr' scripts/validation/relative-link-allowlist.txt`.
- [MAJOR] The probe command at .docs/slice-plans/herdr-hc-client.md:175 omits a model, leaving the requested model unspecified and the result dependent on ambient configuration. Specify the intended selector and include it in the exact command and verification. Exact command: `rg -n 'hc run|model' .docs/slice-plans/herdr-hc-client.md`.
- [MAJOR] The probe at .docs/slice-plans/herdr-hc-client.md:211-220 claims Q1 (status at launch before a turn) from a wait/get performed after a prompt has already been sent; a report during the turn cannot establish status at launch. A timeout or unreported status also does not establish why no report arrived. Record only what the observation proves, or add a separate pre-turn observation. Exact command: `rg -n 'Q1|OSC|hc run|hc wait|reported' .docs/slice-plans/herdr-hc-client.md .docs/research/2026-11-01-hc-agent-runtime-reference.md`.

## Required changes

1. Correct the guard and test the specified environment-assignment form.
2. Prevent role launch until the required live probes and non-delegation contract are satisfied; retain any experimental probe as generic rather than role work.
3. Make the retirement search exclude the expressly retained history link, or otherwise reconcile the criterion with the retention instruction.
4. Specify the probe model and limit Q1 conclusions to evidence that establishes pre-turn status.

## Notes

The ADR prescribes no role-session allowlist: all hc invocations are denied. `hc --help` and research include read verbs `templates` and `schema`; the all-verbs policy covers them without enumerating them. The exact gate, retirement counts, open blind-review constraint, and CLI-only cleanup are specified. The probe requires no Herdr UI. Commands used: `hc --help`; `rg -n '^\| \x60(templates|schema|file|ls|get|read|events)' .docs/research/2026-11-01-hc-agent-runtime-reference.md`; `git show --stat --oneline eaf1374`; `git log -1 --format='%h %s' -- .docs/slice-plans/herdr-hc-client.md`. The acceptance commit and plan commit were found. This review did not run the live probe or the implementation gate.
