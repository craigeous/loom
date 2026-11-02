# 0032 — Release Client Mapping and Retirement of the Dogfood Support Tier

Status: Plan Review
Date: 2026-11-01

## Context

Loom has accumulated clients under three different labels. ADR 0019 defines the v0.2
public release as Claude Code + Codex CLI on Ubuntu 22.04/24.04 x86-64 and macOS 14+
(on the architectures §2 names), blocked until its matrix is green. ADR 0024 authorized a
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

**Owner decisions (binding).**

1. **"Supported"** means loom fully functions within the harness on the platform: every
   role, the full loop, and the gate, on that OS with that client. Support is judged per
   (platform, harness) pair.
2. **Release sequence.** v0.2.0 = macOS only, with Claude Code CLI and Codex CLI.
   v0.3.0 = the other harnesses (Antigravity, Orca, Herdr `hc`) on macOS. v0.4.0 = the
   other operating systems, starting with Ubuntu 22.04 and 24.04 on x86-64.
   macOS Intel is not a supported platform in any release.
3. **"Dogfood" is retired as a support tier.** A (platform, harness) pair is supported
   in a release with conformance evidence, or it is not in that release. There is no
   private middle tier for a pair a release claims. ADR 0024's macOS evidence stays a
   historical record, not a support claim.

In scope: the release sequence, the definition of "supported", the per-pair evidence,
the disposition of Antigravity and Orca, and exactly which parts of earlier ADRs this
supersedes. Out of scope: spec text, `CLAUDE.md`, README, workflow, matrix or code
changes, and the Herdr work already decided by ADR 0031.

## Decision

ADR 0032 supersedes ADR 0019 §2 for v0.2.0 and v0.3.0: the Ubuntu and macOS-Intel release-matrix requirement is replaced by the Apple-silicon-only macOS requirement in this ADR; macOS Intel is not a supported platform. ADR 0019 is otherwise unchanged.

Replacement macOS requirement for v0.2.0 and v0.3.0: macOS 14 or newer on Apple silicon
(arm64), one required pair per harness in the release row (§1), each with the §3
evidence. No other macOS architecture and no Ubuntu evidence is required for either
release.

### 1. Release sequence

A *platform* is an operating system plus CPU architecture. A *harness* is a Claude Code
CLI, Codex CLI, Antigravity, Orca or Herdr (`hc`) as defined in the compatibility
matrix. The macOS platform for v0.2.0 and v0.3.0 is **macOS 14 or newer on Apple silicon
(arm64) only**; it is the only macOS platform loom supports in any release. The Ubuntu
platform is **Ubuntu 22.04 and 24.04 on x86-64**, from v0.4.0.

Per-(platform, harness) pairs (each platform below is a separate row set; "CC" = Claude
Code CLI, "Codex" = Codex CLI):

| Release | Platform | Harness | Status |
|---|---|---|---|
| v0.2.0 | macOS 14+ Apple silicon | CC | REQUIRED |
| v0.2.0 | macOS 14+ Apple silicon | Codex | REQUIRED |
| v0.3.0 | macOS 14+ Apple silicon | CC, Codex | REQUIRED (carried) |
| v0.3.0 | macOS 14+ Apple silicon | Antigravity | REQUIRED |
| v0.3.0 | macOS 14+ Apple silicon | Orca | REQUIRED |
| v0.3.0 | macOS 14+ Apple silicon | Herdr (`hc`) | REQUIRED |
| v0.4.0 | Ubuntu 22.04 x86-64 | CC, Codex, Antigravity, Orca, Herdr | each REQUIRED unless the v0.4.0 ADR records it NOT APPLICABLE |
| v0.4.0 | Ubuntu 24.04 x86-64 | same five harnesses | same rule |
| v0.4.0 | macOS 14+ Apple silicon | the five v0.3.0 harnesses | REQUIRED (carried) |

Counts: v0.2.0 has 2 required pairs; v0.3.0 has 5 required pairs. The v0.4.0 harness
list and any NOT APPLICABLE pair are fixed by the v0.4.0 planning ADR, not here. No
macOS Intel pair appears in any row.

**The pair rule (stated once):** every pair in a release row is either *required* or
*not applicable*. All required pairs of the row, together and atomically, must satisfy
§3 or the release is not published. A pair is *not applicable* only if the ADR that
fixes the row names the reason (the harness does not run on that platform) and the check
that proves it (the harness vendor's published platform support at the pinned floor,
plus a failed install or launch attempt on that platform with a log reference). Absent
both, the pair is required. A not-applicable pair is not counted as required and is not
claimed as supported. As written, every pair in the v0.2.0 and v0.3.0 rows is required;
none is declared not applicable.

Each later release is additive: it also carries every earlier pair, which must keep
passing its own evidence. If a required pair cannot satisfy §3, the release is not shipped
under that label; moving a pair to a later release requires a superseding ADR. A
(platform, harness) pair in no row is unsupported, whatever code exists for it. The
release at which a pair is first supported is fixed by this table.

**Ubuntu is not required for v0.2.0 or v0.3.0.** It moves to v0.4.0. v0.4.0 scope beyond
Ubuntu (other operating systems) is not decided here.

### 2. Retirement of the dogfood tier

"Dogfood", "private dogfood" and "development runtime adapter" cease to be support
statuses. For a release, a pair is *supported* (§3 evidence complete) or *absent*.
Pre-release evidence gathered on one platform remains valid input to §3 for that
platform but confers no status. Code for a harness outside the current release's row
may exist in the tree but SHALL NOT be documented, matrixed or described as supported,
and SHALL NOT be reachable by default routing (see §6, Antigravity).

Replacement for the `CLAUDE.md` invariant "Private macOS dogfood is not public support
or release conformance": **"A (platform, harness) pair is supported only in a release
whose compatibility matrix lists it with complete conformance evidence; there is no
private or partial support tier. Evidence from one platform or harness is not
conformance for another."** (Listed in §8; this ADR does not edit `CLAUDE.md`.)

### 3. Definition of "supported" and per-pair evidence

A (platform, harness) pair is **supported** in release R when loom fully functions in
that harness on that platform: **every role** (researcher, planner, plan evaluator,
developer, code evaluator), **the full loop** (research, plan, plan evaluation,
develop, code evaluation, land, with every handoff committed) and **the gate**
(`scripts/check`, or the managed project's gate) all work, with blind review intact
(ADR 0022). A harness that passes on one platform has no claim on another.

For release R, E1–E3 hold in the tagged commit and E4–E5 are recorded in an external
evidence record (below) bound to that commit:

- **E1 — Matrix entry.** `plugins/loom/adapters/compatibility/vR.json` lists the harness
  with a pinned floor version, its profile mapping and the platforms it is claimed on.
- **E2 — Binding.** For a plugin-style harness, a root binding under `adapters/roots/`
  plus manifest/catalog loading. For a host (Orca, Herdr), a host adapter descriptor
  that maps the launcher's inner-client descriptor to host commands (spec 07 host
  table) with no policy of its own. Which form applies is a planner decision per
  harness (open question 2).
- **E3 — Offline Bats conformance.** Offline tests for launch descriptor, role contract
  parity, hook/guard behavior where the harness has a hook surface, and refusal of
  unknown or below-floor versions, run in the repository gate (`scripts/check`) on every
  platform of the release.
- **E4 — Live conformance per pair.** For **each** (platform, harness) pair in the
  release's row, at the pinned floor and against the matrix, recorded runs showing:
  (a) each of the five roles launched and returning through the harness; (b) one full
  loop from research through landing, with blind review (no author identity, no
  author reasoning); and (c) the gate passing on that platform. Each run is recorded
  with platform, harness floor, result and a log or journal reference. A run on one
  pair does not substitute for another.
- **E5 — Owner sign-off.** An owner acknowledgement in the evidence record, naming each
  pair, the evidence set and the commit.

**Evidence record.** E4 and E5 are recorded in an immutable file, one per release, at
`.docs/evaluations/release-evidence/vR.json`, written **after** the candidate commit
is chosen and tagged `vR`. It names the full candidate commit hash, and per pair the
runs (a)–(c) (floor version, platform, result, log or journal reference) and the owner
acknowledgement. The candidate commit therefore never contains its own hash or its
post-test acknowledgement. It is checkable with git: the record lives in a commit that
descends from the tag (`git merge-base --is-ancestor vR <record-commit>`), the hash it
names equals `git rev-parse vR^{commit}`, and the record is append-only after
publication (corrections are new files, not edits). A release is not published until
the record exists on `main` and verifies. Candidate-commit content (E1–E3) is
unaffected; a later change to the candidate requires a new tag and a new record.
This changes where evidence is recorded, not whether evidence is required.

Not invented here: the exact evidence file format, where E4 runs are stored, and
whether existing ADR 0024 journals can be reused for any E4 pair. Those are for the
spec 10 amendment; no existing journal is declared to satisfy any element.

### 4. Relationship to ADR 0019 (superseded and kept)

ADR 0019 is Accepted and immutable; this ADR supersedes only the clauses below and
edits nothing in it.

**Superseded, for v0.2.0 and v0.3.0 (ADR 0019 §2 only; Ubuntu deferred to v0.4.0; Intel unsupported).** The first two bullets are the §2 supersession; the remaining items state how §2's replacement applies to ADR 0019 text that cites the declared matrix, and are not further supersessions:

- §2, second bullet, "macOS 14 or newer on Apple silicon and x86-64 where the selected
  client itself is supported" (the macOS-Intel release-matrix clause). **Exact
  replacement for macOS:** "macOS 14 or newer on Apple silicon (arm64), where the
  selected harness itself is supported." macOS Intel is not a supported platform; no
  Intel evidence is required or accepted as support. The condition "where the selected client itself is
  supported" is retained.
- §2, first bullet, "Ubuntu 22.04 LTS and 24.04 LTS on x86-64" as a platform the
  "v0.2 line supports". Ubuntu is not part of v0.2.0 or v0.3.0 support, and is not a
  release requirement for either. It becomes a v0.4.0 platform.
- §5 (applied reading, not superseded), the requirement of "Ubuntu and macOS CI; both adapter matrices": for v0.2.0 and
  v0.3.0 it means macOS CI and the per-pair adapter matrix of §1, not Ubuntu CI.
- §4 (applied reading, not superseded), the reading of "M0 through M7 are green on the declared matrix" that makes the
  declared matrix include Ubuntu: the declared matrix for v0.2.0 is the two pairs
  in §1 and for v0.3.0 the five pairs.
- Consequence text "Ubuntu/macOS only" as a description of v0.2 scope (informative,
  not normative; read as macOS only).

**Kept (unchanged):**

- Release evidence itself is required, and **no release is published without it**
  (§4 last sentence, §5): "failure of any required cell blocks publication".
- §1 (Bash 3.2+/Git 2.34+/jq 1.6+ runtime, syntax migration) in full.
- §2 macOS bullet's "macOS 14 or newer" floor and its "where the selected client itself
  is supported" condition (architecture replaced as above), the non-support of native Windows, PowerShell, Git Bash/MSYS2, Cygwin
  and WSL, and the tool-dependency paragraph.
- §3 pinned floors (Claude Code 2.1.216, Codex CLI 0.144.6), the matrix scope (clean
  install, loading, explicit invocation, cold-role launch, hooks, helper resolution,
  uninstall), and the unknown/below-floor refusal.
- §4 SemVer, atomic release of all surfaces, and protocol versioning.
- §5 other requirements: clean clone at the tag, full local check, clean install/
  upgrade/uninstall and fresh-clone end-to-end, migration notes, license, changelog,
  agreement of manifests/catalogs/docs/helpers, tag-resolves-to-tested-commit,
  artifacts not edited after testing.

The macOS Apple-silicon evidence from ADR 0024 is a possible input to v0.2.0 E4 only
if shown to be at the pinned floors against the final candidate (open question 1).

### 5. Applies to hosts as well as clients

Because ADR 0031 makes Herdr a host rather than a model client, E1–E5 are applied to
Orca and Herdr as hosts: the harness under test is the host adapter plus the inner
clients it launches. Per ADR 0031 §5–§6, Herdr's `hc` gates and the unresolved
blind-review constraint remain preconditions; this ADR does not resolve them and no
evaluator role runs on `hc` until a follow-up ADR does. Since E4 requires every role,
Herdr cannot be a supported pair until that is resolved.

### 6. Disposition for v0.3.0

All v0.3.0 work is on macOS pairs; no Ubuntu evidence is required.

**Antigravity.** Currently a dogfood adapter (ADR 0027 §4) with launcher code only.
Until v0.3.0 it is not supported and is not described as such. Work to reach
v0.3.0 supported status:

- Pin an Antigravity (`agy`) floor version; record it in the v0.3.0 matrix.
- Add the E1 matrix entry and profile mapping (the launcher already derives models
  from `agy models`; matrix and launcher must agree).
- Decide and add the E2 binding form (open question 2); no manifest or root binding exists.
- Specify and test Antigravity's role-isolation properties against ADR 0022 (blind
  review), spec 02 and role governance; the launcher alone proves none of this.
- Offline Bats for the launcher path (stubbed `agy`), unknown/below-floor refusal and
  rotation behavior.
- Default evaluator rotation excludes Antigravity until v0.3.0 meets §3: the
  `claude -> codex -> antigravity -> claude` rotation SHALL NOT route to Antigravity
  by default in any v0.2.x build (code slice). Antigravity is reachable only by
  explicit opt-in, undocumented as supported. Restoring it to default rotation needs
  the v0.3.0 evidence record to verify first.
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

Supersedes **ADR 0019** §2 only, as stated at the head of the Decision and detailed in §4.

Supersedes **ADR 0024** only in: (a) the "private development checkpoint" /
"dogfood-ready" status vocabulary in §1 as a lasting classification; (b) any reading
that dogfood readiness is a state a pair can hold between unsupported and supported.

Supersedes **ADR 0027 §4** entirely (Antigravity is not a "private dogfood and
development runtime adapter"; it is unsupported until v0.3.0 meets §3). The remainder
of ADR 0027 (§1–§3 ambient inheritance, precedence, effort policy; §5 amendments)
stands, as does its rotation text subject to §6.

**Unchanged:** the ADR 0019 clauses kept in §4; ADR 0024's bootstrap/transition
mechanics (§§2–5: exact amendment, slice eligibility, publication prerequisites)
and its recorded evidence as history; ADR 0031 in full (this ADR adds a release
mapping around it and does not alter its decisions).

### 8. Edits this decision requires later (listed, not drafted; finalize pass after acceptance)

- **README "Supported Platforms & Prerequisites":** currently says macOS on Apple
  silicon or Intel and Ubuntu 22.04/24.04 as the v0.2 baseline; restate as macOS-only for v0.2.0/v0.3.0 with Ubuntu planned for v0.4.0, and
  state the per-pair support definition.
- **`CLAUDE.md` (finalize pass):** replace the line "Private macOS dogfood is not
  public support or release conformance." with the §2 invariant; reword the Map entry
  for `scripts/macos-dual-client-dogfood` ("private evidence only, not public Codex
  support (ADR 0024)") to say it is historical evidence tooling and confers no
  support status.
- **Spec 10:** release-evidence section gains E1–E5, the per-release (platform,
  harness) table and the macOS-only v0.2.0 matrix; Antigravity/Orca/Herdr packaging
  forms; v0.3.0 matrix correction; Ubuntu moved to v0.4.0.
- **ADR 0024 / ADR 0027 supersession notes:** note ADR 0024 §1 and ADR 0027 §4 partly
  superseded by 0032, and ADR 0019 §2/§5 Ubuntu clauses superseded, in the ADR
  README register on acceptance (ADR bodies stay immutable).
- **Release matrix workflow (`.github/workflows/check.yml`):** drop Ubuntu from the
  v0.2.0/v0.3.0 release matrix (macOS Apple silicon only; remove the macOS Intel lane and the Ubuntu lane); Ubuntu returns for v0.4.0.
- **Spec 07:** "Private dogfood workflow and role mapping" (line ~94) retired or
  recast as v0.2.0 conformance; "Host surfaces" gains the Orca mapping once specified
  and the per-release status table; line ~120 "dogfood evaluation passes" reworded.
- **Spec 00/02/03/06:** "dogfood" status language in 00 (~104), 02 ("Private dual-client
  dogfood role proof", ~217), 03 and 06 ("Isolated dogfood homes") reviewed; ADR 0024
  eligibility subsections stay as history where they describe the transition.

## Consequences

- Public claims become simple: macOS with two harnesses in 0.2.0, three more harnesses
  on macOS in 0.3.0, other operating systems from 0.4.0, nothing in between.
  Antigravity code already in the tree is unsupported until 0.3.0.
- v0.2.0 no longer waits on Ubuntu; it still waits on macOS Apple-silicon live
  evidence for both harnesses (Apple silicon only). ADR 0024 evidence cannot be cited as support; at
  best it feeds E4 for the v0.2.0 pairs.
- Ubuntu users have no supported path until v0.4.0; documentation may not imply one.
- Orca and Antigravity each need specification and evidence work, and Herdr's
  M9 depends on the unresolved ADR 0031 §5 blind-review choice, so v0.3.0 timing is
  gated on owner decisions below.
- Forecloses a future partial-support tier without a new ADR.

## Open Questions (owner, before acceptance)

Resolved normatively above and no longer open: the release sequence, the macOS
Apple-silicon-only scope of v0.2.0 and v0.3.0 and the non-support of macOS Intel (owner
decision; §1); the per-pair definition and E1–E5 (§3); the ADR 0019
clauses superseded and kept (§4); Antigravity excluded from default rotation until
v0.3.0 (§6); each release atomic (§1). The questions below do not reopen those
decisions.

1. May ADR 0024's Apple-silicon journals count toward v0.2.0 E4 for the Apple-silicon
   pairs? Default per §4: no, unless shown to be at the pinned floors against the final
   candidate. Trigger: decided in the spec 10 amendment.
2. Binding form per harness: plugin-style (manifest/root) or host-adapter descriptor, for
   Antigravity and Orca?
3. Herdr evaluators on `hc`: still blocked by ADR 0031 §5; which isolation choice?
4. What replaces the `herdr` entries in `v0.3.0.json`, and who pins the Orca and `agy` floors?
