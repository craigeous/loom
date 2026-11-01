#!/usr/bin/env bats
# Test suite for git-identity-guard.sh (ADR 0003 policy; spec 08 wire adapters).
# Drives the hook with hook-shaped JSON on stdin; asserts exit code/output.
# The code evaluator re-runs this suite as the shell gate's TEST step.
bats_require_minimum_version 1.5.0

GUARD="${BATS_TEST_DIRNAME}/git-identity-guard.sh"

setup_file() {
    : "${LOOM_TEST_BASH:?LOOM_TEST_BASH is required}"
    : "${LOOM_EXPECTED_BASH_VERSION:?LOOM_EXPECTED_BASH_VERSION is required}"
    case "$LOOM_TEST_BASH" in /*) ;; *) return 1 ;; esac
    [ -x "$LOOM_TEST_BASH" ]
    [[ "$($LOOM_TEST_BASH -c 'printf %s "$BASH_VERSION"')" =~ $LOOM_EXPECTED_BASH_VERSION ]]
    REAL_ROOT="$(CDPATH='' cd -- "${BATS_TEST_DIRNAME}/.." && pwd -P)"
    export REAL_ROOT
}

# guard <json> -- runs the hook against the real (validated) Claude root
guard() {
    run env CLAUDE_PLUGIN_ROOT="$REAL_ROOT" "$LOOM_TEST_BASH" "$GUARD" <<<"$1"
}

# guard_codex <json> -- runs the hook against the real (validated) Codex root
guard_codex() {
    run env PLUGIN_ROOT="$REAL_ROOT" "$LOOM_TEST_BASH" "$GUARD" <<<"$1"
}

# ---------------------------------------------------------------------------
# BLOCK cases (exit 2) — identity override detected (Claude wire)
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

@test "BLOCK B09: --author= beside escaped inner quote" {
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

@test "BLOCK: stderr is a single control-character-free line ending in one LF" {
    guard '{"tool_input":{"command":"git commit --author=evil -m z"}}'
    [ "$status" -eq 2 ]
    [ "$output" = "loom identity guard: blocked --author override (ADR 0003 requires the uniform commit identity)." ]
}

# ---------------------------------------------------------------------------
# ALLOW cases (exit 0) — no identity override (Claude wire)
# ---------------------------------------------------------------------------

@test "ALLOW A01: plain commit, no override" {
    guard '{"tool_input":{"command":"git commit -m \"msg\""}}'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
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

# Accepted false positives: tokens are scanned in the raw text, quoted bodies
# included, so recognized tokens inside messages or read filters are blocked.
@test "BLOCK F05: author flag text inside message body (accepted false positive)" {
    guard '{"tool_input":{"command":"git commit -m \"fix --author= parsing\""}}'
    [ "$status" -eq 2 ]
}

@test "BLOCK F07: GIT_AUTHOR_NAME= inside message body (accepted false positive)" {
    guard '{"tool_input":{"command":"git commit -m \"set GIT_AUTHOR_NAME=foo in script\""}}'
    [ "$status" -eq 2 ]
}

@test "BLOCK F08: -c user.email= inside message body (accepted false positive)" {
    guard '{"tool_input":{"command":"git commit -m \"add -c user.email= override\""}}'
    [ "$status" -eq 2 ]
}

@test "BLOCK F09: --grep value naming the author flag (accepted false positive)" {
    guard '{"tool_input":{"command":"git log --grep=\"--author=\""}}'
    [ "$status" -eq 2 ]
}

@test "BLOCK F10: escaped-inner-quote message with author flag text" {
    guard '{"tool_input":{"command":"git commit -m \"use \\\"--author=\\\" flag carefully\""}}'
    [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# Wrapped commands, unbalanced quoting, env/-c variants
# ---------------------------------------------------------------------------

@test "BLOCK W01: author flag inside bash -c quoted body" {
    guard '{"tool_input":{"command":"bash -c \"git commit --author=x -m z\""}}'
    [ "$status" -eq 2 ]
}

@test "BLOCK W02: author flag inside sh -c single-quoted body" {
    guard '{"tool_input":{"command":"sh -c '"'"'git commit --author x -m z'"'"'"}}'
    [ "$status" -eq 2 ]
}

@test "BLOCK W03: env wrapper with GIT_COMMITTER_NAME assignment" {
    guard '{"tool_input":{"command":"env GIT_COMMITTER_NAME=x git commit -m z"}}'
    [ "$status" -eq 2 ]
}

@test "BLOCK W04: GIT_AUTHOR_DATE assignment" {
    guard '{"tool_input":{"command":"GIT_AUTHOR_DATE=2020-01-01 git commit -m z"}}'
    [ "$status" -eq 2 ]
}

@test "BLOCK W05: unbalanced quoting does not discard a recognized token" {
    guard '{"tool_input":{"command":"git commit --author=x -m \"wip"}}'
    [ "$status" -eq 2 ]
}

@test "BLOCK W06: -c author.name and -c committer.email overrides" {
    guard '{"tool_input":{"command":"git -c author.name=x commit -m z"}}'
    [ "$status" -eq 2 ]
    guard '{"tool_input":{"command":"git -c committer.email=x@y commit -m z"}}'
    [ "$status" -eq 2 ]
}

@test "BLOCK W07: -c with quoted user key inside bash -c" {
    guard '{"tool_input":{"command":"bash -c \"git -c user.name=x commit -m z\""}}'
    [ "$status" -eq 2 ]
}

@test "BLOCK W08: -c GIT_COMMITTER_EMAIL override" {
    guard '{"tool_input":{"command":"git -c GIT_COMMITTER_EMAIL=x commit -m z"}}'
    [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# git config identity writes (all scopes) vs safe reads
# ---------------------------------------------------------------------------

@test "BLOCK C01: git config user.name value (the two known reproductions)" {
    guard '{"tool_input":{"command":"git config user.name Foo"}}'
    [ "$status" -eq 2 ]
    guard '{"tool_input":{"command":"git config user.email x@y"}}'
    [ "$status" -eq 2 ]
}

@test "BLOCK C02: git config in each scope and file form" {
    for c in \
        'git config --local user.name Foo' \
        'git config --global user.email x@y' \
        'git config --system user.name Foo' \
        'git config --file .gitconfig user.email x@y' \
        'git config --global author.name Foo' \
        'git config committer.email x@y'; do
        guard "$(jq -nc --arg c "$c" '{tool_input:{command:$c}}')"
        [ "$status" -eq 2 ]
    done
}

@test "BLOCK C03: unset, replace-all, add and edit forms" {
    for c in \
        'git config --unset user.name' \
        'git config --global --unset-all user.email' \
        'git config --replace-all user.name Foo' \
        'git config --add user.email x@y' \
        'git config --edit --global user.name' \
        'git config --global --unset committer.name'; do
        guard "$(jq -nc --arg c "$c" '{tool_input:{command:$c}}')"
        [ "$status" -eq 2 ]
    done
}

@test "BLOCK C04: quoted value and wrapped git config write" {
    guard '{"tool_input":{"command":"git config user.name \"Foo Bar\""}}'
    [ "$status" -eq 2 ]
    guard '{"tool_input":{"command":"bash -c \"git config --global user.email x@y\""}}'
    [ "$status" -eq 2 ]
}

@test "BLOCK C05: write after a safe read on a later line" {
    guard '{"tool_input":{"command":"git config --get user.name\ngit config user.name Foo"}}'
    [ "$status" -eq 2 ]
}

@test "BLOCK C06: write after a safe read on the same line" {
    guard '{"tool_input":{"command":"git config --get user.name; git config user.name Evil"}}'
    [ "$status" -eq 2 ]
    guard '{"tool_input":{"command":"git config --get user.name && git config user.name Evil"}}'
    [ "$status" -eq 2 ]
    guard_codex '{"tool_input":{"command":"git config --get user.name; git config user.name Evil"}}'
    [ "$status" -eq 0 ]
    [[ "$output" == *'"permissionDecision":"deny"'* ]]
}

@test "BLOCK B12: quoted bare author flag (Claude and Codex wire)" {
    guard '{"tool_input":{"command":"git commit \u0027--author\u0027 \u0027Evil <evil@example.com>\u0027 -m z"}}'
    [ "$status" -eq 2 ]
    guard '{"tool_input":{"command":"git commit \"--author\" \"Evil <e@e>\" -m z"}}'
    [ "$status" -eq 2 ]
    guard_codex '{"tool_input":{"command":"git commit \u0027--author\u0027 \u0027Evil <evil@example.com>\u0027 -m z"}}'
    [ "$status" -eq 0 ]
    [[ "$output" == *'"permissionDecision":"deny"'* ]]
}

@test "ALLOW R01: bare reads of identity keys" {
    for c in \
        'git config user.name' \
        'git config user.email' \
        'git config --global user.name' \
        'git config --get user.email' \
        'git config --global --get user.name' \
        'git config --list' \
        'git config --get-all user.email' \
        'git config user.name && git commit -m z' \
        'git config --local user.email | cat'; do
        guard "$(jq -nc --arg c "$c" '{tool_input:{command:$c}}')"
        [ "$status" -eq 0 ]
        [ -z "$output" ]
    done
}

@test "ALLOW R02: non-identity git config writes are untouched" {
    guard '{"tool_input":{"command":"git config core.editor vim"}}'
    [ "$status" -eq 0 ]
    guard '{"tool_input":{"command":"git config --global pull.rebase true"}}'
    [ "$status" -eq 0 ]
}

@test "ALLOW R03: ordinary commit with message mentioning config in prose" {
    guard '{"tool_input":{"command":"git commit -m \"tidy config loading\""}}'
    [ "$status" -eq 0 ]
}

@test "codex BLOCK: wrapped author bypass and config write use the Codex envelope" {
    guard_codex '{"tool_input":{"command":"bash -c \"git config user.name x\""}}'
    [ "$status" -eq 0 ]
    [[ "$output" == '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"loom identity guard: blocked git config write'* ]]
    guard_codex '{"tool_input":{"command":"sh -c \"git commit --author=x\""}}'
    [ "$status" -eq 0 ]
    [[ "$output" == *'"permissionDecision":"deny"'* ]]
}

@test "ALLOW A13: unbalanced quoting with no recognized token still allows" {
    guard '{"tool_input":{"command":"git commit -m \"wip"}}'
    [ "$status" -eq 0 ]
}

@test "ALLOW A14: plain git push, no override token" {
    guard '{"tool_input":{"command":"git push"}}'
    [ "$status" -eq 0 ]
}

@test "ALLOW A15: missing tool_input.command (no target) allows, matching ADR 0003" {
    guard '{}'
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Codex wire — same policy decisions, Codex envelope (spec 08)
# ---------------------------------------------------------------------------

@test "codex ALLOW: exit 0, empty stdout/stderr" {
    guard_codex '{"tool_input":{"command":"git commit -m ok"}}'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "codex BLOCK: exit 0, empty stderr, exact hookSpecificOutput JSON on stdout" {
    guard_codex '{"tool_input":{"command":"git commit --author=evil -m z"}}'
    [ "$status" -eq 0 ]
    expected='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"loom identity guard: blocked --author override (ADR 0003 requires the uniform commit identity)."}}'
    [ "$output" = "$expected" ]
}

# ---------------------------------------------------------------------------
# Malformed input (spec 08 fixed reason) — fails closed through the client wire
# ---------------------------------------------------------------------------

@test "malformed: invalid JSON fails closed (claude)" {
    guard 'not json'
    [ "$status" -eq 2 ]
    [ "$output" = "Loom hook input invalid for pre-tool-use." ]
}

@test "malformed: invalid JSON fails closed (codex)" {
    guard_codex 'not json'
    [ "$status" -eq 0 ]
    expected='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Loom hook input invalid for pre-tool-use."}}'
    [ "$output" = "$expected" ]
}

@test "malformed: tool_input.command wrong type (number) fails closed" {
    guard '{"tool_input":{"command":42}}'
    [ "$status" -eq 2 ]
    [ "$output" = "Loom hook input invalid for pre-tool-use." ]
}

@test "malformed: tool_input.command wrong type (array) fails closed" {
    guard '{"tool_input":{"command":["git","commit"]}}'
    [ "$status" -eq 2 ]
    [ "$output" = "Loom hook input invalid for pre-tool-use." ]
}

@test "malformed: tool_input not an object fails closed" {
    guard '{"tool_input":"nope"}'
    [ "$status" -eq 2 ]
    [ "$output" = "Loom hook input invalid for pre-tool-use." ]
}

# ---------------------------------------------------------------------------
# Root/client selection (spec 10) — empty/ambiguous/mismatched roots
# ---------------------------------------------------------------------------

@test "root: neither PLUGIN_ROOT nor CLAUDE_PLUGIN_ROOT set fails closed" {
    run env -u CLAUDE_PLUGIN_ROOT -u PLUGIN_ROOT "$LOOM_TEST_BASH" "$GUARD" <<<'{"tool_input":{"command":"git commit -m ok"}}'
    [ "$status" -eq 2 ]
    [ "$output" = "Loom hook input invalid for pre-tool-use." ]
}

@test "root: both PLUGIN_ROOT and CLAUDE_PLUGIN_ROOT validate (ambiguous) fails closed" {
    run env PLUGIN_ROOT="$REAL_ROOT" CLAUDE_PLUGIN_ROOT="$REAL_ROOT" "$LOOM_TEST_BASH" "$GUARD" <<<'{"tool_input":{"command":"git commit -m ok"}}'
    [ "$status" -eq 2 ]
    [ "$output" = "Loom hook input invalid for pre-tool-use." ]
}

@test "root: CLAUDE_PLUGIN_ROOT pointing at a non-plugin directory fails closed" {
    NOTROOT="$(mktemp -d)"
    run env CLAUDE_PLUGIN_ROOT="$NOTROOT" "$LOOM_TEST_BASH" "$GUARD" <<<'{"tool_input":{"command":"git commit -m ok"}}'
    rm -rf "$NOTROOT"
    [ "$status" -eq 2 ]
    [ "$output" = "Loom hook input invalid for pre-tool-use." ]
}

@test "root: relative CLAUDE_PLUGIN_ROOT fails closed" {
    run env CLAUDE_PLUGIN_ROOT="relative/path" "$LOOM_TEST_BASH" "$GUARD" <<<'{"tool_input":{"command":"git commit -m ok"}}'
    [ "$status" -eq 2 ]
}

@test "jq absent: fails closed (no grep/sed fallback exists for root/JSON validation)" {
    stub="$(mktemp -d)"
    for t in cat sed tr wc grep dirname mv mkdir cd pwd; do
        for d in /usr/bin /bin; do
            [ -x "$d/$t" ] && {
                ln -s "$d/$t" "$stub/$t"
                break
            }
        done
    done
    run env PATH="$stub" CLAUDE_PLUGIN_ROOT="$REAL_ROOT" "$LOOM_TEST_BASH" "$GUARD" <<<'{"tool_input":{"command":"git commit -m ok"}}'
    rm -rf "$stub"
    [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# RED-GREEN sentinel — proves the malformed-command-type guard is exercised
# ---------------------------------------------------------------------------

@test "RED-GREEN: a well-typed command still allows while a wrong-typed one is rejected" {
    guard '{"tool_input":{"command":"git push"}}'
    [ "$status" -eq 0 ]
    guard '{"tool_input":{"command":7}}'
    [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# hook-wire-v1 fixture conformance (spec 08) — pre-tool-use half of the
# Cartesian product (claude/codex x allow/block/malformed); the precompact
# bats suite covers the pre-compact half. Byte-exact via cmp, not string
# comparison, so a trailing-newline/byte-count drift is caught too.
# ---------------------------------------------------------------------------

FIXTURE_ROOT="${BATS_TEST_DIRNAME}/fixtures/hook-wire-v1"

fixture_env_var() {
    case "$1" in
    codex) printf 'PLUGIN_ROOT' ;;
    herdr) printf 'HERDR_PLUGIN_ROOT' ;;
    *) printf 'CLAUDE_PLUGIN_ROOT' ;;
    esac
}

# assert_fixture <client> <case> — byte-compares stdout/stderr/exit for
# fixtures/hook-wire-v1/<client>/pre-tool-use/<case>.* against a live run.
assert_fixture() {
    local client="$1" case_name="$2" dir env_var out_file err_file actual_exit expected_exit
    dir="$FIXTURE_ROOT/$client/pre-tool-use"

    run jq -e '.tool_input | type == "object"' "$dir/$case_name.input.json"
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]

    env_var="$(fixture_env_var "$client")"
    out_file="$(mktemp)"
    err_file="$(mktemp)"
    # not wrapped in `run`: an unguarded nonzero exit here (the block cases
    # legitimately exit 2) would otherwise trip bats' own errexit and abort
    # the test before the byte comparisons run.
    env "$env_var=$REAL_ROOT" "$LOOM_TEST_BASH" "$GUARD" <"$dir/$case_name.input.json" >"$out_file" 2>"$err_file" && actual_exit=0 || actual_exit=$?
    expected_exit=$(tr -d '\n' <"$dir/$case_name.exit")

    cmp -s "$out_file" "$dir/$case_name.stdout"
    local stdout_match=$?
    cmp -s "$err_file" "$dir/$case_name.stderr"
    local stderr_match=$?
    rm -f "$out_file" "$err_file"

    [ "$actual_exit" -eq "$expected_exit" ]
    [ "$stdout_match" -eq 0 ]
    [ "$stderr_match" -eq 0 ]
}

@test "fixture claude/pre-tool-use/allow" { assert_fixture claude allow; }

@test "fixture claude/pre-tool-use/block" { assert_fixture claude block; }

@test "fixture claude/pre-tool-use/malformed" { assert_fixture claude malformed; }

@test "fixture codex/pre-tool-use/allow" { assert_fixture codex allow; }

@test "fixture codex/pre-tool-use/block" { assert_fixture codex block; }

@test "fixture codex/pre-tool-use/malformed" { assert_fixture codex malformed; }

@test "fixture herdr/pre-tool-use/allow" { assert_fixture herdr allow; }

@test "fixture herdr/pre-tool-use/block" { assert_fixture herdr block; }

@test "fixture herdr/pre-tool-use/malformed" { assert_fixture herdr malformed; }

# --- Herdr root selection matrix (ADR 0030): exactly one validated root ---

HERDR_OK='{"tool_input":{"command":"git commit -m ok"}}'
HERDR_BAD='{"tool_input":{"command":"git commit --author=x -m ok"}}'

herdr_run() { run env -u PLUGIN_ROOT -u CLAUDE_PLUGIN_ROOT -u HERDR_PLUGIN_ROOT "$@" "$LOOM_TEST_BASH" "$GUARD" <<<"$HERDR_OK"; }

mk_herdr_root() { # <dir> <name> <version>
    mkdir -p "$1/.herdr-plugin"
    printf '{"name":"%s","version":"%s"}\n' "$2" "$3" >"$1/.herdr-plugin/plugin.json"
}

@test "herdr root: valid root allows and blocks with the stderr wire" {
    herdr_run HERDR_PLUGIN_ROOT="$REAL_ROOT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run env -u PLUGIN_ROOT -u CLAUDE_PLUGIN_ROOT HERDR_PLUGIN_ROOT="$REAL_ROOT" "$LOOM_TEST_BASH" "$GUARD" <<<"$HERDR_BAD"
    [ "$status" -eq 2 ]
    [[ "$output" == "loom identity guard: blocked --author"* ]]
}

@test "herdr root: missing, relative, and non-plugin roots fail closed" {
    herdr_run
    [ "$status" -eq 2 ]
    [ "$output" = "Loom hook input invalid for pre-tool-use." ]
    herdr_run HERDR_PLUGIN_ROOT="relative/path"
    [ "$status" -eq 2 ]
    herdr_run HERDR_PLUGIN_ROOT="$BATS_TEST_TMPDIR"
    [ "$status" -eq 2 ]
}

@test "herdr root: wrong manifest name or version fails closed" {
    mk_herdr_root "$BATS_TEST_TMPDIR/n" other 0.2.0
    herdr_run HERDR_PLUGIN_ROOT="$BATS_TEST_TMPDIR/n"
    [ "$status" -eq 2 ]
    mk_herdr_root "$BATS_TEST_TMPDIR/v" loom 9.9.9
    herdr_run HERDR_PLUGIN_ROOT="$BATS_TEST_TMPDIR/v"
    [ "$status" -eq 2 ]
}

@test "herdr root: two or three validated roots are ambiguous and fail closed" {
    herdr_run HERDR_PLUGIN_ROOT="$REAL_ROOT" CLAUDE_PLUGIN_ROOT="$REAL_ROOT"
    [ "$status" -eq 2 ]
    herdr_run HERDR_PLUGIN_ROOT="$REAL_ROOT" PLUGIN_ROOT="$REAL_ROOT"
    [ "$status" -eq 2 ]
    herdr_run HERDR_PLUGIN_ROOT="$REAL_ROOT" PLUGIN_ROOT="$REAL_ROOT" CLAUDE_PLUGIN_ROOT="$REAL_ROOT"
    [ "$status" -eq 2 ]
    [ "$output" = "Loom hook input invalid for pre-tool-use." ]
}

@test "herdr root: a valid root alongside an invalid one still selects Herdr" {
    herdr_run HERDR_PLUGIN_ROOT="$REAL_ROOT" CLAUDE_PLUGIN_ROOT="$BATS_TEST_TMPDIR"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
