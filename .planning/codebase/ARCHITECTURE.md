# Architecture

**Analysis Date:** 2026-03-08

## Pattern Overview

**Overall:** Opinionated NixOS module library with profile-based composition

**Key Characteristics:**
- All NERV-specific settings live under a single `nerv.*` option namespace — no raw NixOS options in the module bodies, only `config.*` assignments
- Every feature module is opt-in via `nerv.<module>.enable = true` — nothing activates unless explicitly declared
- Profiles (`hostProfile`, `serverProfile`, `vmProfile`) in `flake.nix` are plain Nix attrsets that set `nerv.*` options; no host-specific logic leaks into module code
- Modules are always-on aggregators (system, security, nix, boot) or feature-gated (services, impermanence, secureboot, home)
- Import order is significant in `modules/system/default.nix` — `secureboot.nix` must be last because it applies `lib.mkForce false` to `systemd-boot`
- Machine-specific values live exclusively in `hosts/configuration.nix` as placeholder values the operator must fill before first boot

## Layers

**Flake Layer:**
- Purpose: Defines inputs, profiles, module exports, and `nixosConfigurations` targets
- Location: `flake.nix`
- Contains: Input pins, profile attrsets, `nixosModules` exports, `nixosConfigurations` for `host`, `server`, `vm`
- Depends on: All upstream inputs (nixpkgs, lanzaboote, home-manager, disko, impermanence)
- Used by: End-user host flakes that consume `nixosModules.default` or individual sub-exports

**System Module Layer:**
- Purpose: Low-level kernel, hardware, boot, security, Nix daemon, and identity configuration
- Location: `modules/system/`
- Contains: `identity.nix`, `hardware.nix`, `kernel.nix`, `security.nix`, `nix.nix`, `packages.nix`, `boot.nix`, `impermanence.nix`, `secureboot.nix`
- Depends on: nixpkgs, lanzaboote (for secureboot), impermanence upstream module (for full mode)
- Used by: `modules/default.nix` aggregator

**Services Module Layer:**
- Purpose: Optional userspace services, each independently toggled
- Location: `modules/services/`
- Contains: `openssh.nix`, `pipewire.nix`, `bluetooth.nix`, `printing.nix`, `zsh.nix`
- Depends on: nixpkgs packages declared in each module
- Used by: `modules/default.nix` aggregator

**Home Manager Layer:**
- Purpose: Wires the Home Manager NixOS module for per-user personal config
- Location: `home/default.nix`
- Contains: `nerv.home.enable` + `nerv.home.users` options; generates `home-manager.users.*` attrset
- Depends on: home-manager input, per-user `~/home.nix` files (outside flake boundary, requires `--impure`)
- Used by: `modules/default.nix` aggregator

**Host Layer:**
- Purpose: Machine-specific identity and disk layout — the only place operator fills in real values
- Location: `hosts/`
- Contains: `configuration.nix` (identity, locale, hardware enums), `disko-configuration.nix` (GPT/EFI/LUKS/LVM layout), `hardware-configuration.nix` (placeholder — replaced per machine)
- Depends on: `modules/default.nix` (via flake composition), disko module
- Used by: `nixosConfigurations.*` entries in `flake.nix`

## Data Flow

**Configuration Evaluation Flow:**

1. `flake.nix` selects a profile (`hostProfile`, `serverProfile`, or `vmProfile`) — a plain attrset of `nerv.*` option values
2. `nixpkgs.lib.nixosSystem` composes the module list: upstream modules (lanzaboote, home-manager, disko, impermanence) + `self.nixosModules.default` + profile attrset + `hosts/configuration.nix` + `hosts/disko-configuration.nix`
3. NixOS module system merges all `options.*` declarations from every imported module and evaluates `config.*` assignments under `lib.mkIf cfg.enable` guards
4. `modules/default.nix` → imports `./system`, `./services`, `../home` — these recursively import their submodules
5. `hosts/configuration.nix` provides concrete values for `nerv.hostname`, `nerv.primaryUser`, `nerv.hardware.*`, `nerv.locale.*`, and `disko.devices.*`
6. Final evaluated config is passed to `nixos-rebuild` or `disko` tooling

**Impermanence Data Flow (full mode):**

1. Boot: `/` mounts as 2 GB tmpfs — ephemeral root
2. `/persist` (ext4 LV from NIXPERSIST label) mounts with `neededForBoot = true`
3. `environment.persistence."/persist"` bind-mounts `/var/log`, `/var/lib/nixos`, `/var/lib/systemd`, `/etc/nixos` into the tmpfs root
4. SSH host keys and `/etc/machine-id` are bind-mounted from `/persist` as files
5. On reboot: tmpfs root is discarded; only `/persist` contents survive

**Secure Boot Setup Flow (two-boot sequence):**

1. Boot 1: `secureboot-enroll-keys.service` detects Setup Mode, runs `sbctl enroll-keys --microsoft`, writes sentinel at `/var/lib/secureboot-keys-enrolled`, then reboots
2. Boot 2: `secureboot-enroll-tpm2.service` detects sentinel and active Secure Boot, runs `systemd-cryptenroll` to bind LUKS (`NIXLUKS` label) to TPM2 PCRs 0+7, writes sentinel at `/var/lib/secureboot-setup-done`

**State Management:**
- NixOS module system manages all state declaratively; no runtime mutation outside systemd oneshot services
- Persistent host state (SSH keys, machine-id, journals) is separated from ephemeral state via impermanence
- Operator's personal config lives at `~/home.nix` — outside the flake, never committed here

## Key Abstractions

**nerv.* Option Namespace:**
- Purpose: Single namespace for all NERV-specific options; prevents collision with upstream NixOS options
- Examples: `nerv.hostname`, `nerv.primaryUser`, `nerv.hardware.cpu`, `nerv.openssh.enable`, `nerv.impermanence.mode`
- Pattern: Each module declares its own `options.nerv.<module>.*` block; `config` blocks are always guarded by `lib.mkIf cfg.enable`

**Profile Attrsets:**
- Purpose: Named machine archetypes that set `nerv.*` flags; no NixOS expression logic
- Examples: `hostProfile`, `serverProfile`, `vmProfile` in `flake.nix` lines 35–74
- Pattern: Plain Nix attrsets inlined into the `modules` list of `nixosSystem`; operator copies and customizes

**Aggregator Modules (default.nix):**
- Purpose: Single import that pulls in an entire subtree; consumers import one file per layer
- Examples: `modules/default.nix`, `modules/system/default.nix`, `modules/services/default.nix`
- Pattern: `{ imports = [ ./a ./b ./c ]; }` — no options or config, pure composition

**Opaque vs. Feature-Gated Modules:**
- Purpose: Separates always-on hardening (security, nix, boot) from opt-in features (openssh, audio, secureboot)
- Pattern: Opaque modules have no options and emit config unconditionally; feature-gated modules expose `nerv.<name>.enable` and wrap all config in `lib.mkIf cfg.enable`

## Entry Points

**Flake Outputs:**
- Location: `flake.nix` lines 76–128
- Triggers: `nix build`, `nixos-rebuild`, `disko`
- Responsibilities: Exposes `nixosModules.{default,system,services,home}` for downstream consumers and `nixosConfigurations.{host,server,vm}` for direct use

**Primary Module Entry Point:**
- Location: `modules/default.nix`
- Triggers: Imported by `nixosConfigurations.*` via `self.nixosModules.default`
- Responsibilities: Aggregates all three layers (system + services + home) into a single import

**Host Entry Point:**
- Location: `hosts/configuration.nix`
- Triggers: Imported directly by each `nixosConfigurations.*` entry
- Responsibilities: Provides concrete machine identity, hardware enum, locale, and disk device values; imports `hardware-configuration.nix`

**Disk Layout Entry Point:**
- Location: `hosts/disko-configuration.nix`
- Triggers: Imported by each `nixosConfigurations.*` entry alongside disko NixOS module
- Responsibilities: Declares GPT partition table (ESP → NIXLUKS LUKS → LVM VG → swap/store/persist LVs)

## Error Handling

**Strategy:** NixOS module system assertions — evaluation-time failures with descriptive messages

**Patterns:**
- `nerv.hostname` must be non-empty: assertion in `modules/system/identity.nix`
- `nerv.openssh.tarpitPort` must differ from `nerv.openssh.port`: assertion in `modules/services/openssh.nix`
- Impermanence + secureboot guard: `/var/lib/sbctl` must not appear in tmpfs paths (would wipe Secure Boot keys on reboot): assertion in `modules/system/impermanence.nix`
- Placeholder values in `hosts/configuration.nix` are not assertion-guarded — operator must replace all `"PLACEHOLDER"` strings before first boot

## Cross-Cutting Concerns

**Security:** Always-on in `modules/system/security.nix` — AppArmor, auditd with baseline ruleset, ClamAV daemon + daily definition updates, AIDE file integrity monitoring (daily systemd timer), PTI enforcement, kernel image protection, sudo restricted to wheel group

**Logging:** systemd journal throughout; auditd writes to `/var/log/audit/audit.log`; AIDE check results to journal via `aide-check` unit; sentinels for secureboot setup written to `/var/lib/`

**Authentication:** SSH key-only by default (`PasswordAuthentication = false`); endlessh tarpit on port 22; fail2ban with exponential ban escalation; LUKS full-disk encryption with optional TPM2 auto-unlock sealed to Secure Boot state (PCR 0+7)

---

*Architecture analysis: 2026-03-08*
