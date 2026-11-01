# 0031 — Herdr as an hc-Driven Client

Status: Plan Review
Supersedes (in part): ADR 0029, ADR 0030
Extends: ADR 0018, ADR 0027
Date: 2026-11-01

## Context

ADR [0029](0029-herdr-client-adapter-and-native-app-support.md) and ADR
[0030](0030-herdr-native-app-hooks.md) treated Herdr as a **plugin host**: a
`.herdr-plugin/` manifest and marketplace, a `HERDR_PLUGIN_ROOT` installed-root
binding, and Herdr-installed hooks with an exit-2 wire. Milestone M9 is in progress
(`roadmap.md`): its three slices landed on offline fixtures only, and `progress.md`
keeps live Herdr and native-app evidence as outstanding owner-run work.

Two research notes show that framing has no support in the installed product:

- [Extension loading](../research/2026-11-01-herdr-extension-loading.md): the app's
  extension unit is a "mod" (`~/.config/herdr-app/mods/<name>/main.js`). The search of
  the app, the CLI and the bundle found no evidence of a hook, plugin-install or
  marketplace API (absence of evidence, not proof of absence). A
  `gpui-shell.json` manifest validator exists in the binary, but no loader or install
  path was found (unverified). The `.herdr-plugin/` format loom shipped is not
  evidenced anywhere in the product. The `exit 2` hook wire in ADR 0030 §4 is a
  "provisional default", not an observed contract.
- [hc runtime reference](../research/2026-11-01-hc-agent-runtime-reference.md): `hc`
  (herdr-core 0.1.16) launches, messages, waits on and reads agent programs in
  persistent terminals. The desktop app (herdr-app 0.1.11) displays `hc`-run terminals. It
  can also start programs itself (`herdr-app --skill` documents `tab.new` and
  `terminal.open`; the note observed an app-started terminal). Loom launching only
  through `hc` is an owner-selected integration constraint, not a claim about what
  the app can do.

**Owner decision (binding).** Herdr is its own client, the way Orca is a client
within loom. Loom is made Herdr-aware. The plugin framing is dropped: loom ships no
Herdr plugin, marketplace or `.herdr-plugin` manifest as its integration. Herdr is
driven through `hc`. Loom's hooks stay inside Claude Code and are not
installed through Herdr. This ADR adds, changes or removes no Codex hook wiring.

**Versions.** `hc` 0.1.16 and herdr-app 0.1.11. The owner's earlier brief, ADR 0029,
ADR 0030 and `clientFloors.herdr` said 0.1.10; the installed app is 0.1.11
(`Info.plist`, `herdr-app --version`). Neither project publishes a compatibility
statement.

**Scope.** In: the Herdr client model, what survives or is superseded from 0029/0030,
disposition of existing Herdr files, the blind-review constraint, Orca/`hc` parity.
Out: the launcher code, schemas and matrix edits (a later slice after acceptance),
live-app evidence (owner-run), mods or any Herdr-side UI.

## Decision

### 1. Herdr is a launch host driven by `hc`

Herdr is a **host client**: it runs cold role sessions in persistent terminals through
`hc`. The role's *agent* is still `claude` or `codex`; Herdr contributes the terminal,
worktree placement, readiness and wait, not a model, a plugin root or a hook runtime.
Consequently:

- Claude Code and Codex keep their own installed roots (`claude-plugin-root/v1`,
  `codex-skill-source/v1`). Hooks stay inside Claude Code. A role launched under `hc`
  resolves helpers exactly as it does elsewhere. There is no Herdr root.
- Loom drives only the `hc` CLI. It does not call `herdr-app do`, write
  `~/.config/herdr-app` or `~/.config/herdr-core`, or ship a mod. Read-only
  observation from a user-owned mod is allowed and out of scope.
- The `hc` path is **opt-in** and, per §6, **gated per role and per client** on named
  live probes. Until a gate passes, the existing launch path is the supported path.

### 2. What survives from ADR 0029 and ADR 0030

| Decision | Disposition |
|---|---|
| 0029 §1 authorize Herdr as a client | **Survives, reframed**: a host client driven by `hc`, not a plugin adapter. |
| 0029 §2 `.herdr-plugin/plugin.json` and marketplace | **Superseded.** |
| 0029 §3 `herdr-plugin-root/v1`, `HERDR_PLUGIN_ROOT` | **Superseded.** |
| 0029 §4 `clientFloors.herdr` `0.1.10`, Herdr root binding, Herdr profile entries | **Superseded**: replaced by an `hc` floor of `0.1.16` and an observed (not floored) app version `0.1.11`. |
| 0029 §5 `loom-resolve-helper herdr`; `loom-launch-role herdr` descriptor-only with ambient model | **Superseded**: see §3. The launch invariants (`delegation: false`, permissions `one-level`, `LOOM_ROLE=<role>`, cold) **survive** and apply to the `hc` path. |
| 0029 Consequences: thin adapters, portable core, non-delegation, cross-family evaluation, uniform identity | **Survive unchanged.** |
| 0030 §1 manifest `hooks` field | **Superseded.** |
| 0030 §2 `HERDR_PLUGIN_ROOT` in the hook dispatcher path | **Superseded**; this ADR makes no other change to the dispatcher path. |
| 0030 §3 `herdr` hook client selection and three-way mutual exclusion | **Superseded**: the `herdr` selection branch is removed; this ADR makes no other change to hook client selection. |
| 0030 §4 Herdr `exit 2` wire | **Superseded** (provisional, never observed). |
| 0030 §5 fixtures as offline, deterministic verification; live evidence is owner-run | **Survives as a principle**: the `hc` path is verified offline with a stub `hc` plus owner-run live probes; offline fixtures alone never establish support (see §7). |
| The fail-closed rule for ambiguous or invalid client state | **Survives.** |

0029 and 0030 are not edited. Their `Status:` stays `Accepted`; this ADR is the
superseding record, and the ADR register notes it.

### 3. Launcher model

`loom-launch-role` keeps emitting the **inner-client** descriptor (`claude` or
`codex`, with matrix-driven model and effort). The `herdr` value of its client enum is
removed. A new host adapter (name and schema fixed by the amended specs and a slice
plan) turns a descriptor plus worktree plus brief into `hc` invocations. The host is
orthogonal to the client: a descriptor may be consumed by Orca, by `hc`, or by direct
execution.

Model and effort: for the `hc` host they go **inside the program's command string**
(`hc` has no model or effort field; templates likewise). This relaxes the "Herdr
inherits the ambient model" statement of 0029 and is consistent with ADR 0027: Claude
uses the matrix selector, Codex uses matrix model and effort, or ambient inheritance
where 0027 already permits it.

### 4. Orca / `hc` parity

Loom's specs do not define an Orca launcher; Orca is an operator-side host (worktree,
terminal create/send/wait/read/close). Parity is therefore stated at the behavior
level, and an Orca-specific mapping is **not** specified here.

| Loom launch input | `hc` command | Orca counterpart |
|---|---|---|
| role | `--name <role>-<opaque id>` (1–32 chars of `a-z 0-9 - _`, unique among live terminals) | terminal/worktree title (operator choice) |
| inner client | program `claude` or `codex --no-daemon` (§6 gates) | same program |
| model, effort | inside the command string (§3) | same string, or ambient |
| worktree | `--cwd <worktree>` | terminal created in the worktree |
| `LOOM_ROLE` | `env LOOM_ROLE=<role> <program> …` as argv (`hc run` has no env flag) | env or shell prefix |
| brief | `hc run … <program> "<brief>"` (brief as its own argv token; delivery untracked), or `hc wait` then `hc send` | send to terminal |
| readiness | `hc wait` (needs the program to report status, else it waits for exit or timeout) | wait on terminal |
| completion | `hc wait` returns, then root reads the **committed artifact**; then `hc kill`, `hc rm` | read terminal, then close |
| parent/lifetime | `--no-parent` for roles that must outlive the root's terminal; otherwise default parent | n/a |
| cross-family evaluator | `--author-client` unchanged; the evaluator's inner client differs from the author's | same |

**Unchanged across Orca and `hc`:** a fresh cold session per role (never `--resume` or
`--continue`); only root delegates; the role is launched with no delegation capability;
`LOOM_ROLE` set; roles exchange work only through committed `.docs/` artifacts and
git, never through terminal messages or screens; the role's bounded return; commit
per handoff under one uniform identity; evaluators blind per §5; root ends the role
explicitly after its return.

**Different on `hc`, and why:** interactive agents do not exit at turn end, so root
must `hc kill` then `hc rm`; children end with their parent unless `--outlive-parent`
or `--no-parent`; readiness and completion depend on the program reporting OSC 7501
status, which is a *hint to look*, never a dispatcher. **The artifact `Status:`
remains the dispatcher** (spec 03). `hc wait` always carries a timeout; a timeout is
reported as degraded, never as completion.

"Only root delegates" is not enforced by `hc` (any process with Bash may call
`hc run`). The enforcement stays in Claude Code: the role-governance PreToolUse guard
gains a **deny-by-default `hc` policy**: when `LOOM_ROLE` is a non-orchestrator role,
every `hc` invocation is refused. There is no allowlist for role sessions; the
orchestrator is the only caller of `hc`. This covers every verb in the research note's
table (`run`, `exec`, `send`, `keys`, `interrupt`, `attach`, `kill`, `rm`, `label`,
`keep`, `put`, `file write|edit`, `machine …`, `server …`, `update`, `connect`, and the
read verbs), and any verb added by a later `hc` version. Like the git guard this is
defense in depth, evadable (for example through a shell wrapper or the core socket),
and not a boundary.

### 5. Blind-review constraint (hard requirement)

`hc` sender tags (`<hc from="t7 name">…</hc>`), terminal names, labels, parents, cwd,
`foreground.argv` (session ids and flags) and screens can reveal authorship. `notes =
false` (or `--no-notify` per launch) removes only hc-typed notes and tags. It hides
nothing else, and the project states there is no per-client permission check on the
core socket.

**Required for any evaluator (`plan-evaluator`, `code-evaluator`) launched through
`hc`:**

1. **No `hc`-delivered content.** Evaluators are launched with `--no-notify`, and with
   `notes = false` where a config exists. Root never `hc send`s an evaluator anything
   derived from the author. The brief names only artifact paths and commits.
2. **Opaque identity.** Name is `eval-<coldId>`; no labels; `--no-parent`; `--cwd` is
   the sanitized evaluator workspace of ADR 0022 (`loom-eval-workspace`), never the
   author's worktree.
3. **No author terminal in the core.** Before an evaluator starts, every author-role
   terminal for the artifact is `kill`ed **and** `rm`ed, so `hc ls --all` shows none.
4. **No `hc` in the evaluator's hands.** The evaluator's tool policy and the
   role-governance guard deny every `hc` verb (§4 deny-by-default, read verbs included:
   `ls`, `get`, `read`, `events`, `attach --observe`) for evaluator roles.

Items 1–4 are necessary and **not sufficient**: item 4 is evadable from Bash, and an
evaluator with a shell under the owner's account can still reach the core socket.
Therefore **this is an open requirement that blocks the `hc` path for evaluator
roles.** The owner must choose, in a follow-up ADR, one of: (a) OS-account or socket
isolation so the evaluator cannot reach the author's core (strong, heavy); or (b)
explicit acceptance of "blind by convention" for `hc` evaluators, recorded as a
degraded-blindness mode in progress notes. Until then, evaluators run on a host that
already satisfies ADR 0022 (Orca or direct); `hc` hosts only researcher, planner and
developer, and the research note's open question 8 (can an evaluator `hc read` another
terminal?) is a pre-condition probe for either option.

### 6. Gates before any role runs on `hc`

Each is a named live probe from the hc reference §10 and is owner-run; the `hc` path
for a given role/client pair stays unsupported until its probes pass and are recorded.

- **Claude roles:** does a positional prompt work and `first_message` stay unset
  (Q3); how an interactive session loads the `agents/<role>.md` definition and
  excludes the `Agent` tool, so non-delegation holds under `hc` (Q4); whether
  `HC_TERMINAL_ID` reaches the Bash tool (Q5); whether the session reports OSC 7501
  at launch (Q1).
- **Codex roles:** loom's current Codex launch is one-shot `codex exec … --sandbox
  read-only`. It does not fit an interactive `hc` terminal and cannot write. The Codex
  `hc` path needs its own contract and Q2 passing; **until then Codex roles are not
  supported on `hc`.**
- **Lifetime:** parent-end behavior and `--outlive-parent` (Q6).

### 7. Disposition of existing Herdr files

**Recommendation: retire all of them; do not rename.** Reasons: the manifests assert a
plugin format no Herdr build is shown to load, so keeping them advertises support
that does not exist; renaming does not help because the concept they encode (an
installed Herdr plugin root) has no counterpart under `hc`, where Claude and Codex
bring their own roots; and a second root candidate in the hooks forces the three-way
mutual-exclusion logic and 24 fixtures to defend a path that is never exercised.

| File / entry | Action (later code slice; nothing is deleted in this step) |
|---|---|
| `.herdr-plugin/marketplace.json` | Retire (delete). |
| `plugins/loom/.herdr-plugin/plugin.json` | Retire (delete). |
| `plugins/loom/adapters/roots/herdr-plugin-root-v1.json` and the `herdr-plugin-root/v1` branch of `loom-installed-root-binding-v1.schema.json` | Retire. |
| `herdr` entries in `v0.3.0.json` (`clientFloors.herdr`, root binding, per-profile `herdr` keys) | Retire. The matrix is release-owned: if `v0.3.0` is released, the change lands in the next matrix version with an `hc` floor of `0.1.16`; otherwise in place. The code slice decides from release state. |
| `herdr` hook fixtures (24 files) and the `HERDR_PLUGIN_ROOT` branches in the three hook scripts and `hooks.json` | Retire; `hook-wire-v1` becomes 2 clients × 2 events × 3 outcomes = 12 cases / 48 files. |
| `herdr` branches in `loom-resolve-helper`, `loom-launch-role` (client enum, schema), `validate-repository.mjs` | Retire; replaced by the host adapter (§3). |
| `scripts/tests/herdr-verification.bats` | Retire or rewrite against a stub `hc` (code slice decides). |
| `.docs/research/…herdr-client-adapter-contract.md`, `…native-app-hooks-contract.md`, archived 0029/0030 slice plans and evaluations | Keep as history; they are superseded, not deleted. |

### 8. Milestone M9

M9 status is **"reopened: plugin framing superseded; hc-driven client pending."** The
three landed slices are fixture-only against an unverified plugin format and do not
establish Herdr support. This ADR records the change; the orchestrator updates
`roadmap.md`, `progress.md` and `handoff.md`. New M9 work: spec amendments (this
cycle), then slices for (1) retirement, (2) the `hc` host adapter and amended
launcher, (3) role-governance `hc` deny, (4) stub-`hc` offline verification. Live
probes (§6) are owner-run and tracked separately; none counts as support until
recorded.

## Consequences

- Herdr support is real only for roles whose probes pass; today none do. The honest
  status is "designed, unverified."
- Loom stops claiming a plugin install path for Herdr, removing a false-support surface
  and a three-way root-selection complexity from the hooks.
- Blind evaluation stays on its current host until the owner resolves §5; the `hc`
  path cannot weaken ADR 0022 by default.
- Loom's hooks live only in Claude Code. Herdr is shown no hook surface, so anything
  depending on interception stays there.
- **Open blocker:** blind review through `hc` is unresolved (§5). Items 1–4 are
  necessary, not sufficient (`hc <hc from=…>` tags, names, cwd and argv can reveal
  authorship). No evaluator role runs on `hc` until a follow-up ADR records the
  owner's choice of isolation or explicit degraded blindness.
- Follow-on: owner decision on §5; amended specs 07, 08, 10 (drafted in
  `.docs/slice-plans/herdr-hc-spec-amendments.md`); `CLAUDE.md` Map line on the
  hook fixture product ("18-case (3 clients …; 72 fixture files)") and the
  `herdr-plugin-root` references updated by the developer's finalize pass.
- Forecloses: any Herdr-native install or hook support until the app publishes a
  documented, verified surface; that would need a new ADR.
