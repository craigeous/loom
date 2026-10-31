#!/usr/bin/env bats
# Test suite for loom-verify-identity (ADR 0003; spec 08). Uses isolated repos.
bats_require_minimum_version 1.5.0

VERIFY="${BATS_TEST_DIRNAME}/loom-verify-identity"

setup_file() {
    : "${LOOM_TEST_BASH:?LOOM_TEST_BASH is required}"
    : "${LOOM_EXPECTED_BASH_VERSION:?LOOM_EXPECTED_BASH_VERSION is required}"
    case "$LOOM_TEST_BASH" in /*) ;; *) return 1 ;; esac
    [ -x "$LOOM_TEST_BASH" ]
    [[ "$($LOOM_TEST_BASH -c 'printf %s "$BASH_VERSION"')" =~ $LOOM_EXPECTED_BASH_VERSION ]]
}

setup() {
    REPO="$(mktemp -d)"
    REPO="$(CDPATH='' cd -- "$REPO" && pwd -P)"
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null GIT_CONFIG_NOSYSTEM=1
    unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
    cd "$REPO"
    git init -q .
    git config user.name "Real Person"
    git config user.email "real@example.com"
    git config commit.gpgsign false
}

teardown() {
    cd /
    [ -z "${REPO:-}" ] || rm -rf "$REPO"
}

verify() {
    run "$LOOM_TEST_BASH" "$VERIFY" "$@"
}

# commit_as <author-name> <author-email> <committer-name> <committer-email> <file>
commit_as() {
    echo "$5" >>"$5"
    git add "$5"
    GIT_AUTHOR_NAME="$1" GIT_AUTHOR_EMAIL="$2" GIT_COMMITTER_NAME="$3" GIT_COMMITTER_EMAIL="$4" \
        git commit -q -m "change $5"
}

good_commit() { commit_as "Real Person" "real@example.com" "Real Person" "real@example.com" "$1"; }

@test "usage: no argument exits 1" {
    verify
    [ "$status" -eq 1 ]
    [[ "$output" == *usage* ]]
}

@test "usage: two arguments exit 1" {
    verify unborn extra
    [ "$status" -eq 1 ]
}

@test "baseline: malformed baseline exits 1" {
    good_commit a
    verify "not-a-sha"
    [ "$status" -eq 1 ]
}

@test "baseline: well-formed but unknown SHA exits 1" {
    good_commit a
    verify "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
    [ "$status" -eq 1 ]
}

@test "not a repository exits 1" {
    NOREPO="$(mktemp -d)"
    cd "$NOREPO"
    GIT_CEILING_DIRECTORIES="$(dirname "$NOREPO")" verify unborn
    cd /
    rm -rf "$NOREPO"
    [ "$status" -eq 1 ]
}

@test "unborn baseline with still-unborn HEAD is a no-op (0)" {
    verify unborn
    [ "$status" -eq 0 ]
}

@test "unborn baseline with valid first commit exits 0" {
    good_commit a
    verify unborn
    [ "$status" -eq 0 ]
}

@test "unchanged HEAD is a no-op (0) even when HEAD identity is bad" {
    commit_as "Evil" "evil@example.com" "Evil" "evil@example.com" a
    base=$(git rev-parse HEAD)
    verify "$base"
    [ "$status" -eq 0 ]
}

@test "valid new commit after baseline exits 0" {
    good_commit a
    base=$(git rev-parse HEAD)
    good_commit b
    verify "$base"
    [ "$status" -eq 0 ]
}

@test "valid amended HEAD exits 0" {
    good_commit a
    good_commit b
    base=$(git rev-parse HEAD)
    GIT_COMMITTER_NAME="Real Person" GIT_COMMITTER_EMAIL="real@example.com" git commit -q --amend -m "amended"
    [ "$(git rev-parse HEAD)" != "$base" ]
    verify "$base"
    [ "$status" -eq 0 ]
}

@test "wrong author exits 2 with SHA and remediation" {
    good_commit a
    base=$(git rev-parse HEAD)
    commit_as "Other" "other@example.com" "Real Person" "real@example.com" b
    bad=$(git rev-parse HEAD)
    verify "$base"
    [ "$status" -eq 2 ]
    [[ "$output" == *"$bad"* ]]
    [[ "$output" == *"git commit --amend --reset-author --no-edit"* ]]
    [[ "$output" == *"STOP"* ]]
    [ "$(git rev-parse HEAD)" = "$bad" ]
}

@test "wrong committer exits 2" {
    good_commit a
    base=$(git rev-parse HEAD)
    commit_as "Real Person" "real@example.com" "Other" "other@example.com" b
    bad=$(git rev-parse HEAD)
    verify "$base"
    [ "$status" -eq 2 ]
    [[ "$output" == *"$bad"* ]]
    [[ "$output" == *"committer"* ]]
}

@test "same name but wrong email exits 2" {
    good_commit a
    base=$(git rev-parse HEAD)
    commit_as "Real Person" "other@example.com" "Real Person" "real@example.com" b
    verify "$base"
    [ "$status" -eq 2 ]
}

@test "loom@localhost fallback exits 2" {
    good_commit a
    base=$(git rev-parse HEAD)
    commit_as "loom" "loom@localhost" "loom" "loom@localhost" b
    verify "$base"
    [ "$status" -eq 2 ]
    [[ "$output" == *localhost* ]]
}

@test "configured localhost email is a config error (1)" {
    git config user.email "real@localhost"
    good_commit a
    verify unborn
    [ "$status" -eq 1 ]
}

@test "multiple new commits: a bad middle commit is found" {
    good_commit a
    base=$(git rev-parse HEAD)
    good_commit b
    commit_as "Other" "other@example.com" "Other" "other@example.com" c
    bad=$(git rev-parse HEAD)
    good_commit d
    verify "$base"
    [ "$status" -eq 2 ]
    [[ "$output" == *"$bad"* ]]
}

@test "multiple bad commits are all reported" {
    good_commit a
    base=$(git rev-parse HEAD)
    commit_as "Other" "other@example.com" "Other" "other@example.com" b
    bad1=$(git rev-parse HEAD)
    commit_as "Other" "other@example.com" "Other" "other@example.com" c
    bad2=$(git rev-parse HEAD)
    verify "$base"
    [ "$status" -eq 2 ]
    [[ "$output" == *"$bad1"* ]]
    [[ "$output" == *"$bad2"* ]]
}

@test "unborn baseline checks every commit including a bad root commit" {
    commit_as "Other" "other@example.com" "Other" "other@example.com" a
    good_commit b
    verify unborn
    [ "$status" -eq 2 ]
}

@test "missing configured user.name fails closed (1)" {
    good_commit a
    base=$(git rev-parse HEAD)
    good_commit b
    git config --unset user.name
    verify "$base"
    [ "$status" -eq 1 ]
}

@test "missing configured user.email fails closed (1)" {
    good_commit a
    base=$(git rev-parse HEAD)
    good_commit b
    git config --unset user.email
    verify "$base"
    [ "$status" -eq 1 ]
}

@test "baseline given but HEAD unborn fails closed (1)" {
    verify "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
    [ "$status" -eq 1 ]
}

@test "verifier never mutates history on violation" {
    good_commit a
    base=$(git rev-parse HEAD)
    commit_as "Other" "other@example.com" "Other" "other@example.com" b
    before=$(git rev-parse HEAD)
    count_before=$(git rev-list --all --count)
    verify "$base"
    [ "$status" -eq 2 ]
    [ "$(git rev-parse HEAD)" = "$before" ]
    [ "$(git rev-list --all --count)" = "$count_before" ]
}

@test "bypassed bad commit stops the workflow; remediation then reverifies clean" {
    good_commit a
    base=$(git rev-parse HEAD)
    commit_as "Other" "other@example.com" "Other" "other@example.com" b
    verify "$base"
    [ "$status" -eq 2 ]
    git commit -q --amend --reset-author --no-edit
    verify "$base"
    [ "$status" -eq 0 ]
}
