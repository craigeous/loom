# Evaluation: local-review-agents (code)

Verdict: PASS
Round: 0
Reviewed against: commit b0033b9310d29a7dc6451d3a88afdc24211e2235, revision diff 9c1a0b3..b0033b9, local-review-agents slice plan, prior Round 0 evaluation, ADRs 0021 and 0022, findings schema, code evaluation rubric and severity rules.

## Findings

No unresolved blockers or majors. No new defects were found in the revision diff.

## Required changes (for FAIL)

None.

## Notes

The revision validates all explicit override entries before defaults, rejecting unknown IDs and versions, malformed or empty values, mismatched hashes and duplicate keys; added tests exercise these cases without creating a run. The fixture runner now reads the assigned prompt, finds each deliberate defect in prepared source, verifies its changed range, and checks concrete evidence and location through validation and assembly. This is a deterministic controlled fixture, not a live-model detection claim. No advisory findings artifact was supplied within the authorized inputs.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 0 | code | FAIL | Two blockers: invalid overrides were silently defaulted or ignored, and defect fixtures did not exercise prompts or defects. Revision diff 9c1a0b3..b0033b9 adds explicit override validation and negative tests, plus defect-specific prompt-consuming fixtures with concrete locations and evidence. Both are resolved. |

## Gate rerun evidence

Command: `scripts/check` (exit 0; 702 Bats tests passed; selected Bash 5.3.9). Exact combined output:
```text

==> toolchain contract and pinned digests

==> locked JavaScript dependencies and metadata validation

added 17 packages in 1s
Repository metadata validation passed

==> shfmt

==> ShellCheck

==> Bash syntax

==> Bats tests
Discovered 702 Bats tests
Selected Bash: /opt/homebrew/Cellar/bash/5.3.9/bin/bash (5.3.9(1)-release)
1..702
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
ok 128 no arguments is a usage error
ok 129 relative invocation is rejected
ok 130 unsupported mode, bad ref, bad ids and bad head fail before mutation
ok 131 publication without evidence is rejected
ok 132 session without the claim is an ownership failure
ok 133 evidence mismatches fail closed with exit 1 and leave the remote untouched
ok 134 candidate-only builds, gates, records state, cleans up and does not publish
ok 135 candidate-only twice reuses the exact candidate commit
ok 136 gate failure exits 10, preserves state and claim
ok 137 a gate that dirties the candidate exits 10
ok 138 stale disposable branch is cleaned idempotently
ok 139 clean publication pushes, verifies, receipts, releases the claim and updates the mirror
ok 140 dirty, ahead and stale local main cannot enter the candidate
ok 141 target movement before publication rebuilds, exits 3 and needs fresh evidence
ok 142 target movement while acquiring the lock releases the lock, exits 3 and rebuilds on the next run
ok 143 non-fast-forward push race is rejected without force and keeps the claim
ok 144 merge conflict exits 3 and keeps the claim
ok 145 lock contention exits 3 and keeps the claim
ok 146 lock loss after a verified push is recovered without a second push
ok 147 recovery reconstructs a missing receipt when the candidate is already on the remote
ok 148 re-running after success is idempotent
ok 149 unverifiable push (remote rewrites the ref) exits 10 and keeps the claim
ok 150 recovery rejects a receipt left by a different slice and writes a current one
ok 151 stale receipt from another slice cannot release a claim without the claim
ok 152 recovery after remote advancement records the observed target as resultSha
ok 153 recovery receipt write requires the publish lock
ok 154 uncertain prior push not contained in the target stops for owner action
ok 155 verification reads the push destination, not the fetch URL
ok 156 rejected push to a distinct pushurl is not verified from the fetch repository
ok 157 operational git failure while building the candidate exits 10 and keeps the claim
ok 158 recovery verifies containment against the push destination, not the fetch URL
ok 159 recovery rejects a receipt whose bindings differ and writes a current one
ok 160 receipt write failure exits 10 and preserves state and claim
ok 161 unwritable session directory exits 10
ok 162 separate-clone publisher wins the race: loser is rejected, resets the attempt and needs fresh evidence
ok 163 competing publishers in separate clones: winner lands, loser rebuilds and keeps claim
ok 164 failed push preserves publishAttempt and the next run stops with exit 10
ok 165 coordination-state: claim and work start leave tracked main untouched
ok 166 coordination-state: publication carries exactly one slice plus finalization
ok 167 coordination-state: unrelated local main history is never published, also after rebuild
ok 168 coordination-state: missing or incomplete finalize is rejected on a Ready to Publish slice
ok 169 coordination-state: a plan that is not Ready to Publish is rejected
ok 170 coordination-state: finalize is repeatable across time and identity and a failing finalize writes nothing
ok 171 coordination-state: a changed finalize command invalidates the candidate evidence
ok 172 coordination-state: gate and finalize never run under the publish lock
ok 173 coordination-state: a positively rejected push resets the attempt and the loser rebuilds on the winner
ok 174 coordination-state: an unreadable remote after a failed push stays uncertain with exit 10
ok 175 coordination-state: a failed push the server accepted and another publisher advanced is contained, not repushed
ok 176 coordination-state: offline publication keeps main, claim and Ready to Publish plan
ok 177 coordination-state: post-publication cleanup crash recovers without a second push
ok 178 coordination-state: a push reported successful whose remote tip is not the candidate is not contained
ok 179 claude: researcher launches on Economy/haiku with no Agent capability
ok 180 claude: developer launches on Standard/sonnet
ok 181 claude: planner launches on Deep review/opus
ok 182 claude: plan-evaluator launches on Deep review/opus
ok 183 claude: code-evaluator launches on Deep review/opus
ok 184 codex: researcher launches on Economy/gpt-6.1-terra/low
ok 185 codex: developer launches on Standard/gpt-6.1-terra/medium
ok 186 codex: planner launches on Deep review/gpt-6.1-sol/high
ok 187 codex: plan-evaluator launches on Deep review/gpt-6.1-sol/high
ok 188 codex: code-evaluator launches on Deep review/gpt-6.1-sol/high
ok 189 codex: exact argv contract (ephemeral, no user config, strict, no multi-agent, read-only, model/effort, no web search, output schema, canonical contract)
ok 190 codex: the closed bounded-output schema path is a real regular file
ok 191 codex: never emits a bare --model without an exact matrix value
ok 192 usage: unknown client fails with usage error
ok 193 usage: unknown/renamed role fails with usage error
ok 194 usage: missing arguments fails with usage error
ok 195 usage: no arguments fails with usage error
ok 196 usage: extra arguments fail with usage error
ok 197 usage: never accepts a caller-supplied vendor selector as an argument
ok 198 guard: descendant launch attempt is rejected (LOOM_LAUNCH_ROLE_ACTIVE set)
ok 199 guard: descendant launch attempt is rejected for codex too
ok 200 guard: inherited CODEX_MODEL is rejected
ok 201 guard: inherited MODEL_REASONING_EFFORT is rejected
ok 202 guard: inherited OPENAI_MODEL is rejected
ok 203 guard: inherited ANTHROPIC_MODEL is rejected
ok 204 guard: inherited CLAUDE_MODEL is rejected
ok 205 guard: an enabled delegation feature is rejected
ok 206 guard: a falsy delegation-feature value does not trip the guard
ok 207 guard: invocation must be by absolute path
ok 208 cold id: two invocations never reuse the same launch id
ok 209 claude: missing agent adapter file fails closed
ok 210 claude: agent adapter missing the model field fails closed
ok 211 claude: agent adapter missing the tools field fails closed
ok 212 claude: a substituted/renamed model in the agent adapter fails closed
ok 213 claude: an inherited model value fails closed
ok 214 claude: an Agent capability grant in the tools field fails closed (delegation)
ok 215 RED-GREEN: agent-adapter model tampering flips a valid fixture from accept to reject
ok 216 codex: missing compatibility matrix fails closed
ok 217 codex: wrong matrix schema identity fails closed
ok 218 codex: wrong matrix version fails closed
ok 219 codex: a role absent from every profile's consumers fails closed (role/profile drift)
ok 220 codex: a missing model for the resolved profile fails closed (unavailable model)
ok 221 codex: a missing effort for the resolved profile fails closed (unavailable effort)
ok 222 codex: a substituted model for the resolved profile is used verbatim and validated only by enumeration in the schema
ok 223 codex: missing role skill (undefined canonical contract) fails closed
ok 224 codex: missing closed bounded-output schema fails closed (unbounded output)
ok 225 RED-GREEN: matrix schema tampering flips a valid codex fixture from accept to reject
ok 226 static: never reads CLAUDE_PLUGIN_ROOT/PLUGIN_ROOT/CODEX_HOME for root or vendor resolution
ok 227 codex: never consults CLAUDE_PLUGIN_ROOT/PLUGIN_ROOT/CODEX_HOME even when set
ok 228 claude: launch is independent of the caller's working directory
ok 229 codex: launch is independent of the caller's working directory
ok 230 antigravity: researcher launches on Economy/flash with subagent tools disabled
ok 231 antigravity: developer launches on Standard/inherit
ok 232 antigravity: planner, plan-evaluator, and code-evaluator launch on Deep review/pro
ok 233 antigravity: missing canonical role contract fails closed
ok 234 cross-family: --author-client same-family rejection on plan-evaluator and code-evaluator
ok 235 cross-family: --author-client cross-family acceptance emits authorClient and crossFamilyVerified
ok 236 cross-family: LOOM_REQUIRE_CROSS_FAMILY_EVAL=1 without author client fails closed
ok 237 cross-family: auto client deterministically routes claude->codex->antigravity->claude
ok 238 cross-family: --routing-file positive routing and same-family rejection under requireCrossFamilyEval
ok 239 model: codex inherits an ambient gpt-6.1 model from config.toml
ok 240 model: --model and --effort override ambient config and are emitted
ok 241 model: repo config outranks ambient config; flags outrank repo config
ok 242 model: corrupt or invalid repo config fails closed
ok 243 model: emitted codex, antigravity, and cross-family launches validate against the launch schema
ok 244 model: ambient model_reasoning_effort differing from the profile default is honored
ok 245 model: invalid ambient model_reasoning_effort fails closed
ok 246 model: explicit empty --model fails closed
ok 247 model: explicit empty --effort fails closed
ok 248 model: antigravity maps Deep review to the cached opus high variant
ok 249 model: antigravity explicit --model is used verbatim; empty or malformed fails closed
ok 250 model: stale cache triggers discovery and an atomic owner-only rewrite
ok 251 model: fresh cache is used without invoking agy
ok 252 model: missing, corrupted, or group-readable agy cache with no agy falls back to profile floors
ok 253 model: claude --model selects a tier selector; other values fail closed
ok 254 model: invalid --effort fails closed
ok 255 model: invalid --model for codex fails closed
ok 256 model: unsupported or malformed ambient codex model fails closed
ok 257 model: cross-family evaluation is still enforced with overrides
ok 258 claude: resolves loom-coord from a valid CLAUDE_PLUGIN_ROOT
ok 259 claude: resolves loom-verify-identity from a valid CLAUDE_PLUGIN_ROOT
ok 260 codex: resolves loom-verify-identity from a valid skill source path
ok 261 claude: resolves loom-review from a valid CLAUDE_PLUGIN_ROOT
ok 262 codex: resolves loom-review from a valid skill source path
ok 263 codex: resolves loom-coord from a valid skill source path
ok 264 usage: unknown client fails closed with usage error
ok 265 usage: missing arguments fails with usage error
ok 266 usage: codex missing skill-source argument fails with usage error
ok 267 usage: extra arguments fail with usage error
ok 268 claude: unset CLAUDE_PLUGIN_ROOT fails closed
ok 269 claude: relative CLAUDE_PLUGIN_ROOT fails closed
ok 270 claude: helper not allowlisted fails closed
ok 271 claude: wrong manifest name fails closed
ok 272 claude: wrong manifest version fails closed
ok 273 claude: malformed manifest JSON fails closed
ok 274 claude: missing manifest fails closed
ok 275 claude: manifest is a symlink escaping the root fails closed
ok 276 claude: absent helper fails closed
ok 277 claude: non-executable helper fails closed
ok 278 claude: helper symlink escaping the root fails closed
ok 279 claude: helper directory symlink escaping the root fails closed
ok 280 claude: helper found only as a nested (non-direct) child fails closed
ok 281 codex: relative skill source path fails closed
ok 282 codex: empty skill source path fails closed
ok 283 codex: missing skill source file fails closed
ok 284 codex: wrong suffix (not skills/<skill>/SKILL.md) fails closed
ok 285 codex: nested skill segment (extra path component) fails closed
ok 286 codex: frontmatter name mismatched with directory fails closed
ok 287 codex: manifest name mismatch fails closed
ok 288 codex: manifest version mismatch fails closed
ok 289 codex: missing manifest fails closed
ok 290 codex: skill source symlink escaping the root fails closed
ok 291 codex: absent helper fails closed
ok 292 codex: non-executable helper fails closed
ok 293 codex: helper not allowlisted fails closed
ok 294 codex: never consults CLAUDE_PLUGIN_ROOT/PLUGIN_ROOT/CODEX_HOME
ok 295 static: the Codex resolution path never references PATH/CLAUDE_PLUGIN_ROOT/PLUGIN_ROOT/CODEX_HOME for root identity
ok 296 codex: a forbidden environment-only guess cannot substitute for a missing source argument
ok 297 claude: resolution is independent of the caller's working directory
ok 298 codex: resolution is independent of the caller's working directory
ok 299 RED-GREEN: an allowlisted-but-nonexistent helper name would resolve if the allowlist check were removed
ok 300 antigravity: resolves loom-coord from plugins/loom/skills/<skill>/SKILL.md
ok 301 antigravity: resolves loom-coord from .agents/skills/<skill>/SKILL.md in a repo root
ok 302 antigravity: frontmatter name mismatch in .agents/skills/<skill>/SKILL.md fails closed
ok 303 prepare: records exact SHAs, tree, diff hash, inventory, ranges and provenance
ok 304 prepare: source export matches ls-tree and ignores export attributes; no .git
ok 305 prepare: manifest is schema-valid
ok 306 prepare: accepts untracked gate evidence inside the repo; other untracked file rejects
ok 307 prepare: leaves the run directory private and the tree untouched
ok 308 prepare rejects abbreviated, symbolic, range and nonexistent revisions
ok 309 prepare rejects base == head and base not an ancestor
ok 310 prepare rejects a dirty tracked file, other untracked file, and HEAD != head
ok 311 prepare rejects missing, symlinked, out-of-repo plan and modified spec
ok 312 prepare rejects a gitlink in the diff
ok 313 prepare defaults omitted --prompt-hash and --finder-profile to pinned hash and claude:sonnet
ok 314 prepare: explicit --prompt-hash mismatch fails closed with exit 2
ok 315 prepare rejects malformed overrides
ok 316 prepare rejects unknown finder IDs and versions in --prompt-hash and --finder-profile
ok 317 prepare rejects empty explicit override values and entries without a key or '='
ok 318 prepare rejects duplicate overrides for the same finder
ok 319 prepare/validate: prompt byte drift or missing asset fails closed (script-relative root)
ok 320 validate rejects a manifest whose prompt hash is not the pinned hash
ok 321 prepare rejects an existing run and an unknown flag
ok 322 network-silent: no network command is invoked across all subcommands
ok 323 validate accepts mixed results with the right aggregate and schema-valid results
ok 324 validate: all-clean results yield ran-clean
ok 325 validate accepts old-side finding on a deleted file and file-level binary finding
ok 326 validate rejects a missing finder and never reports ran-clean
ok 327 validate rejects duplicate and extra result files
ok 328 validate rejects invalid JSON, invalid UTF-8 and schema violations
ok 329 validate rejects unknown protocol, prompt version/hash, manifest hash and run id mismatch
ok 330 validate rejects a manifest with an unknown protocol major
ok 331 validate rejects failed, truncated and nonzero-exit results
ok 332 validate rejects status/finding inconsistency in both directions
ok 333 validate rejects provenance and binding mismatches in results
ok 334 validate rejects a modified source export (edited, added, removed, chmod'd, attribute-omitted)
ok 335 validate rejects modified diff and input files
ok 336 validate rejects swapped head_tree/SHAs/files[] even when the manifest is re-hashed
ok 337 validate fails closed when the repository or objects are unavailable
ok 338 validate rejects invalid ranges (wrong side, missing side)
ok 339 validate rejects findings at invalid locations
ok 340 validate rejects duplicate finding ids
ok 341 assemble refuses invalid and pending runs without writing
ok 342 assemble output is identity-neutral, deterministic and sorted
ok 343 assemble works for a run directory containing whitespace
ok 344 assemble defaults to .docs/evaluations/<slice>-review-findings.md
ok 345 assemble is atomic: a read-only target directory leaves nothing behind
ok 346 status: prepared -> collecting -> validated -> assembled with exit codes
ok 347 status: invalid exits 2, missing run exits 1, --json parses
ok 348 status never writes
ok 349 status: validate with zero results reports invalid (not prepared), exit 2
ok 350 status: a result changed after a valid verdict is stale -> collecting, exit 3
ok 351 clean removes only the named run, including read-only source
ok 352 clean --all and --older-than
ok 353 clean refuses paths outside the root, symlinked runs, and dirs without a manifest
ok 354 clean never touches committed review-findings files
ok 355 usage errors exit 1
ok 356 registration: loom-review is last in every helper allowlist copy
ok 357 registration: validate-repository --all passes
ok 358 finder prompts: each names its finder ID and every boundary clause
ok 359 finder prompts: packaged as non-empty regular files under the plugin root
ok 360 fixtures: per-finder synthetic defects validate and assemble with normalized findings
ok 361 fixtures: failed, truncated, out-of-diff and missing output never assemble or read clean
ok 362 usage: no argument exits 1
ok 363 usage: two arguments exit 1
ok 364 baseline: malformed baseline exits 1
ok 365 baseline: well-formed but unknown SHA exits 1
ok 366 not a repository exits 1
ok 367 unborn baseline with still-unborn HEAD is a no-op (0)
ok 368 unborn baseline with valid first commit exits 0
ok 369 unchanged HEAD is a no-op (0) even when HEAD identity is bad
ok 370 valid new commit after baseline exits 0
ok 371 valid amended HEAD exits 0
ok 372 wrong author exits 2 with SHA and remediation
ok 373 wrong committer exits 2
ok 374 same name but wrong email exits 2
ok 375 loom@localhost fallback exits 2
ok 376 configured localhost email is a config error (1)
ok 377 multiple new commits: a bad middle commit is found
ok 378 multiple bad commits are all reported
ok 379 unborn baseline checks every commit including a bad root commit
ok 380 missing configured user.name fails closed (1)
ok 381 missing configured user.email fails closed (1)
ok 382 baseline given but HEAD unborn fails closed (1)
ok 383 unborn baseline with corrupt HEAD ref fails closed (1)
ok 384 unborn baseline with corrupt HEAD file fails closed (1)
ok 385 unborn baseline with dangling symlink HEAD ref fails closed (1)
ok 386 verifier never mutates history on violation
ok 387 bypassed bad commit stops the workflow; remediation then reverifies clean
ok 388 BLOCK B01: commit --author= with quoted value
ok 389 BLOCK B02: -c user.email= override
ok 390 BLOCK B03: -c user.name= override
ok 391 BLOCK B04: inline GIT_AUTHOR_NAME env
ok 392 BLOCK B05: exported GIT_COMMITTER_EMAIL env
ok 393 BLOCK B06: --author with space form
ok 394 BLOCK B07: -c GIT_AUTHOR_NAME= override
ok 395 BLOCK B08: --author= with quoted value and quoted message
ok 396 BLOCK B09: --author= beside escaped inner quote
ok 397 BLOCK B10: read over-block — -c user.email= on log (accepted fail-closed limitation, ADR 0003)
ok 398 BLOCK B11: read over-block — git log --author= (accepted fail-closed limitation)
ok 399 BLOCK: stderr is a single control-character-free line ending in one LF
ok 400 ALLOW A01: plain commit, no override
ok 401 ALLOW A02: -c core.* is non-identity config
ok 402 ALLOW A03: not a git command
ok 403 ALLOW A04: git only as substring of another word
ok 404 BLOCK F05: author flag text inside message body (accepted false positive)
ok 405 BLOCK F07: GIT_AUTHOR_NAME= inside message body (accepted false positive)
ok 406 BLOCK F08: -c user.email= inside message body (accepted false positive)
ok 407 BLOCK F09: --grep value naming the author flag (accepted false positive)
ok 408 BLOCK F10: escaped-inner-quote message with author flag text
ok 409 BLOCK W01: author flag inside bash -c quoted body
ok 410 BLOCK W02: author flag inside sh -c single-quoted body
ok 411 BLOCK W03: env wrapper with GIT_COMMITTER_NAME assignment
ok 412 BLOCK W04: GIT_AUTHOR_DATE assignment
ok 413 BLOCK W05: unbalanced quoting does not discard a recognized token
ok 414 BLOCK W06: -c author.name and -c committer.email overrides
ok 415 BLOCK W07: -c with quoted user key inside bash -c
ok 416 BLOCK W08: -c GIT_COMMITTER_EMAIL override
ok 417 BLOCK C01: git config user.name value (the two known reproductions)
ok 418 BLOCK C02: git config in each scope and file form
ok 419 BLOCK C03: unset, replace-all, add and edit forms
ok 420 BLOCK C04: quoted value and wrapped git config write
ok 421 BLOCK C05: write after a safe read on a later line
ok 422 BLOCK C06: write after a safe read on the same line
ok 423 BLOCK B12: quoted bare author flag (Claude and Codex wire)
ok 424 ALLOW R01: bare reads of identity keys
ok 425 ALLOW R02: non-identity git config writes are untouched
ok 426 ALLOW R03: ordinary commit with message mentioning config in prose
ok 427 codex BLOCK: wrapped author bypass and config write use the Codex envelope
ok 428 ALLOW A13: unbalanced quoting with no recognized token still allows
ok 429 ALLOW A14: plain git push, no override token
ok 430 ALLOW A15: missing tool_input.command (no target) allows, matching ADR 0003
ok 431 codex ALLOW: exit 0, empty stdout/stderr
ok 432 codex BLOCK: exit 0, empty stderr, exact hookSpecificOutput JSON on stdout
ok 433 malformed: invalid JSON fails closed (claude)
ok 434 malformed: invalid JSON fails closed (codex)
ok 435 malformed: tool_input.command wrong type (number) fails closed
ok 436 malformed: tool_input.command wrong type (array) fails closed
ok 437 malformed: tool_input not an object fails closed
ok 438 root: neither PLUGIN_ROOT nor CLAUDE_PLUGIN_ROOT set fails closed
ok 439 root: both PLUGIN_ROOT and CLAUDE_PLUGIN_ROOT validate (ambiguous) fails closed
ok 440 root: CLAUDE_PLUGIN_ROOT pointing at a non-plugin directory fails closed
ok 441 root: relative CLAUDE_PLUGIN_ROOT fails closed
ok 442 jq absent: fails closed (no grep/sed fallback exists for root/JSON validation)
ok 443 RED-GREEN: a well-typed command still allows while a wrong-typed one is rejected
ok 444 fixture claude/pre-tool-use/allow
ok 445 fixture claude/pre-tool-use/block
ok 446 fixture claude/pre-tool-use/malformed
ok 447 fixture codex/pre-tool-use/allow
ok 448 fixture codex/pre-tool-use/block
ok 449 fixture codex/pre-tool-use/malformed
ok 450 T1a progress-advanced manual -> status 0, marker updated
ok 451 T1b progress-advanced auto -> status 0, marker updated
ok 452 T2 no-progress manual -> status 2, exact single-line reason, marker unchanged
ok 453 T2codex no-progress manual -> exit 0, exact continue/stopReason JSON
ok 454 T3 no-progress auto -> status 0, log line appended, marker unchanged
ok 455 T4 first-run no marker -> status 0, marker created with current SHA
ok 456 T5 round-trip: first-run allow, then no-progress block, then advance allow
ok 457 T6a missing trigger field fails closed (malformed)
ok 458 T6b unknown trigger value fails closed (malformed)
ok 459 T6c the obsolete compaction_trigger field is not recognized -> missing trigger -> malformed
ok 460 T6d trigger wrong JSON type fails closed (malformed)
ok 461 T6e invalid JSON fails closed (malformed)
ok 462 T6f malformed on codex wire uses the JSON continue/stopReason envelope
ok 463 T7a missing session_id fails closed (malformed)
ok 464 T7b session_id with a path separator fails closed (path-traversal attempt)
ok 465 T7c session_id with embedded whitespace/control-shaped content fails closed
ok 466 T7d session_id over the length bound fails closed
ok 467 T7e session_id at the exact length bound (128) is accepted
ok 468 T8a not a git repo -> status 0 (fail-open)
ok 469 T8b empty stdin -> status 0 (fail-open)
ok 470 T9 jq absent -> fails closed (root validation cannot succeed without jq)
ok 471 T10 cwd-independence: running from unrelated dir uses cwd from JSON
ok 472 T11 one session's checkpoint never authorizes another session's manual compaction
ok 473 T12 the no-progress-auto log is capped at LOOM_PRECOMPACT_LOG_CAP lines
ok 474 T13 an interrupted marker write leaves the prior marker intact (atomic rename)
ok 475 T7f session_id with single dots is accepted
ok 476 T7g session_id containing .. fails closed
ok 477 T7h session_id with a leading non-alphanumeric fails closed
ok 478 T7i non-string JSON session_id fails closed
ok 479 T12b auto no-progress log is <timestamp>TAB<session>TAB<anchor>
ok 480 T12b log helper strips control characters
ok 481 T12b invalid or leading-zero LOOM_PRECOMPACT_LOG_CAP falls back to 200
ok 482 T14 coordinated session: first-run allow, block with remediation, advance unblocks
ok 483 T15 one coordinated session's advance never unblocks another
ok 484 T16 coordinated session dir without checkpoint file records checkpoint:none
ok 485 T17 concurrent compactions across sessions keep markers intact, no temp files
ok 486 T18 linked worktree resolves the common git dir
ok 487 RED-GREEN: a recognized trigger still proceeds while an unrecognized one is rejected
ok 488 fixture claude/pre-compact/allow
ok 489 fixture claude/pre-compact/block
ok 490 fixture claude/pre-compact/malformed
ok 491 fixture codex/pre-compact/allow
ok 492 fixture codex/pre-compact/block
ok 493 fixture codex/pre-compact/malformed
ok 494 root: Codex prefers its valid PLUGIN_ROOT when both compatibility roots validate
ok 495 unset LOOM_ROLE fails open for test runners and git mutation
ok 496 orchestrator blocks scripts/check
ok 497 orchestrator blocks bats, cargo test, npm test, pytest
ok 498 orchestrator may run scripts/check with LOOM_ALLOW_ORCHESTRATOR_GATE=1
ok 499 orchestrator gate allowance does not unlock bats
ok 500 orchestrator allows non-test commands
ok 501 evaluators block git mutation
ok 502 code-evaluator allows read-only inspection
ok 503 arguments that mention test runners or mutations are allowed
ok 504 landing exception does not unlock other runners in compound commands
ok 505 evaluators block git mutation behind value-taking global options
ok 506 quoted command words are de-quoted; quoted arguments are ignored
ok 507 missing or empty command allows
ok 508 Claude wire: stderr reason, empty stdout, exit 2
ok 509 Codex wire: deny JSON on stdout, exit 0
ok 510 Codex wire: allow is silent exit 0
ok 511 invalid root, invalid JSON, and wrong-typed command fail closed
ok 512 quoted executable paths containing spaces are blocked at command position
ok 513 quoted executable paths with spaces are blocked after env assignments
ok 514 prepare creates a marker-owned run below the canonical temp root with schema-valid state
ok 515 RED>GREEN: prepare rejects a symlinked TMPDIR, succeeds against the real dir
ok 516 RED>GREEN: prepare rejects a nonexistent TMPDIR, succeeds against a real one
ok 517 RED>GREEN: prepare rejects run-root/owner-home overlap, succeeds when disjoint
ok 518 RED>GREEN: phase entry rejects a marker mismatch, succeeds once restored
ok 519 RED>GREEN: phase entry rejects candidate drift, succeeds once restored
ok 520 prepare rejects an unresolved --exercise before --prepare (missing run root)
ok 521 one native mutation journals the exact record sequence and preserves worker PID across exec
ok 522 hash chain is contiguous: each record's prevHash equals the previous record's hash
ok 523 full exercise -> uninstall -> clean succeeds end to end and leaves zero residue
ok 524 exercise captures list/discovery, helper-root, and role/hook probes for both clients
ok 525 RED>GREEN: claude uninstall postcondition reads installed_plugins.json, not raw cache presence
ok 526 RED>GREEN: handshake deadline is computed after the pre-inventory walk, not before it
ok 527 residue after uninstall is refused (exit 6)
ok 528 RED>GREEN: a bare empty ancestor directory left under codex-home/plugins is not residue
ok 529 an unmet postcondition with a clean exit is a product failure (exit 5), not a false success
ok 530 a mutation that writes outside its allowed roots is quarantined (exit 3)
ok 531 an infrastructure-block marker in native output classifies exit 4, not a product failure
ok 532 INT during a mutation yields exit 130
ok 533 TERM during a mutation yields exit 143
ok 534 injection before:intent: nothing is journaled, clean retry succeeds
ok 535 injection after:intent (supervisor never spawned): aborts, no cache mutation, clean retry succeeds
ok 536 injection after:supervisor-hello (supervisor dies before release): no mutation, atomic release recovery on retry
ok 537 injection after:native-hello (worker dies before native-release): no mutation, clean retry succeeds
ok 538 injection before:exec (worker dies with native-release durable, before exec): resume never relaunches, terminal records the kill
ok 539 injection supervisor-die-while-worker-continues: durable worker identity prevents a hidden orphan; reconciles to recovered-after-apply
ok 540 exhausting resume attempts under a persistent fault quarantines rather than looping forever
ok 541 an escaped, token-tagged descendant is detected and blocks --clean until it dies
ok 542 a descendant that stays inside the process group but retains the token still blocks --clean
ok 543 RED>GREEN: --clean refuses an unresolved run, succeeds once resolved
ok 544 --clean refuses a symlinked run-root argument
ok 545 --clean refuses a path outside the temp prefix
ok 546 a quarantined run is cleanable only after a fresh complete inventory proves ownership
ok 547 RED>GREEN: a quarantined run with an owned root swapped for an escaping symlink refuses --clean, succeeds once restored
ok 548 RED>GREEN: --clean fails closed on a tampered non-charset runId instead of building a stray receipt path
ok 549 injection before:native-hello (worker dies before its own hello): supervisor's worker-hello-timeout abort and the gate-2 writer-settle path fire together; no early mutation, clean retry succeeds
ok 550 injection before:supervisor-hello (supervisor dies before writing its own hello): no early mutation, exactly one clean reconciliation on retry
ok 551 injection before:native-release (supervisor dies before granting release): the orchestrator resumes and grants the missed release exactly once; the worker -- blocked until then -- proceeds only after, and a clean retry completes
ok 552 injection before:terminal (supervisor dies after full worker exit, before writing terminal): reconciles to recovered-after-apply
ok 553 injection after:terminal (supervisor dies immediately after writing terminal): applies from the durable terminal record
ok 554 injection after:supervisor-hello is operation-agnostic across marketplace-add, uninstall, marketplace-remove, and a codex opKey
ok 555 default root resolution is stable from a nested working directory
ok 556 all mode passes for the valid repository
ok 557 all mode reports a failing metadata root
ok 558 missing validation mode exits 2 with deterministic usage
ok 559 repeated validation mode exits 2 with deterministic usage
ok 560 mixed validation modes exit 2 with deterministic usage
ok 561 negative seeds are inert and cannot match production scans
ok 562 valid dual-client metadata, compatibility, bindings, and fixtures pass
ok 563 explicit non-Git root nested in a parent worktree uses the safe filesystem walk
ok 564 tracked discovery failure in a real Git root fails closed without reading an untracked canary
ok 565 README states both exact client floors and the static Codex limitation
ok 566 thin adapters pass for the real repository tree
ok 567 a command adapter missing its shared-skill pointer fails closed
ok 568 a command adapter that copies the shared workflow body fails closed on line count
ok 569 an agent adapter missing its shared-role pointer fails closed
ok 570 an agent adapter that copies the shared role body fails closed on line count
ok 571 each README client floor fails metadata validation directly when drifted
ok 572 every client-visible claim surface rejects prohibited unqualified wording
ok 573 a narrow evaluation term passes only with the immediate required qualification
ok 574 malformed JSON names the materialized file
ok 575 malformed JSON Schema names the materialized file
ok 576 missing, unterminated, and invalid YAML frontmatter fail with filenames
ok 577 unknown command frontmatter key fails closed
ok 578 unknown agent frontmatter key fails closed independently
ok 579 unknown skill frontmatter key fails closed independently
ok 580 command missing description fails independently
ok 581 agent missing name fails independently
ok 582 Claude manifest rejects a top-level unknown field
ok 583 Claude manifest rejects an unknown nested author field
ok 584 Claude catalog rejects unknown top-level owner and plugin fields independently
ok 585 Codex manifest rejects top-level and nested author unknown fields independently
ok 586 Codex catalog rejects unknown top-level owner and plugin fields independently
ok 587 compatibility matrix closes every nested object boundary
ok 588 Claude root binding rejects an unknown field
ok 589 Codex root binding rejects an unknown field
ok 590 each Claude installed-root requirement fails independently when omitted
ok 591 each Codex installed-root requirement fails independently when omitted
ok 592 installed-root constants reject false or substituted declarations independently
ok 593 catalog-shaped tracked JSON is rejected outside exact live and release-fixture paths
ok 594 null false zero and empty string receive schema diagnostics as metadata values
ok 595 null false zero and empty string receive deterministic referenced-schema diagnostics
ok 596 catalog source escape fails
ok 597 catalog symlink and different physical root fail
ok 598 catalog source resolving to a different physical plugin root fails
ok 599 duplicate catalog names fail independently
ok 600 duplicate component names fail independently
ok 601 manifest product name drift fails independently
ok 602 manifest exact SemVer drift fails independently
ok 603 manifest shared identity drift fails independently
ok 604 catalog product name drift fails independently
ok 605 catalog source identity drift fails independently
ok 606 catalog release provenance drift fails independently
ok 607 client floor drift fails independently
ok 608 profile mapping drift fails independently
ok 609 matrix schema version drift fails independently
ok 610 duplicate root binding ID fails exact pair enforcement
ok 611 swapped root binding ID and path fails exact pair enforcement
ok 612 alternate same-schema root binding path fails exact pair enforcement
ok 613 root binding identity drift fails independently
ok 614 a command adapter pointing at a deleted shared workflow skill fails closed
ok 615 an agent adapter pointing at a deleted shared role contract fails closed
ok 616 a second client-specific hook manifest fails closed
ok 617 missing client manifest reference fails independently
ok 618 missing matrix root reference fails independently
ok 619 missing referenced schema fails independently
ok 620 release fixture drift fails independently
ok 621 release fixture equality ignores object member order
ok 622 release fixture equality preserves array order
ok 623 schema-valid manifest homepage drift fails shared identity
ok 624 schema-invalid metadata path stops before outside semantic reads
ok 625 outside-root sentinels use unique cleanup-owned directories
ok 626 JSON symlink is rejected before parsing outside content
ok 627 frontmatter symlink is rejected before reading outside content
ok 628 schema symlink is rejected before reading outside content
ok 629 release fixture symlink is rejected before reading outside content
ok 630 real tree metadata passes while inert seeds remain tracked
ok 631 forced real-tree validator failure leaves the checkout intact
ok 632 valid relative targets and local and cross-file fragments pass
ok 633 rendered inline heading text and duplicate GitHub suffixes pass
ok 634 encoded spaces Unicode paths and Unicode fragments pass
ok 635 malformed percent encoding fails with source and exact target
ok 636 encoded traversal cannot escape the repository
ok 637 Markdown source symlink is rejected before reading outside content
ok 638 Markdown target symlink is rejected before reading outside content
ok 639 allowlist symlink is rejected before reading outside content
ok 640 missing targets and fragments name source and target
ok 641 only exact historical trees are excluded
ok 642 malformed duplicate and stale allowlist records fail
ok 643 live allowlist entry with empty reason is rejected and does not suppress the link
ok 644 one exact live broken link is allowlisted but code-block pseudo-link is stale
ok 645 one exact live allowlist entry passes and suppresses its broken-link diagnostic
ok 646 exact workflow and toolchain contract passes
ok 647 loom-coord exact Bash shebang is mechanically required
ok 648 git identity guard exact Bash shebang is mechanically required
ok 649 precompact backstop exact Bash shebang is mechanically required
ok 650 workflow runner row deletion fails
ok 651 workflow inline-comment spoof fails exact verified contract
ok 652 workflow commented-out security setting fails exact verified contract
ok 653 workflow duplicate key fails exact verified contract
ok 654 workflow relocated exact-head string fails exact verified contract
ok 655 workflow runner label mutation fails
ok 656 workflow host mutation fails
ok 657 workflow architecture mutation fails
ok 658 workflow release mutation fails
ok 659 workflow selected shell mutation fails
ok 660 workflow Bash regex mutation fails
ok 661 workflow checkout action pin mutation fails
ok 662 workflow exact-head checkout ref mutation fails
ok 663 workflow exact-head environment mutation fails
ok 664 workflow exact-head assertion mutation fails
ok 665 workflow exact-head log deletion fails
ok 666 workflow selected-shell physical resolver deletion fails
ok 667 toolchain runner deletion fails closed
ok 668 exact tool version mutation fails closed
ok 669 runtime floor mutation fails closed
ok 670 checkout contract pin mutation fails closed
ok 671 package-lock contract digest mutation fails closed
ok 672 unexpected toolchain top-level field fails closed
ok 673 required download deletion fails closed
ok 674 download platform mutation fails closed
ok 675 download URL mutation fails closed
ok 676 download digest mutation fails closed on an unselected platform
ok 677 required vendored asset deletion fails closed
ok 678 vendored asset path mutation fails closed
ok 679 vendored provenance omission fails closed
ok 680 vendored provenance kind mutation fails closed
ok 681 vendored digest mutation fails closed
ok 682 gate independently rejects a selected Bash below 3.2
ok 683 Git immediately below 2.34 is rejected with an actionable diagnostic
ok 684 Git exact floor 2.34 is accepted
ok 685 jq immediately below 1.6 is rejected with an actionable diagnostic
ok 686 jq exact floor 1.6 is accepted
ok 687 unknown host OS is rejected before provisioning
ok 688 supported host OS with unsupported architecture is rejected before provisioning
ok 689 first-stage failure preserves status and emits one exact diagnostic before later stages
ok 690 advanced-stage failure preserves status and stops before every later stage
ok 691 gate resolves terminal and relative multihop selected-Bash symlinks
ok 692 gate HUP cleanup is deterministic and exits 129 without success
ok 693 gate INT cleanup is deterministic and exits 130 without success
ok 694 gate TERM cleanup is deterministic and exits 143 without success
ok 695 fresh provisioning ignores a poisoned persistent extracted-tool tree
ok 696 Bats version probing cannot execute a poisoned ambient bash
ok 697 cache-root symlink is rejected without touching its owned target
ok 698 cached-download symlink is rejected without overwriting its target
ok 699 owner-controlled cache directories are repaired before use
ok 700 hard-linked cached download is rejected without mutating its outside sentinel
ok 701 unexpected cache ownership is rejected
ok 702 cache rewrite race never executes unauthenticated bytes

==> relative links
Repository links validation passed

==> Claude strict plugin validation
Validating plugin manifest: /Users/craig/git/loom/plugins/loom/.claude-plugin/plugin.json

✔ Validation passed

==> diff whitespace

All checks passed
```

Command: `node scripts/validate-repository.mjs --root "$PWD" --all` (exit 0; no test count). Exact combined output:
```text
Repository all validation passed
```
