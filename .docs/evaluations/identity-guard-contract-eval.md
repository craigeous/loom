# Evaluation: identity-guard-contract

Verdict: FAIL
Round: 0
Reviewed against: identity-guard-contract slice plan and commit c6d3040..f698d67; code-eval rubric and severity rules.

## Findings

- [BLOCKER] The config scanner treats any read option on a line as proof that the whole line is a read. `git config --get user.name; git config user.name Evil` exits the Claude hook with status 0, allowing the second command to mutate the configured identity. The plan requires recognized writes and ambiguous forms to be blocked. The tests cover a read followed by a write only on separate lines.
- [BLOCKER] The author flag matcher requires whitespace, `=`, or end of text immediately after `--author`, so `git commit '--author' 'Evil <evil@example.com>'` is allowed despite passing the recognized flag to Git. This violates the requirement to scan quoted tokens without discarding them.
- [BLOCKER] The verifier maps every failed `git rev-parse --verify -q 'HEAD^{commit}'` to an empty HEAD and accepts it with baseline `unborn`. An existing but unreadable or corrupt HEAD is therefore treated as an unborn no-op, contrary to the required fail-closed behavior for unreadable history.

## Required changes

1. Classify config reads without allowing a read elsewhere in the command text to suppress a recognized write; add a same-line read/write regression test.
2. Recognize quote delimiters after a bare author flag and test the quoted flag in both relevant wire paths.
3. Distinguish a genuinely unborn HEAD from an existing unreadable HEAD and fail closed on the latter; add a regression test.

## Notes

The explicit repository validator passed. The helper registration, schema and metadata mirrors, and workflow wiring are included in the diff. The reviewed commit message has no attribution or co-authored-by trailer. The mandatory gate `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check` passed (636 Bats tests), and `node scripts/validate-repository.mjs --root /Users/craig/git/loom --all` passed.
