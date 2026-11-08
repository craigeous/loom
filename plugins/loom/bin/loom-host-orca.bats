#!/usr/bin/env bats
# Test suite for loom-host-orca host adapter (ADR 0034 §1, §2, §5).

bats_require_minimum_version 1.5.0

HELPER="${BATS_TEST_DIRNAME}/loom-host-orca"

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
    STUB_LOG="$BATS_TEST_TMPDIR/orca.log"
    : >"$STUB_LOG"

    cat >"$STUB_DIR/orca" <<'EOF'
#!/bin/bash
for arg in "$@"; do
    printf '%s\n' "$arg" >>"${STUB_LOG:?}"
done

cmd="${1:-}"
if [ "$cmd" != "terminal" ]; then
    exit 99
fi
shift
sub="${1:-}"
shift

case "$sub" in
    show)
        if [ -n "${STUB_SHOW_EXIT:-}" ]; then
            if [ -n "${STUB_SHOW_OUTPUT:-}" ]; then
                printf '%s\n' "$STUB_SHOW_OUTPUT"
            fi
            exit "$STUB_SHOW_EXIT"
        fi
        if [ -n "${STUB_SHOW_OUTPUT:-}" ]; then
            printf '%s\n' "$STUB_SHOW_OUTPUT"
            exit 0
        fi
        cat <<'JSON'
{"ok":true,"result":{"terminal":{"handle":"my-term","title":"Test Term","connected":true,"worktreePath":"/path/to/worktree","exitCause":null}}}
JSON
        exit 0
        ;;
    wait)
        if [ -n "${STUB_WAIT_EXIT:-}" ]; then
            exit "$STUB_WAIT_EXIT"
        fi
        cat <<'JSON'
{"ok":true,"result":{"wait":{"handle":"my-term","condition":"exit","satisfied":true,"status":"exited","exitCode":0}}}
JSON
        exit 0
        ;;
    read)
        if [ -n "${STUB_READ_EXIT:-}" ]; then
            if [ -n "${STUB_READ_OUTPUT:-}" ]; then
                printf '%s\n' "$STUB_READ_OUTPUT"
            fi
            exit "$STUB_READ_EXIT"
        fi
        if [ -n "${STUB_READ_OUTPUT:-}" ]; then
            printf '%s\n' "$STUB_READ_OUTPUT"
            exit 0
        fi
        # Default: produce 1000 lines in tail array
        lines_json=$(for i in $(seq 1 1000); do printf '"line %d",' "$i"; done | sed 's/,$//')
        printf '{"ok":true,"result":{"terminal":{"handle":"my-term","status":"active","tail":[%s],"returnedLineCount":1000}}}\n' "$lines_json"
        exit 0
        ;;
    close)
        if [ -n "${STUB_CLOSE_EXIT:-}" ]; then
            if [ -n "${STUB_CLOSE_OUTPUT:-}" ]; then
                printf '%s\n' "$STUB_CLOSE_OUTPUT"
            fi
            exit "$STUB_CLOSE_EXIT"
        fi
        if [ -n "${STUB_CLOSE_OUTPUT:-}" ]; then
            printf '%s\n' "$STUB_CLOSE_OUTPUT"
            exit 0
        fi
        cat <<'JSON'
{"ok":true,"result":{"close":{"handle":"my-term","tabId":"tab-123","ptyKilled":true}}}
JSON
        exit 0
        ;;
    *)
        exit 99
        ;;
esac
EOF
    chmod 755 "$STUB_DIR/orca"
    export PATH="$STUB_DIR:$PATH"
    export STUB_LOG
}

@test "launch exits 2 unconditionally without invoking orca" {
    run "$HELPER" launch
    [ "$status" -eq 2 ]
    [[ "$output" == *"unsupported: role launch on orca requires the owner-recorded probes (ADR 0034 sections 1 and 2)"* ]]
    [ ! -s "$STUB_LOG" ]

    run "$HELPER" launch t1 developer
    [ "$status" -eq 2 ]
    [ ! -s "$STUB_LOG" ]

    LOOM_ORCA_BIN="$STUB_DIR/orca" run "$HELPER" launch --any-flag
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

@test "bad handle formats are refused before invoking orca" {
    for bad_handle in "-x" "a b" "" $'valid\ninvalid' $'valid\rinvalid' "abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz012345"; do
        run "$HELPER" status "$bad_handle"
        [ "$status" -ne 0 ]
        [ ! -s "$STUB_LOG" ]

        run "$HELPER" wait "$bad_handle" --timeout 10
        [ "$status" -ne 0 ]
        [ ! -s "$STUB_LOG" ]

        run "$HELPER" read "$bad_handle"
        [ "$status" -ne 0 ]
        [ ! -s "$STUB_LOG" ]

        run "$HELPER" events "$bad_handle"
        [ "$status" -ne 0 ]
        [ ! -s "$STUB_LOG" ]

        run "$HELPER" end "$bad_handle"
        [ "$status" -ne 0 ]
        [ ! -s "$STUB_LOG" ]
    done
}

@test "status parses JSON shape, maps stale to not_found, and fails closed on malformed or CLI error" {
    run "$HELPER" status my-term
    [ "$status" -eq 0 ]
    [ "$output" = '{"handle":"my-term","title":"Test Term","connected":true,"exitCause":null,"worktreePath":"/path/to/worktree"}' ]

    # Only terminal, show, --terminal, my-term, --json in the stub log
    log_content="$(cat "$STUB_LOG")"
    [ "$log_content" = $'terminal\nshow\n--terminal\nmy-term\n--json' ]

    # stale handle exit 1 -> not_found on stdout and exit 2
    : >"$STUB_LOG"
    STUB_SHOW_EXIT=1 STUB_SHOW_OUTPUT='{"ok":false,"error":{"code":"terminal_handle_stale","message":"terminal_handle_stale"}}' \
        run "$HELPER" status my-term
    [ "$status" -eq 2 ]
    [ "$output" = "not_found" ]

    # non-stale error (exit != 0) fails closed with exit 2 and failure message
    : >"$STUB_LOG"
    STUB_SHOW_EXIT=5 STUB_SHOW_OUTPUT='{"ok":false,"error":{"code":"internal_error"}}' \
        run "$HELPER" status my-term
    [ "$status" -eq 2 ]
    [[ "$output" == *"orca terminal show exited with status 5"* ]]

    # malformed JSON fails closed with exit 2
    : >"$STUB_LOG"
    STUB_SHOW_EXIT=0 STUB_SHOW_OUTPUT='not json' \
        run "$HELPER" status my-term
    [ "$status" -eq 2 ]
    [[ "$output" == *"failed to parse orca terminal show JSON"* ]]
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

    # exit 0 prints returned and passes timeout-ms
    run "$HELPER" wait my-term --timeout 30
    [ "$status" -eq 0 ]
    [ "$output" = "returned: read the committed artifact" ]
    log_content="$(cat "$STUB_LOG")"
    [ "$log_content" = $'terminal\nwait\n--terminal\nmy-term\n--for\nexit\n--timeout-ms\n30000\n--json' ]

    # nonzero exits map to exit 4 degraded and output never contains complete
    for orca_exit in 1 124 3; do
        : >"$STUB_LOG"
        STUB_WAIT_EXIT="$orca_exit" run "$HELPER" wait my-term --timeout 15
        [ "$status" -eq 4 ]
        [[ "$output" == *"degraded: wait did not return (orca exit ${orca_exit}); not completion"* ]]
        [[ "$output" != *"complete"* ]]
    done
}

@test "read and events map --lines to --limit and truncate tail lines" {
    run "$HELPER" read my-term --lines 10
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 10 ]
    [ "${lines[0]}" = "line 1" ]
    [ "${lines[9]}" = "line 10" ]

    # Verify --limit 10 passed to orca
    log_content="$(cat "$STUB_LOG")"
    [ "$log_content" = $'terminal\nread\n--terminal\nmy-term\n--limit\n10\n--json' ]

    # events synonym works identically and defaults to 500 lines
    : >"$STUB_LOG"
    run "$HELPER" events my-term
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 500 ]
    log_content="$(cat "$STUB_LOG")"
    [ "$log_content" = $'terminal\nread\n--terminal\nmy-term\n--limit\n500\n--json' ]

    # out of bounds lines
    for bad_lines in 0 501 -1 abc 999999999999999999999999999999; do
        run "$HELPER" read my-term --lines "$bad_lines"
        [ "$status" -eq 1 ]
    done

    # CLI error (exit != 0) fails closed with exit 2
    STUB_READ_EXIT=3 run "$HELPER" read my-term
    [ "$status" -eq 2 ]
    [[ "$output" == *"orca terminal read exited with status 3"* ]]

    # Malformed JSON fails closed with exit 2
    STUB_READ_EXIT=0 STUB_READ_OUTPUT='not json' run "$HELPER" read my-term
    [ "$status" -eq 2 ]
    [[ "$output" == *"failed to parse orca terminal read JSON"* ]]
}

@test "end invokes close and verifies cleanup with strict fail-closed validation" {
    # Positive case 1: close exit 0 -> show exit 1 (stale) confirms cleanup
    STUB_CLOSE_EXIT=0 STUB_CLOSE_OUTPUT='{"ok":true,"result":{"close":{"handle":"my-term","tabId":"tab-123","ptyKilled":true}}}' \
    STUB_SHOW_EXIT=1 STUB_SHOW_OUTPUT='{"ok":false,"error":{"code":"terminal_handle_stale","message":"terminal_handle_stale"}}' \
        run "$HELPER" end my-term
    [ "$status" -eq 0 ]
    log_content="$(cat "$STUB_LOG")"
    [ "$log_content" = $'terminal\nclose\n--terminal\nmy-term\n--tab\n--json\nterminal\nshow\n--terminal\nmy-term\n--json' ]

    # Positive case 2: close exit 0 -> show exit 0 with connected=false and exitCause=operator_close
    : >"$STUB_LOG"
    STUB_CLOSE_EXIT=0 STUB_CLOSE_OUTPUT='{"ok":true,"result":{"close":{"handle":"my-term","tabId":"tab-123","ptyKilled":true}}}' \
    STUB_SHOW_EXIT=0 STUB_SHOW_OUTPUT='{"ok":true,"result":{"terminal":{"handle":"my-term","title":"T","connected":false,"worktreePath":"/p","exitCause":{"kind":"operator_close"}}}}' \
        run "$HELPER" end my-term
    [ "$status" -eq 0 ]

    # Positive case 3: close exit 1 (stale) -> show exit 1 (stale) confirms cleanup
    : >"$STUB_LOG"
    STUB_CLOSE_EXIT=1 STUB_CLOSE_OUTPUT='{"ok":false,"error":{"code":"terminal_handle_stale","message":"stale"}}' \
    STUB_SHOW_EXIT=1 STUB_SHOW_OUTPUT='{"ok":false,"error":{"code":"terminal_handle_stale","message":"stale"}}' \
        run "$HELPER" end my-term
    [ "$status" -eq 0 ]

    # Negative case 1: close exit 0 with malformed JSON
    : >"$STUB_LOG"
    STUB_CLOSE_EXIT=0 STUB_CLOSE_OUTPUT='not-json' \
        run "$HELPER" end my-term
    [ "$status" -eq 2 ]
    [[ "$output" == *"failed to parse orca terminal close JSON"* ]]

    # Negative case 2: close exit 0 but handle mismatch
    : >"$STUB_LOG"
    STUB_CLOSE_EXIT=0 STUB_CLOSE_OUTPUT='{"ok":true,"result":{"close":{"handle":"other-term","tabId":"tab-123","ptyKilled":true}}}' \
        run "$HELPER" end my-term
    [ "$status" -eq 2 ]
    [[ "$output" == *"orca terminal close response did not confirm handle my-term"* ]]

    # Negative case 3: close exit 1 with malformed JSON
    : >"$STUB_LOG"
    STUB_CLOSE_EXIT=1 STUB_CLOSE_OUTPUT='not-json' \
        run "$HELPER" end my-term
    [ "$status" -eq 2 ]
    [[ "$output" == *"failed to parse orca terminal close JSON"* ]]

    # Negative case 4: close exit 1 with non-stale error
    : >"$STUB_LOG"
    STUB_CLOSE_EXIT=1 STUB_CLOSE_OUTPUT='{"ok":false,"error":{"code":"other_error"}}' \
        run "$HELPER" end my-term
    [ "$status" -eq 2 ]
    [[ "$output" == *"orca terminal close exited with status 1 but was not stale"* ]]

    # Negative case 5: close unexpected exit code != 0 and != 1
    : >"$STUB_LOG"
    STUB_CLOSE_EXIT=2 STUB_CLOSE_OUTPUT='{"ok":false}' \
        run "$HELPER" end my-term
    [ "$status" -eq 2 ]
    [[ "$output" == *"orca terminal close exited with status 2"* ]]

    # Negative case 6: show after close has malformed JSON
    : >"$STUB_LOG"
    STUB_CLOSE_EXIT=0 STUB_CLOSE_OUTPUT='{"ok":true,"result":{"close":{"handle":"my-term","tabId":"tab-123","ptyKilled":true}}}' \
    STUB_SHOW_EXIT=0 STUB_SHOW_OUTPUT='not-json' \
        run "$HELPER" end my-term
    [ "$status" -eq 2 ]
    [[ "$output" == *"failed to parse orca terminal show JSON"* ]]

    # Negative case 7: show after close reports connected: true
    : >"$STUB_LOG"
    STUB_CLOSE_EXIT=0 STUB_CLOSE_OUTPUT='{"ok":true,"result":{"close":{"handle":"my-term","tabId":"tab-123","ptyKilled":true}}}' \
    STUB_SHOW_EXIT=0 STUB_SHOW_OUTPUT='{"ok":true,"result":{"terminal":{"handle":"my-term","title":"T","connected":true,"worktreePath":"/p","exitCause":null}}}' \
        run "$HELPER" end my-term
    [ "$status" -eq 2 ]
    [[ "$output" == *"orca terminal show after close did not confirm terminal termination"* ]]

    # Negative case 8: show after close reports unrecognized exitCause
    : >"$STUB_LOG"
    STUB_CLOSE_EXIT=0 STUB_CLOSE_OUTPUT='{"ok":true,"result":{"close":{"handle":"my-term","tabId":"tab-123","ptyKilled":true}}}' \
    STUB_SHOW_EXIT=0 STUB_SHOW_OUTPUT='{"ok":true,"result":{"terminal":{"handle":"my-term","title":"T","connected":false,"worktreePath":"/p","exitCause":{"kind":"unknown_cause"}}}}' \
        run "$HELPER" end my-term
    [ "$status" -eq 2 ]
    [[ "$output" == *"orca terminal show after close did not confirm terminal termination"* ]]
}

@test "only terminal with show wait read close are ever invoked on orca across all subcommands" {
    # Run status, wait, events, end
    run "$HELPER" status my-term
    run "$HELPER" wait my-term --timeout 10
    run "$HELPER" events my-term --lines 5
    STUB_CLOSE_EXIT=0 STUB_CLOSE_OUTPUT='{"ok":true,"result":{"close":{"handle":"my-term","tabId":"tab-123","ptyKilled":true}}}' \
    STUB_SHOW_EXIT=1 STUB_SHOW_OUTPUT='{"ok":false,"error":{"code":"terminal_handle_stale","message":"terminal_handle_stale"}}' \
        run "$HELPER" end my-term

    # Read all arguments logged
    while IFS= read -r arg; do
        case "$arg" in
            terminal|show|wait|read|close|my-term|--terminal|--json|--timeout-ms|10000|--for|exit|--limit|5|--tab) ;;
            *)
                echo "unexpected orca argument: $arg" >&2
                return 1
                ;;
        esac
    done <"$STUB_LOG"
}
