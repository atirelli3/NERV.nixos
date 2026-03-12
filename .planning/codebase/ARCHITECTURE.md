# Architecture

**Analysis Date:** 2026-03-12

## Pattern Overview

**Overall:** NixOS declarative module library with strict separation of system configuration layers (immutable infrastructure as code). No runtime composition — all configuration resolved at evaluation time via Nix expressions and modules.

**Key Characteristics:**
- **Module-based composition:** All functionality exposed as NixOS modules in `modules/` with granular enable/disable flags
- **Two-profile model:** `host` (desktop/laptop with BTRFS) and implicit server variant (LVM) with different defaults and capabilities
- **Declarative disk layout:** Disk partitioning and filesystem structure defined in Nix, not imperative commands
- **Selective impermanence:** Root filesystem can be reset to pristine state on boot (desktop BTRFS mode) or run as tmpfs (server full mode) with persistent state in `/persist`
- **Home Manager wiring:** User environment managed via Home Manager module integrated into NixOS build
- **Assertion-driven safety:** Critical invariants enforced as build-time assertions (e.g., sbctl keys not in tmpfs paths)

## Layers

**System Modules (`modules/system/`):**
- Purpose: Always-active system configuration — hardware, kernel, boot, security, networking, persistence
- Location: `modules/system/*.nix`
- Contains: Device drivers, kernel tuning, initrd setup, LUKS encryption, BTRFS/LVM configuration, hardening (AppArmor, auditd, ClamAV)
- Depends on: NixOS module system, nixpkgs, disko, lanzaboote, impermanence flake inputs
- Used by: Top-level module aggregator at `modules/default.nix`

**Service Modules (`modules/services/`):**
- Purpose: Optional services disabled by default — OpenSSH, PipeWire audio, Bluetooth, printing, Zsh shell
- Location: `modules/services/*.nix`
- Contains: Service configuration, daemon setup, CLI tool aliases, firewall rules
- Depends on: NixOS module system, nixpkgs
- Used by: Top-level module aggregator at `modules/default.nix`

**Home Manager Module (`home/default.nix`):**
- Purpose: Per-user environment configuration (dotfiles, packages, programs) — imported into NixOS at eval time
- Location: `home/default.nix` (wiring), `~/home.nix` per user (user-owned implementation)
- Contains: Home Manager user configuration for each listed user, pulls in `~/{home,config}` from user homedir
- Depends on: Home Manager NixOS module, user-supplied `~/home.nix` (read at eval time via absolute path import)
- Used by: NixOS evaluation, requires `--impure` flag for nixos-rebuild (accesses files outside flake boundary)

**Host Configuration (`hosts/configuration.nix`):**
- Purpose: Per-machine identity — hostname, timezone, hardware detection, disk device, user declarations
- Location: `hosts/configuration.nix`
- Contains: Machine-specific facts (hostname, timezone, CPU type, GPU type, primary users, disk device, stateVersion)
- Depends on: Hardware configuration (auto-generated at `hosts/hardware-configuration.nix`)
- Used by: Flake output's `nixosConfigurations.host` entry point

**Flake Interface (`flake.nix`):**
- Purpose: Dependency management and build entry point
- Location: `flake.nix`
- Contains: Flake inputs (nixpkgs, home-manager, disko, lanzaboote, impermanence), nixosConfigurations with default `host` profile
- Depends on: External flake inputs (GitHub URLs pinned to versions or tags)
- Used by: `nix flake` commands, nixos-rebuild with `--flake` flag

## Data Flow

**System Initialization (Boot):**

1. **Stage 1 (initrd):** LUKS decryption via password from `/tmp/luks-password` (provided at install time) or TPM2 (when secureboot is enabled)
2. **BTRFS Rollback (Stage 1.5 — desktop only):** Initrd systemd service snapshots `@root-blank` subvolume over `@` to reset root to pristine state
3. **Stage 2 (NixOS activation):** Mounts all filesystems (/ as `@` BTRFS subvolume, `/home` as `@home`, `/var/log` as `@log`, etc.)
4. **impermanence bind-mount phase:** Binds persistent state from `/persist` into system directories (`/var/lib`, `/etc/nixos`, SSH host keys)
5. **Service activation:** systemd units start in order — audit daemon, fail2ban, OpenSSH, PipeWire, etc.

**Module Evaluation (Build Time):**

1. **Flake inputs resolved:** nixpkgs, home-manager, disko, lanzaboote, impermanence pulled and inputs aligned
2. **Configuration merge:** `nixosConfigurations.host` loads all module imports in order:
   - lanzaboote module
   - home-manager module
   - impermanence module
   - disko module
   - `self.nixosModules.default` (entire nerv module tree)
   - `hosts/configuration.nix` (machine identity — highest priority)
3. **Module tree evaluation:**
   - `modules/default.nix` imports system + services + home aggregators
   - `modules/system/default.nix` imports all system modules (order matters: secureboot last to force systemd-boot to false)
   - `modules/services/default.nix` imports all service modules (disabled by default, enabled via `nerv.*` options in configuration.nix)
   - `home/default.nix` wires per-user Home Manager configs, imports `~/home.nix` for each user
4. **disko evaluation:** Determines whether to build BTRFS or LVM disk layout based on `nerv.disko.layout` value
5. **impermanence mode:** Determines whether root is tmpfs (server full) or BTRFS subvolume (desktop btrfs) based on `nerv.impermanence.mode` value
6. **Assertion checking:** Build fails if invariants violated (e.g., sbctl keys in tmpfs paths, tarpit port != SSH port)
7. **Derivation build:** All evaluation complete → Nix builds closure and outputs `/nix/store/...` result

**State Management:**

- **Transient state:** `/` (root) reset on every boot to `@root-blank` snapshot (BTRFS desktop) or tmpfs (server). No cross-boot persistence.
- **Persistent state:** `/persist` filesystem (BTRFS subvolume or ext4 partition) survives reboots and rollbacks. Bind-mounted into `/var/lib`, `/etc/ssh`, `/etc/nixos`, etc. at stage 2 activation.
- **Nix store:** `/nix` read-only after boot. Not reset — accumulates packages across rebuilds until `nix-collect-garbage` is run.
- **Logs:** `/var/log` on separate BTRFS subvolume (`@log`) — survives reboots but not accessible after rollback (intentional: preserves space and allows per-volume retention policies).

## Key Abstractions

**Module Options Namespace (`nerv.*`):**
- Purpose: All configuration exposed via `config.nerv.*` options — no direct NixOS option modification
- Examples: `nerv.hostname`, `nerv.openssh.enable`, `nerv.impermanence.mode`, `nerv.disko.layout`
- Pattern: Each system/service module defines its own `options.nerv.*` subtree; host configuration sets values

**Conditional Disk Layout:**
- Purpose: Single codebase supports BTRFS (desktop) and LVM (server) via `nerv.disko.layout` value
- Examples: `disko.nix` has separate `lib.mkIf isBtrfs` and `lib.mkIf isLvm` branches; initrd configuration changes accordingly
- Pattern: Layout-specific code conditional on `cfg.layout == "btrfs"` or `cfg.layout == "lvm"`. No implicit defaults — forces explicit declaration.

**Conditional Impermanence Mode:**
- Purpose: Root filesystem strategy varies (BTRFS rollback vs tmpfs) based on system type
- Examples: `impermanence.nix` has branches for `mode = "btrfs"` (desktop) and `mode = "full"` (server)
- Pattern: Same `/persist` directory structure, different mount strategies. Assertions prevent invalid combinations (e.g., tmpfs impermanence mode with disko.layout = "lvm").

**Module Aggregators:**
- Purpose: Multi-level import tree allows granular flake exports (users can import only `services` or `system`)
- Examples:
  - `modules/default.nix`: imports system + services + home
  - `modules/system/default.nix`: aggregates all system modules (import order: identity, hardware, kernel, security, nix, packages, boot, impermanence, disko, secureboot)
  - `modules/services/default.nix`: aggregates all service modules
- Pattern: Each level is a simple `{ imports = [ ... ]; }` file — no config, just aggregation

**Home Manager User Binding:**
- Purpose: Dynamically wire Home Manager for each user in `nerv.home.users` list
- Pattern: `home/default.nix` uses `builtins.listToAttrs` to generate `home-manager.users` attrset from the users list. Each value is a function that imports `/home/<name>/home.nix` at eval time.

## Entry Points

**System Build (`nixosConfigurations.host`):**
- Location: `flake.nix` lines 74–87
- Triggers: `nix flake show`, `nixos-rebuild switch/boot/test --flake /etc/nixos#host`
- Responsibilities:
  - Loads all flake inputs and module dependencies
  - Merges NixOS modules in order (lanzaboote, home-manager, impermanence, disko, self.nixosModules.default, hosts/configuration.nix)
  - Evaluates entire module tree and assertions
  - Builds system derivation

**Module Export (`nixosModules.default`):**
- Location: `flake.nix` line 67
- Triggers: Other flakes that import `nerv` as an input and add `self.nixosModules.default` to their module list
- Responsibilities: Aggregates entire module tree (system + services + home) for external users

**Host Configuration (`hosts/configuration.nix`):**
- Location: `hosts/configuration.nix`
- Triggers: Evaluated as part of `nixosConfigurations.host` module list (loaded last, highest priority via mkMerge default behavior)
- Responsibilities:
  - Sets machine identity (`nerv.hostname`, `nerv.locale`, `nerv.primaryUser`)
  - Declares hardware properties (`nerv.hardware.cpu`, `nerv.hardware.gpu`)
  - Specifies disk layout (`nerv.disko.layout`, `disko.devices.disk.main.device`)
  - Enables services (`nerv.openssh.enable`, `nerv.audio.enable`, etc.)
  - Declares users (`users.users.alice`, `nerv.home.users`)

**User Home Manager (`~/home.nix`):**
- Location: User's home directory (not in flake — requires `--impure`)
- Triggers: `nixos-rebuild switch --flake /etc/nixos#host --impure` when user is in `nerv.home.users` list
- Responsibilities: Per-user environment (packages, programs, dotfiles, configuration)

## Error Handling

**Strategy:** NixOS module assertions (build-time failure) for critical invariants, NixOS service SuccessExitStatus for runtime non-fatal conditions.

**Patterns:**

- **Build-time assertions:** `assertions = [{ assertion = ...; message = "..."; }]` — fails evaluation if condition false
  - Example: `nerv.hostname` must not be empty string (identity.nix)
  - Example: `nerv.openssh.tarpitPort` must differ from `nerv.openssh.port` (openssh.nix)
  - Example: `/var/lib/sbctl` must not be in impermanence tmpfs paths when secureboot is enabled (impermanence.nix, IMPL-02)

- **Service exit code handling:** Some systemd services configured to accept non-zero exits as success (e.g., `aide-check` exits 1 if integrity changes detected — not a failure)
  - Example: `systemd.services.aide-check` has `SuccessExitStatus = [ 0 1 ]` (security.nix line 119)

- **Warnings (not errors):** `lib.warn` for less-critical guidance that should not block builds
  - Example: sbctl keys not covered by persistence in btrfs mode produces warning, not assertion (impermanence.nix line 157–165)

## Cross-Cutting Concerns

**Logging:** auditd (system call auditing to `/var/log/audit/audit.log`), journald (systemd journal), application logs to `/var/log`. AIDE daily integrity checks logged to journal.

**Validation:**
- NixOS option types enforce correct values (e.g., `types.port` for SSH port)
- Assertions check logical constraints (tarpit != ssh port, sbctl paths not in tmpfs)
- No runtime validation layer — all constraints enforced at build time

**Authentication:**
- OpenSSH: key-based by default, password auth optional (disabled via `nerv.openssh.passwordAuth = false`)
- TPM2 LUKS unlock (when secureboot enabled) or password-based (default)
- sudo restricted to wheel group only (`security.sudo.execWheelOnly = true`)
- User authentication delegated to NixOS user/group system (uid/gid declared in configuration.nix)

**Security hardening:**
- Kernel: forced page table isolation, kernel image write protection
- AppArmor mandatory access control (opt-in per app)
- auditd system call logging (execve, openat, connect, setuid/setgid, /etc/passwd/shadow/sudoers/sshd_config)
- ClamAV antivirus with automatic definition updates
- AIDE file integrity monitoring (daily check, compares binaries and configs against baseline)
- Secure boot with lanzaboote (UKI signed with sbctl keys, TPM2 measurements)

---

*Architecture analysis: 2026-03-12*
