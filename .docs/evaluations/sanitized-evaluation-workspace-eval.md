# Evaluation: sanitized-evaluation-workspace Code Review

Status: Evaluated
Round: 0
Verdict: FAIL
Reviewed against: sanitized-evaluation-workspace slice plan and plan evaluation, ADR 0022, code evaluation rubric, and severity rubric; diff 82edf56..7570254.

## Findings

### Blocker

- [BLOCKER] The mandatory full gate fails: Bats test 390 expects `loom-review` last in each helper allowlist, but the new registration appends `loom-eval-workspace`. Update the existing registration test to reflect the approved helper order, then rerun the full gate.
- [BLOCKER] Excluded content is exported in the exact diff. `plugins/loom/bin/loom-eval-workspace:873` writes an unrestricted base-to-head patch, while the exclusion policy at lines 137–157 applies only to the source tree. A change to a tracked `.env`, transcript, status history, or unrelated evaluation therefore appears in `diff.patch` despite being listed as excluded from source; the revision patch at line 811 has the same problem. This violates the controlled-input omission requirement. Reject a run whose exact required diff contains excluded content, or reconcile the exact-diff contract with a reviewed policy before exporting.
- [BLOCKER] Research and plan evidence snapshots leak status and unrelated evaluations. The early return at `plugins/loom/bin/loom-eval-workspace:153` applies those exclusions only to code, although the plan requires evidence snapshots to follow recorded exclusions and omit history and unrelated evaluations. Apply the policy to every snapshot, preserving only explicitly approved authority or artifact inputs.
- [BLOCKER] The published implementation exceeds the explicit slice limit and does not perform the required split. The diff adds 1,265 lines in `plugins/loom/bin/loom-eval-workspace` alone, more than twice the plan's 600 net LOC excluding tests and schemas. Split the gate runner into a separately planned slice as the plan requires.
- [BLOCKER] Runtime validation is not schema validation. `plugins/loom/bin/loom-eval-workspace:226–303` substitutes handwritten jq checks for the two schemas; for example nested manifest objects can contain unknown fields, and rerun validation does not check required timestamps or reject extra properties. `do_verify` and `status` accept those partial checks rather than validating the declared contracts, contrary to steps 1 and 4. Validate against both schemas and their cross-field invariants before accepting or reporting a run.
- [BLOCKER] Research evidence freshness is checked only at preparation. `validate_captures` checks `fresh_until` at lines 560–561, but `do_verify` only compares the capture inventory at lines 476–479; an expired citation continues to yield `prepared` from `status`. Recheck provenance and freshness during verification and return the specified infrastructure-blocked status for unavailable required fresh evidence.

- [BLOCKER] Privacy checks accept world-accessible run directories. The `find -perm 700` predicates at `plugins/loom/bin/loom-eval-workspace:382–385` and 759 require owner bits but permit group and other bits, so a run root, output or scratch changed to mode 777 still verifies. Check the exact mode and reject any group/other access.

### Major

- None.

### Minor

- None.

### Nit

- None.

## Required changes

Address the fail-closed export, schema and freshness checks above, and split the implementation according to the approved plan. Add focused regression tests for each corrected boundary.

## Gate rerun evidence

The checked-out HEAD was `75702546a0002a4b3334ea4e7e3ff11d70be98f9`. `scripts/check` exited 1: 736 tests discovered, 735 passed and 1 failed; the format, lint and syntax stages completed before the Bats failure. Exact combined output follows.

```text

==> toolchain contract and pinned digests

==> locked JavaScript dependencies and metadata validation

added 17 packages in 1s
Repository metadata validation passed

==> shfmt

==> ShellCheck

==> Bash syntax

==> Bats tests
Discovered 736 Bats tests
Selected Bash: /opt/homebrew/Cellar/bash/5.3.9/bin/bash (5.3.9(1)-release)
1..736
bats-process BASH_VERSION=5.3.9(1)-release
executable-child BASH_VERSION=5.3.9(1)-release
ok 1 Bats and an env-bash executable child use the selected Bash
ok 2 launcher rejects a relative selected shell
ok 3 launcher rejects a non-executable selected shell
ok 4 launcher rejects a missing Bats entrypoint
ok 5 launcher rejects a selected Bash version mismatch
ok 6 launcher independently rejects Bash below 3.2
ok 7 launcher resolves a terminal selected-shell symlink
ok 8 launcher resolves relative multihop symlinks before links are retargeted
ok 9 launcher rejects a selected-shell symlink loop
ok 10 launcher rejects a missing runtime canary
ok 11 launcher puts the runtime canary first exactly once
ok 12 launcher removes its private directory after success
ok 13 launcher preserves failure status and removes its private directory
ok 14 launcher removes its private directory after a termination signal
ok 15 L1 lock-acquire on free lock: exit 0, holder session-id == self
ok 16 L2 lock-acquire vs LIVE holder: exit 3, original holder stamp unchanged
ok 17 L3 lock-acquire vs DEAD stale holder: exit 0, holder now == contender
ok 18 L4 lock holder with FRESH stamp (within TTL) is not cleared
ok 19 L5 concurrent stale reclaim: exactly one winner, looped 10x
ok 20 L6 second lock-acquire returns 3 while first is held; lock-verify confirms
ok 21 L7a lock-verify while A holds: A→0 (held), B→5
ok 22 L7b lock-verify with no lock: exit 5
ok 23 L7c lock-verify outside a repo: exit 10
ok 24 L8 lock-release by non-holder: exit 5, lock intact
ok 25 L9 lock-release delete-CAS refuses when ref was changed by another holder
ok 26 C1 claim free slice: exit 0, registry and held-claims updated
ok 27 C2 claim with live peer: exit 4, registry unchanged
ok 28 C3 claim own already-held slice: idempotent exit 0
ok 29 C4 claim without holding the lock: exit 5
ok 30 R1 renew: epoch advances and pid overwritten
ok 31 R1b renew by non-owner: exit 5
ok 32 RC1 release-claim: removes registry line and held-claims entry
ok 33 RCL1 reclaim dead peer claim: exit 0, registry owned by us
ok 34 RCL1b reclaim live peer claim: exit 6, claim unchanged
ok 35 S1 session-start prints uuid and creates session dir
ok 36 S1b checkpoint write/read round-trip
ok 37 S1c claim updates held-claims in session dir
ok 38 SB1 session-bootstrap re-adopts claims and renews leases
ok 39 CU1 cleanup sweeps dead session, leaves live session intact
ok 40 FC1 lock-acquire outside a repo: exit 10 (deny, not 0)
ok 41 FC1b claim outside a repo: exit 10 (deny)
ok 42 U1 lock-acquire without --session: exit 1
ok 43 U1b claim without --session: exit 1
ok 44 U1c unknown subcommand: exit 1
ok 45 NEG-F1 claiming 'v2' does not touch 'auth-v2' registry row
ok 46 NEG-F1b remove_claim 'v2' does not remove 'auth-v2'
ok 47 NEG-F2 cleanup with live lock holder: exit non-zero, claims unchanged
ok 48 NEG-F4 dead ses-foo not reported alive because live ses-foo-bar exists
ok 49 NEG-F6 stale-lease session with orphan worktree still on disk: orphan IS removed by cleanup
ok 50 NEG-F7 session-end when lock busy: exit non-zero, claims and session dir preserved
ok 51 REG1 hooks.json has no entry for loom-coord.sh
ok 52 NEG-R1 stale-lease session with worktree IS swept (lease freshness is the sole liveness signal)
ok 53 NEG-R2 dead 'bar' not falsely alive because live 'wt-foo-bar' has it as trailing suffix
ok 54 NEG-R3 session-id with ERE metachar 'run[1]' matched literally, not as regex vs live 'run1'
ok 55 NEG-R6 live session with space in worktree path: reclaim refused (space-safe parsing)
ok 56 T3 wt_sid_match: backslash-n decoded sid is quarantined (malformed persisted state)
ok 57 T5 cleanup: corrupted claim (empty sid) increments skipped counter
ok 58 LV-fresh fresh-lease claim (no worktree) is NOT reclaimable (exit 6)
ok 59 LV-stale stale-lease claim with live worktree IS reclaimable (worktree no longer protects)
ok 60 RNW-1 renewer-start launches renewer; renewer-stop kills it cleanly
ok 61 RNW-2 renewer identity gate: renewer self-exits when session start-time changes
ok 62 CC1 claim CAS: two concurrent create-only attempts, exactly one wins
ok 63 SC1 slice name with colon maps to valid ref; claim/renew/release round-trip
ok 64 LC1 list-claims returns ref paths and blob content for active claims
ok 65 RNW-3 renewer heartbeats the lock ref while main session holds it (U3 fix)
ok 66 U2 empty lease-ts: claim treated as live (reclaim refused, exit 6)
ok 67 U5 renewer-stop with empty starttime and alive pid: no kill issued
ok 68 U6 cleanup: empty-ts claim treated as live (skipped, session dir preserved)
ok 69 V1 lock held past TTL with renewer: peer cannot steal (renewer keeps it fresh)
ok 70 V2 stale claim: cleanup runs delete-CAS-first path; ref and worktree swept
ok 71 V2b concurrent renewal: cleanup CAS refused; live holder worktree preserved
ok 72 V3 stale claim: reclaim runs CAS-steal-first path; reclaimer owns claim, holder worktree removed
ok 73 V3b concurrent renewal: reclaim CAS refused; holder worktree preserved
ok 74 V4 lock-release succeeds while renewer heartbeats (retry-loop, no deadlock)
ok 75 V5a slice named 'foo.lock' can be claimed and released (hash-ref avoids .lock suffix)
ok 76 V5b slice named 'a..b' can be claimed and released (hash-ref avoids double-dot)
ok 77 V6 'Auth' and 'auth' are independent claims (hash-ref is case-sensitive)
ok 78 PROC-1 stat field-22 parse: comm containing spaces and parens gives correct starttime
ok 79 NEG-ID1 session-id traversal 'x/../../victim': exit 1, no dir created outside STATE_DIR
ok 80 NEG-ID2 absolute session id: exit 1, no out-of-tree dir created
ok 81 NEG-ID3 empty session id: exit 1 (regression: assert_session)
ok 82 NEG-ID3b overlong (129-char) session id: exit 1
ok 83 NEG-ID4 session id containing a literal tab: exit 1
ok 84 NEG-ID4b session id containing a real newline: exit 1
ok 85 NEG-ID5 session id containing Unicode U+2044 (fraction slash): exit 1
ok 86 NEG-ID5b session id containing Unicode U+2215 (division slash): exit 1
ok 87 NEG-ID6 cleanup: malformed decoded sid (traversal string) is quarantined, not swept
ok 88 NEG-ID6b reclaim: malformed decoded sid does not drive worktree removal outside the tree
ok 89 NEG-ID7 claim rejects a slice name containing a newline: exit 1
ok 90 NEG-ID7b claim rejects a slice name containing a tab: exit 1
ok 91 NEG-ID7c renew rejects a slice name containing a control byte: exit 1
ok 92 NEG-ID7d claim with empty slice name: exit 1 (regression)
ok 93 NEG-ID7e claim succeeds with slice names containing '/', ':', or '..' (V5/V6 capability preserved)
ok 94 NEG-ID8 renewer-start rejects a non-numeric pid: exit 1
ok 95 NEG-ID9 session-end removes known files and the (now-empty) session dir
ok 96 NEG-ID9b session-end quarantines a session dir holding an unexpected file (rmdir refuses non-empty)
ok 97 CONT-1 symlinked state root: session-start fails closed and victim is unchanged
ok 98 CONT-2 symlinked session: start/checkpoint/bootstrap never read or write victim
ok 99 CONT-3 held-claim add/remove and session-end reject symlink without victim mutation
ok 100 CONT-4 child-path swap: checkpoint symlink is rejected and target bytes stay unchanged
ok 101 CONT-5 later session-dir swap is revalidated by lifecycle and cleanup paths
ok 102 CONT-6 renewer start/stop reject symlink and do not create process-state or temporaries
ok 103 CONT-6b detached renewer revalidates a swapped session before victim held-claims read
ok 104 CONT-7 non-directory session object fails closed without unrelated mutation
ok 105 CONT-8 normal real-directory checkpoint, claim, bootstrap, renewer, and end stay green
ok 106 LOCK-OWN-1 forced race: cleanup holds 2s lock, peer steals after expiry, cleanup aborts (exit 5), peer lock and stale claim survive
ok 107 LOCK-OWN-2 expired lock holder cannot claim or verify (exit 5)
ok 108 SCHEMA-CAS-1 schema ref write failure fails closed with exit 10 (never silently grants lock)
ok 109 SCHEMA-CAS-2 incompatible schema blocks lock-acquire (exit 10) but allows teardown/cleanup
ok 110 invocation: relative path is rejected fail-closed (exit 2)
ok 111 usage: missing subcommand exits 1
ok 112 skeleton-doc: deterministically strips narrative prose with >= 80% size reduction
ok 113 skeleton-diff: extracts git diff --stat and -U0 from a git repo
ok 114 disabled mode: default LOOM_SYSTEMONE_ENABLED=0 skips cleanly (exit 0)
ok 115 disabled mode: --require fails closed when disabled (exit 2)
ok 116 eval-audit: passes when scope_creep, unproven_acceptance_criteria, and defect_severity are within thresholds
ok 117 eval-audit: fails closed (exit 2) when scope_creep.noul >= 0.70
ok 118 eval-audit: fails closed (exit 2) when defect_severity.score >= 2.0 or confidence < 0.70
ok 119 eval-audit: payload > LOOM_SYSTEMONE_MAX_BYTES triggers skeleton compression and long-context header
ok 120 loop-health: passes on low wheel_spinning and retry_local
ok 121 loop-health: fails closed (exit 2) when wheel-spinning or switch_model_family is recommended
ok 122 route-role: deterministically excludes author_client for code-evaluator
ok 123 endpoint policy: self-hosted URL works without API key while TypeSafe URL requires API key or Keychain
ok 124 keychain: resolves API key from macOS Keychain via security find-generic-password when env var is unset
ok 125 config file: loads loom-systemone-config/v1 settings when env vars are unset
ok 126 secret-set and secret-status: macOS GUI prompt stores in Keychain without leaking secret to stdout
ok 127 secret-set: Windows OS detection uses windows-dpapi-vault via PowerShell without leaking secret
ok 128 plan: exports exact objects, canonical schema-valid manifest, exclusions and permissions
ok 129 plan: without an evidence snapshot the source directory is empty
ok 130 plan: evidence snapshot is the complete tree at the declared evidence SHA
ok 131 plan: default root is a private 0700 directory outside the repository
ok 132 plan: independent runs do not share writable paths
ok 133 plan: re-review binds the prior verdict and the exact revision diff
ok 134 research: complete fresh captures with provenance are required and bound
ok 135 research: stale, hash-mismatched, incomplete and unsafe captures fail closed
ok 136 code: exact diff with rename, binary and mode metadata; pinned gate; schema valid
ok 137 code: base-not-ancestor, equal ids, bad options and unavailable objects are rejected
ok 138 code: docs-only status is recorded explicitly and no review findings are included
ok 139 code: unassembled, invalid, mismatched and bootstrap review findings are rejected
ok 140 verify: altered source, input, mode, extra and missing files fail closed after a successful verification
ok 141 verify: manifest edits, bad self-hash, unknown versions and top-level extras are rejected
ok 142 verify: symlinks, hardlinks and special files inside the run are rejected
ok 143 verify: unavailable Git objects are infrastructure-blocked, never valid
ok 144 verify: diff, base and dependency bindings are rechecked for code runs
ok 145 status: incomplete runs exit 3 and a changed run is never valid
ok 146 prepare: unsafe output roots, duplicate and extra inputs are rejected with no partial run
ok 147 prepare: tracked symlinks and gitlinks in the exported tree are rejected, not omitted
ok 148 prepare: external evidence must be a regular, single-link, non-symlink file
ok 149 clean: removes only the selected recognized run
ok 150 clean: rejects foreign directories, symlinked roots, malformed manifests, links and the repository
ok 151 gate-rerun: runs in a verified private copy, records bound evidence and removes the copy
ok 152 gate-rerun: nonzero exit is rerun-failed with exit 2 and the copy is removed
ok 153 gate-rerun: a gate that alters immutable source or the managed checkout never reports a valid rerun
ok 154 gate-rerun: tampered dependencies or source fail before execution and never report a valid rerun
ok 155 gate-rerun: unavailable gate or tool version mismatch is infrastructure-blocked (4)
ok 156 gate-rerun: interrupted execution is infrastructure-blocked and discards the copy
ok 157 gate-rerun: rejects non-code runs and any command, source, environment or dependency override
ok 158 gate-rerun: a stale rerun record cannot make a changed run valid
ok 159 usage: unknown subcommands, missing arguments and help exit 1
ok 160 no arguments is a usage error
ok 161 relative invocation is rejected
ok 162 unsupported mode, bad ref, bad ids and bad head fail before mutation
ok 163 publication without evidence is rejected
ok 164 session without the claim is an ownership failure
ok 165 evidence mismatches fail closed with exit 1 and leave the remote untouched
ok 166 candidate-only builds, gates, records state, cleans up and does not publish
ok 167 candidate-only twice reuses the exact candidate commit
ok 168 gate failure exits 10, preserves state and claim
ok 169 a gate that dirties the candidate exits 10
ok 170 stale disposable branch is cleaned idempotently
ok 171 clean publication pushes, verifies, receipts, releases the claim and updates the mirror
ok 172 dirty, ahead and stale local main cannot enter the candidate
ok 173 target movement before publication rebuilds, exits 3 and needs fresh evidence
ok 174 target movement while acquiring the lock releases the lock, exits 3 and rebuilds on the next run
ok 175 non-fast-forward push race is rejected without force and keeps the claim
ok 176 merge conflict exits 3 and keeps the claim
ok 177 lock contention exits 3 and keeps the claim
ok 178 lock loss after a verified push is recovered without a second push
ok 179 recovery reconstructs a missing receipt when the candidate is already on the remote
ok 180 re-running after success is idempotent
ok 181 unverifiable push (remote rewrites the ref) exits 10 and keeps the claim
ok 182 recovery rejects a receipt left by a different slice and writes a current one
ok 183 stale receipt from another slice cannot release a claim without the claim
ok 184 recovery after remote advancement records the observed target as resultSha
ok 185 recovery receipt write requires the publish lock
ok 186 uncertain prior push not contained in the target stops for owner action
ok 187 verification reads the push destination, not the fetch URL
ok 188 rejected push to a distinct pushurl is not verified from the fetch repository
ok 189 operational git failure while building the candidate exits 10 and keeps the claim
ok 190 recovery verifies containment against the push destination, not the fetch URL
ok 191 recovery rejects a receipt whose bindings differ and writes a current one
ok 192 receipt write failure exits 10 and preserves state and claim
ok 193 unwritable session directory exits 10
ok 194 separate-clone publisher wins the race: loser is rejected, resets the attempt and needs fresh evidence
ok 195 competing publishers in separate clones: winner lands, loser rebuilds and keeps claim
ok 196 failed push preserves publishAttempt and the next run stops with exit 10
ok 197 coordination-state: claim and work start leave tracked main untouched
ok 198 coordination-state: publication carries exactly one slice plus finalization
ok 199 coordination-state: unrelated local main history is never published, also after rebuild
ok 200 coordination-state: missing or incomplete finalize is rejected on a Ready to Publish slice
ok 201 coordination-state: a plan that is not Ready to Publish is rejected
ok 202 coordination-state: finalize is repeatable across time and identity and a failing finalize writes nothing
ok 203 coordination-state: a changed finalize command invalidates the candidate evidence
ok 204 coordination-state: gate and finalize never run under the publish lock
ok 205 coordination-state: a positively rejected push resets the attempt and the loser rebuilds on the winner
ok 206 coordination-state: an unreadable remote after a failed push stays uncertain with exit 10
ok 207 coordination-state: a failed push the server accepted and another publisher advanced is contained, not repushed
ok 208 coordination-state: offline publication keeps main, claim and Ready to Publish plan
ok 209 coordination-state: post-publication cleanup crash recovers without a second push
ok 210 coordination-state: a push reported successful whose remote tip is not the candidate is not contained
ok 211 claude: researcher launches on Economy/haiku with no Agent capability
ok 212 claude: developer launches on Standard/sonnet
ok 213 claude: planner launches on Deep review/opus
ok 214 claude: plan-evaluator launches on Deep review/opus
ok 215 claude: code-evaluator launches on Deep review/opus
ok 216 codex: researcher launches on Economy/gpt-6.1-terra/low
ok 217 codex: developer launches on Standard/gpt-6.1-terra/medium
ok 218 codex: planner launches on Deep review/gpt-6.1-sol/high
ok 219 codex: plan-evaluator launches on Deep review/gpt-6.1-sol/high
ok 220 codex: code-evaluator launches on Deep review/gpt-6.1-sol/high
ok 221 codex: exact argv contract (ephemeral, no user config, strict, no multi-agent, read-only, model/effort, no web search, output schema, canonical contract)
ok 222 codex: the closed bounded-output schema path is a real regular file
ok 223 codex: never emits a bare --model without an exact matrix value
ok 224 usage: unknown client fails with usage error
ok 225 usage: unknown/renamed role fails with usage error
ok 226 usage: missing arguments fails with usage error
ok 227 usage: no arguments fails with usage error
ok 228 usage: extra arguments fail with usage error
ok 229 usage: never accepts a caller-supplied vendor selector as an argument
ok 230 guard: descendant launch attempt is rejected (LOOM_LAUNCH_ROLE_ACTIVE set)
ok 231 guard: descendant launch attempt is rejected for codex too
ok 232 guard: inherited CODEX_MODEL is rejected
ok 233 guard: inherited MODEL_REASONING_EFFORT is rejected
ok 234 guard: inherited OPENAI_MODEL is rejected
ok 235 guard: inherited ANTHROPIC_MODEL is rejected
ok 236 guard: inherited CLAUDE_MODEL is rejected
ok 237 guard: an enabled delegation feature is rejected
ok 238 guard: a falsy delegation-feature value does not trip the guard
ok 239 guard: invocation must be by absolute path
ok 240 cold id: two invocations never reuse the same launch id
ok 241 claude: missing agent adapter file fails closed
ok 242 claude: agent adapter missing the model field fails closed
ok 243 claude: agent adapter missing the tools field fails closed
ok 244 claude: a substituted/renamed model in the agent adapter fails closed
ok 245 claude: an inherited model value fails closed
ok 246 claude: an Agent capability grant in the tools field fails closed (delegation)
ok 247 RED-GREEN: agent-adapter model tampering flips a valid fixture from accept to reject
ok 248 codex: missing compatibility matrix fails closed
ok 249 codex: wrong matrix schema identity fails closed
ok 250 codex: wrong matrix version fails closed
ok 251 codex: a role absent from every profile's consumers fails closed (role/profile drift)
ok 252 codex: a missing model for the resolved profile fails closed (unavailable model)
ok 253 codex: a missing effort for the resolved profile fails closed (unavailable effort)
ok 254 codex: a substituted model for the resolved profile is used verbatim and validated only by enumeration in the schema
ok 255 codex: missing role skill (undefined canonical contract) fails closed
ok 256 codex: missing closed bounded-output schema fails closed (unbounded output)
ok 257 RED-GREEN: matrix schema tampering flips a valid codex fixture from accept to reject
ok 258 static: never reads CLAUDE_PLUGIN_ROOT/PLUGIN_ROOT/CODEX_HOME for root or vendor resolution
ok 259 codex: never consults CLAUDE_PLUGIN_ROOT/PLUGIN_ROOT/CODEX_HOME even when set
ok 260 claude: launch is independent of the caller's working directory
ok 261 codex: launch is independent of the caller's working directory
ok 262 antigravity: researcher launches on Economy/flash with subagent tools disabled
ok 263 antigravity: developer launches on Standard/inherit
ok 264 antigravity: planner, plan-evaluator, and code-evaluator launch on Deep review/pro
ok 265 antigravity: missing canonical role contract fails closed
ok 266 cross-family: --author-client same-family rejection on plan-evaluator and code-evaluator
ok 267 cross-family: --author-client cross-family acceptance emits authorClient and crossFamilyVerified
ok 268 cross-family: LOOM_REQUIRE_CROSS_FAMILY_EVAL=1 without author client fails closed
ok 269 cross-family: auto client deterministically routes claude->codex->antigravity->claude
ok 270 cross-family: --routing-file positive routing and same-family rejection under requireCrossFamilyEval
ok 271 model: codex inherits an ambient gpt-6.1 model from config.toml
ok 272 model: --model and --effort override ambient config and are emitted
ok 273 model: repo config outranks ambient config; flags outrank repo config
ok 274 model: corrupt or invalid repo config fails closed
ok 275 model: emitted codex, antigravity, and cross-family launches validate against the launch schema
ok 276 model: ambient model_reasoning_effort differing from the profile default is honored
ok 277 model: invalid ambient model_reasoning_effort fails closed
ok 278 model: explicit empty --model fails closed
ok 279 model: explicit empty --effort fails closed
ok 280 model: antigravity maps Deep review to the cached opus high variant
ok 281 model: antigravity explicit --model is used verbatim; empty or malformed fails closed
ok 282 model: stale cache triggers discovery and an atomic owner-only rewrite
ok 283 model: fresh cache is used without invoking agy
ok 284 model: missing, corrupted, or group-readable agy cache with no agy falls back to profile floors
ok 285 model: claude --model selects a tier selector; other values fail closed
ok 286 model: invalid --effort fails closed
ok 287 model: invalid --model for codex fails closed
ok 288 model: unsupported or malformed ambient codex model fails closed
ok 289 model: cross-family evaluation is still enforced with overrides
ok 290 claude: resolves loom-coord from a valid CLAUDE_PLUGIN_ROOT
ok 291 claude: resolves loom-verify-identity from a valid CLAUDE_PLUGIN_ROOT
ok 292 codex: resolves loom-verify-identity from a valid skill source path
ok 293 claude: resolves loom-review from a valid CLAUDE_PLUGIN_ROOT
ok 294 codex: resolves loom-review from a valid skill source path
ok 295 claude: resolves loom-eval-workspace from a valid CLAUDE_PLUGIN_ROOT
ok 296 codex: resolves loom-eval-workspace from a valid skill source path
ok 297 codex: resolves loom-coord from a valid skill source path
ok 298 usage: unknown client fails closed with usage error
ok 299 usage: missing arguments fails with usage error
ok 300 usage: codex missing skill-source argument fails with usage error
ok 301 usage: extra arguments fail with usage error
ok 302 claude: unset CLAUDE_PLUGIN_ROOT fails closed
ok 303 claude: relative CLAUDE_PLUGIN_ROOT fails closed
ok 304 claude: helper not allowlisted fails closed
ok 305 claude: wrong manifest name fails closed
ok 306 claude: wrong manifest version fails closed
ok 307 claude: malformed manifest JSON fails closed
ok 308 claude: missing manifest fails closed
ok 309 claude: manifest is a symlink escaping the root fails closed
ok 310 claude: absent helper fails closed
ok 311 claude: non-executable helper fails closed
ok 312 claude: helper symlink escaping the root fails closed
ok 313 claude: helper directory symlink escaping the root fails closed
ok 314 claude: helper found only as a nested (non-direct) child fails closed
ok 315 codex: relative skill source path fails closed
ok 316 codex: empty skill source path fails closed
ok 317 codex: missing skill source file fails closed
ok 318 codex: wrong suffix (not skills/<skill>/SKILL.md) fails closed
ok 319 codex: nested skill segment (extra path component) fails closed
ok 320 codex: frontmatter name mismatched with directory fails closed
ok 321 codex: manifest name mismatch fails closed
ok 322 codex: manifest version mismatch fails closed
ok 323 codex: missing manifest fails closed
ok 324 codex: skill source symlink escaping the root fails closed
ok 325 codex: absent helper fails closed
ok 326 codex: non-executable helper fails closed
ok 327 codex: helper not allowlisted fails closed
ok 328 codex: never consults CLAUDE_PLUGIN_ROOT/PLUGIN_ROOT/CODEX_HOME
ok 329 static: the Codex resolution path never references PATH/CLAUDE_PLUGIN_ROOT/PLUGIN_ROOT/CODEX_HOME for root identity
ok 330 codex: a forbidden environment-only guess cannot substitute for a missing source argument
ok 331 claude: resolution is independent of the caller's working directory
ok 332 codex: resolution is independent of the caller's working directory
ok 333 RED-GREEN: an allowlisted-but-nonexistent helper name would resolve if the allowlist check were removed
ok 334 antigravity: resolves loom-coord from plugins/loom/skills/<skill>/SKILL.md
ok 335 antigravity: resolves loom-coord from .agents/skills/<skill>/SKILL.md in a repo root
ok 336 antigravity: frontmatter name mismatch in .agents/skills/<skill>/SKILL.md fails closed
ok 337 prepare: records exact SHAs, tree, diff hash, inventory, ranges and provenance
ok 338 prepare: source export matches ls-tree and ignores export attributes; no .git
ok 339 prepare: manifest is schema-valid
ok 340 prepare: accepts untracked gate evidence inside the repo; other untracked file rejects
ok 341 prepare: leaves the run directory private and the tree untouched
ok 342 prepare rejects abbreviated, symbolic, range and nonexistent revisions
ok 343 prepare rejects base == head and base not an ancestor
ok 344 prepare rejects a dirty tracked file, other untracked file, and HEAD != head
ok 345 prepare rejects missing, symlinked, out-of-repo plan and modified spec
ok 346 prepare rejects a gitlink in the diff
ok 347 prepare defaults omitted --prompt-hash and --finder-profile to pinned hash and claude:sonnet
ok 348 prepare: explicit --prompt-hash mismatch fails closed with exit 2
ok 349 prepare rejects malformed overrides
ok 350 prepare rejects unknown finder IDs and versions in --prompt-hash and --finder-profile
ok 351 prepare rejects empty explicit override values and entries without a key or '='
ok 352 prepare rejects duplicate overrides for the same finder
ok 353 prepare/validate: prompt byte drift or missing asset fails closed (script-relative root)
ok 354 validate rejects a manifest whose prompt hash is not the pinned hash
ok 355 prepare rejects an existing run and an unknown flag
ok 356 network-silent: no network command is invoked across all subcommands
ok 357 validate accepts mixed results with the right aggregate and schema-valid results
ok 358 validate: all-clean results yield ran-clean
ok 359 validate accepts old-side finding on a deleted file and file-level binary finding
ok 360 validate rejects a missing finder and never reports ran-clean
ok 361 validate rejects duplicate and extra result files
ok 362 validate rejects invalid JSON, invalid UTF-8 and schema violations
ok 363 validate rejects unknown protocol, prompt version/hash, manifest hash and run id mismatch
ok 364 validate rejects a manifest with an unknown protocol major
ok 365 validate rejects failed, truncated and nonzero-exit results
ok 366 validate rejects status/finding inconsistency in both directions
ok 367 validate rejects provenance and binding mismatches in results
ok 368 validate rejects a modified source export (edited, added, removed, chmod'd, attribute-omitted)
ok 369 validate rejects modified diff and input files
ok 370 validate rejects swapped head_tree/SHAs/files[] even when the manifest is re-hashed
ok 371 validate fails closed when the repository or objects are unavailable
ok 372 validate rejects invalid ranges (wrong side, missing side)
ok 373 validate rejects findings at invalid locations
ok 374 validate rejects duplicate finding ids
ok 375 assemble refuses invalid and pending runs without writing
ok 376 assemble output is identity-neutral, deterministic and sorted
ok 377 assemble works for a run directory containing whitespace
ok 378 assemble defaults to .docs/evaluations/<slice>-review-findings.md
ok 379 assemble is atomic: a read-only target directory leaves nothing behind
ok 380 status: prepared -> collecting -> validated -> assembled with exit codes
ok 381 status: invalid exits 2, missing run exits 1, --json parses
ok 382 status never writes
ok 383 status: validate with zero results reports invalid (not prepared), exit 2
ok 384 status: a result changed after a valid verdict is stale -> collecting, exit 3
ok 385 clean removes only the named run, including read-only source
ok 386 clean --all and --older-than
ok 387 clean refuses paths outside the root, symlinked runs, and dirs without a manifest
ok 388 clean never touches committed review-findings files
ok 389 usage errors exit 1
not ok 390 registration: loom-review is last in every helper allowlist copy
# (in test file plugins/loom/bin/loom-review.bats, line 953)
#   `[ "$(jq -r '.allowedHelpers | last' "$root/$f")" = "loom-review" ]' failed
# warning: in the working copy of 'crlf.txt', LF will be replaced by CRLF the next time Git touches it
# warning: in the working copy of 'crlf.txt', LF will be replaced by CRLF the next time Git touches it
ok 391 registration: validate-repository --all passes
ok 392 finder prompts: each names its finder ID and every boundary clause
ok 393 finder prompts: packaged as non-empty regular files under the plugin root
ok 394 fixtures: per-finder synthetic defects validate and assemble with normalized findings
ok 395 fixtures: failed, truncated, out-of-diff and missing output never assemble or read clean
ok 396 usage: no argument exits 1
ok 397 usage: two arguments exit 1
ok 398 baseline: malformed baseline exits 1
ok 399 baseline: well-formed but unknown SHA exits 1
ok 400 not a repository exits 1
ok 401 unborn baseline with still-unborn HEAD is a no-op (0)
ok 402 unborn baseline with valid first commit exits 0
ok 403 unchanged HEAD is a no-op (0) even when HEAD identity is bad
ok 404 valid new commit after baseline exits 0
ok 405 valid amended HEAD exits 0
ok 406 wrong author exits 2 with SHA and remediation
ok 407 wrong committer exits 2
ok 408 same name but wrong email exits 2
ok 409 loom@localhost fallback exits 2
ok 410 configured localhost email is a config error (1)
ok 411 multiple new commits: a bad middle commit is found
ok 412 multiple bad commits are all reported
ok 413 unborn baseline checks every commit including a bad root commit
ok 414 missing configured user.name fails closed (1)
ok 415 missing configured user.email fails closed (1)
ok 416 baseline given but HEAD unborn fails closed (1)
ok 417 unborn baseline with corrupt HEAD ref fails closed (1)
ok 418 unborn baseline with corrupt HEAD file fails closed (1)
ok 419 unborn baseline with dangling symlink HEAD ref fails closed (1)
ok 420 verifier never mutates history on violation
ok 421 bypassed bad commit stops the workflow; remediation then reverifies clean
ok 422 BLOCK B01: commit --author= with quoted value
ok 423 BLOCK B02: -c user.email= override
ok 424 BLOCK B03: -c user.name= override
ok 425 BLOCK B04: inline GIT_AUTHOR_NAME env
ok 426 BLOCK B05: exported GIT_COMMITTER_EMAIL env
ok 427 BLOCK B06: --author with space form
ok 428 BLOCK B07: -c GIT_AUTHOR_NAME= override
ok 429 BLOCK B08: --author= with quoted value and quoted message
ok 430 BLOCK B09: --author= beside escaped inner quote
ok 431 BLOCK B10: read over-block — -c user.email= on log (accepted fail-closed limitation, ADR 0003)
ok 432 BLOCK B11: read over-block — git log --author= (accepted fail-closed limitation)
ok 433 BLOCK: stderr is a single control-character-free line ending in one LF
ok 434 ALLOW A01: plain commit, no override
ok 435 ALLOW A02: -c core.* is non-identity config
ok 436 ALLOW A03: not a git command
ok 437 ALLOW A04: git only as substring of another word
ok 438 BLOCK F05: author flag text inside message body (accepted false positive)
ok 439 BLOCK F07: GIT_AUTHOR_NAME= inside message body (accepted false positive)
ok 440 BLOCK F08: -c user.email= inside message body (accepted false positive)
ok 441 BLOCK F09: --grep value naming the author flag (accepted false positive)
ok 442 BLOCK F10: escaped-inner-quote message with author flag text
ok 443 BLOCK W01: author flag inside bash -c quoted body
ok 444 BLOCK W02: author flag inside sh -c single-quoted body
ok 445 BLOCK W03: env wrapper with GIT_COMMITTER_NAME assignment
ok 446 BLOCK W04: GIT_AUTHOR_DATE assignment
ok 447 BLOCK W05: unbalanced quoting does not discard a recognized token
ok 448 BLOCK W06: -c author.name and -c committer.email overrides
ok 449 BLOCK W07: -c with quoted user key inside bash -c
ok 450 BLOCK W08: -c GIT_COMMITTER_EMAIL override
ok 451 BLOCK C01: git config user.name value (the two known reproductions)
ok 452 BLOCK C02: git config in each scope and file form
ok 453 BLOCK C03: unset, replace-all, add and edit forms
ok 454 BLOCK C04: quoted value and wrapped git config write
ok 455 BLOCK C05: write after a safe read on a later line
ok 456 BLOCK C06: write after a safe read on the same line
ok 457 BLOCK B12: quoted bare author flag (Claude and Codex wire)
ok 458 ALLOW R01: bare reads of identity keys
ok 459 ALLOW R02: non-identity git config writes are untouched
ok 460 ALLOW R03: ordinary commit with message mentioning config in prose
ok 461 codex BLOCK: wrapped author bypass and config write use the Codex envelope
ok 462 ALLOW A13: unbalanced quoting with no recognized token still allows
ok 463 ALLOW A14: plain git push, no override token
ok 464 ALLOW A15: missing tool_input.command (no target) allows, matching ADR 0003
ok 465 codex ALLOW: exit 0, empty stdout/stderr
ok 466 codex BLOCK: exit 0, empty stderr, exact hookSpecificOutput JSON on stdout
ok 467 malformed: invalid JSON fails closed (claude)
ok 468 malformed: invalid JSON fails closed (codex)
ok 469 malformed: tool_input.command wrong type (number) fails closed
ok 470 malformed: tool_input.command wrong type (array) fails closed
ok 471 malformed: tool_input not an object fails closed
ok 472 root: neither PLUGIN_ROOT nor CLAUDE_PLUGIN_ROOT set fails closed
ok 473 root: both PLUGIN_ROOT and CLAUDE_PLUGIN_ROOT validate (ambiguous) fails closed
ok 474 root: CLAUDE_PLUGIN_ROOT pointing at a non-plugin directory fails closed
ok 475 root: relative CLAUDE_PLUGIN_ROOT fails closed
ok 476 jq absent: fails closed (no grep/sed fallback exists for root/JSON validation)
ok 477 RED-GREEN: a well-typed command still allows while a wrong-typed one is rejected
ok 478 fixture claude/pre-tool-use/allow
ok 479 fixture claude/pre-tool-use/block
ok 480 fixture claude/pre-tool-use/malformed
ok 481 fixture codex/pre-tool-use/allow
ok 482 fixture codex/pre-tool-use/block
ok 483 fixture codex/pre-tool-use/malformed
ok 484 T1a progress-advanced manual -> status 0, marker updated
ok 485 T1b progress-advanced auto -> status 0, marker updated
ok 486 T2 no-progress manual -> status 2, exact single-line reason, marker unchanged
ok 487 T2codex no-progress manual -> exit 0, exact continue/stopReason JSON
ok 488 T3 no-progress auto -> status 0, log line appended, marker unchanged
ok 489 T4 first-run no marker -> status 0, marker created with current SHA
ok 490 T5 round-trip: first-run allow, then no-progress block, then advance allow
ok 491 T6a missing trigger field fails closed (malformed)
ok 492 T6b unknown trigger value fails closed (malformed)
ok 493 T6c the obsolete compaction_trigger field is not recognized -> missing trigger -> malformed
ok 494 T6d trigger wrong JSON type fails closed (malformed)
ok 495 T6e invalid JSON fails closed (malformed)
ok 496 T6f malformed on codex wire uses the JSON continue/stopReason envelope
ok 497 T7a missing session_id fails closed (malformed)
ok 498 T7b session_id with a path separator fails closed (path-traversal attempt)
ok 499 T7c session_id with embedded whitespace/control-shaped content fails closed
ok 500 T7d session_id over the length bound fails closed
ok 501 T7e session_id at the exact length bound (128) is accepted
ok 502 T8a not a git repo -> status 0 (fail-open)
ok 503 T8b empty stdin -> status 0 (fail-open)
ok 504 T9 jq absent -> fails closed (root validation cannot succeed without jq)
ok 505 T10 cwd-independence: running from unrelated dir uses cwd from JSON
ok 506 T11 one session's checkpoint never authorizes another session's manual compaction
ok 507 T12 the no-progress-auto log is capped at LOOM_PRECOMPACT_LOG_CAP lines
ok 508 T13 an interrupted marker write leaves the prior marker intact (atomic rename)
ok 509 T7f session_id with single dots is accepted
ok 510 T7g session_id containing .. fails closed
ok 511 T7h session_id with a leading non-alphanumeric fails closed
ok 512 T7i non-string JSON session_id fails closed
ok 513 T12b auto no-progress log is <timestamp>TAB<session>TAB<anchor>
ok 514 T12b log helper strips control characters
ok 515 T12b invalid or leading-zero LOOM_PRECOMPACT_LOG_CAP falls back to 200
ok 516 T14 coordinated session: first-run allow, block with remediation, advance unblocks
ok 517 T15 one coordinated session's advance never unblocks another
ok 518 T16 coordinated session dir without checkpoint file records checkpoint:none
ok 519 T17 concurrent compactions across sessions keep markers intact, no temp files
ok 520 T18 linked worktree resolves the common git dir
ok 521 RED-GREEN: a recognized trigger still proceeds while an unrecognized one is rejected
ok 522 fixture claude/pre-compact/allow
ok 523 fixture claude/pre-compact/block
ok 524 fixture claude/pre-compact/malformed
ok 525 fixture codex/pre-compact/allow
ok 526 fixture codex/pre-compact/block
ok 527 fixture codex/pre-compact/malformed
ok 528 root: Codex prefers its valid PLUGIN_ROOT when both compatibility roots validate
ok 529 unset LOOM_ROLE fails open for test runners and git mutation
ok 530 orchestrator blocks scripts/check
ok 531 orchestrator blocks bats, cargo test, npm test, pytest
ok 532 orchestrator may run scripts/check with LOOM_ALLOW_ORCHESTRATOR_GATE=1
ok 533 orchestrator gate allowance does not unlock bats
ok 534 orchestrator allows non-test commands
ok 535 evaluators block git mutation
ok 536 code-evaluator allows read-only inspection
ok 537 arguments that mention test runners or mutations are allowed
ok 538 landing exception does not unlock other runners in compound commands
ok 539 evaluators block git mutation behind value-taking global options
ok 540 quoted command words are de-quoted; quoted arguments are ignored
ok 541 missing or empty command allows
ok 542 Claude wire: stderr reason, empty stdout, exit 2
ok 543 Codex wire: deny JSON on stdout, exit 0
ok 544 Codex wire: allow is silent exit 0
ok 545 invalid root, invalid JSON, and wrong-typed command fail closed
ok 546 quoted executable paths containing spaces are blocked at command position
ok 547 quoted executable paths with spaces are blocked after env assignments
ok 548 prepare creates a marker-owned run below the canonical temp root with schema-valid state
ok 549 RED>GREEN: prepare rejects a symlinked TMPDIR, succeeds against the real dir
ok 550 RED>GREEN: prepare rejects a nonexistent TMPDIR, succeeds against a real one
ok 551 RED>GREEN: prepare rejects run-root/owner-home overlap, succeeds when disjoint
ok 552 RED>GREEN: phase entry rejects a marker mismatch, succeeds once restored
ok 553 RED>GREEN: phase entry rejects candidate drift, succeeds once restored
ok 554 prepare rejects an unresolved --exercise before --prepare (missing run root)
ok 555 one native mutation journals the exact record sequence and preserves worker PID across exec
ok 556 hash chain is contiguous: each record's prevHash equals the previous record's hash
ok 557 full exercise -> uninstall -> clean succeeds end to end and leaves zero residue
ok 558 exercise captures list/discovery, helper-root, and role/hook probes for both clients
ok 559 RED>GREEN: claude uninstall postcondition reads installed_plugins.json, not raw cache presence
ok 560 RED>GREEN: handshake deadline is computed after the pre-inventory walk, not before it
ok 561 residue after uninstall is refused (exit 6)
ok 562 RED>GREEN: a bare empty ancestor directory left under codex-home/plugins is not residue
ok 563 an unmet postcondition with a clean exit is a product failure (exit 5), not a false success
ok 564 a mutation that writes outside its allowed roots is quarantined (exit 3)
ok 565 an infrastructure-block marker in native output classifies exit 4, not a product failure
ok 566 INT during a mutation yields exit 130
ok 567 TERM during a mutation yields exit 143
ok 568 injection before:intent: nothing is journaled, clean retry succeeds
ok 569 injection after:intent (supervisor never spawned): aborts, no cache mutation, clean retry succeeds
ok 570 injection after:supervisor-hello (supervisor dies before release): no mutation, atomic release recovery on retry
ok 571 injection after:native-hello (worker dies before native-release): no mutation, clean retry succeeds
ok 572 injection before:exec (worker dies with native-release durable, before exec): resume never relaunches, terminal records the kill
ok 573 injection supervisor-die-while-worker-continues: durable worker identity prevents a hidden orphan; reconciles to recovered-after-apply
ok 574 exhausting resume attempts under a persistent fault quarantines rather than looping forever
ok 575 an escaped, token-tagged descendant is detected and blocks --clean until it dies
ok 576 a descendant that stays inside the process group but retains the token still blocks --clean
ok 577 RED>GREEN: --clean refuses an unresolved run, succeeds once resolved
ok 578 --clean refuses a symlinked run-root argument
ok 579 --clean refuses a path outside the temp prefix
ok 580 a quarantined run is cleanable only after a fresh complete inventory proves ownership
ok 581 RED>GREEN: a quarantined run with an owned root swapped for an escaping symlink refuses --clean, succeeds once restored
ok 582 RED>GREEN: --clean fails closed on a tampered non-charset runId instead of building a stray receipt path
ok 583 injection before:native-hello (worker dies before its own hello): supervisor's worker-hello-timeout abort and the gate-2 writer-settle path fire together; no early mutation, clean retry succeeds
ok 584 injection before:supervisor-hello (supervisor dies before writing its own hello): no early mutation, exactly one clean reconciliation on retry
ok 585 injection before:native-release (supervisor dies before granting release): the orchestrator resumes and grants the missed release exactly once; the worker -- blocked until then -- proceeds only after, and a clean retry completes
ok 586 injection before:terminal (supervisor dies after full worker exit, before writing terminal): reconciles to recovered-after-apply
ok 587 injection after:terminal (supervisor dies immediately after writing terminal): applies from the durable terminal record
ok 588 injection after:supervisor-hello is operation-agnostic across marketplace-add, uninstall, marketplace-remove, and a codex opKey
ok 589 default root resolution is stable from a nested working directory
ok 590 all mode passes for the valid repository
ok 591 all mode reports a failing metadata root
ok 592 missing validation mode exits 2 with deterministic usage
ok 593 repeated validation mode exits 2 with deterministic usage
ok 594 mixed validation modes exit 2 with deterministic usage
ok 595 negative seeds are inert and cannot match production scans
ok 596 valid dual-client metadata, compatibility, bindings, and fixtures pass
ok 597 explicit non-Git root nested in a parent worktree uses the safe filesystem walk
ok 598 tracked discovery failure in a real Git root fails closed without reading an untracked canary
ok 599 README states both exact client floors and the static Codex limitation
ok 600 thin adapters pass for the real repository tree
ok 601 a command adapter missing its shared-skill pointer fails closed
ok 602 a command adapter that copies the shared workflow body fails closed on line count
ok 603 an agent adapter missing its shared-role pointer fails closed
ok 604 an agent adapter that copies the shared role body fails closed on line count
ok 605 each README client floor fails metadata validation directly when drifted
ok 606 every client-visible claim surface rejects prohibited unqualified wording
ok 607 a narrow evaluation term passes only with the immediate required qualification
ok 608 malformed JSON names the materialized file
ok 609 malformed JSON Schema names the materialized file
ok 610 missing, unterminated, and invalid YAML frontmatter fail with filenames
ok 611 unknown command frontmatter key fails closed
ok 612 unknown agent frontmatter key fails closed independently
ok 613 unknown skill frontmatter key fails closed independently
ok 614 command missing description fails independently
ok 615 agent missing name fails independently
ok 616 Claude manifest rejects a top-level unknown field
ok 617 Claude manifest rejects an unknown nested author field
ok 618 Claude catalog rejects unknown top-level owner and plugin fields independently
ok 619 Codex manifest rejects top-level and nested author unknown fields independently
ok 620 Codex catalog rejects unknown top-level owner and plugin fields independently
ok 621 compatibility matrix closes every nested object boundary
ok 622 Claude root binding rejects an unknown field
ok 623 Codex root binding rejects an unknown field
ok 624 each Claude installed-root requirement fails independently when omitted
ok 625 each Codex installed-root requirement fails independently when omitted
ok 626 installed-root constants reject false or substituted declarations independently
ok 627 catalog-shaped tracked JSON is rejected outside exact live and release-fixture paths
ok 628 null false zero and empty string receive schema diagnostics as metadata values
ok 629 null false zero and empty string receive deterministic referenced-schema diagnostics
ok 630 catalog source escape fails
ok 631 catalog symlink and different physical root fail
ok 632 catalog source resolving to a different physical plugin root fails
ok 633 duplicate catalog names fail independently
ok 634 duplicate component names fail independently
ok 635 manifest product name drift fails independently
ok 636 manifest exact SemVer drift fails independently
ok 637 manifest shared identity drift fails independently
ok 638 catalog product name drift fails independently
ok 639 catalog source identity drift fails independently
ok 640 catalog release provenance drift fails independently
ok 641 client floor drift fails independently
ok 642 profile mapping drift fails independently
ok 643 matrix schema version drift fails independently
ok 644 duplicate root binding ID fails exact pair enforcement
ok 645 swapped root binding ID and path fails exact pair enforcement
ok 646 alternate same-schema root binding path fails exact pair enforcement
ok 647 root binding identity drift fails independently
ok 648 a command adapter pointing at a deleted shared workflow skill fails closed
ok 649 an agent adapter pointing at a deleted shared role contract fails closed
ok 650 a second client-specific hook manifest fails closed
ok 651 missing client manifest reference fails independently
ok 652 missing matrix root reference fails independently
ok 653 missing referenced schema fails independently
ok 654 release fixture drift fails independently
ok 655 release fixture equality ignores object member order
ok 656 release fixture equality preserves array order
ok 657 schema-valid manifest homepage drift fails shared identity
ok 658 schema-invalid metadata path stops before outside semantic reads
ok 659 outside-root sentinels use unique cleanup-owned directories
ok 660 JSON symlink is rejected before parsing outside content
ok 661 frontmatter symlink is rejected before reading outside content
ok 662 schema symlink is rejected before reading outside content
ok 663 release fixture symlink is rejected before reading outside content
ok 664 real tree metadata passes while inert seeds remain tracked
ok 665 forced real-tree validator failure leaves the checkout intact
ok 666 valid relative targets and local and cross-file fragments pass
ok 667 rendered inline heading text and duplicate GitHub suffixes pass
ok 668 encoded spaces Unicode paths and Unicode fragments pass
ok 669 malformed percent encoding fails with source and exact target
ok 670 encoded traversal cannot escape the repository
ok 671 Markdown source symlink is rejected before reading outside content
ok 672 Markdown target symlink is rejected before reading outside content
ok 673 allowlist symlink is rejected before reading outside content
ok 674 missing targets and fragments name source and target
ok 675 only exact historical trees are excluded
ok 676 malformed duplicate and stale allowlist records fail
ok 677 live allowlist entry with empty reason is rejected and does not suppress the link
ok 678 one exact live broken link is allowlisted but code-block pseudo-link is stale
ok 679 one exact live allowlist entry passes and suppresses its broken-link diagnostic
ok 680 exact workflow and toolchain contract passes
ok 681 loom-coord exact Bash shebang is mechanically required
ok 682 git identity guard exact Bash shebang is mechanically required
ok 683 precompact backstop exact Bash shebang is mechanically required
ok 684 workflow runner row deletion fails
ok 685 workflow inline-comment spoof fails exact verified contract
ok 686 workflow commented-out security setting fails exact verified contract
ok 687 workflow duplicate key fails exact verified contract
ok 688 workflow relocated exact-head string fails exact verified contract
ok 689 workflow runner label mutation fails
ok 690 workflow host mutation fails
ok 691 workflow architecture mutation fails
ok 692 workflow release mutation fails
ok 693 workflow selected shell mutation fails
ok 694 workflow Bash regex mutation fails
ok 695 workflow checkout action pin mutation fails
ok 696 workflow exact-head checkout ref mutation fails
ok 697 workflow exact-head environment mutation fails
ok 698 workflow exact-head assertion mutation fails
ok 699 workflow exact-head log deletion fails
ok 700 workflow selected-shell physical resolver deletion fails
ok 701 toolchain runner deletion fails closed
ok 702 exact tool version mutation fails closed
ok 703 runtime floor mutation fails closed
ok 704 checkout contract pin mutation fails closed
ok 705 package-lock contract digest mutation fails closed
ok 706 unexpected toolchain top-level field fails closed
ok 707 required download deletion fails closed
ok 708 download platform mutation fails closed
ok 709 download URL mutation fails closed
ok 710 download digest mutation fails closed on an unselected platform
ok 711 required vendored asset deletion fails closed
ok 712 vendored asset path mutation fails closed
ok 713 vendored provenance omission fails closed
ok 714 vendored provenance kind mutation fails closed
ok 715 vendored digest mutation fails closed
ok 716 gate independently rejects a selected Bash below 3.2
ok 717 Git immediately below 2.34 is rejected with an actionable diagnostic
ok 718 Git exact floor 2.34 is accepted
ok 719 jq immediately below 1.6 is rejected with an actionable diagnostic
ok 720 jq exact floor 1.6 is accepted
ok 721 unknown host OS is rejected before provisioning
ok 722 supported host OS with unsupported architecture is rejected before provisioning
ok 723 first-stage failure preserves status and emits one exact diagnostic before later stages
ok 724 advanced-stage failure preserves status and stops before every later stage
ok 725 gate resolves terminal and relative multihop selected-Bash symlinks
ok 726 gate HUP cleanup is deterministic and exits 129 without success
ok 727 gate INT cleanup is deterministic and exits 130 without success
ok 728 gate TERM cleanup is deterministic and exits 143 without success
ok 729 fresh provisioning ignores a poisoned persistent extracted-tool tree
ok 730 Bats version probing cannot execute a poisoned ambient bash
ok 731 cache-root symlink is rejected without touching its owned target
ok 732 cached-download symlink is rejected without overwriting its target
ok 733 owner-controlled cache directories are repaired before use
ok 734 hard-linked cached download is rejected without mutating its outside sentinel
ok 735 unexpected cache ownership is rejected
ok 736 cache rewrite race never executes unauthenticated bytes
FAILED stage Bats tests (exit 1)
```

`node scripts/validate-repository.mjs --root "$PWD" --all` exited 0. Exact combined output:

```text
Repository all validation passed
```

## Notes

This review does not establish the adapter confinement, evidence collection, or recording boundary. The plan’s recorded targeted test successes do not establish a passing full gate; this independent full rerun exposed an existing registration test that was not updated.
