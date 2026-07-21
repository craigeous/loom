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

mutate_json() {
    local relative="$1" filter="$2"
    jq "$filter" "$TEST_ROOT/$relative" >"$TEST_ROOT/value.next"
    mv "$TEST_ROOT/value.next" "$TEST_ROOT/$relative"
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

@test "unknown command frontmatter key fails closed" {
    make_metadata_root
    printf '%s\n' '---' 'description: x' 'unknown: true' '---' >"$TEST_ROOT/plugins/loom/commands/develop.md"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"plugins/loom/commands/develop.md: schema / must NOT have additional properties"* ]]
}

@test "command missing description fails independently" {
    make_metadata_root
    printf '%s\n' '---' 'argument-hint: x' '---' >"$TEST_ROOT/plugins/loom/commands/develop.md"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"commands/develop.md: schema / must have required property 'description'"* ]]
}

@test "agent missing name fails independently" {
    make_metadata_root
    printf '%s\n' '---' 'description: x' 'model: opus' 'color: red' 'tools: Read' '---' >"$TEST_ROOT/plugins/loom/agents/code-evaluator.md"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"must have required property 'name'"* ]]
}

@test "Claude manifest rejects a top-level unknown field" {
    make_metadata_root
    mutate_json plugins/loom/.claude-plugin/plugin.json '.unknown=true'
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"plugins/loom/.claude-plugin/plugin.json: schema / must NOT have additional properties"* ]]
}

@test "Claude manifest rejects an unknown nested author field" {
    make_metadata_root
    mutate_json plugins/loom/.claude-plugin/plugin.json '.author.unknown=true'
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"plugin.json: schema /author must NOT have additional properties"* ]]
}

@test "Claude catalog rejects unknown top-level owner and plugin fields independently" {
    for filter in '.unknown=true' '.owner.unknown=true' '.plugins[0].unknown=true'; do
        make_metadata_root
        mutate_json .claude-plugin/marketplace.json "$filter"
        metadata
        [ "$status" -ne 0 ]
        [[ "$output" == *".claude-plugin/marketplace.json: schema "*"must NOT have additional properties"* ]]
        rm -rf "$TEST_ROOT"
        TEST_ROOT=""
    done
}

@test "Codex manifest rejects top-level and nested author unknown fields independently" {
    for filter in '.unknown=true' '.author.unknown=true'; do
        make_metadata_root
        mutate_json plugins/loom/.codex-plugin/plugin.json "$filter"
        metadata
        [ "$status" -ne 0 ]
        [[ "$output" == *"plugins/loom/.codex-plugin/plugin.json: schema "*"must NOT have additional properties"* ]]
        rm -rf "$TEST_ROOT"
        TEST_ROOT=""
    done
}

@test "Codex catalog rejects unknown top-level owner and plugin fields independently" {
    for filter in '.unknown=true' '.owner.unknown=true' '.plugins[0].unknown=true'; do
        make_metadata_root
        mutate_json .agents/plugins/marketplace.json "$filter"
        metadata
        [ "$status" -ne 0 ]
        [[ "$output" == *".agents/plugins/marketplace.json: schema "*"must NOT have additional properties"* ]]
        rm -rf "$TEST_ROOT"
        TEST_ROOT=""
    done
}

@test "compatibility matrix closes every nested object boundary" {
    for filter in '.unknown=true' '.clientFloors.unknown=true' '.rootBindings[0].unknown=true' '.profiles[0].unknown=true' '.profiles[0].claude.unknown=true' '.profiles[0].codex.unknown=true'; do
        make_metadata_root
        mutate_json plugins/loom/adapters/compatibility/v0.2.0.json "$filter"
        metadata
        [ "$status" -ne 0 ]
        [[ "$output" == *"compatibility/v0.2.0.json: schema "*"must NOT have additional properties"* ]]
        rm -rf "$TEST_ROOT"
        TEST_ROOT=""
    done
}

@test "Claude root binding rejects an unknown field" {
    make_metadata_root
    mutate_json plugins/loom/adapters/roots/claude-plugin-root-v1.json '.unknown=true'
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"claude-plugin-root-v1.json: schema / must NOT have additional properties"* ]]
}

@test "Codex root binding rejects an unknown field" {
    make_metadata_root
    mutate_json plugins/loom/adapters/roots/codex-skill-source-v1.json '.unknown=true'
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"codex-skill-source-v1.json: schema / must NOT have additional properties"* ]]
}

@test "catalog source escape fails" {
    make_metadata_root
    "$LOOM_NODE" -e 'const fs=require("fs"),f=process.argv[1],x=JSON.parse(fs.readFileSync(f));x.plugins[0].source="../outside";fs.writeFileSync(f,JSON.stringify(x))' "$TEST_ROOT/.agents/plugins/marketplace.json"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *".agents/plugins/marketplace.json: schema /plugins/0/source must be equal to constant"* ]]
}

@test "catalog symlink and different physical root fail" {
    make_metadata_root
    mv "$TEST_ROOT/plugins/loom" "$TEST_ROOT/plugins/real-loom"
    ln -s /tmp "$TEST_ROOT/plugins/loom"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"unsafe path contains symlink: plugins/loom"* ]]
}

@test "catalog source resolving to a different physical plugin root fails" {
    make_metadata_root
    cp -R "$TEST_ROOT/plugins/loom" "$TEST_ROOT/plugins/other"
    "$LOOM_NODE" -e 'const fs=require("fs"),f=process.argv[1],x=JSON.parse(fs.readFileSync(f));x.plugins[0].source="./plugins/other";fs.writeFileSync(f,JSON.stringify(x))' "$TEST_ROOT/.agents/plugins/marketplace.json"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *".agents/plugins/marketplace.json: schema /plugins/0/source must be equal to constant"* ]]
}

@test "duplicate catalog names fail independently" {
    make_metadata_root
    mutate_json .agents/plugins/marketplace.json '.plugins += [.plugins[0]]'
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *".agents/plugins/marketplace.json: schema /plugins must NOT have more than 1 items"* ]]
}

@test "duplicate component names fail independently" {
    make_metadata_root
    cp "$TEST_ROOT/plugins/loom/agents/developer.md" "$TEST_ROOT/plugins/loom/agents/developer-copy.md"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"duplicate agent name"* ]]
}

@test "manifest product name drift fails independently" {
    make_metadata_root
    mutate_json plugins/loom/.codex-plugin/plugin.json '.name="other"'
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"plugins/loom/.codex-plugin/plugin.json: schema /name must be equal to constant"* ]]
}

@test "manifest exact SemVer drift fails independently" {
    make_metadata_root
    mutate_json plugins/loom/.codex-plugin/plugin.json '.version="0.2.1"'
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"plugin.json: schema /version must be equal to constant"* ]]
}

@test "manifest shared identity drift fails independently" {
    make_metadata_root
    mutate_json plugins/loom/.codex-plugin/plugin.json '.description="different but schema-valid"'
    cp "$TEST_ROOT/plugins/loom/.codex-plugin/plugin.json" "$TEST_ROOT/plugins/loom/adapters/fixtures/v0.2.0/metadata/codex-manifest.json"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"manifest identity differs from Claude manifest"* ]]
}

@test "catalog product name drift fails independently" {
    make_metadata_root
    mutate_json .agents/plugins/marketplace.json '.name="other"'
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *".agents/plugins/marketplace.json: schema /name must be equal to constant"* ]]
}

@test "catalog source identity drift fails independently" {
    make_metadata_root
    mutate_json .agents/plugins/marketplace.json '.plugins[0].source="./plugins/other"'
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *".agents/plugins/marketplace.json: schema /plugins/0/source must be equal to constant"* ]]
}

@test "catalog release provenance drift fails independently" {
    make_metadata_root
    mutate_json .claude-plugin/marketplace.json '.plugins[0].version="0.2.1"'
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *".claude-plugin/marketplace.json: schema /plugins/0/version must be equal to constant"* ]]
}

@test "client floor drift fails independently" {
    make_metadata_root
    mutate_json plugins/loom/adapters/compatibility/v0.2.0.json '.clientFloors.codex="0.144.7"'
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"compatibility/v0.2.0.json: schema /clientFloors/codex must be equal to constant"* ]]
}

@test "profile mapping drift fails independently" {
    make_metadata_root
    mutate_json plugins/loom/adapters/compatibility/v0.2.0.json '.profiles[0].claude.selector="opus"'
    cp "$TEST_ROOT/plugins/loom/adapters/compatibility/v0.2.0.json" "$TEST_ROOT/plugins/loom/adapters/fixtures/v0.2.0/metadata/compatibility.json"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"profile mapping drift"* ]]
}

@test "matrix schema version drift fails independently" {
    make_metadata_root
    mutate_json plugins/loom/adapters/compatibility/v0.2.0.json '.schema="loom-compatibility-matrix/v2"'
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"compatibility/v0.2.0.json: schema /schema must be equal to constant"* ]]
}

@test "duplicate root binding ID fails exact pair enforcement" {
    make_metadata_root
    mutate_json plugins/loom/adapters/compatibility/v0.2.0.json '.rootBindings[1].id="claude-plugin-root/v1"'
    cp "$TEST_ROOT/plugins/loom/adapters/compatibility/v0.2.0.json" "$TEST_ROOT/plugins/loom/adapters/fixtures/v0.2.0/metadata/compatibility.json"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"root binding ID/path pair drift"* ]]
}

@test "swapped root binding ID and path fails exact pair enforcement" {
    make_metadata_root
    mutate_json plugins/loom/adapters/compatibility/v0.2.0.json '.rootBindings = [(.rootBindings[0] | {id:"codex-skill-source/v1",path:.path}), (.rootBindings[1] | {id:"claude-plugin-root/v1",path:.path})]'
    cp "$TEST_ROOT/plugins/loom/adapters/compatibility/v0.2.0.json" "$TEST_ROOT/plugins/loom/adapters/fixtures/v0.2.0/metadata/compatibility.json"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"root binding ID/path pair drift"* ]]
}

@test "alternate same-schema root binding path fails exact pair enforcement" {
    make_metadata_root
    cp "$TEST_ROOT/plugins/loom/adapters/roots/claude-plugin-root-v1.json" "$TEST_ROOT/plugins/loom/adapters/roots/alternate.json"
    mutate_json plugins/loom/adapters/compatibility/v0.2.0.json '.rootBindings[0].path="plugins/loom/adapters/roots/alternate.json"'
    cp "$TEST_ROOT/plugins/loom/adapters/compatibility/v0.2.0.json" "$TEST_ROOT/plugins/loom/adapters/fixtures/v0.2.0/metadata/compatibility.json"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"root binding ID/path pair drift"* ]]
}

@test "root binding identity drift fails independently" {
    make_metadata_root
    mutate_json plugins/loom/adapters/roots/codex-skill-source-v1.json '.expectedVersion="0.2.1"'
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"codex-skill-source-v1.json: schema /expectedVersion must be equal to constant"* ]]
}

@test "missing client manifest reference fails independently" {
    make_metadata_root
    rm "$TEST_ROOT/plugins/loom/.codex-plugin/plugin.json"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"plugins/loom/.codex-plugin/plugin.json: required file is missing"* ]]
}

@test "missing matrix root reference fails independently" {
    make_metadata_root
    rm "$TEST_ROOT/plugins/loom/adapters/roots/claude-plugin-root-v1.json"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"claude-plugin-root-v1.json: required file is missing"* ]]
}

@test "missing referenced schema fails independently" {
    make_metadata_root
    rm "$TEST_ROOT/scripts/schemas/codex-plugin-0.144.6.schema.json"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"schema reference is missing or unsafe: scripts/schemas/codex-plugin-0.144.6.schema.json"* ]]
}

@test "release fixture drift fails independently" {
    make_metadata_root
    mutate_json plugins/loom/adapters/fixtures/v0.2.0/metadata/claude-manifest.json '.description="fixture drift"'
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"claude-manifest.json: release fixture differs"* ]]
}

@test "schema-invalid metadata path stops before outside semantic reads" {
    make_metadata_root
    sentinel="$(dirname "$TEST_ROOT")/outside-sentinel.json"
    printf 'DO_NOT_DISCLOSE\n' >"$sentinel"
    mutate_json plugins/loom/adapters/compatibility/v0.2.0.json '.rootBindings[0].path="../../outside-sentinel.json"'
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"compatibility/v0.2.0.json: schema /rootBindings/0/path must match pattern"* ]]
    [[ "$output" != *"DO_NOT_DISCLOSE"* ]]
    rm -f "$sentinel"
}

@test "JSON symlink is rejected before parsing outside content" {
    make_metadata_root
    sentinel="$(dirname "$TEST_ROOT")/json-sentinel"
    printf 'DO_NOT_DISCLOSE\n' >"$sentinel"
    rm "$TEST_ROOT/plugins/loom/.claude-plugin/plugin.json"
    ln -s "$sentinel" "$TEST_ROOT/plugins/loom/.claude-plugin/plugin.json"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"plugin.json: unsafe path contains symlink"* ]]
    [[ "$output" != *"DO_NOT_DISCLOSE"* ]]
    rm -f "$sentinel"
}

@test "frontmatter symlink is rejected before reading outside content" {
    make_metadata_root
    sentinel="$(dirname "$TEST_ROOT")/frontmatter-sentinel"
    printf 'DO_NOT_DISCLOSE\n' >"$sentinel"
    rm "$TEST_ROOT/plugins/loom/commands/run.md"
    ln -s "$sentinel" "$TEST_ROOT/plugins/loom/commands/run.md"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"commands/run.md: unsafe path contains symlink"* ]]
    [[ "$output" != *"DO_NOT_DISCLOSE"* ]]
    rm -f "$sentinel"
}

@test "schema symlink is rejected before reading outside content" {
    make_metadata_root
    sentinel="$(dirname "$TEST_ROOT")/schema-sentinel"
    printf 'DO_NOT_DISCLOSE\n' >"$sentinel"
    rm "$TEST_ROOT/scripts/schemas/command-frontmatter-v1.schema.json"
    ln -s "$sentinel" "$TEST_ROOT/scripts/schemas/command-frontmatter-v1.schema.json"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"command-frontmatter-v1.schema.json: unsafe path contains symlink"* ]]
    [[ "$output" != *"DO_NOT_DISCLOSE"* ]]
    rm -f "$sentinel"
}

@test "release fixture symlink is rejected before reading outside content" {
    make_metadata_root
    sentinel="$(dirname "$TEST_ROOT")/fixture-sentinel"
    printf 'DO_NOT_DISCLOSE\n' >"$sentinel"
    fixture="$TEST_ROOT/plugins/loom/adapters/fixtures/v0.2.0/metadata/claude-manifest.json"
    rm "$fixture"
    ln -s "$sentinel" "$fixture"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"claude-manifest.json: unsafe path contains symlink"* ]]
    [[ "$output" != *"DO_NOT_DISCLOSE"* ]]
    rm -f "$sentinel"
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

@test "rendered inline heading text and duplicate GitHub suffixes pass" {
    make_link_root
    printf '%s\n' '# [Foo](target.md) and *Bar* `Baz`' '# Repeat' '# Repeat' '[inline](#foo-and-bar-baz)' '[duplicate](#repeat-1)' >"$TEST_ROOT/docs/main.md"
    printf '# Target\n' >"$TEST_ROOT/docs/target.md"
    links
    [ "$status" -eq 0 ]
}

@test "encoded spaces Unicode paths and Unicode fragments pass" {
    make_link_root
    printf '%s\n' '[encoded](caf%C3%A9%20file.md#%C3%BCber-caf%C3%A9)' >"$TEST_ROOT/docs/main.md"
    printf '# Über Café\n' >"$TEST_ROOT/docs/café file.md"
    links
    [ "$status" -eq 0 ]
}

@test "malformed percent encoding fails with source and exact target" {
    make_link_root
    printf '[bad](other%%ZZ.md#x)\n' >"$TEST_ROOT/docs/main.md"
    links
    [ "$status" -ne 0 ]
    [[ "$output" == *"docs/main.md: malformed percent encoding in link: other%ZZ.md#x"* ]]
}

@test "encoded traversal cannot escape the repository" {
    make_link_root
    printf '[bad](%%2e%%2e/%%2e%%2e/outside.md)\n' >"$TEST_ROOT/docs/main.md"
    links
    [ "$status" -ne 0 ]
    [[ "$output" == *"missing or unsafe relative-link target"* ]]
}

@test "Markdown source symlink is rejected before reading outside content" {
    make_link_root
    sentinel="$(dirname "$TEST_ROOT")/markdown-source-sentinel"
    printf 'DO_NOT_DISCLOSE\n' >"$sentinel"
    ln -s "$sentinel" "$TEST_ROOT/docs/source.md"
    links
    [ "$status" -ne 0 ]
    [[ "$output" == *"docs/source.md: unsafe path contains symlink"* ]]
    [[ "$output" != *"DO_NOT_DISCLOSE"* ]]
    rm -f "$sentinel"
}

@test "Markdown target symlink is rejected before reading outside content" {
    make_link_root
    sentinel="$(dirname "$TEST_ROOT")/markdown-target-sentinel"
    printf 'DO_NOT_DISCLOSE\n' >"$sentinel"
    printf '[target](target.md#secret)\n' >"$TEST_ROOT/docs/source.md"
    ln -s "$sentinel" "$TEST_ROOT/docs/target.md"
    links
    [ "$status" -ne 0 ]
    [[ "$output" == *"docs/target.md: unsafe path contains symlink"* ]]
    [[ "$output" == *"docs/source.md: missing or unsafe relative-link target: target.md#secret"* ]]
    [[ "$output" != *"DO_NOT_DISCLOSE"* ]]
    rm -f "$sentinel"
}

@test "allowlist symlink is rejected before reading outside content" {
    make_link_root
    sentinel="$(dirname "$TEST_ROOT")/allowlist-sentinel"
    printf 'DO_NOT_DISCLOSE\n' >"$sentinel"
    rm "$TEST_ROOT/scripts/validation/relative-link-allowlist.txt"
    ln -s "$sentinel" "$TEST_ROOT/scripts/validation/relative-link-allowlist.txt"
    links
    [ "$status" -ne 0 ]
    [[ "$output" == *"relative-link-allowlist.txt: unsafe path contains symlink"* ]]
    [[ "$output" != *"DO_NOT_DISCLOSE"* ]]
    rm -f "$sentinel"
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
