<!-- loom:project-instructions begin schema=loom-project-instructions/v1 sha256=1c04cef53e48e9ca8830087536edc77948f71b176de0e02393defaddb495ee11 -->
## Loom project instructions

- Read `.docs/spec/README.md`, `.docs/status/handoff.md`, progress, then roadmap.
- Five cold roles use committed artifacts; no self-review; only root delegates.
- Specs change only through planner + cold plan evaluation. Remote verification and
  receipt establish `Landed`; never force-push a target.
- Keep shared policy portable and client adapters thin. A (platform, harness)
  pair is supported only in a release whose compatibility matrix lists it with
  complete conformance evidence; there is no private or partial support tier. Evidence
  from one platform or harness is not conformance for another.
- Run `scripts/check`; runtime floors are Bash 3.2+, Git 2.34+, and jq 1.6+.
- Codex workflows use `$loom-<name>` and installed helpers resolve from the physical
  Codex skill-source ascent; see specs 03, 04, 07, 08, and 10 for authority.
<!-- loom:project-instructions end -->
