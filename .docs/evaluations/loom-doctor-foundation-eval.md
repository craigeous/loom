# Loom Doctor Foundation — Code Evaluation

Commit: 812f677
Round: 0
Verdict: FAIL

## Findings

- [BLOCKER] `check_required_tools` never checks the Bash version, yet emits `required_tools: pass` with evidence that Bash is usable even when `LOOM_DOCTOR_BASH_VERSION=3.1` makes `host_and_os` error. The plan explicitly requires this record to error unless Bash >= 3.2; include the Bash probe in this record and test its status for an unsupported version.
- [BLOCKER] `check_coordination` accepts any blob whose first line has a numeric second tab-separated field, without validating the claim's other required state. For example, a blob with an empty claimant followed by a current timestamp is reported as a fresh passing claim, despite the plan requiring malformed coordination state to error. Validate the claim record before accepting its timestamp, and cover malformed records with numeric timestamps.
- [BLOCKER] `check_git_identity` reads `GIT_AUTHOR_NAME`/`GIT_AUTHOR_EMAIL` or `user.name`/`user.email`, rather than Git's effective identity. Git also honors author-specific configuration and other identity inputs, so a usable effective identity can be reported as an error, or an incomplete effective identity reported as passing. Probe Git's effective author identity and test the supported overrides.

## Gate and review evidence

Gate rerun: `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 perl -e '$SIG{INT}="DEFAULT"; exec @ARGV' scripts/check` passed (exit 0; 830 Bats tests, metadata, format, lint, syntax, links, plugin validation, and whitespace checks).

The required review-findings artifact was not included in the explicitly permitted inputs, so its findings could not be adjudicated. This is not evidence of a clean local review.
