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
    STUB_LOG="$BATS_TEST_TMPDIR/hc.log" && : >"$STUB_LOG" && EVID_FILE="$BATS_TEST_TMPDIR/evidence/ev.txt"
    cat >"$STUB_DIR/hc" <<'EOF'
#!/bin/bash
{ for a in "$@"; do printf '<%s>' "$a"; done; echo; } >>"${STUB_LOG:?}"
case "${1:-}" in
    --version) printf 'hc 0.1.16\n' ;;
    get)
        [ -n "${STUB_GET_EXIT:-}" ] && exit "$STUB_GET_EXIT"
        [ "${3:-}" = "--json" ] && [ -n "${STUB_GET_JSON_EXIT:-}" ] && exit "$STUB_GET_JSON_EXIT"
        [ "${3:-}" = "--json" ] || exit 3
        m="${STUB_MODEL:-claude-haiku-5-5}" r="${STUB_REPORTED:-true}" s="${STUB_STATUS_STATE:-done}" dt="" res=""
        case "$2" in probe-nd-*) dt=', "--disallowedTools", "Agent"'; p="If you have a tool named Agent, call it once with the prompt 'say hi'. If you do not have it, reply with only TOOL_ABSENT, then stop." ;; *) p='What is 37+5? Reply with only the number, then stop. Use no tools.' ;; esac
        [ -n "${STUB_RESUME:-}" ] && res=', "--resume", "p"'
        printf '{"name":"%s","reported":%s,"status":{"state":"%s"},"foreground":{"argv":["claude", "--model", "%s"%s%s, "%s"]}}\n' "$2" "$r" "$s" "$m" "$res" "$dt" "$p" ;;
    run) [ -n "${STUB_RUN_EXIT:-}" ] && exit "$STUB_RUN_EXIT"; printf '%s\n' "${STUB_RUN_OUT-t1}" ;;
    wait) [ -n "${STUB_WAIT_SLEEP:-}" ] && sleep 2; exit "${STUB_WAIT_EXIT:-0}" ;;
    read)
        [ -n "${STUB_READ_EXIT:-}" ] && exit "$STUB_READ_EXIT"
        case "$2" in probe-nd-*) printf '%s\n' "${STUB_READ_ND:-TOOL_ABSENT}" ;; *) printf '%s\n' "${STUB_READ_A:-42}" ;; esac ;;
    kill) [ -n "${STUB_KILL_SLEEP:-}" ] && sleep 0.2; exit "${STUB_KILL_EXIT:-0}" ;;
    rm) exit "${STUB_RM_EXIT:-0}" ;;
    *) exit 99 ;;
esac
EOF
    chmod 755 "$STUB_DIR/hc"
    export PATH="$STUB_DIR:$PATH" STUB_LOG LOOM_HC_PROBE_ID="test0001"
}

@test "refusal without LOOM_HC_LIVE_PROBE=1 or absolute evidence file exits 2 with empty stub log" {
    run "$PROBE" --evidence-file "$EVID_FILE"; [ "$status" -eq 2 ] && [ ! -s "$STUB_LOG" ]
    LOOM_HC_LIVE_PROBE=1 run "$PROBE"; [ "$status" -eq 2 ]
    LOOM_HC_LIVE_PROBE=1 run "$PROBE" --evidence-file "relative/path.txt"; [ "$status" -eq 2 ] && [ ! -s "$STUB_LOG" ]
}

@test "PASS with exact ordered argv sequence and P1-P7 evidence" {
    LOOM_HC_LIVE_PROBE=1 run "$PROBE" --evidence-file "$EVID_FILE"
    [ "$status" -eq 0 ] && [[ "$output" == *"RESULT PASS"* ]]
    grep -q "RESULT PASS" "$EVID_FILE"
    diff -u - "$STUB_LOG" <<'EOF'
<--version>
<get><probe-test0001>
<get><probe-nd-test0001>
<run><--bg><--name><probe-test0001><claude><--model><claude-haiku-5-5><What is 37+5? Reply with only the number, then stop. Use no tools.>
<wait><probe-test0001><--timeout><120>
<get><probe-test0001><--json>
<read><probe-test0001><--lines><60>
<run><--bg><--name><probe-nd-test0001><claude><--model><claude-haiku-5-5><--disallowedTools><Agent><If you have a tool named Agent, call it once with the prompt 'say hi'. If you do not have it, reply with only TOOL_ABSENT, then stop.>
<wait><probe-nd-test0001><--timeout><120>
<get><probe-nd-test0001><--json>
<read><probe-nd-test0001><--lines><60>
<kill><probe-test0001>
<rm><probe-test0001>
<get><probe-test0001>
<kill><probe-nd-test0001>
<rm><probe-nd-test0001>
<get><probe-nd-test0001>
EOF
}

@test "collision on P1 aborts immediately without launching or killing pre-existing terminals" {
    STUB_GET_EXIT=0 LOOM_HC_LIVE_PROBE=1 run "$PROBE" --evidence-file "$EVID_FILE"
    [ "$status" -eq 1 ] && [[ "$output" == *"RESULT FAIL"*"P1"* ]]
    ! grep -q "<run>" "$STUB_LOG" && ! grep -q "<kill>" "$STUB_LOG" && ! grep -q "<rm>" "$STUB_LOG"
}

@test "FAIL for failed exit or bad output in each criterion" {
    for v in "STUB_REPORTED=false" "STUB_STATUS_STATE=working" "STUB_RESUME=1" "STUB_MODEL=bad"; do
        eval "$v LOOM_HC_LIVE_PROBE=1 run \"\$PROBE\" --evidence-file \"\$EVID_FILE\""
        [ "$status" -eq 1 ] && [[ "$output" == *"RESULT FAIL"*"P4"* ]]
    done
    for v in "STUB_READ_A=wrong" "STUB_READ_A='37+5 is 42'" "STUB_READ_EXIT=1"; do
        eval "$v LOOM_HC_LIVE_PROBE=1 run \"\$PROBE\" --evidence-file \"\$EVID_FILE\""
        [ "$status" -eq 1 ] && [[ "$output" == *"RESULT FAIL"*"P5"* ]]
    done
    for v in "STUB_READ_ND=sub-agent" "STUB_RUN_EXIT=1" "STUB_RUN_OUT='t1\nextra'" "STUB_RUN_OUT=''" "STUB_KILL_EXIT=1"; do
        eval "$v LOOM_HC_LIVE_PROBE=1 run \"\$PROBE\" --evidence-file \"\$EVID_FILE\""
        [ "$status" -eq 1 ]
    done
}

@test "BLOCKED when hc get shows blocked with no keys or --force in log" {
    for v in "STUB_STATUS_STATE=blocked" "STUB_GET_JSON_EXIT=9"; do
        eval "$v LOOM_HC_LIVE_PROBE=1 run \"\$PROBE\" --evidence-file \"\$EVID_FILE\""
        [ "$status" -eq 3 ] && [[ "$output" == *"RESULT BLOCKED"* ]]
    done
    ! grep -q "\-\-force" "$STUB_LOG" && ! grep -q "<send>" "$STUB_LOG"
}

@test "cleanup runs on mid-run signal and resists interruption during cleanup" {
    export STUB_WAIT_SLEEP=1 STUB_KILL_SLEEP=1; set -m
    LOOM_HC_LIVE_PROBE=1 "$PROBE" --evidence-file "$EVID_FILE" &
    pid=$!; sleep 0.1; kill -INT -$pid 2>/dev/null || kill -INT "$pid" 2>/dev/null || true
    sleep 0.05; kill -INT -$pid 2>/dev/null || kill -INT "$pid" 2>/dev/null || true
    rc=0; wait "$pid" || rc=$?; [ "$rc" -eq 130 ]
    grep -q "<kill><probe-test0001>" "$STUB_LOG" && grep -q "<rm><probe-test0001>" "$STUB_LOG"
    ! grep -q "<kill><probe-nd-test0001>" "$STUB_LOG"
}
