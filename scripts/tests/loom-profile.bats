#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

REPOSITORY_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
PROFILE="$REPOSITORY_ROOT/plugins/loom/bin/loom-profile"
DOCS=(
    "$REPOSITORY_ROOT/plugins/loom/skills/loom-playbook/references/orchestration.md"
    "$REPOSITORY_ROOT/plugins/loom/skills/loom-run/SKILL.md"
)

setup() {
    TEST_PARENT="${TMPDIR:-/tmp}"
    ROOT="$(mktemp -d "$TEST_PARENT/loom-profile-test.XXXXXX")"
    mkdir -p "$ROOT/.loom"
}

teardown() {
    case "$ROOT" in
    "$TEST_PARENT"/loom-profile-test.*) rm -rf "$ROOT" ;;
    esac
}

# expect_json <selected> <source> <recommended> <reason>
expect_json() {
    [ "$output" = "{\"selected\":\"$1\",\"source\":\"$2\",\"recommended\":\"$3\",\"reason\":\"$4\"}" ]
}

@test "default selects standard with unspecified risk" {
    run "$PROFILE" resolve "$ROOT"
    [ "$status" -eq 0 ]
    expect_json standard default standard "risk unspecified"
}

@test "risk table recommends without changing selection" {
    local row risk rec
    for row in "low light" "normal standard" "high strict"; do
        risk=${row% *}
        rec=${row#* }
        run "$PROFILE" resolve "$ROOT" --risk "$risk"
        [ "$status" -eq 0 ]
        expect_json standard default "$rec" "$risk risk"
    done
}

@test "cli profiles select with source cli" {
    local p
    for p in light standard strict; do
        run "$PROFILE" resolve "$ROOT" --profile "$p" --risk high
        [ "$status" -eq 0 ]
        expect_json "$p" cli strict "high risk"
    done
}

@test "file profile is used when no flag" {
    local p
    for p in light standard strict; do
        printf '{"profile":"%s"}\n' "$p" >"$ROOT/.loom/profile.json"
        run "$PROFILE" resolve "$ROOT" --risk low
        [ "$status" -eq 0 ]
        expect_json "$p" file light "low risk"
    done
}

@test "cli overrides a valid file" {
    printf '{"profile":"strict"}' >"$ROOT/.loom/profile.json"
    run "$PROFILE" resolve "$ROOT" --profile light
    [ "$status" -eq 0 ]
    expect_json light cli standard "risk unspecified"
}

@test "output is deterministic" {
    printf '{"profile":"light"}' >"$ROOT/.loom/profile.json"
    run "$PROFILE" resolve "$ROOT" --risk high
    first=$output
    run "$PROFILE" resolve "$ROOT" --risk high
    [ "$output" = "$first" ]
}

@test "duplicate keys follow jq last-key-wins" {
    printf '{"profile":"light","profile":"strict"}' >"$ROOT/.loom/profile.json"
    run "$PROFILE" resolve "$ROOT"
    [ "$status" -eq 0 ]
    expect_json strict file standard "risk unspecified"
}

@test "invalid config exits 1, even when cli overrides" {
    local body
    for body in '{' '' '[]' '"light"' '{}' '{"profile":1}' '{"profile":null}' \
        '{"profile":"turbo"}' '{"profile":"light","extra":1}' '{"extra":"light"}' \
        '{"profile":"light"}{"profile":"light"}'; do
        printf '%s' "$body" >"$ROOT/.loom/profile.json"
        run --separate-stderr "$PROFILE" resolve "$ROOT"
        [ "$status" -eq 1 ]
        [ -z "$output" ]
        [ -n "$stderr" ]
        run "$PROFILE" resolve "$ROOT" --profile light
        [ "$status" -eq 1 ]
    done
}

@test "symlink and non-regular profile paths exit 1" {
    printf '{"profile":"light"}' >"$ROOT/real.json"
    ln -s "$ROOT/real.json" "$ROOT/.loom/profile.json"
    run "$PROFILE" resolve "$ROOT"
    [ "$status" -eq 1 ]
    rm "$ROOT/.loom/profile.json"
    mkdir "$ROOT/.loom/profile.json"
    run "$PROFILE" resolve "$ROOT"
    [ "$status" -eq 1 ]
}

@test "usage errors exit 2" {
    local args
    for args in "" "resolve" "bogus $ROOT" "resolve $ROOT --profile" "resolve $ROOT --risk" \
        "resolve $ROOT --profile turbo" "resolve $ROOT --risk extreme" \
        "resolve $ROOT --profile light --profile strict" \
        "resolve $ROOT --risk low --risk high" "resolve $ROOT --unknown x" "resolve $ROOT extra"; do
        # shellcheck disable=SC2086
        run "$PROFILE" $args
        [ "$status" -eq 2 ]
    done
}

@test "missing repo directory exits 1" {
    run "$PROFILE" resolve "$ROOT/nope"
    [ "$status" -eq 1 ]
}

@test "docs document workflow profiles without skip language" {
    local doc section
    for doc in "${DOCS[@]}"; do
        grep -Fxq '## Workflow Profiles' "$doc"
        section=$(awk '/^## /{on=($0=="## Workflow Profiles")} on' "$doc")
        for phrase in Light Standard Strict 'resume reads the recorded profile' \
            'invalid configuration stops dispatch' \
            'all required lifecycle stages remain mandatory' \
            'advisory human pauses before developer dispatch and publication'; do
            printf '%s\n' "$section" | tr '\n' ' ' | sed 's/  */ /g' | grep -Fq "$phrase"
        done
        ! printf '%s\n' "$section" | tr '\n' ' ' | sed 's/  */ /g' |
            grep -Eiq '(^|[^[:alpha:]])(skip|skips|skippable)[[:space:]]+(any |required )?(lifecycle |stage|gate|review|evaluation)'
    done
}
