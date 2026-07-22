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

setup() {
    TEST_ROOT=""
    OUTSIDE_ROOT=""
    TEST_TEMP_PARENT="${TMPDIR:-/tmp}"
    OWNED_ROOTS=()
}

make_owned_root() {
    local purpose="$1" created
    created="$(mktemp -d "$TEST_TEMP_PARENT/loom-ci-test.$purpose.XXXXXX")"
    case "$created" in
    "$TEST_TEMP_PARENT"/loom-ci-test."$purpose".*) ;;
    *) return 1 ;;
    esac
    [ -d "$created" ] && [ ! -L "$created" ]
    : >"$created/.loom-ci-test-owned"
    OWNED_ROOTS+=("$created")
    NEW_OWNED_ROOT="$created"
}

teardown() {
    local owned
    if [ "${#OWNED_ROOTS[@]}" -eq 0 ]; then return; fi
    for owned in "${OWNED_ROOTS[@]}"; do
        case "$owned" in
        "$TEST_TEMP_PARENT"/loom-ci-test.*) ;;
        *) printf 'refusing to clean unowned test path: %s\n' "$owned" >&2; return 1 ;;
        esac
        [ -d "$owned" ] && [ ! -L "$owned" ] && [ -f "$owned/.loom-ci-test-owned" ] || {
            printf 'refusing to clean invalid test root: %s\n' "$owned" >&2
            return 1
        }
        rm -rf -- "$owned"
    done
}

make_metadata_root() {
    make_owned_root metadata
    TEST_ROOT="$NEW_OWNED_ROOT"
    populate_metadata_root
}

populate_metadata_root() {
    mkdir -p "$TEST_ROOT/.claude-plugin" "$TEST_ROOT/.agents/plugins" "$TEST_ROOT/plugins" "$TEST_ROOT/scripts"
    cp -R "$REPOSITORY_ROOT/plugins/loom" "$TEST_ROOT/plugins/loom"
    cp "$REPOSITORY_ROOT/.claude-plugin/marketplace.json" "$TEST_ROOT/.claude-plugin/marketplace.json"
    cp "$REPOSITORY_ROOT/.agents/plugins/marketplace.json" "$TEST_ROOT/.agents/plugins/marketplace.json"
    cp "$REPOSITORY_ROOT/README.md" "$TEST_ROOT/README.md"
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
    make_owned_root links
    TEST_ROOT="$NEW_OWNED_ROOT"
    mkdir -p "$TEST_ROOT/scripts/validation" "$TEST_ROOT/docs"
    : >"$TEST_ROOT/scripts/validation/relative-link-allowlist.txt"
}

make_outside_root() {
    make_owned_root outside
    OUTSIDE_ROOT="$NEW_OWNED_ROOT"
}

links() {
    run "$LOOM_NODE" "$VALIDATOR" --root "$TEST_ROOT" --links
}

@test "default root resolution is stable from a nested working directory" {
    run /bin/bash -c 'cd "$1" && "$2" "$3" --metadata' _ \
        "$REPOSITORY_ROOT/plugins/loom/skills" "$LOOM_NODE" "$VALIDATOR"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Repository metadata validation passed"* ]]
}

@test "all mode passes for the valid repository" {
    run "$LOOM_NODE" "$VALIDATOR" --root "$REPOSITORY_ROOT" --all
    [ "$status" -eq 0 ]
    [[ "$output" == *"Repository all validation passed"* ]]
}

@test "all mode reports a failing metadata root" {
    make_metadata_root
    printf '{ invalid all-mode JSON\n' >"$TEST_ROOT/plugins/loom/.claude-plugin/plugin.json"
    run "$LOOM_NODE" "$VALIDATOR" --root "$TEST_ROOT" --all
    [ "$status" -eq 1 ]
    [[ "$output" == *"plugins/loom/.claude-plugin/plugin.json: invalid JSON"* ]]
}

@test "missing validation mode exits 2 with deterministic usage" {
    run "$LOOM_NODE" "$VALIDATOR" --root "$REPOSITORY_ROOT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"validate-repository: exactly one of --metadata, --links, or --all is required"* ]]
    [[ "$output" == *"usage: validate-repository.mjs [--root PATH] (--metadata|--links|--all)"* ]]
}

@test "repeated validation mode exits 2 with deterministic usage" {
    run "$LOOM_NODE" "$VALIDATOR" --root "$REPOSITORY_ROOT" --metadata --metadata
    [ "$status" -eq 2 ]
    [[ "$output" == *"validate-repository: unknown or repeated argument: --metadata"* ]]
}

@test "mixed validation modes exit 2 with deterministic usage" {
    run "$LOOM_NODE" "$VALIDATOR" --root "$REPOSITORY_ROOT" --metadata --links
    [ "$status" -eq 2 ]
    [[ "$output" == *"validate-repository: unknown or repeated argument: --links"* ]]
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

@test "explicit non-Git root nested in a parent worktree uses the safe filesystem walk" {
    make_owned_root parent-worktree
    parent_root="$NEW_OWNED_ROOT"
    git -C "$parent_root" init -q
    TEST_ROOT="$parent_root/untracked-validation-root"
    populate_metadata_root
    printf '{ invalid nested root JSON\n' >"$TEST_ROOT/plugins/loom/.claude-plugin/plugin.json"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"plugins/loom/.claude-plugin/plugin.json: invalid JSON"* ]]
}

@test "tracked discovery failure in a real Git root fails closed without reading an untracked canary" {
    make_metadata_root
    git -C "$TEST_ROOT" init -q
    git -C "$TEST_ROOT" add README.md
    printf '{ UNTRACKED_CANARY_MUST_NOT_BE_READ\n' >"$TEST_ROOT/untracked-canary.json"
    real_git="$(command -v git)"
    mkdir "$TEST_ROOT/fake-bin"
    printf '%s\n' '#!/bin/sh' 'if [ "$3" = ls-files ]; then exit 73; fi' "exec '$real_git' \"\$@\"" >"$TEST_ROOT/fake-bin/git"
    chmod +x "$TEST_ROOT/fake-bin/git"
    run env PATH="$TEST_ROOT/fake-bin:$PATH" "$LOOM_NODE" "$VALIDATOR" --root "$TEST_ROOT" --metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"tracked Git discovery failed closed (73)"* ]]
    [[ "$output" != *"untracked-canary.json"* ]]
    [[ "$output" != *"UNTRACKED_CANARY_MUST_NOT_BE_READ"* ]]
}

@test "README states both exact client floors and the static Codex limitation" {
    make_metadata_root
    metadata
    [ "$status" -eq 0 ]
    [[ "$(<"$TEST_ROOT/README.md")" == *"Claude Code 2.1.216"* ]]
    [[ "$(<"$TEST_ROOT/README.md")" == *"Codex CLI 0.144.6"* ]]
    [[ "$(<"$TEST_ROOT/README.md")" == *"static scaffolding only"* ]]
}

@test "each README client floor fails metadata validation directly when drifted" {
    for mutation in 's/Claude Code 2\.1\.216 and Codex CLI/Claude Code 2.1.215 and Codex CLI/' 's/Codex CLI 0\.144\.6\./Codex CLI 0.144.5./'; do
        make_metadata_root
        sed "$mutation" "$TEST_ROOT/README.md" >"$TEST_ROOT/README.next"
        mv "$TEST_ROOT/README.next" "$TEST_ROOT/README.md"
        metadata
        [ "$status" -ne 0 ]
        [[ "$output" == *"README.md: missing exact supported client-floor statement: Claude Code 2.1.216 and Codex CLI 0.144.6"* ]]
    done
}

@test "every client-visible claim surface rejects prohibited unqualified wording" {
    while IFS='|' read -r relative claim; do
        make_metadata_root
        if [ "$relative" = README.md ]; then
            printf '\n%s\n' "$claim" >>"$TEST_ROOT/$relative"
        else
            jq --arg claim "$claim" 'if has("description") then .description=$claim else .schema=$claim end' \
                "$TEST_ROOT/$relative" >"$TEST_ROOT/claim.next"
            mv "$TEST_ROOT/claim.next" "$TEST_ROOT/$relative"
        fi
        metadata
        [ "$status" -ne 0 ]
        [[ "$output" == *"$relative: prohibited unqualified evaluation claim; use 'independent cold-agent evaluation with controlled inputs'"* ]]
    done <<'EOF'
README.md|blind evaluation
.claude-plugin/marketplace.json|blind-reviewed
.agents/plugins/marketplace.json|blind
plugins/loom/.claude-plugin/plugin.json|impartial by construction
plugins/loom/.codex-plugin/plugin.json|anonymous evaluator
plugins/loom/adapters/fixtures/v0.2.0/metadata/claude-manifest.json|self-favoring is impossible
plugins/loom/adapters/fixtures/v0.2.0/metadata/claude-marketplace.json|impartial
plugins/loom/adapters/fixtures/v0.2.0/metadata/claude-root.json|anonymous
plugins/loom/adapters/fixtures/v0.2.0/metadata/codex-manifest.json|blind evaluation
plugins/loom/adapters/fixtures/v0.2.0/metadata/codex-marketplace.json|blind-reviewed
plugins/loom/adapters/fixtures/v0.2.0/metadata/codex-root.json|anonymously
plugins/loom/adapters/fixtures/v0.2.0/metadata/compatibility.json|impossible
EOF
}

@test "a narrow evaluation term passes only with the immediate required qualification" {
    make_metadata_root
    printf '\nblind evaluation — independent cold-agent evaluation with controlled inputs\n' >>"$TEST_ROOT/README.md"
    metadata
    [ "$status" -eq 0 ]

    make_metadata_root
    printf '\nblind evaluation\nindependent cold-agent evaluation with controlled inputs\n' >>"$TEST_ROOT/README.md"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"README.md: prohibited unqualified evaluation claim"* ]]
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

@test "unknown agent frontmatter key fails closed independently" {
    make_metadata_root
    printf '%s\n' '---' 'name: code-evaluator' 'description: x' 'model: opus' 'color: red' 'tools: Read' 'unknown: true' '---' >"$TEST_ROOT/plugins/loom/agents/code-evaluator.md"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"plugins/loom/agents/code-evaluator.md: schema / must NOT have additional properties"* ]]
}

@test "unknown skill frontmatter key fails closed independently" {
    make_metadata_root
    skill_path="$(find "$TEST_ROOT/plugins/loom/skills" -name SKILL.md | head -n 1)"
    printf '%s\n' '---' "name: $(basename "$(dirname "$skill_path")")" 'description: x' 'unknown: true' '---' >"$skill_path"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"plugins/loom/skills/"*"/SKILL.md: schema / must NOT have additional properties"* ]]
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
    done
}

@test "Codex manifest rejects top-level and nested author unknown fields independently" {
    for filter in '.unknown=true' '.author.unknown=true'; do
        make_metadata_root
        mutate_json plugins/loom/.codex-plugin/plugin.json "$filter"
        metadata
        [ "$status" -ne 0 ]
        [[ "$output" == *"plugins/loom/.codex-plugin/plugin.json: schema "*"must NOT have additional properties"* ]]
    done
}

@test "Codex catalog rejects unknown top-level owner and plugin fields independently" {
    for filter in '.unknown=true' '.owner.unknown=true' '.plugins[0].unknown=true'; do
        make_metadata_root
        mutate_json .agents/plugins/marketplace.json "$filter"
        metadata
        [ "$status" -ne 0 ]
        [[ "$output" == *".agents/plugins/marketplace.json: schema "*"must NOT have additional properties"* ]]
    done
}

@test "compatibility matrix closes every nested object boundary" {
    for filter in '.unknown=true' '.clientFloors.unknown=true' '.rootBindings[0].unknown=true' '.profiles[0].unknown=true' '.profiles[0].claude.unknown=true' '.profiles[0].codex.unknown=true'; do
        make_metadata_root
        mutate_json plugins/loom/adapters/compatibility/v0.2.0.json "$filter"
        metadata
        [ "$status" -ne 0 ]
        [[ "$output" == *"compatibility/v0.2.0.json: schema "*"must NOT have additional properties"* ]]
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

@test "each Claude installed-root requirement fails independently when omitted" {
    for field in binding inputMustBeAbsolute invocationMustBeAbsolute canonicalizeInput canonicalRootRequired manifest manifestMustBeCanonical manifestMustBeRegularFile expectedName expectedVersion helperDirectory helperDirectoryMustBeDirectChild allowedHelpers helperMustBeRegularFile helperMustBeExecutable; do
        make_metadata_root
        mutate_json plugins/loom/adapters/roots/claude-plugin-root-v1.json "del(.$field)"
        metadata
        [ "$status" -ne 0 ]
        [[ "$output" == *"plugins/loom/adapters/roots/claude-plugin-root-v1.json: schema "* ]]
    done
}

@test "each Codex installed-root requirement fails independently when omitted" {
    for field in inputMustBeAbsolute invocationMustBeAbsolute skillSuffix skillMustBeCanonical skillMustBeRegularFile skillIdentitySource skillIdentityMustMatchDirectory pluginRootAscent pluginRootMustBeCanonical ascendToManifest manifestMustBeCanonical manifestMustBeRegularFile expectedName expectedVersion helperDirectory helperDirectoryMustBeDirectChild allowedHelpers helperMustBeRegularFile helperMustBeExecutable forbiddenWorkflowRootGuesses hookBinding hookManifest; do
        make_metadata_root
        mutate_json plugins/loom/adapters/roots/codex-skill-source-v1.json "del(.$field)"
        metadata
        [ "$status" -ne 0 ]
        [[ "$output" == *"plugins/loom/adapters/roots/codex-skill-source-v1.json: schema "* ]]
    done
}

@test "installed-root constants reject false or substituted declarations independently" {
    for record in \
        'plugins/loom/adapters/roots/claude-plugin-root-v1.json|.inputMustBeAbsolute=false' \
        'plugins/loom/adapters/roots/claude-plugin-root-v1.json|.manifest="other.json"' \
        'plugins/loom/adapters/roots/claude-plugin-root-v1.json|.allowedHelpers=["other"]' \
        'plugins/loom/adapters/roots/codex-skill-source-v1.json|.skillSuffix="SKILL.md"' \
        'plugins/loom/adapters/roots/codex-skill-source-v1.json|.pluginRootAscent=".."' \
        'plugins/loom/adapters/roots/codex-skill-source-v1.json|.skillIdentitySource="directory"' \
        'plugins/loom/adapters/roots/codex-skill-source-v1.json|.helperDirectory="../bin"'; do
        relative=${record%%|*}
        filter=${record#*|}
        make_metadata_root
        mutate_json "$relative" "$filter"
        metadata
        [ "$status" -ne 0 ]
        [[ "$output" == *"$relative: schema "* ]]
    done
}

@test "catalog-shaped tracked JSON is rejected outside exact live and release-fixture paths" {
    for record in \
        '.claude-plugin/marketplace.json|plugins/loom/catalog-copy.json' \
        '.agents/plugins/marketplace.json|plugins/loom/adapters/fixtures/v0.2.0/metadata/codex-marketplace-copy.json'; do
        source=${record%%|*}
        destination=${record#*|}
        make_metadata_root
        cp "$TEST_ROOT/$source" "$TEST_ROOT/$destination"
        metadata
        [ "$status" -ne 0 ]
        [[ "$output" == *"$destination: catalog-shaped JSON is not at an authorized live or release-fixture path"* ]]
    done
}

@test "null false zero and empty string receive schema diagnostics as metadata values" {
    for record in \
        'plugins/loom/.claude-plugin/plugin.json|null' \
        '.claude-plugin/marketplace.json|false' \
        'plugins/loom/.codex-plugin/plugin.json|0' \
        '.agents/plugins/marketplace.json|""' \
        'plugins/loom/adapters/compatibility/v0.2.0.json|null' \
        'plugins/loom/adapters/roots/claude-plugin-root-v1.json|false' \
        'plugins/loom/adapters/roots/codex-skill-source-v1.json|0' \
        'plugins/loom/adapters/fixtures/v0.2.0/metadata/compatibility.json|""'; do
        relative=${record%%|*}
        value=${record#*|}
        make_metadata_root
        printf '%s\n' "$value" >"$TEST_ROOT/$relative"
        metadata
        [ "$status" -ne 0 ]
        [[ "$output" == *"$relative: schema / must be object"* ]]
    done
}

@test "null false zero and empty string receive deterministic referenced-schema diagnostics" {
    for value in null false 0 '""'; do
        make_metadata_root
        printf '%s\n' "$value" >"$TEST_ROOT/scripts/schemas/codex-plugin-0.144.6.schema.json"
        metadata
        [ "$status" -ne 0 ]
        expected_type=string
        case "$value" in null) expected_type=null ;; false) expected_type=boolean ;; 0) expected_type=number ;; esac
        [[ "$output" == *"scripts/schemas/codex-plugin-0.144.6.schema.json: invalid JSON Schema: expected object, got $expected_type"* ]]
        [[ "$output" != *"product name, exact SemVer"* ]]
    done
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

@test "release fixture equality ignores object member order" {
    make_metadata_root
    "$LOOM_NODE" -e 'const fs=require("fs"),f=process.argv[1],value=JSON.parse(fs.readFileSync(f));const reordered=Object.fromEntries(Object.entries(value).reverse());fs.writeFileSync(f,JSON.stringify(reordered))' \
        "$TEST_ROOT/plugins/loom/.codex-plugin/plugin.json"
    metadata
    [ "$status" -eq 0 ]
}

@test "release fixture equality preserves array order" {
    make_metadata_root
    mutate_json plugins/loom/adapters/fixtures/v0.2.0/metadata/compatibility.json '.workflows |= reverse'
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"compatibility.json: release fixture differs"* ]]
}

@test "schema-valid manifest homepage drift fails shared identity" {
    make_metadata_root
    mutate_json plugins/loom/.codex-plugin/plugin.json '.homepage="https://example.com/loom"'
    cp "$TEST_ROOT/plugins/loom/.codex-plugin/plugin.json" "$TEST_ROOT/plugins/loom/adapters/fixtures/v0.2.0/metadata/codex-manifest.json"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"plugins/loom/.codex-plugin/plugin.json: manifest identity differs from Claude manifest"* ]]
}

@test "schema-invalid metadata path stops before outside semantic reads" {
    make_metadata_root
    make_outside_root
    sentinel="$OUTSIDE_ROOT/outside-sentinel.json"
    printf 'DO_NOT_DISCLOSE\n' >"$sentinel"
    mutate_json plugins/loom/adapters/compatibility/v0.2.0.json '.rootBindings[0].path="../../outside-sentinel.json"'
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"compatibility/v0.2.0.json: schema /rootBindings/0/path must match pattern"* ]]
    [[ "$output" != *"DO_NOT_DISCLOSE"* ]]
}

@test "outside-root sentinels use unique cleanup-owned directories" {
    make_outside_root
    first_root="$OUTSIDE_ROOT"
    make_outside_root
    second_root="$OUTSIDE_ROOT"
    [ "$first_root" != "$second_root" ]
    (printf 'first\n' >"$first_root/sentinel") &
    first_pid=$!
    (printf 'second\n' >"$second_root/sentinel") &
    second_pid=$!
    wait "$first_pid"
    wait "$second_pid"
    [ "$(cat "$first_root/sentinel")" = first ]
    [ "$(cat "$second_root/sentinel")" = second ]
}

@test "JSON symlink is rejected before parsing outside content" {
    make_metadata_root
    make_outside_root
    sentinel="$OUTSIDE_ROOT/json-sentinel"
    printf 'DO_NOT_DISCLOSE\n' >"$sentinel"
    rm "$TEST_ROOT/plugins/loom/.claude-plugin/plugin.json"
    ln -s "$sentinel" "$TEST_ROOT/plugins/loom/.claude-plugin/plugin.json"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"plugin.json: unsafe path contains symlink"* ]]
    [[ "$output" != *"DO_NOT_DISCLOSE"* ]]
}

@test "frontmatter symlink is rejected before reading outside content" {
    make_metadata_root
    make_outside_root
    sentinel="$OUTSIDE_ROOT/frontmatter-sentinel"
    printf 'DO_NOT_DISCLOSE\n' >"$sentinel"
    rm "$TEST_ROOT/plugins/loom/commands/run.md"
    ln -s "$sentinel" "$TEST_ROOT/plugins/loom/commands/run.md"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"commands/run.md: unsafe path contains symlink"* ]]
    [[ "$output" != *"DO_NOT_DISCLOSE"* ]]
}

@test "schema symlink is rejected before reading outside content" {
    make_metadata_root
    make_outside_root
    sentinel="$OUTSIDE_ROOT/schema-sentinel"
    printf 'DO_NOT_DISCLOSE\n' >"$sentinel"
    rm "$TEST_ROOT/scripts/schemas/command-frontmatter-v1.schema.json"
    ln -s "$sentinel" "$TEST_ROOT/scripts/schemas/command-frontmatter-v1.schema.json"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"command-frontmatter-v1.schema.json: unsafe path contains symlink"* ]]
    [[ "$output" != *"DO_NOT_DISCLOSE"* ]]
}

@test "release fixture symlink is rejected before reading outside content" {
    make_metadata_root
    make_outside_root
    sentinel="$OUTSIDE_ROOT/fixture-sentinel"
    printf 'DO_NOT_DISCLOSE\n' >"$sentinel"
    fixture="$TEST_ROOT/plugins/loom/adapters/fixtures/v0.2.0/metadata/claude-manifest.json"
    rm "$fixture"
    ln -s "$sentinel" "$fixture"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"claude-manifest.json: unsafe path contains symlink"* ]]
    [[ "$output" != *"DO_NOT_DISCLOSE"* ]]
}

@test "real tree metadata passes while inert seeds remain tracked" {
    run "$LOOM_NODE" "$VALIDATOR" --root "$REPOSITORY_ROOT" --metadata
    [ "$status" -eq 0 ]
}

@test "forced real-tree validator failure leaves the checkout intact" {
    make_owned_root forced-validator
    fake_validator="$NEW_OWNED_ROOT/fail-validator"
    printf '%s\n' '#!/bin/sh' 'exit 19' >"$fake_validator"
    chmod +x "$fake_validator"
    before="$(sha256sum "$REPOSITORY_ROOT/CLAUDE.md" 2>/dev/null | awk '{print $1}' || shasum -a 256 "$REPOSITORY_ROOT/CLAUDE.md" | awk '{print $1}')"
    run "$fake_validator" --root "$REPOSITORY_ROOT" --metadata
    [ "$status" -eq 19 ]
    [ -d "$REPOSITORY_ROOT/.git" ] || git -C "$REPOSITORY_ROOT" rev-parse --git-dir >/dev/null
    after="$(sha256sum "$REPOSITORY_ROOT/CLAUDE.md" 2>/dev/null | awk '{print $1}' || shasum -a 256 "$REPOSITORY_ROOT/CLAUDE.md" | awk '{print $1}')"
    [ "$after" = "$before" ]
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
    make_outside_root
    sentinel="$OUTSIDE_ROOT/markdown-source-sentinel"
    printf 'DO_NOT_DISCLOSE\n' >"$sentinel"
    ln -s "$sentinel" "$TEST_ROOT/docs/source.md"
    links
    [ "$status" -ne 0 ]
    [[ "$output" == *"docs/source.md: unsafe path contains symlink"* ]]
    [[ "$output" != *"DO_NOT_DISCLOSE"* ]]
}

@test "Markdown target symlink is rejected before reading outside content" {
    make_link_root
    make_outside_root
    sentinel="$OUTSIDE_ROOT/markdown-target-sentinel"
    printf 'DO_NOT_DISCLOSE\n' >"$sentinel"
    printf '[target](target.md#secret)\n' >"$TEST_ROOT/docs/source.md"
    ln -s "$sentinel" "$TEST_ROOT/docs/target.md"
    links
    [ "$status" -ne 0 ]
    [[ "$output" == *"docs/target.md: unsafe path contains symlink"* ]]
    [[ "$output" == *"docs/source.md: missing or unsafe relative-link target: target.md#secret"* ]]
    [[ "$output" != *"DO_NOT_DISCLOSE"* ]]
}

@test "allowlist symlink is rejected before reading outside content" {
    make_link_root
    make_outside_root
    sentinel="$OUTSIDE_ROOT/allowlist-sentinel"
    printf 'DO_NOT_DISCLOSE\n' >"$sentinel"
    rm "$TEST_ROOT/scripts/validation/relative-link-allowlist.txt"
    ln -s "$sentinel" "$TEST_ROOT/scripts/validation/relative-link-allowlist.txt"
    links
    [ "$status" -ne 0 ]
    [[ "$output" == *"relative-link-allowlist.txt: unsafe path contains symlink"* ]]
    [[ "$output" != *"DO_NOT_DISCLOSE"* ]]
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

@test "live allowlist entry with empty reason is rejected and does not suppress the link" {
    make_link_root
    printf '[live](missing.md)\n' >"$TEST_ROOT/docs/main.md"
    printf 'docs/main.md\tmissing.md\t\n' >"$TEST_ROOT/scripts/validation/relative-link-allowlist.txt"
    links
    [ "$status" -ne 0 ]
    [[ "$output" == *"malformed allowlist record"* ]]
    [[ "$output" == *"docs/main.md: missing or unsafe relative-link target: missing.md"* ]]
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

@test "one exact live allowlist entry passes and suppresses its broken-link diagnostic" {
    make_link_root
    printf '[live](missing.md)\n' >"$TEST_ROOT/docs/main.md"
    printf '%s\n' $'docs/main.md\tmissing.md\tupstream historical pointer' >"$TEST_ROOT/scripts/validation/relative-link-allowlist.txt"
    links
    [ "$status" -eq 0 ]
    [[ "$output" == *"Repository links validation passed"* ]]
    [[ "$output" != *"missing or unsafe relative-link target"* ]]
    [[ "$output" != *"stale allowlist record"* ]]
}

make_contract_root() {
    make_owned_root contract
    TEST_ROOT="$NEW_OWNED_ROOT"
    mkdir -p "$TEST_ROOT/scripts/check-tools" "$TEST_ROOT/.github/workflows" \
        "$TEST_ROOT/plugins/loom/bin" "$TEST_ROOT/plugins/loom/hooks"
    cp "$REPOSITORY_ROOT/scripts/check" "$TEST_ROOT/scripts/check"
    cp "$REPOSITORY_ROOT/scripts/check-toolchain.json" "$TEST_ROOT/scripts/check-toolchain.json"
    cp "$REPOSITORY_ROOT/scripts/check-tools/package-lock.json" "$TEST_ROOT/scripts/check-tools/package-lock.json"
    cp "$REPOSITORY_ROOT/.github/workflows/check.yml" "$TEST_ROOT/.github/workflows/check.yml"
    cp "$REPOSITORY_ROOT/plugins/loom/bin/loom-coord" "$TEST_ROOT/plugins/loom/bin/loom-coord"
    cp "$REPOSITORY_ROOT/plugins/loom/hooks/git-identity-guard.sh" "$TEST_ROOT/plugins/loom/hooks/git-identity-guard.sh"
    cp "$REPOSITORY_ROOT/plugins/loom/hooks/precompact-write-ahead-backstop.sh" \
        "$TEST_ROOT/plugins/loom/hooks/precompact-write-ahead-backstop.sh"
    while IFS= read -r vendored; do
        mkdir -p "$TEST_ROOT/$(dirname "$vendored")"
        cp "$REPOSITORY_ROOT/$vendored" "$TEST_ROOT/$vendored"
    done < <(jq -r '.vendored[].path' "$REPOSITORY_ROOT/scripts/check-toolchain.json")
}

ensure_contract_root() {
    [ -n "$TEST_ROOT" ] || make_contract_root
}

contract_check() {
    ensure_contract_root
    run env LOOM_CHECK_CONTRACT_ONLY=1 /bin/bash "$TEST_ROOT/scripts/check"
}

assert_required_bash_shebang_rejected() {
    relative="$1"
    make_contract_root
    {
        printf '%s\n' '#!/bin/sh'
        tail -n +2 "$TEST_ROOT/$relative"
    } >"$TEST_ROOT/shebang.next"
    mv "$TEST_ROOT/shebang.next" "$TEST_ROOT/$relative"
    contract_check
    [ "$status" -eq 1 ]
    [[ "$output" == *"required Bash shebang drift: $relative must start exactly with #!/usr/bin/env bash"* ]]
}

rewrite_workflow() {
    ensure_contract_root
    "$LOOM_NODE" -e 'const fs=require("fs"),f=process.argv[1],old=process.argv[2],next=process.argv[3];const text=fs.readFileSync(f,"utf8");if(!text.includes(old))process.exit(2);fs.writeFileSync(f,text.replace(old,next))' \
        "$TEST_ROOT/.github/workflows/check.yml" "$1" "$2"
}

mutate_contract() {
    ensure_contract_root
    expression="$1"
    jq "$expression" "$TEST_ROOT/scripts/check-toolchain.json" >"$TEST_ROOT/contract.next"
    mv "$TEST_ROOT/contract.next" "$TEST_ROOT/scripts/check-toolchain.json"
}

@test "exact workflow and toolchain contract passes" {
    contract_check
    [ "$status" -eq 0 ]
}

@test "loom-coord exact Bash shebang is mechanically required" {
    assert_required_bash_shebang_rejected plugins/loom/bin/loom-coord
}

@test "git identity guard exact Bash shebang is mechanically required" {
    assert_required_bash_shebang_rejected plugins/loom/hooks/git-identity-guard.sh
}

@test "precompact backstop exact Bash shebang is mechanically required" {
    assert_required_bash_shebang_rejected plugins/loom/hooks/precompact-write-ahead-backstop.sh
}

@test "workflow runner row deletion fails" {
    ensure_contract_root
    "$LOOM_NODE" -e 'const fs=require("fs"),f=process.argv[1];let s=fs.readFileSync(f,"utf8");s=s.replace(/          - runner: macos-15-intel\n(?:            .*\n){5}/,"");fs.writeFileSync(f,s)' "$TEST_ROOT/.github/workflows/check.yml"
    contract_check
    [ "$status" -ne 0 ]
    [[ "$output" == *"workflow exact-contract digest drift"* ]]
}

@test "workflow inline-comment spoof fails exact verified contract" {
    rewrite_workflow '          persist-credentials: false' '          persist-credentials: true # persist-credentials: false'
    contract_check
    [ "$status" -ne 0 ]
    [[ "$output" == *"workflow exact-contract digest drift"* ]]
}

@test "workflow commented-out security setting fails exact verified contract" {
    rewrite_workflow '          ref: ${{ github.event.pull_request.head.sha || github.sha }}' '          # ref: ${{ github.event.pull_request.head.sha || github.sha }}'
    contract_check
    [ "$status" -ne 0 ]
    [[ "$output" == *"workflow exact-contract digest drift"* ]]
}

@test "workflow duplicate key fails exact verified contract" {
    rewrite_workflow '          fetch-depth: 0' $'          fetch-depth: 0\n          fetch-depth: 1'
    contract_check
    [ "$status" -ne 0 ]
    [[ "$output" == *"workflow exact-contract digest drift"* ]]
}

@test "workflow relocated exact-head string fails exact verified contract" {
    rewrite_workflow '          test "$actual_head" = "$EXPECTED_HEAD"' $'      # test "$actual_head" = "$EXPECTED_HEAD"\n          test -n "$actual_head"'
    contract_check
    [ "$status" -ne 0 ]
    [[ "$output" == *"workflow exact-contract digest drift"* ]]
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

@test "workflow checkout action pin mutation fails" {
    rewrite_workflow 'actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683' 'actions/checkout@0000000000000000000000000000000000000000'
    contract_check
    [ "$status" -ne 0 ]
}

@test "workflow exact-head checkout ref mutation fails" {
    rewrite_workflow '          ref: ${{ github.event.pull_request.head.sha || github.sha }}' '          ref: ${{ github.sha }}'
    contract_check
    [ "$status" -ne 0 ]
}

@test "workflow exact-head environment mutation fails" {
    rewrite_workflow '          EXPECTED_HEAD: ${{ github.event.pull_request.head.sha || github.sha }}' '          EXPECTED_HEAD: ${{ github.sha }}'
    contract_check
    [ "$status" -ne 0 ]
}

@test "workflow exact-head assertion mutation fails" {
    rewrite_workflow '          test "$actual_head" = "$EXPECTED_HEAD"' '          test -n "$actual_head"'
    contract_check
    [ "$status" -ne 0 ]
}

@test "workflow exact-head log deletion fails" {
    rewrite_workflow "          printf 'Exact HEAD: %s\\n' \"\$actual_head\"" '          true'
    contract_check
    [ "$status" -ne 0 ]
}

@test "workflow selected-shell physical resolver deletion fails" {
    rewrite_workflow '          physical_shell=$(resolve_executable "$SELECTED_BASH")' '          physical_shell="$SELECTED_BASH"'
    contract_check
    [ "$status" -ne 0 ]
}

@test "toolchain runner deletion fails closed" {
    mutate_contract 'del(.runners[3])'
    contract_check
    [ "$status" -ne 0 ]
}

@test "exact tool version mutation fails closed" {
    mutate_contract '.tools.node="22.18.0"'
    contract_check
    [ "$status" -ne 0 ]
}

@test "runtime floor mutation fails closed" {
    mutate_contract '.runtimeFloors.bash="3.1"'
    contract_check
    [ "$status" -ne 0 ]
}

@test "checkout contract pin mutation fails closed" {
    mutate_contract '.actions.checkout=("0" * 40)'
    contract_check
    [ "$status" -ne 0 ]
}

@test "package-lock contract digest mutation fails closed" {
    mutate_contract '.packageLockSha256=("0" * 64)'
    contract_check
    [ "$status" -ne 0 ]
    [[ "$output" == *"package-lock digest drift"* ]]
}

@test "unexpected toolchain top-level field fails closed" {
    mutate_contract '.unexpected=true'
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
    ensure_contract_root
    fake_shell="$TEST_ROOT/bash-3.1"
    printf '%s\n' '#!/bin/sh' 'printf %s "3.1.99"' >"$fake_shell"
    chmod +x "$fake_shell"
    run env LOOM_CHECK_BASH_ONLY=1 LOOM_TEST_BASH="$fake_shell" LOOM_EXPECTED_BASH_VERSION='^3\\.1' /bin/bash "$TEST_ROOT/scripts/check"
    [ "$status" -ne 0 ]
    [[ "$output" == *"selected LOOM_TEST_BASH 3.1.99 is below required 3.2"* ]]
}

make_runtime_floor_shim() {
    tool="$1"
    advertised_version="$2"
    delegate="$3"
    mkdir -p "$TEST_ROOT/runtime-floor-bin"
    case "$tool" in
    git)
        printf '#!/bin/sh\nif [ "$1" = --version ]; then printf "git version %%s\\n" "%s"; exit 0; fi\nexec "%s" "$@"\n' \
            "$advertised_version" "$delegate" >"$TEST_ROOT/runtime-floor-bin/git"
        ;;
    jq)
        printf '#!/bin/sh\nif [ "$1" = --version ]; then printf "jq-%%s\\n" "%s"; exit 0; fi\nexec "%s" "$@"\n' \
            "$advertised_version" "$delegate" >"$TEST_ROOT/runtime-floor-bin/jq"
        ;;
    *) return 1 ;;
    esac
    chmod +x "$TEST_ROOT/runtime-floor-bin/$tool"
}

make_unsupported_host_shims() {
    rejected_os="$1"
    rejected_arch="$2"
    shim_root="$TEST_ROOT/unsupported-host-bin"
    uname_count="$TEST_ROOT/uname-s-count"
    provision_marker="$TEST_ROOT/provisioning-reached"
    mkdir -p "$shim_root"

    printf '%s\n' \
        '#!/bin/sh' \
        'case "$1" in' \
        '-s)' \
        "  count_file='$uname_count'" \
        '  count=0' \
        '  [ ! -f "$count_file" ] || count=$(cat "$count_file")' \
        '  count=$((count + 1))' \
        '  printf "%s\\n" "$count" >"$count_file"' \
        '  if [ "$count" -le 2 ]; then exec '"$(command -v uname)"' -s; fi' \
        "  printf '%s\\n' '$rejected_os'" \
        '  ;;' \
        "-m) printf '%s\\n' '$rejected_arch' ;;" \
        '*) exec '"$(command -v uname)"' "$@" ;;' \
        'esac' >"$shim_root/uname"
    printf '%s\n' \
        '#!/bin/sh' \
        'case "$*" in *".downloads[]"*) : >'"'$provision_marker'"' ;; esac' \
        'exec '"$(command -v jq)"' "$@"' >"$shim_root/jq"
    printf '%s\n' \
        '#!/bin/sh' \
        ': >'"'$provision_marker'" \
        'exit 88' >"$shim_root/curl"
    chmod +x "$shim_root/uname" "$shim_root/jq" "$shim_root/curl"
}

assert_unsupported_host_rejected_before_provisioning() {
    expected_diagnostic="$1"
    run env PATH="$shim_root:$PATH" /bin/bash "$TEST_ROOT/scripts/check"
    [ "$status" -eq 1 ]
    [ "$(printf '%s\n' "$output" | grep -Fxc "$expected_diagnostic")" -eq 1 ]
    [ ! -e "$provision_marker" ]
    [[ "$output" != *"Downloading pinned"* ]]
}

@test "Git immediately below 2.34 is rejected with an actionable diagnostic" {
    make_contract_root
    make_runtime_floor_shim git 2.33 "$(command -v git)"
    run env PATH="$TEST_ROOT/runtime-floor-bin:$PATH" LOOM_CHECK_BASH_ONLY=1 /bin/bash "$TEST_ROOT/scripts/check"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Git 2.33 is below required 2.34"* ]]
}

@test "Git exact floor 2.34 is accepted" {
    make_contract_root
    make_runtime_floor_shim git 2.34 "$(command -v git)"
    run env PATH="$TEST_ROOT/runtime-floor-bin:$PATH" LOOM_CHECK_BASH_ONLY=1 /bin/bash "$TEST_ROOT/scripts/check"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Selected Bash floor check passed"* ]]
}

@test "jq immediately below 1.6 is rejected with an actionable diagnostic" {
    make_contract_root
    make_runtime_floor_shim jq 1.5 "$(command -v jq)"
    run env PATH="$TEST_ROOT/runtime-floor-bin:$PATH" LOOM_CHECK_BASH_ONLY=1 /bin/bash "$TEST_ROOT/scripts/check"
    [ "$status" -eq 1 ]
    [[ "$output" == *"jq 1.5 is below required 1.6"* ]]
}

@test "jq exact floor 1.6 is accepted" {
    make_contract_root
    make_runtime_floor_shim jq 1.6 "$(command -v jq)"
    run env PATH="$TEST_ROOT/runtime-floor-bin:$PATH" LOOM_CHECK_BASH_ONLY=1 /bin/bash "$TEST_ROOT/scripts/check"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Selected Bash floor check passed"* ]]
}

@test "unknown host OS is rejected before provisioning" {
    make_contract_root
    make_unsupported_host_shims Plan9 x86_64
    assert_unsupported_host_rejected_before_provisioning "Unsupported check host: Plan9 x86_64"
}

@test "supported host OS with unsupported architecture is rejected before provisioning" {
    make_contract_root
    supported_os=$(uname -s)
    make_unsupported_host_shims "$supported_os" riscv64
    assert_unsupported_host_rejected_before_provisioning "Unsupported check host: $supported_os riscv64"
}

@test "first-stage failure preserves status and emits one exact diagnostic before later stages" {
    make_contract_root
    run env LOOM_CHECK_TEST_FAIL_STAGE='toolchain contract and pinned digests' LOOM_CHECK_TEST_FAIL_STATUS=67 \
        /bin/bash "$TEST_ROOT/scripts/check"
    [ "$status" -eq 67 ]
    diagnostic='FAILED stage toolchain contract and pinned digests (exit 67)'
    [ "$(printf '%s\n' "$output" | grep -Fxc "$diagnostic")" -eq 1 ]
    [ "$(printf '%s\n' "$output" | grep -c '^FAILED stage ')" -eq 1 ]
    [[ "$output" == *"==> toolchain contract and pinned digests"* ]]
    [[ "$output" != *"==> locked JavaScript dependencies and metadata validation"* ]]
    [[ "$output" != *"==> shfmt"* ]]
}

@test "advanced-stage failure preserves status and stops before every later stage" {
    make_contract_root
    prepare_cached_downloads
    run env LOOM_CHECK_TEST_FAIL_STAGE='locked JavaScript dependencies and metadata validation' LOOM_CHECK_TEST_FAIL_STATUS=73 \
        /bin/bash "$TEST_ROOT/scripts/check"
    [ "$status" -eq 73 ]
    diagnostic='FAILED stage locked JavaScript dependencies and metadata validation (exit 73)'
    [ "$(printf '%s\n' "$output" | grep -Fxc "$diagnostic")" -eq 1 ]
    [ "$(printf '%s\n' "$output" | grep -c '^FAILED stage ')" -eq 1 ]
    [[ "$output" == *"==> toolchain contract and pinned digests"* ]]
    [[ "$output" == *"==> locked JavaScript dependencies and metadata validation"* ]]
    [[ "$output" != *"==> shfmt"* ]]
    [[ "$output" != *"==> ShellCheck"* ]]
}

@test "gate resolves terminal and relative multihop selected-Bash symlinks" {
    ensure_contract_root
    mkdir -p "$TEST_ROOT/bash-links/sub"
    ln -s "$LOOM_TEST_BASH_PHYSICAL" "$TEST_ROOT/bash-links/sub/terminal"
    ln -s sub/terminal "$TEST_ROOT/bash-links/selected"
    run env LOOM_CHECK_BASH_ONLY=1 LOOM_TEST_BASH="$TEST_ROOT/bash-links/selected" LOOM_EXPECTED_BASH_VERSION="$LOOM_EXPECTED_BASH_VERSION" /bin/bash "$TEST_ROOT/scripts/check"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Selected Bash floor check passed"* ]]
}

prepare_cached_downloads() {
    ensure_contract_root
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

run_signal_case() {
    signal_name="$1"
    expected_status="$2"
    ensure_contract_root
    pause="$TEST_ROOT/pause"
    success="$TEST_ROOT/success"
    log="$TEST_ROOT/check.log"
    run env SIGNAL_NAME="$signal_name" EXPECTED_STATUS="$expected_status" PAUSE_PATH="$pause" SUCCESS_PATH="$success" LOG_PATH="$log" \
        "$LOOM_NODE" -e '
          const fs = require("fs"), { spawn } = require("child_process");
          const log = fs.openSync(process.env.LOG_PATH, "w");
          const child = spawn("/bin/bash", [process.argv[1]], {
            env: { ...process.env, LOOM_CHECK_TEST_PAUSE: process.env.PAUSE_PATH,
              LOOM_CHECK_TEST_SUCCESS_MARKER: process.env.SUCCESS_PATH }, stdio: ["ignore", log, log]
          });
          let attempts = 0, sent = false;
          const timer = setInterval(() => {
            attempts += 1;
            if (fs.existsSync(`${process.env.PAUSE_PATH}.ready`)) {
              sent = child.kill(`SIG${process.env.SIGNAL_NAME}`);
              clearInterval(timer);
            } else if (attempts >= 200) {
              clearInterval(timer); child.kill("SIGKILL");
            }
          }, 25);
          child.on("exit", (code, signal) => {
            clearInterval(timer); fs.closeSync(log);
            console.log(`code=${code} signal=${signal || "none"} sent=${sent}`);
            process.exit(sent && code === Number(process.env.EXPECTED_STATUS) ? 0 : 1);
          });
        ' "$TEST_ROOT/scripts/check"
    [ "$status" -eq 0 ]
    [ -e "$pause.ready" ]
    run_dir=$(cat "$pause.run-dir")
    [ ! -e "$run_dir" ]
    [ ! -e "$success" ]
    ! grep -F 'All checks passed' "$log"
}

@test "gate HUP cleanup is deterministic and exits 129 without success" {
    run_signal_case HUP 129
}

@test "gate INT cleanup is deterministic and exits 130 without success" {
    run_signal_case INT 130
}

@test "gate TERM cleanup is deterministic and exits 143 without success" {
    run_signal_case TERM 143
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

@test "Bats version probing cannot execute a poisoned ambient bash" {
    prepare_cached_downloads
    mkdir -p "$TEST_ROOT/fake-bin"
    marker="$TEST_ROOT/ambient-bash-executed"
    printf '%s\n' '#!/bin/sh' ": >'$marker'" 'exit 97' >"$TEST_ROOT/fake-bin/bash"
    chmod +x "$TEST_ROOT/fake-bin/bash"
    run env PATH="$TEST_ROOT/fake-bin:$PATH" LOOM_TEST_BASH="$LOOM_TEST_BASH_PHYSICAL" LOOM_EXPECTED_BASH_VERSION="$LOOM_EXPECTED_BASH_VERSION" LOOM_CHECK_PROVISION_ONLY=1 /bin/bash "$TEST_ROOT/scripts/check"
    [ "$status" -eq 0 ]
    [ ! -e "$marker" ]
}

@test "cache-root symlink is rejected without touching its owned target" {
    ensure_contract_root
    make_outside_root
    sentinel="$OUTSIDE_ROOT/value"
    printf 'unchanged\n' >"$sentinel"
    ln -s "$OUTSIDE_ROOT" "$TEST_ROOT/.check-cache"
    provision_check
    [ "$status" -ne 0 ]
    [ "$(cat "$sentinel")" = unchanged ]
}

@test "cached-download symlink is rejected without overwriting its target" {
    prepare_cached_downloads
    make_outside_root
    sentinel="$OUTSIDE_ROOT/sentinel"
    printf 'unchanged\n' >"$sentinel"
    rm "$TEST_ROOT/.check-cache/downloads/shfmt-$platform"
    ln -s "$sentinel" "$TEST_ROOT/.check-cache/downloads/shfmt-$platform"
    provision_check
    [ "$status" -ne 0 ]
    [ "$(cat "$sentinel")" = unchanged ]
}

@test "owner-controlled cache directories are repaired before use" {
    prepare_cached_downloads
    chmod 755 "$TEST_ROOT/.check-cache" "$TEST_ROOT/.check-cache/downloads"
    provision_check
    [ "$status" -eq 0 ]
    case "$(uname -s)" in
    Darwin) [ "$(stat -f %Lp "$TEST_ROOT/.check-cache")" = 700 ] ;;
    *) [ "$(stat -c %a "$TEST_ROOT/.check-cache")" = 700 ] ;;
    esac
}

@test "hard-linked cached download is rejected without mutating its outside sentinel" {
    prepare_cached_downloads
    make_outside_root
    cache_file="$TEST_ROOT/.check-cache/downloads/shfmt-$platform"
    sentinel="$OUTSIDE_ROOT/shfmt-sentinel"
    mv "$cache_file" "$sentinel"
    chmod 666 "$sentinel"
    ln "$sentinel" "$cache_file"
    before_digest=$(shasum -a 256 "$sentinel" | awk '{print $1}')
    case "$(uname -s)" in
    Darwin) before_mode=$(stat -f %Lp "$sentinel") ;;
    *) before_mode=$(stat -c %a "$sentinel") ;;
    esac

    provision_check
    [ "$status" -ne 0 ]
    [[ "$output" == *"unsafe cached download link count"* ]]
    [ "$(shasum -a 256 "$sentinel" | awk '{print $1}')" = "$before_digest" ]
    case "$(uname -s)" in
    Darwin) [ "$(stat -f %Lp "$sentinel")" = "$before_mode" ] ;;
    *) [ "$(stat -c %a "$sentinel")" = "$before_mode" ] ;;
    esac
}

@test "unexpected cache ownership is rejected" {
    prepare_cached_downloads
    mkdir -p "$TEST_ROOT/fake-bin"
    printf '%s\n' '#!/bin/sh' 'if [ "$1" = -u ]; then printf "999999\\n"; else exec /usr/bin/id "$@"; fi' >"$TEST_ROOT/fake-bin/id"
    chmod +x "$TEST_ROOT/fake-bin/id"
    run env PATH="$TEST_ROOT/fake-bin:$PATH" LOOM_CHECK_PROVISION_ONLY=1 /bin/bash "$TEST_ROOT/scripts/check"
    [ "$status" -ne 0 ]
    [[ "$output" == *"unsafe cache directory owner"* ]]
}

@test "cache rewrite race never executes unauthenticated bytes" {
    prepare_cached_downloads
    cache_file="$TEST_ROOT/.check-cache/downloads/shfmt-$platform"
    good_file="$TEST_ROOT/shfmt.good"
    bad_file="$TEST_ROOT/shfmt.bad"
    marker="$TEST_ROOT/unauthenticated-executed"
    cp "$cache_file" "$good_file"
    printf '%s\n' '#!/bin/sh' ": >'$marker'" 'printf v3.13.1' >"$bad_file"
    stop_file="$TEST_ROOT/stop-race"
    (
        while [ ! -e "$stop_file" ]; do
            cp "$bad_file" "$cache_file" 2>/dev/null || :
            cp "$good_file" "$cache_file" 2>/dev/null || :
        done
    ) &
    race_pid=$!
    provision_check
    race_status=$status
    : >"$stop_file"
    wait "$race_pid"
    [ "$race_status" -eq 0 ] || [[ "$output" == *"digest mismatch"* ]]
    [ ! -e "$marker" ]
}
