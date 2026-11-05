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
HC="Loom policy: hc is orchestrator-only; role sessions cannot call hc."
HC_ROLES="researcher planner plan-evaluator developer code-evaluator foo"

# hc_guard_denied <command> -- every non-orchestrator role, both wires
hc_guard_denied() {
    local r
    for r in $HC_ROLES; do
        guard "$r" "$1"
        [ "$status" -eq 2 ]
        [ "$output" = "$HC" ]
        guard_codex "$r" "$1"
        [ "$status" -eq 0 ]
        jq -e --arg r "$HC" '.hookSpecificOutput == {hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}' <<<"$output"
    done
}

# hc_wire_allowed <role> <command> -- silent exit 0 on both wires ("" = LOOM_ROLE unset)
hc_wire_allowed() {
    guard "$1" "$2"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    guard_codex "$1" "$2"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

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

@test "landing exception does not unlock other runners in compound commands" {
    GATE=1 guard orchestrator "scripts/check && bats foo.bats"
    [ "$status" -eq 2 ]
    GATE=1 guard orchestrator "bats foo.bats; scripts/check"
    [ "$status" -eq 2 ]
    GATE=1 guard orchestrator "scripts/check"
    [ "$status" -eq 0 ]
}

@test "evaluators block git mutation behind value-taking global options" {
    local c
    for c in "git -C /tmp commit -m x" "git -c user.name=x commit -m x" "git --git-dir /tmp/g push" "git --git-dir=/tmp/g -C /tmp reset --hard" "git --no-pager -C . merge x"; do
        guard code-evaluator "$c"
        [ "$status" -eq 2 ]
        guard plan-evaluator "$c"
        [ "$status" -eq 2 ]
    done
    guard code-evaluator "git -C /tmp log --oneline"
    [ "$status" -eq 0 ]
}

@test "quoted command words are de-quoted; quoted arguments are ignored" {
    guard orchestrator "'bats' tests"
    [ "$status" -eq 2 ]
    guard orchestrator "\"cargo\" test"
    [ "$status" -eq 2 ]
    guard code-evaluator "git 'commit' -m x"
    [ "$status" -eq 2 ]
    guard code-evaluator 'git "commit" -m x'
    [ "$status" -eq 2 ]
    guard orchestrator "echo 'bats'"
    [ "$status" -eq 0 ]
    guard orchestrator "echo 'a; bats'"
    [ "$status" -eq 0 ]
    guard code-evaluator 'git log --grep="bats"'
    [ "$status" -eq 0 ]
    guard code-evaluator "git log --grep='commit'"
    [ "$status" -eq 0 ]
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

@test "quoted executable paths containing spaces are blocked at command position" {
    guard orchestrator '"/tmp/my tools/bats" tests'
    [ "$status" -eq 2 ]
    guard orchestrator "'/tmp/space dir/scripts/check'"
    [ "$status" -eq 2 ]
    GATE=1 guard orchestrator '"/tmp/space dir/scripts/check"'
    [ "$status" -eq 0 ]
    guard orchestrator 'echo "/tmp/my tools/bats"'
    [ "$status" -eq 0 ]
}

@test "quoted executable paths with spaces are blocked after env assignments" {
    guard orchestrator 'FOO=1 "/tmp/my tools/bats" tests'
    [ "$status" -eq 2 ]
    guard orchestrator 'FOO=1 "/tmp/space dir/scripts/check"'
    [ "$status" -eq 2 ]
    GATE=1 guard orchestrator 'FOO=1 "/tmp/space dir/scripts/check"'
    [ "$status" -eq 0 ]
    guard orchestrator 'echo FOO=1 "/tmp/my tools/bats"'
    [ "$status" -eq 0 ]
}

@test "herdr root retired: a lone HERDR_PLUGIN_ROOT fails closed" {
    json=$(jq -cn --arg c "git commit -m x" '{tool_input:{command:$c}}')
    run env -u PLUGIN_ROOT -u CLAUDE_PLUGIN_ROOT LOOM_ROLE=code-evaluator HERDR_PLUGIN_ROOT="$REAL_ROOT" "$LOOM_TEST_BASH" "$GUARD" <<<"$json"
    [ "$status" -eq 2 ]
    [ "$output" = "Loom hook input invalid for pre-tool-use." ]
}

@test "root: both PLUGIN_ROOT and CLAUDE_PLUGIN_ROOT validate (ambiguous) fails closed" {
    json=$(jq -cn --arg c "git status" '{tool_input:{command:$c}}')
    run env LOOM_ROLE=code-evaluator PLUGIN_ROOT="$REAL_ROOT" CLAUDE_PLUGIN_ROOT="$REAL_ROOT" "$LOOM_TEST_BASH" "$GUARD" <<<"$json"
    [ "$status" -eq 2 ]
    [ "$output" = "Loom hook input invalid for pre-tool-use." ]
}

@test "hc: direct invocation is denied" {
    hc_guard_denied "hc ls"
    hc_guard_denied "hc run --bg x claude"
    hc_guard_denied "hc get t1 --json"
}

@test "hc: assignment and env prefixes are denied" {
    for c in "A=1 hc ls" "env A=1 hc get t1" "A=1 env B=2 hc ls" "env -i hc ls" "command hc read t1" "exec hc ls" "time hc ls"; do
        hc_guard_denied "$c"
    done
}

@test "hc: sh -c strings are denied" {
    for c in 'sh -c "hc ls"' "sh -c 'hc kill t1'" 'sh -c "echo a; hc ls"'; do
        hc_guard_denied "$c"
    done
}

@test "hc: bash -c strings are denied" {
    for c in 'bash -c "hc ls"' "bash -lc 'hc send t1 x'" 'env -i bash -c "hc ls"'; do
        hc_guard_denied "$c"
    done
}

@test "hc: eval strings are denied" {
    for c in 'eval "hc ls"' "eval 'hc rm t1'"; do
        hc_guard_denied "$c"
    done
}

@test "hc: backtick substitution is denied" {
    for c in 'echo `hc ls`' 'x=`hc get t1`'; do
        hc_guard_denied "$c"
    done
}

@test "hc: command substitution is denied" {
    for c in 'echo $(hc ls)' 'x=$(hc get t1); echo $x'; do
        hc_guard_denied "$c"
    done
}

@test "hc: timeout wrapper is denied" {
    for c in "timeout 5 hc wait t1" "timeout -k 1 5 hc ls"; do
        hc_guard_denied "$c"
    done
}

@test "hc: xargs is denied" {
    for c in "echo t1 | xargs hc get" "printf 't1\n' | xargs -I{} hc kill {}"; do
        hc_guard_denied "$c"
    done
}

@test "hc: absolute and relative paths are denied" {
    for c in "/usr/local/bin/hc ls" "/opt/homebrew/bin/hc kill t1" "./hc ls"; do
        hc_guard_denied "$c"
    done
}

@test "hc: chained, nohup, exec-terminated and quote-obfuscated forms are denied" {
    for c in "ls && hc send t1 x" "nohup hc wait t1" 'find . -exec hc\;' "ls;hc ls" 'echo $(hc)' 'h"c" ls' 'h\c ls'; do
        hc_guard_denied "$c"
    done
}

@test "hc: an unbalanced quote does not bypass the hc deny" {
    hc_guard_denied "hc ls # '"
}

@test "hc: unspaced pipe and background separators are denied" {
    # the hc scan maps | and & to spaces; spaced forms are covered above, unspaced ones must match too
    for c in "ls|hc ls" "ls&hc ls"; do
        hc_guard_denied "$c"
    done
}

@test "hc: a line continuation inside the executable name is denied" {
    # bash joins h\<newline>c into hc, so the scan must join it too
    for c in $'h\\\nc ls' $'h\\\nc get t1' $'ls && h\\\nc send t1 x'; do
        hc_guard_denied "$c"
    done
}

@test "hc: a line continuation inside a path executable name is denied" {
    for c in $'/usr/local/bin/h\\\nc ls' $'./h\\\nc kill t1'; do
        hc_guard_denied "$c"
    done
}

@test "hc: a line continuation inside a sh -c or bash -c string is denied" {
    for c in $'sh -c "h\\\nc ls"' $'sh -c \'h\\\nc ls\'' $'bash -c "h\\\nc ls"' $'bash -lc \'h\\\nc get t1\''; do
        hc_guard_denied "$c"
    done
}

@test "hc: an escaped backslash before a newline does not hide a later hc" {
    # x\\ ends a word; the newline after it is a real separator, so hc still starts a command
    hc_guard_denied $'x\\\\\nhc ls'
}

@test "hc: words that merely contain hc are allowed for every role" {
    for r in "" orchestrator $HC_ROLES; do
        for c in "echo abc" "which-hc" "./hc.sh" "git status" "rg -n chc plugins"; do
            hc_wire_allowed "$r" "$c"
        done
    done
}

@test "hc: documented false positives are denied for non-orchestrator roles" {
    hc_guard_denied 'git commit -m "hc run"'
    hc_guard_denied "echo hc"
}

@test "hc: orchestrator and unset LOOM_ROLE are not affected" {
    for c in "hc ls" "/usr/local/bin/hc run --bg x claude" 'sh -c "hc ls"'; do
        hc_wire_allowed orchestrator "$c"
        hc_wire_allowed "" "$c"
    done
}
