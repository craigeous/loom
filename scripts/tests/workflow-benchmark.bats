#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

REPOSITORY_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
BENCH="$REPOSITORY_ROOT/scripts/workflow-benchmark.sh"
WORKLOADS="doc-fix localized-bug feature security architecture"

setup() {
    TEST_PARENT="${TMPDIR:-/tmp}"
    ROOT="$(mktemp -d "$TEST_PARENT/loom-wb-test.XXXXXX")"
    OUT="$ROOT/out"
}

teardown() {
    case "$ROOT" in
    "$TEST_PARENT"/loom-wb-test.*) rm -rf "$ROOT" ;;
    esac
}

# Fill one record with complete data; extra jq filter is applied afterwards.
complete_record() {
    local file=$1 wall=$2 extra=${3:-.}
    jq --argjson wall "$wall" '
        .status = "success"
        | .timestamps = {start: "2026-01-01T00:00:00Z", end: "2026-01-01T01:00:00Z", interruptions: []}
        | .wallClockSeconds = $wall | .agentCount = 3 | .tokenInput = 100 | .tokenOutput = 50
        | .estimatedCostUsd = 1.25 | .commits = 2 | .reviewRounds = 1 | .defectsIntroduced = 0
        | .defectsCaught = 1 | .humanInterventions = 0
        | .provenance |= with_entries(.value = "x")
        | .evidence.testOutcomes = ["pass"] | .evidence.paths = ["p"]' "$file" |
        jq "$extra" >"$file.new"
    mv "$file.new" "$file"
}

complete_all() {
    local w m
    for w in $WORKLOADS; do
        for m in loom single-agent; do
            complete_record "$OUT/records/$w--$m.json" 100
        done
    done
}

edit() {
    jq "$2" "$OUT/records/$1.json" >"$ROOT/edit.json"
    mv "$ROOT/edit.json" "$OUT/records/$1.json"
}

# Run validate and summarize; both must fail with the same status and token.
rejects() {
    local token=$1 field=${2:-}
    run --separate-stderr "$BENCH" validate "$OUT"
    [ "$status" -eq 1 ]
    [[ "$stderr" == *"$token"* ]]
    [[ "$stderr" == *"$field"* ]]
    run --separate-stderr "$BENCH" summarize "$OUT"
    [ "$status" -eq 1 ]
    [[ "$stderr" == *"$token"* ]]
    [[ "$stderr" == *"$field"* ]]
    [ -z "$output" ]
}

@test "init creates manifest and ten distinct templates that validate" {
    run "$BENCH" init "$OUT"
    [ "$status" -eq 0 ]
    jq -e '.schemaVersion == "loom-workflow-benchmark/v1" and (.records | length == 10)
        and ((.records | unique | length) == 10)' "$OUT/manifest.json"
    [ "$(find "$OUT/records" -name '*.json' | wc -l | tr -d ' ')" -eq 10 ]
    jq -e '.status == "incomplete" and .wallClockSeconds == null
        and .timestamps.start == null and .timestamps.interruptions == []' \
        "$OUT/records/doc-fix--loom.json"
    run "$BENCH" validate "$OUT"
    [ "$status" -eq 0 ]
}

@test "init refuses an existing directory and leaves it unchanged" {
    mkdir "$OUT"
    echo keep >"$OUT/file"
    run --separate-stderr "$BENCH" init "$OUT"
    [ "$status" -eq 1 ]
    [[ "$stderr" == *exists* ]]
    [ "$(cat "$OUT/file")" = keep ]
    [ "$(ls "$OUT")" = file ]
}

@test "usage errors exit 2" {
    for args in "" "init" "bogus x" "validate a b" "summarize"; do
        # shellcheck disable=SC2086
        run --separate-stderr "$BENCH" $args
        [ "$status" -eq 2 ]
        [[ "$stderr" == *usage* ]]
    done
}

@test "complete dataset validates and summarizes" {
    "$BENCH" init "$OUT"
    complete_all
    run "$BENCH" validate "$OUT"
    [ "$status" -eq 0 ]
    run "$BENCH" summarize "$OUT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"wallClockSeconds: loom=100 single-agent=100 delta=0"* ]]
}

@test "delta is loom minus single-agent in both directions" {
    "$BENCH" init "$OUT"
    complete_all
    complete_record "$OUT/records/feature--loom.json" 120
    complete_record "$OUT/records/feature--single-agent.json" 90
    run "$BENCH" summarize "$OUT"
    [[ "$output" == *"wallClockSeconds: loom=120 single-agent=90 delta=30"* ]]
    complete_record "$OUT/records/feature--loom.json" 90
    complete_record "$OUT/records/feature--single-agent.json" 120
    run "$BENCH" summarize "$OUT"
    [[ "$output" == *"wallClockSeconds: loom=90 single-agent=120 delta=-30"* ]]
}

@test "incomplete members and null metrics with reasons yield unknown" {
    "$BENCH" init "$OUT"
    complete_all
    run "$BENCH" validate "$OUT"
    [ "$status" -eq 0 ]
    complete_record "$OUT/records/security--loom.json" 100 \
        '.tokenInput = null | .unknownReasons = {tokenInput: "not exported"}'
    edit doc-fix--single-agent '.status = "incomplete" | .wallClockSeconds = 7'
    run "$BENCH" summarize "$OUT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"tokenInput: loom=unknown single-agent=100 delta=unknown"* ]]
    [[ "$output" == *"tokenOutput: loom=50 single-agent=50 delta=0"* ]]
    [[ "$output" == *"wallClockSeconds: loom=100 single-agent=7 delta=unknown"* ]]
}

@test "missing manifest and missing record" {
    run --separate-stderr "$BENCH" validate "$OUT"
    [ "$status" -eq 1 ]
    [[ "$stderr" == *missing* ]]
    "$BENCH" init "$OUT"
    rm "$OUT/records/feature--loom.json"
    rejects missing feature--loom
}

edit_wrong_keys() {
    edit feature--loom '.extra = 1'
}

@test "malformed json and wrong schema or keys" {
    "$BENCH" init "$OUT"
    echo '{' >"$OUT/records/feature--loom.json"
    rejects invalid feature--loom
    rm -rf "$OUT"
    "$BENCH" init "$OUT"
    edit_wrong_keys
    rejects invalid feature--loom
    jq '.schemaVersion = "v0"' "$OUT/manifest.json" >"$ROOT/x" && mv "$ROOT/x" "$OUT/manifest.json"
    rejects invalid manifest
}

@test "duplicate pair names the pair" {
    "$BENCH" init "$OUT"
    jq '.records[1] = .records[0]' "$OUT/manifest.json" >"$ROOT/x" && mv "$ROOT/x" "$OUT/manifest.json"
    rejects duplicate doc-fix--loom
}

@test "negative, noninteger, and bad values name the field" {
    "$BENCH" init "$OUT"
    complete_all
    edit feature--loom '.wallClockSeconds = -1'
    rejects invalid wallClockSeconds
    complete_record "$OUT/records/feature--loom.json" 100 '.commits = 1.5'
    rejects invalid commits
    complete_record "$OUT/records/feature--loom.json" 100 '.agentCount = "3"'
    rejects invalid agentCount
    complete_record "$OUT/records/feature--loom.json" 100
    edit feature--loom '.workload = "other"'
    rejects invalid workload
    edit feature--loom '.workload = "feature"'
    edit feature--loom '.mode = "single-agent"'
    rejects invalid mode
    edit feature--loom '.mode = "loom"'
    edit feature--loom '.status = "done"'
    rejects invalid status
}

@test "invalid and reversed timestamps" {
    "$BENCH" init "$OUT"
    complete_all
    edit feature--loom '.timestamps.start = "yesterday"'
    rejects invalid timestamps
    complete_record "$OUT/records/feature--loom.json" 100
    edit feature--loom '.timestamps.end = "2025-01-01T00:00:00Z"'
    rejects invalid timestamps
    complete_record "$OUT/records/feature--loom.json" 100
    edit feature--loom '.timestamps.end = null'
    rejects invalid timestamps
}

@test "missing provenance, evidence, and unknown reason" {
    "$BENCH" init "$OUT"
    complete_all
    edit feature--loom '.provenance.model = ""'
    rejects provenance model
    complete_record "$OUT/records/feature--loom.json" 100
    edit feature--loom '.evidence.paths = []'
    rejects evidence paths
    complete_record "$OUT/records/feature--loom.json" 100
    edit feature--loom '.evidence.testOutcomes = []'
    rejects evidence testOutcomes
    complete_record "$OUT/records/feature--loom.json" 100
    edit feature--loom '.commits = null'
    rejects "unknown reason" commits
}
