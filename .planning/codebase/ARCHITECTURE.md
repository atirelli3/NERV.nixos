# Architecture

**Analysis Date:** 2026-03-10

## Pattern Overview

**Overall:** NixOS Flake Library — opinionated, profile-driven NixOS base configuration

**Key Characteristics:**
- All configuration is expressed as NixOS modules under the `nerv.*` option namespace
- Two deployment profiles (`hostProfile`, `serverProfile`) are defined in `flake.nix` as attribute sets and composed into `nixosConfigurations`
- Every module defaults to off (`enable = false` or no default) — hosts opt-in via profiles; no implicit side-effects
- Import order is significant in `modules/system/default.nix`: `secureboot.nix` must be last to apply `lib.mkForce false` on `systemd-boot` without priority conflicts
- Overrides use `lib.mkForce` at the host level — no patching of library modules directly

## Layers

**Flake Layer:**
- Purpose: Defines inputs, profiles, and `nixosConfigurations`. The single source of truth for which external inputs are pinned and how profiles compose modules.
- Location: `flake.nix`
- Contains: Input declarations (`nixpkgs`, `lanzaboote`, `home-manager`, `disko`, `impermanence`), `hostProfile` attrset, `serverProfile` attrset, `nixosModules` exports, `nixosConfigurations.host` and `nixosConfigurations.server`
- Depends on: All `modules/` subtrees, `home/`, `hosts/`
- Used by: `nixos-rebuild`, `disko`, CI

**Aggregator Layer:**
- Purpose: Collects module subtrees into named exports. No logic of its own — pure `imports` lists.
- Location: `modules/default.nix`, `modules/system/default.nix`, `modules/services/default.nix`
- Contains: `{ imports = [ ... ]; }` only
- Depends on: Individual module files
- Used by: `flake.nix` via `self.nixosModules.default`

**System Module Layer:**
- Purpose: OS-level concerns: disk layout, boot, kernel, hardware drivers, security hardening, identity, Nix daemon config, base packages, impermanence, and secure boot.
- Location: `modules/system/`
- Contains: `identity.nix`, `hardware.nix`, `kernel.nix`, `security.nix`, `nix.nix`, `packages.nix`, `boot.nix`, `impermanence.nix`, `disko.nix`, `secureboot.nix`
- Depends on: `nixpkgs`, `lanzaboote` (secureboot), `disko` (disk layout), `impermanence` (bind mounts)
- Used by: `modules/default.nix`

**Services Module Layer:**
- Purpose: Opt-in user-facing services. All disabled by default; enabled via `nerv.<service>.enable = true` in a profile or host config.
- Location: `modules/services/`
- Contains: `openssh.nix`, `pipewire.nix`, `bluetooth.nix`, `printing.nix`, `zsh.nix`
- Depends on: `nixpkgs`, inter-service soft coupling (`bluetooth.nix` uses `services.pipewire.wireplumber.extraConfig`)
- Used by: `modules/default.nix`

**Home Manager Layer:**
- Purpose: Wires `home-manager` as a NixOS module for each username listed in `nerv.home.users`. Does not own `~/home.nix` content — each user maintains their own.
- Location: `home/default.nix`
- Contains: `nerv.home.enable`, `nerv.home.users` option; generates `home-manager.users` attrset
- Depends on: `home-manager` flake input, `/home/<name>/home.nix` at runtime (outside flake boundary — requires `--impure`)
- Used by: `modules/default.nix`

**Host Layer:**
- Purpose: Machine-specific values only. Contains placeholders that must be filled before first boot.
- Location: `hosts/configuration.nix`, `hosts/hardware-configuration.nix`
- Contains: `nerv.hostname`, `nerv.primaryUser`, `nerv.hardware.*`, `nerv.locale.*`, `system.stateVersion`, `disko.devices.disk.main.device`, `nerv.disko.layout`, `nerv.disko.lvm.*`
- Depends on: `modules/` (all options declared there), `hosts/hardware-configuration.nix` (machine-generated)
- Used by: `flake.nix` `nixosConfigurations.host` and `nixosConfigurations.server`

## Data Flow

**Configuration Evaluation:**

1. `nixos-rebuild switch --flake /etc/nixos#host` is invoked
2. Nix evaluates `flake.nix` outputs, resolving `nixosConfigurations.host`
3. The module system merges: `lanzaboote`, `home-manager`, `impermanence`, `disko` external modules + `self.nixosModules.default` + `hostProfile` attrset + `hosts/configuration.nix`
4. `modules/default.nix` pulls in `modules/system` + `modules/services` + `home/`
5. `modules/system/default.nix` imports all system modules in order; option values from `hostProfile` + `hosts/configuration.nix` flow into each module's `config = lib.mkIf cfg.enable { ... }` block
6. The final merged NixOS config is realised as a system closure

**Boot Sequence (btrfs profile):**

1. systemd stage 1 runs the `rollback` service (`modules/system/disko.nix`)
2. The rollback service deletes `@`, snapshots `@root-blank` → `@`, giving a blank root
3. LUKS container is unlocked (via passphrase or TPM2 if secureboot enabled)
4. BTRFS subvolumes mount: `@` → `/`, `@home` → `/home`, `@nix` → `/nix`, `@persist` → `/persist`, `@log` → `/var/log`
5. `impermanence` bind mounts overlay `/persist` paths over `/var/lib`, `/etc/nixos`, `/etc/machine-id`, SSH host keys
6. Stage 2 systemd activates services

**Profile Selection:**

- `hostProfile` enables: `nerv.openssh`, `nerv.audio`, `nerv.bluetooth`, `nerv.printing`, `nerv.impermanence` (mode = `btrfs`), `nerv.zsh`, `nerv.home`; sets `nerv.disko.layout = "btrfs"`
- `serverProfile` enables: `nerv.openssh`, `nerv.impermanence` (mode = `full`), `nerv.zsh`; sets `nerv.disko.layout = "lvm"`

## Key Abstractions

**`nerv.*` Option Namespace:**
- Purpose: All library-provided options are scoped under `nerv.` to avoid collisions with upstream NixOS options. Every module declares its own `options.nerv.<name>` block.
- Examples: `modules/system/identity.nix`, `modules/system/disko.nix`, `modules/services/openssh.nix`
- Pattern: `options.nerv.<module> = { enable = lib.mkEnableOption "..."; ... };` followed by `config = lib.mkIf cfg.enable { ... };`

**Profiles (attrsets in `flake.nix`):**
- Purpose: Pre-configured bundles of `nerv.*` option assignments for common deployment types. Passed as a module directly to `nixosConfigurations`.
- Examples: `hostProfile`, `serverProfile` in `flake.nix` (lines 35–62)
- Pattern: Plain Nix attrset of `nerv.<option> = <value>` pairs — no module boilerplate required

**Conditional Disk Layout (`nerv.disko.layout`):**
- Purpose: A single `disko.nix` module supports two disk topologies (BTRFS subvolumes for desktop, LVM LVs for server) controlled by an enum option.
- Examples: `modules/system/disko.nix` — `lib.mkIf isBtrfs { ... }` and `lib.mkIf isLvm { ... }` branches
- Pattern: `lib.mkMerge [ (lib.mkIf condA { ... }) (lib.mkIf condB { ... }) shared ]`

**Impermanence Modes:**
- Purpose: Two strategies for ephemeral root — `btrfs` mode uses BTRFS rollback snapshot; `full` mode mounts `/` as tmpfs. Both use `environment.persistence` from the `impermanence` module for bind mounts from `/persist`.
- Examples: `modules/system/impermanence.nix` lines 105–177
- Pattern: `lib.mkIf (cfg.mode == "btrfs") { ... }` / `lib.mkIf (cfg.mode == "full") { ... }`

**`lib.mkForce` Escape Hatch:**
- Purpose: Every opaque module documents that host-level overrides use `lib.mkForce`. No module exposes every tunable as an option — only the meaningful dials.
- Examples: `modules/system/boot.nix`, `modules/system/security.nix`, `modules/system/nix.nix`
- Pattern: Documented in each file header: `Override: lib.mkForce at the host level.`

## Entry Points

**`flake.nix`:**
- Location: `flake.nix`
- Triggers: `nixos-rebuild`, `nix flake check`, `disko` disk formatting
- Responsibilities: Pins all inputs, defines profiles, exposes `nixosModules` and `nixosConfigurations`

**`hosts/configuration.nix`:**
- Location: `hosts/configuration.nix`
- Triggers: Included in every `nixosConfigurations.*` modules list
- Responsibilities: Declares machine identity (`nerv.hostname`, `nerv.primaryUser`, `nerv.hardware.*`, `nerv.locale.*`, `system.stateVersion`, `disko.devices.disk.main.device`, LVM sizes). All values are `PLACEHOLDER` until the operator fills them in.

**`hosts/hardware-configuration.nix`:**
- Location: `hosts/hardware-configuration.nix`
- Triggers: Imported by `hosts/configuration.nix`
- Responsibilities: Placeholder — replaced per-machine with `nixos-generate-config --show-hardware-config` output

**`modules/default.nix`:**
- Location: `modules/default.nix`
- Triggers: Imported as `self.nixosModules.default` from `flake.nix`
- Responsibilities: Aggregates `modules/system`, `modules/services`, `home/` into a single NixOS module

## Error Handling

**Strategy:** NixOS module system assertions — build-time failures, not runtime panics.

**Patterns:**
- Hard assertions (`assertions = [{ assertion = ...; message = ...; }]`) for invariants that would cause unrecoverable boot failures (e.g., `nerv.hostname` must not be empty; `nerv.openssh.tarpitPort != port`; `/var/lib/sbctl` must not be in `impermanence.extraDirs` when secureboot is enabled)
- Soft warnings (`warnings = lib.optionals ...`) for recoverable risks (e.g., sbctl not covered by persistence in btrfs mode — keys are lost on rollback but re-enrollment is possible)
- `lib.mkEnableOption` defaults every service to disabled — missing declarations are safe (off), not broken (error)
- Intentional no-default on `nerv.disko.layout`, `nerv.impermanence.mode`, and `nerv.hostname` — forces explicit operator declaration; a missing value is a build-time type error

## Cross-Cutting Concerns

**Logging:** No custom logging framework. System journals via systemd. Security events via `auditd` (all process executions, file opens, network connections, privilege escalation). AIDE runs daily and logs to `journalctl -u aide-check`.

**Validation:** NixOS module system type-checking (`lib.types.enum`, `lib.types.str`, `lib.types.listOf`, `lib.types.port`) plus explicit `assertions` blocks in modules that have non-trivial invariants.

**Authentication:** SSH key-based only by default (`passwordAuth = false`, `kbdInteractiveAuth = false`). Root login always disabled. Wheel group is the only privilege escalation path (`security.sudo.execWheelOnly = true`). LUKS full-disk encryption on all layouts. Optional TPM2 auto-unlock bound to Secure Boot PCRs 0+7 via `nerv.secureboot.enable`.

---

*Architecture analysis: 2026-03-10*
