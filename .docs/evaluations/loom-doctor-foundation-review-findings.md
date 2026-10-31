# Review findings: loom-doctor-foundation (local review, round 0 fixes)

```text
Evidence mode: local review by the developer role
Conformance: not loom-local-review/v1; no sealed package
Isolation: not established under ADR 0022
```

Scope: the fixes for the three BLOCKER findings in
`.docs/evaluations/loom-doctor-foundation-eval.md` (Round 0, commit 812f677).

## Findings

- **C1** (correctness — fixed) `check_required_tools` now probes Bash against
  the >= 3.2 floor (honoring `LOOM_DOCTOR_BASH_VERSION`) and errors with
  `bash>=3.2`. Covered by a new Bats case at `LOOM_DOCTOR_BASH_VERSION=3.1`.
- **C2** (correctness — fixed) `check_coordination` validates the claimant
  (`[A-Za-z0-9][A-Za-z0-9._-]{0,127}`) before accepting the numeric lease
  timestamp; empty or invalid claimants are `malformed coordination state`
  errors. Covered by new Bats cases (empty claimant, invalid claimant, valid
  claimant).
- **C3** (correctness — fixed) `check_git_identity` reads Git's effective
  author identity via `git var GIT_AUTHOR_IDENT`; it errors when the probe
  fails or the name/email is empty or `loom@localhost`. Covered by new Bats
  cases for environment overrides, `author.*` config, and the placeholder.

## Residual notes

- Git may synthesize an email from the hostname when `user.useConfigOnly` is
  unset; the doctor treats whatever Git would author with as the effective
  identity. Tests set `useConfigOnly` to make incompleteness deterministic.
- Claimant validation is an inline `case` check, not shared with `loom-coord`;
  drift would be caught by the spec-defined pattern, not by code reuse.

## Verification

- `shfmt -i 4 -d` and `shellcheck -s bash` clean on `loom-doctor` and `loom`.
- `TMPDIR=/private/tmp bats plugins/loom/bin/loom-doctor.bats`: all green.
- `scripts/check` and `node scripts/validate-repository.mjs --root . --all`:
  see the slice-plan Verification Evidence.
