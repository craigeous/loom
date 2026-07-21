#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

REPOSITORY_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
LAUNCHER="$REPOSITORY_ROOT/scripts/run-bats-under"

setup() {
    : "${LOOM_TEST_BASH:?LOOM_TEST_BASH is required}"
    SHELL_TEST_PARENT="${TMPDIR:-/tmp}"
    SHELL_TEST_ROOT="$(mktemp -d "$SHELL_TEST_PARENT/loom-shell-test.XXXXXX")"
    case "$SHELL_TEST_ROOT" in
    "$SHELL_TEST_PARENT"/loom-shell-test.*) ;;
    *) return 1 ;;
    esac
    : >"$SHELL_TEST_ROOT/.loom-shell-test-owned"
    mkdir -p "$SHELL_TEST_ROOT/tmp"
    CANARY="$SHELL_TEST_ROOT/scripts/tests/shell-runtime.bats"
    OTHER="$SHELL_TEST_ROOT/other.bats"
    mkdir -p "$(dirname "$CANARY")"
    : >"$CANARY"
    : >"$OTHER"
    FAKE_BATS="$SHELL_TEST_ROOT/fake-bats"
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        'printf "%s\n" "$@" >"$LAUNCHER_RECORD"' \
        'case "${FAKE_BATS_MODE:-success}" in' \
        '  fail) exit 17 ;;' \
        '  signal) kill -TERM "$PPID"; exit 0 ;;' \
        'esac' >"$FAKE_BATS"
    chmod +x "$FAKE_BATS"
    export LAUNCHER_RECORD="$SHELL_TEST_ROOT/record"
}

teardown() {
    case "$SHELL_TEST_ROOT" in
    "$SHELL_TEST_PARENT"/loom-shell-test.*) ;;
    *) return 1 ;;
    esac
    [ -d "$SHELL_TEST_ROOT" ] && [ ! -L "$SHELL_TEST_ROOT" ] && [ -f "$SHELL_TEST_ROOT/.loom-shell-test-owned" ]
    rm -rf -- "$SHELL_TEST_ROOT"
}

launcher() {
    run env TMPDIR="$SHELL_TEST_ROOT/tmp" LAUNCHER_RECORD="$LAUNCHER_RECORD" FAKE_BATS_MODE="${FAKE_BATS_MODE:-success}" \
        "$LOOM_TEST_BASH" "$LAUNCHER" "$@"
}

@test "Bats and an env-bash executable child use the selected Bash" {
    : "${LOOM_EXPECTED_BASH_VERSION:?LOOM_EXPECTED_BASH_VERSION is required}"
    [[ "$BASH_VERSION" =~ $LOOM_EXPECTED_BASH_VERSION ]]
    printf 'bats-process BASH_VERSION=%s\n' "$BASH_VERSION" >&3
    run "$BATS_TEST_DIRNAME/fixtures/runtime-child"
    [ "$status" -eq 0 ]
    [[ "$output" == "executable-child BASH_VERSION=$BASH_VERSION" ]]
    printf '%s\n' "$output" >&3
}

@test "launcher rejects a relative selected shell" {
    launcher bash '.*' "$FAKE_BATS" "$CANARY"
    [ "$status" -eq 2 ]
    [[ "$output" == *"shell path must be absolute"* ]]
}

@test "launcher rejects a non-executable selected shell" {
    shell_file="$SHELL_TEST_ROOT/not-executable"
    : >"$shell_file"
    launcher "$shell_file" '.*' "$FAKE_BATS" "$CANARY"
    [ "$status" -eq 2 ]
    [[ "$output" == *"shell is not executable"* ]]
}

@test "launcher rejects a missing Bats entrypoint" {
    launcher "$LOOM_TEST_BASH" '.*' "$SHELL_TEST_ROOT/missing-bats" "$CANARY"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Bats entrypoint is missing"* ]]
}

@test "launcher rejects a selected Bash version mismatch" {
    launcher "$LOOM_TEST_BASH" '^0\\.' "$FAKE_BATS" "$CANARY"
    [ "$status" -eq 2 ]
    [[ "$output" == *"does not match"* ]]
}

@test "launcher independently rejects Bash below 3.2" {
    fake_shell="$SHELL_TEST_ROOT/bash-3.1"
    printf '%s\n' '#!/bin/sh' 'printf %s "3.1.99(1)-release"' >"$fake_shell"
    chmod +x "$fake_shell"
    launcher "$fake_shell" '^3\\.1\\.' "$FAKE_BATS" "$CANARY"
    [ "$status" -eq 2 ]
    [[ "$output" == *"below required 3.2"* ]]
}

@test "launcher resolves a terminal selected-shell symlink" {
    ln -s "$LOOM_TEST_BASH_PHYSICAL" "$SHELL_TEST_ROOT/terminal-bash"
    launcher "$SHELL_TEST_ROOT/terminal-bash" "$LOOM_EXPECTED_BASH_VERSION" "$FAKE_BATS" "$CANARY"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Selected Bash: $LOOM_TEST_BASH_PHYSICAL"* ]]
}

@test "launcher resolves relative multihop symlinks before links are retargeted" {
    mkdir -p "$SHELL_TEST_ROOT/links/sub"
    ln -s "$LOOM_TEST_BASH_PHYSICAL" "$SHELL_TEST_ROOT/links/sub/terminal"
    ln -s sub/terminal "$SHELL_TEST_ROOT/links/selected"
    retarget_bats="$SHELL_TEST_ROOT/retarget-bats"
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        'rm "$RELINK_SELECTED" "$RELINK_TERMINAL"' \
        'ln -s /bin/false "$RELINK_SELECTED"' \
        'ln -s /bin/false "$RELINK_TERMINAL"' \
        'printf "%s\n" "$LOOM_TEST_BASH_PHYSICAL" "$BASH_VERSION" "$(bash -c '\''printf %s "$BASH_VERSION"'\'')" >"$LAUNCHER_RECORD"' >"$retarget_bats"
    chmod +x "$retarget_bats"
    export RELINK_SELECTED="$SHELL_TEST_ROOT/links/selected"
    export RELINK_TERMINAL="$SHELL_TEST_ROOT/links/sub/terminal"
    launcher "$SHELL_TEST_ROOT/links/selected" "$LOOM_EXPECTED_BASH_VERSION" "$retarget_bats" "$CANARY"
    [ "$status" -eq 0 ]
    mapfile=()
    while IFS= read -r line; do mapfile+=("$line"); done <"$LAUNCHER_RECORD"
    [ "${mapfile[0]}" = "$LOOM_TEST_BASH_PHYSICAL" ]
    [[ "${mapfile[1]}" =~ $LOOM_EXPECTED_BASH_VERSION ]]
    [[ "${mapfile[2]}" =~ $LOOM_EXPECTED_BASH_VERSION ]]
}

@test "launcher rejects a selected-shell symlink loop" {
    ln -s loop-b "$SHELL_TEST_ROOT/loop-a"
    ln -s loop-a "$SHELL_TEST_ROOT/loop-b"
    launcher "$SHELL_TEST_ROOT/loop-a" '.*' "$FAKE_BATS" "$CANARY"
    [ "$status" -eq 2 ]
    [[ "$output" == *"too deep or cyclic"* ]]
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
    run find "$SHELL_TEST_ROOT/tmp" -maxdepth 1 -name 'loom-bash.*' -print
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "launcher preserves failure status and removes its private directory" {
    FAKE_BATS_MODE=fail launcher "$LOOM_TEST_BASH" '.*' "$FAKE_BATS" "$CANARY"
    [ "$status" -eq 17 ]
    run find "$SHELL_TEST_ROOT/tmp" -maxdepth 1 -name 'loom-bash.*' -print
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "launcher removes its private directory after a termination signal" {
    FAKE_BATS_MODE=signal launcher "$LOOM_TEST_BASH" '.*' "$FAKE_BATS" "$CANARY"
    [ "$status" -eq 143 ]
    run find "$SHELL_TEST_ROOT/tmp" -maxdepth 1 -name 'loom-bash.*' -print
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
