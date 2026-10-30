#!/usr/bin/env bats
# Test suite for loom-land (remote-first integration candidate, ADR 0020).
# Every test builds an isolated bare remote plus local clones; no network is used.
bats_require_minimum_version 1.5.0

LAND="${BATS_TEST_DIRNAME}/loom-land"
COORD="${BATS_TEST_DIRNAME}/loom-coord"

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
    REMOTE="$WORK/remote.git"
    REPO="$WORK/repo"
    OTHER="$WORK/other"
    GATE="test -f feature.txt"
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
    git init -q --bare -b main "$REMOTE"
    git clone -q "$REMOTE" "$REPO" 2>/dev/null
    git_cfg "$REPO"
    printf 'base\n' >"$REPO/base.txt"
    git -C "$REPO" add base.txt
    git -C "$REPO" commit -q -m base
    git -C "$REPO" branch -M main
    git -C "$REPO" push -q origin main
    git clone -q "$REMOTE" "$OTHER" 2>/dev/null
    git_cfg "$OTHER"
    # Slice branch with the feature, then back to main.
    git -C "$REPO" checkout -q -b slice-a
    printf 'feature\n' >"$REPO/feature.txt"
    git -C "$REPO" add feature.txt
    git -C "$REPO" commit -q -m feature
    HEAD_SHA="$(git -C "$REPO" rev-parse HEAD)"
    git -C "$REPO" checkout -q main
    SDIR="$REPO/.git/loom/session-s1"
    coordr session-start --session s1 >/dev/null
    coordr lock-acquire --session s1 >/dev/null
    coordr claim slice-a --session s1 >/dev/null
    coordr lock-release --session s1 >/dev/null
}

teardown() {
    if [ -n "${WORK:-}" ] && [ -d "$WORK" ]; then
        rm -rf "$WORK"
    fi
    return 0
}

git_cfg() {
    git -C "$1" config user.email test@example.com
    git -C "$1" config user.name Test
}

coordr() { (cd "$REPO" && "$LOOM_TEST_BASH" "$COORD" "$@"); }

# land [args...] — run loom-land with the standard inputs; extra args override/append.
land() {
    run --separate-stderr "$LOOM_TEST_BASH" "$LAND" --repo "$REPO" --remote origin \
        --target-ref refs/heads/main --mode remote-direct --slice slice-a --session s1 \
        --head "$HEAD_SHA" --gate "$GATE" "$@"
}

# evidence <sha> [gate] [review-hash] — write $WORK/ev.json
evidence() {
    printf '{"schema":"loom-evidence/v1","candidateSha":"%s","gate":"%s","gateEvidenceSha256":"%s","reviewEvidenceSha256":"%s"}\n' \
        "$1" "${2:-$GATE}" "$(printf 'a%.0s' $(seq 1 64))" "${3:-$(printf 'b%.0s' $(seq 1 64))}" >"$WORK/ev.json"
}

# prepare — candidate-only run; sets CAND and writes matching evidence
prepare() {
    land --candidate-only
    [ "$status" -eq 0 ]
    CAND="$output"
    evidence "$CAND"
}

# other_push <file> — commit a new file on main from the other clone and push it
other_push() {
    git -C "$OTHER" pull -q origin main 2>/dev/null
    printf '%s\n' "$1" >"$OTHER/$1"
    git -C "$OTHER" add "$1"
    git -C "$OTHER" commit -q -m "other $1"
    git -C "$OTHER" push -q origin main
}

remote_main() { git -C "$REMOTE" rev-parse refs/heads/main; }
claims() { coordr list-claims; }

# stub_coord <body> — LOOM_COORD_BIN wrapper; $1 is the subcommand, then delegates to the real helper
stub_coord() {
    STUB="$WORK/coord-stub"
    {
        printf '#!/usr/bin/env bash\n'
        printf '%s\n' "$1"
        printf 'exec "%s" "%s" "$@"\n' "$LOOM_TEST_BASH" "$COORD"
    } >"$STUB"
    chmod +x "$STUB"
    export LOOM_COORD_BIN="$STUB"
}

count_hook() {
    mkdir -p "$REMOTE/hooks"
    printf '#!/bin/sh\necho x >>"%s/pushes"\ntouch "%s/push-done"\n' "$WORK" "$WORK" >"$REMOTE/hooks/post-receive"
    chmod +x "$REMOTE/hooks/post-receive"
}

pushes() { wc -l <"$WORK/pushes" 2>/dev/null | tr -d ' ' || echo 0; }

# ---- usage / input validation -------------------------------------------

@test "no arguments is a usage error" {
    run --separate-stderr "$LOOM_TEST_BASH" "$LAND"
    [ "$status" -eq 1 ]
}

@test "relative invocation is rejected" {
    run --separate-stderr bash -c "cd '$BATS_TEST_DIRNAME' && '$LOOM_TEST_BASH' ./loom-land --repo '$REPO'"
    [ "$status" -eq 1 ]
    [[ "$stderr" == *"absolute path"* ]]
}

@test "unsupported mode, bad ref, bad ids and bad head fail before mutation" {
    land --mode pr --candidate-only
    [ "$status" -eq 1 ]
    land --target-ref main --candidate-only
    [ "$status" -eq 1 ]
    land --slice '../x' --candidate-only
    [ "$status" -eq 1 ]
    land --head deadbeefdeadbeefdeadbeefdeadbeefdeadbeef --candidate-only
    [ "$status" -eq 1 ]
    land --remote nosuch --candidate-only
    [ "$status" -eq 1 ]
    land --bogus
    [ "$status" -eq 1 ]
    [ ! -e "$SDIR/candidate.json" ]
}

@test "publication without evidence is rejected" {
    land
    [ "$status" -eq 1 ]
    [[ "$stderr" == *"--evidence"* ]]
}

@test "session without the claim is an ownership failure" {
    land --session s2 --candidate-only
    [ "$status" -eq 5 ]
}

# ---- evidence validation ---------------------------------------------------

@test "evidence mismatches fail closed with exit 1 and leave the remote untouched" {
    prepare
    before="$(remote_main)"
    evidence "$(printf 'c%.0s' $(seq 1 40))"
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 1 ]
    [[ "$stderr" == *"does not match candidate"* ]]
    evidence "$CAND" "other-gate"
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 1 ]
    evidence "$CAND" "$GATE" "not-hex"
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 1 ]
    printf '{"schema":"loom-evidence/v0"}\n' >"$WORK/ev.json"
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 1 ]
    [ "$(remote_main)" = "$before" ]
    [ -n "$(claims)" ]
}

# ---- candidate-only ----------------------------------------------------------

@test "candidate-only builds, gates, records state, cleans up and does not publish" {
    before="$(remote_main)"
    land --candidate-only
    [ "$status" -eq 0 ]
    [ "$(remote_main)" = "$before" ]
    [ "$(jq -r .candidateSha "$SDIR/candidate.json")" = "$output" ]
    [ "$(jq -r .baseCommit "$SDIR/candidate.json")" = "$before" ]
    [ "$(jq -r .sliceHead "$SDIR/candidate.json")" = "$HEAD_SHA" ]
    git -C "$REPO" cat-file -e "$output:feature.txt"
    jq -e '.slice == "slice-a" and .mode == "remote-direct"' "$SDIR/candidate-manifest.json"
    ! git -C "$REPO" ls-tree -r --name-only "$output" | grep -q '^\.loom/'
    [ -z "$(git -C "$REPO" branch --list 'loom-land/*')" ]
    [ ! -d "$REPO/.git/loom/land-s1/wt" ]
    [ -n "$(claims)" ]
}

@test "candidate-only twice reuses the exact candidate commit" {
    land --candidate-only
    first="$output"
    land --candidate-only
    [ "$output" = "$first" ]
}

@test "gate failure exits 10, preserves state and claim" {
    land --candidate-only --gate "false"
    [ "$status" -eq 10 ]
    [ -f "$SDIR/candidate.json" ]
    [ -n "$(claims)" ]
}

@test "a gate that dirties the candidate exits 10" {
    land --candidate-only --gate "touch junk.txt"
    [ "$status" -eq 10 ]
    [ -n "$(claims)" ]
}

@test "stale disposable branch is cleaned idempotently" {
    git -C "$REPO" branch loom-land/s1-slice-a main
    land --candidate-only
    [ "$status" -eq 0 ]
    land --candidate-only
    [ "$status" -eq 0 ]
}

# ---- publication ---------------------------------------------------------------

@test "clean publication pushes, verifies, receipts, releases the claim and updates the mirror" {
    count_hook
    prepare
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 0 ]
    [ "$output" = "landed $CAND" ]
    [ "$(remote_main)" = "$CAND" ]
    [ "$(pushes)" = 1 ]
    r="$SDIR/publication-receipt.json"
    [ "$(jq -r .candidateSha "$r")" = "$CAND" ]
    [ "$(jq -r .resultSha "$r")" = "$CAND" ]
    [ "$(jq -r .verification "$r")" = verified ]
    [ "$(jq -r .sliceHead "$r")" = "$HEAD_SHA" ]
    [ "$(jq -r .schema "$r")" = "loom-receipt/v1" ]
    [ "$(jq -r .reviewEvidenceSha256 "$r")" = "$(jq -r .reviewEvidenceSha256 "$WORK/ev.json")" ]
    [ -z "$(claims)" ]
    [ -z "$(coordr lock-holder)" ]
    [ -z "$(git -C "$REPO" branch --list 'loom-land/*')" ]
    [ "$(git -C "$REPO" rev-parse main)" = "$CAND" ]
}

@test "dirty, ahead and stale local main cannot enter the candidate" {
    other_push stale.txt
    printf 'local\n' >"$REPO/local.txt"
    git -C "$REPO" add local.txt
    git -C "$REPO" commit -q -m "local only"
    printf 'dirty\n' >>"$REPO/base.txt"
    prepare
    ! git -C "$REPO" cat-file -e "$CAND:local.txt" 2>/dev/null
    [ "$(git -C "$REPO" show "$CAND:base.txt")" = base ]
    git -C "$REPO" cat-file -e "$CAND:stale.txt"
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 0 ]
    [ "$(remote_main)" = "$CAND" ]
    # Mirror was not fast-forwardable: local work and dirt are intact, publication unaffected.
    git -C "$REPO" cat-file -e main:local.txt
    grep -q dirty "$REPO/base.txt"
}

@test "target movement before publication rebuilds, exits 3 and needs fresh evidence" {
    prepare
    other_push moved.txt
    moved="$(remote_main)"
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 3 ]
    [[ "$stderr" == *"fresh review evidence"* ]]
    [ "$(remote_main)" = "$moved" ]
    new="$(jq -r .candidateSha "$SDIR/candidate.json")"
    [ "$new" != "$CAND" ]
    [ "$(jq -r .baseCommit "$SDIR/candidate.json")" = "$moved" ]
    [ -n "$(claims)" ]
    [ -z "$(coordr lock-holder)" ]
    evidence "$new"
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 0 ]
    [ "$(remote_main)" = "$new" ]
    git -C "$REMOTE" cat-file -e "$new:moved.txt"
}

@test "target movement while acquiring the lock rebuilds and exits 3" {
    prepare
    stub_coord "if [ \"\$1\" = lock-acquire ] && [ ! -e '$WORK/moved' ]; then touch '$WORK/moved'; ( cd '$OTHER' && git pull -q origin main && echo m >m.txt && git add m.txt && git commit -q -m m && git push -q origin main ) >/dev/null 2>&1; fi"
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 3 ]
    [ "$(jq -r .candidateSha "$SDIR/candidate.json")" != "$CAND" ]
    [ "$(remote_main)" != "$CAND" ]
    [ -n "$(claims)" ]
    [ -z "$(coordr lock-holder)" ]
}

@test "non-fast-forward push race is rejected without force and keeps the claim" {
    prepare
    stub_coord "if [ \"\$1\" = lock-verify ] && [ ! -e '$WORK/raced' ]; then touch '$WORK/raced'; ( cd '$OTHER' && git pull -q origin main && echo r >r.txt && git add r.txt && git commit -q -m r && git push -q origin main ) >/dev/null 2>&1; fi"
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 3 ]
    [[ "$stderr" == *"push rejected"* ]]
    git -C "$REMOTE" cat-file -e main:r.txt
    ! git -C "$REMOTE" merge-base --is-ancestor "$CAND" main
    [ -n "$(claims)" ]
    [ -z "$(coordr lock-holder)" ]
}

@test "merge conflict exits 3 and keeps the claim" {
    git -C "$REPO" checkout -q slice-a
    printf 'slice change\n' >"$REPO/base.txt"
    git -C "$REPO" commit -q -am "slice edits base"
    HEAD_SHA="$(git -C "$REPO" rev-parse HEAD)"
    git -C "$REPO" checkout -q main
    git -C "$OTHER" pull -q origin main
    printf 'other change\n' >"$OTHER/base.txt"
    git -C "$OTHER" commit -q -am "other edits base"
    git -C "$OTHER" push -q origin main
    land --candidate-only
    [ "$status" -eq 3 ]
    [ -n "$(claims)" ]
    [ -z "$(git -C "$REPO" branch --list 'loom-land/*')" ]
}

@test "lock contention exits 3 and keeps the claim" {
    prepare
    (cd "$REPO" && "$COORD" session-start --session s2 >/dev/null && "$COORD" lock-acquire --session s2 >/dev/null)
    LOOM_LOCK_RETRIES=1 land --evidence "$WORK/ev.json"
    [ "$status" -eq 3 ]
    [ "$(remote_main)" != "$CAND" ]
    [ -n "$(claims)" ]
    [ "$(coordr lock-holder | cut -f1)" = s2 ]
}

@test "lock loss after a verified push is recovered without a second push" {
    count_hook
    prepare
    stub_coord "if [ \"\$1\" = lock-verify ] && [ -e '$WORK/push-done' ]; then exit 5; fi"
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 10 ]
    [ "$(remote_main)" = "$CAND" ]
    [ -f "$SDIR/publication-receipt.json" ]
    [ -n "$(claims)" ]
    unset LOOM_COORD_BIN
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 0 ]
    [ "$(pushes)" = 1 ]
    [ -z "$(claims)" ]
}

@test "recovery reconstructs a missing receipt when the candidate is already on the remote" {
    prepare
    git -C "$REPO" push -q origin "$CAND:refs/heads/main"
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 0 ]
    [ "$(jq -r .push "$SDIR/publication-receipt.json")" = recovered ]
    [ -z "$(claims)" ]
}

@test "re-running after success is idempotent" {
    count_hook
    prepare
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 0 ]
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 0 ]
    [ "$(pushes)" = 1 ]
    [ -z "$(claims)" ]
    [ -z "$(git -C "$REPO" branch --list 'loom-land/*')" ]
}

@test "unverifiable push (remote rewrites the ref) exits 10 and keeps the claim" {
    prepare
    printf '#!/bin/sh\nexit 1\n' >"$REMOTE/hooks/update"
    chmod +x "$REMOTE/hooks/update"
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 10 ]
    [ "$(remote_main)" != "$CAND" ]
    [ -n "$(claims)" ]
    [ ! -f "$SDIR/publication-receipt.json" ]
}

@test "recovery rejects a receipt left by a different slice and writes a current one" {
    prepare
    git -C "$REPO" push -q origin "$CAND:refs/heads/main"
    mkdir -p "$SDIR"
    jq -n '{schema: "loom-receipt/v1", slice: "slice-old", session: "s1", candidateSha: "deadbeef"}' >"$SDIR/publication-receipt.json"
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 0 ]
    [ "$(jq -r .slice "$SDIR/publication-receipt.json")" = slice-a ]
    [ "$(jq -r .candidateSha "$SDIR/publication-receipt.json")" = "$CAND" ]
    [ -z "$(claims)" ]
}

@test "stale receipt from another slice cannot release a claim without the claim" {
    prepare
    git -C "$REPO" push -q origin "$CAND:refs/heads/main"
    coordr lock-acquire --session s1 >/dev/null
    coordr release-claim slice-a --session s1 >/dev/null
    coordr lock-release --session s1 >/dev/null
    jq -n '{slice: "slice-old", session: "s1", candidateSha: "deadbeef"}' >"$SDIR/publication-receipt.json"
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 5 ]
    [ "$(jq -r .slice "$SDIR/publication-receipt.json")" = slice-old ]
}

@test "recovery after remote advancement records the observed target as resultSha" {
    prepare
    git -C "$REPO" push -q origin "$CAND:refs/heads/main"
    other_push later.txt
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 0 ]
    [ "$(jq -r .resultSha "$SDIR/publication-receipt.json")" = "$(remote_main)" ]
    [ "$(remote_main)" != "$CAND" ]
    [ -z "$(claims)" ]
}

@test "recovery receipt write requires the publish lock" {
    prepare
    git -C "$REPO" push -q origin "$CAND:refs/heads/main"
    (cd "$REPO" && "$COORD" session-start --session s2 >/dev/null && "$COORD" lock-acquire --session s2 >/dev/null)
    LOOM_LOCK_RETRIES=1 land --evidence "$WORK/ev.json"
    [ "$status" -eq 3 ]
    [ ! -f "$SDIR/publication-receipt.json" ]
    [ -n "$(claims)" ]
}

@test "uncertain prior push not contained in the target stops for owner action" {
    prepare
    printf '#!/bin/sh\nexit 1\n' >"$REMOTE/hooks/update"
    chmod +x "$REMOTE/hooks/update"
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 10 ]
    [ "$(jq -r .publishAttempt "$SDIR/candidate.json")" = true ]
    rm "$REMOTE/hooks/update"
    other_push moved.txt
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 10 ]
    [ "$(jq -r .candidateSha "$SDIR/candidate.json")" = "$CAND" ]
    [ "$(git -C "$REPO" rev-parse refs/loom/land/s1/candidate)" = "$CAND" ]
    [ -n "$(claims)" ]
}

@test "verification reads the push destination, not the fetch URL" {
    prepare
    git init -q --bare -b main "$WORK/mirror.git"
    git -C "$REPO" push -q "$WORK/mirror.git" main
    git -C "$REPO" config remote.origin.pushurl "$WORK/mirror.git"
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 0 ]
    [ "$(git -C "$WORK/mirror.git" rev-parse refs/heads/main)" = "$CAND" ]
    [ "$(remote_main)" != "$CAND" ]
}

@test "rejected push to a distinct pushurl is not verified from the fetch repository" {
    prepare
    git -C "$REPO" push -q origin "$CAND:refs/heads/side"
    git init -q --bare -b main "$WORK/mirror.git"
    git -C "$REPO" push -q "$WORK/mirror.git" main
    printf '#!/bin/sh\nexit 1\n' >"$WORK/mirror.git/hooks/update"
    chmod +x "$WORK/mirror.git/hooks/update"
    git -C "$REPO" config remote.origin.pushurl "$WORK/mirror.git"
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 10 ]
    [ ! -f "$SDIR/publication-receipt.json" ]
    [ -n "$(claims)" ]
}

@test "operational git failure while building the candidate exits 10 and keeps the claim" {
    REAL_GIT="$(command -v git)"
    mkdir -p "$WORK/fakebin"
    printf '#!/bin/sh\ncase " $* " in *" worktree add "*) exit 1 ;; esac\nexec "%s" "$@"\n' "$REAL_GIT" >"$WORK/fakebin/git"
    chmod +x "$WORK/fakebin/git"
    PATH="$WORK/fakebin:$PATH" land --candidate-only
    [ "$status" -eq 10 ]
    [ -n "$(claims)" ]
}

@test "recovery verifies containment against the push destination, not the fetch URL" {
    prepare
    git init -q --bare -b main "$WORK/mirror.git"
    git -C "$REPO" push -q "$WORK/mirror.git" main
    git -C "$REPO" config remote.origin.pushurl "$WORK/mirror.git"
    # The candidate sits on the fetch remote only; the push destination does not contain it.
    git -C "$REPO" push -q "$REMOTE" "$CAND:refs/heads/main"
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 0 ]
    [ "$(git -C "$WORK/mirror.git" rev-parse refs/heads/main)" = "$CAND" ]
    [ "$(jq -r .push "$SDIR/publication-receipt.json")" = pushed ]
}

@test "recovery rejects a receipt whose bindings differ and writes a current one" {
    prepare
    git -C "$REPO" push -q origin "$CAND:refs/heads/main"
    jq -n --arg c "$CAND" --arg h "$HEAD_SHA" '{schema: "loom-receipt/v1", slice: "slice-a", session: "s1",
        remote: "origin", targetRef: "refs/heads/main", mode: "remote-direct", candidateSha: $c, sliceHead: $h,
        gateEvidenceSha256: "0", reviewEvidenceSha256: "0"}' >"$SDIR/publication-receipt.json"
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 0 ]
    [ "$(jq -r .push "$SDIR/publication-receipt.json")" = recovered ]
    [ "$(jq -r .gateEvidenceSha256 "$SDIR/publication-receipt.json")" = "$(printf 'a%.0s' $(seq 1 64))" ]
    [ -z "$(claims)" ]
}

@test "receipt write failure exits 10 and preserves state and claim" {
    prepare
    # The push succeeds, then the session directory becomes read-only before the receipt is written.
    printf '#!/bin/sh\nchmod a-w "%s"\n' "$SDIR" >"$REMOTE/hooks/post-receive"
    chmod +x "$REMOTE/hooks/post-receive"
    land --evidence "$WORK/ev.json"
    chmod u+w "$SDIR"
    [ ! -f "$SDIR/publication-receipt.json" ]
    [ "$status" -eq 10 ]
    [ "$(jq -r .candidateSha "$SDIR/candidate.json")" = "$CAND" ]
    [ "$(jq -r .publishAttempt "$SDIR/candidate.json")" = true ]
    [ -n "$(claims)" ]
}

@test "unwritable session directory exits 10" {
    rm -rf "$SDIR"
    printf 'x' >"$SDIR"
    land --candidate-only
    [ "$status" -eq 10 ]
}

@test "separate-clone publisher wins the race: loser is rejected, resets the attempt and needs fresh evidence" {
    prepare
    stub_coord "if [ \"\$1\" = lock-verify ] && [ ! -e '$WORK/raced' ]; then touch '$WORK/raced'; ( cd '$OTHER' && git pull -q origin main && echo c1 >c1.txt && git add c1.txt && git commit -q -m c1 && git push -q origin main ) >/dev/null 2>&1; fi"
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 3 ]
    winner="$(remote_main)"
    [ "$winner" = "$(git -C "$OTHER" rev-parse HEAD)" ]
    [ "$(jq -r .publishAttempt "$SDIR/candidate.json")" = false ]
    [ "$(git -C "$REPO" rev-parse refs/loom/land/s1/candidate)" = "$CAND" ]
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 3 ]
    [ "$(remote_main)" = "$winner" ]
    [ -n "$(claims)" ]
}

@test "competing publishers in separate clones: winner lands, loser rebuilds and keeps claim" {
    prepare
    CAND_A="$CAND"
    EV_A="$WORK/ev-a.json"
    cp "$WORK/ev.json" "$EV_A"
    # Clone 2: slice B, session s2, claim, candidate and evidence.
    GATE_B="test -f featureb.txt"
    git -C "$OTHER" pull -q origin main 2>/dev/null
    git -C "$OTHER" checkout -q -b slice-b
    printf 'featureb\n' >"$OTHER/featureb.txt"
    git -C "$OTHER" add featureb.txt
    git -C "$OTHER" commit -q -m featureb
    HEAD_B="$(git -C "$OTHER" rev-parse HEAD)"
    git -C "$OTHER" checkout -q main
    otherc() { (cd "$OTHER" && "$LOOM_TEST_BASH" "$COORD" "$@"); }
    otherc session-start --session s2 >/dev/null
    otherc lock-acquire --session s2 >/dev/null
    otherc claim slice-b --session s2 >/dev/null
    otherc lock-release --session s2 >/dev/null
    land_b() {
        run --separate-stderr "$LOOM_TEST_BASH" "$LAND" --repo "$OTHER" --remote origin \
            --target-ref refs/heads/main --mode remote-direct --slice slice-b --session s2 \
            --head "$HEAD_B" --gate "$GATE_B" "$@"
    }
    land_b --candidate-only
    [ "$status" -eq 0 ]
    CAND_B="$output"
    EV_B="$WORK/ev-b.json"
    printf '{"schema":"loom-evidence/v1","candidateSha":"%s","gate":"%s","gateEvidenceSha256":"%s","reviewEvidenceSha256":"%s"}\n' \
        "$CAND_B" "$GATE_B" "$(printf 'a%.0s' $(seq 1 64))" "$(printf 'b%.0s' $(seq 1 64))" >"$EV_B"
    # Winner: clone 1 publishes slice A.
    land --evidence "$EV_A"
    [ "$status" -eq 0 ]
    [ "$(remote_main)" = "$CAND_A" ]
    [ -z "$(claims)" ]
    # Loser: clone 2 detects target movement, rebuilds on candidate A and exits 3.
    land_b --evidence "$EV_B"
    [ "$status" -eq 3 ]
    [ "$(remote_main)" = "$CAND_A" ]
    ODIR="$OTHER/.git/loom/session-s2"
    [ "$(jq -r .baseCommit "$ODIR/candidate.json")" = "$CAND_A" ]
    [ "$(jq -r .candidateSha "$ODIR/candidate.json")" != "$CAND_B" ]
    [ -n "$(otherc list-claims)" ]
    [ -z "$(otherc lock-holder)" ]
}

@test "failed push preserves publishAttempt and the next run stops with exit 10" {
    prepare
    printf '#!/bin/sh\nexit 1\n' >"$REMOTE/hooks/update"
    chmod +x "$REMOTE/hooks/update"
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 10 ]
    [ "$(jq -r .publishAttempt "$SDIR/candidate.json")" = true ]
    rm "$REMOTE/hooks/update"
    other_push moved.txt
    moved="$(remote_main)"
    land --evidence "$WORK/ev.json"
    [ "$status" -eq 10 ]
    [[ "$stderr" == *"owner action"* ]]
    [ "$(remote_main)" = "$moved" ]
    [ "$(jq -r .publishAttempt "$SDIR/candidate.json")" = true ]
    [ -n "$(claims)" ]
}

# ---- coordination-state separation -------------------------------------------

# slice_commit <clone> <name> — status docs on base; slice branch br-<name> with a
# Ready to Publish plan and <name>.txt. Sets SC_HEAD and leaves the clone on main.
slice_commit() {
    local c="$1" n="$2"
    git -C "$c" checkout -q main
    git -C "$c" pull -q origin main 2>/dev/null
    if ! git -C "$c" cat-file -e main:.docs/status/progress.md 2>/dev/null; then
        mkdir -p "$c/.docs/status" "$c/.docs/slice-plans/archive"
        printf '# Slice Plans\n' >"$c/.docs/slice-plans/README.md"
        printf '# Progress\n' >"$c/.docs/status/progress.md"
        printf '# Handoff\n' >"$c/.docs/status/handoff.md"
        printf '# Roadmap\n' >"$c/.docs/status/roadmap.md"
        touch "$c/.docs/slice-plans/archive/.gitkeep"
        git -C "$c" add .docs
        git -C "$c" commit -q -m "status docs"
        git -C "$c" push -q origin main
    fi
    git -C "$c" checkout -q -b "br-$n"
    mkdir -p "$c/.docs/slice-plans"
    printf '# %s\n\nStatus: Ready to Publish\n' "$n" >"$c/.docs/slice-plans/$n.md"
    printf '%s\n' "$n" >"$c/$n.txt"
    git -C "$c" add .
    git -C "$c" commit -q -m "slice $n"
    SC_HEAD="$(git -C "$c" rev-parse HEAD)"
    git -C "$c" checkout -q main
}

# mkfin — FIN: a deterministic finalizer that archives the plan and appends to the four docs
mkfin() {
    export LOCKLOG="$WORK/lockseen"
    cat >"$WORK/fin.sh" <<'EOS'
set -e
if git show-ref --verify --quiet refs/loom/lock; then echo x >>"${LOCKLOG:-/dev/null}"; fi
mkdir -p .docs/slice-plans/archive
git mv ".docs/slice-plans/$LOOM_SLICE.md" ".docs/slice-plans/archive/$LOOM_SLICE.md"
for f in .docs/slice-plans/README.md .docs/status/progress.md .docs/status/handoff.md .docs/status/roadmap.md; do
    case "$f" in *"${SKIP:-none-skip}"*) continue ;; esac
    printf -- '- %s\n' "$LOOM_SLICE" >>"$f"
done
EOS
    FIN="bash $WORK/fin.sh"
}

# managed — a Ready to Publish slice-a on top of the status docs, with FIN and its gate
managed() {
    slice_commit "$REPO" slice-a
    HEAD_SHA="$SC_HEAD"
    GATE="test -f slice-a.txt"
    mkfin
}

landf() { land --finalize "$FIN" "$@"; }
preparef() {
    landf --candidate-only
    [ "$status" -eq 0 ]
    CAND="$output"
    evidence "$CAND"
}

@test "coordination-state: claim and work start leave tracked main untouched" {
    before="$(git -C "$REPO" rev-parse main)"
    coordr lock-acquire --session s1 >/dev/null
    coordr claim slice-x --session s1 >/dev/null
    coordr lock-release --session s1 >/dev/null
    [ "$(git -C "$REPO" rev-parse main)" = "$before" ]
    [ -z "$(git -C "$REPO" status --porcelain)" ]
    claims | grep -q '^slice-x'
}

@test "coordination-state: publication carries exactly one slice plus finalization" {
    managed
    base="$(remote_main)"
    preparef
    landf --evidence "$WORK/ev.json"
    [ "$status" -eq 0 ]
    names="$(git -C "$REMOTE" diff --no-renames --name-only "$base" main | LC_ALL=C sort | tr '\n' ' ')"
    [ "$names" = ".docs/slice-plans/README.md .docs/slice-plans/archive/slice-a.md .docs/status/handoff.md .docs/status/progress.md .docs/status/roadmap.md slice-a.txt " ]
    [ "$(git -C "$REMOTE" rev-list --merges "$base..main" | wc -l | tr -d ' ')" = 1 ]
    [ "$(git -C "$REMOTE" rev-list --count "$base..main")" = 3 ]
    [ "$(git -C "$REMOTE" rev-parse "main^^2")" = "$HEAD_SHA" ]
    [ "$(git -C "$REMOTE" log -1 --format=%s main)" = "Finalize slice slice-a" ]
    ! git -C "$REMOTE" ls-tree -r --name-only main | grep -q '^\.loom/'
    [ -z "$(claims)" ]
}

@test "coordination-state: unrelated local main history is never published, also after rebuild" {
    managed
    printf 'local\n' >"$REPO/local.txt"
    git -C "$REPO" add local.txt
    git -C "$REPO" commit -q -m "local only"
    preparef
    ! git -C "$REPO" cat-file -e "$CAND:local.txt" 2>/dev/null
    other_push moved.txt
    landf --evidence "$WORK/ev.json"
    [ "$status" -eq 3 ]
    evidence "$(jq -r .candidateSha "$SDIR/candidate.json")"
    landf --evidence "$WORK/ev.json"
    [ "$status" -eq 0 ]
    ! git -C "$REMOTE" cat-file -e main:local.txt 2>/dev/null
    git -C "$REMOTE" cat-file -e main:moved.txt
}

@test "coordination-state: missing or incomplete finalize is rejected on a Ready to Publish slice" {
    managed
    before="$(remote_main)"
    land --candidate-only
    [ "$status" -eq 1 ]
    [[ "$stderr" == *"--finalize"* ]]
    land --candidate-only --finalize "SKIP=handoff $FIN"
    [ "$status" -eq 1 ]
    [[ "$stderr" == *"handoff.md"* ]]
    [ "$(remote_main)" = "$before" ]
    [ -n "$(claims)" ]
    [ ! -f "$SDIR/candidate.json" ]
}

@test "coordination-state: a plan that is not Ready to Publish is rejected" {
    managed
    git -C "$REPO" checkout -q "br-slice-a"
    printf '# slice-a\n\nStatus: Implemented\n' >"$REPO/.docs/slice-plans/slice-a.md"
    git -C "$REPO" commit -q -am "not ready"
    HEAD_SHA="$(git -C "$REPO" rev-parse HEAD)"
    git -C "$REPO" checkout -q main
    landf --candidate-only
    [ "$status" -eq 1 ]
    [[ "$stderr" == *"Ready to Publish"* ]]
}

@test "coordination-state: finalize is repeatable across time and identity and a failing finalize writes nothing" {
    managed
    preparef
    first="$CAND"
    rm -f "$SDIR/candidate.json"
    git -C "$REPO" update-ref -d refs/loom/land/s1/candidate
    sleep 2
    GIT_AUTHOR_DATE="2001-01-01T00:00:00Z" GIT_COMMITTER_DATE="2001-01-01T00:00:00Z" \
        GIT_AUTHOR_NAME=Other GIT_COMMITTER_NAME=Other GIT_AUTHOR_EMAIL=o@example.com GIT_COMMITTER_EMAIL=o@example.com \
        landf --candidate-only
    [ "$status" -eq 0 ]
    [ "$output" = "$first" ]
    [ "$(git -C "$REPO" rev-parse "$first^")" = "$(git -C "$REPO" rev-parse "$output^")" ]
    before="$(remote_main)"
    rm -f "$SDIR/candidate.json"
    git -C "$REPO" update-ref -d refs/loom/land/s1/candidate
    landf --candidate-only --finalize "false"
    [ "$status" -eq 10 ]
    [ ! -f "$SDIR/candidate.json" ]
    [ -n "$(claims)" ]
    [ "$(remote_main)" = "$before" ]
}

@test "coordination-state: a changed finalize command invalidates the candidate evidence" {
    managed
    preparef
    old="$CAND"
    landf --finalize "$FIN; echo more >>.docs/status/progress.md" --evidence "$WORK/ev.json"
    [ "$status" -eq 3 ]
    [[ "$stderr" == *"fresh review evidence"* ]]
    new="$(jq -r .candidateSha "$SDIR/candidate.json")"
    [ "$new" != "$old" ]
    evidence "$new"
    landf --finalize "$FIN; echo more >>.docs/status/progress.md" --evidence "$WORK/ev.json"
    [ "$status" -eq 0 ]
    [ "$(remote_main)" = "$new" ]
}

@test "coordination-state: gate and finalize never run under the publish lock" {
    managed
    GATE="test -f slice-a.txt && { if git show-ref --verify --quiet refs/loom/lock; then echo x >>$LOCKLOG; fi; }"
    preparef
    stub_coord "if [ \"\$1\" = lock-acquire ] && [ ! -e '$WORK/moved' ]; then touch '$WORK/moved'; ( cd '$OTHER' && git pull -q origin main && echo m >m.txt && git add m.txt && git commit -q -m m && git push -q origin main ) >/dev/null 2>&1; fi"
    landf --evidence "$WORK/ev.json"
    [ "$status" -eq 3 ]
    [ ! -e "$LOCKLOG" ]
    [ -n "$(claims)" ]
    [ -z "$(coordr lock-holder)" ]
    unset LOOM_COORD_BIN
    evidence "$(jq -r .candidateSha "$SDIR/candidate.json")"
    landf --evidence "$WORK/ev.json"
    [ "$status" -eq 0 ]
    [ ! -e "$LOCKLOG" ]
}

@test "coordination-state: a positively rejected push resets the attempt and the loser rebuilds on the winner" {
    managed
    preparef
    stub_coord "if [ \"\$1\" = lock-verify ] && [ ! -e '$WORK/raced' ]; then touch '$WORK/raced'; ( cd '$OTHER' && git pull -q origin main && echo '- winner' >>.docs/status/progress.md && git commit -q -am winner && git push -q origin main ) >/dev/null 2>&1; fi"
    landf --evidence "$WORK/ev.json"
    [ "$status" -eq 3 ]
    winner="$(remote_main)"
    [ "$(jq -r .publishAttempt "$SDIR/candidate.json")" = false ]
    landf --evidence "$WORK/ev.json"
    [ "$status" -eq 3 ]
    [ "$(remote_main)" = "$winner" ]
    new="$(jq -r .candidateSha "$SDIR/candidate.json")"
    [ "$new" != "$CAND" ]
    evidence "$new"
    landf --evidence "$WORK/ev.json"
    [ "$status" -eq 0 ]
    git -C "$REMOTE" show main:.docs/status/progress.md | grep -q -- '- winner'
    git -C "$REMOTE" show main:.docs/status/progress.md | grep -q -- '- slice-a'
    [ -z "$(claims)" ]
}

@test "coordination-state: an unreadable remote after a failed push stays uncertain with exit 10" {
    managed
    preparef
    REAL_GIT="$(command -v git)"
    mkdir -p "$WORK/fakebin"
    printf '#!/bin/sh\ncase " $* " in *" push "*|*" ls-remote "*) exit 1 ;; esac\nexec "%s" "$@"\n' "$REAL_GIT" >"$WORK/fakebin/git"
    chmod +x "$WORK/fakebin/git"
    PATH="$WORK/fakebin:$PATH" landf --evidence "$WORK/ev.json"
    [ "$status" -eq 10 ]
    [ "$(jq -r .publishAttempt "$SDIR/candidate.json")" = true ]
    landf --evidence "$WORK/ev.json"
    [ "$status" -eq 10 ]
    [ "$(jq -r .publishAttempt "$SDIR/candidate.json")" = true ]
    [ -n "$(claims)" ]
}

@test "coordination-state: a failed push the server accepted and another publisher advanced is contained, not repushed" {
    managed
    preparef
    REAL_GIT="$(command -v git)"
    mkdir -p "$WORK/fakebin"
    cat >"$WORK/fakebin/git" <<EOS
#!/bin/sh
case " \$* " in *" push "*)
    echo x >>"$WORK/ourpushes"
    "$REAL_GIT" "\$@" || exit 1
    ( cd "$OTHER" && "$REAL_GIT" pull -q origin main && echo c >c.txt && "$REAL_GIT" add c.txt && "$REAL_GIT" commit -q -m c && "$REAL_GIT" push -q origin main ) >/dev/null 2>&1
    exit 1 ;;
esac
exec "$REAL_GIT" "\$@"
EOS
    chmod +x "$WORK/fakebin/git"
    PATH="$WORK/fakebin:$PATH" landf --evidence "$WORK/ev.json"
    [ "$status" -eq 0 ]
    [ "$(wc -l <"$WORK/ourpushes" | tr -d ' ')" = 1 ]
    git -C "$REMOTE" merge-base --is-ancestor "$CAND" main
    [ "$(remote_main)" != "$CAND" ]
    [ "$(jq -r .verification "$SDIR/publication-receipt.json")" = contained ]
    [ -z "$(claims)" ]
}

@test "coordination-state: offline publication keeps main, claim and Ready to Publish plan" {
    managed
    preparef
    before="$(git -C "$REPO" rev-parse main)"
    rmain="$(remote_main)"
    mv "$REMOTE" "$REMOTE.off"
    landf --evidence "$WORK/ev.json"
    mv "$REMOTE.off" "$REMOTE"
    [ "$status" -eq 10 ]
    [ "$(git -C "$REPO" rev-parse main)" = "$before" ]
    [ "$(remote_main)" = "$rmain" ]
    [ -n "$(claims)" ]
    [ ! -f "$SDIR/publication-receipt.json" ]
    git -C "$REPO" show "$HEAD_SHA:.docs/slice-plans/slice-a.md" | grep -q '^Status: Ready to Publish'
}

@test "coordination-state: post-publication cleanup crash recovers without a second push" {
    managed
    count_hook
    preparef
    stub_coord "if [ \"\$1\" = release-claim ] && [ ! -e '$WORK/crashed' ]; then touch '$WORK/crashed'; exit 10; fi"
    landf --evidence "$WORK/ev.json"
    [ "$status" -eq 10 ]
    [ "$(pushes)" = 1 ]
    [ -n "$(claims)" ]
    unset LOOM_COORD_BIN
    landf --evidence "$WORK/ev.json"
    [ "$status" -eq 0 ]
    [ "$(pushes)" = 1 ]
    [ -z "$(claims)" ]
    [ "$(remote_main)" = "$CAND" ]
}
