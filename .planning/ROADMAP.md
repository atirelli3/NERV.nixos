# Roadmap: nerv.nixos

## Overview

This roadmap transforms a working but flat NixOS module collection into a properly structured, composable library. The refactor proceeds in dependency order: flake inputs and directory skeleton first (everything else depends on it), then lower-risk service modules to validate the options pattern, then non-boot system modules, then the highest-risk boot-chain files, then the Home Manager skeleton, and finally a cross-cutting documentation sweep. Every phase delivers a coherent, independently verifiable capability. The existing system continues to build and deploy throughout.

v2.0 extends the foundation with stateless disk layouts: BTRFS subvolumes + initrd rollback for desktop, LVM explicit declaration for server/vm. The existing module structure is extended in-place — no new flake inputs required.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

**v1.0 Phases (Complete):**
- [x] **Phase 1: Flake Foundation** - Update flake.nix inputs, create directory skeleton, and wire nixosModules exports (completed 2026-03-06)
- [x] **Phase 2: Services Reorganization** - Migrate service modules to modules/services/ with options.nerv.* API (completed 2026-03-06)
- [x] **Phase 3: System Modules (non-boot)** - Migrate identity, hardware, and non-boot system modules to modules/system/ (completed 2026-03-07)
- [x] **Phase 4: Boot Extraction** - Extract boot config, add impermanence module, complete secureboot wiring (completed 2026-03-07)
- [x] **Phase 5: Home Manager Skeleton** - Wire home-manager NixOS module and expose nerv.home.* options (completed 2026-03-08)
- [x] **Phase 6: Documentation Sweep** - Apply section-header style and disko warning to all files (completed 2026-03-07)
- [x] **Phase 7: Flake Hardening, Disko Wiring, and Nyquist Validation** - Fix unused impermanence input, add explicit option declarations, wire disko as flake input, complete Nyquist validation for all phases (completed 2026-03-08)
- [x] **Phase 8: NERV.nixos Release & Multi-Profile Migration** - Delete dead flat modules, add full impermanence for server, define host/server/vm profiles in flake.nix, migrate to NERV.nixos repo, reset test repo to baseline (completed 2026-03-08)

**v2.0 Phases (Current Milestone):**
- [x] **Phase 9: BTRFS Disko Layout** - Add nerv.disko.layout option to disko.nix with BTRFS subvolume branch and explicit LVM option (completed 2026-03-09)
- [x] **Phase 10: initrd BTRFS Rollback Service** - Wire btrfs-progs into initrd and add systemd rollback service that resets root on every boot (completed 2026-03-10)
- [ ] **Phase 11: Impermanence BTRFS Mode** - Add nerv.impermanence.mode = "btrfs" path with explicit persistence rules and neededForBoot on /persist
- [ ] **Phase 12: Profile Wiring and Documentation** - Wire layout/mode options into all profiles, update module section-headers, document install procedure

## Phase Details

### Phase 1: Flake Foundation
**Goal**: The flake.nix correctly declares all required inputs and exports named nixosModules; the target directory structure exists and the system still evaluates
**Depends on**: Nothing (first phase)
**Requirements**: STRUCT-01, STRUCT-04, STRUCT-05
**Success Criteria** (what must be TRUE):
  1. `nix flake show` lists `nixosModules.default`, `nixosModules.system`, `nixosModules.services`, and `nixosModules.home`
  2. `home-manager` and `impermanence` inputs appear in `flake.nix` with `inputs.nixpkgs.follows = "nixpkgs"` on both
  3. `modules/system/`, `modules/services/`, and `home/` directories exist with stub `default.nix` aggregators
  4. `nixos-rebuild build --flake /etc/nerv#nixos-base` succeeds with no evaluation errors
  5. Host machine config lives in `hosts/nixos-base/` (not `base/`) with `hardware-configuration.nix` tracked in repo
**Plans**: 2 plans

Plans:
- [x] 01-01-PLAN.md — Create root flake.nix, stub aggregators, and wire nixosConfigurations using self references
- [x] 01-02-PLAN.md — Rename base/ → hosts/nixos-base/, copy hardware-configuration.nix into repo, verify full build

### Phase 2: Services Reorganization
**Goal**: All service modules live in modules/services/ with typed options.nerv.* blocks; service behavior is controlled exclusively through the nerv.* API
**Depends on**: Phase 1
**Requirements**: OPT-05, OPT-06, OPT-07, OPT-08
**Success Criteria** (what must be TRUE):
  1. `openssh.nix`, `pipewire.nix`, `bluetooth.nix`, `printing.nix`, and `zsh.nix` are in `modules/services/` and listed in `modules/services/default.nix`
  2. A host flake can set `nerv.openssh.allowUsers`, `nerv.openssh.passwordAuth`, `nerv.openssh.kbdInteractiveAuth`, and `nerv.openssh.port` without editing module files
  3. A host flake can enable or disable audio, bluetooth, printing, and secureboot via `nerv.audio.enable`, `nerv.bluetooth.enable`, `nerv.printing.enable`, `nerv.secureboot.enable` (all default to false)
  4. `nixos-rebuild build --flake .#nixos-base` succeeds with no evaluation errors after migration
**Plans**: 3 plans

Plans:
- [x] 02-01-PLAN.md — Create modules/services/openssh.nix with multi-option nerv.openssh.* API
- [x] 02-02-PLAN.md — Create modules/services/pipewire.nix, bluetooth.nix, printing.nix (enable-only modules)
- [x] 02-03-PLAN.md — Create zsh.nix, wire services/default.nix, update configuration.nix, verify build

### Phase 3: System Modules (non-boot)
**Goal**: Identity, locale, primary user, and hardware options are exposed via the nerv.* API; hardware.nix, kernel.nix, security.nix, and nix.nix are in modules/system/
**Depends on**: Phase 2
**Requirements**: OPT-01, OPT-02, OPT-03, OPT-04
**Success Criteria** (what must be TRUE):
  1. A host flake can declare `nerv.hostname`, `nerv.locale.timeZone`, `nerv.locale.keyMap`, and `nerv.locale.defaultLocale` without editing any module file
  2. A host flake can declare `nerv.primaryUser` and have group membership wired automatically
  3. Setting `nerv.hardware.cpu = "amd"` (or `"intel"`) enables the correct microcode package and any CPU-specific kernel params; setting `"other"` applies neither
  4. Setting `nerv.hardware.gpu = "amd"`, `"nvidia"`, `"intel"`, or `"none"` enables or disables the appropriate GPU drivers
  5. `nixos-rebuild build --flake .#nixos-base` succeeds with no evaluation errors after migration
**Plans**: 3 plans

Plans:
- [x] 03-01-PLAN.md — Create modules/system/identity.nix with nerv.hostname, nerv.locale.*, and nerv.primaryUser options
- [x] 03-02-PLAN.md — Create modules/system/hardware.nix (cpu+gpu enums) and migrate kernel.nix (remove IOMMU lines)
- [x] 03-03-PLAN.md — Migrate security.nix and nix.nix, wire system/default.nix aggregator, update configuration.nix, verify build

### Phase 4: Boot Extraction
**Goal**: Boot configuration is extracted from hosts/nixos-base/configuration.nix; impermanence.nix provides safe tmpfs persistence including sbctl; secureboot.nix is wired last in the system aggregator
**Depends on**: Phase 3
**Requirements**: STRUCT-02, IMPL-01, IMPL-02, IMPL-03
**Success Criteria** (what must be TRUE):
  1. `modules/system/boot.nix` exists and contains the LUKS/initrd/bootloader config previously in `hosts/nixos-base/configuration.nix`; a cross-reference comment links the LUKS label to `disko-configuration.nix`
  2. Setting `nerv.impermanence.enable = true` activates tmpfs persistence using `nerv.impermanence.persistPath` (default `/persist`) and any paths in `nerv.impermanence.extraDirs`
  3. When both `nerv.impermanence.enable = true` and `nerv.secureboot.enable = true`, `/var/lib/sbctl` is automatically persisted without any additional user configuration
  4. A user can declare per-user persistent home subdirectories via `nerv.impermanence.users.<name>` and have them bound to the persist volume
  5. `nixos-rebuild build --flake .#nixos-base` succeeds with no evaluation errors after boot extraction
**Plans**: 3 plans

Plans:
- [x] 04-01-PLAN.md — Create modules/system/boot.nix (opaque) and add NIXLUKS cross-reference comment to disko-configuration.nix
- [x] 04-02-PLAN.md — Create modules/system/impermanence.nix with nerv.impermanence.* options and sbctl safety assertion
- [x] 04-03-PLAN.md — Migrate secureboot.nix with enable guard, wire all three into default.nix, remove boot block from configuration.nix, verify build

### Phase 5: Home Manager Skeleton
**Goal**: Home Manager is wired as a NixOS module; setting `nerv.home.users = [ "demon" ]` automatically imports `/home/<name>/home.nix` for each user — no per-user config in the system repo
**Depends on**: Phase 1
**Requirements**: STRUCT-03, OPT-09
**Note**: Each user owns and manages their own `~/home.nix` (WM/DM, packages, program configs). nerv only provides the wiring convention. Requires `--impure` since user home paths are outside the flake boundary.
**Success Criteria** (what must be TRUE):
  1. `home/default.nix` sets `useGlobalPkgs = true`, `useUserPackages = true`, and inherits `stateVersion` from the system
  2. Setting `nerv.home.users = [ "demon" ]` causes HM to import `/home/demon/home.nix` automatically — no additional config needed in the system repo
  3. Adding a second user to `nerv.home.users` imports their `~/home.nix` without any other changes
  4. `nixos-rebuild switch --flake /etc/nerv#nixos-base --impure` succeeds with no evaluation errors after HM wiring
**Plans**: 1 plan

Plans:
- [x] 05-01-PLAN.md — Wire home-manager.nixosModules.home-manager in flake.nix, implement nerv.home.* module in home/default.nix, enable in configuration.nix, verify build

### Phase 6: Documentation Sweep
**Goal**: Every module and base file carries a section-header comment block; disko has a prominent placeholder warning; LUKS labels are cross-referenced
**Depends on**: Phase 5
**Requirements**: DOCS-01, DOCS-02, DOCS-03, DOCS-04
**Success Criteria** (what must be TRUE):
  1. Every `.nix` file in `modules/` and `hosts/nixos-base/` opens with a section-header comment stating its purpose, defaults, and override entry points
  2. Non-obvious configuration lines throughout all modules carry an inline `#` comment explaining their purpose or security rationale
  3. `disko-configuration.nix` has a prominent warning comment block at the top listing all placeholder values that must be replaced before use (`/dev/DISK`, `SIZE_RAM * 2`)
  4. The LUKS label string is present in both `disko-configuration.nix` and `boot.nix` with a comment in each file explicitly cross-referencing the other file
**Plans**: 3 plans

Plans:
- [x] 06-01-PLAN.md — Add section-header blocks to all five modules/services/ module files (openssh, pipewire, bluetooth, printing, zsh); complete openssh.nix inline comments
- [x] 06-02-PLAN.md — Add structured headers to the three aggregator default.nix files (services, system, root modules)
- [x] 06-03-PLAN.md — Add WARNING+LUKS header to disko-configuration.nix; add host-role header to configuration.nix; add placeholder header to hardware-configuration.nix

### Phase 7: Flake Hardening, Disko Wiring, and Nyquist Validation
**Goal**: Remove or document the unused `impermanence` flake input; make secureboot/impermanence intent explicit in configuration.nix; wire `disko` as a proper flake input for declarative disk management; complete Nyquist-compliant VALIDATION.md for all 6 existing phases
**Depends on**: Phase 6
**Requirements**: None (tech debt closure — no new v1.0 requirements)
**Gap Closure:** Closes tech debt items B, C, D, E from v1.0 audit
**Success Criteria** (what must be TRUE):
  1. `flake.nix` either removes the `impermanence` input entirely or has a clear comment explaining why it is present but the upstream nixos module is intentionally not used
  2. `hosts/nixos-base/configuration.nix` explicitly declares `nerv.impermanence.enable = false` and `nerv.secureboot.enable = false`, making the activation path visible to operators
  3. `disko` is a declared flake input with `inputs.nixpkgs.follows = "nixpkgs"`; `disko.nixosModules.disko` is in the `nixosConfigurations.nixos-base` modules list; `./hosts/nixos-base/disko-configuration.nix` is imported in the nixosConfigurations entry
  4. All 6 VALIDATION.md files reach `nyquist_compliant: true` status

Plans:
- [x] 07-01-PLAN.md — Fix impermanence flake input and add explicit option declarations to configuration.nix
- [x] 07-02-PLAN.md — Wire disko as flake input and import disko-configuration.nix into nixosConfigurations
- [x] 07-03-PLAN.md — Complete Nyquist validation for phases 1–3
- [x] 07-04-PLAN.md — Complete Nyquist validation for phases 4–6

### Phase 8: NERV.nixos Release & Multi-Profile Migration
**Goal**: Delete 9 dead flat modules, extend impermanence.nix for full server impermanence, define host/server/vm profiles inline in flake.nix, clone NERV.nixos repo and migrate all refined work, reset test-nerv.nixos to commit cab4126e
**Depends on**: Phase 7
**Requirements**: None (tech debt closure + graduation — no new v1.0 requirements)
**Gap Closure:** Closes tech debt item A (dead modules). Adds IMPL-04 (full impermanence), IMPL-05 (multi-profile), IMPL-06 (repo migration)
**Success Criteria** (what must be TRUE):
  1. The following files no longer exist in the NERV.nixos repo: `modules/openssh.nix`, `modules/pipewire.nix`, `modules/bluetooth.nix`, `modules/printing.nix`, `modules/zsh.nix`, `modules/kernel.nix`, `modules/security.nix`, `modules/nix.nix`, `modules/hardware.nix`
  2. `modules/system/impermanence.nix` supports both minimal mode (tmpfs /tmp, /var/tmp only) and full mode (/ as tmpfs, state on /persist using impermanence module) via `nerv.impermanence.mode = "minimal" | "full"`
  3. `flake.nix` in NERV.nixos defines three inline module profiles: `hostProfile` (openssh, audio, bluetooth, printing, secureboot=false, minimal impermanence), `serverProfile` (full impermanence, openssh only), `vmProfile` (composable from host)
  4. `flake.nix` defines `nixosConfigurations.host`, `nixosConfigurations.server`, `nixosConfigurations.vm` using self.nixosModules.default + respective profile + `./hosts/configuration.nix`
  5. `hosts/configuration.nix` covers only machine identity: hostname, primaryUser, hardware.cpu/gpu, locale, disk device, stateVersion
  6. NERV.nixos repo at `git@github.com:atirelli3/NERV.nixos.git` has the complete refined structure: `/home`, `/hosts`, `/modules`, `flake.nix`, `.git`
  7. test-nerv.nixos HEAD is at commit `cab4126e8664a808eef482154a8500106ae22246`

**Plans:** 4/4 plans executed

Plans:
- [x] 08-01-PLAN.md — Delete 9 dead flat modules from modules/ root, verify nix flake check
- [x] 08-02-PLAN.md — Add impermanence input to flake.nix, extend impermanence.nix with mode option, write fresh server disko-configuration.nix
- [x] 08-03-PLAN.md — Rewrite flake.nix with inline host/server/vm profiles and nixosConfigurations, create identity-only hosts/configuration.nix
- [x] 08-04-PLAN.md — Clone NERV.nixos, copy refined structure + .planning/, push, then reset test-nerv.nixos to cab4126e

---

## v2.0 Phase Details

### Phase 9: BTRFS Disko Layout
**Goal**: Users can select a disk layout type at configuration time; setting nerv.disko.layout = "btrfs" produces a GPT/LUKS/BTRFS disk with all required subvolumes; setting "lvm" preserves the existing LVM layout explicitly
**Depends on**: Phase 8
**Requirements**: DISKO-01, DISKO-02, DISKO-03
**Success Criteria** (what must be TRUE):
  1. `modules/system/disko.nix` exports a `nerv.disko.layout` option accepting `"btrfs"` or `"lvm"`; setting either value produces no evaluation errors
  2. Setting `nerv.disko.layout = "btrfs"` causes disko to declare a GPT disk with ESP + LUKS partition containing a BTRFS filesystem with subvolumes `@`, `@root-blank`, `@home`, `@nix`, `@persist`, and `@log`
  3. BTRFS subvolumes are mounted with `compress=zstd:3`, `noatime`, and `space_cache=v2`; no swap LV or swap partition is declared in the BTRFS branch
  4. Setting `nerv.disko.layout = "lvm"` produces the existing GPT/LUKS/LVM disk layout (same behavior as before v2.0)
**Plans**: 2 plans

Plans:
- [ ] 09-01-PLAN.md — Rewrite modules/system/disko.nix with nerv.disko.layout enum, BTRFS branch (6 subvolumes), and LVM branch under lib.mkIf isLvm
- [ ] 09-02-PLAN.md — Update hosts/configuration.nix to new nerv.disko.layout + nerv.disko.lvm.* API, verify parse

### Phase 10: initrd BTRFS Rollback Service
**Goal**: When BTRFS layout is active, the initrd includes btrfs-progs and runs a systemd rollback service that deletes @ and re-snapshots @root-blank → @ before root is mounted, resetting the root filesystem on every boot; LVM initrd services are disabled for BTRFS to prevent initrd hang
**Depends on**: Phase 9
**Requirements**: BOOT-01, BOOT-02, BOOT-03
**Research flag**: Verify exact systemd device unit name for `/dev/mapper/cryptroot` in NixOS 25.11 (`dev-mapper-cryptroot.device` per convention — confirm with `systemctl list-units` on target)
**Success Criteria** (what must be TRUE):
  1. When `nerv.disko.layout = "btrfs"`, `boot.initrd.supportedFilesystems` contains `"btrfs"` and `boot.initrd.systemd.storePaths` includes `pkgs.btrfs-progs`
  2. A `boot.initrd.systemd.services.rollback` unit is declared that runs after `dev-mapper-cryptroot.device`, before `sysroot.mount`, executes `btrfs subvolume delete /btrfs_tmp/@` and `btrfs subvolume snapshot -r /btrfs_tmp/@root-blank /btrfs_tmp/@`, then unmounts the temporary btrfs mount
  3. After a reboot on a BTRFS-layout system, files written to `/` during the previous session are absent (root has been reset to @root-blank state)
  4. When `nerv.disko.layout = "lvm"`, LVM initrd services (`boot.initrd.services.lvm.enable`, `preLVM = true`, `dm-snapshot` module) remain active; when layout is `"btrfs"` they are disabled
**Plans**: 2 plans

Plans:
- [ ] 10-01-PLAN.md — Extend disko.nix with BTRFS initrd block, LVM initrd block, shared LUKS unlock; strip boot.nix to layout-agnostic only
- [x] 10-02-PLAN.md — Update section-header comments in disko.nix and boot.nix to reflect Phase 10 changes (completed 2026-03-10)

### Phase 11: Impermanence BTRFS Mode
**Goal**: Setting nerv.impermanence.mode = "btrfs" activates environment.persistence for the desktop profile without a tmpfs /; /persist (the @persist subvolume) is marked neededForBoot so bind-mounts are available before services start; /var/log is excluded from persistence (handled by @log subvolume)
**Depends on**: Phase 9
**Requirements**: PERSIST-01, PERSIST-02
**Research flag**: Verify whether disko v1.13.0 supports `neededForBoot` on subvolume mounts directly or requires a separate `fileSystems."..." = { neededForBoot = true; }` override in impermanence.nix
**Success Criteria** (what must be TRUE):
  1. Setting `nerv.impermanence.mode = "btrfs"` activates `environment.persistence."/persist"` with directories: `/var/lib/nixos`, `/var/lib/systemd`, `/etc/nixos`; and files: `/etc/machine-id`, `/etc/ssh/ssh_host_ed25519_key`, `/etc/ssh/ssh_host_ed25519_key.pub`, `/etc/ssh/ssh_host_rsa_key`, `/etc/ssh/ssh_host_rsa_key.pub`
  2. `/var/log` is absent from `environment.persistence."/persist".directories` in btrfs mode (it is persisted by the @log subvolume, not a bind-mount — a bind-mount would conflict)
  3. The `/persist` filesystem entry has `neededForBoot = true`, verifiable by `nixos-option fileSystems."/persist".neededForBoot` evaluating to `true`
**Plans**: 1 plan

Plans:
- [ ] 11-01-PLAN.md — Rewrite impermanence.nix: drop minimal mode, update enum to [btrfs, full], add btrfs lib.mkIf block with neededForBoot and environment.persistence

### Phase 12: Profile Wiring and Documentation
**Goal**: All three profiles in flake.nix explicitly declare their disk layout and impermanence mode; section-header comments on modified modules reflect new options; the install procedure documents the mandatory post-disko @root-blank snapshot step
**Depends on**: Phases 10, 11
**Requirements**: PROF-01, PROF-02, PROF-03, PROF-04
**Success Criteria** (what must be TRUE):
  1. `hostProfile` in `flake.nix` contains `nerv.disko.layout = "btrfs"` and `nerv.impermanence.mode = "btrfs"`; `nix eval .#nixosConfigurations.host.config.nerv.disko.layout` returns `"btrfs"`
  2. `serverProfile` and `vmProfile` in `flake.nix` each contain `nerv.disko.layout = "lvm"` explicitly; `nix eval` for server and vm layouts returns `"lvm"`
  3. Section-header comments on `disko.nix`, `boot.nix`, and `impermanence.nix` list the new options (`nerv.disko.layout`, rollback service, `nerv.impermanence.mode = "btrfs"`) in their Options/Defaults/Override sections
  4. The install procedure (inline comment block in `disko.nix` or README) documents: run disko, then `btrfs subvolume snapshot -r /mnt/@ /mnt/@root-blank`, then nixos-install — in that order
**Plans**: TBD

## Progress

**Execution Order:**
v1.0 phases: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 (complete)
v2.0 phases: 9 → 10 → 11 → 12
Note: Phase 10 and Phase 11 both depend on Phase 9 and may be executed in either order. Phase 12 requires both 10 and 11 complete.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Flake Foundation | 2/2 | Complete | 2026-03-06 |
| 2. Services Reorganization | 3/3 | Complete | 2026-03-06 |
| 3. System Modules (non-boot) | 3/3 | Complete | 2026-03-07 |
| 4. Boot Extraction | 3/3 | Complete | 2026-03-07 |
| 5. Home Manager Skeleton | 1/1 | Complete | 2026-03-08 |
| 6. Documentation Sweep | 3/3 | Complete | 2026-03-07 |
| 7. Flake Hardening, Disko Wiring, and Nyquist Validation | 4/4 | Complete | 2026-03-08 |
| 8. NERV.nixos Release & Multi-Profile Migration | 4/4 | Complete | 2026-03-08 |
| 9. BTRFS Disko Layout | 2/2 | Complete   | 2026-03-09 |
| 10. initrd BTRFS Rollback Service | 2/2 | Complete    | 2026-03-10 |
| 11. Impermanence BTRFS Mode | 0/1 | Not started | - |
| 12. Profile Wiring and Documentation | 0/TBD | Not started | - |
