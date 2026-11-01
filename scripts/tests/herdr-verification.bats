#!/usr/bin/env bats
# Offline Herdr adapter verification (M9 slice 3). Copies the marketplace and
# plugins/loom into a private install layout and drives the installed copy with
# an isolated HOME: root resolution, role launch, and the hook commands declared
# in hooks/hooks.json. This is a fixture host establishing Loom-side
# compatibility only; no Herdr binary, native application, or network is used.
bats_require_minimum_version 1.5.0

REPOSITORY_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
ROLES=(researcher planner plan-evaluator developer code-evaluator)

setup_file() {
    : "${LOOM_TEST_BASH:?LOOM_TEST_BASH is required}"
    : "${LOOM_EXPECTED_BASH_VERSION:?LOOM_EXPECTED_BASH_VERSION is required}"
    case "$LOOM_TEST_BASH" in /*) ;; *) return 1 ;; esac
    [ -x "$LOOM_TEST_BASH" ]
    [[ "$($LOOM_TEST_BASH -c 'printf %s "$BASH_VERSION"')" =~ $LOOM_EXPECTED_BASH_VERSION ]]
    local base
    base="$(cd "$BATS_FILE_TMPDIR" && pwd -P)"
    mkdir -m 700 "$base/install" "$base/home"
    cp -R "$REPOSITORY_ROOT/.herdr-plugin" "$base/install/.herdr-plugin"
    mkdir "$base/install/plugins"
    cp -R "$REPOSITORY_ROOT/plugins/loom" "$base/install/plugins/loom"
    export INSTALL="$base/install" FAKE_HOME="$base/home"
    # Resolve the declared paths from the copied tree, never from the checkout.
    PLUGIN="$(cd "$INSTALL/$(jq -er .source "$INSTALL/.herdr-plugin/marketplace.json")" && pwd -P)"
    export PLUGIN
}

# in_install <cmd...> -- run with an isolated HOME and no ambient client roots.
in_install() {
    run env -i PATH="$(dirname "$LOOM_TEST_BASH"):$PATH" HOME="$FAKE_HOME" TMPDIR="${TMPDIR:-/tmp}" "$@"
}

hook_cmd() { # <event> <index>
    jq -er --arg e "$1" --argjson i "$2" '.hooks[$e] | [.[].hooks[]] | .[$i].command' "$PLUGIN/hooks/hooks.json"
}

# run_hook <event> <index> <stdin-file> <out> <err> [VAR=value...] -- executes
# the declared command exactly as written; returns its exit status.
run_hook() {
    local cmd in_file="$3" out="$4" err="$5"
    cmd="$(hook_cmd "$1" "$2")"
    shift 5
    env -i PATH="$(dirname "$LOOM_TEST_BASH"):$PATH" HOME="$FAKE_HOME" TMPDIR="${TMPDIR:-/tmp}" "$@" \
        "$LOOM_TEST_BASH" -c "$cmd" <"$in_file" >"$out" 2>"$err"
}

make_repo() { # <dir>
    git init -q "$1"
    git -C "$1" config user.email test@example.com
    git -C "$1" config user.name Test
    mkdir -p "$1/.docs/status"
    printf 'initial\n' >"$1/.docs/status/handoff.md"
    git -C "$1" add .docs
    git -C "$1" commit -q -m "seed docs"
}

# ---------------------------------------------------------------------------
# Step 1: install layout and discovery
# ---------------------------------------------------------------------------

@test "install: marketplace source, manifest, skills and hooks resolve inside the copy" {
    [ "$PLUGIN" = "$INSTALL/plugins/loom" ]
    jq -e '.name == "loom" and .version == "0.2.0"' "$PLUGIN/.herdr-plugin/plugin.json"
    local skills hooks
    skills="$(cd "$PLUGIN/$(jq -er .skills "$PLUGIN/.herdr-plugin/plugin.json")" && pwd -P)"
    hooks="$(cd "$(dirname "$PLUGIN/$(jq -er .hooks "$PLUGIN/.herdr-plugin/plugin.json")")" && pwd -P)/hooks.json"
    case "$skills" in "$INSTALL"/*) ;; *) return 1 ;; esac
    case "$hooks" in "$INSTALL"/*) ;; *) return 1 ;; esac
    [ -d "$skills" ] && [ -f "$hooks" ]
    case "$INSTALL" in "$REPOSITORY_ROOT"/*) return 1 ;; esac
}

# ---------------------------------------------------------------------------
# Step 2: helper resolution, role launch, skills
# ---------------------------------------------------------------------------

@test "resolve: installed helper path is physical; unset and relative roots fail closed" {
    in_install "$LOOM_TEST_BASH" "$PLUGIN/bin/loom-resolve-helper" herdr loom-coord
    [ "$status" -eq 2 ]
    in_install env HERDR_PLUGIN_ROOT="$PLUGIN" "$LOOM_TEST_BASH" "$PLUGIN/bin/loom-resolve-helper" herdr loom-coord
    [ "$status" -eq 0 ]
    [ "$output" = "$PLUGIN/bin/loom-coord" ]
    in_install env HERDR_PLUGIN_ROOT="plugins/loom" "$LOOM_TEST_BASH" "$PLUGIN/bin/loom-resolve-helper" herdr loom-coord
    [ "$status" -eq 2 ]
}

@test "resolve: invalid manifest and missing helper fail closed" {
    local bad="$BATS_TEST_TMPDIR/bad"
    cp -R "$PLUGIN" "$bad"
    printf '{"name":"other","version":"0.2.0"}\n' >"$bad/.herdr-plugin/plugin.json"
    in_install env HERDR_PLUGIN_ROOT="$bad" "$LOOM_TEST_BASH" "$PLUGIN/bin/loom-resolve-helper" herdr loom-coord
    [ "$status" -eq 2 ]
    cp "$PLUGIN/.herdr-plugin/plugin.json" "$bad/.herdr-plugin/plugin.json"
    rm "$bad/bin/loom-coord"
    in_install env HERDR_PLUGIN_ROOT="$bad" "$LOOM_TEST_BASH" "$PLUGIN/bin/loom-resolve-helper" herdr loom-coord
    [ "$status" -eq 2 ]
}

@test "launch: five roles emit cold, non-delegating one-level descriptors" {
    local role profile
    for role in "${ROLES[@]}"; do
        case "$role" in
        researcher) profile=Economy ;;
        developer) profile=Standard ;;
        *) profile="Deep review" ;;
        esac
        in_install "$PLUGIN/bin/loom-launch-role" herdr "$role"
        [ "$status" -eq 0 ]
        printf '%s' "$output" | jq -e --arg r "$role" --arg p "$profile" \
            '.client == "herdr" and .role == $r and .profile == $p and .herdr.profile == $p and .cold == true and .delegation == false and .permissions == "one-level"'
    done
}

@test "launch: explicit model and effort overrides are rejected" {
    in_install "$PLUGIN/bin/loom-launch-role" herdr developer --model foo
    [ "$status" -eq 2 ]
    in_install "$PLUGIN/bin/loom-launch-role" herdr developer --effort high
    [ "$status" -eq 2 ]
}

@test "skills: loom-run and all five role skills are discoverable from the manifest" {
    local skills skill
    skills="$PLUGIN/$(jq -er .skills "$PLUGIN/.herdr-plugin/plugin.json")"
    for skill in loom-run loom-researcher loom-planner loom-plan-evaluator loom-developer loom-code-evaluator; do
        [ -s "$skills/$skill/SKILL.md" ]
    done
}

# ---------------------------------------------------------------------------
# Step 3: declared hook commands, Herdr wire
# ---------------------------------------------------------------------------

# assert_fixture <dir-name> <manifest-event> <case> -- byte-exact comparison of
# exit status, stdout and stderr against the checked-in Herdr wire fixture.
assert_fixture() {
    local dir="$PLUGIN/hooks/fixtures/hook-wire-v1/herdr/$1" case_name="$3" in_file out err actual repo session
    in_file="$dir/$case_name.input.json"
    out="$BATS_TEST_TMPDIR/out"
    err="$BATS_TEST_TMPDIR/err"
    if [ "$1" = pre-compact ]; then
        repo="$BATS_TEST_TMPDIR/repo-$case_name"
        make_repo "$repo"
        session="$(jq -r .session_id "$in_file")"
        if [ "$case_name" = block ]; then
            mkdir -p "$repo/.git/loom/precompact/$session"
            git -C "$repo" log -1 --format=%H -- .docs >"$repo/.git/loom/precompact/$session/marker"
        fi
        jq --arg cwd "$repo" '. + {cwd: $cwd}' "$in_file" >"$BATS_TEST_TMPDIR/in.json"
        in_file="$BATS_TEST_TMPDIR/in.json"
    fi
    run_hook "$2" 0 "$in_file" "$out" "$err" HERDR_PLUGIN_ROOT="$PLUGIN" && actual=0 || actual=$?
    [ "$actual" -eq "$(tr -d '\n' <"$dir/$case_name.exit")" ]
    cmp "$out" "$dir/$case_name.stdout"
    cmp "$err" "$dir/$case_name.stderr"
}

@test "hooks: declared manifest wires identity, role governance and precompact commands" {
    [ "$(jq '[.hooks.PreToolUse[].hooks[]] | length' "$PLUGIN/hooks/hooks.json")" -eq 2 ]
    [ "$(jq '[.hooks.PreCompact[].hooks[]] | length' "$PLUGIN/hooks/hooks.json")" -eq 1 ]
    [[ "$(hook_cmd PreToolUse 0)" == *git-identity-guard.sh* ]]
    [[ "$(hook_cmd PreToolUse 1)" == *role-governance-guard.sh* ]]
    [[ "$(hook_cmd PreCompact 0)" == *precompact-write-ahead-backstop.sh* ]]
}

@test "fixture herdr/pre-tool-use/allow" { assert_fixture pre-tool-use PreToolUse allow; }
@test "fixture herdr/pre-tool-use/block" { assert_fixture pre-tool-use PreToolUse block; }
@test "fixture herdr/pre-tool-use/malformed" { assert_fixture pre-tool-use PreToolUse malformed; }
@test "fixture herdr/pre-compact/allow" { assert_fixture pre-compact PreCompact allow; }
@test "fixture herdr/pre-compact/block" { assert_fixture pre-compact PreCompact block; }
@test "fixture herdr/pre-compact/malformed" { assert_fixture pre-compact PreCompact malformed; }

@test "hooks: role governance blocks evaluator git mutation and allows a permitted command" {
    local out="$BATS_TEST_TMPDIR/out" err="$BATS_TEST_TMPDIR/err" code
    printf '%s\n' '{"tool_input":{"command":"git commit -m x"}}' >"$BATS_TEST_TMPDIR/mutate.json"
    printf '%s\n' '{"tool_input":{"command":"git status"}}' >"$BATS_TEST_TMPDIR/status.json"
    run_hook PreToolUse 1 "$BATS_TEST_TMPDIR/mutate.json" "$out" "$err" HERDR_PLUGIN_ROOT="$PLUGIN" LOOM_ROLE=code-evaluator && code=0 || code=$?
    [ "$code" -eq 2 ]
    [ ! -s "$out" ]
    [ "$(cat "$err")" = "Loom policy: Evaluators are read-only and cannot mutate git history or checkout." ]
    run_hook PreToolUse 1 "$BATS_TEST_TMPDIR/status.json" "$out" "$err" HERDR_PLUGIN_ROOT="$PLUGIN" LOOM_ROLE=code-evaluator
    [ ! -s "$out" ] && [ ! -s "$err" ]
}

@test "hooks: identity mutation is blocked on the Herdr wire; permitted commit passes" {
    local out="$BATS_TEST_TMPDIR/out" err="$BATS_TEST_TMPDIR/err" code
    printf '%s\n' '{"tool_input":{"command":"git commit --author=x -m z"}}' >"$BATS_TEST_TMPDIR/bad.json"
    printf '%s\n' '{"tool_input":{"command":"git commit -m z"}}' >"$BATS_TEST_TMPDIR/ok.json"
    run_hook PreToolUse 0 "$BATS_TEST_TMPDIR/bad.json" "$out" "$err" HERDR_PLUGIN_ROOT="$PLUGIN" && code=0 || code=$?
    [ "$code" -eq 2 ]
    [ ! -s "$out" ]
    [[ "$(cat "$err")" == "loom identity guard: blocked"* ]]
    run_hook PreToolUse 0 "$BATS_TEST_TMPDIR/ok.json" "$out" "$err" HERDR_PLUGIN_ROOT="$PLUGIN"
    [ ! -s "$out" ] && [ ! -s "$err" ]
}

@test "hooks: competing valid client roots fail closed for every declared command" {
    local out="$BATS_TEST_TMPDIR/out" err="$BATS_TEST_TMPDIR/err" code spec
    local repo="$BATS_TEST_TMPDIR/repo-amb"
    make_repo "$repo"
    printf '%s\n' '{"tool_input":{"command":"git status"}}' >"$BATS_TEST_TMPDIR/tool.json"
    jq -n --arg cwd "$repo" '{trigger:"manual",session_id:"amb",cwd:$cwd}' >"$BATS_TEST_TMPDIR/compact.json"
    for spec in "PreToolUse 0 tool" "PreToolUse 1 tool" "PreCompact 0 compact"; do
        # shellcheck disable=SC2086
        set -- $spec
        run_hook "$1" "$2" "$BATS_TEST_TMPDIR/$3.json" "$out" "$err" \
            HERDR_PLUGIN_ROOT="$PLUGIN" CLAUDE_PLUGIN_ROOT="$PLUGIN" && code=0 || code=$?
        [ "$code" -eq 2 ]
        [ ! -s "$out" ]
    done
}
