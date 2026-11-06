# v0.2.0 live proof — preparation and operational plan

Date: 2026-11-06
Author role: researcher (reference, not authority)
Scope: the v0.2.0 live proof for Claude Code CLI and Codex CLI on macOS 14+ Apple
silicon, under ADR 0033 D3 and ADR 0032 E1–E5. This note plans the proof. It does not
decide, amend or admit anything. Decisions it raises are listed in §10 for the planner
and the owner.

Authority read for this note: ADR 0032 §1 and §3 (E1–E5, evidence record), ADR 0033
§1–§3 (narrowed v0.3.0, sequence, retired tooling), ADR 0019 §3–§5 (matrix scope,
upgrade/uninstall, release gate), spec 06 "Isolated dogfood homes and project roots",
spec 10 "Release gate", `.docs/status/handoff.md`.

---

## 1. Starting state (verified 2026-11-06)

| Item | State | Source |
|---|---|---|
| HEAD | `d1f5446`, tree clean at start | `git log` |
| Repository validation | `node scripts/validate-repository.mjs --all` passes at baseline | run during this note |
| Git tags | none exist (`git tag` is empty) | `git tag` |
| Release-evidence directory | `.docs/evaluations/release-evidence/` does not exist | `ls` |
| Dogfood harness | `scripts/macos-dual-client-dogfood` is absent (retired) | `ls scripts/` |
| Retired-tool evidence | `.docs/evaluations/macos-dual-client-dogfood-evidence.json` preserved | ADR 0033 §3 |
| Prerequisite slices (ADR 0033 §2 steps 1–2) | `herdr-surface-retirement`, `dogfood-retirement` landed 2026-11-05 | `.docs/status/handoff.md` |
| Installed Claude Code CLI | `2.1.317` | `claude --version` |
| Installed Codex CLI | `codex-cli 0.166.0` | `codex --version` |
| Pinned floors (matrix) | Claude Code `2.1.216`, Codex `0.144.6` | `adapters/compatibility/v0.2.0.json` |
| Installed `jq` / Node | `jq` at `/opt/homebrew/bin/jq`; Node `v26.7.0` | `which` |

The installed CLIs are **above** their pinned floors. E4 requires runs "at the pinned
floor" (ADR 0032 §3 E4), so the proof must run on floor-pinned binaries, not on what is
installed today (see gap G3).

---

## 2. What the blocked run proved and what it did not

Source: `.docs/evaluations/macos-dual-client-dogfood-evidence.json` (one JSON line,
`state: infrastructure-blocked`, `exit: 4`, `runId` `RQbHF6ARxqWnI2a466896`, candidate
`a0bf31604cc760631ba48b8fee574f89ef120cc8`, tree `e5728c3b…`).

**Proved (exit 0 in the record):**

- Claude marketplace add, install, reinstall (`install-2`), list inside and outside the
  project, helper-root probe, uninstall, marketplace remove.
- Codex marketplace add, install, reinstall, list inside and outside the project,
  helper-root probe, uninstall, marketplace remove.
- Hook trust for both clients (the `git-identity-guard` pre-tool-use fixture, exit 0).
- The Claude researcher cold role launch returned a bounded output
  (`roleReturn.client: claude`, `cold: true`, `delegation: false`).

**Not proved:**

- Codex role launch: `codex-role-launch` exit 1. The Codex binary got HTTP 401 from
  `api.openai.com/v1/responses` because `CODEX_HOME` held no `auth.json`. The run
  deliberately did not seed auth from the owner's real config (spec 06 forbids owner
  state as an input), so the design had no authentication path. This is the gap §3 closes.
- Roles 2–5 on either client; the full loop; the gate; any blind-review evidence.

**Interpretation for E4:** the blocked record is not E4 evidence (ADR 0033 §2). It is the
baseline for the failure mode, and its install/uninstall/hook/list hashes show the
isolation harness works, so the new run can reuse the same fixture shape
(`plugins/loom/adapters/fixtures/v0.2.0/release-install/macos-arm64.json`).

**Observed quirk:** the Claude `role-launch` step recorded success for a command that
only prints a configuration line (see G6). "Launched" in that record means
"configuration validated", not "a role ran".

---

## 3. Gaps found in the tree (must close before a candidate is frozen)

These are facts in the repository, not opinions. Each has a proposed owner. None is
fixed by this note.

**G1 — The launcher reads the v0.3.0 matrix, not v0.2.0.**
`plugins/loom/bin/loom-launch-role` resolves `adapters/compatibility/v0.3.0.json`
(line 492) and rejects any version other than `"0.3.0"` (line 498). The two matrices
differ in the Codex profile mapping:

| Profile | v0.2.0.json Codex | v0.3.0.json Codex |
|---|---|---|
| Economy | `gpt-5.6-terra` / low | `gpt-6.1-terra` / low |
| Standard | `gpt-5.6` / medium | `gpt-6.1-terra` / medium |
| Deep review | `gpt-5.6` / high | `gpt-6.1-sol` / high |

So a v0.2.0 candidate today would launch Codex with v0.3.0's models. ADR 0032 §3 E1 says
the release's own `vR.json` is the matrix that carries the pin and mapping. Options for
the planner: (a) make the launcher select the matrix by the release being tested; (b) freeze
`v0.2.0.json` as the only matrix a v0.2.0 candidate may use and make the launcher take it
explicitly. Either way the Codex model IDs must be confirmed against the pinned
`codex` 0.144.6 binary before E4; this note could not confirm them offline.

**G2 — Auto-rotation still reaches Antigravity by default.**
`_next_client_in_cycle` maps `codex → antigravity` (line 188), and
`plugins/loom/bin/loom-launch-role.bats:657` asserts the full rotation including
Antigravity. ADR 0032 §6 says default rotation "SHALL NOT route to Antigravity by default in
any v0.2.x build (code slice)". The code change is owed. Until it lands, the live run must
avoid `auto` for evaluators and use an explicit per-role routing file (§5.3).

**G3 — Installed CLIs are above the pinned floors.**
Claude `2.1.317` vs floor `2.1.216`; Codex `0.166.0` vs floor `0.144.6`. The proof needs
floor-pinned binaries installed into a run-local prefix. The exact install channel for the
floor versions (npm package names and install prefix) was **not verified** in this note;
the operator should confirm it before the run. The launcher does not appear to check the
installed client version against the floor; confirm with `loom-doctor` (to verify).

**G4 — The evidence schema cannot hold the E4/E5 record.**
`plugins/loom/schemas/loom-dogfood-evidence-v1.schema.json` is a single-run,
`platform: "darwin-arm64"` const schema with no per-pair grouping, no five-role result
table, no commit-descends-from-tag fields, and no owner acknowledgement. E4 and E5 need a
new schema. ADR 0032 §3 leaves the format to a spec 10 amendment, so that amendment is the
prerequisite (§7).

**G5 — ADR 0032 §8 finalize edits are partly owed.**
`CLAUDE.md` no longer contains the line "Private macOS dogfood is not public support or
release conformance." (checked). `README.md` "Supported Platforms & Prerequisites"
(line 71–75) still lists Ubuntu 22.04/24.04 and macOS 14+ on arm64 and x86-64, and
line 244–246 still describes the v0.2 baseline as Ubuntu plus macOS. The README must say
macOS Apple silicon only for v0.2.0 before a release is cut. The CI workflow
(`.github/workflows/check.yml`) and spec 10 also still owe the ADR 0032 §8 edits (not
re-checked in this note; verify before candidate freeze).

**G6 — The Claude "launch" is configuration only.**
For Claude, `loom-launch-role claude <role>` does not spawn a process; it prints one
`loom-role-launch/v1` line after cross-checking the agent file's native tier and tool
allowlist (see the header of the script). A real E4(a) proof for Claude therefore needs the
orchestrator to invoke the installed native agent for each role and observe a bounded return
through the harness. The launch line alone is not role-return evidence.

**G7 — The Codex role launch needs authentication, not just a model.**
Codex runs `codex exec --ephemeral --ignore-user-config --strict-config ...` with the
isolated `CODEX_HOME`. The `--ignore-user-config` help text confirms "auth still uses
`CODEX_HOME`", so an isolated `CODEX_HOME` with valid auth is sufficient. The launcher reads
ambient model config from `$HOME/.codex/config.toml` (not `CODEX_HOME`), so the run must set
`HOME` to the isolated system home as well, or an owner config could leak a model
selection in.

---

## 4. Auth setup strategy for isolated homes

### 4.1 Rules (non-negotiable for this proof)

1. **No owner state as an input.** Spec 06 says owner configuration and cache "is never an
   input". Do not copy `~/.codex/auth.json`, `~/.claude/` or any Keychain item into a run root.
2. **Isolation is per run.** Every run uses a fresh `RUN_ROOT` (fixture variables
   `$RUN_ROOT/claude-home`, `$RUN_ROOT/codex-home`, `$RUN_ROOT/system-home`,
   `$RUN_ROOT/tmp`, `$RUN_ROOT/project`). The run root is deleted after evidence is
   sealed, and the auth files inside it are deleted with it.
3. **No secrets in evidence.** Record the *auth source type* and a boolean probe result,
   never a token, key, `auth.json` content, or a hash of a secret.
4. **Owner-visible state is checked before and after.** Snapshot the owner's
   `claude auth status` and `codex login status` (both read-only) and the owner's
   `~/.claude` / `~/.codex` inventory hashes before the run and after it; the run is
   invalid if they change.

### 4.2 Probe results (today, read-only, throwaway homes)

- `env HOME=<tmp>/system-home CLAUDE_CONFIG_DIR=<tmp>/claude-home claude auth status` →
  `loggedIn: false`, `authMethod: none`. The isolated Claude home is not logged in, as expected.
- `env HOME=<tmp>/system-home CODEX_HOME=<tmp>/codex-home codex login status` → "Not logged
  in". The isolated Codex home is not logged in, as expected.

Both probes confirm the isolation is effective and that authentication must be provisioned
into each home deliberately. Both temporary directories were removed.

### 4.3 Codex options

| Option | Mechanism (to verify at 0.144.6) | Recommendation |
|---|---|---|
| C1. Owner logs in inside the isolated home | `env HOME=$SYS CODEX_HOME=$RUN/codex-home codex login` (device or browser flow), then `codex login status` | **Recommended.** `auth.json` lands only in the disposable root. |
| C2. API key piped into the isolated home | `printenv OPENAI_API_KEY \| env HOME=$SYS CODEX_HOME=$RUN/codex-home codex login --with-api-key` | Acceptable fallback. Bills per API usage. Key comes from the owner's environment at run time only. |
| Rejected: copy owner `auth.json` | — | Violates rule 1. |

Install-time `codex login --help` confirms the `--with-api-key` and `--with-access-token`
flags on this build. Whether the CLI at 0.144.6 accepts the same flags is **not verified**.

### 4.4 Claude options

| Option | Mechanism (to verify at 2.1.216) | Recommendation |
|---|---|---|
| L1. Owner logs in inside the isolated home | `env HOME=$SYS CLAUDE_CONFIG_DIR=$RUN/claude-home claude auth login --claudeai` | **Recommended, after the collision check below.** |
| L2. Long-lived token from `setup-token` | `claude setup-token` run in the isolated env; token passed to runs as an environment variable only, never written to disk | Fallback if L1 proves unsafe. Confirm the env var name at 2.1.216. |
| L3. API key via Console | `claude auth login --console` (API billing) | Fallback. Bills per API usage. |

**Collision check for L1 (must pass before first use).** On macOS, Claude Code keeps
OAuth credentials in the Keychain. **Unverified:** whether the Keychain item is scoped by
`CLAUDE_CONFIG_DIR`. If it is not, an isolated login could overwrite the owner's session.
Procedure: record the owner's `claude auth status` → run `claude auth login` in the isolated
env → re-check the owner's `claude auth status`. If the owner's status changed, stop and use
L2. Record the outcome in the run journal.

### 4.5 What the evidence records about auth

Per client: `authSource` (`owner-login-isolated`, `setup-token-env`, or `api-key-env`), the
probe exit code (`claude auth status` / `codex login status`), and the owner-state
before/after inventory match (boolean). No value of any credential.

---

## 5. Role launch validation matrix (5 roles × 2 clients)

### 5.1 Expected resolution (after G1 is closed; numbers are per the chosen matrix)

| Role | Profile | Claude selector | Codex model / effort (v0.2.0.json) | Codex model / effort (v0.3.0.json) |
|---|---|---|---|---|
| researcher | Economy | `haiku` | `gpt-5.6-terra` / low | `gpt-6.1-terra` / low |
| planner | Deep review | `opus` | `gpt-5.6` / high | `gpt-6.1-sol` / high |
| plan-evaluator | Deep review | `opus` | `gpt-5.6` / high | `gpt-6.1-sol` / high |
| developer | Standard | `sonnet` | `gpt-5.6` / medium | `gpt-6.1-terra` / medium |
| code-evaluator | Deep review | `opus` | `gpt-5.6` / high | `gpt-6.1-sol` / high |

The right-hand Codex columns are shown only so the G1 difference is visible; the
v0.2.0 candidate uses one column, chosen under G1.

### 5.2 Cell checks (each cell = one client × one role)

For each of the 10 cells:

1. **Descriptor.** `loom-launch-role <client> <role>` exits 0; its one stdout line validates
   against `plugins/loom/schemas/loom-role-launch-v1.schema.json`; `profile`, model/selector
   and effort match §5.1; `cold: true`, `delegation: false`.
2. **Real return (E4(a)).**
   - Claude: the orchestrator invokes the installed native agent for the role and receives a
     bounded return through the harness. The launch line is not sufficient (G6).
   - Codex: the launcher's `codex exec` path runs the `$loom-<role>` skill (read-only
     sandbox, web search off, delegation disabled, closed output schema) and returns a
     schema-valid bounded output. Record the output hash.
3. **Delegation refused.** Re-run with `LOOM_LAUNCH_ROLE_ACTIVE=1` in the environment: must
   exit 2 (descendant rejected).
4. **Vendor override refused.** Re-run with one vendor override variable set (e.g.
   `CODEX_MODEL`): must exit 2.
5. **Cross-family (evaluators only).** `plan-evaluator` and `code-evaluator` run with
   `--author-client` set to the other client; same-client must exit 2.

### 5.3 Routing for the run (works around G2)

Use an explicit routing file (`loom-role-routing/v1`, absolute path) with a concrete client
for every role. Do not use `auto` for evaluators while G2 is open. Proposed Pass A (both
authors and evaluators exercised on each client, cross-family enforced):

| Role | Client (Pass A) | Cross-family constraint |
|---|---|---|
| researcher | claude | none (not an evaluator) |
| planner | claude | none (not an evaluator) |
| plan-evaluator | codex | must differ from planner (claude) |
| developer | codex | none (not an evaluator) |
| code-evaluator | claude | must differ from developer (codex) |

Pass B (optional hardening, recommended if budget allows) swaps the clients for planner,
developer and both evaluators, so each client is exercised as author and as evaluator.

---

## 6. Full loop execution pass

Full loop: research → plan → plan-eval → develop → code-eval → land (ADR 0032 E4(b)).

### 6.1 Target and remote (safety)

- Project root: `$RUN/project`, a fresh `git init` repository created for the run, with a
  Loom greenfield or unaligned init as the spec 06 classifier decides.
- Remote: a **local bare repository** `$RUN/remote.git` added as `origin`. The run must never
  push to `github.com/craigeous/loom` or to any remote other than `$RUN/remote.git`. Confirm
  `git -C $RUN/project remote -v` before the first handoff.
- Landing: `loom-land` in remote-direct mode against the local bare remote (ADR 0020). The
  receipt must verify. `Landed` means remote verification plus receipt (CLAUDE.md invariant).

### 6.2 Steps and evidence per step

| Step | Role/owner | Pass criterion | Evidence |
|---|---|---|---|
| 1. Init | root orchestrator | classifier resolves to the expected mode; init commits | commit hash |
| 2. Research | researcher (claude) | research note committed under `.docs/research/`; `Research Review` status | commit hash, note hash |
| 3. Plan | planner (claude) | ADR/spec/slice-plan committed; status reaches Plan Review | commit hash |
| 4. Plan eval | plan-evaluator (codex) | verdict file `.docs/evaluations/<artifact>-eval.md` committed; PASS | verdict hash, cross-family flag |
| 5. Develop | developer (codex) | slice committed; gate run recorded; status Implemented | commit hash, gate log |
| 6. Code eval | code-evaluator (claude) | verdict committed; PASS; gate rerun recorded | verdict hash, rerun log |
| 7. Land | root orchestrator via `loom-land` | remote-direct publish; receipt verifies | receipt, remote ref |

Each handoff must be its own commit (CLAUDE.md, "every handoff commits").

### 6.3 Blind review checks (ADR 0022)

- The evaluator's input is the commit diff and the slice plan only. Confirm the evaluator
  prompt or launch record has no author identity and no author reasoning.
- The cross-family flag in the descriptor (`crossFamilyVerified: true`) must match the
  routing in §5.3.
- A same-client evaluator run is a FAIL of the proof, not a warning.

### 6.4 Gate

- Disposable project: its own format → lint → test gate, learned and recorded under the
  unknown-stack path (gate-learning) or a trivial shell gate; the run records the commands
  and results.
- The loom repository itself: `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check` on the
  candidate commit (CLAUDE.md shell gate). E4(c) requires the gate to pass on this platform.

---

## 7. Platform gate and install / upgrade / uninstall validation

### 7.1 Platform and toolchain

- macOS 14+ on arm64 (`uname -m` = `arm64`; `sw_vers -productVersion` ≥ 14).
- `/bin/bash --version` (3.2 expected) as the Bash floor test; Git ≥ 2.34; jq ≥ 1.6.
- Record `claude --version`, `codex --version` (floor-pinned), and the tool versions in the
  evidence record.

### 7.2 Install sequence (fixture `macos-arm64.json`, pluginVersion `0.2.0`)

Per client, in the isolated environment from the fixture (`HOME`, `CLAUDE_CONFIG_DIR` or
`CODEX_HOME`, `TMPDIR` all under `$RUN_ROOT`):

1. `marketplace-add` (`$REPO_ROOT` = the clean clone at the candidate commit)
2. `install` (`loom@loom`)
3. `list` (JSON for Claude; plain for Codex) — both inside and outside the project resolve
   the same project root
4. `helper-root` probe
5. hook trust (`git-identity-guard` pre-tool-use fixture, exit 0)
6. `install-2` (reinstall over itself)
7. `uninstall`, then `marketplace-remove`
8. post-inventory equals pre-inventory, except documented client caches

### 7.3 Upgrade

No git tag exists, so there is no previously released version to upgrade from. Proposed
definition (planner to confirm): upgrade = install the superseded blocked candidate
`a0bf316…` first, then install the final candidate over it, then uninstall; the inventory
check applies. This is an open question (§10, Q4).

### 7.4 Clean-clone and release gate (ADR 0019 §5)

From a clean clone at the tag: full local check; manifests, catalogs, helpers, schemas,
docs and release metadata agree; tag resolves to the tested commit; artifacts are not edited
after testing.

---

## 8. Evidence schema and destination

### 8.1 Destination (ADR 0032 §3)

- **Final record:** `.docs/evaluations/release-evidence/v0.2.0.json`. It is written after the
  candidate commit is chosen and tagged `v0.2.0`, in a commit that descends from the tag.
  The candidate commit never contains its own hash or its post-test acknowledgement.
- **Run journals and logs:** a sanitized journal per run under
  `.docs/evaluations/release-evidence/v0.2.0/` (or an external store with hashes; planner to
  decide, §10 Q5). Sanitization: replace `$HOME` and `$RUN_ROOT` with placeholders, strip any
  auth file content, never capture the environment.
- The record is append-only after publication; corrections are new files.

### 8.2 Draft shape (illustrative; the spec 10 amendment fixes the real schema)

```json
{
  "schema": "loom-release-evidence/v1",
  "release": "0.2.0",
  "tag": "v0.2.0",
  "candidate": "<full 40-hex commit; equals git rev-parse v0.2.0^{commit}>",
  "platform": { "os": "macOS 14+", "arch": "arm64" },
  "matrix": "adapters/compatibility/v0.2.0.json",
  "pairs": [
    {
      "harness": "claude-code-cli",
      "floor": "2.1.216",
      "e1": "matrix entry at candidate",
      "e2": "root binding claude-plugin-root/v1",
      "e3": "bats run id, result",
      "e4": {
        "a_roles": {
          "researcher": { "result": "pass", "log": "...", "outputHash": "..." },
          "planner": { "result": "pass", "log": "...", "outputHash": "..." },
          "plan-evaluator": { "result": "pass", "log": "...", "outputHash": "..." },
          "developer": { "result": "pass", "log": "...", "outputHash": "..." },
          "code-evaluator": { "result": "pass", "log": "...", "outputHash": "..." }
        },
        "b_loop": { "runId": "...", "result": "pass", "blindReview": "verified", "log": "..." },
        "c_gate": { "command": "scripts/check", "result": "pass", "log": "..." }
      },
      "authSource": "owner-login-isolated",
      "ownerStateUnchanged": true
    },
    { "harness": "codex-cli", "floor": "0.144.6", "...": "same shape" }
  ],
  "installUpgradeUninstall": { "result": "pass", "log": "..." },
  "ownerAck": {
    "by": "owner",
    "pairs": ["claude-code-cli", "codex-cli"],
    "evidenceSet": "sha256 of the journal set",
    "candidate": "<same 40-hex>",
    "date": "YYYY-MM-DD"
  }
}
```

Field names and the schema id are placeholders. Do not treat this shape as normative; it is
a starting point for the spec 10 amendment.

### 8.3 Checks that verify the record

```sh
git merge-base --is-ancestor v0.2.0 <record-commit>
test "$(jq -r .candidate .docs/evaluations/release-evidence/v0.2.0.json)" = "$(git rev-parse v0.2.0^{commit})"
```

---

## 9. Execution sequence

Owner actions are marked **[owner]**. Everything else is agent work.

1. Close G1 (matrix resolution) and G2 (rotation) through planned slices. Land them.
2. Close G5 (README and any remaining ADR 0032 §8 edits) and the spec 10 amendment (G4 schema).
3. **[owner]** Decide the auth options (§4.3, §4.4) and confirm billing consequences.
4. Install floor-pinned `claude` 2.1.216 and `codex` 0.144.6 into a run-local prefix (G3);
   record versions.
5. Run the auth probes and the L1 collision check (§4.4); record outcome.
6. **[owner]** Perform the isolated logins (C1 and L1, or the chosen fallback).
7. Freeze the candidate commit (clean tree, `scripts/check` green on this commit).
8. Run the 5×2 launch matrix (§5); run install/upgrade/uninstall (§7).
9. Run the full loop, Pass A, then Pass B if budgeted (§5.3, §6).
10. Run the platform gate on the candidate (§6.4, §7.1).
11. Tag `v0.2.0` on the candidate.
12. Write the record commit `.docs/evaluations/release-evidence/v0.2.0.json` (§8).
13. **[owner]** E5 owner acknowledgement, named in the record.
14. Verify the record (§8.3); then publish.

Do not change the candidate after step 7. Any change needs a new candidate and new runs.

---

## 10. Open questions for the planner and owner

- **Q1 (planner).** G1: launcher matrix selection. Option (a) select by release, or (b) freeze
  v0.2.0.json. Which one, and which Codex model IDs are correct at 0.144.6?
- **Q2 (planner).** G2: schedule the Antigravity default-rotation code slice before or after
  the proof. Until it lands, §5.3 avoids `auto`.
- **Q3 (owner).** Auth: C1 or C2 for Codex; L1, L2 or L3 for Claude. The choice decides
  billing (API usage or subscription).
- **Q4 (planner).** Definition of "upgrade" when no prior release exists (§7.3).
- **Q5 (planner).** Home and format for run journals and logs; whether they are committed
  (sanitized) or stored externally with hashes.
- **Q6 (planner).** The E4/E5 record schema id and fields (spec 10 amendment, G4).
- **Q7 (owner).** Whether ADR 0024 journals can feed any E4 cell. Default per ADR 0032 open
  question 1 is no; nothing in this note changes that.

---

## 11. Limits of this note

- No live login, role launch, or install was run. The only live actions were read-only
  auth-status probes in temporary homes, which were removed.
- Floor-version install channels, the Codex model IDs at 0.144.6, the Claude keychain
  scoping behavior, and the `setup-token` env var name are **unverified** and are listed as
  checks, not facts.
- Validation: `node scripts/validate-repository.mjs --all` exits 0 on this note. It ran
  snapshot checks only; status transitions were not verified (the validator asks for
  `--baseline <ref>` for that).

## Sources

- `.docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md` (§1, §3, §6, §8)
- `.docs/ADR/0033-narrow-v0.3-scope-and-retire-macos-checkpoint-tooling.md` (§1–§3)
- `.docs/ADR/0019-supported-runtime-and-release-contract.md` (as kept by 0032 §4)
- `.docs/spec/06-init-modes.md` ("Isolated dogfood homes and project roots")
- `.docs/spec/10-packaging.md` ("Release gate")
- `.docs/evaluations/macos-dual-client-dogfood-evidence.json` (blocked record)
- `plugins/loom/bin/loom-launch-role` (lines 11, 185–189, 492–498; script header)
- `plugins/loom/bin/loom-launch-role.bats` (line 657)
- `plugins/loom/adapters/compatibility/v0.2.0.json`, `v0.3.0.json`
- `plugins/loom/adapters/fixtures/v0.2.0/release-install/macos-arm64.json`
- `plugins/loom/schemas/loom-dogfood-evidence-v1.schema.json`
- `.docs/status/handoff.md`
- Local CLI probes (2026-11-06): `claude --version`, `codex --version`,
  `claude auth login --help`, `claude setup-token --help`, `codex login --help`,
  `codex exec --help`, and throwaway-home `auth status` probes.
