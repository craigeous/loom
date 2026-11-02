# 0032 — Release Client Mapping and Retirement of the Dogfood Support Tier

Status: Plan Review
Date: 2026-11-01

## Context

Loom has accumulated clients under three different labels. ADR 0019 defines the v0.2
public release as Claude Code + Codex CLI on Ubuntu 22.04/24.04 x86-64 and macOS 14+
(Apple silicon and Intel), blocked until its matrix is green. ADR 0024 authorized a
"private dogfood" checkpoint on Apple silicon only, and ADR 0027 §4 gave Antigravity the
same "private dogfood and development runtime adapter" status. `CLAUDE.md` encodes this
as the invariant "Private macOS dogfood is not public support or release conformance."
ADR 0031 made Herdr a launch host driven by `hc` and left the Orca mapping unspecified
(§4); spec 07 "Host surfaces (Orca, Herdr `hc`)" names Orca, but no Orca host adapter
exists.

State verified in the tree while drafting:

- `plugins/loom/adapters/compatibility/v0.2.0.json` covers `claude` and `codex` with
  two root bindings. `v0.3.0.json` adds a `herdr` floor, a `herdr-plugin-root/v1`
  binding and `herdr` profile entries; ADR 0031 §7 retires the plugin-root framing, so
  that matrix entry is stale.
- `plugins/loom/bin/loom-launch-role` accepts `antigravity` in its client enum and
  contains launch code (`_launch_antigravity`, `agy models` discovery). No
  Antigravity matrix entry, root binding or manifest exists in `adapters/`.
- No file under `plugins/loom/adapters/` names Orca.

**Owner decision (binding).**

1. v0.2.0 is Claude Code CLI and Codex CLI. v0.3.0 is Antigravity, Orca and Herdr (`hc`).
2. "Dogfood" is retired as a support tier. A client is supported in a release with
   conformance evidence, or it is not in that release. There is no private middle tier
   for a client a release claims. ADR 0024's macOS evidence stays a historical record,
   not a support claim.

In scope: the mapping, the definition of "supported", the disposition of Antigravity and
Orca, and what earlier ADRs this supersedes. Out of scope: spec text, `CLAUDE.md`,
matrix or code changes, and the Herdr work already decided by ADR 0031.

## Decision

### 1. Release mapping

| Release | Supported clients | Basis |
|---|---|---|
| v0.2.0 | Claude Code CLI, Codex CLI | ADR 0019, unchanged |
| v0.3.0 | Antigravity, Orca, Herdr (`hc`) | this ADR |

v0.3.0 is additive: it also carries the v0.2.0 clients, which must keep passing their
own evidence. A client appearing in no row is unsupported in every release, whatever
code exists for it. The release at which a client is first supported is fixed by this
table; moving a client needs a superseding ADR.

### 2. Retirement of the dogfood tier

"Dogfood", "private dogfood" and "development runtime adapter" cease to be support
statuses. For a release, a client is *supported* (§3 evidence complete) or *absent*.
Pre-release evidence gathered on one platform remains valid input to §3 but confers
no status. Code for a client outside the current release's row may exist in the tree
but SHALL NOT be documented, matrixed or described as supported, and SHALL NOT be
reachable by default routing (see §6, Antigravity).

Replacement for the `CLAUDE.md` invariant "Private macOS dogfood is not public support
or release conformance": **"A client is supported only in a release whose compatibility
matrix lists it with complete conformance evidence; there is no private or partial
support tier. Evidence from one platform is not release conformance."** (Listed in §8;
this ADR does not edit `CLAUDE.md`.)

### 3. Definition of "supported client" (proposal — plan evaluator must check each element)

A client is supported in release R only if all of the following are recorded and
checkable from the tagged commit:

- **E1 — Matrix entry.** `plugins/loom/adapters/compatibility/vR.json` lists the client
  with a pinned floor version and its profile mapping.
- **E2 — Binding.** For a plugin-style client, a root binding under
  `adapters/roots/` plus manifest/catalog loading. For a host (Orca, Herdr), a host
  adapter descriptor that maps the launcher's inner-client descriptor to host
  commands (spec 07 host table) with no policy of its own. Which form applies is a
  planner decision per client (open question 3).
- **E3 — Offline Bats conformance.** Offline tests for launch descriptor, role
  contract parity, hook/guard behavior where the client has a hook surface, and
  refusal of unknown or below-floor versions, run in the repository gate
  (`scripts/check`).
- **E4 — Live runs on every mandatory platform.** At least one recorded live run of the
  client on **each** platform ADR 0019 requires for release R (currently Ubuntu
  22.04/24.04 x86-64 and macOS 14+ on Apple silicon and Intel), at the pinned floor,
  against the matrix, with evidence bound to the candidate commit. A run on one
  platform does not substitute for another.
- **E5 — Owner sign-off.** A recorded owner acknowledgement, naming the client, the
  evidence set and the candidate commit.

Not invented here: the exact evidence file format, where E4 runs are stored, and
whether existing ADR 0024 journals can be reused for any E4 cell. Those are for the
spec 10 amendment; no existing journal is declared to satisfy any element.

### 4. ADR 0019's matrix is still owed; not waived

ADR 0019's requirement that Ubuntu and macOS (including Intel) CI and both adapter
matrices pass before any release is published **stands unchanged**. As of this ADR the
Ubuntu and macOS-Intel live evidence for Claude Code and Codex has not been produced
(ADR 0024 §1 deferred it explicitly); it remains owed before v0.2.0 publishes. This ADR
does not waive, narrow, defer or reorder it. The Apple-silicon evidence from ADR 0024
is a partial input to E4 for v0.2.0 only if the planner/evaluator find it was run at
the pinned floors against the final candidate, which this ADR does not assert.

### 5. Applies to hosts as well as clients

Because ADR 0031 makes Herdr a host rather than a model client, E1–E5 are applied to
Orca and Herdr as hosts: the "client" under test is the host adapter plus the inner
clients it launches. Per ADR 0031 §5–§6, Herdr's `hc` gates and the unresolved
blind-review constraint remain preconditions; this ADR does not resolve them and no
evaluator role runs on `hc` until a follow-up ADR does.

### 6. Disposition for v0.3.0

**Antigravity.** Currently a dogfood adapter (ADR 0027 §4) with launcher code only.
Until v0.3.0 it is not supported and is not described as such. Work to reach
v0.3.0 supported status:

- Pin an Antigravity (`agy`) floor version; record it in the v0.3.0 matrix.
- Add the E1 matrix entry and profile mapping (the launcher already derives models
  from `agy models`; matrix and launcher must agree).
- Decide and add the E2 binding form (open question 3); no manifest or root binding exists.
- Specify and test Antigravity's role-isolation properties against ADR 0022 (blind
  review), spec 02 and role governance; the launcher alone proves none of this.
- Offline Bats for the launcher path (stubbed `agy`), unknown/below-floor refusal and
  rotation behavior.
- Decide whether `claude -> codex -> antigravity -> claude` evaluator rotation stays the
  default; before v0.3.0 it SHALL NOT route to Antigravity by default in a v0.2.x
  build (code slice; open question 4).
- Live runs per E4 and owner sign-off per E5.
- Spec 02/07/10 text carrying the ADR 0027 §5 amendments to a supported rather than
  dogfood footing.

**Orca.** Named as a host surface in spec 07; no host adapter exists; ADR 0031 §4
specified only behavior-level parity. Work to reach v0.3.0 supported status:

- Specify the Orca counterpart column of ADR 0031 §4 concretely (terminal/worktree
  create, send, wait, read, close) from verified Orca CLI behavior, with research
  where behavior is unverified; ADR 0031 left this explicitly open.
- Decide the Orca host-adapter artifact (spec 07 "host adapters are thin") and add it
  with an E1 matrix entry and E2 descriptor.
- Pin an Orca floor version.
- Confirm the Orca-hosted blind-evaluation path satisfies ADR 0022 (ADR 0031 §5 says
  Orca already does; this must be backed by E3/E4 evidence, not by that sentence).
- Offline Bats against a stub Orca CLI; refusal of unknown/below-floor versions.
- Live runs per E4 and owner sign-off per E5.

**Herdr (`hc`).** Work stays as ADR 0031 §7–§8 defines (retirement slice, `hc` host
adapter, role-governance `hc` deny, stub-`hc` Bats, owner-run live probes), plus the
E1–E5 evidence above. The `herdr` entries in `v0.3.0.json` (`herdr-plugin-root/v1`,
floor `0.1.10`) are stale under ADR 0031 and need correction in that work.

### 7. What this supersedes and what stands

Supersedes **ADR 0024** only in: (a) the "private development checkpoint" /
"dogfood-ready" status vocabulary in §1 as a lasting classification; (b) any reading
that dogfood readiness is a state a client can hold between unsupported and supported.

Supersedes **ADR 0027 §4** entirely (Antigravity is not a "private dogfood and
development runtime adapter"; it is unsupported until v0.3.0 meets §3). The remainder
of ADR 0027 (§1–§3 ambient inheritance, precedence, effort policy; §5 amendments)
stands, as does its rotation text subject to §6.

**Unchanged:** ADR 0019 in full, including §4 above; ADR 0024's bootstrap/transition
mechanics (§§2–5: exact amendment, slice eligibility, publication prerequisites)
and its recorded evidence as history; ADR 0031 in full (this ADR adds a
release mapping around it and does not alter its decisions).

### 8. Edits this decision requires later (listed, not drafted)

- **Spec 07:** "Private dogfood workflow and role mapping" (line ~94) retired or
  recast as v0.2.0 conformance; "Host surfaces" gains the Orca mapping once specified
  and the per-release status table; line ~120 "dogfood evaluation passes" reworded.
- **Spec 10:** release-evidence section gains E1–E5 and the per-release client
  table; Antigravity/Orca/Herdr packaging forms; v0.3.0 matrix correction.
- **Spec 00/02/03/06:** "dogfood" status language in 00 (~104), 02 ("Private dual-client
  dogfood role proof", ~217), 03 and 06 ("Isolated dogfood homes") reviewed; ADR 0024
  eligibility subsections stay as history where they describe the transition.
- **`CLAUDE.md` (finalize pass):** replace the line "Private macOS dogfood is not
  public support or release conformance." with the §2 invariant; reword the Map entry
  for `scripts/macos-dual-client-dogfood` ("private evidence only, not public Codex
  support (ADR 0024)") to say it is historical evidence tooling and confers no
  support status.
- **ADR README:** note ADR 0024 §1 and ADR 0027 §4 partly superseded by 0032 on
  acceptance.

## Consequences

- Public claims become simpler: two clients in 0.2.0, three more in 0.3.0, nothing
  in between. Antigravity code already in the tree is unsupported until 0.3.0.
- The macOS-only evidence from ADR 0024 cannot be cited as support; at best it
  feeds E4 for Apple silicon.
- v0.2.0 remains blocked on the full ADR 0019 matrix.
- Orca and Antigravity each need specification and evidence work, and Herdr's
  M9 depends on the unresolved ADR 0031 §5 blind-review choice, so v0.3.0 timing is
  gated on owner decisions below.
- Forecloses a future partial-support tier without a new ADR.

## Open Questions (owner, before acceptance)

1. Is E1–E5 the right evidence set, in particular must every client pass E4 on all
   three ADR 0019 platforms, including for hosts and Antigravity?
2. May ADR 0024's Apple-silicon journals count toward E4 for v0.2.0, or must all cells
   be re-run on the final candidate?
3. Binding form per client: plugin-style (manifest/root) or host-adapter descriptor, for
   Antigravity and Orca?
4. Should Antigravity be removed from default evaluator rotation until 0.3.0?
5. Does v0.3.0 ship if one of Antigravity, Orca, Herdr misses its evidence, or are all
   three atomic?
6. Herdr evaluators on `hc`: still blocked by ADR 0031 §5; which isolation choice?
7. What replaces the `herdr` entries in `v0.3.0.json`, and who pins the Orca and `agy` floors?
