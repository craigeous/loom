# README Refresh

Status: Plan Review
Target specs: 00-overview.md, 10-packaging.md
Target size: <= 120 LOC net change (keep this plan <= 200 lines)

## Context

M7 slice 2 makes the root README a usable entry point for installing and using
Loom. The current README describes M0–M6 and prerequisites, but omits practical
upgrade and non-Claude setup guidance, a complete example, managed-project
artifacts, and time/cost expectations; it still says 833 tests. The requirements
are in `.docs/repository-improvement-plan.md` (slice `readme-refresh`); specs
[00](../spec/00-overview.md) and [10](../spec/10-packaging.md) govern claims.

## Out of Scope & Threat-Model Boundary

Change only `README.md` during implementation; do not change product behavior,
client adapters, specs, release status, or the test suite. Spec 00's non-goals
remain unchanged, including unsupported Windows environments and no hostile
local-process sandbox claim. Do not present private Apple-silicon dogfood or an
unverified Antigravity integration as public release conformance.

## Steps

1. **`README.md` — status and requirements.** Retain the exact `Current milestone:
   M7` marker and M0–M6 complete / M7 in progress; add M7's packaging-conformance
   completion and this slice's in-progress status. Keep the supported host matrix,
   Bash 3.2+, Git 2.34+, jq 1.6+, and exact tested client floors. Distinguish the
   prospective v0.2 release matrix from private dogfood evidence and its blocked
   Codex role launch; do not imply newer client versions are automatically supported.
2. **`README.md` — installation and upgrade.** Expand Client Integration into
   separate Claude Code, Codex CLI, and Antigravity instructions. Give the Claude
   marketplace-add/install commands already present and the corresponding update or
   reinstall procedure; for Codex use the native marketplace-add and plugin-add
   flow and `$loom-<name>` invocation. Derive exact client command syntax and upgrade
   actions from the checked-in compatibility fixtures and dogfood harness, not
   guesses; identify the local checkout/catalog paths. Explain how Antigravity
   discovers the repository's `.agents/skills/` adapters and how to refresh them
   with the matching checkout, including their dependency on the canonical Loom
   files; label this integration unverified if release evidence is absent. Preserve
   tracked project state on upgrades and direct users to the client and spec 10
   for migration or unsupported-surface limits.
3. **`README.md` — example and artifacts.** Add a small concrete example in a Git
   repository: invoke `/loom:init` then `/loom:run` with a named slice and a gate,
   follow the scope/gate prompts through planning, independent plan evaluation,
   development, gate and independent code evaluation, and remote publication.
   Show the corresponding `$loom-init` and `$loom-run` Codex spelling and explain
   that checkpoints and failures can pause the sequence. Describe tracked `.docs/`
   spec, ADR, research, slice-plans, evaluations, and status artifacts, generated
   instruction adapters, and transient local `<git-common-dir>/loom/` state (normally
   `.git/loom/`), distinguishing durable project history from local coordination.
4. **`README.md` — expectations and test count.** Add a concise tier table mapping
   Economy to researcher, Standard to developer/orchestrator, and Deep review to
   planner and evaluators; describe relative model capability and cost, client/model
   variability, and that retries and review rounds add time and tokens. Give useful
   illustrative elapsed-time ranges only if supported by reproducible evidence;
   otherwise explicitly say no reliable time or cost estimate is established and
   explain the factors affecting both. Update both 833-test references to 886 Bats
   tests, with the count identified as a snapshot rather than a permanent guarantee.

## Verification

Run the repository gate `scripts/check`. For fast iteration and final documentation
validation run:

```sh
node scripts/validate-repository.mjs --root . --all
git diff --check
```

Use `rg -n '833|886|Current milestone:|M0|M6|M7|Economy|Standard|Deep review' README.md`
and inspect the matches for stale counts, milestone and tier coverage. Check example
commands and setup paths against the shipped adapters and fixtures, and check README
links resolve. The repository validation gate covers documentation and packaging
regressions; no new tests are needed for this documentation-only slice.

## Notes

None.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft. |
