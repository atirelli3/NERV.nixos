# Codebase Structure

**Analysis Date:** 2026-03-08

## Directory Layout

```
nerv.nixos/
├── flake.nix                    # Root flake: inputs, profiles, nixosModules exports, nixosConfigurations
├── README.md                    # Project documentation
├── hosts/                       # Machine-specific configuration (operator-fills placeholders)
│   ├── configuration.nix        # Identity, locale, hardware enums, disko disk device
│   ├── disko-configuration.nix  # GPT/EFI/LUKS/LVM disk layout (placeholder sizes)
│   └── hardware-configuration.nix  # Placeholder — replaced by nixos-generate-config per machine
├── modules/                     # NERV module library
│   ├── default.nix              # Top-level aggregator: imports system + services + home
│   ├── system/                  # Low-level system configuration
│   │   ├── default.nix          # System aggregator (import order is significant)
│   │   ├── identity.nix         # nerv.hostname, nerv.locale.*, nerv.primaryUser
│   │   ├── hardware.nix         # nerv.hardware.cpu / gpu — microcode + drivers
│   │   ├── kernel.nix           # Kernel package selection (zen kernel)
│   │   ├── security.nix         # AppArmor, auditd, ClamAV, AIDE — always-on
│   │   ├── nix.nix              # Nix daemon, GC, optimise, autoUpgrade, flakes
│   │   ├── packages.nix         # Base packages: git, fastfetch (unconditional)
│   │   ├── boot.nix             # initrd systemd + LUKS + systemd-boot (opaque)
│   │   ├── impermanence.nix     # nerv.impermanence.{enable,mode,persistPath,...}
│   │   └── secureboot.nix       # nerv.secureboot.enable — Lanzaboote + TPM2 (last import)
│   └── services/                # Optional userspace services
│       ├── default.nix          # Services aggregator
│       ├── openssh.nix          # nerv.openssh — sshd + endlessh tarpit + fail2ban
│       ├── pipewire.nix         # nerv.audio — PipeWire audio stack
│       ├── bluetooth.nix        # nerv.bluetooth — BlueZ + bluetooth tools
│       ├── printing.nix         # nerv.printing — CUPS + common drivers
│       └── zsh.nix              # nerv.zsh — Zsh with keybindings, fzf, git aliases
├── home/                        # Home Manager NixOS module wiring
│   └── default.nix              # nerv.home.{enable,users} — generates home-manager.users.*
└── docs/                        # Project documentation assets
    └── assets/                  # Logo and media files
```

## Directory Purposes

**`flake.nix` (root file):**
- Purpose: Single source of truth for inputs, profile definitions, module exports, and build targets
- Contains: `hostProfile`, `serverProfile`, `vmProfile` attrsets; `nixosModules.{default,system,services,home}`; `nixosConfigurations.{host,server,vm}`
- Key files: `flake.nix`

**`hosts/`:**
- Purpose: Machine-specific layer — the only place an operator edits to adapt NERV to a real machine
- Contains: Identity values (`nerv.hostname`, `nerv.primaryUser`, `nerv.hardware.*`, `nerv.locale.*`), disk layout, hardware config
- Key files: `hosts/configuration.nix`, `hosts/disko-configuration.nix`, `hosts/hardware-configuration.nix`

**`modules/system/`:**
- Purpose: Always-evaluated system modules; some are opaque (no options), some are feature-gated
- Contains: Kernel, hardware, boot, security hardening, Nix daemon config, impermanence, Secure Boot
- Key files: `modules/system/default.nix`, `modules/system/security.nix`, `modules/system/impermanence.nix`, `modules/system/secureboot.nix`

**`modules/services/`:**
- Purpose: Optional, independently toggled userspace services; all default to `enable = false`
- Contains: SSH, audio, bluetooth, printing, shell
- Key files: `modules/services/default.nix`, `modules/services/openssh.nix`, `modules/services/zsh.nix`

**`home/`:**
- Purpose: Bridges the NixOS system configuration with per-user Home Manager configs stored outside the flake
- Contains: A single `default.nix` that generates `home-manager.users.*` entries from `nerv.home.users` list
- Key files: `home/default.nix`

**`.planning/`:**
- Purpose: GSD planning documents — phases, research, codebase analysis
- Contains: Phase execution records under `.planning/phases/`, codebase maps under `.planning/codebase/`, research notes under `.planning/research/`
- Generated: No
- Committed: Yes

## Key File Locations

**Entry Points:**
- `flake.nix`: Root flake — all builds, module exports, and profile composition start here
- `modules/default.nix`: Primary module entry point imported by all `nixosConfigurations.*` targets
- `hosts/configuration.nix`: Operator-filled machine identity consumed by all build targets

**Configuration:**
- `flake.nix` lines 35–74: Profile attrsets (`hostProfile`, `serverProfile`, `vmProfile`)
- `hosts/disko-configuration.nix`: Disk partitioning layout (GPT → LUKS → LVM → swap/store/persist)
- `hosts/hardware-configuration.nix`: Placeholder replaced by `nixos-generate-config` output

**Core Logic:**
- `modules/system/impermanence.nix`: Two-mode impermanence (minimal tmpfs dirs vs. full tmpfs root + `/persist`)
- `modules/system/secureboot.nix`: Two-boot Lanzaboote + TPM2 auto-enrollment sequence
- `modules/system/security.nix`: Always-on security stack (AppArmor, auditd, ClamAV, AIDE)
- `modules/services/openssh.nix`: Hardened SSH with endlessh tarpit and fail2ban

**Aggregators (composition points):**
- `modules/default.nix`: Imports `./system`, `./services`, `../home`
- `modules/system/default.nix`: Imports all 9 system submodules in dependency order
- `modules/services/default.nix`: Imports all 5 service modules

## Naming Conventions

**Files:**
- Lowercase with hyphens for multi-word names: `disko-configuration.nix`, `hardware-configuration.nix`
- Single-word feature names match the service name: `openssh.nix`, `bluetooth.nix`, `printing.nix`
- Aggregators always named `default.nix`

**Directories:**
- Lowercase, single word: `system/`, `services/`, `home/`, `hosts/`, `modules/`

**Nix Option Namespace:**
- All NERV options under `nerv.*`: `nerv.hostname`, `nerv.openssh.enable`, `nerv.hardware.cpu`
- Feature enable options follow `nerv.<feature>.enable` pattern using `lib.mkEnableOption`
- Sub-options grouped under `nerv.<feature>.*`: `nerv.impermanence.mode`, `nerv.openssh.port`

**Local Variables in Modules:**
- Config binding: `cfg = config.nerv.<module>` at the top of each `let` block
- Derived attrsets: descriptive camelCase names (`extraDirFileSystems`, `userFileSystems`, `userTmpfilesRules`)

## Where to Add New Code

**New System Module (always-on, opaque):**
- Implementation: `modules/system/<name>.nix`
- Register: Add `./name` to the imports list in `modules/system/default.nix`
- Pattern: No `options.*` block; emit `config.*` unconditionally

**New Feature-Gated System Module:**
- Implementation: `modules/system/<name>.nix` — declare `options.nerv.<name>.enable` with `lib.mkEnableOption`, wrap all `config` in `lib.mkIf cfg.enable`
- Register: Add `./name` to `modules/system/default.nix` imports (before `secureboot.nix` if it uses `lib.mkForce`)
- Profile wiring: Add `nerv.<name>.enable = true/false` to each profile attrset in `flake.nix`

**New Service Module:**
- Implementation: `modules/services/<name>.nix` — same option pattern as feature-gated system modules
- Register: Add `./name` to `modules/services/default.nix` imports
- Profile wiring: Add `nerv.<name>.enable = true/false` to relevant profiles in `flake.nix`

**Utilities / Helpers:**
- Inline as `let` bindings within the module file that needs them — no shared utility directory exists or is needed given the Nix evaluation model

**Additional nixosConfiguration Targets:**
- Add a new entry to `nixosConfigurations` in `flake.nix`; select or define a profile attrset; reuse `self.nixosModules.default` and the existing `hosts/` files, or create a new host directory

## Special Directories

**`.planning/`:**
- Purpose: GSD orchestration documents — phase plans, research, and codebase maps used by `/gsd:*` commands
- Generated: No
- Committed: Yes

**`docs/assets/`:**
- Purpose: Logo and media assets referenced in `README.md`
- Generated: No
- Committed: Yes

---

*Structure analysis: 2026-03-08*
