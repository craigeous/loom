#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

REPOSITORY_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"

setup() {
    : "${LOOM_NODE:?LOOM_NODE is required}"
    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/scripts/check-tools" "$TEST_ROOT/.github/workflows"
    cp "$REPOSITORY_ROOT/scripts/check" "$TEST_ROOT/scripts/check"
    cp "$REPOSITORY_ROOT/scripts/check-toolchain.json" "$TEST_ROOT/scripts/check-toolchain.json"
    cp "$REPOSITORY_ROOT/scripts/check-tools/package-lock.json" "$TEST_ROOT/scripts/check-tools/package-lock.json"
    cp "$REPOSITORY_ROOT/.github/workflows/check.yml" "$TEST_ROOT/.github/workflows/check.yml"
    while IFS= read -r vendored; do
        mkdir -p "$TEST_ROOT/$(dirname "$vendored")"
        cp "$REPOSITORY_ROOT/$vendored" "$TEST_ROOT/$vendored"
    done < <(jq -r '.vendored[].path' "$REPOSITORY_ROOT/scripts/check-toolchain.json")
}

teardown() {
    rm -rf "$TEST_ROOT"
}

contract_check() {
    run env LOOM_CHECK_CONTRACT_ONLY=1 /bin/bash "$TEST_ROOT/scripts/check"
}

rewrite_workflow() {
    "$LOOM_NODE" -e 'const fs=require("fs"),f=process.argv[1],old=process.argv[2],next=process.argv[3];const text=fs.readFileSync(f,"utf8");if(!text.includes(old))process.exit(2);fs.writeFileSync(f,text.replace(old,next))' \
        "$TEST_ROOT/.github/workflows/check.yml" "$1" "$2"
}

mutate_contract() {
    expression="$1"
    jq "$expression" "$TEST_ROOT/scripts/check-toolchain.json" >"$TEST_ROOT/contract.next"
    mv "$TEST_ROOT/contract.next" "$TEST_ROOT/scripts/check-toolchain.json"
}

@test "exact workflow runner matrix passes" {
    contract_check
    [ "$status" -eq 0 ]
}

@test "workflow runner row deletion fails" {
    "$LOOM_NODE" -e 'const fs=require("fs"),f=process.argv[1];let s=fs.readFileSync(f,"utf8");s=s.replace(/          - runner: macos-15-intel\n(?:            .*\n){5}/,"");fs.writeFileSync(f,s)' "$TEST_ROOT/.github/workflows/check.yml"
    contract_check
    [ "$status" -ne 0 ]
    [[ "$output" == *"workflow runner matrix differs"* ]]
}

@test "workflow runner label mutation fails" {
    rewrite_workflow '          - runner: ubuntu-22.04' '          - runner: ubuntu-20.04'
    contract_check
    [ "$status" -ne 0 ]
}

@test "workflow host mutation fails" {
    rewrite_workflow '            host: Linux' '            host: Other'
    contract_check
    [ "$status" -ne 0 ]
}

@test "workflow architecture mutation fails" {
    rewrite_workflow '            architecture: x86_64' '            architecture: arm64'
    contract_check
    [ "$status" -ne 0 ]
}

@test "workflow release mutation fails" {
    rewrite_workflow '            release: "22.04"' '            release: "20.04"'
    contract_check
    [ "$status" -ne 0 ]
}

@test "workflow selected shell mutation fails" {
    rewrite_workflow '            shell: /usr/bin/bash' '            shell: /bin/bash'
    contract_check
    [ "$status" -ne 0 ]
}

@test "workflow Bash regex mutation fails" {
    rewrite_workflow "            bash_regex: '^5\\.'" "            bash_regex: '^4\\.'"
    contract_check
    [ "$status" -ne 0 ]
}

@test "toolchain runner deletion fails closed" {
    mutate_contract 'del(.runners[3])'
    contract_check
    [ "$status" -ne 0 ]
}

@test "required download deletion fails closed" {
    mutate_contract 'del(.downloads[0])'
    contract_check
    [ "$status" -ne 0 ]
}

@test "download platform mutation fails closed" {
    mutate_contract '.downloads[0].platform="other"'
    contract_check
    [ "$status" -ne 0 ]
}

@test "download URL mutation fails closed" {
    mutate_contract '.downloads[0].url="https://example.invalid/tool"'
    contract_check
    [ "$status" -ne 0 ]
}

@test "download digest mutation fails closed on an unselected platform" {
    mutate_contract '.downloads[1].sha256=("0" * 64)'
    contract_check
    [ "$status" -ne 0 ]
}

@test "required vendored asset deletion fails closed" {
    mutate_contract 'del(.vendored[0])'
    contract_check
    [ "$status" -ne 0 ]
}

@test "vendored asset path mutation fails closed" {
    mutate_contract '.vendored[0].path="scripts/schemas/alternate.json"'
    contract_check
    [ "$status" -ne 0 ]
}

@test "vendored provenance omission fails closed" {
    mutate_contract 'del(.vendored[0].provenance)'
    contract_check
    [ "$status" -ne 0 ]
}

@test "vendored provenance kind mutation fails closed" {
    mutate_contract '.vendored[0].kind="unknown"'
    contract_check
    [ "$status" -ne 0 ]
}

@test "vendored digest mutation fails closed" {
    mutate_contract '.vendored[0].sha256=("0" * 64)'
    contract_check
    [ "$status" -ne 0 ]
}

@test "gate independently rejects a selected Bash below 3.2" {
    fake_shell="$TEST_ROOT/bash-3.1"
    printf '%s\n' '#!/bin/sh' 'printf %s "3.1.99"' >"$fake_shell"
    chmod +x "$fake_shell"
    run env LOOM_CHECK_BASH_ONLY=1 LOOM_TEST_BASH="$fake_shell" LOOM_EXPECTED_BASH_VERSION='^3\\.1' /bin/bash "$TEST_ROOT/scripts/check"
    [ "$status" -ne 0 ]
    [[ "$output" == *"selected LOOM_TEST_BASH 3.1.99 is below required 3.2"* ]]
}

prepare_cached_downloads() {
    case "$(uname -s):$(uname -m)" in
    Darwin:arm64) platform=darwin-arm64 ;;
    Darwin:x86_64) platform=darwin-x86_64 ;;
    Linux:x86_64) platform=linux-x86_64 ;;
    *) return 1 ;;
    esac
    mkdir -p "$TEST_ROOT/.check-cache/downloads"
    for tool in shfmt shellcheck node bats; do
        cp "$REPOSITORY_ROOT/.check-cache/downloads/$tool-$platform" "$TEST_ROOT/.check-cache/downloads/$tool-$platform"
    done
}

provision_check() {
    run env LOOM_CHECK_PROVISION_ONLY=1 /bin/bash "$TEST_ROOT/scripts/check"
}

@test "fresh provisioning ignores a poisoned persistent extracted-tool tree" {
    prepare_cached_downloads
    mkdir -p "$TEST_ROOT/.check-cache/tools/node/bin"
    marker="$TEST_ROOT/executed"
    printf '%s\n' '#!/bin/sh' ": >'$marker'" 'printf v22.17.0' >"$TEST_ROOT/.check-cache/tools/node/bin/node"
    chmod +x "$TEST_ROOT/.check-cache/tools/node/bin/node"
    provision_check
    [ "$status" -eq 0 ]
    [ ! -e "$marker" ]
    run find "$TEST_ROOT/.check-cache" -maxdepth 1 -name 'run.*' -print
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "cache-root symlink is rejected without touching its target" {
    sentinel_directory="$(mktemp -d)"
    sentinel="$sentinel_directory/value"
    printf 'unchanged\n' >"$sentinel"
    ln -s "$sentinel_directory" "$TEST_ROOT/.check-cache"
    provision_check
    [ "$status" -ne 0 ]
    [ "$(cat "$sentinel")" = unchanged ]
    rm -rf "$sentinel_directory"
}

@test "cached-download symlink is rejected without overwriting its target" {
    prepare_cached_downloads
    sentinel="$TEST_ROOT/sentinel"
    printf 'unchanged\n' >"$sentinel"
    rm "$TEST_ROOT/.check-cache/downloads/shfmt-$platform"
    ln -s "$sentinel" "$TEST_ROOT/.check-cache/downloads/shfmt-$platform"
    provision_check
    [ "$status" -ne 0 ]
    [ "$(cat "$sentinel")" = unchanged ]
}
