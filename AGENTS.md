<!-- loom:project-instructions begin schema=loom-project-instructions/v1 sha256=025e848ae610480a69d54967c9cafb87effe278464130d9cf421ca7100b2b2bf -->
## Loom project instructions

- Read `.docs/spec/README.md`, `.docs/status/handoff.md`, progress, then roadmap.
- Five cold roles use committed artifacts; no self-review; only root delegates.
- Specs change only through planner + cold plan evaluation. Remote verification and
  receipt establish `Landed`; never force-push a target.
- Keep shared policy portable and client adapters thin. Private macOS dogfood is not
  public support or release conformance.
- Run `scripts/check`; runtime floors are Bash 3.2+, Git 2.34+, and jq 1.6+.
- Codex workflows use `$loom-<name>` and installed helpers resolve from the physical
  Codex skill-source ascent; see specs 03, 04, 07, 08, and 10 for authority.
<!-- loom:project-instructions end -->
