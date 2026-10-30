#!/usr/bin/env bats
# Test suite for role-governance-guard.sh (role anti-drift; spec 08 wire adapters).
bats_require_minimum_version 1.5.0

GUARD="${BATS_TEST_DIRNAME}/role-governance-guard.sh"

setup_file() {
    : "${LOOM_TEST_BASH:?LOOM_TEST_BASH is required}"
    : "${LOOM_EXPECTED_BASH_VERSION:?LOOM_EXPECTED_BASH_VERSION is required}"
    case "$LOOM_TEST_BASH" in /*) ;; *) return 1 ;; esac
    [ -x "$LOOM_TEST_BASH" ]
    [[ "$($LOOM_TEST_BASH -c 'printf %s "$BASH_VERSION"')" =~ $LOOM_EXPECTED_BASH_VERSION ]]
    REAL_ROOT="$(CDPATH='' cd -- "${BATS_TEST_DIRNAME}/.." && pwd -P)"
    export REAL_ROOT
}

# guard <role> <command> -- Claude wire; role "" means LOOM_ROLE unset
guard() {
    local json
    json=$(jq -cn --arg c "$2" '{tool_input:{command:$c}}')
    run env -u LOOM_ROLE -u LOOM_ALLOW_ORCHESTRATOR_GATE ${1:+LOOM_ROLE="$1"} ${GATE:+LOOM_ALLOW_ORCHESTRATOR_GATE="$GATE"} \
        CLAUDE_PLUGIN_ROOT="$REAL_ROOT" "$LOOM_TEST_BASH" "$GUARD" <<<"$json"
}

guard_codex() {
    local json
    json=$(jq -cn --arg c "$2" '{tool_input:{command:$c}}')
    run env -u LOOM_ROLE ${1:+LOOM_ROLE="$1"} PLUGIN_ROOT="$REAL_ROOT" "$LOOM_TEST_BASH" "$GUARD" <<<"$json"
}

ORCH="Loom policy: Orchestrators cannot run test suites directly; delegate to an external worker."
EVAL="Loom policy: Evaluators are read-only and cannot mutate git history or checkout."

@test "unset LOOM_ROLE fails open for test runners and git mutation" {
    guard "" "scripts/check"
    [ "$status" -eq 0 ]
    guard "" "git commit -m x"
    [ "$status" -eq 0 ]
}

@test "orchestrator blocks scripts/check" {
    guard orchestrator "TMPDIR=/private/tmp scripts/check"
    [ "$status" -eq 2 ]
    [[ "$output" == *"$ORCH"* ]]
}

@test "orchestrator blocks bats, cargo test, npm test, pytest" {
    for c in "bats foo.bats" "cargo test" "npm test" "pytest -q" "cd x && bats a.bats"; do
        guard orchestrator "$c"
        [ "$status" -eq 2 ]
    done
}

@test "orchestrator may run scripts/check with LOOM_ALLOW_ORCHESTRATOR_GATE=1" {
    GATE=1 guard orchestrator "scripts/check"
    [ "$status" -eq 0 ]
}

@test "orchestrator gate allowance does not unlock bats" {
    GATE=1 guard orchestrator "bats foo.bats"
    [ "$status" -eq 2 ]
}

@test "orchestrator allows non-test commands" {
    for c in "git status" "git commit -m x" "git show HEAD" "ls scripts"; do
        guard orchestrator "$c"
        [ "$status" -eq 0 ]
    done
}

@test "evaluators block git mutation" {
    for r in plan-evaluator code-evaluator; do
        for c in "git commit -m x" "git push" "git merge x" "git rebase main" "git cherry-pick abc" "git apply p.diff" "git reset --hard HEAD~1"; do
            guard "$r" "$c"
            [ "$status" -eq 2 ]
            [[ "$output" == *"$EVAL"* ]]
        done
    done
}

@test "code-evaluator allows read-only inspection" {
    for c in "git diff HEAD~1" "git log --oneline" "git reset --soft HEAD" "cat file" "scripts/check" "bats x.bats"; do
        guard code-evaluator "$c"
        [ "$status" -eq 0 ]
    done
}

@test "arguments that mention test runners or mutations are allowed" {
    for r in orchestrator code-evaluator plan-evaluator developer; do
        for c in "echo bats" "git log --grep=bats" "cat test.bats" "echo 'git commit'" 'echo "scripts/check"'; do
            guard "$r" "$c"
            [ "$status" -eq 0 ]
        done
    done
}

@test "missing or empty command allows" {
    run env LOOM_ROLE=orchestrator CLAUDE_PLUGIN_ROOT="$REAL_ROOT" "$LOOM_TEST_BASH" "$GUARD" <<<'{"tool_input":{}}'
    [ "$status" -eq 0 ]
    run env LOOM_ROLE=orchestrator CLAUDE_PLUGIN_ROOT="$REAL_ROOT" "$LOOM_TEST_BASH" "$GUARD" <<<'{"tool_input":{"command":""}}'
    [ "$status" -eq 0 ]
}

@test "Claude wire: stderr reason, empty stdout, exit 2" {
    run --separate-stderr env LOOM_ROLE=orchestrator CLAUDE_PLUGIN_ROOT="$REAL_ROOT" "$LOOM_TEST_BASH" "$GUARD" <<<'{"tool_input":{"command":"cargo test"}}'
    [ "$status" -eq 2 ]
    [ -z "$output" ]
    [ "$stderr" = "$ORCH" ]
}

@test "Codex wire: deny JSON on stdout, exit 0" {
    guard_codex code-evaluator "git push"
    [ "$status" -eq 0 ]
    jq -e --arg r "$EVAL" '.hookSpecificOutput == {hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}' <<<"$output"
}

@test "Codex wire: allow is silent exit 0" {
    guard_codex orchestrator "git status"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "invalid root, invalid JSON, and wrong-typed command fail closed" {
    run env LOOM_ROLE=orchestrator "$LOOM_TEST_BASH" "$GUARD" <<<'{"tool_input":{"command":"ls"}}'
    [ "$status" -eq 2 ]
    run env CLAUDE_PLUGIN_ROOT="$REAL_ROOT" "$LOOM_TEST_BASH" "$GUARD" <<<'not json'
    [ "$status" -eq 2 ]
    run env CLAUDE_PLUGIN_ROOT="$REAL_ROOT" "$LOOM_TEST_BASH" "$GUARD" <<<'{"tool_input":{"command":5}}'
    [ "$status" -eq 2 ]
}
