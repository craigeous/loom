#!/usr/bin/env bats
# Test suite for loom-host-hc host adapter (ADR 0031 §3, §5, §6, §7, ADR 0034 §5).

bats_require_minimum_version 1.5.0

HELPER="${BATS_TEST_DIRNAME}/loom-host-hc"

setup_file() {
    : "${LOOM_TEST_BASH:?LOOM_TEST_BASH is required}"
    : "${LOOM_EXPECTED_BASH_VERSION:?LOOM_EXPECTED_BASH_VERSION is required}"
    case "$LOOM_TEST_BASH" in /*) ;; *) return 1 ;; esac
    [ -x "$LOOM_TEST_BASH" ]
    [[ "$($LOOM_TEST_BASH -c 'printf %s "$BASH_VERSION"')" =~ $LOOM_EXPECTED_BASH_VERSION ]]
}

setup() {
    STUB_DIR="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$STUB_DIR"
    STUB_LOG="$BATS_TEST_TMPDIR/hc.log"
    : >"$STUB_LOG"

    cat >"$STUB_DIR/hc" <<'EOF'
#!/bin/bash
for arg in "$@"; do
    printf '%s\n' "$arg" >>"${STUB_LOG:?}"
done
verb="${1:-}"
case "$verb" in
    get)
        if [ -n "${STUB_GET_EXIT:-}" ]; then
            exit "$STUB_GET_EXIT"
        fi
        cat <<'JSON'
{"name":"test-term","state":"active","status":"running","reported":"2026-11-08T03:00:00Z","exit_code":0}
JSON
        exit 0
        ;;
    wait)
        if [ -n "${STUB_WAIT_EXIT:-}" ]; then
            exit "$STUB_WAIT_EXIT"
        fi
        exit 0
        ;;
    events)
        if [ -n "${STUB_EVENTS_EXIT:-}" ]; then
            exit "$STUB_EVENTS_EXIT"
        fi
        for i in $(seq 1 1000); do
            printf 'event line %d\n' "$i"
        done
        exit 0
        ;;
    kill)
        if [ -n "${STUB_KILL_EXIT:-}" ]; then
            exit "$STUB_KILL_EXIT"
        fi
        exit 0
        ;;
    rm)
        if [ -n "${STUB_RM_EXIT:-}" ]; then
            exit "$STUB_RM_EXIT"
        fi
        exit 0
        ;;
    *)
        exit 99
        ;;
esac
EOF
    chmod 755 "$STUB_DIR/hc"
    export PATH="$STUB_DIR:$PATH"
    export STUB_LOG
}

@test "launch exits 2 unconditionally without invoking hc" {
    run "$HELPER" launch
    [ "$status" -eq 2 ]
    [[ "$output" == *"unsupported: role launch on hc requires the owner-recorded probes (ADR 0031 section 6)"* ]]
    [ ! -s "$STUB_LOG" ]

    run "$HELPER" launch t1 developer
    [ "$status" -eq 2 ]
    [ ! -s "$STUB_LOG" ]

    LOOM_HC_UNVERIFIED=1 LOOM_HC_BIN="$STUB_DIR/hc" run "$HELPER" launch --any-flag
    [ "$status" -eq 2 ]
    [ ! -s "$STUB_LOG" ]
}

@test "unknown subcommand exits 1 with empty stub log" {
    run "$HELPER" unknown-verb
    [ "$status" -eq 1 ]
    [ ! -s "$STUB_LOG" ]

    run "$HELPER"
    [ "$status" -eq 1 ]
    [ ! -s "$STUB_LOG" ]
}

@test "bad terminal names are refused before invoking hc" {
    for bad_name in "-x" "A" "abcdefghijklmnopqrstuvwxyz0123456" "a b" "" $'valid\ninvalid' $'valid\rinvalid'; do
        run "$HELPER" status "$bad_name"
        [ "$status" -ne 0 ]
        [ ! -s "$STUB_LOG" ]

        run "$HELPER" wait "$bad_name" --timeout 10
        [ "$status" -ne 0 ]
        [ ! -s "$STUB_LOG" ]

        run "$HELPER" events "$bad_name"
        [ "$status" -ne 0 ]
        [ ! -s "$STUB_LOG" ]

        run "$HELPER" end "$bad_name"
        [ "$status" -ne 0 ]
        [ ! -s "$STUB_LOG" ]
    done
}

@test "status outputs compact JSON, maps exit_code to exitCode, and exit 3 to not_found" {
    run "$HELPER" status my-term
    [ "$status" -eq 0 ]
    [ "$output" = '{"name":"test-term","state":"active","status":"running","reported":"2026-11-08T03:00:00Z","exitCode":0}' ]

    # Only get, my-term, --json in the stub log
    log_content="$(cat "$STUB_LOG")"
    [ "$log_content" = $'get\nmy-term\n--json' ]

    # hc exit 3 maps to not_found on stdout and exit 2
    : >"$STUB_LOG"
    STUB_GET_EXIT=3 run "$HELPER" status my-term
    [ "$status" -eq 2 ]
    [ "$output" = "not_found" ]
}

@test "wait requires valid --timeout and maps exit codes correctly" {
    # missing --timeout
    run "$HELPER" wait my-term
    [ "$status" -eq 1 ]
    [ ! -s "$STUB_LOG" ]

    # invalid timeout values
    for bad_timeout in 0 3601 abc -5 "" 999999999999999999999999999999; do
        run "$HELPER" wait my-term --timeout "$bad_timeout"
        [ "$status" -eq 1 ]
        [ ! -s "$STUB_LOG" ]
    done

    # exit 0 prints returned
    run "$HELPER" wait my-term --timeout 30
    [ "$status" -eq 0 ]
    [ "$output" = "returned: read the committed artifact" ]

    # nonzero exits map to exit 4 degraded and output never contains complete
    for hc_exit in 1 124 3; do
        : >"$STUB_LOG"
        STUB_WAIT_EXIT="$hc_exit" run "$HELPER" wait my-term --timeout 15
        [ "$status" -eq 4 ]
        [[ "$output" == *"degraded: wait did not return (hc exit ${hc_exit}); not completion"* ]]
        [[ "$output" != *"complete"* ]]
    done
}

@test "events truncates output after specified or default lines" {
    run "$HELPER" events my-term --lines 10
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 10 ]

    run "$HELPER" events my-term
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 500 ]

    # out of bounds lines
    for bad_lines in 0 501 -1 abc 999999999999999999999999999999; do
        run "$HELPER" events my-term --lines "$bad_lines"
        [ "$status" -eq 1 ]
    done
}

@test "end invokes kill, rm, get in order and accepts kill exit 11" {
    # Standard cleanup: kill (0) -> rm (0) -> get (3 not_found)
    cat >"$STUB_DIR/hc" <<'EOF'
#!/bin/bash
for arg in "$@"; do
    printf '%s\n' "$arg" >>"${STUB_LOG:?}"
done
verb="$1"
case "$verb" in
    kill) exit "${STUB_KILL_EXIT:-0}" ;;
    rm) exit 0 ;;
    get) exit "${STUB_GET_EXIT:-3}" ;;
    *) exit 99 ;;
esac
EOF
    chmod 755 "$STUB_DIR/hc"

    run "$HELPER" end my-term
    [ "$status" -eq 0 ]
    log_content="$(cat "$STUB_LOG")"
    [ "$log_content" = $'kill\nmy-term\nrm\nmy-term\nget\nmy-term\n--json' ]

    # accepts kill exit 11 (finished)
    : >"$STUB_LOG"
    STUB_KILL_EXIT=11 run "$HELPER" end my-term
    [ "$status" -eq 0 ]

    # fails closed if get still finds the terminal (exit 0)
    : >"$STUB_LOG"
    STUB_GET_EXIT=0 run "$HELPER" end my-term
    [ "$status" -eq 2 ]
}

@test "only get wait events kill rm are ever invoked on hc across all subcommands" {
    # Run status, wait, events, end
    run "$HELPER" status my-term
    run "$HELPER" wait my-term --timeout 10
    run "$HELPER" events my-term --lines 5
    STUB_GET_EXIT=3 run "$HELPER" end my-term

    # Read all first arguments logged
    while IFS= read -r arg; do
        case "$arg" in
            get|wait|events|kill|rm|my-term|--json|--timeout|10|--terminal) ;;
            *)
                echo "unexpected hc argument: $arg" >&2
                return 1
                ;;
        esac
    done <"$STUB_LOG"
}
