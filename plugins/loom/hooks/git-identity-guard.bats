#!/usr/bin/env bats
# Test suite for git-identity-guard.sh (ADR 0003 identity guard).
# Drives the hook with hook-shaped JSON on stdin; asserts the exit code.
# The code evaluator re-runs this suite as the shell gate's TEST step.

GUARD="${BATS_TEST_DIRNAME}/git-identity-guard.sh"

# guard <json> -- runs the hook with the given stdin, sets $status/$output
guard() {
    run sh "$GUARD" <<<"$1"
}

# guard_no_jq <json> -- runs the hook with a stub PATH that excludes jq,
# forcing the grep/sed fallback branch (lines ~27-29 of the hook).
guard_no_jq() {
    stub="$(mktemp -d)"
    # NOTE: the interpreter is invoked by ABSOLUTE path (/bin/sh) so it does
    # NOT need to be on the stubbed PATH. Symlink only what the fallback branch
    # uses; deliberately omit jq so command -v jq fails (NO_JQ).
    for t in cat grep sed tr wc head; do
        for d in /usr/bin /bin; do
            [ -x "$d/$t" ] && {
                ln -s "$d/$t" "$stub/$t"
                break
            }
        done
    done
    run env PATH="$stub" /bin/sh "$GUARD" <<<"$1"
    rm -rf "$stub"
}

# ---------------------------------------------------------------------------
# BLOCK cases (exit 2) — identity override detected
# ---------------------------------------------------------------------------

@test "BLOCK B01: commit --author= with quoted value" {
    guard '{"tool_input":{"command":"git commit --author=\"x <x@y>\" -m z"}}'
    [ "$status" -eq 2 ]
}

@test "BLOCK B02: -c user.email= override" {
    guard '{"tool_input":{"command":"git -c user.email=x@y commit -m z"}}'
    [ "$status" -eq 2 ]
}

@test "BLOCK B03: -c user.name= override" {
    guard '{"tool_input":{"command":"git -c user.name=Foo commit -m z"}}'
    [ "$status" -eq 2 ]
}

@test "BLOCK B04: inline GIT_AUTHOR_NAME env" {
    guard '{"tool_input":{"command":"GIT_AUTHOR_NAME=Foo git commit -m z"}}'
    [ "$status" -eq 2 ]
}

@test "BLOCK B05: exported GIT_COMMITTER_EMAIL env" {
    guard '{"tool_input":{"command":"export GIT_COMMITTER_EMAIL=x@y; git commit -m z"}}'
    [ "$status" -eq 2 ]
}

@test "BLOCK B06: --author with space form" {
    guard '{"tool_input":{"command":"git commit --author bar -m z"}}'
    [ "$status" -eq 2 ]
}

@test "BLOCK B07: -c GIT_AUTHOR_NAME= override" {
    guard '{"tool_input":{"command":"git -c GIT_AUTHOR_NAME=x commit"}}'
    [ "$status" -eq 2 ]
}

@test "BLOCK B08: --author= with quoted value and quoted message" {
    guard '{"tool_input":{"command":"git commit --author=\"evil <e@e>\" -m \"ok\""}}'
    [ "$status" -eq 2 ]
}

@test "BLOCK B09: --author= beside escaped inner quote (Stage A no-op on real override)" {
    guard '{"tool_input":{"command":"git commit --author=evil -m \"say \\\"hi\\\"\""}}'
    [ "$status" -eq 2 ]
}

@test "BLOCK B10: read over-block — -c user.email= on log (accepted fail-closed limitation, ADR 0003)" {
    guard '{"tool_input":{"command":"git -c user.email=x@y log"}}'
    [ "$status" -eq 2 ]
}

@test "BLOCK B11: read over-block — git log --author= (accepted fail-closed limitation)" {
    guard '{"tool_input":{"command":"git log --author=alice"}}'
    [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# ALLOW cases (exit 0) — no identity override
# ---------------------------------------------------------------------------

@test "ALLOW A01: plain commit, no override" {
    guard '{"tool_input":{"command":"git commit -m \"msg\""}}'
    [ "$status" -eq 0 ]
}

@test "ALLOW A02: -c core.* is non-identity config" {
    guard '{"tool_input":{"command":"git -c core.pager=cat log"}}'
    [ "$status" -eq 0 ]
}

@test "ALLOW A03: not a git command" {
    guard '{"tool_input":{"command":"ls -la"}}'
    [ "$status" -eq 0 ]
}

@test "ALLOW A04: git only as substring of another word" {
    guard '{"tool_input":{"command":"echo legitimate=1"}}'
    [ "$status" -eq 0 ]
}

@test "ALLOW A05: --author= only inside message body" {
    guard '{"tool_input":{"command":"git commit -m \"fix --author= parsing\""}}'
    [ "$status" -eq 0 ]
}

@test "ALLOW A06: --author flag text only inside message body" {
    guard '{"tool_input":{"command":"git commit -m \"guard against --author flag\""}}'
    [ "$status" -eq 0 ]
}

@test "ALLOW A07: GIT_AUTHOR_NAME= only inside message body" {
    guard '{"tool_input":{"command":"git commit -m \"set GIT_AUTHOR_NAME=foo in script\""}}'
    [ "$status" -eq 0 ]
}

@test "ALLOW A08: -c user.email= only inside message body" {
    guard '{"tool_input":{"command":"git commit -m \"add -c user.email= override\""}}'
    [ "$status" -eq 0 ]
}

@test "ALLOW A09: --grep value is not an identity flag; stripped" {
    guard '{"tool_input":{"command":"git log --grep=\"--author=\""}}'
    [ "$status" -eq 0 ]
}

@test "ALLOW A10: escaped-inner-quote message with --author= text (Stage A)" {
    guard '{"tool_input":{"command":"git commit -m \"use \\\"--author=\\\" flag carefully\""}}'
    [ "$status" -eq 0 ]
}

@test "ALLOW A11: escaped-inner-quote message with GIT_AUTHOR_NAME= text" {
    guard '{"tool_input":{"command":"git commit -m \"mention \\\"GIT_AUTHOR_NAME=x\\\" here\""}}'
    [ "$status" -eq 0 ]
}

@test "ALLOW A12: escaped-inner-quote message with -c user.email= text" {
    guard '{"tool_input":{"command":"git commit -m \"note \\\"-c user.email=\\\" thing\""}}'
    [ "$status" -eq 0 ]
}

@test "ALLOW A13: unbalanced quoting triggers Stage C fail-open" {
    guard '{"tool_input":{"command":"git commit -m \"wip"}}'
    [ "$status" -eq 0 ]
}

@test "ALLOW A14: plain git push, no override token" {
    guard '{"tool_input":{"command":"git push"}}'
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Fallback cases (jq absent) — genuinely exercise the grep/sed branch
# ---------------------------------------------------------------------------

@test "FALLBACK F1: BLOCK survives jq-absent fallback (--author= override)" {
    guard_no_jq '{"tool_input":{"command":"git commit --author=evil -m z"}}'
    [ "$status" -eq 2 ]
}

@test "FALLBACK F2: BLOCK survives jq-absent fallback (inline GIT_AUTHOR_NAME env)" {
    guard_no_jq '{"tool_input":{"command":"GIT_AUTHOR_NAME=Foo git commit -m z"}}'
    [ "$status" -eq 2 ]
}

@test "FALLBACK F3: ALLOW survives jq-absent fallback (plain commit)" {
    guard_no_jq '{"tool_input":{"command":"git commit -m z"}}'
    [ "$status" -eq 0 ]
}
