# Roadmap: nerv.nixos

## Milestones

- ✅ **v2.0 Stateless NixOS Library** — Phases 1-13 (shipped 2026-03-12)
- 🔄 **v3.0 Polish & UX** — Phases 14-15 (in progress)

## Phases

<details>
<summary>✅ v2.0 Stateless NixOS Library (Phases 1-13) — SHIPPED 2026-03-12</summary>

**v1.0 phases (library foundation):**
- [x] Phase 1: Flake Foundation (2/2 plans) — completed 2026-03-06
- [x] Phase 2: Services Reorganization (3/3 plans) — completed 2026-03-06
- [x] Phase 3: System Modules (non-boot) (3/3 plans) — completed 2026-03-07
- [x] Phase 4: Boot Extraction (3/3 plans) — completed 2026-03-07
- [x] Phase 5: Home Manager Skeleton (1/1 plan) — completed 2026-03-08
- [x] Phase 6: Documentation Sweep (3/3 plans) — completed 2026-03-07
- [x] Phase 7: Flake Hardening, Disko Wiring, and Nyquist Validation (4/4 plans) — completed 2026-03-08
- [x] Phase 8: NERV.nixos Release & Multi-Profile Migration (4/4 plans) — completed 2026-03-08

**v2.0 phases (stateless disk layouts):**
- [x] Phase 9: BTRFS Disko Layout (2/2 plans) — completed 2026-03-09
- [x] Phase 10: initrd BTRFS Rollback Service (2/2 plans) — completed 2026-03-10
- [x] Phase 11: Impermanence BTRFS Mode (1/1 plan) — completed 2026-03-10
- [x] Phase 12: Profile Wiring and Documentation (3/3 plans) — completed 2026-03-10
- [x] Phase 13: Audit Gap Closure (4/4 plans) — completed 2026-03-12

Full archive: `.planning/milestones/v2.0-ROADMAP.md`

</details>

**v3.0 phases (polish & UX):**
- [x] **Phase 14: zram Swap Module** — BTRFS-safe in-memory compressed swap via nerv.disko.btrfs.zram options (completed 2026-03-12)
- [x] **Phase 15: Starship Prompt Integration** — Minimal two-line starship prompt auto-enabled with nerv.zsh (completed 2026-03-12)

## Phase Details

### Phase 14: zram Swap Module
**Goal**: Operators using the BTRFS host profile can enable in-memory compressed swap with a single option
**Depends on**: Nothing (new file, zero dependencies on in-flight work)
**Requirements**: SWAP-01, SWAP-02, SWAP-03
**Success Criteria** (what must be TRUE):
  1. Setting `nerv.disko.btrfs.zram.enable = true` on a BTRFS host causes `swapon --show` to list `/dev/zram0` after boot
  2. Setting `nerv.disko.btrfs.zram.memoryPercent = 25` causes the zram device to be sized at 25% of physical RAM
  3. Enabling zram on a system with `nerv.disko.layout = "lvm"` fails at `nix flake check` / `nixos-rebuild` evaluation with a clear error message — the build never reaches the boot stage
  4. Leaving `nerv.disko.btrfs.zram.enable = false` (the default) produces no zram device and no swap in the BTRFS profile — behavior is identical to v2.0
**Plans**: 1 plan

Plans:
- [x] 14-01-PLAN.md — Extend disko.nix with zram options, wired zramSwap config, and LVM assertion

### Phase 15: Starship Prompt Integration
**Goal**: Any host with `nerv.zsh.enable = true` gets a minimal, impermanence-safe two-line shell prompt with no configuration required
**Depends on**: Phase 14 (clean base; starship modifies an existing file, zram creates a new one — ordering keeps diffs isolated)
**Requirements**: PRMT-01, PRMT-02
**Success Criteria** (what must be TRUE):
  1. On a host where `nerv.zsh.enable = true`, opening a new shell displays the two-line starship prompt without any additional option — no `nerv.zsh.starship.enable` flag needed
  2. Line 1 of the prompt shows the username in dim cyan; line 2 shows `$` in white on a zero exit code and red after a non-zero exit code
  3. Arrow-key history search (history-substring-search) works correctly after starship loads — ZLE bindings are not clobbered
  4. After a root subvolume rollback, the prompt reappears unchanged on the next login — `echo $STARSHIP_CONFIG` resolves to a path inside the Nix store
**Plans**: 1 plan

Plans:
- [x] 15-01-PLAN.md — Append programs.starship to zsh.nix and verify prompt, ZLE bindings, impermanence safety

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Flake Foundation | 2/2 | ✅ Complete | 2026-03-06 |
| 2. Services Reorganization | 3/3 | ✅ Complete | 2026-03-06 |
| 3. System Modules (non-boot) | 3/3 | ✅ Complete | 2026-03-07 |
| 4. Boot Extraction | 3/3 | ✅ Complete | 2026-03-07 |
| 5. Home Manager Skeleton | 1/1 | ✅ Complete | 2026-03-08 |
| 6. Documentation Sweep | 3/3 | ✅ Complete | 2026-03-07 |
| 7. Flake Hardening / Disko / Nyquist | 4/4 | ✅ Complete | 2026-03-08 |
| 8. Release & Multi-Profile Migration | 4/4 | ✅ Complete | 2026-03-08 |
| 9. BTRFS Disko Layout | 2/2 | ✅ Complete | 2026-03-09 |
| 10. initrd BTRFS Rollback Service | 2/2 | ✅ Complete | 2026-03-10 |
| 11. Impermanence BTRFS Mode | 1/1 | ✅ Complete | 2026-03-10 |
| 12. Profile Wiring and Documentation | 3/3 | ✅ Complete | 2026-03-10 |
| 13. Audit Gap Closure | 4/4 | ✅ Complete | 2026-03-12 |
| 14. zram Swap Module | 1/1 | ✅ Complete | 2026-03-12 |
| 15. Starship Prompt Integration | 1/1 | Complete    | 2026-03-12 |

---
*v2.0 shipped 2026-03-12 · v3.0 roadmap created 2026-03-12*
