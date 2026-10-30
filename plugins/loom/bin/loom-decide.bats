#!/usr/bin/env bats
# Test suite for loom-decide (deterministic SystemOne / Jev decision-model
# helper, state skeleton pre-compression, and fail-closed decision gates).
bats_require_minimum_version 1.5.0

DECIDE="${BATS_TEST_DIRNAME}/loom-decide"

setup_file() {
    : "${LOOM_TEST_BASH:?LOOM_TEST_BASH is required}"
    : "${LOOM_EXPECTED_BASH_VERSION:?LOOM_EXPECTED_BASH_VERSION is required}"
    case "$LOOM_TEST_BASH" in /*) ;; *) return 1 ;; esac
    [ -x "$LOOM_TEST_BASH" ]
    [[ "$($LOOM_TEST_BASH -c 'printf %s "$BASH_VERSION"')" =~ $LOOM_EXPECTED_BASH_VERSION ]]
}

setup() {
    WORK="$(mktemp -d)"
    WORK="$(CDPATH='' cd -- "$WORK" && pwd -P)"
    PLAN="$WORK/slice-plan.md"
    DIFF="$WORK/slice.diff"
    ATTEMPTS="$WORK/attempts.jsonl"
    CURL_STUB="$WORK/curl-stub"
    CURL_LOG="$WORK/curl-args.log"

    # Build a prose-heavy markdown document (~5 KB of narrative prose + concise
    # structured sections) to verify >80% deterministic skeleton compression.
    {
        printf -- '---\nid: test-slice\nstatus: approved\n---\n# Test Slice\n\n## Context and narrative background\n\n'
        local i
        for i in $(seq 1 60); do
            printf 'Paragraph %d: This is extensive architectural prose explaining historical context, prior art, and verbose background discussion that is useful for human readers but redundant for a structured decision model.\n\n' "$i"
        done
        printf '## Acceptance criteria\n\n- [ ] Gate passes with 0 errors\n- [ ] Skeleton compression achieves >= 80%% reduction\n\n'
        printf '## Long narrative rationale\n\n'
        for i in $(seq 1 40); do
            printf 'More verbose rationale line %d discussing hypothetical alternatives that were not selected.\n' "$i"
        done
        printf '\n## Files to touch\n\n- `plugins/loom/bin/loom-decide`\n\n## Verification\n\n- `bats plugins/loom/bin/loom-decide.bats`\n'
    } >"$PLAN"

    printf -- '--- a/plugins/loom/bin/loom-decide\n+++ b/plugins/loom/bin/loom-decide\n@@ -1,0 +1,2 @@\n+#!/usr/bin/env bash\n+set -u\n' >"$DIFF"

    printf '{"attempt":1,"gate_exit":2,"summary":"failed test"}\n{"attempt":2,"gate_exit":2,"summary":"failed same test"}\n' >"$ATTEMPTS"

    cat >"$CURL_STUB" <<EOF
#!/usr/bin/env bash
set -u
printf '%s\n' "\$@" >"$CURL_LOG"
printf '%s\n' "\${MOCK_SYSTEMONE_RESPONSE:-}"
EOF
    chmod +x "$CURL_STUB"
}

teardown() {
    if [ -n "${WORK:-}" ] && [ -d "$WORK" ]; then
        rm -rf "$WORK"
    fi
    return 0
}

decide() {
    run "$LOOM_TEST_BASH" "$DECIDE" "$@"
}

decide_env() {
    local envs=()
    while [ "$1" != "--" ]; do
        envs+=("$1")
        shift
    done
    shift
    run env "${envs[@]}" "$LOOM_TEST_BASH" "$DECIDE" "$@"
}

# ---------------------------------------------------------------------------
# Entrypoint & usage checks
# ---------------------------------------------------------------------------

@test "invocation: relative path is rejected fail-closed (exit 2)" {
    run "$LOOM_TEST_BASH" -c "cd '$BATS_TEST_DIRNAME' && ./loom-decide skeleton-doc '$PLAN'"
    [ "$status" -eq 2 ]
    [[ "$output" == *"must be invoked by absolute path"* ]]
}

@test "usage: missing subcommand exits 1" {
    decide
    [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# Deterministic Pre-Compression: skeleton-doc & skeleton-diff
# ---------------------------------------------------------------------------

@test "skeleton-doc: deterministically strips narrative prose with >= 80% size reduction" {
    decide skeleton-doc "$PLAN"
    [ "$status" -eq 0 ]
    [[ "$output" == *"id: test-slice"* ]]
    [[ "$output" == *"## Acceptance criteria"* ]]
    [[ "$output" == *"## Files to touch"* ]]
    [[ "$output" == *"## Verification"* ]]
    [[ "$output" != *"Paragraph 1:"* ]]
    [[ "$output" != *"More verbose rationale"* ]]

    local raw_bytes skel_bytes
    raw_bytes=$(wc -c <"$PLAN" | tr -d ' ')
    skel_bytes=${#output}
    # Verify >= 80% reduction (skel_bytes * 5 <= raw_bytes)
    [ $((skel_bytes * 5)) -le "$raw_bytes" ]
}

@test "skeleton-diff: extracts git diff --stat and -U0 from a git repo" {
    local repo="$WORK/repo"
    mkdir -p "$repo"
    git -C "$repo" init -q
    git -C "$repo" config user.email "test@example.com"
    git -C "$repo" config user.name "Test"
    seq 1 50 >"$repo/file.txt"
    git -C "$repo" add file.txt
    git -C "$repo" commit -q -m "initial"
    sed -i.bak 's/^25$/25-modified/' "$repo/file.txt"
    rm -f "$repo/file.txt.bak"

    decide skeleton-diff "$repo" HEAD
    [ "$status" -eq 0 ]
    [[ "$output" == *"### git diff --stat (HEAD)"* ]]
    [[ "$output" == *"### git diff -U0 (HEAD)"* ]]
    [[ "$output" == *"-25"* ]]
    [[ "$output" == *"+25-modified"* ]]
    # Unchanged context lines like 10 or 40 must not appear in -U0 diff
    [[ "$output" != *$'\n 10\n'* ]]
}

# ---------------------------------------------------------------------------
# Opt-in / Disabled mode
# ---------------------------------------------------------------------------

@test "disabled mode: default LOOM_SYSTEMONE_ENABLED=0 skips cleanly (exit 0)" {
    decide_env LOOM_SYSTEMONE_ENABLED=0 -- eval-audit --plan "$PLAN" --diff "$DIFF"
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | jq -r '.status')" = "skipped" ]
    [ "$(printf '%s' "$output" | jq -r '.reason')" = "systemone_disabled" ]
}

@test "disabled mode: --require fails closed when disabled (exit 2)" {
    decide_env LOOM_SYSTEMONE_ENABLED=0 -- eval-audit --plan "$PLAN" --diff "$DIFF" --require
    [ "$status" -eq 2 ]
    [[ "$output" == *'"status":"fail"'* ]]
}

# ---------------------------------------------------------------------------
# eval-audit gate
# ---------------------------------------------------------------------------

@test "eval-audit: passes when scope_creep, unproven_acceptance_criteria, and defect_severity are within thresholds" {
    local mock_resp='{"id":"sys1_test","model":"jev-latest","results":{"scope_creep":{"noul":0.05,"confidence":0.94},"unproven_acceptance_criteria":{"noul":0.08,"confidence":0.91},"defect_severity":{"score":0.2,"confidence":0.89,"probabilities":[0.82,0.16,0.02,0.0]}}}'
    decide_env \
        LOOM_SYSTEMONE_ENABLED=1 \
        LOOM_SYSTEMONE_API_KEY="ts-test-key" \
        LOOM_DECIDE_CURL_BIN="$CURL_STUB" \
        MOCK_SYSTEMONE_RESPONSE="$mock_resp" \
        -- eval-audit --plan "$PLAN" --diff "$DIFF"
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | jq -r '.status')" = "pass" ]
    [ "$(printf '%s' "$output" | jq -r '.gate')" = "eval-audit" ]
}

@test "eval-audit: fails closed (exit 2) when scope_creep.noul >= 0.70" {
    local mock_resp='{"results":{"scope_creep":{"noul":0.85,"confidence":0.92},"unproven_acceptance_criteria":{"noul":0.10,"confidence":0.90},"defect_severity":{"score":0.5,"confidence":0.88}}}'
    decide_env \
        LOOM_SYSTEMONE_ENABLED=1 \
        LOOM_SYSTEMONE_API_KEY="ts-test-key" \
        LOOM_DECIDE_CURL_BIN="$CURL_STUB" \
        MOCK_SYSTEMONE_RESPONSE="$mock_resp" \
        -- eval-audit --plan "$PLAN" --diff "$DIFF"
    [ "$status" -eq 2 ]
    [ "$(printf '%s' "$output" | jq -r '.status')" = "fail" ]
    [ "$(printf '%s' "$output" | jq -r '.reasons[0]')" = "scope_creep_exceeded" ]
}

@test "eval-audit: fails closed (exit 2) when defect_severity.score >= 2.0 or confidence < 0.70" {
    local mock_resp='{"results":{"scope_creep":{"noul":0.10,"confidence":0.92},"unproven_acceptance_criteria":{"noul":0.10,"confidence":0.90},"defect_severity":{"score":2.4,"confidence":0.50}}}'
    decide_env \
        LOOM_SYSTEMONE_ENABLED=1 \
        LOOM_SYSTEMONE_API_KEY="ts-test-key" \
        LOOM_DECIDE_CURL_BIN="$CURL_STUB" \
        MOCK_SYSTEMONE_RESPONSE="$mock_resp" \
        -- eval-audit --plan "$PLAN" --diff "$DIFF"
    [ "$status" -eq 2 ]
    [[ "$(printf '%s' "$output" | jq -c '.reasons')" == *'"defect_severity_exceeded"'* ]]
    [[ "$(printf '%s' "$output" | jq -c '.reasons')" == *'"low_confidence"'* ]]
}

@test "eval-audit: payload > LOOM_SYSTEMONE_MAX_BYTES triggers skeleton compression and long-context header" {
    local mock_resp='{"results":{"scope_creep":{"noul":0.05,"confidence":0.94},"unproven_acceptance_criteria":{"noul":0.08,"confidence":0.91},"defect_severity":{"score":0.1,"confidence":0.90}}}'
    decide_env \
        LOOM_SYSTEMONE_ENABLED=1 \
        LOOM_SYSTEMONE_MAX_BYTES=128 \
        LOOM_SYSTEMONE_API_KEY="ts-test-key" \
        LOOM_DECIDE_CURL_BIN="$CURL_STUB" \
        MOCK_SYSTEMONE_RESPONSE="$mock_resp" \
        -- eval-audit --plan "$PLAN" --diff "$DIFF"
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | jq -r '.compressed')" = "true" ]
    [ "$(printf '%s' "$output" | jq -r '.long_context')" = "true" ]
    grep -q "TypeSafe-Danger-Zone-Long-Context: true" "$CURL_LOG"
}

# ---------------------------------------------------------------------------
# loop-health gate
# ---------------------------------------------------------------------------

@test "loop-health: passes on low wheel_spinning and retry_local" {
    local mock_resp='{"results":{"wheel_spinning":{"noul":0.15,"confidence":0.89},"weakened_test_oracle":{"noul":0.02,"confidence":0.95},"next_action":{"choice":"retry_local","confidence":0.88}}}'
    decide_env \
        LOOM_SYSTEMONE_ENABLED=1 \
        LOOM_SYSTEMONE_API_KEY="ts-test-key" \
        LOOM_DECIDE_CURL_BIN="$CURL_STUB" \
        MOCK_SYSTEMONE_RESPONSE="$mock_resp" \
        -- loop-health --attempts "$ATTEMPTS"
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | jq -r '.status')" = "pass" ]
    [ "$(printf '%s' "$output" | jq -r '.next_action')" = "retry_local" ]
}

@test "loop-health: fails closed (exit 2) when wheel-spinning or switch_model_family is recommended" {
    local mock_resp='{"results":{"wheel_spinning":{"noul":0.88,"confidence":0.93},"weakened_test_oracle":{"noul":0.10,"confidence":0.91},"next_action":{"choice":"switch_model_family","confidence":0.90}}}'
    decide_env \
        LOOM_SYSTEMONE_ENABLED=1 \
        LOOM_SYSTEMONE_API_KEY="ts-test-key" \
        LOOM_DECIDE_CURL_BIN="$CURL_STUB" \
        MOCK_SYSTEMONE_RESPONSE="$mock_resp" \
        -- loop-health --attempts "$ATTEMPTS"
    [ "$status" -eq 2 ]
    [ "$(printf '%s' "$output" | jq -r '.status')" = "fail" ]
    [ "$(printf '%s' "$output" | jq -r '.next_action')" = "switch_model_family" ]
}

# ---------------------------------------------------------------------------
# route-role gate & cross-family enforcement
# ---------------------------------------------------------------------------

@test "route-role: deterministically excludes author_client for code-evaluator" {
    local mock_resp='{"results":{"slice_complexity":{"score":1.8,"confidence":0.86},"target_client":{"choice":"claude","confidence":0.85,"probabilities":{"claude":0.55,"codex":0.35,"antigravity":0.10}}}}'
    decide_env \
        LOOM_SYSTEMONE_ENABLED=1 \
        LOOM_SYSTEMONE_API_KEY="ts-test-key" \
        LOOM_DECIDE_CURL_BIN="$CURL_STUB" \
        MOCK_SYSTEMONE_RESPONSE="$mock_resp" \
        -- route-role --role code-evaluator --state "$PLAN" --author-client claude
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | jq -r '.selected_client')" = "codex" ]
    [ "$(printf '%s' "$output" | jq -r '.cross_family_enforced')" = "true" ]
}

@test "endpoint policy: self-hosted URL works without API key while TypeSafe URL requires API key or Keychain" {
    local mock_resp='{"results":{"wheel_spinning":{"noul":0.10},"weakened_test_oracle":{"noul":0.05},"next_action":{"choice":"retry_local","confidence":0.90}}}'
    # TypeSafe URL without API key or Keychain -> fail-closed exit 2
    decide_env \
        LOOM_SYSTEMONE_ENABLED=1 \
        LOOM_SYSTEMONE_URL="https://api.typesafe.ai/v1/systemone" \
        LOOM_SYSTEMONE_API_KEY="" \
        TYPESAFE_API_KEY="" \
        LOOM_DECIDE_SECURITY_BIN="/nonexistent-security-bin" \
        LOOM_DECIDE_CURL_BIN="$CURL_STUB" \
        MOCK_SYSTEMONE_RESPONSE="$mock_resp" \
        -- loop-health --attempts "$ATTEMPTS"
    [ "$status" -eq 2 ]

    # Self-hosted URL without API key -> pass exit 0
    decide_env \
        LOOM_SYSTEMONE_ENABLED=1 \
        LOOM_SYSTEMONE_URL="http://127.0.0.1:8080/v1/systemone" \
        LOOM_SYSTEMONE_API_KEY="" \
        TYPESAFE_API_KEY="" \
        LOOM_DECIDE_SECURITY_BIN="/nonexistent-security-bin" \
        LOOM_DECIDE_CURL_BIN="$CURL_STUB" \
        MOCK_SYSTEMONE_RESPONSE="$mock_resp" \
        -- loop-health --attempts "$ATTEMPTS"
    [ "$status" -eq 0 ]
}

@test "keychain: resolves API key from macOS Keychain via security find-generic-password when env var is unset" {
    local sec_stub="$WORK/security-stub"
    cat >"$sec_stub" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "find-generic-password" ]; then
    printf 'kc-secret-key-999\n'
    exit 0
fi
exit 1
EOF
    chmod +x "$sec_stub"
    local mock_resp='{"answers":{"wheel_spinning":{"noul":0.10},"weakened_test_oracle":{"noul":0.05},"next_action":{"choice":"retry_local","confidence":0.90}}}'
    decide_env \
        LOOM_SYSTEMONE_ENABLED=1 \
        LOOM_SYSTEMONE_URL="https://api.typesafe.ai/v1/systemone" \
        LOOM_SYSTEMONE_API_KEY="" \
        TYPESAFE_API_KEY="" \
        LOOM_DECIDE_SECURITY_BIN="$sec_stub" \
        LOOM_DECIDE_CURL_BIN="$CURL_STUB" \
        MOCK_SYSTEMONE_RESPONSE="$mock_resp" \
        -- loop-health --attempts "$ATTEMPTS"
    [ "$status" -eq 0 ]
    grep -q "Authorization: Bearer kc-secret-key-999" "$CURL_LOG"
}

@test "config file: loads loom-systemone-config/v1 settings when env vars are unset" {
    local cfg="$WORK/systemone-config.json"
    printf '{"schema":"loom-systemone-config/v1","enabled":true,"url":"http://127.0.0.1:8080/v1/systemone","model":"jev-custom","max_bytes":16384}\n' >"$cfg"
    local mock_resp='{"results":{"wheel_spinning":{"noul":0.10},"weakened_test_oracle":{"noul":0.05},"next_action":{"choice":"retry_local","confidence":0.90}}}'
    decide_env \
        LOOM_DECIDE_CURL_BIN="$CURL_STUB" \
        MOCK_SYSTEMONE_RESPONSE="$mock_resp" \
        -- loop-health --attempts "$ATTEMPTS" --config "$cfg"
    [ "$status" -eq 0 ]
    grep -q "http://127.0.0.1:8080/v1/systemone" "$CURL_LOG"
    grep -q '"model":"jev-custom"' "$CURL_LOG"
}

@test "secret-set and secret-status: macOS GUI prompt stores in Keychain without leaking secret to stdout" {
    local osa_stub="$WORK/osascript-stub"
    local sec_stub="$WORK/security-store-stub"
    local stored_file="$WORK/kc-stored"
    cat >"$osa_stub" <<'EOF'
#!/usr/bin/env bash
printf 'super-secret-gui-key-777\n'
EOF
    cat >"$sec_stub" <<EOF
#!/usr/bin/env bash
if [ "\${1:-}" = "add-generic-password" ]; then
    printf '%s\n' "\$*" >"$stored_file"
    exit 0
fi
if [ "\${1:-}" = "find-generic-password" ]; then
    [ -f "$stored_file" ] && printf 'super-secret-gui-key-777\n' && exit 0
    exit 1
fi
exit 1
EOF
    chmod +x "$osa_stub" "$sec_stub"

    decide_env \
        LOOM_DECIDE_OS_OVERRIDE=macos \
        LOOM_DECIDE_OSASCRIPT_BIN="$osa_stub" \
        LOOM_DECIDE_SECURITY_BIN="$sec_stub" \
        -- secret-set --gui
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | jq -r '.os')" = "macos" ]
    [ "$(printf '%s' "$output" | jq -r '.backend')" = "macos-keychain" ]
    [ "$(printf '%s' "$output" | jq -r '.configured')" = "true" ]
    # Secret must NEVER appear in stdout/stderr
    [[ "$output" != *"super-secret-gui-key-777"* ]]
    grep -q "super-secret-gui-key-777" "$stored_file"

    decide_env \
        LOOM_SYSTEMONE_API_KEY="" \
        TYPESAFE_API_KEY="" \
        LOOM_DECIDE_OS_OVERRIDE=macos \
        LOOM_DECIDE_SECURITY_BIN="$sec_stub" \
        -- secret-status
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | jq -r '.configured')" = "true" ]
    [ "$(printf '%s' "$output" | jq -r '.source')" = "macos-keychain" ]
    [[ "$output" != *"super-secret-gui-key-777"* ]]
}

@test "secret-set: Windows OS detection uses windows-dpapi-vault via PowerShell without leaking secret" {
    local ps_stub="$WORK/powershell-stub"
    local ps_log="$WORK/ps-log"
    cat >"$ps_stub" <<EOF
#!/usr/bin/env bash
cat >"$ps_log"
exit 0
EOF
    chmod +x "$ps_stub"

    run env \
        LOOM_DECIDE_OS_OVERRIDE=windows \
        LOOM_DECIDE_POWERSHELL_BIN="$ps_stub" \
        "$LOOM_TEST_BASH" -c 'printf "win-dpapi-secret-456\n" | "$1" secret-set --stdin' -- "$DECIDE"
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | jq -r '.os')" = "windows" ]
    [ "$(printf '%s' "$output" | jq -r '.backend')" = "windows-dpapi-vault" ]
    [ "$(printf '%s' "$output" | jq -r '.configured')" = "true" ]
    [[ "$output" != *"win-dpapi-secret-456"* ]]
    grep -q "win-dpapi-secret-456" "$ps_log"
}
