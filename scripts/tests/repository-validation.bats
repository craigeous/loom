#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

REPOSITORY_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
VALIDATOR="$REPOSITORY_ROOT/scripts/validate-repository.mjs"
OVERLAYS="$REPOSITORY_ROOT/scripts/tests/fixtures/overlays"

setup_file() {
    : "${LOOM_NODE:?LOOM_NODE must name the absolute pinned Node executable}"
    case "$LOOM_NODE" in /*) ;; *) return 1 ;; esac
    [ -x "$LOOM_NODE" ]
}

teardown() {
    if [ -n "${TEST_ROOT:-}" ] && [ -d "$TEST_ROOT" ]; then
        rm -rf "$TEST_ROOT"
    fi
}

make_metadata_root() {
    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.claude-plugin" "$TEST_ROOT/.agents/plugins" "$TEST_ROOT/plugins" "$TEST_ROOT/scripts"
    cp -R "$REPOSITORY_ROOT/plugins/loom" "$TEST_ROOT/plugins/loom"
    cp "$REPOSITORY_ROOT/.claude-plugin/marketplace.json" "$TEST_ROOT/.claude-plugin/marketplace.json"
    cp "$REPOSITORY_ROOT/.agents/plugins/marketplace.json" "$TEST_ROOT/.agents/plugins/marketplace.json"
    cp -R "$REPOSITORY_ROOT/scripts/schemas" "$TEST_ROOT/scripts/schemas"
    mkdir -p "$TEST_ROOT/scripts/validation"
    cp "$REPOSITORY_ROOT/scripts/validation/relative-link-allowlist.txt" "$TEST_ROOT/scripts/validation/relative-link-allowlist.txt"
}

apply_overlay() {
    local overlay="$1" source destination
    while IFS= read -r source; do
        destination="${source#"$OVERLAYS/$overlay/"}"
        case "$destination" in
        *.json.in) destination="${destination%.in}" ;;
        *.md.in) destination="${destination%.in}" ;;
        *.allowlist.in) destination="${destination%.allowlist.in}/relative-link-allowlist.txt" ;;
        *) return 1 ;;
        esac
        mkdir -p "$TEST_ROOT/$(dirname "$destination")"
        cp "$source" "$TEST_ROOT/$destination"
    done < <(find "$OVERLAYS/$overlay" -type f | sort)
}

metadata() {
    run "$LOOM_NODE" "$VALIDATOR" --root "$TEST_ROOT" --metadata
}

make_link_root() {
    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/scripts/validation" "$TEST_ROOT/docs"
    : >"$TEST_ROOT/scripts/validation/relative-link-allowlist.txt"
}

links() {
    run "$LOOM_NODE" "$VALIDATOR" --root "$TEST_ROOT" --links
}

@test "negative seeds are inert and cannot match production scans" {
    run find "$REPOSITORY_ROOT/scripts/tests/fixtures" -type f \( -name '*.json' -o -name '*.md' \)
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "valid dual-client metadata, compatibility, bindings, and fixtures pass" {
    make_metadata_root
    metadata
    [ "$status" -eq 0 ]
}

@test "malformed JSON names the materialized file" {
    make_metadata_root
    apply_overlay malformed-json
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"plugins/loom/.claude-plugin/plugin.json: invalid JSON"* ]]
}

@test "malformed JSON Schema names the materialized file" {
    make_metadata_root
    apply_overlay malformed-schema
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"scripts/schemas/command-frontmatter-v1.schema.json: invalid JSON Schema"* ]]
}

@test "missing, unterminated, and invalid YAML frontmatter fail with filenames" {
    make_metadata_root
    printf '# missing\n' >"$TEST_ROOT/plugins/loom/commands/develop.md"
    printf '%s\n' '---' 'description: never ends' >"$TEST_ROOT/plugins/loom/commands/plan.md"
    apply_overlay invalid-frontmatter
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"commands/develop.md: missing YAML frontmatter"* ]]
    [[ "$output" == *"commands/plan.md: unterminated YAML frontmatter"* ]]
    [[ "$output" == *"commands/run.md: invalid YAML frontmatter"* ]]
}

@test "unknown frontmatter keys and required component names fail closed" {
    make_metadata_root
    printf '%s\n' '---' 'description: x' 'unknown: true' '---' >"$TEST_ROOT/plugins/loom/commands/develop.md"
    printf '%s\n' '---' 'description: x' 'model: opus' 'color: red' 'tools: Read' '---' >"$TEST_ROOT/plugins/loom/agents/code-evaluator.md"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"must NOT have additional properties"* ]]
    [[ "$output" == *"must have required property 'name'"* ]]
}

@test "unknown fields in each release contract fail additionalProperties schemas" {
    make_metadata_root
    "$LOOM_NODE" -e 'const fs=require("fs");for(const f of process.argv.slice(1)){const x=JSON.parse(fs.readFileSync(f));x.unknown=true;fs.writeFileSync(f,JSON.stringify(x))}' \
        "$TEST_ROOT/plugins/loom/.claude-plugin/plugin.json" \
        "$TEST_ROOT/.agents/plugins/marketplace.json" \
        "$TEST_ROOT/plugins/loom/adapters/compatibility/v0.2.0.json" \
        "$TEST_ROOT/plugins/loom/adapters/roots/claude-plugin-root-v1.json"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"must NOT have additional properties"* ]]
}

@test "catalog source escape fails" {
    make_metadata_root
    "$LOOM_NODE" -e 'const fs=require("fs"),f=process.argv[1],x=JSON.parse(fs.readFileSync(f));x.plugins[0].source="../outside";fs.writeFileSync(f,JSON.stringify(x))' "$TEST_ROOT/.agents/plugins/marketplace.json"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"catalog source"* ]]
}

@test "catalog symlink and different physical root fail" {
    make_metadata_root
    mv "$TEST_ROOT/plugins/loom" "$TEST_ROOT/plugins/real-loom"
    ln -s /tmp "$TEST_ROOT/plugins/loom"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"catalog source"* ]]
}

@test "catalog source resolving to a different physical plugin root fails" {
    make_metadata_root
    cp -R "$TEST_ROOT/plugins/loom" "$TEST_ROOT/plugins/other"
    "$LOOM_NODE" -e 'const fs=require("fs"),f=process.argv[1],x=JSON.parse(fs.readFileSync(f));x.plugins[0].source="./plugins/other";fs.writeFileSync(f,JSON.stringify(x))' "$TEST_ROOT/.agents/plugins/marketplace.json"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"different physical plugin root"* ]]
}

@test "duplicate manifest, catalog, and component names fail" {
    make_metadata_root
    cp "$TEST_ROOT/plugins/loom/agents/developer.md" "$TEST_ROOT/plugins/loom/agents/developer-copy.md"
    "$LOOM_NODE" -e 'const fs=require("fs"),f=process.argv[1],x=JSON.parse(fs.readFileSync(f));x.plugins.push(x.plugins[0]);fs.writeFileSync(f,JSON.stringify(x))' "$TEST_ROOT/.agents/plugins/marketplace.json"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"duplicate catalog component name"* ]]
    [[ "$output" == *"duplicate agent name"* ]]
}

@test "version identity floor profile schema and binding drift fail" {
    make_metadata_root
    "$LOOM_NODE" -e 'const fs=require("fs");let f=process.argv[1],x=JSON.parse(fs.readFileSync(f));x.version="0.2.1";fs.writeFileSync(f,JSON.stringify(x));f=process.argv[2];x=JSON.parse(fs.readFileSync(f));x.clientFloors.codex="9";x.profiles[0].codex.effort="high";fs.writeFileSync(f,JSON.stringify(x));f=process.argv[3];x=JSON.parse(fs.readFileSync(f));x.expectedVersion="0.2.1";fs.writeFileSync(f,JSON.stringify(x))' "$TEST_ROOT/plugins/loom/.codex-plugin/plugin.json" "$TEST_ROOT/plugins/loom/adapters/compatibility/v0.2.0.json" "$TEST_ROOT/plugins/loom/adapters/roots/codex-skill-source-v1.json"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"drift"* ]]
}

@test "missing catalog manifest matrix binding and fixture drift fail" {
    make_metadata_root
    rm "$TEST_ROOT/plugins/loom/.codex-plugin/plugin.json" "$TEST_ROOT/plugins/loom/adapters/roots/claude-plugin-root-v1.json"
    "$LOOM_NODE" -e 'const fs=require("fs"),f=process.argv[1],x=JSON.parse(fs.readFileSync(f));x.description="drift";fs.writeFileSync(f,JSON.stringify(x))' "$TEST_ROOT/plugins/loom/adapters/fixtures/v0.2.0/metadata/claude-manifest.json"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"required file is missing"* ]]
    [[ "$output" == *"root binding reference is missing"* ]]
    [[ "$output" == *"release fixture differs"* ]]
}

@test "real tree metadata passes while inert seeds remain tracked" {
    TEST_ROOT="$REPOSITORY_ROOT"
    metadata
    [ "$status" -eq 0 ]
    TEST_ROOT=""
}

@test "valid relative targets and local and cross-file fragments pass" {
    make_link_root
    printf '%s\n' '# Alpha' '[local](#alpha)' '[cross](other.md#beta)' >"$TEST_ROOT/docs/main.md"
    printf '%s\n' '# Beta' >"$TEST_ROOT/docs/other.md"
    links
    [ "$status" -eq 0 ]
}

@test "missing targets and fragments name source and target" {
    make_link_root
    printf '%s\n' '# Alpha' '[missing](nope.md)' '[fragment](#nope)' >"$TEST_ROOT/docs/main.md"
    links
    [ "$status" -ne 0 ]
    [[ "$output" == *"docs/main.md: missing"*"nope.md"* ]]
    [[ "$output" == *"docs/main.md: missing Markdown fragment: #nope"* ]]
}

@test "only exact historical trees are excluded" {
    make_link_root
    mkdir -p "$TEST_ROOT/.docs/evaluations" "$TEST_ROOT/.docs/slice-plans/archive" "$TEST_ROOT/.docs/evaluations-copy"
    printf '[x](missing.md)\n' >"$TEST_ROOT/.docs/evaluations/old.md"
    printf '[x](missing.md)\n' >"$TEST_ROOT/.docs/slice-plans/archive/old.md"
    printf '[x](missing.md)\n' >"$TEST_ROOT/.docs/evaluations-copy/live.md"
    links
    [ "$status" -ne 0 ]
    [[ "$output" == *"evaluations-copy/live.md"* ]]
    [[ "$output" != *"evaluations/old.md"* ]]
    [[ "$output" != *"archive/old.md"* ]]
}

@test "malformed duplicate and stale allowlist records fail" {
    make_link_root
    printf '[x](missing.md)\n' >"$TEST_ROOT/docs/main.md"
    printf '%s\n' 'bad' $'docs/main.md\tmissing.md\treason' $'docs/main.md\tmissing.md\tagain' $'docs/main.md\tother.md\tstale' >"$TEST_ROOT/scripts/validation/relative-link-allowlist.txt"
    links
    [ "$status" -ne 0 ]
    [[ "$output" == *"malformed allowlist"* ]]
    [[ "$output" == *"duplicate allowlist"* ]]
    [[ "$output" == *"stale allowlist"* ]]
}

@test "one exact live broken link is allowlisted but code-block pseudo-link is stale" {
    make_link_root
    printf '%s\n' '[live](missing.md)' '```' '[pseudo](fake.md)' '```' >"$TEST_ROOT/docs/main.md"
    printf '%s\n' $'docs/main.md\tmissing.md\tupstream historical pointer' $'docs/main.md\tfake.md\tcode is not a link' >"$TEST_ROOT/scripts/validation/relative-link-allowlist.txt"
    links
    [ "$status" -ne 0 ]
    [[ "$output" == *$'stale allowlist record: docs/main.md\tfake.md'* ]]
    [[ "$output" != *$'stale allowlist record: docs/main.md\tmissing.md'* ]]
}
