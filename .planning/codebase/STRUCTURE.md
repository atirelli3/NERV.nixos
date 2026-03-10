# Codebase Structure

**Analysis Date:** 2026-03-10

## Directory Layout

```
NERV.nixos/
├── flake.nix                     # Flake inputs, profiles, nixosConfigurations, nixosModules exports
├── flake.lock                    # (generated) pinned input hashes
├── README.md                     # Installation guide and usage documentation
├── cmd-flow.txt                  # Command reference for install/rebuild workflow
├── disk-layout-refactor.md       # Historical design notes for disk layout decisions
├── hosts/
│   ├── configuration.nix         # Machine identity — all PLACEHOLDER values, filled per host
│   └── hardware-configuration.nix # Placeholder; replaced with nixos-generate-config output
├── modules/
│   ├── default.nix               # Top-level aggregator: imports system + services + home
│   ├── system/
│   │   ├── default.nix           # System aggregator — import order is significant
│   │   ├── identity.nix          # nerv.hostname, nerv.locale.*, nerv.primaryUser
│   │   ├── hardware.nix          # nerv.hardware.cpu/gpu — microcode, GPU drivers, firmware
│   │   ├── kernel.nix            # Zen kernel, kernel params, sysctl hardening, module blacklist
│   │   ├── security.nix          # AppArmor, auditd, ClamAV, AIDE — always-on, opaque
│   │   ├── nix.nix               # Nix daemon, GC, store optimise, autoUpgrade, flake settings
│   │   ├── packages.nix          # Base packages shipped on all flavors (git, fastfetch)
│   │   ├── boot.nix              # systemd stage 1, systemd-boot, EFI — layout-agnostic
│   │   ├── impermanence.nix      # nerv.impermanence.{enable,mode,persistPath,extraDirs,users}
│   │   ├── disko.nix             # nerv.disko.layout (btrfs/lvm), disk layout, rollback service
│   │   └── secureboot.nix        # nerv.secureboot.enable — Lanzaboote + TPM2 (must be last)
│   └── services/
│       ├── default.nix           # Services aggregator
│       ├── openssh.nix           # nerv.openssh — sshd + endlessh tarpit + fail2ban
│       ├── pipewire.nix          # nerv.audio — PipeWire + ALSA + PulseAudio compat + AirPlay
│       ├── bluetooth.nix         # nerv.bluetooth — BlueZ + blueman + WirePlumber BT config
│       ├── printing.nix          # nerv.printing — CUPS + Avahi/mDNS printer discovery
│       └── zsh.nix               # nerv.zsh — Zsh shell, history, aliases, fzf, syntax highlight
├── home/
│   └── default.nix               # nerv.home.{enable,users} — Home Manager NixOS module wiring
├── docs/
│   └── assets/                   # Documentation assets (images, diagrams)
└── .planning/
    ├── codebase/                  # Codebase analysis documents (this directory)
    ├── phases/                    # Phase implementation plans (01–12)
    └── research/                  # Research notes
```

## Directory Purposes

**`hosts/`:**
- Purpose: Machine-specific configuration. The only place operator fills in hardware details.
- Contains: `configuration.nix` (identity, hardware, locale, disk device), `hardware-configuration.nix` (generated per-machine)
- Key files: `hosts/configuration.nix` — edit this first on any new machine

**`modules/system/`:**
- Purpose: OS-level modules. All are always imported (via aggregator); each is conditionally activated by its `nerv.*` option.
- Contains: Ten `.nix` files covering disk, boot, kernel, hardware, identity, security, Nix daemon, packages, impermanence, and secure boot
- Key files: `modules/system/disko.nix` (disk layout + rollback), `modules/system/impermanence.nix` (persistence modes), `modules/system/secureboot.nix` (must be last)

**`modules/services/`:**
- Purpose: Opt-in service modules. None active unless explicitly enabled via profile or host config.
- Contains: Five `.nix` files: `openssh.nix`, `pipewire.nix`, `bluetooth.nix`, `printing.nix`, `zsh.nix`
- Key files: `modules/services/openssh.nix` (SSH hardening with tarpit + fail2ban)

**`home/`:**
- Purpose: Home Manager integration. Wires per-user `~/home.nix` files (which live outside the repo).
- Contains: `home/default.nix` only — a single NixOS module
- Key files: `home/default.nix`

**`docs/`:**
- Purpose: Documentation assets. Prose docs are in `README.md` at repo root.
- Contains: `docs/assets/` for images and diagrams

**`.planning/`:**
- Purpose: GSD planning documents. Not evaluated by Nix.
- Contains: `codebase/` (analysis docs), `phases/` (01–12 implementation plans), `research/`
- Generated: No
- Committed: Yes

## Key File Locations

**Entry Points:**
- `flake.nix`: Flake root — all `nixos-rebuild` and `disko` commands resolve here
- `hosts/configuration.nix`: Machine identity — first file an operator edits for a new host

**Configuration:**
- `flake.nix` (lines 35–62): `hostProfile` and `serverProfile` attrsets — the primary knobs for feature selection
- `hosts/configuration.nix`: All `PLACEHOLDER` values — hostname, user, CPU, GPU, locale, disk device, layout, LVM sizes

**Core Logic:**
- `modules/system/disko.nix`: Disk layout declaration + BTRFS rollback systemd service in initrd
- `modules/system/impermanence.nix`: Persistence bind mounts; `btrfs` vs `full` mode branching
- `modules/system/secureboot.nix`: Lanzaboote + two-boot TPM2 enrollment sequence
- `modules/system/kernel.nix`: Zen kernel selection + sysctl hardening (authoritative over `boot.nix`)
- `modules/system/security.nix`: AppArmor + auditd + ClamAV + AIDE — always-on, no option gate

**Home Manager:**
- `home/default.nix`: NixOS module that reads `nerv.home.users` and generates `home-manager.users`
- `/home/<username>/home.nix`: Per-user file, lives outside repo, imported at build time via `--impure`

## Naming Conventions

**Files:**
- All Nix modules: `<feature>.nix` in lowercase (e.g., `identity.nix`, `openssh.nix`)
- Aggregator files: always named `default.nix` — Nix resolves directory imports to `default.nix`
- Documentation: `README.md` at root; planning docs in `.planning/`

**Directories:**
- Module subtrees: lowercase, plural noun describing the category (`system`, `services`)
- Host configs: flat under `hosts/` — no per-host subdirectory (single-host library design)
- Planning: `.planning/phases/<NN>-<slug>/` where `NN` is zero-padded phase number

**NixOS Options:**
- All library options live under `nerv.<module>.<option>` (e.g., `nerv.openssh.port`, `nerv.disko.layout`)
- Enable flags always use `lib.mkEnableOption` — produces a boolean option named `enable`
- Enum options have no default when the absence of a default enforces explicit declaration (e.g., `nerv.disko.layout`, `nerv.impermanence.mode`)

**Nix Identifiers:**
- Local config bindings: `cfg = config.nerv.<module>` (consistent across all modules)
- Profile attrsets in `flake.nix`: camelCase (`hostProfile`, `serverProfile`)
- Shared LUKS/ESP attrsets in `disko.nix`: camelCase (`sharedEsp`, `sharedLuksOuter`)

## Where to Add New Code

**New system module (e.g., `firewall.nix`):**
- Implementation: `modules/system/firewall.nix` — declare `options.nerv.firewall.*` and `config = lib.mkIf cfg.enable { ... }`
- Register: Add `./firewall.nix` to the imports list in `modules/system/default.nix` (before `./secureboot.nix`)
- Enable in profile: Add `nerv.firewall.enable = true` to `hostProfile` or `serverProfile` in `flake.nix`

**New service module (e.g., `syncthing.nix`):**
- Implementation: `modules/services/syncthing.nix` — same pattern as `modules/services/openssh.nix`
- Register: Add `./syncthing.nix` to the imports list in `modules/services/default.nix`
- Enable in profile: Add `nerv.syncthing.enable = true` to the relevant profile in `flake.nix`

**New host-specific value:**
- Add to `hosts/configuration.nix` only — never add host-specific values to library modules

**New Home Manager option:**
- Add to `home/default.nix` under `options.nerv.home.*` and the corresponding `config = lib.mkIf cfg.enable { ... }` block

**Utilities / shared Nix expressions:**
- No `lib/` directory exists. Inline shared expressions as `let` bindings within the module that needs them. If a helper is needed in multiple modules, evaluate adding a `lib/` directory — currently none exists.

## Special Directories

**`.planning/`:**
- Purpose: GSD orchestration files — phases, research, codebase analysis
- Generated: No
- Committed: Yes — part of the repo history

**`docs/assets/`:**
- Purpose: Images and diagrams for documentation
- Generated: No
- Committed: Yes

---

*Structure analysis: 2026-03-10*
