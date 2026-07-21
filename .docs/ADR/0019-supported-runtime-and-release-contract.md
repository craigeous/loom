# 0019 — Supported Runtime, Platforms, Compatibility, and Release Contract

Status: Accepted
Date: 2026-07-21

## Context

The [repository improvement plan](../repository-improvement-plan.md) requires a
reproducible baseline before safety changes and a coherent release after packaging
conformance. The repository currently labels executables as POSIX `sh` while the
coordinator relies extensively on `local`, and it does not declare supported operating
systems, Windows behavior, production dependency floors, or tested client minima. The
manifest also omits the version described by approved spec 10.

The approved [dual-platform research](../research/2026-07-21-dual-platform-plugin-architecture.md)
adds independently evolving Claude Code and Codex compatibility surfaces. A floating
“works in the user's environment” claim is not reproducible enough for a production
release.

In scope are the shell, host OS, production/runtime dependencies, client compatibility
baseline, version semantics, persisted-protocol compatibility, and release evidence.
CI implementation, lockfile/download mechanics, changelog contents, and release
automation are follow-on work. Workflow profiles and landing-history shape require M8
benchmark evidence and are explicitly not decided here.

## Decision

### 1. Loom executables target Bash, not POSIX `sh`

All shipped shell executables SHALL use `#!/usr/bin/env bash` and support **Bash 3.2
or newer**. Bash 3.2 is the language floor so a supported macOS host can use its system
Bash without Homebrew. Production code SHALL avoid features introduced after 3.2 unless
the release contract is deliberately raised. Tests SHALL run on Bash 3.2 and on the
current Bash 5.x line. Files executed by Bats are Bash test code and follow the same
floor where Bats permits it.

Existing `#!/bin/sh` and “POSIX” claims are migration targets, not grandfathered
exceptions. The M0 gate must switch syntax/lint configuration and documentation
together; mixed unsupported shebang semantics are not releasable.

### 2. Supported hosts and dependencies are explicit

The v0.2 line supports:

- Ubuntu 22.04 LTS and 24.04 LTS on x86-64;
- macOS 14 or newer on Apple silicon and x86-64 where the selected client itself is
  supported.

Native Windows, PowerShell, Git Bash/MSYS2, Cygwin, and WSL are **not supported** in
v0.2. Documentation may describe an unverified community path, but SHALL not imply
support. Adding any of these environments requires a later decision plus CI and
end-to-end evidence.

Required production tools are Bash >=3.2, Git >=2.34, and jq >=1.6, in addition to one
supported Loom client. `jq` is required so hook and protocol JSON is parsed and emitted
without regex fallbacks. Bats, ShellCheck, shfmt, and validators are build/test
dependencies, not end-user runtime dependencies; their exact versions SHALL be pinned
by the reproducible check/bootstrap mechanism rather than merely listed as floating
minimums.

### 3. Client support is a pinned compatibility matrix

The v0.2 minimums are **Claude Code 2.1.216** and **Codex CLI 0.144.6**, the versions
inspected by the approved research. M0 SHALL pin and run the adapter matrix at exactly
those floors: clean install, manifest/marketplace loading, explicit workflow invocation,
cold-role launch, hook fixtures, helper resolution, and uninstall. If either floor
fails, v0.2 is blocked; raising it requires a superseding planning decision backed by
the first passing-version evidence. Implementation SHALL never silently raise the
minimum or claim an untested lower one.

ChatGPT desktop support requires a release whose embedded Codex plugin API passes the
same matrix; a marketing/app version alone is not assumed equivalent. Newer client
versions are supported only after CI or a release-candidate compatibility run passes.
A detected unknown or below-minimum client is a `loom doctor` error and blocks a
supported-mode run; Loom does not silently continue under a compatibility claim it
cannot substantiate.

### 4. The product uses SemVer and releases all surfaces atomically

Loom adopts Semantic Versioning. The authoritative product version is `X.Y.Z`, appears
identically in both plugin manifests and release metadata, and is tagged `vX.Y.Z`.
Catalog entries, helper `--version` output, protocol producers, documentation, and the
changelog SHALL agree with that version. Commit SHAs may be recorded as build provenance
but are not user-facing versions.

While major version is zero, a backward-incompatible change increments the minor
version and a compatible fix increments the patch version. New compatible functionality
also increments the minor version. The planned identifier, coordination, packaging,
and dual-client changes therefore release as **v0.2.0**. No release may be published
until M0 through M7 are green on the declared matrix.

Every persisted state schema and interchange protocol has its own explicit version.
Readers SHALL reject unknown major/schema versions; no best-effort reinterpretation is
allowed. Compatible additive evolution preserves the version or increments a documented
minor as its protocol defines. Incompatible evolution introduces a new major/schema and
an explicit migration or cleanup path. Product SemVer and protocol versions are related
release evidence but are not numerically coupled.

### 5. A release is the tested, tagged source—not a manifest edit

A release requires, from a clean clone at the proposed tag: the full local check;
Ubuntu and macOS CI; both adapter matrices; clean install, upgrade, uninstall, and
fresh-clone end-to-end tests; migration notes for existing `.git/loom` state; an actual
license file; a versioned changelog; agreement of manifests/catalogs/docs/helpers; and
verification that the tag resolves to the tested commit. Failure of any required cell
blocks publication. Release artifacts SHALL be derived from that tag and SHALL not be
edited after testing.

## Consequences

- M0 has a concrete language and support matrix: Bash rather than nominal POSIX `sh`,
  Ubuntu/macOS only, robust JSON via jq, and independently pinned client adapters.
- The Bash 3.2 floor limits convenience features and requires an explicit compatibility
  lane, but avoids forcing a package-manager Bash on macOS. Requiring jq adds one
  dependency and removes unsafe JSON-regex fallbacks.
- Spec 08's POSIX-shell language and spec 10's incomplete version/release text require
  later planner-authored amendments; packaging, README, gates, shebangs, CI, and code
  change only in subsequent slices.
- ADR 0002 remains superseded only as stated by ADR 0018. This ADR adds tested client
  version floors; it does not select role capability profiles or reopen model policy.
- M8 workflow-profile and landing-history choices remain deferred until the benchmark
  produces evidence. They are not smuggled into v0.2 release mechanics.
