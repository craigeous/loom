# Code evaluation — workflow-profiles
Artifact: .docs/slice-plans/workflow-profiles.md
Reviewed against: plugins/loom/skills/loom-playbook/references/code-eval-rubric.md
Commit: cbfc428
Round: 0
Verdict: PASS

## Summary

The implementation satisfies the approved plan: the executable helper is 97 lines, resolves and recommends profiles without changing required lifecycle stages, and both documentation sections describe the required routing and resume behavior. All 12 profile Bats tests passed independently; both Claude and Codex helper resolution succeeded, repository all-validation passed, and all vendored file digests in the toolchain manifest matched their files. The full gate passed.

## Findings

- [MINOR] TST-1 confirmed: the new resolver allowlist entry has no dedicated automated resolution test in either resolver or profile Bats tests. Direct Claude and Codex resolution succeeds, and repository validation checks the inventories; adding resolver coverage would guard against future drift.

## Gate

Command: `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 perl -e '$SIG{INT}="DEFAULT"; exec @ARGV' scripts/check`
Exit status: 0

Combined output:

```text

==> toolchain contract and pinned digests

==> locked JavaScript dependencies and metadata validation

added 17 packages in 1s
Repository metadata validation passed

==> shfmt

==> ShellCheck

==> Bash syntax

==> Bats tests
Discovered 911 Bats tests
Selected Bash: /opt/homebrew/Cellar/bash/5.3.9/bin/bash (5.3.9(1)-release)
1..911
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
ok 128 clean initialized repo: human report passes with explicit unchecked labels, exit 0
ok 129 json report lists the fixed ids in order; unchecked items stay unchecked
ok 130 json report validates against the doctor report schema
ok 131 schema rejects unexpected properties, reordered ids, and unchecked items reported as pass
ok 132 doctor is read-only: working tree and refs are unchanged
ok 133 dirty tree is a warning with exit 0
ok 134 unsupported OS and architecture are errors, exit 1
ok 135 supported Linux x86-64 passes; macOS older than 14 fails
ok 136 bash below 3.2 is an error
ok 137 bash below 3.2 also errors required_tools
ok 138 old tool versions are errors naming the tool
ok 139 old git and old node are both reported
ok 140 missing SHA-256 tooling is an error; either tool suffices
ok 141 missing jq is an error but --json still emits a report
ok 142 incomplete Git identity is an error
ok 143 git identity follows the effective author identity and supported overrides
ok 144 outside a Git work tree the repo-dependent checks error
ok 145 init mode: Greenfield for an empty-ish repo without .docs
ok 146 init mode: Unaligned-bare for a non-empty repo with no docs spine
ok 147 init mode: partial .docs is Unaligned, not Initialized
ok 148 init mode: Unaligned-migrate when a pre-existing docs spine exists
ok 149 init mode: Initialized wins over an otherwise empty repo
ok 150 coordination: schema 2 with a fresh claim passes
ok 151 coordination: a claim at or beyond the lease TTL is a stale warning
ok 152 coordination: leading-zero timestamps and TTL normalize like loom-coord
ok 153 coordination: unreadable timestamp is an error, never stale
ok 154 coordination: malformed claim records with numeric timestamps are errors
ok 155 coordination: incompatible schema version is an error
ok 156 coordination: claims without a schema ref are an error
ok 157 missing finder asset fails review_protocol
ok 158 non-executable loom-review fails review_protocol
ok 159 missing loom-eval-workspace fails eval_protocol only
ok 160 invalid arguments exit 2 with usage on stderr
ok 161 loom doctor dispatches to loom-doctor with the same human report
ok 162 loom doctor --json dispatches to loom-doctor --json
ok 163 loom forwards the helper's exit status
ok 164 loom forwards invalid doctor arguments as exit 2
ok 165 loom rejects unsupported and missing commands with exit 2
ok 166 loom resolves its adjacent helper through a symlink
ok 167 plan: exports exact objects, canonical schema-valid manifest, exclusions and permissions
ok 168 plan: without an evidence snapshot the source directory is empty
ok 169 plan: evidence snapshot is the complete tree at the declared evidence SHA
ok 170 plan: default root is a private 0700 directory outside the repository
ok 171 plan: independent runs do not share writable paths
ok 172 plan: re-review binds the prior verdict and the exact revision diff
ok 173 research: complete fresh captures with provenance are required and bound
ok 174 research: stale, hash-mismatched, incomplete and unsafe captures fail closed
ok 175 code: exact diff with rename, binary and mode metadata; pinned gate; schema valid
ok 176 code: base-not-ancestor, equal ids, bad options and unavailable objects are rejected
ok 177 code: docs-only status is recorded explicitly and no review findings are included
ok 178 code: unassembled, invalid, mismatched and bootstrap review findings are rejected
ok 179 verify: altered source, input, mode, extra and missing files fail closed after a successful verification
ok 180 verify: manifest edits, bad self-hash, unknown versions and top-level extras are rejected
ok 181 verify: symlinks, hardlinks and special files inside the run are rejected
ok 182 verify: unavailable Git objects are infrastructure-blocked, never valid
ok 183 verify: diff, base and dependency bindings are rechecked for code runs
ok 184 status: incomplete runs exit 3 and a changed run is never valid
ok 185 prepare: unsafe output roots, duplicate and extra inputs are rejected with no partial run
ok 186 prepare: tracked symlinks and gitlinks in the exported tree are rejected, not omitted
ok 187 prepare: external evidence must be a regular, single-link, non-symlink file
ok 188 clean: removes only the selected recognized run
ok 189 clean: rejects foreign directories, symlinked roots, malformed manifests, links and the repository
ok 190 diff: a code diff or revision diff touching excluded content is rejected, with no partial run
ok 191 diff: a changed excluded path that is an explicit input is allowed and rechecked by verify
ok 192 exclusions: plan, research and code snapshots omit status history and unrelated evaluations
ok 193 verify: nested unknown manifest properties are rejected
ok 194 verify: manifest schema validates review run_id type and pattern
ok 195 verify: expired research captures are infrastructure-blocked (4) in verify and status
ok 196 verify: run root, output and scratch must be exactly mode 0700
ok 197 usage: unknown subcommands, missing arguments and help exit 1
ok 198 gate-rerun: a passing gate records schema-valid evidence, leaves source and checkout untouched and cleans up
ok 199 gate-rerun: exact argv with spaces and metacharacters runs in an empty pinned environment with reserved redirects
ok 200 gate-rerun: a nonzero gate is rerun-failed (2) and status agrees
ok 201 gate-rerun: usage errors exit 1; overrides, non-code runs and bad runs are rejected without evidence
ok 202 gate-rerun: pinned tools are probed on the pinned PATH and recorded
ok 203 gate-rerun: missing, mismatched, failing or off-PATH tools are infrastructure-blocked (4) with blocked evidence
ok 204 gate-rerun: pinned dependencies are provided read-only through LOOM_EVAL_DEPS
ok 205 gate-rerun: a gate that alters the immutable source is invalid (2) and the run stays invalid
ok 206 gate-rerun: a gate that alters the checkout is invalid; ignored files and .git internals are not changes
ok 207 gate-rerun: succeeds without a git repository and records the checkout as unchanged
ok 208 gate-rerun: succeeds against a bare repository with no checkout
ok 209 gate-rerun: a corrupted execution copy is invalid (2) and the gate never runs
ok 210 gate-rerun: repeat attempts never overwrite and the latest attempt decides status
ok 211 gate-rerun: status rejects corrupt, stale, cross-run and tampered evidence
ok 212 gate-rerun: catchable interruption terminates the gate group, records interrupted evidence and exits 4
ok 213 gate-rerun: a hard kill leaves an incomplete attempt that can never pass
ok 214 gate-rerun: usage text lists the subcommand
ok 215 record: valid plan evaluation records report and transitions to Approved
ok 216 record: valid ADR evaluation transitions to Accepted
ok 217 record: valid plan FAIL transitions to Draft
ok 218 record: valid code evaluation with passing rerun records report and transitions to Ready to Publish
ok 219 record: valid code FAIL with failing rerun transitions to In Progress
ok 220 record: code PASS with failed rerun attempt fails closed (exit 2)
ok 221 record: schema error in verdict.json fails closed (exit 2)
ok 222 record: PASS carrying BLOCKER or MAJOR finding fails closed (exit 2)
ok 223 record: verdict round mismatch against expected round fails closed (exit 2)
ok 224 record: bound prior verdict replacement succeeds for successor round
ok 225 record: differing existing report without bound prior verdict fails closed (exit 2)
ok 226 record: identical existing report succeeds idempotently (exit 0)
ok 227 record: checkout artifact blob mismatch against reviewed head fails closed (exit 2)
ok 228 record: missing output/verdict.json fails with exit 3
ok 229 record: extra or non-regular files in output/ fails closed (exit 2)
ok 230 record: --claimed-gate holds status advance and reports gate-held
ok 231 record: duplicate object keys in verdict.json are rejected before validation
ok 232 record: nested duplicate object keys in verdict.json are rejected
ok 233 record: --bootstrap-phase publication-intent holds the transition
ok 234 record: omitted bootstrap phase with a held authoritative phase is state-held
ok 235 record: omitted bootstrap phase with no authoritative phase is state-held
ok 236 record: a supplied phase contradicting the authoritative phase fails closed (exit 2)
ok 237 record: authoritative active phase advances with and without a matching supplied phase
ok 238 record: ineligible repository (no ADR 0023) is state-held
ok 239 record: repository with placeholder ADR 0023 and active marker remains state-held
ok 240 record: unrelated repository with copied ADR 0023, alternates, and active marker remains state-held
ok 241 record: ADR 0023 that is a symlink makes the repository ineligible
ok 242 record: a slice outside the ADR 0023 closed list is state-held
ok 243 record: ADR 0023 PASS cannot self-ratify into Accepted
ok 244 record: tampered verdict run_id fails closed
ok 245 record: tampered verdict manifest_sha256 fails closed
ok 246 record: tampered verdict head_sha fails closed
ok 247 record: tampered verdict artifact path fails closed
ok 248 record: tampered verdict authority fails closed
ok 249 record: tampered rerun_attempt.seq fails closed
ok 250 record: tampered rerun_attempt.evidence_sha256 fails closed
ok 251 record: tampered rerun_attempt.result fails closed
ok 252 record: reviewed artifact status mismatch fails closed
ok 253 record: illegal status transition fails closed
ok 254 record: usage text lists the subcommand
ok 255 no arguments is a usage error
ok 256 relative invocation is rejected
ok 257 unsupported mode, bad ref, bad ids and bad head fail before mutation
ok 258 publication without evidence is rejected
ok 259 session without the claim is an ownership failure
ok 260 evidence mismatches fail closed with exit 1 and leave the remote untouched
ok 261 candidate-only builds, gates, records state, cleans up and does not publish
ok 262 candidate-only twice reuses the exact candidate commit
ok 263 gate failure exits 10, preserves state and claim
ok 264 a gate that dirties the candidate exits 10
ok 265 stale disposable branch is cleaned idempotently
ok 266 clean publication pushes, verifies, receipts, releases the claim and updates the mirror
ok 267 dirty, ahead and stale local main cannot enter the candidate
ok 268 target movement before publication rebuilds, exits 3 and needs fresh evidence
ok 269 target movement while acquiring the lock releases the lock, exits 3 and rebuilds on the next run
ok 270 non-fast-forward push race is rejected without force and keeps the claim
ok 271 merge conflict exits 3 and keeps the claim
ok 272 lock contention exits 3 and keeps the claim
ok 273 lock loss after a verified push is recovered without a second push
ok 274 recovery reconstructs a missing receipt when the candidate is already on the remote
ok 275 re-running after success is idempotent
ok 276 unverifiable push (remote rewrites the ref) exits 10 and keeps the claim
ok 277 recovery rejects a receipt left by a different slice and writes a current one
ok 278 stale receipt from another slice cannot release a claim without the claim
ok 279 recovery after remote advancement records the observed target as resultSha
ok 280 recovery receipt write requires the publish lock
ok 281 uncertain prior push not contained in the target stops for owner action
ok 282 verification reads the push destination, not the fetch URL
ok 283 rejected push to a distinct pushurl is not verified from the fetch repository
ok 284 operational git failure while building the candidate exits 10 and keeps the claim
ok 285 recovery verifies containment against the push destination, not the fetch URL
ok 286 recovery rejects a receipt whose bindings differ and writes a current one
ok 287 receipt write failure exits 10 and preserves state and claim
ok 288 unwritable session directory exits 10
ok 289 separate-clone publisher wins the race: loser is rejected, resets the attempt and needs fresh evidence
ok 290 competing publishers in separate clones: winner lands, loser rebuilds and keeps claim
ok 291 failed push preserves publishAttempt and the next run stops with exit 10
ok 292 coordination-state: claim and work start leave tracked main untouched
ok 293 coordination-state: publication carries exactly one slice plus finalization
ok 294 coordination-state: unrelated local main history is never published, also after rebuild
ok 295 coordination-state: missing or incomplete finalize is rejected on a Ready to Publish slice
ok 296 coordination-state: a plan that is not Ready to Publish is rejected
ok 297 coordination-state: finalize is repeatable across time and identity and a failing finalize writes nothing
ok 298 coordination-state: a changed finalize command invalidates the candidate evidence
ok 299 coordination-state: gate and finalize never run under the publish lock
ok 300 coordination-state: a positively rejected push resets the attempt and the loser rebuilds on the winner
ok 301 coordination-state: an unreadable remote after a failed push stays uncertain with exit 10
ok 302 coordination-state: a failed push the server accepted and another publisher advanced is contained, not repushed
ok 303 coordination-state: offline publication keeps main, claim and Ready to Publish plan
ok 304 coordination-state: post-publication cleanup crash recovers without a second push
ok 305 coordination-state: a push reported successful whose remote tip is not the candidate is not contained
ok 306 claude: researcher launches on Economy/haiku with no Agent capability
ok 307 claude: developer launches on Standard/sonnet
ok 308 claude: planner launches on Deep review/opus
ok 309 claude: plan-evaluator launches on Deep review/opus
ok 310 claude: code-evaluator launches on Deep review/opus
ok 311 codex: researcher launches on Economy/gpt-6.1-terra/low
ok 312 codex: developer launches on Standard/gpt-6.1-terra/medium
ok 313 codex: planner launches on Deep review/gpt-6.1-sol/high
ok 314 codex: plan-evaluator launches on Deep review/gpt-6.1-sol/high
ok 315 codex: code-evaluator launches on Deep review/gpt-6.1-sol/high
ok 316 codex: exact argv contract (ephemeral, no user config, strict, no multi-agent, read-only, model/effort, no web search, output schema, canonical contract)
ok 317 codex: the closed bounded-output schema path is a real regular file
ok 318 codex: never emits a bare --model without an exact matrix value
ok 319 usage: unknown client fails with usage error
ok 320 usage: unknown/renamed role fails with usage error
ok 321 usage: missing arguments fails with usage error
ok 322 usage: no arguments fails with usage error
ok 323 usage: extra arguments fail with usage error
ok 324 usage: never accepts a caller-supplied vendor selector as an argument
ok 325 guard: descendant launch attempt is rejected (LOOM_LAUNCH_ROLE_ACTIVE set)
ok 326 guard: descendant launch attempt is rejected for codex too
ok 327 guard: inherited CODEX_MODEL is rejected
ok 328 guard: inherited MODEL_REASONING_EFFORT is rejected
ok 329 guard: inherited OPENAI_MODEL is rejected
ok 330 guard: inherited ANTHROPIC_MODEL is rejected
ok 331 guard: inherited CLAUDE_MODEL is rejected
ok 332 guard: an enabled delegation feature is rejected
ok 333 guard: a falsy delegation-feature value does not trip the guard
ok 334 guard: invocation must be by absolute path
ok 335 cold id: two invocations never reuse the same launch id
ok 336 claude: missing agent adapter file fails closed
ok 337 claude: agent adapter missing the model field fails closed
ok 338 claude: agent adapter missing the tools field fails closed
ok 339 claude: a substituted/renamed model in the agent adapter fails closed
ok 340 claude: an inherited model value fails closed
ok 341 claude: an Agent capability grant in the tools field fails closed (delegation)
ok 342 RED-GREEN: agent-adapter model tampering flips a valid fixture from accept to reject
ok 343 codex: missing compatibility matrix fails closed
ok 344 codex: wrong matrix schema identity fails closed
ok 345 codex: wrong matrix version fails closed
ok 346 codex: a role absent from every profile's consumers fails closed (role/profile drift)
ok 347 codex: a missing model for the resolved profile fails closed (unavailable model)
ok 348 codex: a missing effort for the resolved profile fails closed (unavailable effort)
ok 349 codex: a substituted model for the resolved profile is used verbatim and validated only by enumeration in the schema
ok 350 codex: missing role skill (undefined canonical contract) fails closed
ok 351 codex: missing closed bounded-output schema fails closed (unbounded output)
ok 352 RED-GREEN: matrix schema tampering flips a valid codex fixture from accept to reject
ok 353 static: never reads CLAUDE_PLUGIN_ROOT/PLUGIN_ROOT/CODEX_HOME for root or vendor resolution
ok 354 codex: never consults CLAUDE_PLUGIN_ROOT/PLUGIN_ROOT/CODEX_HOME even when set
ok 355 claude: launch is independent of the caller's working directory
ok 356 codex: launch is independent of the caller's working directory
ok 357 antigravity: researcher launches on Economy/flash with subagent tools disabled
ok 358 antigravity: developer launches on Standard/inherit
ok 359 antigravity: planner, plan-evaluator, and code-evaluator launch on Deep review/pro
ok 360 antigravity: missing canonical role contract fails closed
ok 361 cross-family: --author-client same-family rejection on plan-evaluator and code-evaluator
ok 362 cross-family: --author-client cross-family acceptance emits authorClient and crossFamilyVerified
ok 363 cross-family: LOOM_REQUIRE_CROSS_FAMILY_EVAL=1 without author client fails closed
ok 364 cross-family: auto client deterministically routes claude->codex->antigravity->claude
ok 365 cross-family: --routing-file positive routing and same-family rejection under requireCrossFamilyEval
ok 366 model: codex inherits an ambient gpt-6.1 model from config.toml
ok 367 model: --model and --effort override ambient config and are emitted
ok 368 model: repo config outranks ambient config; flags outrank repo config
ok 369 model: corrupt or invalid repo config fails closed
ok 370 model: emitted codex, antigravity, and cross-family launches validate against the launch schema
ok 371 model: ambient model_reasoning_effort differing from the profile default is honored
ok 372 model: invalid ambient model_reasoning_effort fails closed
ok 373 model: explicit empty --model fails closed
ok 374 model: explicit empty --effort fails closed
ok 375 model: antigravity maps Deep review to the cached opus high variant
ok 376 model: antigravity explicit --model is used verbatim; empty or malformed fails closed
ok 377 model: stale cache triggers discovery and an atomic owner-only rewrite
ok 378 model: fresh cache is used without invoking agy
ok 379 model: missing, corrupted, or group-readable agy cache with no agy falls back to profile floors
ok 380 model: claude --model selects a tier selector; other values fail closed
ok 381 model: invalid --effort fails closed
ok 382 model: invalid --model for codex fails closed
ok 383 model: unsupported or malformed ambient codex model fails closed
ok 384 model: cross-family evaluation is still enforced with overrides
ok 385 claude: resolves loom-coord from a valid CLAUDE_PLUGIN_ROOT
ok 386 claude: resolves loom-verify-identity from a valid CLAUDE_PLUGIN_ROOT
ok 387 codex: resolves loom-verify-identity from a valid skill source path
ok 388 claude: resolves loom-review from a valid CLAUDE_PLUGIN_ROOT
ok 389 codex: resolves loom-review from a valid skill source path
ok 390 claude: resolves loom-eval-workspace from a valid CLAUDE_PLUGIN_ROOT
ok 391 claude: resolves loom-doctor from a valid CLAUDE_PLUGIN_ROOT
ok 392 codex: resolves loom-doctor from a valid skill source path
ok 393 codex: resolves loom-eval-workspace from a valid skill source path
ok 394 codex: resolves loom-coord from a valid skill source path
ok 395 usage: unknown client fails closed with usage error
ok 396 usage: missing arguments fails with usage error
ok 397 usage: codex missing skill-source argument fails with usage error
ok 398 usage: extra arguments fail with usage error
ok 399 claude: unset CLAUDE_PLUGIN_ROOT fails closed
ok 400 claude: relative CLAUDE_PLUGIN_ROOT fails closed
ok 401 claude: helper not allowlisted fails closed
ok 402 claude: wrong manifest name fails closed
ok 403 claude: wrong manifest version fails closed
ok 404 claude: malformed manifest JSON fails closed
ok 405 claude: missing manifest fails closed
ok 406 claude: manifest is a symlink escaping the root fails closed
ok 407 claude: absent helper fails closed
ok 408 claude: non-executable helper fails closed
ok 409 claude: helper symlink escaping the root fails closed
ok 410 claude: helper directory symlink escaping the root fails closed
ok 411 claude: helper found only as a nested (non-direct) child fails closed
ok 412 codex: relative skill source path fails closed
ok 413 codex: empty skill source path fails closed
ok 414 codex: missing skill source file fails closed
ok 415 codex: wrong suffix (not skills/<skill>/SKILL.md) fails closed
ok 416 codex: nested skill segment (extra path component) fails closed
ok 417 codex: frontmatter name mismatched with directory fails closed
ok 418 codex: manifest name mismatch fails closed
ok 419 codex: manifest version mismatch fails closed
ok 420 codex: missing manifest fails closed
ok 421 codex: skill source symlink escaping the root fails closed
ok 422 codex: absent helper fails closed
ok 423 codex: non-executable helper fails closed
ok 424 codex: helper not allowlisted fails closed
ok 425 codex: never consults CLAUDE_PLUGIN_ROOT/PLUGIN_ROOT/CODEX_HOME
ok 426 static: the Codex resolution path never references PATH/CLAUDE_PLUGIN_ROOT/PLUGIN_ROOT/CODEX_HOME for root identity
ok 427 codex: a forbidden environment-only guess cannot substitute for a missing source argument
ok 428 claude: resolution is independent of the caller's working directory
ok 429 codex: resolution is independent of the caller's working directory
ok 430 RED-GREEN: an allowlisted-but-nonexistent helper name would resolve if the allowlist check were removed
ok 431 antigravity: resolves loom-coord from plugins/loom/skills/<skill>/SKILL.md
ok 432 antigravity: resolves loom-coord from .agents/skills/<skill>/SKILL.md in a repo root
ok 433 antigravity: frontmatter name mismatch in .agents/skills/<skill>/SKILL.md fails closed
ok 434 prepare: records exact SHAs, tree, diff hash, inventory, ranges and provenance
ok 435 prepare: source export matches ls-tree and ignores export attributes; no .git
ok 436 prepare: manifest is schema-valid
ok 437 prepare: accepts untracked gate evidence inside the repo; other untracked file rejects
ok 438 prepare: leaves the run directory private and the tree untouched
ok 439 prepare rejects abbreviated, symbolic, range and nonexistent revisions
ok 440 prepare rejects base == head and base not an ancestor
ok 441 prepare rejects a dirty tracked file, other untracked file, and HEAD != head
ok 442 prepare rejects missing, symlinked, out-of-repo plan and modified spec
ok 443 prepare rejects a gitlink in the diff
ok 444 prepare defaults omitted --prompt-hash and --finder-profile to pinned hash and claude:sonnet
ok 445 prepare: explicit --prompt-hash mismatch fails closed with exit 2
ok 446 prepare rejects malformed overrides
ok 447 prepare rejects unknown finder IDs and versions in --prompt-hash and --finder-profile
ok 448 prepare rejects empty explicit override values and entries without a key or '='
ok 449 prepare rejects duplicate overrides for the same finder
ok 450 prepare/validate: prompt byte drift or missing asset fails closed (script-relative root)
ok 451 validate rejects a manifest whose prompt hash is not the pinned hash
ok 452 prepare rejects an existing run and an unknown flag
ok 453 network-silent: no network command is invoked across all subcommands
ok 454 validate accepts mixed results with the right aggregate and schema-valid results
ok 455 validate: all-clean results yield ran-clean
ok 456 validate accepts old-side finding on a deleted file and file-level binary finding
ok 457 validate rejects a missing finder and never reports ran-clean
ok 458 validate rejects duplicate and extra result files
ok 459 validate rejects invalid JSON, invalid UTF-8 and schema violations
ok 460 validate rejects unknown protocol, prompt version/hash, manifest hash and run id mismatch
ok 461 validate rejects a manifest with an unknown protocol major
ok 462 validate rejects failed, truncated and nonzero-exit results
ok 463 validate rejects status/finding inconsistency in both directions
ok 464 validate rejects provenance and binding mismatches in results
ok 465 validate rejects a modified source export (edited, added, removed, chmod'd, attribute-omitted)
ok 466 validate rejects modified diff and input files
ok 467 validate rejects swapped head_tree/SHAs/files[] even when the manifest is re-hashed
ok 468 validate fails closed when the repository or objects are unavailable
ok 469 validate rejects invalid ranges (wrong side, missing side)
ok 470 validate rejects findings at invalid locations
ok 471 validate rejects duplicate finding ids
ok 472 assemble refuses invalid and pending runs without writing
ok 473 assemble output is identity-neutral, deterministic and sorted
ok 474 assemble works for a run directory containing whitespace
ok 475 assemble defaults to .docs/evaluations/<slice>-review-findings.md
ok 476 assemble is atomic: a read-only target directory leaves nothing behind
ok 477 status: prepared -> collecting -> validated -> assembled with exit codes
ok 478 status: invalid exits 2, missing run exits 1, --json parses
ok 479 status never writes
ok 480 status: validate with zero results reports invalid (not prepared), exit 2
ok 481 status: a result changed after a valid verdict is stale -> collecting, exit 3
ok 482 clean removes only the named run, including read-only source
ok 483 clean --all and --older-than
ok 484 clean refuses paths outside the root, symlinked runs, and dirs without a manifest
ok 485 clean never touches committed review-findings files
ok 486 usage errors exit 1
ok 487 registration: loom-review is in every helper allowlist copy
ok 488 registration: validate-repository --all passes
ok 489 finder prompts: each names its finder ID and every boundary clause
ok 490 finder prompts: packaged as non-empty regular files under the plugin root
ok 491 fixtures: per-finder synthetic defects validate and assemble with normalized findings
ok 492 fixtures: failed, truncated, out-of-diff and missing output never assemble or read clean
ok 493 usage: no argument exits 1
ok 494 usage: two arguments exit 1
ok 495 baseline: malformed baseline exits 1
ok 496 baseline: well-formed but unknown SHA exits 1
ok 497 not a repository exits 1
ok 498 unborn baseline with still-unborn HEAD is a no-op (0)
ok 499 unborn baseline with valid first commit exits 0
ok 500 unchanged HEAD is a no-op (0) even when HEAD identity is bad
ok 501 valid new commit after baseline exits 0
ok 502 valid amended HEAD exits 0
ok 503 wrong author exits 2 with SHA and remediation
ok 504 wrong committer exits 2
ok 505 same name but wrong email exits 2
ok 506 loom@localhost fallback exits 2
ok 507 configured localhost email is a config error (1)
ok 508 multiple new commits: a bad middle commit is found
ok 509 multiple bad commits are all reported
ok 510 unborn baseline checks every commit including a bad root commit
ok 511 missing configured user.name fails closed (1)
ok 512 missing configured user.email fails closed (1)
ok 513 baseline given but HEAD unborn fails closed (1)
ok 514 unborn baseline with corrupt HEAD ref fails closed (1)
ok 515 unborn baseline with corrupt HEAD file fails closed (1)
ok 516 unborn baseline with dangling symlink HEAD ref fails closed (1)
ok 517 verifier never mutates history on violation
ok 518 bypassed bad commit stops the workflow; remediation then reverifies clean
ok 519 BLOCK B01: commit --author= with quoted value
ok 520 BLOCK B02: -c user.email= override
ok 521 BLOCK B03: -c user.name= override
ok 522 BLOCK B04: inline GIT_AUTHOR_NAME env
ok 523 BLOCK B05: exported GIT_COMMITTER_EMAIL env
ok 524 BLOCK B06: --author with space form
ok 525 BLOCK B07: -c GIT_AUTHOR_NAME= override
ok 526 BLOCK B08: --author= with quoted value and quoted message
ok 527 BLOCK B09: --author= beside escaped inner quote
ok 528 BLOCK B10: read over-block — -c user.email= on log (accepted fail-closed limitation, ADR 0003)
ok 529 BLOCK B11: read over-block — git log --author= (accepted fail-closed limitation)
ok 530 BLOCK: stderr is a single control-character-free line ending in one LF
ok 531 ALLOW A01: plain commit, no override
ok 532 ALLOW A02: -c core.* is non-identity config
ok 533 ALLOW A03: not a git command
ok 534 ALLOW A04: git only as substring of another word
ok 535 BLOCK F05: author flag text inside message body (accepted false positive)
ok 536 BLOCK F07: GIT_AUTHOR_NAME= inside message body (accepted false positive)
ok 537 BLOCK F08: -c user.email= inside message body (accepted false positive)
ok 538 BLOCK F09: --grep value naming the author flag (accepted false positive)
ok 539 BLOCK F10: escaped-inner-quote message with author flag text
ok 540 BLOCK W01: author flag inside bash -c quoted body
ok 541 BLOCK W02: author flag inside sh -c single-quoted body
ok 542 BLOCK W03: env wrapper with GIT_COMMITTER_NAME assignment
ok 543 BLOCK W04: GIT_AUTHOR_DATE assignment
ok 544 BLOCK W05: unbalanced quoting does not discard a recognized token
ok 545 BLOCK W06: -c author.name and -c committer.email overrides
ok 546 BLOCK W07: -c with quoted user key inside bash -c
ok 547 BLOCK W08: -c GIT_COMMITTER_EMAIL override
ok 548 BLOCK C01: git config user.name value (the two known reproductions)
ok 549 BLOCK C02: git config in each scope and file form
ok 550 BLOCK C03: unset, replace-all, add and edit forms
ok 551 BLOCK C04: quoted value and wrapped git config write
ok 552 BLOCK C05: write after a safe read on a later line
ok 553 BLOCK C06: write after a safe read on the same line
ok 554 BLOCK B12: quoted bare author flag (Claude and Codex wire)
ok 555 ALLOW R01: bare reads of identity keys
ok 556 ALLOW R02: non-identity git config writes are untouched
ok 557 ALLOW R03: ordinary commit with message mentioning config in prose
ok 558 codex BLOCK: wrapped author bypass and config write use the Codex envelope
ok 559 ALLOW A13: unbalanced quoting with no recognized token still allows
ok 560 ALLOW A14: plain git push, no override token
ok 561 ALLOW A15: missing tool_input.command (no target) allows, matching ADR 0003
ok 562 codex ALLOW: exit 0, empty stdout/stderr
ok 563 codex BLOCK: exit 0, empty stderr, exact hookSpecificOutput JSON on stdout
ok 564 malformed: invalid JSON fails closed (claude)
ok 565 malformed: invalid JSON fails closed (codex)
ok 566 malformed: tool_input.command wrong type (number) fails closed
ok 567 malformed: tool_input.command wrong type (array) fails closed
ok 568 malformed: tool_input not an object fails closed
ok 569 root: neither PLUGIN_ROOT nor CLAUDE_PLUGIN_ROOT set fails closed
ok 570 root: both PLUGIN_ROOT and CLAUDE_PLUGIN_ROOT validate (ambiguous) fails closed
ok 571 root: CLAUDE_PLUGIN_ROOT pointing at a non-plugin directory fails closed
ok 572 root: relative CLAUDE_PLUGIN_ROOT fails closed
ok 573 jq absent: fails closed (no grep/sed fallback exists for root/JSON validation)
ok 574 RED-GREEN: a well-typed command still allows while a wrong-typed one is rejected
ok 575 fixture claude/pre-tool-use/allow
ok 576 fixture claude/pre-tool-use/block
ok 577 fixture claude/pre-tool-use/malformed
ok 578 fixture codex/pre-tool-use/allow
ok 579 fixture codex/pre-tool-use/block
ok 580 fixture codex/pre-tool-use/malformed
ok 581 T1a progress-advanced manual -> status 0, marker updated
ok 582 T1b progress-advanced auto -> status 0, marker updated
ok 583 T2 no-progress manual -> status 2, exact single-line reason, marker unchanged
ok 584 T2codex no-progress manual -> exit 0, exact continue/stopReason JSON
ok 585 T3 no-progress auto -> status 0, log line appended, marker unchanged
ok 586 T4 first-run no marker -> status 0, marker created with current SHA
ok 587 T5 round-trip: first-run allow, then no-progress block, then advance allow
ok 588 T6a missing trigger field fails closed (malformed)
ok 589 T6b unknown trigger value fails closed (malformed)
ok 590 T6c the obsolete compaction_trigger field is not recognized -> missing trigger -> malformed
ok 591 T6d trigger wrong JSON type fails closed (malformed)
ok 592 T6e invalid JSON fails closed (malformed)
ok 593 T6f malformed on codex wire uses the JSON continue/stopReason envelope
ok 594 T7a missing session_id fails closed (malformed)
ok 595 T7b session_id with a path separator fails closed (path-traversal attempt)
ok 596 T7c session_id with embedded whitespace/control-shaped content fails closed
ok 597 T7d session_id over the length bound fails closed
ok 598 T7e session_id at the exact length bound (128) is accepted
ok 599 T8a not a git repo -> status 0 (fail-open)
ok 600 T8b empty stdin -> status 0 (fail-open)
ok 601 T9 jq absent -> fails closed (root validation cannot succeed without jq)
ok 602 T10 cwd-independence: running from unrelated dir uses cwd from JSON
ok 603 T11 one session's checkpoint never authorizes another session's manual compaction
ok 604 T12 the no-progress-auto log is capped at LOOM_PRECOMPACT_LOG_CAP lines
ok 605 T13 an interrupted marker write leaves the prior marker intact (atomic rename)
ok 606 T7f session_id with single dots is accepted
ok 607 T7g session_id containing .. fails closed
ok 608 T7h session_id with a leading non-alphanumeric fails closed
ok 609 T7i non-string JSON session_id fails closed
ok 610 T12b auto no-progress log is <timestamp>TAB<session>TAB<anchor>
ok 611 T12b log helper strips control characters
ok 612 T12b invalid or leading-zero LOOM_PRECOMPACT_LOG_CAP falls back to 200
ok 613 T14 coordinated session: first-run allow, block with remediation, advance unblocks
ok 614 T15 one coordinated session's advance never unblocks another
ok 615 T16 coordinated session dir without checkpoint file records checkpoint:none
ok 616 T17 concurrent compactions across sessions keep markers intact, no temp files
ok 617 T18 linked worktree resolves the common git dir
ok 618 RED-GREEN: a recognized trigger still proceeds while an unrecognized one is rejected
ok 619 fixture claude/pre-compact/allow
ok 620 fixture claude/pre-compact/block
ok 621 fixture claude/pre-compact/malformed
ok 622 fixture codex/pre-compact/allow
ok 623 fixture codex/pre-compact/block
ok 624 fixture codex/pre-compact/malformed
ok 625 root: Codex prefers its valid PLUGIN_ROOT when both compatibility roots validate
ok 626 unset LOOM_ROLE fails open for test runners and git mutation
ok 627 orchestrator blocks scripts/check
ok 628 orchestrator blocks bats, cargo test, npm test, pytest
ok 629 orchestrator may run scripts/check with LOOM_ALLOW_ORCHESTRATOR_GATE=1
ok 630 orchestrator gate allowance does not unlock bats
ok 631 orchestrator allows non-test commands
ok 632 evaluators block git mutation
ok 633 code-evaluator allows read-only inspection
ok 634 arguments that mention test runners or mutations are allowed
ok 635 landing exception does not unlock other runners in compound commands
ok 636 evaluators block git mutation behind value-taking global options
ok 637 quoted command words are de-quoted; quoted arguments are ignored
ok 638 missing or empty command allows
ok 639 Claude wire: stderr reason, empty stdout, exit 2
ok 640 Codex wire: deny JSON on stdout, exit 0
ok 641 Codex wire: allow is silent exit 0
ok 642 invalid root, invalid JSON, and wrong-typed command fail closed
ok 643 quoted executable paths containing spaces are blocked at command position
ok 644 quoted executable paths with spaces are blocked after env assignments
ok 645 default selects standard with unspecified risk
ok 646 risk table recommends without changing selection
ok 647 cli profiles select with source cli
ok 648 file profile is used when no flag
ok 649 cli overrides a valid file
ok 650 output is deterministic
ok 651 duplicate keys follow jq last-key-wins
ok 652 invalid config exits 1, even when cli overrides
ok 653 symlink and non-regular profile paths exit 1
ok 654 usage errors exit 2
ok 655 missing repo directory exits 1
ok 656 docs document workflow profiles without skip language
ok 657 prepare creates a marker-owned run below the canonical temp root with schema-valid state
ok 658 RED>GREEN: prepare rejects a symlinked TMPDIR, succeeds against the real dir
ok 659 RED>GREEN: prepare rejects a nonexistent TMPDIR, succeeds against a real one
ok 660 RED>GREEN: prepare rejects run-root/owner-home overlap, succeeds when disjoint
ok 661 RED>GREEN: phase entry rejects a marker mismatch, succeeds once restored
ok 662 RED>GREEN: phase entry rejects candidate drift, succeeds once restored
ok 663 prepare rejects an unresolved --exercise before --prepare (missing run root)
ok 664 one native mutation journals the exact record sequence and preserves worker PID across exec
ok 665 hash chain is contiguous: each record's prevHash equals the previous record's hash
ok 666 full exercise -> uninstall -> clean succeeds end to end and leaves zero residue
ok 667 exercise captures list/discovery, helper-root, and role/hook probes for both clients
ok 668 RED>GREEN: claude uninstall postcondition reads installed_plugins.json, not raw cache presence
ok 669 RED>GREEN: handshake deadline is computed after the pre-inventory walk, not before it
ok 670 residue after uninstall is refused (exit 6)
ok 671 RED>GREEN: a bare empty ancestor directory left under codex-home/plugins is not residue
ok 672 an unmet postcondition with a clean exit is a product failure (exit 5), not a false success
ok 673 a mutation that writes outside its allowed roots is quarantined (exit 3)
ok 674 an infrastructure-block marker in native output classifies exit 4, not a product failure
ok 675 INT during a mutation yields exit 130
ok 676 TERM during a mutation yields exit 143
ok 677 injection before:intent: nothing is journaled, clean retry succeeds
ok 678 injection after:intent (supervisor never spawned): aborts, no cache mutation, clean retry succeeds
ok 679 injection after:supervisor-hello (supervisor dies before release): no mutation, atomic release recovery on retry
ok 680 injection after:native-hello (worker dies before native-release): no mutation, clean retry succeeds
ok 681 injection before:exec (worker dies with native-release durable, before exec): resume never relaunches, terminal records the kill
ok 682 injection supervisor-die-while-worker-continues: durable worker identity prevents a hidden orphan; reconciles to recovered-after-apply
ok 683 exhausting resume attempts under a persistent fault quarantines rather than looping forever
ok 684 an escaped, token-tagged descendant is detected and blocks --clean until it dies
ok 685 a descendant that stays inside the process group but retains the token still blocks --clean
ok 686 RED>GREEN: --clean refuses an unresolved run, succeeds once resolved
ok 687 --clean refuses a symlinked run-root argument
ok 688 --clean refuses a path outside the temp prefix
ok 689 a quarantined run is cleanable only after a fresh complete inventory proves ownership
ok 690 RED>GREEN: a quarantined run with an owned root swapped for an escaping symlink refuses --clean, succeeds once restored
ok 691 RED>GREEN: --clean fails closed on a tampered non-charset runId instead of building a stray receipt path
ok 692 injection before:native-hello (worker dies before its own hello): supervisor's worker-hello-timeout abort and the gate-2 writer-settle path fire together; no early mutation, clean retry succeeds
ok 693 injection before:supervisor-hello (supervisor dies before writing its own hello): no early mutation, exactly one clean reconciliation on retry
ok 694 injection before:native-release (supervisor dies before granting release): the orchestrator resumes and grants the missed release exactly once; the worker -- blocked until then -- proceeds only after, and a clean retry completes
ok 695 injection before:terminal (supervisor dies after full worker exit, before writing terminal): reconciles to recovered-after-apply
ok 696 injection after:terminal (supervisor dies immediately after writing terminal): applies from the durable terminal record
ok 697 injection after:supervisor-hello is operation-agnostic across marketplace-add, uninstall, marketplace-remove, and a codex opKey
ok 698 default root resolution is stable from a nested working directory
ok 699 all mode passes for the valid repository
ok 700 all mode reports a failing metadata root
ok 701 missing validation mode exits 2 with deterministic usage
ok 702 repeated validation mode exits 2 with deterministic usage
ok 703 mixed validation modes exit 2 with deterministic usage
ok 704 negative seeds are inert and cannot match production scans
ok 705 valid dual-client metadata, compatibility, bindings, and fixtures pass
ok 706 explicit non-Git root nested in a parent worktree uses the safe filesystem walk
ok 707 tracked discovery failure in a real Git root fails closed without reading an untracked canary
ok 708 README states both exact client floors and the static Codex limitation
ok 709 thin adapters pass for the real repository tree
ok 710 a command adapter missing its shared-skill pointer fails closed
ok 711 a command adapter that copies the shared workflow body fails closed on line count
ok 712 an agent adapter missing its shared-role pointer fails closed
ok 713 an agent adapter that copies the shared role body fails closed on line count
ok 714 each README client floor fails metadata validation directly when drifted
ok 715 every client-visible claim surface rejects prohibited unqualified wording
ok 716 a narrow evaluation term passes only with the immediate required qualification
ok 717 malformed JSON names the materialized file
ok 718 malformed JSON Schema names the materialized file
ok 719 missing, unterminated, and invalid YAML frontmatter fail with filenames
ok 720 unknown command frontmatter key fails closed
ok 721 unknown agent frontmatter key fails closed independently
ok 722 unknown skill frontmatter key fails closed independently
ok 723 command missing description fails independently
ok 724 agent missing name fails independently
ok 725 Claude manifest rejects a top-level unknown field
ok 726 Claude manifest rejects an unknown nested author field
ok 727 Claude catalog rejects unknown top-level owner and plugin fields independently
ok 728 Codex manifest rejects top-level and nested author unknown fields independently
ok 729 Codex catalog rejects unknown top-level owner and plugin fields independently
ok 730 compatibility matrix closes every nested object boundary
ok 731 Claude root binding rejects an unknown field
ok 732 Codex root binding rejects an unknown field
ok 733 each Claude installed-root requirement fails independently when omitted
ok 734 each Codex installed-root requirement fails independently when omitted
ok 735 installed-root constants reject false or substituted declarations independently
ok 736 catalog-shaped tracked JSON is rejected outside exact live and release-fixture paths
ok 737 null false zero and empty string receive schema diagnostics as metadata values
ok 738 null false zero and empty string receive deterministic referenced-schema diagnostics
ok 739 catalog source escape fails
ok 740 catalog symlink and different physical root fail
ok 741 catalog source resolving to a different physical plugin root fails
ok 742 duplicate catalog names fail independently
ok 743 duplicate component names fail independently
ok 744 manifest product name drift fails independently
ok 745 manifest exact SemVer drift fails independently
ok 746 manifest shared identity drift fails independently
ok 747 catalog product name drift fails independently
ok 748 catalog source identity drift fails independently
ok 749 catalog release provenance drift fails independently
ok 750 client floor drift fails independently
ok 751 profile mapping drift fails independently
ok 752 matrix schema version drift fails independently
ok 753 duplicate root binding ID fails exact pair enforcement
ok 754 swapped root binding ID and path fails exact pair enforcement
ok 755 alternate same-schema root binding path fails exact pair enforcement
ok 756 root binding identity drift fails independently
ok 757 a command adapter pointing at a deleted shared workflow skill fails closed
ok 758 an agent adapter pointing at a deleted shared role contract fails closed
ok 759 a second client-specific hook manifest fails closed
ok 760 missing client manifest reference fails independently
ok 761 missing matrix root reference fails independently
ok 762 missing referenced schema fails independently
ok 763 release fixture drift fails independently
ok 764 release fixture equality ignores object member order
ok 765 release fixture equality preserves array order
ok 766 schema-valid manifest homepage drift fails shared identity
ok 767 schema-invalid metadata path stops before outside semantic reads
ok 768 outside-root sentinels use unique cleanup-owned directories
ok 769 JSON symlink is rejected before parsing outside content
ok 770 frontmatter symlink is rejected before reading outside content
ok 771 schema symlink is rejected before reading outside content
ok 772 release fixture symlink is rejected before reading outside content
ok 773 real tree metadata passes while inert seeds remain tracked
ok 774 forced real-tree validator failure leaves the checkout intact
ok 775 valid relative targets and local and cross-file fragments pass
ok 776 rendered inline heading text and duplicate GitHub suffixes pass
ok 777 encoded spaces Unicode paths and Unicode fragments pass
ok 778 malformed percent encoding fails with source and exact target
ok 779 encoded traversal cannot escape the repository
ok 780 Markdown source symlink is rejected before reading outside content
ok 781 Markdown target symlink is rejected before reading outside content
ok 782 allowlist symlink is rejected before reading outside content
ok 783 missing targets and fragments name source and target
ok 784 only exact historical trees are excluded
ok 785 malformed duplicate and stale allowlist records fail
ok 786 live allowlist entry with empty reason is rejected and does not suppress the link
ok 787 one exact live broken link is allowlisted but code-block pseudo-link is stale
ok 788 one exact live allowlist entry passes and suppresses its broken-link diagnostic
ok 789 exact workflow and toolchain contract passes
ok 790 loom-coord exact Bash shebang is mechanically required
ok 791 git identity guard exact Bash shebang is mechanically required
ok 792 precompact backstop exact Bash shebang is mechanically required
ok 793 workflow runner row deletion fails
ok 794 workflow inline-comment spoof fails exact verified contract
ok 795 workflow commented-out security setting fails exact verified contract
ok 796 workflow duplicate key fails exact verified contract
ok 797 workflow relocated exact-head string fails exact verified contract
ok 798 workflow runner label mutation fails
ok 799 workflow host mutation fails
ok 800 workflow architecture mutation fails
ok 801 workflow release mutation fails
ok 802 workflow selected shell mutation fails
ok 803 workflow Bash regex mutation fails
ok 804 workflow checkout action pin mutation fails
ok 805 workflow exact-head checkout ref mutation fails
ok 806 workflow exact-head environment mutation fails
ok 807 workflow exact-head assertion mutation fails
ok 808 workflow exact-head log deletion fails
ok 809 workflow selected-shell physical resolver deletion fails
ok 810 toolchain runner deletion fails closed
ok 811 exact tool version mutation fails closed
ok 812 runtime floor mutation fails closed
ok 813 checkout contract pin mutation fails closed
ok 814 package-lock contract digest mutation fails closed
ok 815 unexpected toolchain top-level field fails closed
ok 816 required download deletion fails closed
ok 817 download platform mutation fails closed
ok 818 download URL mutation fails closed
ok 819 download digest mutation fails closed on an unselected platform
ok 820 required vendored asset deletion fails closed
ok 821 vendored asset path mutation fails closed
ok 822 vendored provenance omission fails closed
ok 823 vendored provenance kind mutation fails closed
ok 824 vendored digest mutation fails closed
ok 825 gate independently rejects a selected Bash below 3.2
ok 826 Git immediately below 2.34 is rejected with an actionable diagnostic
ok 827 Git exact floor 2.34 is accepted
ok 828 jq immediately below 1.6 is rejected with an actionable diagnostic
ok 829 jq exact floor 1.6 is accepted
ok 830 unknown host OS is rejected before provisioning
ok 831 supported host OS with unsupported architecture is rejected before provisioning
ok 832 first-stage failure preserves status and emits one exact diagnostic before later stages
ok 833 advanced-stage failure preserves status and stops before every later stage
ok 834 gate resolves terminal and relative multihop selected-Bash symlinks
ok 835 gate HUP cleanup is deterministic and exits 129 without success
ok 836 gate INT cleanup is deterministic and exits 130 without success
ok 837 gate TERM cleanup is deterministic and exits 143 without success
ok 838 fresh provisioning ignores a poisoned persistent extracted-tool tree
ok 839 Bats version probing cannot execute a poisoned ambient bash
ok 840 cache-root symlink is rejected without touching its owned target
ok 841 cached-download symlink is rejected without overwriting its target
ok 842 owner-controlled cache directories are repaired before use
ok 843 hard-linked cached download is rejected without mutating its outside sentinel
ok 844 unexpected cache ownership is rejected
ok 845 cache rewrite race never executes unauthenticated bytes
ok 846 packaging: conforming LICENSE and CHANGELOG pass
ok 847 packaging: missing LICENSE and CHANGELOG are reported
ok 848 packaging: altered MIT text or copyright is reported
ok 849 packaging: absent or duplicate version heading is reported
ok 850 packaging: empty or whitespace-only version section is reported
ok 851 packaging: fenced list markers do not satisfy the release list requirement
ok 852 packaging: fenced level-two heading does not end the version section
ok 853 packaging: mismatched fence characters stay fenced content
ok 854 packaging: shorter closing fence does not close the block
ok 855 packaging: matching or longer closing fence closes the block
ok 856 packaging: metadata and links modes do not require LICENSE or CHANGELOG
ok 857 docs state: valid fixture passes and reports transitions unverified
ok 858 docs state: illegal and duplicate status fields name the file
ok 859 docs state: archived plans must be Landed or Archived and plan identity is unique
ok 860 docs state: evaluation names accept every legal form and reject others
ok 861 docs state: round, verdict and status fields on evaluations are validated
ok 862 docs state: round sequence follows commit ancestry and rejects unrecorded resets
ok 863 docs state: first evaluation must be round 0 and ordering needs a recorded commit
ok 864 docs state: non-merits FAIL does not advance and Owner-Reset must be a recorded decision
ok 865 docs state: required headings and authority references are enforced
ok 866 docs state: historical links are checked under all but not links mode
ok 867 docs state: rule exceptions are exact and stale ones fail
ok 868 baseline legal transition
ok 869 baseline illegal transition
ok 870 baseline archive rename
ok 871 baseline archive rename before landing is rejected
ok 872 baseline invalid ref
ok 873 baseline usage errors
ok 874 baseline transitive jump without intermediate evidence is rejected
ok 875 baseline Ready to Publish cannot move directly into the archive
ok 876 baseline Needs Clarification restores only the prior status
ok 877 baseline FAIL returns need a recorded FAIL evaluation
ok 878 baseline FAIL return evidence must match the phase and be ordered after the rejected status
ok 879 baseline FAIL return evidence is bounded to the rejected-status interval
ok 880 docs state: evaluation bare authority names must resolve to applicable files
ok 881 docs state: generic evaluation authority must resolve to the artifact's applicable file
ok 882 docs state: ADR problem grounding rejects arbitrary top-level docs
ok 883 docs state: Owner-Reset is validated on the first event and requires the owner decision text
ok 884 docs state: ADR problem statement must be approved research or the designated problem document
ok 885 docs state: evaluation artifact and authority must be applicable references
ok 886 docs state: ADR authority needs approved research or problem and accepted prior authority
ok 887 docs state: plan targets must be approved specs and accepted ADRs
ok 888 docs state: evaluation artifact and authority identification must resolve
ok 889 docs state: an archived historical plan does not block the one active plan
ok 890 docs state: unused historical allowlist records fail under all even when the source is gone
ok 891 docs state: living docs fixture passes and metadata/links ignore living rules
ok 892 docs state: handoff passes at 150 lines and fails at 151, with or without final newline
ok 893 docs state: missing living documents fail naming the path
ok 894 docs state: milestone markers must be single, well formed and matching in all four documents
ok 895 docs state: handoff, progress and roadmap required headings are enforced
ok 896 docs state: duplicate required living headings fail naming the path
ok 897 docs state: action history needs standard dated entries
ok 898 docs state: roadmap needs exactly one in-progress unchecked milestone matching the marker
ok 899 init creates manifest and ten distinct templates that validate
ok 900 init refuses an existing directory and leaves it unchanged
ok 901 usage errors exit 2
ok 902 complete dataset validates and summarizes
ok 903 delta is loom minus single-agent in both directions
ok 904 incomplete members and null metrics with reasons yield unknown
ok 905 missing manifest and missing record
ok 906 malformed json and wrong schema or keys
ok 907 duplicate pair names the pair
ok 908 negative, noninteger, and bad values name the field
ok 909 invalid and reversed timestamps
ok 910 impossible calendar dates are rejected
ok 911 missing provenance, evidence, and unknown reason

==> relative links
Repository links validation passed

==> Claude strict plugin validation
Validating plugin manifest: /Users/craig/git/loom/plugins/loom/.claude-plugin/plugin.json

✔ Validation passed

==> diff whitespace

All checks passed
```
