# Review findings: herdr-client-adapter (local review, round 0 fixes)

```text
Evidence mode: local review by the developer role
Conformance: not loom-local-review/v1; no sealed package
Isolation: not established under ADR 0022
```

Scope: the findings in `.docs/evaluations/herdr-client-adapter-eval.md`
(Round 0, commit 2f52d69) and the fixes applied for them.

## Findings

- **R1** (correctness, major — fixed) The plan's three affirmative launch checks
  invoked `plugins/loom/bin/loom-launch-role` by relative path, which the launcher
  rejects by design. The checks now use `"$PWD/plugins/loom/bin/loom-launch-role"`
  and were re-run; all three print `true`. The launcher contract is unchanged.
- **R2** (validation coverage, minor — fixed) `scripts/validate-repository.mjs` never
  read the Herdr metadata. `.herdr-plugin/marketplace.json` is now an authorized
  catalog and both Herdr files are claim surfaces. A new `validateHerdrMetadata`
  checks `name == loom`, `version == 0.2.0`, a non-empty `description` and
  (marketplace) `source == ./plugins/loom`. Changing the manifest `name` makes
  `--all` fail.

## Residual notes

- `plugins/loom/.herdr-plugin/plugin.json` has no `main` field. The validator accepts
  `main` only as `bin/loom-doctor` when present and does not require it, because
  neither ADR 0029 nor the research note specifies one. Requiring it needs a planner
  decision plus a manifest change.
- No cold finders ran; this record is not a `loom-local-review/v1` run.
