# Roadmap: nerv.nixos

## Overview

This roadmap transforms a working but flat NixOS module collection into a properly structured, composable library. The refactor proceeds in dependency order: flake inputs and directory skeleton first (everything else depends on it), then lower-risk service modules to validate the options pattern, then non-boot system modules, then the highest-risk boot-chain files, then the Home Manager skeleton, and finally a cross-cutting documentation sweep. Every phase delivers a coherent, independently verifiable capability. The existing system continues to build and deploy throughout.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Flake Foundation** - Update flake.nix inputs, create directory skeleton, and wire nixosModules exports (completed 2026-03-06)
- [x] **Phase 2: Services Reorganization** - Migrate service modules to modules/services/ with options.nerv.* API (completed 2026-03-06)
- [x] **Phase 3: System Modules (non-boot)** - Migrate identity, hardware, and non-boot system modules to modules/system/ (completed 2026-03-07)
- [x] **Phase 4: Boot Extraction** - Extract boot config, add impermanence module, complete secureboot wiring (completed 2026-03-07)
- [ ] **Phase 5: Home Manager Skeleton** - Wire home-manager NixOS module and expose nerv.home.* options
- [x] **Phase 6: Documentation Sweep** - Apply section-header style and disko warning to all files (completed 2026-03-07)
- [x] **Phase 7: Flake Hardening, Disko Wiring, and Nyquist Validation** - Fix unused impermanence input, add explicit option declarations, wire disko as flake input, complete Nyquist validation for all phases (completed 2026-03-08)
- [ ] **Phase 8: NERV.nixos Release & Multi-Profile Migration** - Delete dead flat modules, add full impermanence for server, define host/server/vm profiles in flake.nix, migrate to NERV.nixos repo, reset test repo to baseline

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
- [ ] 01-02-PLAN.md — Rename base/ → hosts/nixos-base/, copy hardware-configuration.nix into repo, verify full build

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
- [ ] 02-01-PLAN.md — Create modules/services/openssh.nix with multi-option nerv.openssh.* API
- [ ] 02-02-PLAN.md — Create modules/services/pipewire.nix, bluetooth.nix, printing.nix (enable-only modules)
- [ ] 02-03-PLAN.md — Create zsh.nix, wire services/default.nix, update configuration.nix, verify build

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
- [ ] 03-01-PLAN.md — Create modules/system/identity.nix with nerv.hostname, nerv.locale.*, and nerv.primaryUser options
- [ ] 03-02-PLAN.md — Create modules/system/hardware.nix (cpu+gpu enums) and migrate kernel.nix (remove IOMMU lines)
- [ ] 03-03-PLAN.md — Migrate security.nix and nix.nix, wire system/default.nix aggregator, update configuration.nix, verify build

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
- [ ] 04-01-PLAN.md — Create modules/system/boot.nix (opaque) and add NIXLUKS cross-reference comment to disko-configuration.nix
- [ ] 04-02-PLAN.md — Create modules/system/impermanence.nix with nerv.impermanence.* options and sbctl safety assertion
- [ ] 04-03-PLAN.md — Migrate secureboot.nix with enable guard, wire all three into default.nix, remove boot block from configuration.nix, verify build

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
- [ ] 05-01-PLAN.md — Wire home-manager.nixosModules.home-manager in flake.nix, implement nerv.home.* module in home/default.nix, enable in configuration.nix, verify build

### Phase 6: Documentation Sweep
**Goal**: Every module and base file carries a section-header comment block; disko has a prominent placeholder warning; LUKS labels are cross-referenced
**Depends on**: Phase 5
**Requirements**: DOCS-01, DOCS-02, DOCS-03, DOCS-04
**Success Criteria** (what must be TRUE):
  1. Every `.nix` file in `modules/` and `hosts/nixos-base/` opens with a section-header comment stating its purpose, defaults, and override entry points
  2. Non-obvious configuration lines throughout all modules carry an inline `#` comment explaining their purpose or security rationale
  3. `disko-configuration.nix` has a prominent warning block at the top listing all placeholder values that must be replaced before use (`/dev/DISK`, `SIZE_RAM * 2`)
  4. The LUKS label string is present in both `disko-configuration.nix` and `boot.nix` with a comment in each file explicitly cross-referencing the other file
**Plans**: 3 plans

Plans:
- [ ] 06-01-PLAN.md — Add section-header blocks to all five modules/services/ module files (openssh, pipewire, bluetooth, printing, zsh); complete openssh.nix inline comments
- [ ] 06-02-PLAN.md — Add structured headers to the three aggregator default.nix files (services, system, root modules)
- [ ] 06-03-PLAN.md — Add WARNING+LUKS header to disko-configuration.nix; add host-role header to configuration.nix; add placeholder header to hardware-configuration.nix

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
- [ ] 07-01-PLAN.md — Fix impermanence flake input and add explicit option declarations to configuration.nix
- [ ] 07-02-PLAN.md — Wire disko as flake input and import disko-configuration.nix into nixosConfigurations
- [ ] 07-03-PLAN.md — Complete Nyquist validation for phases 1–3
- [ ] 07-04-PLAN.md — Complete Nyquist validation for phases 4–6

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

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8
Note: Phase 5 depends only on Phase 1 (not Phase 4); it may be executed after Phase 1 if desired, but standard order places it after Phase 4 to benefit from the stable options pattern.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Flake Foundation | 2/2 | Complete   | 2026-03-06 |
| 2. Services Reorganization | 3/3 | Complete   | 2026-03-06 |
| 3. System Modules (non-boot) | 3/3 | Complete   | 2026-03-07 |
| 4. Boot Extraction | 2/3 | Complete    | 2026-03-07 |
| 5. Home Manager Skeleton | 0/1 | Not started | - |
| 6. Documentation Sweep | 3/3 | Complete   | 2026-03-07 |
| 7. Flake Hardening, Disko Wiring, and Nyquist Validation | 4/4 | Complete   | 2026-03-08 |
| 8. NERV.nixos Release & Multi-Profile Migration | 4/4 | Complete   | 2026-03-08 |
