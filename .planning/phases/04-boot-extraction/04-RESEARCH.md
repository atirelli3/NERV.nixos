# Phase 4: Boot Extraction - Research

**Researched:** 2026-03-07
**Domain:** NixOS module authoring — boot/initrd/LUKS extraction, selective tmpfs impermanence, secureboot migration
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**boot.nix — fully opaque, initrd+loader+LUKS only**
- Fully opaque module — no `nerv.boot.*` options exposed; `lib.mkForce` is the documented escape hatch
- Consistent with kernel.nix, security.nix posture
- Scope: owns `boot.initrd.*` (systemd, lvm, kernelModules, luks device) and `boot.loader.*` (systemd-boot + EFI)
- Does NOT own: `fileSystems` (NIXBOOT/NIXROOT) and `swapDevices` (NIXSWAP) — these stay in `hosts/nixos-base/configuration.nix` as they are host-specific hardware labels and Disko overrides
- `boot.kernelPackages = pkgs.linuxPackages_latest` is set in boot.nix (matches current configuration.nix); `kernel.nix` overrides it with `lib.mkForce pkgs.linuxPackages_zen` — comment in boot.nix documents this intentional override relationship

**LUKS label — hardcoded + cross-reference comments**
- No `nerv.boot.luksLabel` option — `NIXLUKS` stays hardcoded in all files
- Cross-reference comments required in all three files:
  - `modules/system/boot.nix`: comment noting label must match `disko-configuration.nix`
  - `hosts/nixos-base/disko-configuration.nix`: comment noting label must match `boot.nix` and `secureboot.nix`
  - `modules/system/secureboot.nix`: comment noting label must match `boot.nix` and `disko-configuration.nix`
- Satisfies DOCS-04 requirement

**impermanence.nix — selective per-directory tmpfs**
- Architecture: selective per-directory tmpfs mounts — NOT full root-on-tmpfs
  - Root `/` stays on disk (ext4); specific directories are mounted as tmpfs
  - The upstream NixOS impermanence module (`environment.persistence`) is NOT used
- `nerv.impermanence.persistPath` (default `/persist`) kept in the options API for forward compatibility but documented as unused/limited in the selective model
- `nerv.impermanence.extraDirs` is a list of absolute system paths to mount as tmpfs (additive to the hardcoded defaults)
- Default system tmpfs mounts (active when `nerv.impermanence.enable = true`):
  - `/tmp` — size 25% RAM
  - `/var/tmp` — size 25% RAM
- Default user tmpfs mounts (active for all users in `nerv.primaryUser` when enable = true):
  - `~/Desktop` — size 25% RAM
  - `~/Downloads` — size 25% RAM
- Default tmpfs size: `size=25%` (standard Linux tmpfs default; scales with RAM) unless overridden per-dir

**nerv.impermanence.users.<name> — attrset with size overrides**
- Type: `types.attrsOf types.str` — keys are absolute paths, values are size strings
- Example: `nerv.impermanence.users.demon0 = { "/home/demon0/Videos" = "8G"; "/home/demon0/Projects" = "4G"; };`
- These are additional per-user tmpfs mounts beyond the default Desktop/Downloads

**IMPL-02 — sbctl safety assertion**
- In the selective tmpfs model, `/var/lib/sbctl` is on disk by default and safe
- When `nerv.impermanence.enable = true AND nerv.secureboot.enable = true`: module adds an assertion that `/var/lib/sbctl` (or any prefix of it) is NOT present in `extraDirs` or any `users.<name>` value
- Prevents accidental sbctl wipe via misconfigured impermanence config
- Evaluation fails with a clear error message if violated

**secureboot.nix migration**
- Migrated from `modules/secureboot.nix` (flat, unconditional) to `modules/system/secureboot.nix`
- Wrapped with `nerv.secureboot.enable` guard (`mkIf cfg.enable`) — completes OPT-08
- LUKS label `NIXLUKS` stays hardcoded in TPM2 enrollment scripts with cross-reference comment
- Imported last in `modules/system/default.nix` (prevents `lib.mkForce false` conflict with systemd-boot set in boot.nix)

### Claude's Discretion
- Exact NixOS module option descriptions and example values for impermanence options
- Whether per-user default Desktop/Downloads mounts use `boot.initrd.postMountCommands` or `fileSystems` entries with `neededForBoot = false`
- Mount option flags beyond `size=` (e.g. `mode=`, `nosuid`, `nodev`)
- Order of imports in `modules/system/default.nix` (boot, impermanence before secureboot)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| STRUCT-02 | Boot/LUKS/initrd configuration is extracted from `base/configuration.nix` into a dedicated `modules/system/boot.nix` | boot.nix opaque pattern is well-established in the codebase; exact source lines are boot block in configuration.nix lines 25-41 |
| IMPL-01 | `modules/system/impermanence.nix` exists with `nerv.impermanence.enable`, `nerv.impermanence.persistPath` (default `/persist`), and `nerv.impermanence.extraDirs` options | NixOS `fileSystems` entries with `fsType = "tmpfs"` is the correct mechanism; options pattern follows identity.nix/hardware.nix |
| IMPL-02 | When `nerv.impermanence.enable = true` and `nerv.secureboot.enable = true`, `/var/lib/sbctl` is automatically persisted to prevent TPM2 re-enrollment on reboot | In selective tmpfs model sbctl is on disk by default; safety is provided by a `lib.mkAssert` that `/var/lib/sbctl` is not in tmpfs path list |
| IMPL-03 | User can declare per-user persistent directories via `nerv.impermanence.users.<name>` (list of strings mapping to `~/` subdirs) | Context decided this as `types.attrsOf types.str` — keys are absolute paths, values are size strings |
</phase_requirements>

---

## Summary

Phase 4 extracts boot configuration from `hosts/nixos-base/configuration.nix` and creates two new system modules: `modules/system/boot.nix` (opaque, no options) and `modules/system/impermanence.nix` (option-bearing, enable guard). It also migrates the existing `modules/secureboot.nix` to `modules/system/secureboot.nix` and wraps it with an enable guard.

All three operations are straightforward Nix module authoring work with no new libraries required. The boot extraction is a direct cut-paste-refactor. The impermanence module uses standard NixOS `fileSystems` entries with `fsType = "tmpfs"` — the upstream impermanence NixOS module is explicitly NOT used. The secureboot migration is a file move plus an `mkIf cfg.enable` wrapper around existing content.

The critical integration constraint is import order in `modules/system/default.nix`: secureboot.nix must be last because it uses `lib.mkForce false` on `boot.loader.systemd-boot.enable`, which conflicts if evaluated before boot.nix sets the option.

**Primary recommendation:** Execute as three sequential tasks (boot.nix, impermanence.nix, secureboot.nix) then a wiring task that adds all three to the aggregator and removes the old secureboot import. Each task verifies with `nixos-rebuild build --flake .#nixos-base`.

---

## Standard Stack

### Core (all built-in NixOS — no new packages)

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| NixOS `fileSystems` | Built-in | tmpfs mount declarations | Canonical NixOS way to declare mounts; activates at boot via systemd mount units |
| `lib.mkForce` | Built-in | Escape hatch for opaque modules | Established project pattern (kernel.nix, security.nix, nix.nix) |
| `lib.mkIf` | Built-in | Conditional config blocks | Used throughout services modules for enable guards |
| `lib.mkEnableOption` | Built-in | Boolean enable option shorthand | Used in pipewire.nix, openssh.nix, all services modules |
| `lib.mkOption` | Built-in | Typed option declarations | Used in identity.nix, hardware.nix for all non-boolean options |
| `lib.types.attrsOf` | Built-in | Attribute-set option type | Per-user size overrides map (keys = paths, values = size strings) |
| `lib.types.listOf` | Built-in | List option type | `extraDirs` list |
| `assertions` | Built-in | Build-time safety checks | Used in identity.nix for `nerv.hostname != ""` — same mechanism for sbctl assertion |
| `lib.any` | Built-in | List predicate helper | Used in the sbctl safety assertion to check if any path is a prefix of `/var/lib/sbctl` |

### Alternatives Considered (and rejected per context)

| Instead of | Could Use | Reason Rejected |
|------------|-----------|-----------------|
| Manual `fileSystems` tmpfs entries | `environment.persistence` (upstream impermanence module) | Explicit decision: upstream module not used; selective per-directory model is simpler and does not require full root-on-tmpfs |
| Hardcoded NIXLUKS | `nerv.boot.luksLabel` option | Explicit decision: option is unnecessary complexity; cross-reference comments are sufficient |

---

## Architecture Patterns

### Recommended File Structure After Phase 4

```
modules/
├── system/
│   ├── default.nix        # updated: adds boot, impermanence (new), secureboot (migrated)
│   ├── boot.nix           # new: opaque, no options
│   ├── impermanence.nix   # new: option-bearing, enable guard
│   ├── secureboot.nix     # migrated from modules/secureboot.nix + enable guard
│   ├── identity.nix       # unchanged
│   ├── hardware.nix       # unchanged
│   ├── kernel.nix         # unchanged
│   ├── security.nix       # unchanged
│   └── nix.nix            # unchanged
hosts/
└── nixos-base/
    ├── configuration.nix  # boot block removed; fileSystems/swapDevices remain
    └── disko-configuration.nix  # cross-reference comment added
```

### Pattern 1: Opaque Module (boot.nix)

**What:** Module that unconditionally applies configuration with no user-facing options.
**When to use:** When all hosts using this module must have the same behavior; variation is handled via `lib.mkForce` at the host level.

```nix
# modules/system/boot.nix
#
# Purpose : initrd + LUKS + bootloader configuration.
# Options : None — fully opaque. Use lib.mkForce to override any setting.
# Note    : boot.kernelPackages = pkgs.linuxPackages_latest is set here but
#           overridden by kernel.nix (lib.mkForce pkgs.linuxPackages_zen) —
#           kernel.nix is the authoritative source for the kernel package.
# LUKS    : NIXLUKS label must stay in sync with disko-configuration.nix
#           and modules/system/secureboot.nix.

{ config, lib, pkgs, ... }:

{
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # ... initrd and loader config
}
```

Source: Established project pattern. See `modules/system/kernel.nix` and `modules/system/security.nix`.

### Pattern 2: Enable-Guard Option Module (impermanence.nix)

**What:** Module that declares options and only applies configuration when `enable = true`.
**When to use:** When the feature is optional and may not be activated on all hosts.

```nix
# modules/system/impermanence.nix
{ config, lib, pkgs, ... }:
let
  cfg = config.nerv.impermanence;
in {
  options.nerv.impermanence = {
    enable = lib.mkEnableOption "selective per-directory tmpfs impermanence";
    persistPath = lib.mkOption {
      type    = lib.types.str;
      default = "/persist";
      description = "Persistence base path. Reserved for forward compatibility; unused in selective tmpfs model.";
    };
    extraDirs = lib.mkOption {
      type    = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional absolute system paths to mount as tmpfs. Additive to the defaults (/tmp, /var/tmp).";
      example = [ "/var/cache/app" ];
    };
    users = lib.mkOption {
      type    = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
      default = {};
      description = "Per-user additional tmpfs mounts. Keys are usernames; values are attrsets of absolute path => size string.";
      example = { demon0 = { "/home/demon0/Videos" = "8G"; }; };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !(config.nerv.secureboot.enable &&
          (lib.any (d: lib.hasPrefix d "/var/lib/sbctl" || lib.hasPrefix "/var/lib/sbctl" d)
            (cfg.extraDirs ++
             lib.concatLists (lib.mapAttrsToList (_user: paths: lib.attrNames paths) cfg.users))));
        message = "nerv: /var/lib/sbctl is in impermanence tmpfs paths — this would wipe Secure Boot keys on every reboot. Remove it from impermanence configuration.";
      }
    ];
    # fileSystems entries for system defaults + extraDirs
    # fileSystems entries for per-user mounts via lib.genAttrs on nerv.primaryUser
  };
}
```

Source: Established project pattern. See `modules/services/pipewire.nix` (enable guard), `modules/system/identity.nix` (assertions + options).

### Pattern 3: Migration + Enable-Guard (secureboot.nix)

**What:** Existing flat module moved to new location and wrapped with `mkIf cfg.enable`.
**When to use:** When a module exists unconditionally but needs to become opt-in (OPT-08 completion).

```nix
# modules/system/secureboot.nix
{ config, lib, pkgs, ... }:
let
  cfg = config.nerv.secureboot;
  # nerv.secureboot.enable already declared in modules/services/ (OPT-08)
  # This module only adds config under mkIf cfg.enable
in {
  config = lib.mkIf cfg.enable {
    # All content from modules/secureboot.nix verbatim
    # Plus: LUKS cross-reference comment on the NIXLUKS hardcode
  };
}
```

**Important:** `nerv.secureboot.enable` option is declared elsewhere (it is part of OPT-08, already complete in Phase 2). `secureboot.nix` at `modules/system/` only needs to use `cfg.enable`, not re-declare the option. Verify where the option is currently declared before writing the module.

### Pattern 4: tmpfs fileSystems Entry

**What:** How NixOS declares a tmpfs mount — used for each directory in impermanence.nix.

```nix
fileSystems."/tmp" = {
  device  = "tmpfs";
  fsType  = "tmpfs";
  options = [ "size=25%" "mode=1777" "nosuid" "nodev" ];
};
```

**For user home subdirectories**, the same pattern applies. `neededForBoot = false` is implicit for non-`/boot` paths:

```nix
fileSystems."/home/demon0/Downloads" = {
  device  = "tmpfs";
  fsType  = "tmpfs";
  options = [ "size=25%" "mode=0755" "nosuid" "nodev" "uid=1000" "gid=1000" ];
};
```

Source: NixOS manual, `fileSystems` option documentation — HIGH confidence.

### Generating Per-User Mounts

Use `lib.genAttrs` (or `builtins.listToAttrs` + `map`) to iterate `nerv.primaryUser` for default Desktop/Downloads mounts, and `lib.mapAttrs'` to iterate `cfg.users` for custom mounts.

```nix
# Default Desktop + Downloads for each primaryUser
(lib.mkMerge (map (user: {
  fileSystems."/home/${user}/Desktop" = {
    device = "tmpfs"; fsType = "tmpfs";
    options = [ "size=25%" "nosuid" "nodev" ];
  };
  fileSystems."/home/${user}/Downloads" = {
    device = "tmpfs"; fsType = "tmpfs";
    options = [ "size=25%" "nosuid" "nodev" ];
  };
}) config.nerv.primaryUser))

# Per-user custom mounts from cfg.users
(lib.mkMerge (lib.concatLists (lib.mapAttrsToList (user: pathMap:
  lib.mapAttrsToList (path: size: {
    fileSystems.${path} = {
      device = "tmpfs"; fsType = "tmpfs";
      options = [ "size=${size}" "nosuid" "nodev" ];
    };
  }) pathMap
) cfg.users)))
```

Source: Standard NixOS Nix module patterns — HIGH confidence.

### Anti-Patterns to Avoid

- **Re-declaring `nerv.secureboot.enable` in secureboot.nix:** The option is already declared in a services module (OPT-08 is complete). Adding it again causes a merge conflict or duplicate-option error. Check where it is declared and only add `config = lib.mkIf cfg.enable { ... }`.
- **Putting `fileSystems` (NIXROOT, NIXBOOT) or `swapDevices` in boot.nix:** These are host-specific Disko-managed entries. They must remain in `hosts/nixos-base/configuration.nix`.
- **Importing secureboot.nix before boot.nix in default.nix:** secureboot.nix sets `boot.loader.systemd-boot.enable = lib.mkForce false`. If evaluated before boot.nix creates the option, there is no conflict — but the intent is that secureboot.nix's `lib.mkForce false` wins over boot.nix's `enable = true`. NixOS module merge handles this regardless of import order, but the project decision says last to be explicit and clear.
- **Using `environment.persistence` (upstream impermanence module):** The flake includes the impermanence input, but the user explicitly decided NOT to use `environment.persistence`. Use `fileSystems` entries directly.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Conditional config blocks | Custom if-then attrset merges | `lib.mkIf` | NixOS priority system; mkIf integrates with module merge |
| Per-user config generation | Manual attrset construction | `lib.genAttrs` / `map` + `lib.mkMerge` | Handles empty lists correctly; idiomatic Nix |
| Safety assertions | Runtime scripts or systemd checks | `assertions = [{ assertion = ...; message = ...; }]` | Fails at evaluation time, not at runtime — catches misconfiguration before any boot |
| String prefix checks | Manual string ops | `lib.hasPrefix` | Built-in, handles edge cases |

**Key insight:** All "does this path conflict with sbctl" logic must happen at eval time via `assertions`, not at runtime. Runtime checks would fail after reboot, when Secure Boot keys are already gone.

---

## Common Pitfalls

### Pitfall 1: Forgetting to declare nerv.secureboot.enable in secureboot.nix

**What goes wrong:** Writing `modules/system/secureboot.nix` with only `config = lib.mkIf cfg.enable { ... }` but without the `options.nerv.secureboot.enable` declaration, causing "The option 'nerv.secureboot.enable' does not exist" at build time.
**Why it happens:** Assuming OPT-08 completion means the option is already declared somewhere. Verified by grep: `nerv.secureboot.enable` is NOT declared anywhere in the current codebase. The existing `modules/secureboot.nix` is flat and unconditional — it never checks an enable flag.
**How to avoid:** `modules/system/secureboot.nix` MUST declare `options.nerv.secureboot.enable = lib.mkEnableOption "Lanzaboote Secure Boot and TPM2 LUKS auto-unlock";` before the `config = lib.mkIf cfg.enable { ... }` block.
**Warning signs:** `nixos-rebuild build` fails with "The option 'nerv.secureboot.enable' does not exist."

### Pitfall 2: tmpfs uid/gid mismatches for user home subdirs

**What goes wrong:** `/home/demon0/Downloads` is mounted as tmpfs but owned by root, so the user cannot write to it.
**Why it happens:** tmpfs defaults to root ownership.
**How to avoid:** Add `uid=` and `gid=` mount options. For the NixOS setup, users are typically created with predictable UIDs starting from 1000. However, hardcoding UIDs is fragile. A safer approach is to use `systemd.tmpfiles.rules` to set ownership after mount, or accept that Claude's discretion applies here (the context delegates mount option flags to the implementer).
**Warning signs:** User home tmpfs dirs exist but `ls -la` shows `root root` ownership.

### Pitfall 3: Missing `lib.mkForce` comment in boot.nix

**What goes wrong:** The `boot.kernelPackages = pkgs.linuxPackages_latest` line in boot.nix looks redundant (it gets overridden by kernel.nix), and a maintainer removes it thinking it is dead code.
**Why it happens:** The override relationship between boot.nix and kernel.nix is not obvious.
**How to avoid:** Add the exact comment specified in the context: `# boot.kernelPackages set here but overridden by kernel.nix (lib.mkForce pkgs.linuxPackages_zen) — kernel.nix is the authoritative source for the kernel package`.

### Pitfall 4: LUKS label cross-reference comments incomplete

**What goes wrong:** Only one or two of the three files get the cross-reference comment. A future refactor changes the NIXLUKS label in disko-configuration.nix but misses boot.nix or secureboot.nix.
**Why it happens:** Comments are added piecemeal across tasks.
**How to avoid:** The wiring/cleanup task should verify all three files have the comment. The DOCS-04 requirement tracks this.

### Pitfall 5: Impermanence tmpfs mounts for non-existent user directories

**What goes wrong:** If `/home/demon0/Desktop` does not exist on disk before the tmpfs is mounted, the mount point does not exist and the mount fails at boot.
**Why it happens:** tmpfs requires the mountpoint directory to exist.
**How to avoid:** Use `systemd.tmpfiles.rules` to create the directories before mount, or include `CreateDirectories = true` behavior via activation scripts. The safest NixOS idiom is `systemd.tmpfiles.rules = [ "d /home/${user}/Desktop 0755 ${user} users -" ]` for each user dir. This is a Claude's Discretion area for the implementer.

### Pitfall 6: Import order in modules/system/default.nix

**What goes wrong:** secureboot.nix is imported before boot.nix. This works in NixOS (module merge is order-independent for most cases), but the explicit project decision says secureboot last.
**Why it happens:** Natural alphabetical or insertion order.
**How to avoid:** Imports list in default.nix: `boot.nix`, `impermanence.nix`, then `secureboot.nix` last.

---

## Code Examples

### boot.nix — complete verbatim migration

```nix
# modules/system/boot.nix
#
# Purpose : initrd (systemd + LVM + LUKS) and bootloader (systemd-boot + EFI) configuration.
# Options : None — fully opaque. Use lib.mkForce to override any setting.
# Note    : boot.kernelPackages = pkgs.linuxPackages_latest is set here but
#           overridden by kernel.nix (lib.mkForce pkgs.linuxPackages_zen) —
#           kernel.nix is the authoritative source for the kernel package.
# LUKS    : NIXLUKS label must stay in sync with hosts/nixos-base/disko-configuration.nix
#           and modules/system/secureboot.nix.

{ config, lib, pkgs, ... }:

{
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.initrd = {
    systemd.enable      = true;   # required for services.lvm and crypttabExtraOpts
    services.lvm.enable = true;
    kernelModules = [ "dm-snapshot" "cryptd" ];  # LVM-on-LUKS snapshots and async dm-crypt
    luks.devices."cryptroot" = {
      device       = "/dev/disk/by-label/NIXLUKS";  # must match disko-configuration.nix and secureboot.nix
      preLVM       = true;
      allowDiscards = true;  # TRIM pass-through for SSDs
    };
  };

  boot.loader = {
    systemd-boot.enable       = true;
    efi.canTouchEfiVariables  = true;
  };
}
```

Source: Directly from `hosts/nixos-base/configuration.nix` lines 25-41 (verified).

### secureboot.nix — migration wrapper skeleton

```nix
# modules/system/secureboot.nix
#
# Purpose : Lanzaboote Secure Boot + TPM2 LUKS auto-unlock.
# Options : nerv.secureboot.enable (declared in OPT-08; see modules/services/)
# Defaults: disabled by default (nerv.secureboot.enable = false)
# Override: Use lib.mkForce at the host level for TPM2 PCR set or sbctl path.
# LUKS    : NIXLUKS label must stay in sync with hosts/nixos-base/disko-configuration.nix
#           and modules/system/boot.nix.
# Import  : Must be last in modules/system/default.nix (lib.mkForce false on
#           systemd-boot conflicts with boot.nix if merge priority is ambiguous).

{ config, lib, pkgs, ... }:

let
  cfg = config.nerv.secureboot;
in {
  config = lib.mkIf cfg.enable {
    # All content from modules/secureboot.nix verbatim
    # boot.loader.systemd-boot.enable = lib.mkForce false;
    # boot.initrd.luks.devices."cryptroot".crypttabExtraOpts = ...
    # boot.lanzaboote = { ... };
    # security.tpm2 = { ... };
    # systemd.services.secureboot-enroll-keys = { ... };
    # systemd.services.secureboot-enroll-tpm2 = { ... };
    # environment.systemPackages = [ ... ];
  };
}
```

Source: Existing `modules/secureboot.nix` (verified, full content read above).

### modules/system/default.nix — updated aggregator

```nix
# Aggregates all nerv system modules.
{ imports = [
    ./identity.nix
    ./hardware.nix
    ./kernel.nix
    ./security.nix
    ./nix.nix
    ./boot.nix          # new
    ./impermanence.nix  # new
    ./secureboot.nix    # migrated — must be last (lib.mkForce false on systemd-boot)
  ];
}
```

Source: `modules/system/default.nix` (verified, current state read above).

### disko-configuration.nix cross-reference comment placement

The comment belongs at the `extraFormatArgs = [ "--label" "NIXLUKS" ]` line:

```nix
extraFormatArgs = [ "--label" "NIXLUKS" ];  # NIXLUKS label — must stay in sync with modules/system/boot.nix and modules/system/secureboot.nix
```

Source: `hosts/nixos-base/disko-configuration.nix` line 27 (verified).

### IMPL-02 assertion — sbctl path safety

The assertion needs to check that no path in the impermanence configuration is `/var/lib/sbctl` or a parent of it:

```nix
assertions = [
  (lib.mkIf config.nerv.secureboot.enable {
    assertion =
      let
        allPaths = cfg.extraDirs
          ++ lib.concatLists (lib.mapAttrsToList (_user: pathMap: lib.attrNames pathMap) cfg.users);
        isSbctlPath = p: p == "/var/lib/sbctl"
          || lib.hasPrefix "/var/lib/sbctl" p
          || lib.hasPrefix p "/var/lib/sbctl";
      in
        !(lib.any isSbctlPath allPaths);
    message = "nerv: /var/lib/sbctl is in impermanence tmpfs paths — this would wipe Secure Boot keys on every reboot. Remove it from impermanence configuration.";
  })
];
```

Source: Project context decision + NixOS `assertions` built-in pattern from `modules/system/identity.nix` (verified).

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Boot config in host `configuration.nix` | Extracted to `modules/system/boot.nix` (opaque) | Enables reuse across hosts; single source of truth |
| `modules/secureboot.nix` flat and unconditional | `modules/system/secureboot.nix` under `mkIf cfg.enable` | Completes OPT-08; secureboot no longer forced on all hosts |
| No impermanence | `modules/system/impermanence.nix` with selective per-dir tmpfs | `/tmp` and user volatile dirs become RAM-backed; deterministic per-boot state |

**Not applicable here:**
- The upstream `nixos-community/impermanence` module (`environment.persistence`) is intentionally not used
- Full root-on-tmpfs is explicitly out of scope

---

## Open Questions

1. ~~**Where is `nerv.secureboot.enable` currently declared?**~~ **RESOLVED**
   - Grep confirms: `nerv.secureboot.enable` does NOT exist anywhere in the codebase. `modules/secureboot.nix` is flat and unconditional — no enable check. OPT-08 completion refers to the semantic intent captured in REQUIREMENTS.md, not to existing code.
   - Resolution: `modules/system/secureboot.nix` MUST declare `options.nerv.secureboot.enable = lib.mkEnableOption ...` as well as the `config = lib.mkIf cfg.enable { ... }` block. No risk of double-declaration.

2. **uid/gid for user home tmpfs mounts**
   - What we know: Claude's discretion. Hardcoded UIDs are fragile.
   - What's unclear: Best approach for ensuring correct ownership of `/home/<user>/Desktop` and `/home/<user>/Downloads` when mounted as tmpfs.
   - Recommendation: Use `systemd.tmpfiles.rules` entries to `d` (create-and-chown) each directory before mount. This integrates cleanly with the NixOS activation process. Alternatively, use `neededForBoot = false` on the fileSystems entry and rely on PAM/login to set ownership.

3. **Existing LUKS label audit (pre-condition from STATE.md)**
   - What we know: STATE.md flags this as a required manual check before Phase 4 begins. The label `NIXLUKS` appears in `disko-configuration.nix` line 26 and `configuration.nix` line 32 and `secureboot.nix` lines 21-22 and 118-124.
   - What's unclear: Whether the actual deployed disk uses `NIXLUKS` or a different label set during initial install.
   - Recommendation: The planner should include a verification task or note that this is a deployment concern, not a development concern. The source files all use `NIXLUKS` consistently, so the code migration is safe.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `nixos-rebuild build` (Nix evaluation check) |
| Config file | `flake.nix` (root) |
| Quick run command | `nixos-rebuild build --flake /home/demon/Developments/test-nerv.nixos#nixos-base` |
| Full suite command | `nix flake check /home/demon/Developments/test-nerv.nixos` |

No unit test framework exists or is needed — this is a NixOS configuration repo. Validation is build-time evaluation.

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| STRUCT-02 | boot block absent from configuration.nix; `modules/system/boot.nix` exists and builds | smoke | `nixos-rebuild build --flake .#nixos-base` | Wave 0: create boot.nix |
| IMPL-01 | `nerv.impermanence.enable = false` (default) builds clean; setting `= true` adds fileSystems entries | smoke | `nixos-rebuild build --flake .#nixos-base` | Wave 0: create impermanence.nix |
| IMPL-02 | Setting extraDirs = [ "/var/lib/sbctl" ] with secureboot.enable = true causes eval failure with correct message | assertion/eval | `nix eval .#nixosConfigurations.nixos-base.config.assertions` (or attempt build with violation) | Wave 0: create impermanence.nix |
| IMPL-03 | `nerv.impermanence.users.demon0 = { "/home/demon0/Videos" = "8G"; }` adds correct fileSystems entry | smoke | `nixos-rebuild build --flake .#nixos-base` | Wave 0: create impermanence.nix |

### Sampling Rate
- **Per task commit:** `nixos-rebuild build --flake /home/demon/Developments/test-nerv.nixos#nixos-base`
- **Per wave merge:** `nix flake check /home/demon/Developments/test-nerv.nixos`
- **Phase gate:** Full `nix flake check` green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `modules/system/boot.nix` — covers STRUCT-02 (create in first task)
- [ ] `modules/system/impermanence.nix` — covers IMPL-01, IMPL-02, IMPL-03 (create in second task)
- [ ] `modules/system/secureboot.nix` — covers OPT-08 migration (create in third task)

---

## Sources

### Primary (HIGH confidence)
- Direct file reads: `modules/secureboot.nix`, `hosts/nixos-base/configuration.nix`, `hosts/nixos-base/disko-configuration.nix`, `modules/system/default.nix`, `modules/system/kernel.nix`, `modules/system/security.nix`, `modules/system/identity.nix`, `modules/system/hardware.nix`, `modules/services/pipewire.nix`
- `.planning/phases/04-boot-extraction/04-CONTEXT.md` — all architectural decisions
- `.planning/REQUIREMENTS.md` — requirement definitions
- `.planning/STATE.md` — accumulated decisions and pre-conditions

### Secondary (MEDIUM confidence)
- NixOS `fileSystems` + `fsType = "tmpfs"` pattern: standard NixOS idiom, confirmed via multiple source files in the codebase using `fileSystems` and the NixOS module system

### Tertiary (LOW confidence)
- uid/gid behavior for tmpfs home subdirs: standard Linux behavior, not verified against NixOS-specific activation order

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — everything is built-in NixOS; no external libraries
- Architecture: HIGH — all patterns directly verified from existing codebase files
- Pitfalls: HIGH (ownership pitfall) / MEDIUM (uid/gid order) — based on codebase inspection and standard Linux knowledge

**Research date:** 2026-03-07
**Valid until:** Stable — NixOS module system API does not change within a NixOS release cycle. Valid indefinitely for this project.
