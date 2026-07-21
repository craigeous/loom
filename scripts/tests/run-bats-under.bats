#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

REPOSITORY_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
LAUNCHER="$REPOSITORY_ROOT/scripts/run-bats-under"

setup() {
    : "${LOOM_TEST_BASH:?LOOM_TEST_BASH is required}"
    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/tmp"
    CANARY="$TEST_ROOT/scripts/tests/shell-runtime.bats"
    OTHER="$TEST_ROOT/other.bats"
    mkdir -p "$(dirname "$CANARY")"
    : >"$CANARY"
    : >"$OTHER"
    FAKE_BATS="$TEST_ROOT/fake-bats"
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        'printf "%s\n" "$@" >"$LAUNCHER_RECORD"' \
        'case "${FAKE_BATS_MODE:-success}" in' \
        '  fail) exit 17 ;;' \
        '  signal) kill -TERM "$PPID"; exit 0 ;;' \
        'esac' >"$FAKE_BATS"
    chmod +x "$FAKE_BATS"
    export LAUNCHER_RECORD="$TEST_ROOT/record"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

launcher() {
    run env TMPDIR="$TEST_ROOT/tmp" LAUNCHER_RECORD="$LAUNCHER_RECORD" FAKE_BATS_MODE="${FAKE_BATS_MODE:-success}" \
        "$LOOM_TEST_BASH" "$LAUNCHER" "$@"
}

@test "launcher rejects a relative selected shell" {
    launcher bash '.*' "$FAKE_BATS" "$CANARY"
    [ "$status" -eq 2 ]
    [[ "$output" == *"shell path must be absolute"* ]]
}

@test "launcher rejects a non-executable selected shell" {
    shell_file="$TEST_ROOT/not-executable"
    : >"$shell_file"
    launcher "$shell_file" '.*' "$FAKE_BATS" "$CANARY"
    [ "$status" -eq 2 ]
    [[ "$output" == *"shell is not executable"* ]]
}

@test "launcher rejects a missing Bats entrypoint" {
    launcher "$LOOM_TEST_BASH" '.*' "$TEST_ROOT/missing-bats" "$CANARY"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Bats entrypoint is missing"* ]]
}

@test "launcher rejects a selected Bash version mismatch" {
    launcher "$LOOM_TEST_BASH" '^0\\.' "$FAKE_BATS" "$CANARY"
    [ "$status" -eq 2 ]
    [[ "$output" == *"does not match"* ]]
}

@test "launcher independently rejects Bash below 3.2" {
    fake_shell="$TEST_ROOT/bash-3.1"
    printf '%s\n' '#!/bin/sh' 'printf %s "3.1.99(1)-release"' >"$fake_shell"
    chmod +x "$fake_shell"
    launcher "$fake_shell" '^3\\.1\\.' "$FAKE_BATS" "$CANARY"
    [ "$status" -eq 2 ]
    [[ "$output" == *"below required 3.2"* ]]
}

@test "launcher rejects a missing runtime canary" {
    launcher "$LOOM_TEST_BASH" '.*' "$FAKE_BATS" "$OTHER"
    [ "$status" -eq 2 ]
    [[ "$output" == *"runtime canary is missing"* ]]
}

@test "launcher puts the runtime canary first exactly once" {
    launcher "$LOOM_TEST_BASH" '.*' "$FAKE_BATS" "$OTHER" "$CANARY" "$OTHER"
    [ "$status" -eq 0 ]
    arguments=()
    while IFS= read -r argument; do arguments+=("$argument"); done <"$LAUNCHER_RECORD"
    [ "${arguments[0]}" = "$CANARY" ]
    [ "${arguments[1]}" = "$OTHER" ]
    [ "${arguments[2]}" = "$OTHER" ]
    [ "${#arguments[@]}" -eq 3 ]
}

@test "launcher removes its private directory after success" {
    launcher "$LOOM_TEST_BASH" '.*' "$FAKE_BATS" "$CANARY"
    [ "$status" -eq 0 ]
    run find "$TEST_ROOT/tmp" -maxdepth 1 -name 'loom-bash.*' -print
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "launcher preserves failure status and removes its private directory" {
    FAKE_BATS_MODE=fail launcher "$LOOM_TEST_BASH" '.*' "$FAKE_BATS" "$CANARY"
    [ "$status" -eq 17 ]
    run find "$TEST_ROOT/tmp" -maxdepth 1 -name 'loom-bash.*' -print
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "launcher removes its private directory after a termination signal" {
    FAKE_BATS_MODE=signal launcher "$LOOM_TEST_BASH" '.*' "$FAKE_BATS" "$CANARY"
    [ "$status" -eq 143 ]
    run find "$TEST_ROOT/tmp" -maxdepth 1 -name 'loom-bash.*' -print
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
