# Requirements: nerv.nixos

**Defined:** 2026-03-06
**Core Value:** A user declares only their machine-specific parameters and gets a secure, well-documented NixOS system out of the box.

## v1 Requirements

### Structure

- [x] **STRUCT-01**: Repository is reorganized into `modules/system/` and `modules/services/` subdirectories with `default.nix` aggregators in each
- [x] **STRUCT-02**: Boot/LUKS/initrd configuration is extracted from `base/configuration.nix` into a dedicated `modules/system/boot.nix`
- [x] **STRUCT-03**: `home/default.nix` skeleton exists with Home Manager NixOS module wired in and `stateVersion` inherited from system
- [x] **STRUCT-04**: Root `flake.nix` exports `nixosModules.default`, `nixosModules.system`, `nixosModules.services`, and `nixosModules.home` for external host flake consumption
- [x] **STRUCT-05**: `flake.nix` includes `home-manager` and `impermanence` as inputs with `inputs.nixpkgs.follows = "nixpkgs"`

### Options API

- [x] **OPT-01**: User can set `nerv.hostname`, `nerv.locale.timeZone`, `nerv.locale.keyMap`, `nerv.locale.defaultLocale` to configure machine identity without editing core modules
- [x] **OPT-02**: User can set `nerv.primaryUser` to declare the primary system user, wiring group membership and HM user config
- [x] **OPT-03**: User can set `nerv.hardware.cpu` (enum: `amd`/`intel`/`other`) to enable correct microcode updates and CPU-specific kernel params
- [x] **OPT-04**: User can set `nerv.hardware.gpu` (enum: `amd`/`nvidia`/`intel`/`none`) to enable appropriate GPU drivers
- [x] **OPT-05**: User can set `nerv.openssh.allowUsers` (list of strings, default empty = all) to restrict SSH access without risking a full lockout
- [x] **OPT-06**: User can set `nerv.openssh.passwordAuth` and `nerv.openssh.kbdInteractiveAuth` (both default `false`) to adjust SSH auth policy
- [x] **OPT-07**: User can set `nerv.openssh.port` (default `22`) to change the SSH listener port
- [x] **OPT-08**: User can enable/disable audio, bluetooth, printing, and secureboot independently via `nerv.audio.enable`, `nerv.bluetooth.enable`, `nerv.printing.enable`, `nerv.secureboot.enable` (all default `false`)
- [x] **OPT-09**: User can set `nerv.home.enable` and `nerv.home.users` to activate Home Manager for specific users

### Impermanence

- [x] **IMPL-01**: `modules/system/impermanence.nix` exists with `nerv.impermanence.enable`, `nerv.impermanence.persistPath` (default `/persist`), and `nerv.impermanence.extraDirs` options
- [x] **IMPL-02**: When `nerv.impermanence.enable = true` and `nerv.secureboot.enable = true`, `/var/lib/sbctl` is automatically persisted to prevent TPM2 re-enrollment on reboot
- [x] **IMPL-03**: User can declare per-user persistent directories via `nerv.impermanence.users.<name>` (list of strings mapping to `~/` subdirs)

### Documentation

- [x] **DOCS-01**: Every `.nix` file in `modules/` and `base/` has a section-header comment block stating its purpose, defaults, and override entry points
- [x] **DOCS-02**: Non-obvious configuration lines throughout all modules have inline `#` comments explaining their purpose or security rationale
- [x] **DOCS-03**: `disko-configuration.nix` has a prominent warning comment block at the top listing all placeholder values that must be replaced before use (`/dev/DISK`, `SIZE_RAM * 2`)
- [x] **DOCS-04**: LUKS disk labels are cross-referenced between `disko-configuration.nix` and `base/configuration.nix` (or `modules/system/boot.nix`) with a comment noting they must stay in sync

## v2 Requirements

### Options API

- **OPT-V2-01**: `nerv.nix.autoUpdate` — auto-upgrade toggle (disabled by default)
- **OPT-V2-02**: `nerv.kernel.package` — override kernel package (currently hardcoded to latest)
- **OPT-V2-03**: `nerv.nix.gcInterval` — GC frequency option

### Structure

- **STRUCT-V2-01**: Per-target flake profiles (desktop, server, VM) built from composed module sets
- **STRUCT-V2-02**: Host-specific example configuration templates

## Out of Scope

| Feature | Reason |
|---------|--------|
| DE/WM/DM configuration | Belongs in host flake, not base modules |
| Full home impermanence ($HOME on tmpfs) | Too opinionated for a general base |
| Home Manager dotfiles | Skeleton only; actual dotfiles are user responsibility |
| `PasswordAuthentication = true` as an easy option | Security regression — `lib.mkForce` escape hatch documented instead |
| Per-sysctl boolean toggles | Too granular; defeats hardening coherence |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| STRUCT-01 | Phase 1 | Complete |
| STRUCT-02 | Phase 4 | Complete |
| STRUCT-03 | Phase 5 | Complete |
| STRUCT-04 | Phase 1 | Complete |
| STRUCT-05 | Phase 1 | Complete |
| OPT-01 | Phase 3 | Complete |
| OPT-02 | Phase 3 | Complete |
| OPT-03 | Phase 3 | Complete |
| OPT-04 | Phase 3 | Complete |
| OPT-05 | Phase 2 | Complete |
| OPT-06 | Phase 2 | Complete |
| OPT-07 | Phase 2 | Complete |
| OPT-08 | Phase 2 | Complete |
| OPT-09 | Phase 5 | Complete |
| IMPL-01 | Phase 4 | Complete |
| IMPL-02 | Phase 4 | Complete |
| IMPL-03 | Phase 4 | Complete |
| DOCS-01 | Phase 6 | Complete |
| DOCS-02 | Phase 6 | Complete |
| DOCS-03 | Phase 6 | Complete |
| DOCS-04 | Phase 6 | Complete |

**Coverage:**
- v1 requirements: 21 total
- Mapped to phases: 21
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-06*
*Last updated: 2026-03-06 after roadmap creation (corrected count from 18 to 21; updated phase assignments to match ROADMAP.md)*
