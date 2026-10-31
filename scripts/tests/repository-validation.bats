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

@test "thin adapters pass for the real repository tree" {
    make_metadata_root
    metadata
    [ "$status" -eq 0 ]
}

@test "a command adapter missing its shared-skill pointer fails closed" {
    make_metadata_root
    sed 's#skills/loom-run/SKILL.md#skills/nowhere/SKILL.md#' "$TEST_ROOT/plugins/loom/commands/run.md" >"$TEST_ROOT/run.next"
    mv "$TEST_ROOT/run.next" "$TEST_ROOT/plugins/loom/commands/run.md"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"plugins/loom/commands/run.md: thin adapter does not route to its shared canonical body: missing reference to skills/loom-run/SKILL.md"* ]]
}

@test "a command adapter that copies the shared workflow body fails closed on line count" {
    make_metadata_root
    for _ in $(seq 1 20); do printf 'copied workflow body line\n' >>"$TEST_ROOT/plugins/loom/commands/run.md"; done
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"plugins/loom/commands/run.md: thin adapter exceeds 20 lines"* ]]
}

@test "an agent adapter missing its shared-role pointer fails closed" {
    make_metadata_root
    sed 's#roles/researcher\.md#roles/nowhere.md#' "$TEST_ROOT/plugins/loom/agents/researcher.md" >"$TEST_ROOT/researcher.next"
    mv "$TEST_ROOT/researcher.next" "$TEST_ROOT/plugins/loom/agents/researcher.md"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"plugins/loom/agents/researcher.md: thin adapter does not route to its shared canonical body: missing reference to roles/researcher.md"* ]]
}

@test "an agent adapter that copies the shared role body fails closed on line count" {
    make_metadata_root
    for _ in $(seq 1 20); do printf 'copied role body line\n' >>"$TEST_ROOT/plugins/loom/agents/researcher.md"; done
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"plugins/loom/agents/researcher.md: thin adapter exceeds 20 lines"* ]]
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
        'plugins/loom/adapters/roots/claude-plugin-root-v1.json|.allowedHelpers=["loom-coord"]' \
        'plugins/loom/adapters/roots/codex-skill-source-v1.json|.allowedHelpers=["loom-doctor","loom-eval-workspace","loom-review","loom-verify-identity","loom-coord"]' \
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

@test "a command adapter pointing at a deleted shared workflow skill fails closed" {
    make_metadata_root
    rm -rf "$TEST_ROOT/plugins/loom/skills/loom-run"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"plugins/loom/commands/run.md: thin adapter routes to a shared canonical body that does not exist: skills/loom-run/SKILL.md"* ]]
}

@test "an agent adapter pointing at a deleted shared role contract fails closed" {
    make_metadata_root
    rm "$TEST_ROOT/plugins/loom/roles/researcher.md"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"plugins/loom/agents/researcher.md: thin adapter routes to a shared canonical body that does not exist: roles/researcher.md"* ]]
}

@test "a second client-specific hook manifest fails closed" {
    make_metadata_root
    printf '{}' >"$TEST_ROOT/plugins/loom/hooks/codex-hooks.json"
    metadata
    [ "$status" -ne 0 ]
    [[ "$output" == *"plugins/loom/hooks/hooks.json: expected exactly one shared hook manifest, found: plugins/loom/hooks/codex-hooks.json, plugins/loom/hooks/hooks.json"* ]]
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

# ---- documentation-state validation (--all) ----

fixture_git() {
    git -C "$TEST_ROOT" "$@"
}

fixture_commit() {
    fixture_git add -A
    fixture_git commit -q -m "$1"
}

put() {
    mkdir -p "$TEST_ROOT/$(dirname "$1")"
    cat >"$TEST_ROOT/$1"
}

# The copied plugin docs link into the real .docs tree, which a fixture lacks;
# inventory those links so the fixture isolates the documentation-state rules.
inventory_plugin_links() {
    local line pattern='^([^:]+): (missing or unsafe relative-link target|missing Markdown fragment): (.*)$'
    : >"$TEST_ROOT/scripts/validation/relative-link-allowlist.txt"
    run "$LOOM_NODE" "$VALIDATOR" --root "$TEST_ROOT" --links
    while IFS= read -r line; do
        if [[ "$line" =~ $pattern ]]; then
            printf '%s\t%s\tfixture\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[3]}"
        fi
    done <<<"$output" | sort -u >"$TEST_ROOT/scripts/validation/relative-link-allowlist.txt"
}

make_docs_root() {
    make_metadata_root
    inventory_plugin_links
    fixture_git init -q
    fixture_git config user.name Fixture
    fixture_git config user.email fixture@example.invalid
    fixture_git config commit.gpgsign false
    fixture_git config core.hooksPath /dev/null
    put .docs/research/r.md <<'DOC'
# Research
Status: Approved
DOC
    put .docs/ADR/0001-a.md <<'DOC'
# ADR 0001: A
Status: Accepted

## Context
Grounded in [research](../research/r.md); prior authority [spec](../spec/00-a.md).

## Decision
Decide.

## Consequences
Consequences.
DOC
    put .docs/spec/00-a.md <<'DOC'
# Spec A
Status: Approved

## Authority
Derived from [ADR 0001](../ADR/0001-a.md).
DOC
    put .docs/slice-plans/p.md <<'DOC'
# Plan P
Status: Approved
Target specs: 00-a.md

## Context
## Out of Scope & Threat-Model Boundary
## Steps
## Verification
## Revision Log
DOC
    put .docs/evaluations/p-plan-eval.md <<'DOC'
# Evaluation: P
Verdict: PASS
Round: 0
Reviewed against: [spec](../spec/00-a.md)

## Summary
Fine.

## Findings
None.
DOC
    fixture_commit "initial"
}

docs_all() {
    fixture_git add -A
    run "$LOOM_NODE" "$VALIDATOR" --root "$TEST_ROOT" --all "$@"
}

edit_file() {
    sed -i.bak "$2" "$TEST_ROOT/$1" && rm "$TEST_ROOT/$1.bak"
}

set_status() {
    edit_file "$1" "s/^Status: .*/Status: $2/"
}

@test "docs state: valid fixture passes and reports transitions unverified" {
    make_docs_root
    docs_all
    [ "$status" -eq 0 ]
    [[ "$output" == *"Repository all validation passed"* ]]
    [[ "$output" == *"status transitions were not verified"* ]]
}

@test "docs state: illegal and duplicate status fields name the file" {
    make_docs_root
    set_status .docs/spec/00-a.md Done
    edit_file .docs/ADR/0001-a.md 's/^Status: Accepted$/Status: Accepted\nStatus: Draft/'
    docs_all
    [ "$status" -eq 1 ]
    [[ "$output" == *".docs/spec/00-a.md: illegal spec status 'Done'"* ]]
    [[ "$output" == *".docs/ADR/0001-a.md: expected exactly one 'Status:' field, found 2"* ]]
    set_status .docs/slice-plans/p.md Accepted
    docs_all
    [[ "$output" == *".docs/slice-plans/p.md: illegal plan status 'Accepted'"* ]]
}

@test "docs state: archived plans must be Landed or Archived and plan identity is unique" {
    make_docs_root
    mkdir -p "$TEST_ROOT/.docs/slice-plans/archive"
    cp "$TEST_ROOT/.docs/slice-plans/p.md" "$TEST_ROOT/.docs/slice-plans/archive/q.md"
    cp "$TEST_ROOT/.docs/slice-plans/p.md" "$TEST_ROOT/.docs/slice-plans/p-plan.md"
    docs_all
    [ "$status" -eq 1 ]
    [[ "$output" == *"archive/q.md: archived plan must be Landed or Archived, found 'Approved'"* ]]
    [[ "$output" == *"slice-plans/p.md: slice 'p' has more than one active plan"* ]]
    [[ "$output" == *"slice-plans/p-plan.md: slice 'p' has more than one active plan"* ]]
}

@test "docs state: evaluation names accept every legal form and reject others" {
    make_docs_root
    put .docs/evaluations/p-review-findings.md <<'DOC'
findings
DOC
    put .docs/evaluations/p-acceptance.md <<'DOC'
acceptance
DOC
    put .docs/evaluations/macos-dual-client-dogfood-evidence.json <<'DOC'
{}
DOC
    # The fixture README's inventoried link to this evidence file now resolves.
    grep -v 'dogfood-evidence.json' "$TEST_ROOT/scripts/validation/relative-link-allowlist.txt" >"$TEST_ROOT/allowlist.next" || true
    mv "$TEST_ROOT/allowlist.next" "$TEST_ROOT/scripts/validation/relative-link-allowlist.txt"
    put_eval 2026-01-02-r-eval.md PASS 0 "Artifact: [r](../research/r.md)"
    docs_all
    [ "$status" -eq 0 ]
    put .docs/evaluations/notes.md <<'DOC'
notes
DOC
    cp "$TEST_ROOT/.docs/evaluations/p-plan-eval.md" "$TEST_ROOT/.docs/evaluations/2026-13-40-r-eval.md"
    docs_all
    [ "$status" -eq 1 ]
    [[ "$output" == *".docs/evaluations/notes.md: name is not"* ]]
    [[ "$output" == *"2026-13-40-r-eval.md: invalid date prefix"* ]]
}

@test "docs state: round, verdict and status fields on evaluations are validated" {
    make_docs_root
    edit_file .docs/evaluations/p-plan-eval.md 's/^Round: 0/Status: Evaluated\nRound: -1/; s/^Verdict: PASS/Verdict: MAYBE/'
    docs_all
    [ "$status" -eq 1 ]
    [[ "$output" == *"p-plan-eval.md: Round must be a nonnegative decimal integer"* ]]
    [[ "$output" == *"p-plan-eval.md: Verdict must be PASS or FAIL"* ]]
    [[ "$output" == *"p-plan-eval.md: evaluation must not carry a 'Status:' field"* ]]
}

# put_eval <name> <verdict> <round> [extra header lines...]
put_eval() {
    local name="$1" verdict="$2" round="$3"
    shift 3
    {
        printf '# Evaluation: P\nVerdict: %s\nRound: %s\nReviewed against: [spec](../spec/00-a.md)\n' "$verdict" "$round"
        for line in "$@"; do printf '%s\n' "$line"; done
        printf '\n## Summary\nx\n\n## Findings\nNone.\n'
    } >"$TEST_ROOT/.docs/evaluations/$name"
}

@test "docs state: round sequence follows commit ancestry and rejects unrecorded resets" {
    make_docs_root
    first="$(fixture_git rev-parse HEAD)"
    put_eval p-plan-eval.md FAIL 0 "Commit: $first"
    fixture_commit "plan fail"
    second="$(fixture_git rev-parse HEAD)"
    put_eval p-eval.md PASS 0 "Commit: $second"
    docs_all
    [ "$status" -eq 1 ]
    [[ "$output" == *"p-eval.md: round 0 follows"*"expected exactly 1"* ]]
    put_eval p-eval.md PASS 3 "Commit: $second"
    docs_all
    [ "$status" -eq 1 ]
    [[ "$output" == *"p-eval.md: round 3 follows"*"expected exactly 1"* ]]
    put_eval p-eval.md PASS 1 "Commit: $second"
    docs_all
    [ "$status" -eq 0 ]
    put_eval p-eval.md FAIL 2 "Commit: $second"
    docs_all
    [ "$status" -eq 1 ]
}

@test "docs state: first evaluation must be round 0 and ordering needs a recorded commit" {
    make_docs_root
    put_eval p-plan-eval.md PASS 2
    docs_all
    [ "$status" -eq 1 ]
    [[ "$output" == *"p-plan-eval.md: first evaluation of 'p' must be Round: 0, found 2"* ]]
    put_eval p-plan-eval.md FAIL 0
    put_eval p-eval.md PASS 1
    docs_all
    [ "$status" -eq 1 ]
    [[ "$output" == *"p-eval.md: cannot order evaluations: the recorded reviewed 'Commit:' is missing"* ]]
    [[ "$output" == *"p-plan-eval.md: cannot order evaluations"* ]]
}

@test "docs state: non-merits FAIL does not advance and Owner-Reset must be a recorded decision" {
    make_docs_root
    first="$(fixture_git rev-parse HEAD)"
    put_eval p-plan-eval.md FAIL 0 "Commit: $first" "Run-Status: infrastructure-blocked"
    fixture_commit "blocked"
    second="$(fixture_git rev-parse HEAD)"
    put_eval p-eval.md PASS 0 "Commit: $second"
    docs_all
    [ "$status" -eq 0 ]
    put_eval p-plan-eval.md FAIL 0 "Commit: $first" "Run-Status: flaky"
    docs_all
    [ "$status" -eq 1 ]
    [[ "$output" == *"p-plan-eval.md: Run-Status must be one of invalid, infrastructure-blocked"* ]]
    put_eval p-plan-eval.md FAIL 4 "Commit: $first"
    put_eval p-eval.md FAIL 0 "Commit: $second" "Owner-Reset: yes"
    docs_all
    [ "$status" -eq 1 ]
    [[ "$output" == *"p-eval.md: Owner-Reset must record an owner decision naming 'p'"* ]]
    put_eval p-eval.md FAIL 0 "Commit: $second" "Owner-Reset: owner decision for p: materially new direction, reset to 0"
    docs_all
    [[ "$output" != *"p-eval.md:"* ]]
}

@test "docs state: required headings and authority references are enforced" {
    make_docs_root
    printf '# Spec\nStatus: Approved\n\n## Authority\nSee ADR 0001 by name only.\n' >"$TEST_ROOT/.docs/spec/00-a.md"
    printf '# ADR\nStatus: Accepted\n\n## Context\nNo links.\n' >"$TEST_ROOT/.docs/ADR/0001-a.md"
    printf '# Plan\nStatus: Approved\n\n## Context\nNothing.\n' >"$TEST_ROOT/.docs/slice-plans/p.md"
    printf '# Eval\nVerdict: PASS\nRound: 0\n\n## Summary\nx\n' >"$TEST_ROOT/.docs/evaluations/p-plan-eval.md"
    docs_all
    [ "$status" -eq 1 ]
    [[ "$output" == *"spec/00-a.md: Authority section must link at least one existing ADR"* ]]
    [[ "$output" == *"ADR/0001-a.md: missing required heading 'Decision'"* ]]
    [[ "$output" == *"ADR/0001-a.md: body must link existing approved research"* ]]
    [[ "$output" == *"slice-plans/p.md: missing required heading 'Steps'"* ]]
    [[ "$output" == *"slice-plans/p.md: plan must identify target specs"* ]]
    [[ "$output" == *"p-plan-eval.md: missing required heading 'Findings'"* ]]
    [[ "$output" == *"p-plan-eval.md: evaluation header must identify"* ]]
}

@test "docs state: historical links are checked under all but not links mode" {
    make_docs_root
    printf '[gone](missing.md)\n' >>"$TEST_ROOT/.docs/evaluations/p-plan-eval.md"
    fixture_git add -A
    links
    [ "$status" -eq 0 ]
    docs_all
    [ "$status" -eq 1 ]
    [[ "$output" == *".docs/evaluations/p-plan-eval.md: missing or unsafe relative-link target: missing.md"* ]]
    printf '%s\t%s\t%s\n' .docs/evaluations/p-plan-eval.md missing.md "historical pointer" >>"$TEST_ROOT/scripts/validation/relative-link-allowlist.txt"
    docs_all
    [ "$status" -eq 0 ]
}

@test "docs state: rule exceptions are exact and stale ones fail" {
    make_docs_root
    put .docs/evaluations/old-eval.md <<'DOC'
# Old
Verdict: PASS
Round: 0
Reviewed against: x

## Findings
none
DOC
    docs_all
    [ "$status" -eq 1 ]
    [[ "$output" == *"old-eval.md: missing required heading 'Summary' [heading-summary]"* ]]
    printf '%s\t%s\t%s\n' .docs/evaluations/old-eval.md rule:heading-summary "pre-template" \
        .docs/evaluations/p-plan-eval.md rule:heading-summary "not needed" >>"$TEST_ROOT/scripts/validation/relative-link-allowlist.txt"
    docs_all
    [ "$status" -eq 1 ]
    [[ "$output" != *"old-eval.md: missing required heading"* ]]
    [[ "$output" == *"stale rule exception: .docs/evaluations/p-plan-eval.md"$'\t'"rule:heading-summary"* ]]
}

@test "baseline legal transition" {
    make_docs_root
    base="$(fixture_git rev-parse HEAD)"
    set_status .docs/slice-plans/p.md "In Progress"
    fixture_commit "progress"
    set_status .docs/slice-plans/p.md "Implemented"
    docs_all --baseline "$base"
    [ "$status" -eq 0 ]
    [[ "$output" != *"were not verified"* ]]
    set_status .docs/slice-plans/p.md "In Progress"
    docs_all --baseline HEAD
    [ "$status" -eq 0 ]
}

@test "baseline illegal transition" {
    make_docs_root
    set_status .docs/slice-plans/p.md Implemented
    fixture_commit "implemented"
    base="$(fixture_git rev-parse HEAD)"
    set_status .docs/ADR/0001-a.md Draft
    set_status .docs/slice-plans/p.md Approved
    set_status .docs/spec/00-a.md Abandoned
    docs_all --baseline "$base"
    [ "$status" -eq 1 ]
    [[ "$output" == *".docs/ADR/0001-a.md: baseline: illegal status transition"* ]]
    [[ "$output" == *".docs/slice-plans/p.md: baseline: illegal status transition (.docs/slice-plans/p.md 'Implemented' -> .docs/slice-plans/p.md 'Approved')"* ]]
    [[ "$output" != *"spec/00-a.md: baseline"* ]]
}

@test "baseline archive rename" {
    make_docs_root
    set_status .docs/slice-plans/p.md "Landed"
    fixture_commit "landed"
    base="$(fixture_git rev-parse HEAD)"
    mkdir -p "$TEST_ROOT/.docs/slice-plans/archive"
    fixture_git mv .docs/slice-plans/p.md .docs/slice-plans/archive/p.md
    set_status .docs/slice-plans/archive/p.md Archived
    docs_all --baseline "$base"
    [ "$status" -eq 0 ]
    set_status .docs/slice-plans/archive/p.md Landed
    docs_all --baseline "$base"
    [ "$status" -eq 0 ]
    fixture_commit "archive"
    fixture_git mv .docs/slice-plans/archive/p.md .docs/slice-plans/p.md
    docs_all --baseline HEAD
    [ "$status" -eq 1 ]
    [[ "$output" == *"baseline: archived plan was reactivated"* ]]
}

@test "baseline archive rename before landing is rejected" {
    make_docs_root
    base="$(fixture_git rev-parse HEAD)"
    mkdir -p "$TEST_ROOT/.docs/slice-plans/archive"
    fixture_git mv .docs/slice-plans/p.md .docs/slice-plans/archive/p.md
    set_status .docs/slice-plans/archive/p.md Landed
    docs_all --baseline "$base"
    [ "$status" -eq 1 ]
    [[ "$output" == *"archive/p.md: baseline: archive rename before landing"* ]]
}

@test "baseline invalid ref" {
    make_docs_root
    docs_all --baseline no-such-ref
    [ "$status" -eq 2 ]
    [[ "$output" == *"baseline ref is unavailable: no-such-ref"* ]]
    fixture_git branch dup
    fixture_git tag dup
    docs_all --baseline dup
    [ "$status" -eq 2 ]
    [[ "$output" == *"ambiguous baseline ref: dup"* ]]
    docs_all --baseline --root
    [ "$status" -eq 2 ]
    make_owned_root nogit
    TEST_ROOT="$NEW_OWNED_ROOT"
    run "$LOOM_NODE" "$VALIDATOR" --root "$TEST_ROOT" --all --baseline HEAD
    [ "$status" -eq 2 ]
}

@test "baseline usage errors" {
    make_docs_root
    run "$LOOM_NODE" "$VALIDATOR" --root "$TEST_ROOT" --links --baseline HEAD
    [ "$status" -eq 2 ]
    [[ "$output" == *"--baseline is only valid with --all"* ]]
    run "$LOOM_NODE" "$VALIDATOR" --root "$TEST_ROOT" --metadata --baseline HEAD
    [ "$status" -eq 2 ]
    run "$LOOM_NODE" "$VALIDATOR" --root "$TEST_ROOT" --baseline HEAD
    [ "$status" -eq 2 ]
    run "$LOOM_NODE" "$VALIDATOR" --root "$TEST_ROOT" --all --baseline
    [ "$status" -eq 2 ]
    [[ "$output" == *"--baseline requires a Git ref"* ]]
    run "$LOOM_NODE" "$VALIDATOR" --root "$TEST_ROOT" --all --baseline HEAD --baseline HEAD
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage: validate-repository.mjs [--root PATH] (--metadata|--links|--all) [--baseline REF]"* ]]
}

@test "baseline transitive jump without intermediate evidence is rejected" {
    make_docs_root
    base="$(fixture_git rev-parse HEAD)"
    set_status .docs/slice-plans/p.md Implemented
    docs_all --baseline "$base"
    [ "$status" -eq 1 ]
    [[ "$output" == *"p.md: baseline: illegal status transition (.docs/slice-plans/p.md 'Approved' -> .docs/slice-plans/p.md 'Implemented')"* ]]
}

@test "baseline Ready to Publish cannot move directly into the archive" {
    make_docs_root
    set_status .docs/slice-plans/p.md "Ready to Publish"
    fixture_commit "ready"
    base="$(fixture_git rev-parse HEAD)"
    mkdir -p "$TEST_ROOT/.docs/slice-plans/archive"
    fixture_git mv .docs/slice-plans/p.md .docs/slice-plans/archive/p.md
    set_status .docs/slice-plans/archive/p.md Archived
    docs_all --baseline "$base"
    [ "$status" -eq 1 ]
    [[ "$output" == *"archive/p.md: baseline: archive rename before landing"* ]]
}

@test "baseline Needs Clarification restores only the prior status" {
    make_docs_root
    set_status .docs/slice-plans/p.md "In Progress"
    fixture_commit "progress"
    set_status .docs/slice-plans/p.md "Needs Clarification"
    fixture_commit "paused"
    base="$(fixture_git rev-parse HEAD)"
    set_status .docs/slice-plans/p.md "In Progress"
    docs_all --baseline "$base"
    [ "$status" -eq 0 ]
    set_status .docs/slice-plans/p.md "Plan Review"
    docs_all --baseline "$base"
    [ "$status" -eq 1 ]
    [[ "$output" == *"p.md: baseline: illegal status transition"* ]]
    # A clarification with no earlier status in history is ambiguous, not assumed.
    set_status .docs/slice-plans/p.md "Needs Clarification"
    fixture_git checkout -q --orphan fresh
    fixture_git rm -rqf --cached . >/dev/null
    fixture_git add -A
    fixture_git commit -q -m "squashed"
    base="$(fixture_git rev-parse HEAD)"
    set_status .docs/slice-plans/p.md "In Progress"
    docs_all --baseline "$base"
    [ "$status" -eq 1 ]
    [[ "$output" == *"p.md: baseline: ambiguous clarification restoration"* ]]
}

@test "baseline FAIL returns need a recorded FAIL evaluation" {
    make_docs_root
    set_status .docs/slice-plans/p.md "Plan Review"
    fixture_commit "review"
    base="$(fixture_git rev-parse HEAD)"
    set_status .docs/slice-plans/p.md Draft
    docs_all --baseline "$base"
    [ "$status" -eq 1 ]
    [[ "$output" == *"p.md: baseline: FAIL return without a recorded FAIL evaluation"* ]]
    put_eval p-plan-eval.md FAIL 0 "Commit: $base"
    docs_all --baseline "$base"
    [ "$status" -eq 0 ]
}

@test "baseline FAIL return evidence must match the phase and be ordered after the rejected status" {
    make_docs_root
    old="$(fixture_git rev-parse HEAD)"
    set_status .docs/slice-plans/p.md "Plan Review"
    fixture_commit "review"
    base="$(fixture_git rev-parse HEAD)"
    set_status .docs/slice-plans/p.md Draft
    # A code evaluation FAIL cannot justify a plan-review return.
    put_eval p-eval.md FAIL 0 "Commit: $base"
    docs_all --baseline "$base"
    [ "$status" -eq 1 ]
    [[ "$output" == *"p.md: baseline: FAIL return without a recorded FAIL evaluation"* ]]
    rm "$TEST_ROOT/.docs/evaluations/p-eval.md"
    # A plan FAIL that reviewed a commit before the plan entered Plan Review is stale.
    put_eval p-plan-eval.md FAIL 0 "Commit: $old"
    docs_all --baseline "$base"
    [ "$status" -eq 1 ]
    [[ "$output" == *"p.md: baseline: FAIL return without a recorded FAIL evaluation"* ]]
    # Without a recorded reviewed commit the ordering is ambiguous, not assumed.
    put_eval p-plan-eval.md FAIL 0
    docs_all --baseline "$base"
    [ "$status" -eq 1 ]
    [[ "$output" == *"p.md: baseline: FAIL return evidence cannot be ordered"* ]]
    put_eval p-plan-eval.md FAIL 0 "Commit: $base"
    docs_all --baseline "$base"
    [ "$status" -eq 0 ]
}

@test "docs state: Owner-Reset is validated on the first event and requires the owner decision text" {
    make_docs_root
    first="$(fixture_git rev-parse HEAD)"
    put_eval p-plan-eval.md FAIL 3 "Commit: $first" "Owner-Reset: yes"
    fixture_commit "plan fail"
    second="$(fixture_git rev-parse HEAD)"
    put_eval p-eval.md PASS 0 "Commit: $second"
    docs_all
    [ "$status" -eq 1 ]
    [[ "$output" == *"p-plan-eval.md: Owner-Reset must record an owner decision naming 'p'"* ]]
    # Mentioning the identity, 'direction' and a reset is not an owner decision.
    put_eval p-plan-eval.md FAIL 0 "Commit: $first" "Owner-Reset: p direction reset 0"
    docs_all
    [ "$status" -eq 1 ]
    [[ "$output" == *"p-plan-eval.md: Owner-Reset must record an owner decision"* ]]
    put_eval p-plan-eval.md FAIL 0 "Commit: $first" "Owner-Reset: owner decision for p: materially new direction, reset to 0"
    docs_all
    [[ "$output" != *"must record an owner decision"* ]]
}

@test "docs state: ADR problem statement must be approved research or a top-level problem document" {
    make_docs_root
    mkdir -p "$TEST_ROOT/.docs/status"
    printf '# Notes\nStatus: Approved\n' >"$TEST_ROOT/.docs/status/notes.md"
    printf '# ADR\nStatus: Accepted\n\n## Context\n[notes](../status/notes.md) and [spec](../spec/00-a.md).\n\n## Decision\nd\n\n## Consequences\nc\n' >"$TEST_ROOT/.docs/ADR/0001-a.md"
    docs_all
    [ "$status" -eq 1 ]
    [[ "$output" == *"ADR/0001-a.md: body must link existing approved research or a problem statement"* ]]
    printf '# Problem\nStatus: Draft\n' >"$TEST_ROOT/.docs/problem.md"
    printf '# ADR\nStatus: Accepted\n\n## Context\n[problem](../problem.md) and [spec](../spec/00-a.md).\n\n## Decision\nd\n\n## Consequences\nc\n' >"$TEST_ROOT/.docs/ADR/0001-a.md"
    docs_all
    [[ "$output" == *"ADR/0001-a.md: body must link existing approved research or a problem statement"* ]]
    printf '# Problem\nStatus: Approved\n' >"$TEST_ROOT/.docs/problem.md"
    docs_all
    [[ "$output" != *"ADR/0001-a.md: body must link existing approved research"* ]]
}

@test "docs state: evaluation artifact and authority must be applicable references" {
    make_docs_root
    # An artifact link to an unrelated existing file does not identify the reviewed artifact.
    put_eval q-eval.md PASS 0 "Artifact: [other](../slice-plans/p.md)"
    docs_all
    [ "$status" -eq 1 ]
    [[ "$output" == *"q-eval.md: evaluation does not identify a resolvable reviewed artifact"* ]]
    # A bare Artifact: value that names nothing real is not identification.
    put_eval q-eval.md PASS 0 "Artifact: anything"
    docs_all
    [[ "$output" == *"q-eval.md: evaluation does not identify a resolvable reviewed artifact"* ]]
    # Authority that links only another evaluation, or names no authority, is not applicable.
    put_eval p-eval.md PASS 0
    printf '# E\nVerdict: PASS\nRound: 0\nReviewed against: [prior](p-eval.md)\n\n## Summary\nx\n\n## Findings\nNone.\n' >"$TEST_ROOT/.docs/evaluations/p-plan-eval.md"
    docs_all
    [[ "$output" == *"p-plan-eval.md: evaluation authority must reference applicable specs"* ]]
    printf '# E\nVerdict: PASS\nRound: 0\nReviewed against: ADR 9999\n\n## Summary\nx\n\n## Findings\nNone.\n' >"$TEST_ROOT/.docs/evaluations/p-plan-eval.md"
    docs_all
    [[ "$output" == *"p-plan-eval.md: evaluation authority names an ADR that does not exist: 9999"* ]]
}

@test "docs state: ADR authority needs approved research or problem and accepted prior authority" {
    make_docs_root
    printf '# ADR\nStatus: Accepted\n\n## Context\nOnly [research](../research/r.md).\n\n## Decision\nd\n\n## Consequences\nc\n' >"$TEST_ROOT/.docs/ADR/0001-a.md"
    docs_all
    [ "$status" -eq 1 ]
    [[ "$output" == *"ADR/0001-a.md: body must link accepted prior authority"* ]]
    [[ "$output" != *"approved research or a problem statement"* ]]
    set_status .docs/research/r.md Draft
    printf '# ADR\nStatus: Accepted\n\n## Context\nOnly [spec](../spec/00-a.md).\n\n## Decision\nd\n\n## Consequences\nc\n' >"$TEST_ROOT/.docs/ADR/0001-a.md"
    docs_all
    [ "$status" -eq 1 ]
    [[ "$output" == *"ADR/0001-a.md: body must link existing approved research or a problem statement"* ]]
}

@test "docs state: plan targets must be approved specs and accepted ADRs" {
    make_docs_root
    set_status .docs/spec/00-a.md Draft
    docs_all
    [ "$status" -eq 1 ]
    [[ "$output" == *"slice-plans/p.md: plan target .docs/spec/00-a.md must be Approved, found 'Draft'"* ]]
    set_status .docs/spec/00-a.md Approved
    set_status .docs/ADR/0001-a.md Draft
    edit_file .docs/slice-plans/p.md 's/^Target specs: .*/Target specs: 00-a.md ADR 0001/'
    docs_all
    [[ "$output" == *"slice-plans/p.md: plan target .docs/ADR/0001-a.md must be Accepted, found 'Draft'"* ]]
}

@test "docs state: evaluation artifact and authority identification must resolve" {
    make_docs_root
    put_eval unknown-thing-eval.md PASS 0
    docs_all
    [ "$status" -eq 1 ]
    [[ "$output" == *"unknown-thing-eval.md: evaluation does not identify a resolvable reviewed artifact: unknown-thing"* ]]
    put_eval unknown-thing-eval.md PASS 0 "Artifact: [thing](../slice-plans/p.md)"
    docs_all
    [ "$status" -eq 1 ]
    put_eval unknown-thing-eval.md PASS 0 "Artifact: [thing](../research/r.md)"
    docs_all
    [ "$status" -eq 1 ]
    rm "$TEST_ROOT/.docs/evaluations/unknown-thing-eval.md"
    put_eval r-eval.md PASS 0 "Artifact: [thing](../research/r.md)"
    docs_all
    [ "$status" -eq 0 ]
    rm "$TEST_ROOT/.docs/evaluations/r-eval.md"
    put_eval unknown-thing-eval.md PASS 0
    put_eval unknown-thing-eval.md PASS 0 "Artifact: [thing](../slice-plans/nope.md)"
    docs_all
    [[ "$output" == *"unknown-thing-eval.md: evaluation does not identify a resolvable reviewed artifact"* ]]
    printf '# E\nVerdict: PASS\nRound: 0\n\n## Summary\n**Reviewed against:** [spec](../spec/missing.md)\n\n## Findings\nNone.\n' >"$TEST_ROOT/.docs/evaluations/p-plan-eval.md"
    docs_all
    [[ "$output" == *"p-plan-eval.md: evaluation authority links must resolve to local files"* ]]
}

@test "docs state: an archived historical plan does not block the one active plan" {
    make_docs_root
    mkdir -p "$TEST_ROOT/.docs/slice-plans/archive"
    cp "$TEST_ROOT/.docs/slice-plans/p.md" "$TEST_ROOT/.docs/slice-plans/archive/p.md"
    set_status .docs/slice-plans/archive/p.md Landed
    docs_all
    [ "$status" -eq 0 ]
}

@test "docs state: unused historical allowlist records fail under all even when the source is gone" {
    make_docs_root
    printf '%s\t%s\t%s\n' .docs/evaluations/deleted-eval.md gone.md "deleted historical source" >>"$TEST_ROOT/scripts/validation/relative-link-allowlist.txt"
    docs_all
    [ "$status" -eq 1 ]
    [[ "$output" == *"stale allowlist record: .docs/evaluations/deleted-eval.md"$'\t'"gone.md"* ]]
    links
    [ "$status" -eq 0 ]
}
