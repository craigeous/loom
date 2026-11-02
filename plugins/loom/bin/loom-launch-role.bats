#!/usr/bin/env bats
# Test suite for loom-launch-role (spec 10 -> Versioned compatibility and
# capability mapping; macos-dual-client-dogfood plan Step 6). Positive tests
# run the real script against the real repository tree (proving no drift from
# the tracked compatibility matrix / agents / skills / schema). Negative
# tests that need a corrupted input build an isolated fixture tree so the
# real repository state is never mutated. Codex-path tests always stub the
# child process via LOOM_LAUNCH_ROLE_CODEX_BIN -- this suite MUST NEVER spawn
# a live codex process. The code evaluator re-runs this suite as the shell
# gate's TEST step.
bats_require_minimum_version 1.5.0

LAUNCH="${BATS_TEST_DIRNAME}/loom-launch-role"
REPO_ROOT="${BATS_TEST_DIRNAME}/../../.."

setup_file() {
    : "${LOOM_TEST_BASH:?LOOM_TEST_BASH is required}"
    : "${LOOM_EXPECTED_BASH_VERSION:?LOOM_EXPECTED_BASH_VERSION is required}"
    case "$LOOM_TEST_BASH" in /*) ;; *) return 1 ;; esac
    [ -x "$LOOM_TEST_BASH" ]
    [[ "$($LOOM_TEST_BASH -c 'printf %s "$BASH_VERSION"')" =~ $LOOM_EXPECTED_BASH_VERSION ]]
}

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

# make_stub — an executable that records its own env/argv and never contacts
# a real client. Prints nothing that could be mistaken for a real codex run.
make_stub() {
    STUB_DIR="$(mktemp -d)"
    STUB="$STUB_DIR/codex-stub"
    RECORD="$STUB_DIR/record"
    cat >"$STUB" <<EOF
#!/usr/bin/env bash
{
    printf 'ACTIVE=%s\n' "\${LOOM_LAUNCH_ROLE_ACTIVE:-}"
    printf 'ARGC=%s\n' "\$#"
    for a in "\$@"; do printf 'ARG:%s\n' "\$a"; done
} >"$RECORD"
exit 0
EOF
    chmod +x "$STUB"
}

# make_root — a fully valid isolated copy of the launch-relevant subtree
# (bin/adapters/agents/schemas/skills), rooted at $ROOT, copied verbatim from
# the real repository so positive behavior is identical; individual tests
# corrupt only what they need.
make_root() {
    ROOT="$(mktemp -d)"
    ROOT="$(CDPATH='' cd -- "$ROOT" && pwd -P)"
    mkdir -p "$ROOT/bin" "$ROOT/adapters/compatibility" "$ROOT/agents" "$ROOT/roles" "$ROOT/schemas" "$ROOT/skills"
    cp "$LAUNCH" "$ROOT/bin/loom-launch-role"
    chmod +x "$ROOT/bin/loom-launch-role"
    cp "$REPO_ROOT/plugins/loom/adapters/compatibility/v0.3.0.json" "$ROOT/adapters/compatibility/v0.3.0.json"
    cp "$REPO_ROOT/plugins/loom/schemas/loom-role-launch-v1.schema.json" "$ROOT/schemas/loom-role-launch-v1.schema.json"
    local role
    for role in researcher planner plan-evaluator developer code-evaluator; do
        cp "$REPO_ROOT/plugins/loom/agents/$role.md" "$ROOT/agents/$role.md"
        cp "$REPO_ROOT/plugins/loom/roles/$role.md" "$ROOT/roles/$role.md"
        mkdir -p "$ROOT/skills/loom-$role"
        cp "$REPO_ROOT/plugins/loom/skills/loom-$role/SKILL.md" "$ROOT/skills/loom-$role/SKILL.md"
    done
}

# Hermetic ambient state: no real ~/.codex, agy cache, or agy binary is read.
setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/cache"
    export LOOM_LAUNCH_ROLE_AGY_BIN="$BATS_TEST_TMPDIR/no-agy"
    mkdir -p "$HOME"
}

teardown() {
    if [ -n "${ROOT:-}" ] && [ -d "$ROOT" ]; then rm -rf "$ROOT"; fi
    if [ -n "${STUB_DIR:-}" ] && [ -d "$STUB_DIR" ]; then rm -rf "$STUB_DIR"; fi
    return 0
}

# portable_sed <script> <file> — GNU/BSD-portable in-place-equivalent edit
# (writes to a temp file then replaces; avoids sed -i's incompatible flag
# shape across platforms).
portable_sed() {
    local script="$1" file="$2" tmp
    tmp="$file.tmp.$$"
    sed "$script" "$file" >"$tmp" && mv "$tmp" "$file"
}

# portable_grep_v <pattern> <file> — GNU/BSD-portable line-deletion.
portable_grep_v() {
    local pattern="$1" file="$2" tmp
    tmp="$file.tmp.$$"
    grep -v "$pattern" "$file" >"$tmp" && mv "$tmp" "$file"
}

launch() {
    run "$LOOM_TEST_BASH" "$LAUNCH" "$@"
}

# launch_env VAR=val [VAR=val ...] -- <loom-launch-role args...>
launch_env() {
    local envs=()
    while [ "$1" != "--" ]; do
        envs+=("$1")
        shift
    done
    shift
    run env "${envs[@]}" "$LOOM_TEST_BASH" "$LAUNCH" "$@"
}

# ---------------------------------------------------------------------------
# Positive: Claude, all five roles (all three profiles), real repo tree
# ---------------------------------------------------------------------------

@test "claude: researcher launches on Economy/haiku with no Agent capability" {
    launch claude researcher
    [ "$status" -eq 0 ]
    [[ "$output" == *'"client":"claude"'* ]]
    [[ "$output" == *'"role":"researcher"'* ]]
    [[ "$output" == *'"profile":"Economy"'* ]]
    [[ "$output" == *'"selector":"haiku"'* ]]
    [[ "$output" == *'"agentCapability":false'* ]]
    [[ "$output" == *'"cold":true'* ]]
    [[ "$output" == *'"delegation":false'* ]]
    [[ "$output" == *'"permissions":"one-level"'* ]]
}

@test "claude: developer launches on Standard/sonnet" {
    launch claude developer
    [ "$status" -eq 0 ]
    [[ "$output" == *'"profile":"Standard"'* ]]
    [[ "$output" == *'"selector":"sonnet"'* ]]
}

@test "claude: planner launches on Deep review/opus" {
    launch claude planner
    [ "$status" -eq 0 ]
    [[ "$output" == *'"profile":"Deep review"'* ]]
    [[ "$output" == *'"selector":"opus"'* ]]
}

@test "claude: plan-evaluator launches on Deep review/opus" {
    launch claude plan-evaluator
    [ "$status" -eq 0 ]
    [[ "$output" == *'"profile":"Deep review"'* ]]
    [[ "$output" == *'"selector":"opus"'* ]]
}

@test "claude: code-evaluator launches on Deep review/opus" {
    launch claude code-evaluator
    [ "$status" -eq 0 ]
    [[ "$output" == *'"profile":"Deep review"'* ]]
    [[ "$output" == *'"selector":"opus"'* ]]
}

# ---------------------------------------------------------------------------
# Positive: Codex, all five roles (all three profiles), stubbed child
# ---------------------------------------------------------------------------

@test "codex: researcher launches on Economy/gpt-6.1-terra/low" {
    make_stub
    LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" launch codex researcher
    [ "$status" -eq 0 ]
    [[ "$output" == *'"profile":"Economy"'* ]]
    [[ "$output" == *'"model":"gpt-6.1-terra"'* ]]
    [[ "$output" == *'"effort":"low"'* ]]
    run cat "$RECORD"
    [[ "$output" == *'ACTIVE=1'* ]]
    [[ "$output" == *'ARG:$loom-researcher'* ]]
}

@test "codex: developer launches on Standard/gpt-6.1-terra/medium" {
    make_stub
    LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" launch codex developer
    [ "$status" -eq 0 ]
    [[ "$output" == *'"profile":"Standard"'* ]]
    [[ "$output" == *'"model":"gpt-6.1-terra"'* ]]
    [[ "$output" == *'"effort":"medium"'* ]]
}

@test "codex: planner launches on Deep review/gpt-6.1-sol/high" {
    make_stub
    LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" launch codex planner
    [ "$status" -eq 0 ]
    [[ "$output" == *'"profile":"Deep review"'* ]]
    [[ "$output" == *'"model":"gpt-6.1-sol"'* ]]
    [[ "$output" == *'"effort":"high"'* ]]
}

@test "codex: plan-evaluator launches on Deep review/gpt-6.1-sol/high" {
    make_stub
    LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" launch codex plan-evaluator
    [ "$status" -eq 0 ]
    [[ "$output" == *'"profile":"Deep review"'* ]]
    [[ "$output" == *'"model":"gpt-6.1-sol"'* ]]
    [[ "$output" == *'"effort":"high"'* ]]
}

@test "codex: code-evaluator launches on Deep review/gpt-6.1-sol/high" {
    make_stub
    LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" launch codex code-evaluator
    [ "$status" -eq 0 ]
    [[ "$output" == *'"profile":"Deep review"'* ]]
    [[ "$output" == *'"model":"gpt-6.1-sol"'* ]]
    [[ "$output" == *'"effort":"high"'* ]]
}

# ---------------------------------------------------------------------------
# Codex argv/env contract
# ---------------------------------------------------------------------------

@test "codex: exact argv contract (ephemeral, no user config, strict, no multi-agent, read-only, model/effort, no web search, output schema, canonical contract)" {
    make_stub
    LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" launch codex researcher
    [ "$status" -eq 0 ]
    run cat "$RECORD"
    [[ "$output" == *'ARG:exec'* ]]
    [[ "$output" == *'ARG:--ephemeral'* ]]
    [[ "$output" == *'ARG:--ignore-user-config'* ]]
    [[ "$output" == *'ARG:--strict-config'* ]]
    [[ "$output" == *'ARG:--disable'* ]]
    [[ "$output" == *'ARG:multi_agent'* ]]
    [[ "$output" == *'ARG:--sandbox'* ]]
    [[ "$output" == *'ARG:read-only'* ]]
    [[ "$output" == *'ARG:--model'* ]]
    [[ "$output" == *'ARG:gpt-6.1-terra'* ]]
    [[ "$output" == *'ARG:model_reasoning_effort=low'* ]]
    [[ "$output" == *'ARG:tools.web_search=false'* ]]
    [[ "$output" == *'ARG:--output-schema'* ]]
    [[ "$output" == *'loom-role-launch-v1.schema.json'* ]]
}

@test "codex: the closed bounded-output schema path is a real regular file" {
    make_stub
    LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" launch codex researcher
    [ "$status" -eq 0 ]
    schema_path=$(awk '/ARG:--output-schema/{getline; print}' "$RECORD" | sed 's/^ARG://')
    [ -f "$schema_path" ]
}

@test "codex: never emits a bare --model without an exact matrix value" {
    make_stub
    LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" launch codex researcher
    [ "$status" -eq 0 ]
    run awk '/ARG:--model/{getline; print}' "$RECORD"
    [ "$output" = "ARG:gpt-6.1-terra" ]
}

# ---------------------------------------------------------------------------
# Usage errors (exit 1)
# ---------------------------------------------------------------------------

@test "usage: unknown client fails with usage error" {
    launch bogus researcher
    [ "$status" -eq 1 ]
}

@test "usage: unknown/renamed role fails with usage error" {
    launch claude Researcher
    [ "$status" -eq 1 ]
}

@test "usage: missing arguments fails with usage error" {
    launch claude
    [ "$status" -eq 1 ]
}

@test "usage: no arguments fails with usage error" {
    launch
    [ "$status" -eq 1 ]
}

@test "usage: extra arguments fail with usage error" {
    launch claude researcher extra
    [ "$status" -eq 1 ]
}

@test "usage: never accepts a caller-supplied vendor selector as an argument" {
    launch codex researcher gpt-6.1-terra
    [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# Fail-closed guards (exit 2)
# ---------------------------------------------------------------------------

@test "guard: descendant launch attempt is rejected (LOOM_LAUNCH_ROLE_ACTIVE set)" {
    launch_env LOOM_LAUNCH_ROLE_ACTIVE=1 -- claude researcher
    [ "$status" -eq 2 ]
    [[ "$output" == *"descendant launch attempt"* ]]
}

@test "guard: descendant launch attempt is rejected for codex too" {
    make_stub
    launch_env LOOM_LAUNCH_ROLE_ACTIVE=1 LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" -- codex researcher
    [ "$status" -eq 2 ]
    [ ! -e "$RECORD" ]
}

@test "guard: inherited CODEX_MODEL is rejected" {
    launch_env CODEX_MODEL=hacked -- codex researcher
    [ "$status" -eq 2 ]
    [[ "$output" == *"override vendor model/effort"* ]]
}

@test "guard: inherited MODEL_REASONING_EFFORT is rejected" {
    launch_env MODEL_REASONING_EFFORT=hacked -- codex researcher
    [ "$status" -eq 2 ]
}

@test "guard: inherited OPENAI_MODEL is rejected" {
    launch_env OPENAI_MODEL=hacked -- codex researcher
    [ "$status" -eq 2 ]
}

@test "guard: inherited ANTHROPIC_MODEL is rejected" {
    launch_env ANTHROPIC_MODEL=hacked -- claude researcher
    [ "$status" -eq 2 ]
}

@test "guard: inherited CLAUDE_MODEL is rejected" {
    launch_env CLAUDE_MODEL=hacked -- claude researcher
    [ "$status" -eq 2 ]
}

@test "guard: an enabled delegation feature is rejected" {
    launch_env LOOM_LAUNCH_ROLE_ALLOW_DELEGATION=1 -- codex researcher
    [ "$status" -eq 2 ]
    [[ "$output" == *"delegation feature enabled"* ]]
}

@test "guard: a falsy delegation-feature value does not trip the guard" {
    launch_env LOOM_LAUNCH_ROLE_ALLOW_DELEGATION=0 -- claude researcher
    [ "$status" -eq 0 ]
}

@test "guard: invocation must be by absolute path" {
    run "$LOOM_TEST_BASH" -c 'cd "$1" && exec "$LOOM_TEST_BASH" ./loom-launch-role claude researcher' \
        -- "$BATS_TEST_DIRNAME"
    [ "$status" -eq 2 ]
    [[ "$output" == *"absolute path"* ]]
}

# ---------------------------------------------------------------------------
# Cold IDs
# ---------------------------------------------------------------------------

@test "cold id: two invocations never reuse the same launch id" {
    launch claude researcher
    [ "$status" -eq 0 ]
    id1="$output"
    launch claude researcher
    [ "$status" -eq 0 ]
    id2="$output"
    [ "$id1" != "$id2" ]
}

# ---------------------------------------------------------------------------
# Claude negative paths (fixture)
# ---------------------------------------------------------------------------

@test "claude: missing agent adapter file fails closed" {
    make_root
    rm "$ROOT/agents/researcher.md"
    run "$LOOM_TEST_BASH" "$ROOT/bin/loom-launch-role" claude researcher
    [ "$status" -eq 2 ]
    [[ "$output" == *"agent adapter is missing"* ]]
}

@test "claude: agent adapter missing the model field fails closed" {
    make_root
    portable_grep_v '^model: ' "$ROOT/agents/researcher.md"
    run "$LOOM_TEST_BASH" "$ROOT/bin/loom-launch-role" claude researcher
    [ "$status" -eq 2 ]
    [[ "$output" == *"no model field"* ]]
}

@test "claude: agent adapter missing the tools field fails closed" {
    make_root
    portable_grep_v '^tools: ' "$ROOT/agents/researcher.md"
    run "$LOOM_TEST_BASH" "$ROOT/bin/loom-launch-role" claude researcher
    [ "$status" -eq 2 ]
    [[ "$output" == *"no tools field"* ]]
}

@test "claude: a substituted/renamed model in the agent adapter fails closed" {
    make_root
    portable_sed 's/^model: haiku/model: sonnet/' "$ROOT/agents/researcher.md"
    run "$LOOM_TEST_BASH" "$ROOT/bin/loom-launch-role" claude researcher
    [ "$status" -eq 2 ]
    [[ "$output" == *"does not match the compatibility matrix tier"* ]]
}

@test "claude: an inherited model value fails closed" {
    make_root
    portable_sed 's/^model: haiku/model: inherit/' "$ROOT/agents/researcher.md"
    run "$LOOM_TEST_BASH" "$ROOT/bin/loom-launch-role" claude researcher
    [ "$status" -eq 2 ]
}

@test "claude: an Agent capability grant in the tools field fails closed (delegation)" {
    make_root
    portable_sed 's/^tools: .*/tools: Read, Grep, Glob, Agent/' "$ROOT/agents/researcher.md"
    run "$LOOM_TEST_BASH" "$ROOT/bin/loom-launch-role" claude researcher
    [ "$status" -eq 2 ]
    [[ "$output" == *"forbidden Agent capability"* ]]
}

# RED-GREEN sentinel: the same fixture is accepted before the tamper and
# rejected after, proving the model-mismatch guard actually distinguishes.
@test "RED-GREEN: agent-adapter model tampering flips a valid fixture from accept to reject" {
    make_root
    run "$LOOM_TEST_BASH" "$ROOT/bin/loom-launch-role" claude researcher
    [ "$status" -eq 0 ]
    portable_sed 's/^model: haiku/model: sonnet/' "$ROOT/agents/researcher.md"
    run "$LOOM_TEST_BASH" "$ROOT/bin/loom-launch-role" claude researcher
    [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# Codex negative paths (fixture)
# ---------------------------------------------------------------------------

@test "codex: missing compatibility matrix fails closed" {
    make_root
    make_stub
    rm "$ROOT/adapters/compatibility/v0.3.0.json"
    run env LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" "$LOOM_TEST_BASH" "$ROOT/bin/loom-launch-role" codex researcher
    [ "$status" -eq 2 ]
    [[ "$output" == *"compatibility matrix is missing"* ]]
}

@test "codex: wrong matrix schema identity fails closed" {
    make_root
    make_stub
    tmp="$ROOT/adapters/compatibility/v0.3.0.json.tmp"
    jq '.schema = "bogus"' "$ROOT/adapters/compatibility/v0.3.0.json" >"$tmp" && mv "$tmp" "$ROOT/adapters/compatibility/v0.3.0.json"
    run env LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" "$LOOM_TEST_BASH" "$ROOT/bin/loom-launch-role" codex researcher
    [ "$status" -eq 2 ]
    [[ "$output" == *"schema mismatch"* ]]
}

@test "codex: wrong matrix version fails closed" {
    make_root
    make_stub
    tmp="$ROOT/adapters/compatibility/v0.3.0.json.tmp"
    jq '.version = "9.9.9"' "$ROOT/adapters/compatibility/v0.3.0.json" >"$tmp" && mv "$tmp" "$ROOT/adapters/compatibility/v0.3.0.json"
    run env LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" "$LOOM_TEST_BASH" "$ROOT/bin/loom-launch-role" codex researcher
    [ "$status" -eq 2 ]
    [[ "$output" == *"version mismatch"* ]]
}

@test "codex: a role absent from every profile's consumers fails closed (role/profile drift)" {
    make_root
    make_stub
    tmp="$ROOT/adapters/compatibility/v0.3.0.json.tmp"
    jq '(.profiles[] | select(.profile=="Economy") | .consumers) = []' "$ROOT/adapters/compatibility/v0.3.0.json" >"$tmp" && mv "$tmp" "$ROOT/adapters/compatibility/v0.3.0.json"
    run env LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" "$LOOM_TEST_BASH" "$ROOT/bin/loom-launch-role" codex researcher
    [ "$status" -eq 2 ]
    [[ "$output" == *"no profile mapped for role"* ]]
}

@test "codex: a missing model for the resolved profile fails closed (unavailable model)" {
    make_root
    make_stub
    tmp="$ROOT/adapters/compatibility/v0.3.0.json.tmp"
    jq '(.profiles[] | select(.profile=="Economy") | .codex) |= del(.model)' "$ROOT/adapters/compatibility/v0.3.0.json" >"$tmp" && mv "$tmp" "$ROOT/adapters/compatibility/v0.3.0.json"
    run env LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" "$LOOM_TEST_BASH" "$ROOT/bin/loom-launch-role" codex researcher
    [ "$status" -eq 2 ]
    [[ "$output" == *"no Codex model mapped"* ]]
}

@test "codex: a missing effort for the resolved profile fails closed (unavailable effort)" {
    make_root
    make_stub
    tmp="$ROOT/adapters/compatibility/v0.3.0.json.tmp"
    jq '(.profiles[] | select(.profile=="Economy") | .codex) |= del(.effort)' "$ROOT/adapters/compatibility/v0.3.0.json" >"$tmp" && mv "$tmp" "$ROOT/adapters/compatibility/v0.3.0.json"
    run env LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" "$LOOM_TEST_BASH" "$ROOT/bin/loom-launch-role" codex researcher
    [ "$status" -eq 2 ]
    [[ "$output" == *"no Codex effort mapped"* ]]
}

@test "codex: a substituted model for the resolved profile is used verbatim and validated only by enumeration in the schema" {
    make_root
    make_stub
    tmp="$ROOT/adapters/compatibility/v0.3.0.json.tmp"
    jq '(.profiles[] | select(.profile=="Economy") | .codex.model) = "renamed-model"' "$ROOT/adapters/compatibility/v0.3.0.json" >"$tmp" && mv "$tmp" "$ROOT/adapters/compatibility/v0.3.0.json"
    run env LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" "$LOOM_TEST_BASH" "$ROOT/bin/loom-launch-role" codex researcher
    [ "$status" -eq 0 ]
    [[ "$output" == *'"model":"renamed-model"'* ]]
}

@test "codex: missing role skill (undefined canonical contract) fails closed" {
    make_root
    make_stub
    rm "$ROOT/skills/loom-researcher/SKILL.md"
    run env LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" "$LOOM_TEST_BASH" "$ROOT/bin/loom-launch-role" codex researcher
    [ "$status" -eq 2 ]
    [[ "$output" == *"codex role skill is missing"* ]]
}

@test "codex: missing closed bounded-output schema fails closed (unbounded output)" {
    make_root
    make_stub
    rm "$ROOT/schemas/loom-role-launch-v1.schema.json"
    run env LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" "$LOOM_TEST_BASH" "$ROOT/bin/loom-launch-role" codex researcher
    [ "$status" -eq 2 ]
    [[ "$output" == *"closed bounded-output schema is missing"* ]]
    [ ! -e "$RECORD" ]
}

# RED-GREEN sentinel: the same fixture is accepted before the tamper and
# rejected after, proving the matrix-schema guard actually distinguishes.
@test "RED-GREEN: matrix schema tampering flips a valid codex fixture from accept to reject" {
    make_root
    make_stub
    run env LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" "$LOOM_TEST_BASH" "$ROOT/bin/loom-launch-role" codex researcher
    [ "$status" -eq 0 ]
    tmp="$ROOT/adapters/compatibility/v0.3.0.json.tmp"
    jq '.schema = "bogus"' "$ROOT/adapters/compatibility/v0.3.0.json" >"$tmp" && mv "$tmp" "$ROOT/adapters/compatibility/v0.3.0.json"
    run env LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" "$LOOM_TEST_BASH" "$ROOT/bin/loom-launch-role" codex researcher
    [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# No forbidden environment-only root/vendor guesses
# ---------------------------------------------------------------------------

@test "static: never reads CLAUDE_PLUGIN_ROOT/PLUGIN_ROOT/CODEX_HOME for root or vendor resolution" {
    run grep -Eo '\$\{?(CLAUDE_PLUGIN_ROOT|PLUGIN_ROOT|CODEX_HOME)\b' "$LAUNCH"
    [ "$status" -ne 0 ]
}

@test "codex: never consults CLAUDE_PLUGIN_ROOT/PLUGIN_ROOT/CODEX_HOME even when set" {
    make_stub
    run env CLAUDE_PLUGIN_ROOT=/nonexistent PLUGIN_ROOT=/nonexistent CODEX_HOME=/nonexistent \
        LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" "$LOOM_TEST_BASH" "$LAUNCH" codex researcher
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Working-directory independence
# ---------------------------------------------------------------------------

@test "claude: launch is independent of the caller's working directory" {
    run "$LOOM_TEST_BASH" -c 'cd /tmp && exec "$1" claude researcher' -- "$LAUNCH"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"role":"researcher"'* ]]
}

@test "codex: launch is independent of the caller's working directory" {
    make_stub
    run env LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" "$LOOM_TEST_BASH" -c 'cd /tmp && exec "$1" codex researcher' -- "$LAUNCH"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"role":"researcher"'* ]]
}

# ---------------------------------------------------------------------------
# Antigravity positive & negative paths
# ---------------------------------------------------------------------------

@test "antigravity: researcher launches on Economy/flash with subagent tools disabled" {
    launch antigravity researcher
    [ "$status" -eq 0 ]
    [[ "$output" == *'"client":"antigravity"'* ]]
    [[ "$output" == *'"role":"researcher"'* ]]
    [[ "$output" == *'"profile":"Economy"'* ]]
    [[ "$output" == *'"model":"flash"'* ]]
    [[ "$output" == *'"enableSubagentTools":false'* ]]
    [[ "$output" == *'"cold":true'* ]]
    [[ "$output" == *'"delegation":false'* ]]
}

@test "antigravity: developer launches on Standard/inherit" {
    launch antigravity developer
    [ "$status" -eq 0 ]
    [[ "$output" == *'"profile":"Standard"'* ]]
    [[ "$output" == *'"model":"inherit"'* ]]
}

@test "antigravity: planner, plan-evaluator, and code-evaluator launch on Deep review/pro" {
    for role in planner plan-evaluator code-evaluator; do
        launch antigravity "$role"
        [ "$status" -eq 0 ]
        [[ "$output" == *'"profile":"Deep review"'* ]]
        [[ "$output" == *'"model":"pro"'* ]]
    done
}

@test "antigravity: missing canonical role contract fails closed" {
    make_root
    rm "$ROOT/roles/researcher.md"
    run "$LOOM_TEST_BASH" "$ROOT/bin/loom-launch-role" antigravity researcher
    [ "$status" -eq 2 ]
    [[ "$output" == *"canonical role contract is missing"* ]]
}

# ---------------------------------------------------------------------------
# Herdr retired (ADR 0031 §7): herdr is not a launchable client or author client
# ---------------------------------------------------------------------------

@test "herdr: retired client is a usage error; --author-client herdr is rejected" {
    launch herdr researcher
    [ "$status" -eq 1 ]
    launch claude plan-evaluator --author-client herdr
    [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# Cross-family evaluation guards & multi-client routing
# ---------------------------------------------------------------------------

@test "cross-family: --author-client same-family rejection on plan-evaluator and code-evaluator" {
    launch claude plan-evaluator --author-client claude
    [ "$status" -eq 2 ]
    [[ "$output" == *"cross-family evaluation violation: plan-evaluator client (claude) matches author client (claude)"* ]]

    make_stub
    LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" launch codex code-evaluator --author-client codex
    [ "$status" -eq 2 ]
    [[ "$output" == *"cross-family evaluation violation: code-evaluator client (codex) matches author client (codex)"* ]]
    [ ! -e "$RECORD" ]

    launch antigravity plan-evaluator --author-client antigravity
    [ "$status" -eq 2 ]
    [[ "$output" == *"cross-family evaluation violation: plan-evaluator client (antigravity) matches author client (antigravity)"* ]]
}

@test "cross-family: --author-client cross-family acceptance emits authorClient and crossFamilyVerified" {
    make_stub
    LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" launch codex plan-evaluator --author-client claude
    [ "$status" -eq 0 ]
    [[ "$output" == *'"client":"codex"'* ]]
    [[ "$output" == *'"role":"plan-evaluator"'* ]]
    [[ "$output" == *'"authorClient":"claude"'* ]]
    [[ "$output" == *'"crossFamilyVerified":true'* ]]

    launch claude code-evaluator --author-client codex
    [ "$status" -eq 0 ]
    [[ "$output" == *'"client":"claude"'* ]]
    [[ "$output" == *'"role":"code-evaluator"'* ]]
    [[ "$output" == *'"authorClient":"codex"'* ]]
    [[ "$output" == *'"crossFamilyVerified":true'* ]]
}

@test "cross-family: LOOM_REQUIRE_CROSS_FAMILY_EVAL=1 without author client fails closed" {
    launch_env LOOM_REQUIRE_CROSS_FAMILY_EVAL=1 -- claude plan-evaluator
    [ "$status" -eq 2 ]
    [[ "$output" == *"cross-family evaluation required but no author client was supplied"* ]]

    launch_env LOOM_REQUIRE_CROSS_FAMILY_EVAL=1 -- antigravity code-evaluator
    [ "$status" -eq 2 ]
    [[ "$output" == *"cross-family evaluation required but no author client was supplied"* ]]
}

@test "cross-family: auto client deterministically routes claude->codex->antigravity->claude" {
    make_stub
    LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" launch auto plan-evaluator --author-client claude
    [ "$status" -eq 0 ]
    [[ "$output" == *'"client":"codex"'* ]]
    [[ "$output" == *'"authorClient":"claude"'* ]]
    [[ "$output" == *'"crossFamilyVerified":true'* ]]

    launch auto plan-evaluator --author-client codex
    [ "$status" -eq 0 ]
    [[ "$output" == *'"client":"antigravity"'* ]]
    [[ "$output" == *'"authorClient":"codex"'* ]]
    [[ "$output" == *'"crossFamilyVerified":true'* ]]

    launch auto code-evaluator --author-client antigravity
    [ "$status" -eq 0 ]
    [[ "$output" == *'"client":"claude"'* ]]
    [[ "$output" == *'"authorClient":"antigravity"'* ]]
    [[ "$output" == *'"crossFamilyVerified":true'* ]]

    launch auto plan-evaluator
    [ "$status" -eq 2 ]
    [[ "$output" == *"cross-family evaluation required but no author client was supplied"* ]]
}

@test "cross-family: --routing-file positive routing and same-family rejection under requireCrossFamilyEval" {
    make_root
    make_stub
    local routing_ok="$ROOT/routing-ok.json"
    cat >"$routing_ok" <<'EOF'
{
  "schema": "loom-role-routing/v1",
  "requireCrossFamilyEval": true,
  "routes": {
    "researcher": "antigravity",
    "planner": "claude",
    "plan-evaluator": "codex",
    "developer": "claude",
    "code-evaluator": "codex"
  }
}
EOF
    run "$LOOM_TEST_BASH" "$ROOT/bin/loom-launch-role" auto researcher --routing-file "$routing_ok"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"client":"antigravity"'* ]]
    [[ "$output" == *'"role":"researcher"'* ]]

    run env LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" "$LOOM_TEST_BASH" "$ROOT/bin/loom-launch-role" auto plan-evaluator --routing-file "$routing_ok"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"client":"codex"'* ]]
    [[ "$output" == *'"authorClient":"claude"'* ]]
    [[ "$output" == *'"crossFamilyVerified":true'* ]]

    local routing_bad_plan="$ROOT/routing-bad-plan.json"
    jq '.routes["plan-evaluator"] = "claude"' "$routing_ok" >"$routing_bad_plan"
    run "$LOOM_TEST_BASH" "$ROOT/bin/loom-launch-role" auto plan-evaluator --routing-file "$routing_bad_plan"
    [ "$status" -eq 2 ]
    [[ "$output" == *"cross-family evaluation violation: plan-evaluator client (claude) matches author client (claude)"* ]]

    local routing_bad_code="$ROOT/routing-bad-code.json"
    jq '.routes["developer"] = "codex" | .routes["code-evaluator"] = "codex"' "$routing_ok" >"$routing_bad_code"
    run env LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" "$LOOM_TEST_BASH" "$ROOT/bin/loom-launch-role" auto code-evaluator --routing-file "$routing_bad_code"
    [ "$status" -eq 2 ]
    [[ "$output" == *"cross-family evaluation violation: code-evaluator client (codex) matches author client (codex)"* ]]
}

# ---------------------------------------------------------------------------
# Model/effort resolution (ADR 0027): flags > repo config > ambient > matrix
# ---------------------------------------------------------------------------

write_codex_config() {
    mkdir -p "$HOME/.codex"
    printf '%s\n' "$@" >"$HOME/.codex/config.toml"
}

# write_agy_cache <fetchedAt> <model...> — owner-only cache, as the launcher writes it.
write_agy_cache() {
    local at="$1"
    shift
    mkdir -p "$XDG_CACHE_HOME/loom"
    printf '%s\n' "$@" | jq -Rn --argjson t "$at" '{fetchedAt: $t, models: [inputs | select(length > 0)]}' >"$XDG_CACHE_HOME/loom/agy-models.json"
    chmod 600 "$XDG_CACHE_HOME/loom/agy-models.json"
}

make_agy_stub() {
    make_stub
    AGY_STUB="$STUB_DIR/agy-stub"
    printf '#!/usr/bin/env bash\nprintf "Fetching available models...\\n"\nprintf "claude-opus-5-5-high\\tClaude Opus 5.5 (High)\\n"\nprintf "claude-opus-5-5-low\\tClaude Opus 5.5 (Low)\\n"\nprintf "gemini-3.8-flash-low\\tFlash (Low)\\n"\n' >"$AGY_STUB"
    chmod +x "$AGY_STUB"
}

@test "model: codex inherits an ambient gpt-6.1 model from config.toml" {
    make_stub
    write_codex_config '# user config' 'model = "gpt-6.1-sol"  # pinned' 'model_reasoning_effort = "low"' '[profiles.x]' 'model = "bogus"'
    LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" launch codex researcher
    [ "$status" -eq 0 ]
    [[ "$output" == *'"model":"gpt-6.1-sol"'* ]]
    [[ "$output" == *'"effort":"low"'* ]]
}

@test "model: --model and --effort override ambient config and are emitted" {
    make_stub
    write_codex_config 'model = "gpt-6.1-sol"'
    LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" launch codex planner --model gpt-6.1-terra --effort low
    [ "$status" -eq 0 ]
    [[ "$output" == *'"model":"gpt-6.1-terra"'* ]]
    [[ "$output" == *'"effort":"low"'* ]]
    run cat "$RECORD"
    [[ "$output" == *'ARG:model_reasoning_effort=low'* ]]
}

@test "model: repo config outranks ambient config; flags outrank repo config" {
    make_stub
    write_codex_config 'model = "gpt-6.1-sol"'
    mkdir -p "$BATS_TEST_TMPDIR/proj/.docs"
    printf '{"codex":{"model":"gpt-6.1-terra","effort":"medium"}}' >"$BATS_TEST_TMPDIR/proj/.docs/loom-models.json"
    cd "$BATS_TEST_TMPDIR/proj"
    LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" launch codex planner
    [ "$status" -eq 0 ]
    [[ "$output" == *'"model":"gpt-6.1-terra"'* ]]
    [[ "$output" == *'"effort":"medium"'* ]]
    LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" launch codex planner --model gpt-6.1-sol --effort high
    [[ "$output" == *'"model":"gpt-6.1-sol"'* ]]
    [[ "$output" == *'"effort":"high"'* ]]
}

@test "model: corrupt or invalid repo config fails closed" {
    mkdir -p "$BATS_TEST_TMPDIR/proj/.docs"
    cd "$BATS_TEST_TMPDIR/proj"
    printf '{not json' >.docs/loom-models.json
    launch codex planner
    [ "$status" -eq 2 ]
    printf '{"codex":{"model":"bad@model"}}' >.docs/loom-models.json
    launch codex planner
    [ "$status" -eq 2 ]
}

# validate_launch <json-file> — real JSON Schema (draft 2020-12) validation via the pinned ajv.
validate_launch() {
    node --input-type=module -e '
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
const require = createRequire(process.argv[1] + "/scripts/");
const Ajv2020 = require("ajv/dist/2020.js");
const ajv = new Ajv2020({ strict: true, allowUnionTypes: true });
const schema = JSON.parse(readFileSync(process.argv[1] + "/plugins/loom/schemas/loom-role-launch-v1.schema.json", "utf8"));
const doc = JSON.parse(readFileSync(process.argv[2], "utf8"));
const ok = ajv.compile(schema)(doc);
process.exit(ok ? 0 : 1);
' "$REPO_ROOT" "$1"
}

@test "model: emitted codex, antigravity, and cross-family launches validate against the launch schema" {
    make_stub
    LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" launch codex planner --model gpt-6.1-sol
    [ "$status" -eq 0 ]
    printf '%s' "${lines[0]}" >"$BATS_TEST_TMPDIR/codex.json"
    validate_launch "$BATS_TEST_TMPDIR/codex.json"
    launch antigravity planner
    [ "$status" -eq 0 ]
    printf '%s' "${lines[0]}" >"$BATS_TEST_TMPDIR/agy.json"
    validate_launch "$BATS_TEST_TMPDIR/agy.json"
    launch antigravity code-evaluator --author-client claude
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == *'"crossFamilyVerified":true'* ]]
    printf '%s' "${lines[0]}" >"$BATS_TEST_TMPDIR/agy-cross.json"
    validate_launch "$BATS_TEST_TMPDIR/agy-cross.json"
    LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" launch codex plan-evaluator --author-client claude
    printf '%s' "${lines[0]}" >"$BATS_TEST_TMPDIR/codex-cross.json"
    validate_launch "$BATS_TEST_TMPDIR/codex-cross.json"
    launch claude code-evaluator --author-client codex
    printf '%s' "${lines[0]}" >"$BATS_TEST_TMPDIR/claude-cross.json"
    validate_launch "$BATS_TEST_TMPDIR/claude-cross.json"
    # the validator rejects unknown fields (so a pass above is meaningful)
    jq '. + {bogus: 1}' "$BATS_TEST_TMPDIR/agy-cross.json" >"$BATS_TEST_TMPDIR/bad.json"
    run validate_launch "$BATS_TEST_TMPDIR/bad.json"
    [ "$status" -ne 0 ]
}

@test "model: ambient model_reasoning_effort differing from the profile default is honored" {
    make_stub
    write_codex_config 'model_reasoning_effort = "low"'
    LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" launch codex planner
    [ "$status" -eq 0 ]
    [[ "$output" == *'"effort":"low"'* ]]
    run cat "$RECORD"
    [[ "$output" == *'ARG:model_reasoning_effort=low'* ]]
}

@test "model: invalid ambient model_reasoning_effort fails closed" {
    make_stub
    write_codex_config 'model_reasoning_effort = "xhigh"'
    LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" launch codex planner
    [ "$status" -eq 2 ]
}

@test "model: explicit empty --model fails closed" {
    make_stub
    LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" launch codex planner --model ''
    [ "$status" -eq 2 ]
    launch antigravity developer --model ''
    [ "$status" -eq 2 ]
}

@test "model: explicit empty --effort fails closed" {
    make_stub
    LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" launch codex planner --effort ''
    [ "$status" -eq 2 ]
}

@test "model: antigravity maps Deep review to the cached opus high variant" {
    write_agy_cache "$(date +%s)" claude-opus-5-5-low claude-opus-5-5-high gemini-3.8-flash-high
    launch antigravity planner
    [ "$status" -eq 0 ]
    [[ "$output" == *'"model":"claude-opus-5-5-high"'* ]]
    launch antigravity planner --effort low
    [[ "$output" == *'"model":"claude-opus-5-5-low"'* ]]
}

@test "model: antigravity explicit --model is used verbatim; empty or malformed fails closed" {
    write_agy_cache "$(date +%s)" claude-opus-5-5-high
    launch antigravity planner --model custom-model.1
    [ "$status" -eq 0 ]
    [[ "$output" == *'"model":"custom-model.1"'* ]]
    launch antigravity planner --model ""
    [ "$status" -eq 2 ]
    launch antigravity planner --model 'bad"model'
    [ "$status" -eq 2 ]
}

@test "model: stale cache triggers discovery and an atomic owner-only rewrite" {
    make_agy_stub
    write_agy_cache "$(($(date +%s) - 90000))" old-model-high
    LOOM_LAUNCH_ROLE_AGY_BIN="$AGY_STUB" launch antigravity planner
    [ "$status" -eq 0 ]
    [[ "$output" == *'"model":"claude-opus-5-5-high"'* ]]
    f="$XDG_CACHE_HOME/loom/agy-models.json"
    [ "$(ls -l "$f" | cut -c1-10)" = "-rw-------" ]
    jq -e '.models | index("claude-opus-5-5-high")' "$f"
    [ "$(find "$XDG_CACHE_HOME/loom" -type f | wc -l | tr -d ' ')" = "1" ]
}

@test "model: fresh cache is used without invoking agy" {
    make_agy_stub
    write_agy_cache "$(date +%s)" claude-opus-5-5-high
    printf '#!/usr/bin/env bash\nexit 1\n' >"$AGY_STUB"
    LOOM_LAUNCH_ROLE_AGY_BIN="$AGY_STUB" launch antigravity planner
    [ "$status" -eq 0 ]
    [[ "$output" == *'"model":"claude-opus-5-5-high"'* ]]
}

@test "model: missing, corrupted, or group-readable agy cache with no agy falls back to profile floors" {
    launch antigravity planner
    [[ "$output" == *'"model":"pro"'* ]]
    mkdir -p "$XDG_CACHE_HOME/loom"
    printf 'garbage' >"$XDG_CACHE_HOME/loom/agy-models.json"
    chmod 600 "$XDG_CACHE_HOME/loom/agy-models.json"
    launch antigravity researcher
    [ "$status" -eq 0 ]
    [[ "$output" == *'"model":"flash"'* ]]
    write_agy_cache "$(date +%s)" claude-opus-5-5-high
    chmod 644 "$XDG_CACHE_HOME/loom/agy-models.json"
    launch antigravity planner
    [[ "$output" == *'"model":"pro"'* ]]
}

@test "model: claude --model selects a tier selector; other values fail closed" {
    launch claude researcher --model haiku
    [ "$status" -eq 0 ]
    [[ "$output" == *'"selector":"haiku"'* ]]
    launch claude researcher --model gpt-6.1-sol
    [ "$status" -eq 2 ]
}

@test "model: invalid --effort fails closed" {
    launch claude researcher --effort foo
    [ "$status" -eq 2 ]
    make_stub
    LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" launch codex researcher --effort foo
    [ "$status" -eq 2 ]
    [ ! -e "$RECORD" ]
}

@test "model: invalid --model for codex fails closed" {
    make_stub
    LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" launch codex researcher --model invalid@model
    [ "$status" -eq 2 ]
    LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" launch codex researcher --model gpt-4o
    [ "$status" -eq 2 ]
    [ ! -e "$RECORD" ]
}

@test "model: unsupported or malformed ambient codex model fails closed" {
    make_stub
    write_codex_config 'model = "gpt-4o"'
    LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" launch codex researcher
    [ "$status" -eq 2 ]
    write_codex_config 'model = gpt-6.1-sol'
    LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" launch codex researcher
    [ "$status" -eq 2 ]
    [ ! -e "$RECORD" ]
}

@test "model: cross-family evaluation is still enforced with overrides" {
    launch codex code-evaluator --author-client codex --model gpt-6.1-sol
    [ "$status" -eq 2 ]
    [[ "$output" == *"cross-family evaluation violation"* ]]
}
