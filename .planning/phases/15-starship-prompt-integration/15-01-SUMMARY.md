---
phase: 15-starship-prompt-integration
plan: 01
subsystem: infra
tags: [starship, zsh, prompt, nixos, shell]

# Dependency graph
requires:
  - phase: 13-audit-gap-closure
    provides: zsh.nix with history-substring-search ZLE bindings (base to append starship into)
provides:
  - programs.starship block inside lib.mkIf cfg.enable in modules/services/zsh.nix
  - Two-line starship prompt (username + character) auto-enabled on nerv.zsh.enable = true
  - Impermanence-safe prompt: STARSHIP_CONFIG exported to /nix/store path by NixOS module
affects: [15-starship-prompt-integration, any phase touching zsh.nix or shell UX]

# Tech tracking
tech-stack:
  added: [starship (via programs.starship NixOS module — built-in nixpkgs)]
  patterns:
    - programs.starship.enable used exclusively (never interactiveShellInit eval) to avoid ZLE clobbering
    - interactiveOnly left at default true so promptInit runs after interactiveShellInit (preserves ZLE bindings)
    - format string pins only two modules to prevent future nixpkgs default bleed-in

key-files:
  created: []
  modified:
    - modules/services/zsh.nix

key-decisions:
  - "programs.starship.enable used exclusively — never eval in interactiveShellInit; double init would clobber history-substring-search ZLE hooks"
  - "interactiveOnly left at default true — NixOS places starship init in promptInit which runs after interactiveShellInit, preserving ZLE bindings"
  - "format = \"$username\\n$character\" pins exactly two modules; future nixpkgs additions cannot bleed into the prompt"
  - "No separate nerv.zsh.starship.enable toggle — starship is always-on with nerv.zsh.enable, consistent with opinionated zero-config stance"
  - "STARSHIP_CONFIG not set manually — NixOS module serializes settings to /nix/store TOML and exports STARSHIP_CONFIG automatically"

patterns-established:
  - "NixOS programs.* module usage pattern: use built-in NixOS module attributes, not manual eval in interactiveShellInit"
  - "Prompt config pinned via explicit format string to prevent module sprawl"

requirements-completed: [PRMT-01, PRMT-02]

# Metrics
duration: 5min
completed: 2026-03-12
---

# Phase 15 Plan 01: Starship Prompt Integration Summary

**programs.starship block wired into zsh.nix — two-line username/character prompt auto-enabled on nerv.zsh.enable with ZLE bindings preserved via promptInit load order**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-03-12T21:17:29Z
- **Completed:** 2026-03-12T21:22:00Z
- **Tasks:** 2 of 2 complete
- **Files modified:** 1

## Accomplishments
- Appended `programs.starship` attribute set as sibling inside `lib.mkIf cfg.enable` in modules/services/zsh.nix
- Configured two-line prompt: line 1 username (dim cyan / red bold for root), line 2 `$` character (white on exit 0, bold red on non-zero)
- Pinned format string to `$username\n$character` only — no other modules can bleed in
- Left `interactiveOnly` unset (default true) — ensures starship init in `promptInit` runs after `interactiveShellInit`, preserving history-substring-search ZLE bindings
- NixOS module handles STARSHIP_CONFIG export to /nix/store path automatically — impermanence-safe by design

## Task Commits

Each task was committed atomically:

1. **Task 1: Append programs.starship block to zsh.nix** - `1339b22` (feat)
2. **Task 2: Verify starship prompt, ZLE bindings, and impermanence safety** - human-verify checkpoint approved

## Files Created/Modified
- `modules/services/zsh.nix` - Added programs.starship block (32 lines) after environment.systemPackages inside lib.mkIf cfg.enable

## Decisions Made
- Used `programs.starship.enable = true` exclusively — no `eval "$(starship init zsh)"` in interactiveShellInit; doing both would initialize starship twice and clobber ZLE widget registrations made by history-substring-search
- Left `interactiveOnly` unset at its default `true` — the NixOS module sources starship init in `promptInit`, which runs after `interactiveShellInit`; this preserves the `bindkey '^[[A'` and `bindkey '^[[B'` ZLE bindings
- Did not set STARSHIP_CONFIG manually — the NixOS `programs.starship` module serializes `settings` to a Nix-store TOML file and exports `STARSHIP_CONFIG` automatically, making the config survive root subvolume rollbacks

## Deviations from Plan

None - plan executed exactly as written.

Note: `nix-instantiate --parse` verification was attempted but Nix tooling is not available in the current environment (not on a NixOS host). Syntax was verified by manual review of the file structure. The plan explicitly notes to skip to the checkpoint if running outside an installed system.

## Issues Encountered
- `nix-instantiate` not available (no /nix directory on current host — development environment). Manual review confirmed correct Nix syntax: balanced braces, proper Nix string escaping with double-bracket strings for `\$`, all attributes inside `lib.mkIf cfg.enable`.

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- All tasks complete. Human-verify checkpoint approved with all checks passing:
  1. Two-line prompt appears correctly (username dim cyan, $ white) — confirmed
  2. Failing command turns $ red (bold red on non-zero exit) — confirmed
  3. Arrow-key history search works after starship loads (ZLE not clobbered) — confirmed
  4. `echo $STARSHIP_CONFIG` resolves to a /nix/store/...-starship.toml path — confirmed
  5. `sudo -i` shows username in red bold — confirmed
- v3.0 milestone fully complete: Phase 14 (zram) and Phase 15 (starship) both shipped

## Self-Check: PASSED

- modules/services/zsh.nix: FOUND
- 15-01-SUMMARY.md: FOUND
- Commit 1339b22: FOUND

---
*Phase: 15-starship-prompt-integration*
*Completed: 2026-03-12*
