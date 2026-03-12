# nerv.nixos

## What This Is

A general-purpose, opinionated NixOS flake providing hardened system defaults as composable modules with stateless disk layouts for both desktop and server targets. Users declare only machine-specific parameters (hostname, primary user, CPU/GPU, disk layout) and get a secure, well-documented, stateless NixOS system out of the box.

**v2.0 ships two stateless profiles:**
- `hostProfile` — BTRFS subvolumes (@, @root-blank, @home, @nix, @persist, @log) with initrd rollback service that resets root on every boot
- `serverProfile` — LVM layout with tmpfs root and environment.persistence for explicit state declaration

## Core Value

A user should be able to declare only their machine-specific parameters and get a secure, well-documented NixOS system out of the box.

## Requirements

### Validated

**v1.0 — Library Structure:**
- ✓ Repository reorganized into modules/system/ and modules/services/ with default.nix aggregators — v1.0/v2.0
- ✓ Boot/LUKS/initrd config extracted into modules/system/boot.nix — v1.0/v2.0
- ✓ home/default.nix skeleton with Home Manager NixOS module wired — v1.0/v2.0
- ✓ flake.nix exports nixosModules.{default,system,services,home} — v1.0/v2.0
- ✓ flake.nix includes home-manager and impermanence inputs with nixpkgs.follows — v1.0/v2.0

**v1.0 — Options API:**
- ✓ nerv.hostname, nerv.locale.{timeZone,keyMap,defaultLocale} — v1.0/v2.0
- ✓ nerv.primaryUser with auto group membership (wheel + networkmanager) — v1.0/v2.0
- ✓ nerv.hardware.cpu enum (amd/intel/other) for microcode — v1.0/v2.0
- ✓ nerv.hardware.gpu enum (amd/nvidia/intel/none) for GPU drivers — v1.0/v2.0
- ✓ nerv.openssh.{allowUsers,passwordAuth,kbdInteractiveAuth,port} — v1.0/v2.0
- ✓ nerv.{audio,bluetooth,printing,secureboot}.enable (all default false) — v1.0/v2.0
- ✓ nerv.home.{enable,users} for Home Manager wiring — v1.0/v2.0

**v1.0 — Impermanence (base):**
- ✓ nerv.impermanence.{enable,persistPath,extraDirs} options — v1.0/v2.0
- ✓ /var/lib/sbctl auto-persisted when both impermanence.enable and secureboot.enable — v1.0/v2.0
- ✓ nerv.impermanence.users.<name> for per-user persistent directories — v1.0/v2.0

**v1.0 — Documentation:**
- ✓ Section-header comments on all .nix files in modules/ and hosts/ — v1.0/v2.0
- ✓ Inline comments on non-obvious configuration lines — v1.0/v2.0
- ✓ disko-configuration.nix prominent WARNING block with placeholder values — v1.0/v2.0
- ✓ NIXLUKS label cross-referenced between disko.nix and secureboot.nix — v2.0 (boot.nix no longer declares LUKS)

**v2.0 — Disk Layout:**
- ✓ nerv.disko.layout = "btrfs" → GPT/LUKS/BTRFS with @, @root-blank, @home, @nix, @persist, @log — v2.0
- ✓ nerv.disko.layout = "lvm" → GPT/LUKS/LVM with swap + store + persist LVs — v2.0
- ✓ BTRFS subvolumes use compress=zstd:3, noatime, space_cache=v2; no swap in BTRFS branch — v2.0

**v2.0 — Boot / Rollback:**
- ✓ layout=btrfs → initrd includes btrfs-progs (supportedFilesystems + storePaths) — v2.0
- ✓ layout=btrfs → rollback service resets @ from @root-blank on every boot — v2.0
- ✓ LVM initrd services (lvm.enable, dm-snapshot) only active for layout=lvm — v2.0

**v2.0 — Persistence (BTRFS mode):**
- ✓ nerv.impermanence.mode = "btrfs" → environment.persistence."/persist" without tmpfs / — v2.0
- ✓ /persist has neededForBoot = true when mode = "btrfs" — v2.0

**v2.0 — Profiles & Documentation:**
- ✓ hostProfile: nerv.disko.layout = "btrfs" + nerv.impermanence.mode = "btrfs" — v2.0
- ✓ serverProfile: nerv.disko.layout = "lvm" (vmProfile removed) — v2.0
- ✓ Section-header comments on disko.nix, boot.nix, impermanence.nix with # Profiles cross-reference — v2.0
- ✓ README install procedure documents post-disko @root-blank snapshot step — v2.0

## Current Milestone: v3.0 Polish & UX

**Goal:** Add zram swap support for the BTRFS host profile and a minimal starship shell prompt.

**Target features:**
- zram swap (`nerv.swap.zram.enable` + size option) — BTRFS-safe in-memory compressed swap
- Starship prompt integrated into `nerv.zsh` — minimal two-line, subtle color, username + `$`

### Active (v3.0)

- [ ] nerv.swap.zram.enable — zram compressed swap (default: false)
- [ ] nerv.swap.zram.size — zram device size in MB (default: half RAM)
- [ ] Starship prompt in nerv.zsh — minimal two-line, subtle cyan username + white `$`

### Deferred (v4.0 candidates)

- [ ] nerv.disko.tmpfsSize — configurable tmpfs size for server profile (currently hardcoded 2G)
- [ ] @log subvolume on/off toggle (nerv.disko.logSubvolume.enable or similar)
- [ ] nerv.nix.autoUpdate — auto-upgrade toggle (disabled by default)
- [ ] nerv.kernel.package — override kernel package (currently hardcoded to zen)
- [ ] nerv.nix.gcInterval — GC frequency option

### Out of Scope

- Full home impermanence ($HOME on tmpfs) — too opinionated for a general base; users can add this themselves
- DE/WM/DM configuration — belongs in the user's host flake, not the base
- Home Manager dotfiles — skeleton only; actual dotfiles are user responsibility
- Multi-host examples/templates — out of scope; structure is stable, users fork hosts/configuration.nix
- BTRFS RAID — multi-disk assumption breaks single-disk disko layout
- Automated LVM→BTRFS migration — too risky to automate; backup/restore is user responsibility
- Snapper integration — orthogonal concern; users add if needed

## Context

**v2.0 shipped 2026-03-12.** 13 phases, 35 plans, 1,530 LOC (Nix), 4 days of development.

**Architecture:** Single-repo under `/etc/nerv` (or any path). Library modules in `modules/system/` and `modules/services/`; host machine identity in `hosts/configuration.nix`. Two first-class flake outputs: `nixosConfigurations.host` and `nixosConfigurations.server`.

**Deployed layout:** `nixos-rebuild switch --flake /etc/nerv#host` (desktop) or `#server`. `hosts/configuration.nix` is the only file operators edit per machine.

**Home Manager split:** `home/default.nix` wires HM as a NixOS module only. User dotfiles live in a separate user-owned repo under `$HOME`.

**Key reference implementations:** nix-mineral hardening baseline, xeiaso paranoid NixOS patterns, NixOS wiki patterns for SSH, PipeWire, Bluetooth, fail2ban.

## Constraints

- **Tech stack**: Pure NixOS flakes, no non-Nix tooling
- **Compatibility**: Must remain valid for NixOS 25.11 (current stateVersion)
- **Override mechanism**: NixOS module options where practical, lib.mkForce as fallback for edge cases
- **Scope**: System-level config only in modules/; Home Manager in home/ skeleton form

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Nested modules/system/ + modules/services/ | Mirrors /etc/nerv vision, clear separation of kernel/hardware vs daemon concerns | ✓ Good — clean module boundaries throughout |
| NixOS module options as primary override API | Idiomatic, type-checked, self-documenting; lib.mkForce as escape hatch | ✓ Good — all options typed, documented |
| Include Home Manager skeleton in v1 | Users need a place to hook HM; skeleton costs little and avoids structural rework later | ✓ Good — low cost, high future value |
| Section-header + inline comment style | File headers document purpose and override points; inline comments explain non-obvious lines only | ✓ Good — established documentation convention |
| Single-repo under /etc/nerv — hosts/ subdir replaces /etc/nixos | path:.. fails in pure eval when /etc/nerv is a nix store symlink; root flake with self references avoids cross-flake path issues entirely | ✓ Good — no path issues encountered |
| Home Manager user dotfiles in $HOME, not in this repo | System-level wiring (NixOS module) belongs here; user-specific packages/dotfiles belong in a user-owned repo under $HOME — different ownership, different change rate | ✓ Good — separation maintained |
| All layout-conditional initrd config lives in disko.nix (not boot.nix) | Co-locates disk layout decision with the initrd config that depends on it; prevents LVM initrd hang on BTRFS hosts | ✓ Good — prevents real boot failure scenario |
| nerv.disko.layout enum with isBtrfs/isLvm let-bindings in same file | Single source of truth; no cross-module option dependency for initrd guards | ✓ Good — clean conditional wiring |
| @root-blank snapshot is a manual post-disko step | Cannot be automated in disko declarative config; documented in README and module header | ✓ Good — install procedure is clear |
| /var/lib as single impermanence entry (vs /var/lib/nixos + /var/lib/systemd) | Superset covers all service state without an explicit list requiring maintenance | ✓ Good — functional, lower maintenance |
| vmProfile removed entirely in v2.0 | CONTEXT.md locked decision pre-Phase-12; vm profile added no unique value over host profile | ✓ Good — simpler flake outputs (host + server only) |
| preLVM omitted from luks.devices.cryptroot | Silently ignored by systemd stage 1 (boot.initrd.systemd.enable = true); documented in code and plan | ✓ Good — avoids misleading config |

---
*Last updated: 2026-03-12 after v3.0 milestone start*
