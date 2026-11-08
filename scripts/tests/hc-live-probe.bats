#!/usr/bin/env bats
# Test suite for hc-live-probe (ADR 0031 §6, ADR 0034 §5).

bats_require_minimum_version 1.5.0
PROBE="${BATS_TEST_DIRNAME}/../hc-live-probe"

setup_file() {
    : "${LOOM_TEST_BASH:?}" "${LOOM_EXPECTED_BASH_VERSION:?}"
    case "$LOOM_TEST_BASH" in /*) [ -x "$LOOM_TEST_BASH" ] ;; *) return 1 ;; esac
    [[ "$($LOOM_TEST_BASH -c 'printf %s "$BASH_VERSION"')" =~ $LOOM_EXPECTED_BASH_VERSION ]]
}

setup() {
    STUB_DIR="$BATS_TEST_TMPDIR/bin"; mkdir -p "$STUB_DIR"
    STUB_LOG="$BATS_TEST_TMPDIR/hc.log"; : >"$STUB_LOG"
    EVID_FILE="$BATS_TEST_TMPDIR/evidence/ev.txt"
    cat >"$STUB_DIR/hc" <<'EOF'
#!/bin/bash
for a in "$@"; do printf '%s\n' "$a" >>"${STUB_LOG:?}"; done
case "${1:-}" in
    --version) printf 'hc 0.1.16\n' ;;
    get)
        [ -n "${STUB_GET_EXIT:-}" ] && exit "$STUB_GET_EXIT"
        [ "${3:-}" = "--json" ] || exit 3
        m="${STUB_MODEL:-claude-haiku-5-5}" r="${STUB_REPORTED:-true}" s="${STUB_STATUS_STATE:-done}"
        dt=""; case "$2" in probe-nd-*) dt=', "--disallowedTools", "Agent"' ;; esac
        res=""; [ -n "${STUB_RESUME:-}" ] && res=', "--resume", "p"'
        p='What is 37+5? Reply with only the number, then stop. Use no tools.'
        case "$2" in probe-nd-*) p="If you have a tool named Agent, call it once with the prompt 'say hi'. If you do not have it, reply with only TOOL_ABSENT, then stop." ;; esac
        printf '{"name":"%s","reported":%s,"status":{"state":"%s"},"foreground":{"argv":["claude", "--model", "%s"%s%s, "%s"]}}\n' "$2" "$r" "$s" "$m" "$res" "$dt" "$p" ;;
    run) [ -n "${STUB_RUN_EXIT:-}" ] && exit "$STUB_RUN_EXIT"; printf 't1\n' ;;
    wait) [ -n "${STUB_WAIT_SIGINT:-}" ] && kill -INT "$$"; exit "${STUB_WAIT_EXIT:-0}" ;;
    read)
        [ -n "${STUB_READ_EXIT:-}" ] && exit "$STUB_READ_EXIT"
        case "$2" in probe-nd-*) printf '%s\n' "${STUB_READ_ND:-TOOL_ABSENT}" ;; *) printf '%s\n' "${STUB_READ_A:-42}" ;; esac ;;
    kill) exit "${STUB_KILL_EXIT:-0}" ;;
    rm) exit "${STUB_RM_EXIT:-0}" ;;
    *) exit 99 ;;
esac
EOF
    chmod 755 "$STUB_DIR/hc"
    export PATH="$STUB_DIR:$PATH" STUB_LOG LOOM_HC_PROBE_ID="test0001"
}

@test "refusal without LOOM_HC_LIVE_PROBE=1 exits 2 with empty stub log" {
    run "$PROBE" --evidence-file "$EVID_FILE"
    [ "$status" -eq 2 ] && [ ! -s "$STUB_LOG" ]
}

@test "refusal without absolute evidence file exits 2 with empty stub log" {
    LOOM_HC_LIVE_PROBE=1 run "$PROBE"
    [ "$status" -eq 2 ]
    LOOM_HC_LIVE_PROBE=1 run "$PROBE" --evidence-file "relative/path.txt"
    [ "$status" -eq 2 ] && [ ! -s "$STUB_LOG" ]
}

@test "PASS when all criteria met with exact command sequence and allowed verbs" {
    LOOM_HC_LIVE_PROBE=1 run "$PROBE" --evidence-file "$EVID_FILE"
    [ "$status" -eq 0 ] && [[ "$output" == *"RESULT PASS"* ]]
    grep -q "RESULT PASS" "$EVID_FILE" && grep -q "claude-haiku-5-5" "$STUB_LOG"
    while IFS= read -r a; do
        case "$a" in
        get | run | wait | read | kill | rm | --version | --* | claude | claude-haiku-5-5 | Agent | test0001 | probe-* | t1 | *[0-9]* | "What is 37+5?"* | "If you have a tool named Agent"* | "") ;;
        *) false ;;
        esac
    done <"$STUB_LOG"
}

@test "FAIL for each of: reported false, wrong status, missing 42, 37+5 echoed, resume, missing model, agent present, kill fail, get 0" {
    for var in "STUB_REPORTED=false" "STUB_STATUS_STATE=working" "STUB_RESUME=1" "STUB_MODEL=bad"; do
        eval "$var LOOM_HC_LIVE_PROBE=1 run \"\$PROBE\" --evidence-file \"\$EVID_FILE\""
        [ "$status" -eq 1 ] && [[ "$output" == *"RESULT FAIL"*"P4"* ]]
    done
    for var in "STUB_READ_A=wrong" "STUB_READ_A='37+5 is 42'"; do
        eval "$var LOOM_HC_LIVE_PROBE=1 run \"\$PROBE\" --evidence-file \"\$EVID_FILE\""
        [ "$status" -eq 1 ] && [[ "$output" == *"RESULT FAIL"*"P5"* ]]
    done
    STUB_READ_ND="TOOL_ABSENT with sub-agent" LOOM_HC_LIVE_PROBE=1 run "$PROBE" --evidence-file "$EVID_FILE"
    [ "$status" -eq 1 ] && [[ "$output" == *"RESULT FAIL"*"P6"* ]]
    STUB_KILL_EXIT=1 LOOM_HC_LIVE_PROBE=1 run "$PROBE" --evidence-file "$EVID_FILE"
    [ "$status" -eq 1 ] && [[ "$output" == *"RESULT FAIL"*"P7"* ]]
    STUB_GET_EXIT=0 LOOM_HC_LIVE_PROBE=1 run "$PROBE" --evidence-file "$EVID_FILE"
    [ "$status" -eq 1 ] && [[ "$output" == *"RESULT FAIL"* ]]
}

@test "BLOCKED when hc get shows blocked with no keys or --force in log" {
    STUB_STATUS_STATE=blocked LOOM_HC_LIVE_PROBE=1 run "$PROBE" --evidence-file "$EVID_FILE"
    [ "$status" -eq 3 ] && [[ "$output" == *"RESULT BLOCKED"* ]]
    ! grep -q "\-\-force" "$STUB_LOG" && ! grep -q "^send$" "$STUB_LOG"
}

@test "cleanup runs on mid-run signal" {
    STUB_WAIT_SIGINT=1 LOOM_HC_LIVE_PROBE=1 run "$PROBE" --evidence-file "$EVID_FILE"
    grep -q "kill" "$STUB_LOG" && grep -q "rm" "$STUB_LOG"
}
