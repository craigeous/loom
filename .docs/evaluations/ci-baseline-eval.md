# Evaluation: Reproducible local check and dual-platform CI baseline

Verdict: FAIL
Round: 1
Reviewed against: approved specs 08 and 10; accepted ADRs 0018 and 0019;
repository improvement plan M0; approved dual-platform architecture research;
the current repository and installed Claude Code 2.1.216/Codex CLI 0.144.6 command
surfaces; plan-evaluation rubric and severity rules.

## Findings

- [BLOCKER] The plan defers the adapter matrix that ADR 0019 assigns to M0 —
  `Explicitly out of scope` excludes install, workflow/role/hook/helper behavior,
  and uninstall (lines 70–76), and Step 8 expressly runs neither Codex nor an
  install smoke (lines 333–339). ADR 0019 §3 instead says M0 SHALL run both exact
  client floors through clean install, manifest/marketplace loading, explicit
  workflow invocation, cold-role launch, hook fixtures, helper resolution, and
  uninstall. Spec 10 §Validation matrix and the approved research's M0 impact say
  the same dual-client behavior cannot be replaced by schema checks. The plan is
  commendably explicit that Codex metadata validation is not install evidence, but
  that honesty does not satisfy the required M0 evidence.

- [BLOCKER] The negative JSON fixtures conflict with the real-repository metadata
  gate — Step 1 requires a tracked malformed-JSON fixture below
  `scripts/tests/fixtures/metadata/**` and invokes each fixture root directly, while
  Step 3 requires the real-root validator to parse *every tracked `*.json`*. The
  malformed fixture therefore makes `scripts/validate-repository.mjs --metadata`
  fail permanently on the real tree. The stated metadata-green and unified-green
  transitions cannot both occur as written.

- [BLOCKER] The CI sketch does not establish the declared host/Bash matrix. The
  supported contract includes macOS on both Apple silicon and x86-64, but the sole
  `macos-14` cell currently selects an arm64 GitHub-hosted runner; there is no Intel
  cell or other x86-64 evidence. Separately, invoking `scripts/check` with
  `/bin/bash` does not prove Bats runs under it: Bats 1.13.0 starts with
  `#!/usr/bin/env bash`, and the inspected macOS environment resolves Homebrew Bash
  before `/bin/bash`. Without an explicit controlled child-shell binding and
  assertion, the claimed Bash 3.2 behavioral run may actually execute under Bash
  5.x. See GitHub's current
  [runner architecture table](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).

- [MAJOR] Link validation has no executable regression suite — the only new Bats
  file and required fixtures are metadata-focused. Running `--links` against the
  currently clean real tree proves only a happy path; it does not prove rejection of
  a missing target, malformed/duplicate/stale allowlist entry, a disallowed
  directory exclusion, or a bad fragment when fragment validation is supported.
  Those are substantive behaviors promised by Step 3, so an independent
  implementation could silently accept regressions while the stated gate remains
  green.

## Required changes (for FAIL)

1. Reconcile the M0 plan with ADR 0019: include pinned, isolated floor-client
   adapter-matrix evidence for both clients, or obtain a reviewed authority change;
   continue to distinguish Codex schema validation from install/behavior evidence.
2. Materialize malformed JSON only in an untracked temporary fixture root (for
   example from a non-`.json` seed), so the real-tree all-tracked-JSON invariant and
   the negative test can coexist.
3. Add macOS Intel evidence and specify how every Bats child process is forced onto
   and verifies the selected lane's Bash, including `/bin/bash` 3.2 on macOS.
4. Add positive and negative link-validator fixtures/tests covering targets,
   exclusions, allowlist parsing/duplication/staleness, and supported fragments.

## Notes

Live checks confirm the plan's starting facts: shfmt 3.13.1, ShellCheck 0.11.0,
Bats 1.13.0 with 103 discovered tests, Claude Code 2.1.216 reporting the `run.md`
YAML error plus missing manifest version, and Codex CLI 0.144.6 exposing
marketplace/plugin add/list/remove but no validator. The narrow `run.md`
frontmatter quotation and Claude version addition address that known red baseline.
