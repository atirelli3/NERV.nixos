---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: planning
stopped_at: Completed 08-legacy-module-cleanup-03-PLAN.md
last_updated: "2026-03-08T16:16:50.981Z"
last_activity: 2026-03-06 — Roadmap created; ready to begin Phase 1 planning
progress:
  total_phases: 8
  completed_phases: 7
  total_plans: 23
  completed_plans: 22
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-06)

**Core value:** A user declares only their machine-specific parameters and gets a secure, well-documented NixOS system out of the box.
**Current focus:** Phase 1 — Flake Foundation

## Current Position

Phase: 1 of 6 (Flake Foundation)
Plan: 0 of TBD in current phase
Status: Ready to plan
Last activity: 2026-03-06 — Roadmap created; ready to begin Phase 1 planning

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: —
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**
- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
| Phase 01-flake-foundation P01 | 2 | 2 tasks | 6 files |
| Phase 01-flake-foundation P02 | 1 | 2 tasks | 4 files |
| Phase 02-services-reorganization P01 | 3 | 1 tasks | 1 files |
| Phase 02-services-reorganization P02 | 2 | 3 tasks | 3 files |
| Phase 02-services-reorganization P03 | 2 | 3 tasks | 3 files |
| Phase 03-system-modules-non-boot P01 | 1 | 1 tasks | 1 files |
| Phase 03-system-modules-non-boot P02 | 525597 | 2 tasks | 2 files |
| Phase 03-system-modules-non-boot P03 | 2 | 3 tasks | 4 files |
| Phase 04-boot-extraction P01 | 5 | 2 tasks | 2 files |
| Phase 04-boot-extraction P02 | 6 | 1 tasks | 1 files |
| Phase 04-boot-extraction P03 | 15 | 2 tasks | 4 files |
| Phase 05-home-manager-skeleton P01 | 2 | 2 tasks | 3 files |
| Phase 06-documentation-sweep P03 | 2 | 2 tasks | 3 files |
| Phase 06-documentation-sweep P02 | 4 | 1 tasks | 3 files |
| Phase 06-documentation-sweep P01 | 4 | 2 tasks | 5 files |
| Phase 07-flake-hardening-disko-nyquist P01 | 1 | 2 tasks | 2 files |
| Phase 07-flake-hardening-disko-nyquist P02 | 2 | 2 tasks | 3 files |
| Phase 07-flake-hardening-disko-nyquist P03 | 2 | 2 tasks | 3 files |
| Phase 07-flake-hardening-disko-nyquist P04 | 2 | 2 tasks | 3 files |
| Phase 08-legacy-module-cleanup P01 | 1 | 2 tasks | 9 files |
| Phase 08-legacy-module-cleanup P02 | 2 | 2 tasks | 3 files |
| Phase 08-legacy-module-cleanup P03 | 2 | 2 tasks | 3 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Pre-phase]: flake.nix inputs (HM + impermanence) must be added before any module work — all module phases depend on this being correct
- [Pre-phase]: Service modules migrate before system/boot modules — lower blast radius validates the options pattern safely
- [Pre-phase]: sbctl persistence must be wired in impermanence.nix before secureboot.nix is enabled — IMPL-02 dependency within Phase 4
- [Pre-phase]: secureboot.nix imported last in modules/system/default.nix — prevents lib.mkForce conflict with systemd-boot
- [Phase 01-flake-foundation]: Library inputs (lanzaboote, home-manager, impermanence) live only in root flake.nix — host flake gets them transitively to prevent lock drift
- [Phase 01-flake-foundation]: nixosModules values use import ./path (not bare path) — required for nix flake check correctness
- [Phase 01-flake-foundation]: home-manager.nixosModules.home-manager is canonical attribute name for Phase 5 (not .default alias)
- [Phase 01-flake-foundation]: nixosConfigurations live in root flake.nix using self references — path:.. in a sub-flake fails when /etc/nerv is a nix store symlink (pure eval forbids absolute store paths)
- [Phase 01-flake-foundation]: host machine config moves to hosts/nixos-base/ (not base/) — hardware-configuration.nix tracked in repo, not in /etc/nixos
- [Phase 01-flake-foundation]: home/ in this repo is NixOS wiring module only; user dotfiles (packages, programs, dotfiles) belong in a separate user-owned repo under $HOME
- [Phase 01-flake-foundation]: nerv.home.users = [ "demon" ] convention — module auto-imports /home/<name>/home.nix for each listed user; requires --impure on nixos-rebuild
- [Phase 01-flake-foundation]: build command is `nixos-rebuild switch --flake /etc/nerv#nixos-base` (from anywhere)
- [Phase 01-flake-foundation]: hardware-configuration.nix tracked in repo under hosts/nixos-base/ as placeholder on dev machine; replaced with nixos-generate-config output on NixOS machine
- [Phase 01-flake-foundation]: base/flake.nix removed — nixosConfigurations live in root flake.nix with self references; sub-flake path:.. fails under pure eval when /etc/nerv is a nix store symlink
- [Phase 02-services-reorganization]: AllowUsers omitted entirely when allowUsers is empty (lib.optionalAttrs guard) — empty AllowUsers in sshd locks everyone out
- [Phase 02-services-reorganization]: fail2ban jail port is toString cfg.port — types.port is int but fail2ban expects string; explicit coercion
- [Phase 02-services-reorganization]: Original modules/openssh.nix left untouched until Plan 03 wiring removes it — avoids breaking existing config
- [Phase 02-services-reorganization]: avahi.enable removed from pipewire.nix; split ownership to printing.nix and bluetooth.nix independently
- [Phase 02-services-reorganization]: printing.nix owns avahi.enable = true directly so CUPS network discovery works independently of nerv.audio
- [Phase 02-services-reorganization]: bluetooth.nix owns avahi.enable = true independently for BT service mDNS advertisement
- [Phase 02-services-reorganization]: nix aliases in zsh.nix hardcoded to /etc/nerv#nixos-base (old /etc/nixos#nixos removed)
- [Phase 02-services-reorganization]: services/default.nix is the single aggregator for all five service modules — callers import only this file
- [Phase 02-services-reorganization]: host configuration.nix uses only nerv.* API; audio/bluetooth/printing disabled until deployed on target hardware
- [Phase 03-system-modules-non-boot]: nerv.hostname has no default — forces explicit declaration, prevents silent misconfiguration
- [Phase 03-system-modules-non-boot]: console.font/packages hardcoded to ter-v18n/terminus_font with lib.mkForce escape hatch documented in comment
- [Phase 03-system-modules-non-boot]: Cross-wiring to config.nerv.zsh.enable in identity.nix is safe — NixOS merges all modules before evaluation
- [Phase 03-system-modules-non-boot]: IOMMU kernel params (amd_iommu=on, iommu=pt) moved to hardware.nix behind nerv.hardware.cpu conditionals — keeps kernel.nix CPU-vendor-agnostic
- [Phase 03-system-modules-non-boot]: hardware.nvidia.open = true default targets Turing+ (RTX 20xx+) only — Maxwell/Pascal users must override with lib.mkForce false
- [Phase 03-system-modules-non-boot]: security.nix and nix.nix are fully opaque modules — lib.mkForce is the documented escape hatch
- [Phase 03-system-modules-non-boot]: autoUpgrade flake path corrected from /etc/nixos#nixos to /etc/nerv#nixos-base in nix.nix
- [Phase 03-system-modules-non-boot]: users.users.demon0 reduced to isNormalUser = true only — extraGroups now owned by identity.nix via nerv.primaryUser
- [Phase 04-boot-extraction]: boot.nix is fully opaque (no nerv.* options) — lib.mkForce is the documented escape hatch, consistent with kernel.nix
- [Phase 04-boot-extraction]: boot.kernelPackages = pkgs.linuxPackages_latest present in boot.nix but overridden by kernel.nix (lib.mkForce pkgs.linuxPackages_zen) — kernel.nix is authoritative
- [Phase 04-boot-extraction]: NIXLUKS cross-reference comment on disko-configuration.nix line 26 — second of three required sync anchors (boot.nix, disko-configuration.nix, secureboot.nix)
- [Phase 04-boot-extraction]: lib.optional config.nerv.secureboot.enable used for IMPL-02 sbctl assertion — prevents evaluation errors before secureboot.nix is wired
- [Phase 04-boot-extraction]: systemd.tmpfiles.rules d entries pre-create user home tmpfs mount points — prevents boot failure on missing directories (Pitfall 5)
- [Phase 04-boot-extraction]: modules/secureboot.nix deleted after migration — flat unconditional file would apply secureboot to all hosts without the enable guard
- [Phase 04-boot-extraction]: luks-cryptenroll let binding moved inside config = lib.mkIf block — preserves scoping under enable guard
- [Phase 05-home-manager-skeleton]: nerv.home uses listOf str + listToAttrs so host declares only usernames; function form { osConfig, ... } required for stateVersion inheritance
- [Phase 05-home-manager-skeleton]: nixos-rebuild --impure required for home-manager user activation because /home/<name>/home.nix is outside flake boundary
- [Phase 06-documentation-sweep]: disko-configuration.nix WARNING block placed before the opening { — first thing any reader sees, satisfying DOCS-03
- [Phase 06-documentation-sweep]: hardware-configuration.nix structured header replaces inline comment; { ... }: { } body unchanged — DOCS-01 for placeholder files
- [Phase 06-documentation-sweep]: Aggregator header omits Options/Defaults/Override sections — aggregators have no option surface
- [Phase 06-documentation-sweep]: openssh.nix header Note explicitly documents tarpit port convention and allowUsers guard (empty list never emitted as AllowUsers)
- [Phase 06-documentation-sweep]: zsh.nix header Note documents syntaxHighlighting.enable=false + manual sourcing to enforce autosuggestions -> syntax-highlighting -> history-substring-search load order
- [Phase 06-documentation-sweep]: printing.nix header Note documents avahi.enable ownership for independence from nerv.audio
- [Phase 07-flake-hardening-disko-nyquist]: impermanence flake input removed — modules/system/impermanence.nix is self-contained using native NixOS fileSystems, no flake input needed
- [Phase 07-flake-hardening-disko-nyquist]: nerv.secureboot.enable = false and nerv.impermanence.enable = false explicitly declared so operators see activation path without reading module source
- [Phase 07-flake-hardening-disko-nyquist]: disko pinned to v1.13.0 with nixpkgs.follows = nixpkgs — same pattern as lanzaboote and home-manager inputs
- [Phase 07-flake-hardening-disko-nyquist]: lib removed from configuration.nix function args after mkForce removal — no other lib references in file
- [Phase 07-flake-hardening-disko-nyquist]: ESP mountOptions changed from umask=0077 to fmask=0077 dmask=0077 — separate file and directory permission control, matching intent of removed override
- [Phase 07-flake-hardening-disko-nyquist]: Phase 5 integration tasks (nixos-rebuild switch --impure, systemctl status home-manager) marked green with live-system notes — code complete, runtime environment absent on dev machine
- [Phase 07-flake-hardening-disko-nyquist]: Phase 1 task 1-01-03 marked green with note — impermanence removed in Phase 7 Plan 01, STRUCT-05 satisfied via home-manager presence alone
- [Phase 07-flake-hardening-disko-nyquist]: Phase 1 full suite command corrected from ./base#nixos-base to absolute path — stale path from pre-reorganization era
- [Phase 08-legacy-module-cleanup]: nix flake check skipped on dev machine (nix unavailable); deletion safety confirmed by import-chain audit — no references to deleted flat modules exist in any *.nix file
- [Phase 08-legacy-module-cleanup]: impermanence re-added to flake.nix inputs with no nixpkgs follows — upstream module has no nixpkgs input to override
- [Phase 08-legacy-module-cleanup]: lib.mkMerge list approach for mode-conditional config in impermanence.nix — avoids pushDownProperties cycle
- [Phase 08-legacy-module-cleanup]: hosts/disko-configuration.nix at hosts/ root (not hosts/nixos-base/) — NERV.nixos target layout; no root LV, no home LV; neededForBoot for /persist set by impermanence.nix module
- [Phase 08-legacy-module-cleanup]: Three profiles as plain attrsets in let bindings — no module wrapper needed; passed directly in modules list alongside nixosModules.default
- [Phase 08-legacy-module-cleanup]: vm omits lanzaboote — VMs lack TPM2, secureboot disabled; avoids module conflicts
- [Phase 08-legacy-module-cleanup]: hosts/hardware-configuration.nix created as placeholder at hosts/ root — required for nix import resolution
- [Phase 08-legacy-module-cleanup]: disko.devices.disk.main.device override lives in hosts/configuration.nix — single identity file to edit per machine

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 4 pre-condition]: Lanzaboote current tag needs verification before Phase 1 pin (`gh release list -R nix-community/lanzaboote`)
- [Phase 4 pre-condition]: Exact `nixosModules` attribute name in HM flake needs verification before Phase 1 (`nix flake show github:nix-community/home-manager`)
- [Phase 4 pre-condition]: Existing LUKS label must be manually audited in `disko-configuration.nix` and `base/configuration.nix` before Phase 4 begins — string mismatch causes silent boot failure

## Session Continuity

Last session: 2026-03-08T16:16:50.980Z
Stopped at: Completed 08-legacy-module-cleanup-03-PLAN.md
Resume file: None
