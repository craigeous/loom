# Evaluation: identity-guard-contract

Verdict: FAIL
Round: 1
Reviewed against: identity-guard-contract slice plan and revision diff f698d67..9d207c8; code-eval rubric and severity rules.

## Findings

- [BLOCKER] Unreadable HEAD handling remains incomplete. In the new unborn check, `[ -e "$REF_PATH" ]` follows symlinks and returns false for a dangling symlink. In a freshly initialized repository with configured identity, creating `.git/refs/heads/<HEAD branch>` as a symlink to a nonexistent path causes `loom-verify-identity unborn` to exit 0 even though the HEAD ref exists and is corrupt. The plan requires unreadable or corrupt history to fail closed. This is a deterministic failure of that explicit invariant and an unresolved Round 0 finding.

## Required changes

1. Treat a dangling symbolic link at the HEAD ref path as an existing corrupt ref, and add an isolated-repository regression test asserting exit 1 for an unborn baseline.

## Notes

The revision splits config statements on `;`, `&`, and `|`, resolving the reported same-line read/write examples, and accepts quote delimiters after `--author`, resolving the reported quoted flag in both client wire paths. The verifier now rejects the tested corrupt ref contents and corrupt HEAD file, but its existence test leaves the dangling-ref case above unresolved. The mandatory gate `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check` passed (640 Bats tests), and `node scripts/validate-repository.mjs --root /Users/craig/git/loom --all` passed.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 0 | code | FAIL | Same-line config read/write and quoted author flag resolved in f698d67..9d207c8; unreadable HEAD handling remains incomplete as described above. |
