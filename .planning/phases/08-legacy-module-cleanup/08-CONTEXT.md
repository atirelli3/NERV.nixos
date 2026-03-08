# Phase 8: NERV.nixos Release & Multi-Profile Migration - Context

**Gathered:** 2026-03-08
**Status:** Ready for planning
**Source:** PRD Express Path (user requirements)

<domain>
## Phase Boundary

This phase graduates all refined work from the test-nerv.nixos development repo into the public NERV.nixos repo (`git@github.com:atirelli3/NERV.nixos.git`). It also extends the impermanence module for full server impermanence, defines three inline host profiles in flake.nix, and resets the test repo to its original baseline commit.

Deliverables:
- Dead flat modules deleted (cleanup)
- Full impermanence mode added to impermanence.nix (server use case)
- Three profiles (host, server, vm) defined inline in flake.nix
- NERV.nixos repo receives the complete refined structure
- test-nerv.nixos reset to commit cab4126e8664a808eef482154a8500106ae22246

</domain>

<decisions>
## Implementation Decisions

### Target Repository
- New repo: `git@github.com:atirelli3/NERV.nixos.git`
- Placed at `/etc/nixos` during installation (user clones it there)
- `.git` must be tracked (users pull further updates from NERV.nixos)

### Directory Structure in NERV.nixos
Exact structure that must be present:
```
/etc/nixos (NERV.nixos repo root)
├── home/
│   └── default.nix          # HM wiring module
├── hosts/
│   ├── configuration.nix    # machine identity only
│   ├── disko-configuration.nix
│   └── hardware-configuration.nix
├── modules/
│   ├── default.nix
│   ├── services/
│   │   └── *.nix            # service modules
│   └── system/
│       └── *.nix            # system modules
└── flake.nix
```

### Profile Strategy (Preferred: inline in flake.nix)
All nerv module settings defined as inline module lambdas inside flake.nix — NOT in hosts/configuration.nix. Three profiles:

**hostProfile** (classic desktop):
- openssh: enabled
- audio (PipeWire): enabled
- bluetooth: enabled
- printing: enabled
- secureboot: false (user enables after sbctl setup)
- impermanence: minimal mode (only /tmp, /var/tmp as tmpfs)

**serverProfile**:
- openssh: enabled (only service)
- impermanence: full mode (/ as tmpfs, /persist for state)
- audio/bluetooth/printing: disabled

**vmProfile**:
- Composable from hostProfile defaults
- secureboot: disabled
- Easy to customize based on task (host-like or server-like)

**hosts/configuration.nix covers only:**
- nerv.hostname
- nerv.primaryUser
- nerv.hardware.cpu / nerv.hardware.gpu
- nerv.locale.timeZone / defaultLocale / keyMap
- system.stateVersion
- disko disk device placeholder

### Fallback (if inline profiles not feasible)
If inline module lambdas in flake.nix prove unworkable, create `hosts/configuration.nix` with ALL nerv module options listed per section, all commented out — user removes comments to enable/disable. This is the fallback only.

### Full Impermanence Design (server profile)
References:
- https://xeiaso.net/blog/paranoid-nixos-2021-07-18/
- https://www.willbush.dev/blog/impermanent-nixos/

Full impermanence means:
- `/` is a tmpfs (reset on every reboot)
- `/nix` is persistent (the Nix store — ext4)
- `/persist` is persistent (system state — ext4)
- `/boot` is persistent (EFI — vfat)
- Selective persistence via `environment.persistence` from `nixos-community/impermanence` module
- The `impermanence` flake input (already in flake.nix) becomes actually used

Implementation:
- Add `nerv.impermanence.mode` option: `"minimal"` (default, current behavior) | `"full"` (server)
- `"minimal"`: mounts /tmp, /var/tmp as tmpfs (current behavior, unchanged)
- `"full"`: requires impermanence nixos module, sets up environment.persistence, declares what to persist
- Server disko layout needs NIXPERSIST + NIXSTORE + NIXBOOT partitions with tmpfs root

### Legacy Module Cleanup
Delete these 9 dead flat files (no aggregator imports them):
- modules/openssh.nix
- modules/pipewire.nix
- modules/bluetooth.nix
- modules/printing.nix
- modules/zsh.nix
- modules/kernel.nix
- modules/security.nix
- modules/nix.nix
- modules/hardware.nix

### Test Repo Reset
After NERV.nixos is pushed:
- Reset test-nerv.nixos to `cab4126e8664a808eef482154a8500106ae22246`
- This is a `git reset --hard` — user must confirm this step
- The planning/.template directories are preserved in NERV.nixos but not needed in the reset state

### Claude's Discretion
- Exact `environment.persistence` declarations for server (what paths to persist: /etc/nixos, /var/lib/*, etc.) — reference implementations consulted during research
- Whether to add `impermanence` module to flake.nix nixosModules exports or only use internally
- Commit message strategy for NERV.nixos initial push
- Whether server disko-configuration.nix needs updating for tmpfs root layout
- How to handle the `server/` and `vm/` directories in the current repo (migrate useful parts, discard stubs)

</decisions>

<specifics>
## Specific Ideas

**Impermanence references (MUST consult during research):**
- https://xeiaso.net/blog/paranoid-nixos-2021-07-18/
- https://www.willbush.dev/blog/impermanent-nixos/

**NERV.nixos repo:** `git@github.com:atirelli3/NERV.nixos.git`

**Baseline commit to reset to:** `cab4126e8664a808eef482154a8500106ae22246`

**Disk layout for server full impermanence (from server/disko-configuration.nix):**
- ESP → NIXBOOT (vfat)
- LUKS → LVM → NIXSWAP, NIXSTORE (/nix), NIXPERSIST (/persist), NIXROOT (/ tmpfs or small ext4), NIXHOME (/home tmpfs or via persist)

**Inline profile pattern in flake.nix:**
```nix
let
  hostProfile = { nerv.openssh.enable = true; nerv.audio.enable = true; ... };
  serverProfile = { nerv.impermanence = { enable = true; mode = "full"; }; ... };
in {
  nixosConfigurations = {
    host   = nixpkgs.lib.nixosSystem { modules = [ self.nixosModules.default hostProfile ./hosts/configuration.nix ... ]; };
    server = nixpkgs.lib.nixosSystem { modules = [ self.nixosModules.default serverProfile ./hosts/configuration.nix ... ]; };
    vm     = nixpkgs.lib.nixosSystem { modules = [ self.nixosModules.default vmProfile ./hosts/configuration.nix ... ]; };
  };
}
```

</specifics>

<deferred>
## Deferred Ideas

- Full home impermanence ($HOME on tmpfs) — marked out-of-scope in PROJECT.md
- DE/WM/DM configuration — user responsibility
- Multi-host examples beyond the three profiles — post v1.0
- Automated install script — separate concern

</deferred>

---

*Phase: 08-legacy-module-cleanup*
*Context gathered: 2026-03-08 via PRD Express Path (user requirements session)*
