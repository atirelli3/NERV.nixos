# Requirements: nerv.nixos

**Defined:** 2026-03-12
**Core Value:** A user declares only their machine-specific parameters and gets a secure, well-documented NixOS system out of the box.

## v3.0 Requirements

### Swap

- [x] **SWAP-01**: User can enable zram compressed swap via `nerv.disko.btrfs.zram.enable` (default: false, BTRFS layout only)
- [x] **SWAP-02**: User can configure zram device size as percent of RAM via `nerv.disko.btrfs.zram.memoryPercent` (default: 50)
- [x] **SWAP-03**: System raises a hard evaluation error when `nerv.disko.btrfs.zram.enable = true` on LVM layout

### Prompt

- [x] **PRMT-01**: Starship prompt activates automatically when `nerv.zsh.enable = true` — no separate toggle
- [x] **PRMT-02**: Prompt renders username on line 1 (dim cyan) and `$` on line 2 (white; red on non-zero exit code) with no other modules

## v4.0 Requirements

### Swap

- **SWAP-04**: `nerv.disko.btrfs.zram.algorithm` option (zstd is hardcoded in v3.0; escape hatch is `lib.mkForce`)
- **SWAP-05**: MB-based zram size option (alternative to memoryPercent for operators who prefer fixed sizes)

### Options

- **OPT-01**: `nerv.disko.lvm.tmpfsSize` — configurable tmpfs size for server profile (currently hardcoded 2G)
- **OPT-02**: `nerv.disko.btrfs.logSubvolume.enable` — @log subvolume on/off toggle
- **OPT-03**: `nerv.nix.autoUpdate` — auto-upgrade toggle (disabled by default)
- **OPT-04**: `nerv.kernel.package` — override kernel package (currently hardcoded to zen)
- **OPT-05**: `nerv.nix.gcInterval` — GC frequency option

## Out of Scope

| Feature | Reason |
|---------|--------|
| Disk-based BTRFS swapfile | BTRFS CoW incompatible; zram is the correct solution for this profile |
| `nerv.swap.zram.*` namespace | Moved to `nerv.disko.btrfs.zram.*` — BTRFS-layout-scoped by design |
| Starship git/directory modules | Belong in user dotfiles or Home Manager, not the system library |
| Per-user starship config option | Per-user override via `~/.config/starship.toml` already works natively |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SWAP-01 | Phase 14 | Complete |
| SWAP-02 | Phase 14 | Complete |
| SWAP-03 | Phase 14 | Complete |
| PRMT-01 | Phase 15 | Complete |
| PRMT-02 | Phase 15 | Complete |

**Coverage:**
- v3.0 requirements: 5 total
- Mapped to phases: 5
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-12*
*Last updated: 2026-03-12 — traceability updated after v3.0 roadmap creation (phases 14-15)*
