#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

@test "Bats and an env-bash executable child use the selected Bash" {
    : "${LOOM_EXPECTED_BASH_VERSION:?LOOM_EXPECTED_BASH_VERSION is required}"
    [[ "$BASH_VERSION" =~ $LOOM_EXPECTED_BASH_VERSION ]]
    printf 'bats-process BASH_VERSION=%s\n' "$BASH_VERSION" >&3
    run "$BATS_TEST_DIRNAME/fixtures/runtime-child"
    [ "$status" -eq 0 ]
    [[ "$output" == "executable-child BASH_VERSION=$BASH_VERSION" ]]
    printf '%s\n' "$output" >&3
}
