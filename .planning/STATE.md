---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: milestone
status: "Roadmap approved — ready for /gsd:plan-phase 14"
stopped_at: "Phase 15-01 Task 1 complete; Task 2 checkpoint:human-verify pending"
last_updated: "2026-03-12T21:19:29.401Z"
last_activity: 2026-03-12 — v3.0 roadmap created
progress:
  total_phases: 2
  completed_phases: 2
  total_plans: 2
  completed_plans: 2
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-12 after v2.0)

**Core value:** A user declares only their machine-specific parameters and gets a secure, well-documented NixOS system out of the box.
**Current focus:** v3.0 Polish & UX — roadmap approved, ready to plan Phase 14

## Current Position

Phase: 14 (not started)
Plan: —
Status: Roadmap approved — ready for /gsd:plan-phase 14
Last activity: 2026-03-12 — v3.0 roadmap created

Progress: [░░░░░░░░░░] 0% (v3.0 — 0/2 phases)

## Performance Metrics

**Velocity:**
- Total plans completed: 0 (v3.0)
- Average duration: —
- Total execution time: 0 hours

**By Phase (v3.0):**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 14. zram Swap Module | - | - | - |
| 15. Starship Prompt Integration | - | - | - |

**Recent Trend:**
- Last 5 plans: —
- Trend: —

*Updated after each plan completion*

**v2.0 Historical (complete):**
| Phase 09-btrfs-disko-layout P01 | 2 | 1 tasks | 1 files |
| Phase 09-btrfs-disko-layout P02 | 1 | 2 tasks | 1 files |
| Phase 10-initrd-btrfs-rollback-service P01 | 2 | 2 tasks | 2 files |
| Phase 10-initrd-btrfs-rollback-service P02 | 2 | 2 tasks | 2 files |
| Phase 11-impermanence-btrfs-mode P01 | 3 | 2 tasks | 1 files |
| Phase 12-profile-wiring-and-documentation P01 | 1 | 1 tasks | 1 files |
| Phase 12-profile-wiring-and-documentation P02 | 3 | 2 tasks | 4 files |
| Phase 12-profile-wiring-and-documentation P03 | 4 | 2 tasks | 1 files |
| Phase 13-audit-gap-closure P01 | 2 | 2 tasks | 1 files |
| Phase 13-audit-gap-closure P02 | 1 | 1 tasks | 1 files |
| Phase 13-audit-gap-closure P03 | 5 | 1 tasks | 3 files |
| Phase 13-audit-gap-closure P04 | 1 | 1 tasks | 1 files |
| Phase 14-zram-swap-module P01 | 15 | 1 tasks | 1 files |
| Phase 14-zram-swap-module P01 | 15 | 2 tasks | 1 files |
| Phase 15-starship-prompt-integration P01 | 5 | 1 tasks | 1 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [v3.0 pre-phase]: No new flake inputs required — zramSwap and programs.starship are both built-in NixOS modules present in nixpkgs release-25.11
- [v3.0 pre-phase]: nerv.disko.btrfs.zram.* namespace chosen (not nerv.swap.zram.*) — scoped to BTRFS layout by design; name makes the BTRFS constraint self-documenting
- [v3.0 pre-phase]: memoryPercent exposed (not MB-based size) — avoids memoryMax + memoryPercent "smaller wins" interaction bug (nixpkgs #435031); MB sizing deferred to v4.0 as SWAP-05
- [v3.0 pre-phase]: LVM + zram combination prevented by hard evaluation assertion (not lib.warn) — silent incorrect config is worse than a build failure
- [v3.0 pre-phase]: Starship is always-on with nerv.zsh.enable — no separate toggle; prompt is a baseline UX improvement consistent with the library's opinionated stance
- [v3.0 pre-phase]: programs.starship.enable exclusively (never interactiveShellInit eval) — double init clobbers ZLE hooks (history-substring-search breaks)
- [v3.0 pre-phase]: programs.starship.interactiveOnly left at default true — false would move starship init before plugin chain, breaking history-substring-search ZLE bindings
- [v3.0 pre-phase]: zram implemented first (new file, isolated risk) then starship (existing file, cleaner diff against known-working base)
- [Phase 14-zram-swap-module]: zramSwap block placed inside lib.mkIf isBtrfs double-guard; lib.mkForce on algorithm; priority=100; memoryMax omitted to avoid nixpkgs #435031
- [Phase 14-zram-swap-module]: zramSwap block double-guarded inside lib.mkIf isBtrfs AND lib.mkIf cfg.btrfs.zram.enable — defense in depth if assertion bypassed
- [Phase 14-zram-swap-module]: memoryMax omitted entirely to avoid nixpkgs #435031 silent size truncation bug
- [Phase 15-starship-prompt-integration]: programs.starship.enable used exclusively (never interactiveShellInit eval) to avoid double-init clobbering history-substring-search ZLE hooks
- [Phase 15-starship-prompt-integration]: interactiveOnly left at default true — promptInit runs after interactiveShellInit, preserving ZLE bindings for history-substring-search
- [Phase 15-starship-prompt-integration]: format string pinned to $username\n$character only — prevents future nixpkgs default module additions from bleeding into the prompt

### Pending Todos

- Phase 14: Confirm zramSwap.priority value in implementation notes (nixpkgs default is 5; 100 documented in research as "prefer zram" — either is correct post-LVM assertion)
- Phase 14: Add init_on_free=1 CPU tradeoff comment in swap.nix (kernel.nix already sets this; heavy swap + zstd decompression adds CPU overhead — document, do not change)
- Phase 15: Verify arrow-key history search works after starship loads (history-substring-search ZLE binding conflict is the primary risk for this phase)

### Blockers/Concerns

None at roadmap creation. Research flags above become implementation verification tasks.

## Session Continuity

Last session: 2026-03-12T21:19:29.400Z
Stopped at: Phase 15-01 Task 1 complete; Task 2 checkpoint:human-verify pending
Resume file: None
Next action: /gsd:plan-phase 14
