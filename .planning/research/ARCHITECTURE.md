# Architecture Research

**Domain:** NixOS flake library — v3.0 zram swap + starship prompt
**Researched:** 2026-03-12
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
modules/system/default.nix (aggregator)
  ├── identity.nix
  ├── hardware.nix
  ├── kernel.nix
  ├── security.nix
  ├── nix.nix
  ├── packages.nix
  ├── boot.nix              layout-agnostic initrd + bootloader
  ├── impermanence.nix
  ├── disko.nix             disk layout + layout-conditional initrd services
  ├── [NEW] swap.nix        zram swap (nerv.swap.zram.*)
  └── secureboot.nix        MUST remain last (lib.mkForce false on systemd-boot)

modules/services/default.nix (aggregator)
  ├── openssh.nix
  ├── pipewire.nix
  ├── bluetooth.nix
  ├── printing.nix
  └── zsh.nix               [MODIFIED] gains programs.starship block
```

### Component Responsibilities

| Component | Responsibility | Placement |
|-----------|----------------|-----------|
| swap.nix (new) | zramSwap.enable, memoryPercent, algorithm; nerv.swap.zram.* options | modules/system/ |
| zsh.nix (modified) | existing zsh config + new programs.starship block when nerv.zsh.starship.enable | modules/services/ |
| disko.nix | disk layout only — no zram concern; LVM branch has swap-on-disk, BTRFS branch has none | no change needed |
| boot.nix | layout-agnostic initrd + bootloader — no swap concern | no change needed |
| system/default.nix | import list — swap.nix inserted before secureboot | one line added |

## Recommended Project Structure

```
modules/
├── system/
│   ├── default.nix         # ADD: ./swap.nix import (before secureboot.nix)
│   ├── boot.nix            # no change
│   ├── disko.nix           # no change
│   ├── hardware.nix        # no change
│   ├── identity.nix        # no change
│   ├── impermanence.nix    # no change
│   ├── kernel.nix          # no change
│   ├── nix.nix             # no change
│   ├── packages.nix        # no change
│   ├── security.nix        # no change
│   ├── secureboot.nix      # no change (stays last)
│   └── swap.nix            # NEW — zram swap module
└── services/
    ├── default.nix         # no change (zsh.nix already imported)
    ├── bluetooth.nix       # no change
    ├── openssh.nix         # no change
    ├── pipewire.nix        # no change
    ├── printing.nix        # no change
    └── zsh.nix             # MODIFIED — starship block added inside cfg.enable guard
```

### Structure Rationale

- **swap.nix in modules/system/**: swap is a kernel/memory concern, not a daemon/service. Consistent with how disko.nix handles the LVM swap LV — hardware-layer concerns live in system/, not services/.
- **starship inside zsh.nix (not a new file)**: The prompt is not an independent daemon. It is unconditionally tied to the shell — enabling starship without zsh.enable is nonsensical. Co-location in zsh.nix enforces this dependency structurally and avoids adding a services/default.nix import for a sub-feature.
- **secureboot.nix stays last**: The lib.mkForce false on systemd-boot in secureboot.nix must override anything swap.nix might set. swap.nix sets nothing boot-loader-related, so this is a non-issue in practice, but the ordering rule is preserved by convention.

## Architectural Patterns

### Pattern 1: Option-gated system config (existing pattern, applied to swap)

**What:** Declare a nerv.* option, gate entire config block with `lib.mkIf cfg.enable`.
**When to use:** All new features in this library.
**Trade-offs:** Forces explicit opt-in (default false); self-documents the feature.

**Example (swap.nix skeleton):**
```nix
{ config, lib, ... }:
let cfg = config.nerv.swap.zram; in {
  options.nerv.swap.zram = {
    enable = lib.mkOption {
      type    = lib.types.bool;
      default = false;
      description = "Enable zram in-memory compressed swap.";
    };
    memoryPercent = lib.mkOption {
      type    = lib.types.ints.positive;
      default = 50;
      description = "Maximum zram swap size as percentage of total RAM (default: 50%).";
    };
  };

  config = lib.mkIf cfg.enable {
    zramSwap.enable        = true;
    zramSwap.memoryPercent = cfg.memoryPercent;
    zramSwap.algorithm     = "zstd";   # best ratio for general workloads
  };
}
```

### Pattern 2: Sub-option inside an existing module (starship inside zsh.nix)

**What:** Add a nested `nerv.zsh.starship.enable` option inside the existing `nerv.zsh` options block. The config block for starship lives inside the outer `lib.mkIf cfg.enable` guard, with its own inner `lib.mkIf cfg.starship.enable`.
**When to use:** When a feature is exclusively a sub-concern of an existing module and cannot function without it.
**Trade-offs:** Keeps related concerns together; avoids a proliferation of single-option service files.

**Example (addition to zsh.nix):**
```nix
options.nerv.zsh.starship = {
  enable = lib.mkOption {
    type    = lib.types.bool;
    default = false;
    description = "Enable starship prompt (requires nerv.zsh.enable).";
  };
};

# inside config = lib.mkIf cfg.enable { ... }:
(lib.mkIf cfg.starship.enable {
  programs.starship = {
    enable               = true;
    enableZshIntegration = true;
    settings             = { /* toml config as Nix attrset */ };
  };
})
```

### Pattern 3: programs.starship injection mechanics

**What:** `programs.starship.enable = true` (system-level NixOS module) combined with `enableZshIntegration = true` appends the following into `programs.zsh.promptInit` (or `shellInit` when `interactiveOnly = false`):

```bash
if [[ $TERM != "dumb" ]]; then
  if [[ ! -f "$HOME/.config/starship.toml" ]]; then
    export STARSHIP_CONFIG=${settingsFile}
  fi
  eval "$(starship init zsh)"
fi
```

**When to use:** This is the correct path — do not manually source starship in interactiveShellInit.
**Trade-offs:** programs.starship injects via promptInit, which runs after interactiveShellInit. The existing zsh.nix plugin load order (syntax-highlighting then history-substring-search in interactiveShellInit) is unaffected because promptInit executes after it. No ordering conflict.

## Data Flow

### zram activation flow

```
nerv.swap.zram.enable = true
    |
    v
swap.nix config block
    |
    v
zramSwap.enable = true
zramSwap.memoryPercent = cfg.memoryPercent
zramSwap.algorithm = "zstd"
    |
    v
NixOS zram.nix module (nixpkgs built-in)
    |
    v
systemd zram-setup@zram0.service (runs at boot)
    |
    v
/dev/zram0 created, mkswap, swapon
```

### starship prompt activation flow

```
nerv.zsh.starship.enable = true
    |
    v
zsh.nix inner config block
    |
    v
programs.starship.enable = true
programs.starship.enableZshIntegration = true
programs.starship.settings = { ... }
    |
    v
NixOS starship.nix module (nixpkgs built-in)
    |
    v
programs.zsh.promptInit += eval "$(starship init zsh)"
    |
    v
/etc/zshrc sources promptInit after interactiveShellInit
    |
    v
starship TOML written to /etc/starship.toml (from settings attrset)
```

### Key Data Flows

1. **zram + BTRFS coexistence:** zramSwap creates a kernel block device (/dev/zram0) entirely in RAM. It has no interaction with disko disk layouts. The BTRFS branch of disko.nix deliberately has no swap partition — zram fills that role cleanly with no conflict.
2. **zram + LVM coexistence:** The LVM branch already has a swap LV. Enabling zram.enable on a server profile results in both an on-disk swap LV and a zram swap device. Linux uses both in priority order (zramSwap.priority defaults to 5, higher than disk swap at 0). This is valid and is the user's choice — the module does not block it.
3. **starship config precedence:** `programs.starship.settings` writes `/etc/starship.toml`. If the user has `~/.config/starship.toml`, the init script exports `STARSHIP_CONFIG` only when that file does not exist, giving per-user override capability for free.

## Scaling Considerations

This is a per-machine library, not a service that scales. The relevant concern is module maintainability:

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 1 machine | Current structure is sufficient — swap.nix + zsh.nix modification |
| Many machines, different RAM sizes | nerv.swap.zram.memoryPercent option handles per-host tuning in hosts/configuration.nix |
| Server profile + zram | User opts in explicitly; documented trade-off (disk swap + zram both active) |

## Anti-Patterns

### Anti-Pattern 1: Adding zram config to disko.nix

**What people do:** Put zramSwap.enable inside the BTRFS branch of disko.nix since "BTRFS has no swap."
**Why it's wrong:** Conflates disk layout decisions with memory management. The LVM branch would then need mirrored logic or a flag to skip it. Cross-cutting concerns grow in complexity. The established pattern (from boot.nix splitting off from disko.nix) is to keep layout-conditional config in disko.nix and layout-agnostic config elsewhere.
**Do this instead:** New swap.nix with its own nerv.swap.zram.enable option, layout-agnostic. Users on BTRFS profile opt in; users on LVM profile may also opt in if they want zram alongside disk swap.

### Anti-Pattern 2: Adding zram config to boot.nix

**What people do:** Put zramSwap.enable in boot.nix because "swap is a boot concern."
**Why it's wrong:** boot.nix is documented as layout-agnostic initrd + bootloader. zram is not an initrd or bootloader concern — it activates in userspace via systemd. Adding it to boot.nix violates the documented scope and creates a file with mixed responsibility levels.
**Do this instead:** Dedicated swap.nix.

### Anti-Pattern 3: Separate nerv.starship module file

**What people do:** Create modules/services/starship.nix with a nerv.starship.enable option.
**Why it's wrong:** nerv.starship.enable without nerv.zsh.enable produces a broken configuration (starship init would be injected into programs.zsh.promptInit when programs.zsh.enable = false, which NixOS will either silently ignore or error on). The dependency is not enforced, creating a footgun.
**Do this instead:** Nest nerv.zsh.starship.enable inside zsh.nix so the dependency is structurally enforced: the starship config block is inside `lib.mkIf cfg.enable`, which already requires nerv.zsh.enable = true.

### Anti-Pattern 4: Manually sourcing starship in interactiveShellInit

**What people do:** Add `eval "$(starship init zsh)"` to the interactiveShellInit string in zsh.nix.
**Why it's wrong:** Duplicates work NixOS's programs.starship module already does. It breaks the module's config-file mechanism (STARSHIP_CONFIG export). It also fires before promptInit, potentially running twice or in the wrong order relative to other prompt setup.
**Do this instead:** Set `programs.starship.enable = true` and `enableZshIntegration = true`. The module handles injection at the correct point (promptInit, which runs after interactiveShellInit).

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| NixOS zramSwap module (nixpkgs built-in) | Set zramSwap.* options; NixOS handles systemd service creation | Available on all NixOS versions; no extra flake input needed |
| NixOS programs.starship module (nixpkgs built-in) | Set programs.starship.{enable,enableZshIntegration,settings}; NixOS injects into programs.zsh.promptInit | Requires programs.zsh.enable = true to be meaningful; no extra flake input needed |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| swap.nix to disko.nix | None — orthogonal | zram is RAM-only; no disk layout dependency |
| swap.nix to boot.nix | None — orthogonal | zram activates in userspace, not initrd |
| zsh.nix (starship) to programs.zsh | programs.starship.enableZshIntegration appends to programs.zsh.promptInit | promptInit runs after interactiveShellInit — no conflict with existing plugin load order |
| zsh.nix (starship) to interactiveShellInit | No direct interaction | Starship uses promptInit, plugins use interactiveShellInit — separate injection points |

## Build Order

**Implement zram first, starship second.**

Rationale:
1. swap.nix is a new file with no dependencies on other in-flight work. It can be written, tested, and closed independently.
2. The starship modification touches zsh.nix which is already tested and production. Working on it after swap.nix avoids touching two files simultaneously.
3. zram is lower risk — it sets three options on a well-understood NixOS built-in. A quick `nixos-rebuild test` confirms it works.
4. Starship requires writing a TOML config as a Nix attrset and verifying the two-line prompt aesthetic. This benefits from a clean diff against a known-working zsh.nix.

## Files Affected Summary

| File | Status | Change |
|------|--------|--------|
| modules/system/swap.nix | NEW | Full new module: nerv.swap.zram.{enable,memoryPercent} options + zramSwap config block |
| modules/system/default.nix | MODIFIED | Add `./swap.nix` import before `./secureboot.nix` |
| modules/services/zsh.nix | MODIFIED | Add nerv.zsh.starship.enable option + programs.starship block inside existing cfg.enable guard |
| modules/services/default.nix | no change | zsh.nix already imported |
| modules/system/disko.nix | no change | No swap concern in BTRFS branch; LVM swap LV unchanged |
| modules/system/boot.nix | no change | Not a boot/initrd concern |
| hosts/configuration.nix | no change | Users add nerv.swap.zram.enable and nerv.zsh.starship.enable per-machine; no structural change needed |

## Sources

- NixOS zramSwap options: https://mynixos.com/nixpkgs/options/zramSwap
- zramSwap.memoryPercent default (50): https://mynixos.com/nixpkgs/option/zramSwap.memoryPercent
- NixOS programs.starship module (release-25.11): https://github.com/NixOS/nixpkgs/blob/release-25.11/nixos/modules/programs/starship.nix
- NixOS Swap wiki: https://wiki.nixos.org/wiki/Swap
- zramSwap + zswap performance discussion: https://discourse.nixos.org/t/configuring-zram-and-zswap-parameters-for-optimal-performance/47852

---
*Architecture research for: nerv.nixos v3.0 — zram swap + starship prompt*
*Researched: 2026-03-12*
