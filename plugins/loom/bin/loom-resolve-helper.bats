#!/usr/bin/env bats
# Test suite for loom-resolve-helper (spec 10 -> Installed-root and helper
# binding). Each test builds an isolated fake installed-plugin-root fixture so
# state never touches loom's own real .claude-plugin/.codex-plugin/bin trees.
# The code evaluator re-runs this suite as the shell gate's TEST step.
bats_require_minimum_version 1.5.0

RESOLVE="${BATS_TEST_DIRNAME}/loom-resolve-helper"

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

# make_root — build a fully valid fake installed-plugin root at $ROOT.
# ROOT is canonicalized at creation time (cd + pwd -P) so it matches the
# canonical form loom-resolve-helper resolves internally, independent of any
# platform-specific TMPDIR symlink (e.g. macOS /var -> /private/var).
make_root() {
    ROOT="$(mktemp -d)"
    ROOT="$(CDPATH='' cd -- "$ROOT" && pwd -P)"
    mkdir -p "$ROOT/.claude-plugin" "$ROOT/.codex-plugin" "$ROOT/skills/loom-run" "$ROOT/bin"
    printf '{"name":"loom","version":"0.2.0"}' >"$ROOT/.claude-plugin/plugin.json"
    printf '{"name":"loom","version":"0.2.0"}' >"$ROOT/.codex-plugin/plugin.json"
    printf -- '---\nname: loom-run\ndescription: x\n---\nbody\n' >"$ROOT/skills/loom-run/SKILL.md"
    printf '#!/usr/bin/env bash\necho hi\n' >"$ROOT/bin/loom-coord"
    chmod +x "$ROOT/bin/loom-coord"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$ROOT/bin/loom-verify-identity"
    chmod +x "$ROOT/bin/loom-verify-identity"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$ROOT/bin/loom-review"
    chmod +x "$ROOT/bin/loom-review"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$ROOT/bin/loom-eval-workspace"
    chmod +x "$ROOT/bin/loom-eval-workspace"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$ROOT/bin/loom-doctor"
    chmod +x "$ROOT/bin/loom-doctor"
    SKILL="$ROOT/skills/loom-run/SKILL.md"
}

teardown() {
    if [ -n "${ROOT:-}" ] && [ -d "$ROOT" ]; then rm -rf "$ROOT"; fi
    if [ -n "${OUTSIDE:-}" ] && [ -d "$OUTSIDE" ]; then rm -rf "$OUTSIDE"; fi
    return 0
}

resolve() {
    run "$LOOM_TEST_BASH" "$RESOLVE" "$@"
}

# resolve_env VAR=val [VAR=val ...] -- <loom-resolve-helper args...>
resolve_env() {
    local envs=()
    while [ "$1" != "--" ]; do
        envs+=("$1")
        shift
    done
    shift
    run env "${envs[@]}" "$LOOM_TEST_BASH" "$RESOLVE" "$@"
}

# ---------------------------------------------------------------------------
# Success paths
# ---------------------------------------------------------------------------

@test "claude: resolves loom-coord from a valid CLAUDE_PLUGIN_ROOT" {
    make_root
    CLAUDE_PLUGIN_ROOT="$ROOT" resolve claude loom-coord
    [ "$status" -eq 0 ]
    [ "$output" = "$ROOT/bin/loom-coord" ]
}

@test "claude: resolves loom-verify-identity from a valid CLAUDE_PLUGIN_ROOT" {
    make_root
    CLAUDE_PLUGIN_ROOT="$ROOT" resolve claude loom-verify-identity
    [ "$status" -eq 0 ]
    [ "$output" = "$ROOT/bin/loom-verify-identity" ]
}

@test "codex: resolves loom-verify-identity from a valid skill source path" {
    make_root
    resolve codex "$SKILL" loom-verify-identity
    [ "$status" -eq 0 ]
    [ "$output" = "$ROOT/bin/loom-verify-identity" ]
}

@test "claude: resolves loom-review from a valid CLAUDE_PLUGIN_ROOT" {
    make_root
    CLAUDE_PLUGIN_ROOT="$ROOT" resolve claude loom-review
    [ "$status" -eq 0 ]
    [ "$output" = "$ROOT/bin/loom-review" ]
}

@test "codex: resolves loom-review from a valid skill source path" {
    make_root
    resolve codex "$SKILL" loom-review
    [ "$status" -eq 0 ]
    [ "$output" = "$ROOT/bin/loom-review" ]
}

@test "claude: resolves loom-eval-workspace from a valid CLAUDE_PLUGIN_ROOT" {
    make_root
    CLAUDE_PLUGIN_ROOT="$ROOT" resolve claude loom-eval-workspace
    [ "$status" -eq 0 ]
    [ "$output" = "$ROOT/bin/loom-eval-workspace" ]
}

@test "claude: resolves loom-doctor from a valid CLAUDE_PLUGIN_ROOT" {
    make_root
    CLAUDE_PLUGIN_ROOT="$ROOT" resolve claude loom-doctor
    [ "$status" -eq 0 ]
    [ "$output" = "$ROOT/bin/loom-doctor" ]
}

@test "codex: resolves loom-doctor from a valid skill source path" {
    make_root
    resolve codex "$SKILL" loom-doctor
    [ "$status" -eq 0 ]
    [ "$output" = "$ROOT/bin/loom-doctor" ]
}

@test "codex: resolves loom-eval-workspace from a valid skill source path" {
    make_root
    resolve codex "$SKILL" loom-eval-workspace
    [ "$status" -eq 0 ]
    [ "$output" = "$ROOT/bin/loom-eval-workspace" ]
}

@test "codex: resolves loom-coord from a valid skill source path" {
    make_root
    resolve codex "$SKILL" loom-coord
    [ "$status" -eq 0 ]
    [ "$output" = "$ROOT/bin/loom-coord" ]
}

# ---------------------------------------------------------------------------
# Usage errors (exit 1)
# ---------------------------------------------------------------------------

@test "usage: unknown client fails closed with usage error" {
    resolve bogus loom-coord
    [ "$status" -eq 1 ]
}

@test "usage: missing arguments fails with usage error" {
    resolve claude
    [ "$status" -eq 1 ]
}

@test "usage: codex missing skill-source argument fails with usage error" {
    resolve codex
    [ "$status" -eq 1 ]
}

@test "usage: extra arguments fail with usage error" {
    make_root
    CLAUDE_PLUGIN_ROOT="$ROOT" resolve claude loom-coord extra
    [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# Claude negative paths
# ---------------------------------------------------------------------------

@test "claude: unset CLAUDE_PLUGIN_ROOT fails closed" {
    run env -u CLAUDE_PLUGIN_ROOT "$LOOM_TEST_BASH" "$RESOLVE" claude loom-coord
    [ "$status" -eq 2 ]
}

@test "claude: relative CLAUDE_PLUGIN_ROOT fails closed" {
    CLAUDE_PLUGIN_ROOT="relative/path" resolve claude loom-coord
    [ "$status" -eq 2 ]
}

@test "claude: helper not allowlisted fails closed" {
    make_root
    CLAUDE_PLUGIN_ROOT="$ROOT" resolve claude some-other-tool
    [ "$status" -eq 2 ]
}

@test "claude: wrong manifest name fails closed" {
    make_root
    printf '{"name":"not-loom","version":"0.2.0"}' >"$ROOT/.claude-plugin/plugin.json"
    CLAUDE_PLUGIN_ROOT="$ROOT" resolve claude loom-coord
    [ "$status" -eq 2 ]
}

@test "claude: wrong manifest version fails closed" {
    make_root
    printf '{"name":"loom","version":"9.9.9"}' >"$ROOT/.claude-plugin/plugin.json"
    CLAUDE_PLUGIN_ROOT="$ROOT" resolve claude loom-coord
    [ "$status" -eq 2 ]
}

@test "claude: malformed manifest JSON fails closed" {
    make_root
    printf 'not json' >"$ROOT/.claude-plugin/plugin.json"
    CLAUDE_PLUGIN_ROOT="$ROOT" resolve claude loom-coord
    [ "$status" -eq 2 ]
}

@test "claude: missing manifest fails closed" {
    make_root
    rm "$ROOT/.claude-plugin/plugin.json"
    CLAUDE_PLUGIN_ROOT="$ROOT" resolve claude loom-coord
    [ "$status" -eq 2 ]
}

@test "claude: manifest is a symlink escaping the root fails closed" {
    make_root
    OUTSIDE="$(mktemp -d)"
    printf '{"name":"loom","version":"0.2.0"}' >"$OUTSIDE/plugin.json"
    rm "$ROOT/.claude-plugin/plugin.json"
    ln -s "$OUTSIDE/plugin.json" "$ROOT/.claude-plugin/plugin.json"
    CLAUDE_PLUGIN_ROOT="$ROOT" resolve claude loom-coord
    [ "$status" -eq 2 ]
}

@test "claude: absent helper fails closed" {
    make_root
    rm "$ROOT/bin/loom-coord"
    CLAUDE_PLUGIN_ROOT="$ROOT" resolve claude loom-coord
    [ "$status" -eq 2 ]
}

@test "claude: non-executable helper fails closed" {
    make_root
    chmod -x "$ROOT/bin/loom-coord"
    CLAUDE_PLUGIN_ROOT="$ROOT" resolve claude loom-coord
    [ "$status" -eq 2 ]
}

@test "claude: helper symlink escaping the root fails closed" {
    make_root
    OUTSIDE="$(mktemp -d)"
    printf '#!/usr/bin/env bash\necho hi\n' >"$OUTSIDE/loom-coord"
    chmod +x "$OUTSIDE/loom-coord"
    rm "$ROOT/bin/loom-coord"
    ln -s "$OUTSIDE/loom-coord" "$ROOT/bin/loom-coord"
    CLAUDE_PLUGIN_ROOT="$ROOT" resolve claude loom-coord
    [ "$status" -eq 2 ]
}

@test "claude: helper directory symlink escaping the root fails closed" {
    make_root
    OUTSIDE="$(mktemp -d)"
    printf '#!/usr/bin/env bash\necho hi\n' >"$OUTSIDE/loom-coord"
    chmod +x "$OUTSIDE/loom-coord"
    rm -rf "${ROOT:?}/bin"
    ln -s "$OUTSIDE" "$ROOT/bin"
    CLAUDE_PLUGIN_ROOT="$ROOT" resolve claude loom-coord
    [ "$status" -eq 2 ]
}

@test "claude: helper found only as a nested (non-direct) child fails closed" {
    make_root
    mkdir -p "$ROOT/bin/nested"
    mv "$ROOT/bin/loom-coord" "$ROOT/bin/nested/loom-coord"
    ln -s "nested/loom-coord" "$ROOT/bin/loom-coord"
    CLAUDE_PLUGIN_ROOT="$ROOT" resolve claude loom-coord
    [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# Codex negative paths
# ---------------------------------------------------------------------------

@test "codex: relative skill source path fails closed" {
    make_root
    resolve codex "skills/loom-run/SKILL.md" loom-coord
    [ "$status" -eq 2 ]
}

@test "codex: empty skill source path fails closed" {
    resolve codex "" loom-coord
    [ "$status" -eq 2 ]
}

@test "codex: missing skill source file fails closed" {
    make_root
    resolve codex "$ROOT/skills/loom-run/MISSING.md" loom-coord
    [ "$status" -eq 2 ]
}

@test "codex: wrong suffix (not skills/<skill>/SKILL.md) fails closed" {
    make_root
    mv "$ROOT/skills/loom-run/SKILL.md" "$ROOT/skills/loom-run/NOTASKILL.md"
    resolve codex "$ROOT/skills/loom-run/NOTASKILL.md" loom-coord
    [ "$status" -eq 2 ]
}

@test "codex: nested skill segment (extra path component) fails closed" {
    make_root
    mkdir -p "$ROOT/skills/loom-run/nested"
    cp "$SKILL" "$ROOT/skills/loom-run/nested/SKILL.md"
    resolve codex "$ROOT/skills/loom-run/nested/SKILL.md" loom-coord
    [ "$status" -eq 2 ]
}

@test "codex: frontmatter name mismatched with directory fails closed" {
    make_root
    printf -- '---\nname: wrong-name\ndescription: x\n---\nbody\n' >"$SKILL"
    resolve codex "$SKILL" loom-coord
    [ "$status" -eq 2 ]
}

@test "codex: manifest name mismatch fails closed" {
    make_root
    printf '{"name":"not-loom","version":"0.2.0"}' >"$ROOT/.codex-plugin/plugin.json"
    resolve codex "$SKILL" loom-coord
    [ "$status" -eq 2 ]
}

@test "codex: manifest version mismatch fails closed" {
    make_root
    printf '{"name":"loom","version":"9.9.9"}' >"$ROOT/.codex-plugin/plugin.json"
    resolve codex "$SKILL" loom-coord
    [ "$status" -eq 2 ]
}

@test "codex: missing manifest fails closed" {
    make_root
    rm "$ROOT/.codex-plugin/plugin.json"
    resolve codex "$SKILL" loom-coord
    [ "$status" -eq 2 ]
}

@test "codex: skill source symlink escaping the root fails closed" {
    make_root
    OUTSIDE="$(mktemp -d)"
    mkdir -p "$OUTSIDE/skills/loom-run"
    printf -- '---\nname: loom-run\ndescription: x\n---\nbody\n' >"$OUTSIDE/skills/loom-run/SKILL.md"
    rm "$SKILL"
    ln -s "$OUTSIDE/skills/loom-run/SKILL.md" "$SKILL"
    resolve codex "$SKILL" loom-coord
    [ "$status" -eq 2 ]
}

@test "codex: absent helper fails closed" {
    make_root
    rm "$ROOT/bin/loom-coord"
    resolve codex "$SKILL" loom-coord
    [ "$status" -eq 2 ]
}

@test "codex: non-executable helper fails closed" {
    make_root
    chmod -x "$ROOT/bin/loom-coord"
    resolve codex "$SKILL" loom-coord
    [ "$status" -eq 2 ]
}

@test "codex: helper not allowlisted fails closed" {
    make_root
    resolve codex "$SKILL" some-other-tool
    [ "$status" -eq 2 ]
}

@test "codex: never consults CLAUDE_PLUGIN_ROOT/PLUGIN_ROOT/CODEX_HOME" {
    make_root
    resolve_env CLAUDE_PLUGIN_ROOT="/nonexistent-claude-root" \
        PLUGIN_ROOT="/nonexistent-plugin-root" \
        CODEX_HOME="/nonexistent-codex-home" \
        -- codex "$SKILL" loom-coord
    [ "$status" -eq 0 ]
    [ "$output" = "$ROOT/bin/loom-coord" ]
}

@test "static: the Codex resolution path never references PATH/CLAUDE_PLUGIN_ROOT/PLUGIN_ROOT/CODEX_HOME for root identity" {
    # Extract only the _resolve_codex function body and prove it never reads
    # a forbidden environment-only root guess (PATH search, CLAUDE_PLUGIN_ROOT,
    # PLUGIN_ROOT, or CODEX_HOME). Root identity there comes solely from the
    # explicit absolute skill-source argument.
    run awk '/^_resolve_codex\(\)/{p=1} p{print} p&&/^}/{exit}' "$RESOLVE"
    [ "$status" -eq 0 ]
    ! printf '%s\n' "$output" | grep -Eq '\$\{?(CLAUDE_PLUGIN_ROOT|PLUGIN_ROOT|CODEX_HOME|PATH)\b'
}

@test "codex: a forbidden environment-only guess cannot substitute for a missing source argument" {
    make_root
    resolve_env PLUGIN_ROOT="$ROOT" -- codex
    [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# Working-directory independence
# ---------------------------------------------------------------------------

@test "claude: resolution is independent of the caller's working directory" {
    make_root
    run env CLAUDE_PLUGIN_ROOT="$ROOT" "$LOOM_TEST_BASH" -c 'cd /tmp && exec "$1" claude loom-coord' -- "$RESOLVE"
    [ "$status" -eq 0 ]
    [ "$output" = "$ROOT/bin/loom-coord" ]
}

@test "codex: resolution is independent of the caller's working directory" {
    make_root
    run "$LOOM_TEST_BASH" -c 'cd /tmp && exec "$1" codex "$2" loom-coord' -- "$RESOLVE" "$SKILL"
    [ "$status" -eq 0 ]
    [ "$output" = "$ROOT/bin/loom-coord" ]
}

# ---------------------------------------------------------------------------
# RED-GREEN sentinels: prove each negative test's failure path is exercised
# ---------------------------------------------------------------------------

@test "RED-GREEN: an allowlisted-but-nonexistent helper name would resolve if the allowlist check were removed" {
    make_root
    # Sanity: the fixture root is otherwise fully valid; only the allowlist
    # check distinguishes an accepted vs rejected helper name.
    CLAUDE_PLUGIN_ROOT="$ROOT" resolve claude loom-coord
    [ "$status" -eq 0 ]
    CLAUDE_PLUGIN_ROOT="$ROOT" resolve claude not-allowlisted
    [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# Antigravity positive & negative paths
# ---------------------------------------------------------------------------

@test "antigravity: resolves loom-coord from plugins/loom/skills/<skill>/SKILL.md" {
    make_root
    resolve antigravity "$SKILL" loom-coord
    [ "$status" -eq 0 ]
    [ "$output" = "$ROOT/bin/loom-coord" ]
}

@test "antigravity: resolves loom-coord from .agents/skills/<skill>/SKILL.md in a repo root" {
    ROOT="$(mktemp -d)"
    ROOT="$(CDPATH='' cd -- "$ROOT" && pwd -P)"
    mkdir -p "$ROOT/.agents/skills/loom-run" "$ROOT/plugins/loom/.claude-plugin" "$ROOT/plugins/loom/.codex-plugin" "$ROOT/plugins/loom/skills/loom-run" "$ROOT/plugins/loom/bin"
    printf '{"name":"loom","version":"0.2.0"}' >"$ROOT/plugins/loom/.claude-plugin/plugin.json"
    printf '{"name":"loom","version":"0.2.0"}' >"$ROOT/plugins/loom/.codex-plugin/plugin.json"
    printf -- '---\nname: loom-run\ndescription: x\n---\nbody\n' >"$ROOT/.agents/skills/loom-run/SKILL.md"
    printf -- '---\nname: loom-run\ndescription: x\n---\nbody\n' >"$ROOT/plugins/loom/skills/loom-run/SKILL.md"
    printf '#!/usr/bin/env bash\necho hi\n' >"$ROOT/plugins/loom/bin/loom-coord"
    chmod +x "$ROOT/plugins/loom/bin/loom-coord"
    resolve antigravity "$ROOT/.agents/skills/loom-run/SKILL.md" loom-coord
    [ "$status" -eq 0 ]
    [ "$output" = "$ROOT/plugins/loom/bin/loom-coord" ]
}

@test "antigravity: frontmatter name mismatch in .agents/skills/<skill>/SKILL.md fails closed" {
    ROOT="$(mktemp -d)"
    ROOT="$(CDPATH='' cd -- "$ROOT" && pwd -P)"
    mkdir -p "$ROOT/.agents/skills/loom-run" "$ROOT/plugins/loom/.claude-plugin" "$ROOT/plugins/loom/.codex-plugin" "$ROOT/plugins/loom/bin"
    printf '{"name":"loom","version":"0.2.0"}' >"$ROOT/plugins/loom/.claude-plugin/plugin.json"
    printf '{"name":"loom","version":"0.2.0"}' >"$ROOT/plugins/loom/.codex-plugin/plugin.json"
    printf -- '---\nname: wrong-name\ndescription: x\n---\nbody\n' >"$ROOT/.agents/skills/loom-run/SKILL.md"
    printf '#!/usr/bin/env bash\necho hi\n' >"$ROOT/plugins/loom/bin/loom-coord"
    chmod +x "$ROOT/plugins/loom/bin/loom-coord"
    resolve antigravity "$ROOT/.agents/skills/loom-run/SKILL.md" loom-coord
    [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# Herdr retired (ADR 0031 §7): herdr is not a resolution mode, even with a valid root
# ---------------------------------------------------------------------------

@test "herdr: retired mode is a usage error even with a valid HERDR_PLUGIN_ROOT" {
    make_root
    HERDR_PLUGIN_ROOT="$ROOT" resolve herdr loom-coord
    [ "$status" -eq 1 ]
}
