# Phase 8: NERV.nixos Release & Multi-Profile Migration - Research

**Researched:** 2026-03-08
**Domain:** NixOS impermanence, flake multi-profile inline patterns, git repo migration
**Confidence:** HIGH (impermanence module API), HIGH (inline profile pattern), MEDIUM (disko tmpfs-root layout), HIGH (git migration workflow)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Target Repository:** `git@github.com:atirelli3/NERV.nixos.git`
- Placed at `/etc/nixos` during installation
- `.git` must be tracked (users pull further updates)

**NERV.nixos Directory Structure (exact):**
```
/etc/nixos
├── home/
│   └── default.nix
├── hosts/
│   ├── configuration.nix
│   ├── disko-configuration.nix
│   └── hardware-configuration.nix
├── modules/
│   ├── default.nix
│   ├── services/
│   │   └── *.nix
│   └── system/
│       └── *.nix
└── flake.nix
```

**Profile strategy:** Inline module lambdas in flake.nix — NOT in hosts/configuration.nix.

**Three profiles (locked settings):**
- `hostProfile`: openssh enabled, audio (PipeWire) enabled, bluetooth enabled, printing enabled, secureboot=false, impermanence minimal mode
- `serverProfile`: openssh enabled only, impermanence full mode (/ tmpfs, /persist for state), audio/bluetooth/printing disabled
- `vmProfile`: composable from hostProfile defaults, secureboot disabled

**hosts/configuration.nix covers only:** nerv.hostname, nerv.primaryUser, nerv.hardware.cpu/gpu, nerv.locale.*, system.stateVersion, disko disk device placeholder

**Full impermanence design:**
- `/` is tmpfs (reset on reboot)
- `/nix` persistent ext4
- `/persist` persistent ext4
- `/boot` persistent vfat
- Selective persistence via `environment.persistence` from nixos-community/impermanence module
- The `impermanence` flake input (currently absent — removed in Phase 7) must be added back

**nerv.impermanence.mode option:**
- `"minimal"` (default): current behavior — mounts /tmp, /var/tmp as tmpfs
- `"full"`: requires impermanence nixos module, sets up environment.persistence

**Dead modules to delete (9 files):**
- modules/openssh.nix, modules/pipewire.nix, modules/bluetooth.nix
- modules/printing.nix, modules/zsh.nix, modules/kernel.nix
- modules/security.nix, modules/nix.nix, modules/hardware.nix

**Test repo reset:** `git reset --hard cab4126e8664a808eef482154a8500106ae22246` (user confirms)

### Claude's Discretion

- Exact `environment.persistence` declarations for server (paths: /etc/nixos, /var/lib/*, etc.)
- Whether to add `impermanence` module to flake.nix nixosModules exports or only use internally
- Commit message strategy for NERV.nixos initial push
- Whether server disko-configuration.nix needs updating for tmpfs root layout
- How to handle the `server/` and `vm/` directories (migrate useful parts, discard stubs)

### Deferred Ideas (OUT OF SCOPE)

- Full home impermanence ($HOME on tmpfs)
- DE/WM/DM configuration
- Multi-host examples beyond the three profiles
- Automated install script
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| IMPL-04 | Full impermanence mode: / as tmpfs, state on /persist via environment.persistence | impermanence module API documented below; persistence paths catalogued |
| IMPL-05 | Multi-profile flake: host/server/vm defined as inline module lambdas in flake.nix | Inline module lambda pattern verified — module list accepts plain attrset as a module |
| IMPL-06 | Repo migration: complete refined structure pushed to git@github.com:atirelli3/NERV.nixos.git | git clone + copy + push workflow documented |
| Cleanup | Delete 9 dead flat modules in modules/ root | File list confirmed by `ls modules/` inspection |
</phase_requirements>

---

## Summary

Phase 8 has four distinct work streams: (1) delete 9 dead flat modules that are superseded by their structured counterparts in modules/system/ and modules/services/; (2) extend impermanence.nix to support a `"full"` mode using the nixos-community/impermanence NixOS module and environment.persistence declarations; (3) define three inline profile attrsets in flake.nix and wire them into nixosConfigurations; and (4) clone the NERV.nixos repo, copy the refined structure, push, and reset the test repo.

The impermanence module API is stable and well-documented. The key insight is that `environment.persistence."<path>"` takes a plain attrset with `directories` and `files` lists — the module handles bind-mounts automatically. Critical: the `/persist` filesystem must have `neededForBoot = true` in fileSystems, otherwise impermanence cannot create bind mounts early enough. The impermanence flake input was removed in Phase 7 and must be re-added for full mode.

The inline profile pattern is idiomatic NixOS: a module in `nixpkgs.lib.nixosSystem { modules = [...]; }` can be any value that evaluates to a module — including a plain attrset like `{ nerv.openssh.enable = true; }`. No `{ config, lib, ... }:` wrapper needed for simple option-setting profiles. The `serverProfile` can import the impermanence nixosModule directly as part of the modules list in flake.nix rather than through the profile lambda itself.

**Primary recommendation:** Tackle in this order — (1) delete dead modules, (2) add impermanence input back + extend impermanence.nix, (3) extend flake.nix with profiles + nixosConfigurations, (4) migrate to NERV.nixos, (5) reset test repo.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| nixos-community/impermanence | master (no stable tags) | Provides `environment.persistence` NixOS module that creates bind mounts from /persist to ephemeral paths | De-facto standard for NixOS impermanence; all reference implementations use it |
| disko | v1.13.0 (already pinned) | Declarative disk layout | Already in flake.nix; server disko needs updating for /nix + /persist partitions |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| git | system | Repo clone, copy, commit, push | Migration step only |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| nixos-community/impermanence module | Manual fileSystems bind mounts | Module is cleaner and handles directory creation; manual approach is valid but verbose |
| tmpfs root | btrfs snapshots for root rollback | tmpfs is simpler for a server (no snapshot management); btrfs rollback is more flexible but adds complexity |

**Installation (flake input to add back):**
```nix
impermanence = {
  url = "github:nix-community/impermanence";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Note: impermanence has no `inputs.nixpkgs` to override. The canonical flake input declaration is simply:
```nix
impermanence.url = "github:nix-community/impermanence";
```

---

## Architecture Patterns

### Recommended NERV.nixos Structure
```
/etc/nixos (NERV.nixos repo root)
├── flake.nix              # inputs + inline profiles + nixosConfigurations + nixosModules
├── home/
│   └── default.nix        # HM wiring module
├── hosts/
│   ├── configuration.nix  # machine identity only (hostname, user, hardware, locale)
│   ├── disko-configuration.nix  # disk layout (host variant: ext4 root)
│   └── hardware-configuration.nix  # placeholder — replaced by nixos-generate-config
└── modules/
    ├── default.nix
    ├── services/
    │   ├── default.nix
    │   ├── bluetooth.nix
    │   ├── openssh.nix
    │   ├── pipewire.nix
    │   ├── printing.nix
    │   └── zsh.nix
    └── system/
        ├── default.nix
        ├── boot.nix
        ├── hardware.nix
        ├── identity.nix
        ├── impermanence.nix
        ├── kernel.nix
        ├── nix.nix
        ├── secureboot.nix
        └── security.nix
```

Note: `server/` and `vm/` directories from test-nerv.nixos are NOT migrated. The server disko layout is embedded as documentation/reference in RESEARCH.md — the actual hosts/disko-configuration.nix in NERV.nixos is the host (desktop/laptop) layout.

### Pattern 1: Inline Module Lambda in flake.nix

**What:** Define profile attrsets as `let` bindings in flake.nix outputs. Each profile is a plain attrset setting nerv.* options. NixOS module evaluation accepts plain attrsets as modules.

**When to use:** When profiles are simple option-setting only (no imports, no lib calls needed). For serverProfile, the impermanence nixos module must be in the modules list, not inside the profile attrset.

**Example:**
```nix
# Source: verified pattern — NixOS module system accepts plain attrsets
outputs = { self, nixpkgs, lanzaboote, home-manager, disko, impermanence, ... }:
let
  hostProfile = {
    nerv.openssh.enable        = true;
    nerv.audio.enable          = true;
    nerv.bluetooth.enable      = true;
    nerv.printing.enable       = true;
    nerv.secureboot.enable     = false;
    nerv.impermanence.enable   = true;
    nerv.impermanence.mode     = "minimal";
  };

  serverProfile = {
    nerv.openssh.enable        = true;
    nerv.audio.enable          = false;
    nerv.bluetooth.enable      = false;
    nerv.printing.enable       = false;
    nerv.secureboot.enable     = false;
    nerv.impermanence.enable   = true;
    nerv.impermanence.mode     = "full";
  };

  vmProfile = {
    nerv.openssh.enable        = true;
    nerv.audio.enable          = true;
    nerv.bluetooth.enable      = false;
    nerv.printing.enable       = false;
    nerv.secureboot.enable     = false;
    nerv.impermanence.enable   = true;
    nerv.impermanence.mode     = "minimal";
  };
in {
  nixosConfigurations = {
    host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        lanzaboote.nixosModules.lanzaboote
        home-manager.nixosModules.home-manager
        self.nixosModules.default
        hostProfile
        ./hosts/configuration.nix
        disko.nixosModules.disko
        ./hosts/disko-configuration.nix
      ];
    };

    server = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        lanzaboote.nixosModules.lanzaboote
        home-manager.nixosModules.home-manager
        impermanence.nixosModules.impermanence  # required for mode = "full"
        self.nixosModules.default
        serverProfile
        ./hosts/configuration.nix
        disko.nixosModules.disko
        ./hosts/disko-configuration.nix
      ];
    };

    vm = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        home-manager.nixosModules.home-manager
        self.nixosModules.default
        vmProfile
        ./hosts/configuration.nix
        disko.nixosModules.disko
        ./hosts/disko-configuration.nix
      ];
    };
  };
}
```

**Key insight:** `impermanence.nixosModules.impermanence` goes in the modules list, not inside the profile attrset, because profile attrsets cannot call `imports = [...]` without a lambda wrapper. If a profile needs imports, wrap it: `{ imports = [ impermanence.nixosModules.impermanence ]; nerv.impermanence.mode = "full"; }`. Both approaches work; the cleaner one puts the module in the modules list alongside the profile.

### Pattern 2: Full Impermanence Mode in impermanence.nix

**What:** Add `mode` option to `nerv.impermanence`. When `mode = "full"`, the module activates `environment.persistence` declarations via the upstream nixos-community/impermanence module. The upstream module must be added to nixosModules by the caller (flake.nix).

**When to use:** Server profile only. The minimal mode (current behavior) remains for host and vm.

**Example — extended impermanence.nix structure:**
```nix
# Source: verified against nixos-community/impermanence README and official module options
{ config, lib, pkgs, ... }:
let
  cfg = config.nerv.impermanence;
in {
  options.nerv.impermanence = {
    enable = lib.mkEnableOption "selective per-directory tmpfs impermanence";

    mode = lib.mkOption {
      type        = lib.types.enum [ "minimal" "full" ];
      default     = "minimal";
      description = ''
        Impermanence mode.
        - "minimal": mounts /tmp and /var/tmp as tmpfs only (safe for desktops/VMs).
        - "full": / is tmpfs; system state is persisted to persistPath via
          environment.persistence (requires impermanence.nixosModules.impermanence
          in nixosConfigurations modules list).
      '';
    };

    persistPath = lib.mkOption {
      type    = lib.types.str;
      default = "/persist";
      description = "Persistence base path. Used by full mode for environment.persistence.";
    };

    extraDirs  = /* existing option */;
    users      = /* existing option */;
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # Minimal mode: always active when enable = true
    {
      fileSystems."/tmp"     = { device = "tmpfs"; fsType = "tmpfs"; options = [ "size=25%" "mode=1777" "nosuid" "nodev" ]; };
      fileSystems."/var/tmp" = { device = "tmpfs"; fsType = "tmpfs"; options = [ "size=25%" "mode=1777" "nosuid" "nodev" ]; };
      fileSystems           = extraDirFileSystems // userFileSystems;
      systemd.tmpfiles.rules = userTmpfilesRules;
    }

    # Full mode: additional declarations (/ as tmpfs is in disko, not here)
    (lib.mkIf (cfg.mode == "full") {
      # environment.persistence declarations (upstream module handles bind mounts)
      environment.persistence."${cfg.persistPath}" = {
        hideMounts = true;
        directories = [
          "/var/log"
          "/var/lib/nixos"       # nixos user/group id assignments
          "/var/lib/systemd"     # systemd unit state
          { directory = "/var/lib/ssh"; mode = "0755"; }
        ];
        files = [
          "/etc/machine-id"
          "/etc/ssh/ssh_host_ed25519_key"
          "/etc/ssh/ssh_host_ed25519_key.pub"
          "/etc/ssh/ssh_host_rsa_key"
          "/etc/ssh/ssh_host_rsa_key.pub"
        ];
      };

      # /persist must be marked neededForBoot so bind mounts happen before services
      # (disko sets this when mountpoint = "/persist", but verify in disko config)
      fileSystems."${cfg.persistPath}".neededForBoot = lib.mkDefault true;
    })
  ]);
}
```

### Pattern 3: Server Disko Layout for Full Impermanence

**What:** For full impermanence, disko must provide /nix (persistent Nix store) and /persist (persistent state) as real filesystems, but NOT declare / — root is declared by the hardware-configuration or via fileSystems in the NixOS module (not disko) as a tmpfs.

**Research finding (MEDIUM confidence):** Two approaches exist:
1. Disko declares /nix and /persist as LVM logical volumes; / is declared in NixOS fileSystems as tmpfs (not in disko). This is the standard approach per reference implementations.
2. Disko v1.13 supports `type = "tmpfs"` as a filesystem type — root could be declared in disko. However, all community examples for full impermanence avoid declaring / in disko and instead put it in NixOS fileSystems directly.

**Recommended approach:** Do NOT declare the root partition in server disko-configuration.nix. Remove the `root` LV entirely (or keep it as a 1G emergency ext4 but not mount it). The `/` tmpfs is declared in NixOS module config or hardware-configuration.nix.

**Server disko-configuration.nix LVM layout (revised):**
```nix
# Source: derived from server/disko-configuration.nix + reference impermanence patterns
lvm_vg.lvmroot = {
  type = "lvm_vg";
  lvs = {
    swap = {
      size = "SIZE_RAM * 2";
      content = { type = "swap"; extraArgs = [ "-L" "NIXSWAP" ]; };
    };
    store = {
      size = "SIZE";  # e.g. "60G" — holds entire Nix store
      content = {
        type = "filesystem";
        format = "ext4";
        mountpoint = "/nix";
        extraArgs = [ "-L" "NIXSTORE" ];
      };
    };
    persist = {
      size = "SIZE";  # e.g. "20G" — holds system state
      content = {
        type = "filesystem";
        format = "ext4";
        mountpoint = "/persist";
        extraArgs = [ "-L" "NIXPERSIST" ];
      };
    };
    # No root LV — / is declared as tmpfs in NixOS fileSystems
    # No home LV — /home is ephemeral (tmpfs root) for servers
  };
};
```

**Root tmpfs declaration in NixOS module (impermanence.nix full mode):**
```nix
# This goes in config = lib.mkIf (cfg.enable && cfg.mode == "full") { ... }
fileSystems."/" = {
  device  = "none";
  fsType  = "tmpfs";
  options = [ "defaults" "size=2G" "mode=755" ];
};
```

**CRITICAL:** `/persist` must have `neededForBoot = true` for impermanence bind mounts to work. Disko automatically adds this when the mountpoint is a top-level persistent filesystem; verify after migration.

### Pattern 4: Git Migration Workflow

**What:** Clone empty NERV.nixos repo, copy refined files, make initial commit, push.

**Exact workflow:**
```bash
# Step 1: Clone the empty/target repo
git clone git@github.com:atirelli3/NERV.nixos.git /tmp/nerv-nixos

# Step 2: Copy refined files from test-nerv.nixos
# Include: flake.nix, home/, hosts/, modules/, README.md (if any)
# Exclude: .planning/, server/, vm/, .git (of course)
rsync -av --exclude='.git' --exclude='.planning' --exclude='server' --exclude='vm' \
  /home/demon/Developments/test-nerv.nixos/ /tmp/nerv-nixos/

# Step 3: Verify structure, then commit
cd /tmp/nerv-nixos
git add flake.nix home/ hosts/ modules/ README.md
git commit -m "feat: initial NERV.nixos release — v1.0"
git push origin main

# Step 4: Reset test-nerv.nixos (USER CONFIRMS FIRST)
cd /home/demon/Developments/test-nerv.nixos
git reset --hard cab4126e8664a808eef482154a8500106ae22246
```

### Anti-Patterns to Avoid

- **Putting impermanence.nixosModules.impermanence inside a profile attrset:** Plain attrsets cannot use `imports = [...]`. Either wrap in lambda or put it in the nixosConfigurations modules list.
- **Declaring / in disko for the server profile:** Causes disko to try to format / which conflicts with the running system. Declare / as tmpfs only in NixOS fileSystems.
- **Missing neededForBoot on /persist:** Without this, impermanence bind mounts fail at boot because /persist is not mounted when systemd-tmpfiles runs early activation.
- **Adding impermanence flake input with inputs.nixpkgs.follows:** The impermanence repo has no nixpkgs input to override. Use only `impermanence.url = "github:nix-community/impermanence";`.
- **Committing the /persist neededForBoot in minimal mode path:** The `fileSystems."/persist".neededForBoot` line should only apply when mode = "full" — otherwise it causes errors on systems without a /persist mount.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Bind mounts from /persist to ephemeral paths | Custom systemd mount units | `environment.persistence` from impermanence module | Module handles directory creation, ordering, and activation — manual bind mounts miss early-boot ordering |
| Inline profile option scoping | `{ config, lib, ... }:` lambda with logic | Plain attrset `{ nerv.x.enable = true; }` | For pure option-setting profiles with no logic, a plain attrset is cleaner and idiomatic |
| SSH host key persistence | Environment.etc.ssh symlinks (xe iaso approach) | `environment.persistence."/persist".files = ["/etc/ssh/..."]` | The impermanence module's files list handles this correctly; manual symlinks via environment.etc are valid but more verbose |

**Key insight:** The impermanence module's primary value is ordering — it ensures bind mounts happen at the right point in the boot sequence via systemd activation. Hand-rolling this requires deep knowledge of systemd unit ordering.

---

## Common Pitfalls

### Pitfall 1: /etc/machine-id Conflicts
**What goes wrong:** `environment.persistence."/persist".files = ["/etc/machine-id"]` fails with "file already exists" if machine-id was written during boot before the bind mount.
**Why it happens:** NixOS generates /etc/machine-id during early boot if it doesn't exist; the impermanence module then tries to create a bind mount over it.
**How to avoid:** The impermanence module handles this correctly when /persist is marked `neededForBoot = true`. The module creates the bind mount before systemd-machine-id-setup runs. If issues occur, use `environment.etc."machine-id".source = "/persist/etc/machine-id"` as an alternative.
**Warning signs:** Boot-time error "A file already exists at /etc/machine-id but is not a bind mount."

### Pitfall 2: impermanence Input Has No nixpkgs to Follow
**What goes wrong:** `impermanence.inputs.nixpkgs.follows = "nixpkgs"` causes flake evaluation error because impermanence has no such input.
**Why it happens:** Unlike lanzaboote, home-manager, and disko, the impermanence flake does not declare a nixpkgs input.
**How to avoid:** Declare simply as `impermanence.url = "github:nix-community/impermanence";` with no follows.
**Warning signs:** `nix flake update` error about unknown input.

### Pitfall 3: Inline Profile Mode Mismatch
**What goes wrong:** serverProfile sets `nerv.impermanence.mode = "full"` but `impermanence.nixosModules.impermanence` is not in the server nixosConfigurations modules list — `environment.persistence` option does not exist and evaluation fails.
**Why it happens:** The `environment.persistence` option is declared by the upstream impermanence module, not by nerv. Without the module in the list, the option is unknown.
**How to avoid:** Always add `impermanence.nixosModules.impermanence` to the server nixosConfigurations entry whenever mode = "full" is used.
**Warning signs:** `error: The option 'environment.persistence' does not exist.`

### Pitfall 4: Dead Modules Still Imported Somewhere
**What goes wrong:** Deleting modules/openssh.nix etc. causes evaluation error if anything imports them directly.
**Why it happens:** The flat modules/ root files are NOT imported by any aggregator (confirmed: modules/default.nix imports ./system and ./services only), but hosts/nixos-base/configuration.nix or any other file might reference them.
**How to avoid:** Verify no file contains `import ./openssh` or similar before deletion. Run `nix flake check` after deletion.
**Warning signs:** `error: could not find module 'openssh.nix'` during flake check.

### Pitfall 5: git reset --hard Is Destructive
**What goes wrong:** Running `git reset --hard cab4126e` on test-nerv.nixos destroys all uncommitted changes and all commits after that hash.
**Why it happens:** It's intended — this resets the dev repo to baseline. But if NERV.nixos push failed or was incomplete, the refined work is lost.
**How to avoid:** Confirm NERV.nixos push was successful (check git log on remote) BEFORE running reset. This step must be last.
**Warning signs:** Incomplete NERV.nixos state after reset.

### Pitfall 6: server/disko-configuration.nix Has Wrong LUKS Label
**What goes wrong:** server/disko-configuration.nix has `NIKLUKS` (typo — missing 'X') while the rest of the project uses `NIXLUKS`.
**Why it happens:** The server/ directory is a draft stub with typos. If migrated as-is, boot.nix LUKS device lookup will fail.
**How to avoid:** Fix label to `NIXLUKS` in server disko-configuration.nix before including it anywhere. Or discard server/ entirely and write a fresh server disko-configuration.nix.
**Warning signs:** initrd LUKS unlock fails on server — "no device found for label NIKLUKS".

---

## Code Examples

### environment.persistence for Server (Minimal Required Set)
```nix
# Source: verified against nixos-community/impermanence README
# and community server configurations (guekka.github.io/nixos-server-1/)
environment.persistence."/persist" = {
  hideMounts = true;  # hides bind mounts from `mount` output (cleaner UX)
  directories = [
    "/var/log"            # systemd journal, syslog
    "/var/lib/nixos"      # nixos user/group ID allocations (users.mutableUsers state)
    "/var/lib/systemd"    # systemd coredumps, timers, machine-id state
  ];
  files = [
    "/etc/machine-id"                    # stable machine identity (journald, systemd)
    "/etc/ssh/ssh_host_ed25519_key"      # SSH host identity
    "/etc/ssh/ssh_host_ed25519_key.pub"
    "/etc/ssh/ssh_host_rsa_key"
    "/etc/ssh/ssh_host_rsa_key.pub"
  ];
};
```

Claude's discretion additions to consider (MEDIUM confidence — common in community configs):
```nix
# Add if the server will run specific services:
# "/var/lib/acme"     — for Let's Encrypt certs (add with mode = "0755")
# "/var/lib/fail2ban" — if fail2ban is enabled
# "/etc/nixos"        — if user clones config at /etc/nixos (relevant for NERV.nixos!)
```

For NERV.nixos specifically, `/etc/nixos` should be persisted since the user clones the repo there:
```nix
directories = [
  "/var/log"
  "/var/lib/nixos"
  "/var/lib/systemd"
  "/etc/nixos"  # NERV.nixos repo — user clones here, must survive reboots
];
```

### impermanence Flake Input (Correct Form)
```nix
# Source: github.com/nix-community/impermanence README
impermanence.url = "github:nix-community/impermanence";
# Note: NO inputs.nixpkgs.follows — impermanence has no nixpkgs input
```

### fileSystems."/" as tmpfs (Full Mode)
```nix
# Source: willbush.dev/blog/impermanent-nixos/ — verified pattern
fileSystems."/" = {
  device  = "none";
  fsType  = "tmpfs";
  options = [ "defaults" "size=2G" "mode=755" ];
};
```

### nerv.impermanence.mode Option Declaration
```nix
# New option to add to options.nerv.impermanence attrset
mode = lib.mkOption {
  type        = lib.types.enum [ "minimal" "full" ];
  default     = "minimal";
  description = ''
    Impermanence mode.
    "minimal" (default): mounts /tmp and /var/tmp as tmpfs.
    "full": activates environment.persistence for system state on persistPath.
    Full mode requires impermanence.nixosModules.impermanence in the host
    nixosConfigurations modules list (see flake.nix serverProfile entry).
  '';
};
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| impermanence input with follows = nixpkgs | `impermanence.url = "github:nix-community/impermanence"` (no follows) | Phase 7 removed the input entirely; re-add without follows | Flake evaluates without input error |
| Flat modules/*.nix (9 files) | Structured modules/system/*.nix and modules/services/*.nix | Phases 2-4 | Dead files safe to delete — nothing imports them |
| nixosConfigurations.nixos-base only | nixosConfigurations.host + .server + .vm with inline profiles | Phase 8 | Three build targets for three use cases |

**Deprecated/outdated:**
- `server/disko-configuration.nix`: Draft stub with typo (NIKLUKS vs NIXLUKS) — do not migrate as-is; rewrite or fix.
- `vm/` directory: Empty gitkeep only — discard.
- `modules/openssh.nix` and 8 siblings: Superseded by modules/services/ and modules/system/ counterparts — safe to delete.

---

## Open Questions

1. **Should the server disko-configuration.nix declare a NIXHOME partition?**
   - What we know: server/disko-configuration.nix has a home LV; full impermanence means /home is ephemeral (tmpfs root)
   - What's unclear: does a server need persistent /home at all? Only if the primary user keeps non-ephemeral files there.
   - Recommendation: Omit NIXHOME from server disko. /home is created by tmpfs root and is ephemeral. If users need persistent home dirs, they go in /persist/home via environment.persistence.users.
   - Confidence: MEDIUM

2. **Should `environment.persistence` handle `/var/lib` as a whole or only specific subdirs?**
   - What we know: persisting all of `/var/lib` is easy but catches unexpected state; per-subdir is safer
   - What's unclear: what services the server will actually run is not known at this phase
   - Recommendation: Persist individual subdirs (nixos, systemd) by default; document how to add service-specific paths. Do not persist `/var/lib` wholesale.
   - Confidence: HIGH (based on community practice)

3. **Does `vmProfile` need `lanzaboote.nixosModules.lanzaboote` in its modules list?**
   - What we know: vmProfile has secureboot = false; lanzaboote module is currently in all nixosConfigurations
   - What's unclear: whether lanzaboote module causes errors when secureboot.enable = false (it might define options that conflict)
   - Recommendation: Include lanzaboote module but keep secureboot.enable = false — the module's config block is guarded by the enable flag. This is consistent with current pattern.
   - Confidence: HIGH (same as current nixos-base configuration)

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | nix flake check (NixOS evaluation, no runtime) |
| Config file | flake.nix |
| Quick run command | `nix flake check --no-build 2>&1 \| head -30` |
| Full suite command | `nix flake check` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| Cleanup | 9 dead modules deleted | smoke | `ls modules/*.nix 2>/dev/null \| wc -l` == 0 | ❌ Wave 0 (shell check) |
| IMPL-04 | impermanence.mode = "full" configures environment.persistence | unit (nix eval) | `nix eval .#nixosConfigurations.server.config.environment.persistence` | ❌ Wave 0 |
| IMPL-05 | Three nixosConfigurations defined | smoke | `nix flake show 2>&1 \| grep nixosConfigurations` | existing flake.nix |
| IMPL-06 | NERV.nixos repo has correct structure | manual | `git ls-remote git@github.com:atirelli3/NERV.nixos.git` | post-push only |

### Sampling Rate
- **Per task commit:** `nix flake check --no-build`
- **Per wave merge:** `nix flake check`
- **Phase gate:** Full `nix flake check` green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] Shell check: `ls /home/demon/Developments/test-nerv.nixos/modules/*.nix` should return empty after cleanup
- [ ] `nix eval` command to verify environment.persistence is populated when mode = "full"

---

## Sources

### Primary (HIGH confidence)
- `github.com/nix-community/impermanence` — module API (environment.persistence, directories, files, hideMounts, neededForBoot requirement)
- `github.com/nix-community/disko` — existing integration already in flake.nix; tmpfs filesystem type supported
- Direct file inspection: `modules/system/impermanence.nix`, `flake.nix`, `modules/system/default.nix`, `modules/system/secureboot.nix`

### Secondary (MEDIUM confidence)
- [Xe Iaso: Paranoid NixOS (2021)](https://xeiaso.net/blog/paranoid-nixos-2021-07-18/) — persisted paths list, SSH key symlink pattern
- [Will Bush: Impermanent NixOS](https://willbush.dev/blog/impermanent-nixos/) — tmpfs root fileSystems declaration, partition layout
- [Guekka: NixOS as a Server](https://guekka.github.io/nixos-server-1/) — server-specific environment.persistence paths (machine-id, SSH host keys)
- [notashelf: Full Disk Encryption and Impermanence](https://notashelf.dev/posts/impermanence) — LUKS + impermanence combined pattern

### Tertiary (LOW confidence)
- WebSearch: community patterns for /var/lib subdirectory persistence (no single authoritative source)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — impermanence module API verified from upstream GitHub README
- Architecture (inline profiles): HIGH — NixOS module system verified to accept plain attrsets in modules list
- Architecture (full impermanence paths): MEDIUM — paths derived from multiple community sources, not a single authoritative list; server-specific additions depend on what services are run
- Architecture (server disko layout): MEDIUM — derived from reference implementations + existing server/disko-configuration.nix; disko tmpfs-root behavior not directly verified
- Pitfalls: HIGH — NIKLUKS typo found by direct inspection; machine-id conflict documented by nixos-community/impermanence issue tracker

**Research date:** 2026-03-08
**Valid until:** 2026-09-08 (stable domain; impermanence API rarely changes)
