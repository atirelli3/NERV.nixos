---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: Phase Details
status: planning
stopped_at: Completed 10-01-PLAN.md (Phase 10 Plan 01)
last_updated: "2026-03-10T08:18:17.623Z"
last_activity: 2026-03-09 — v2.0 roadmap created (phases 9–12)
progress:
  total_phases: 12
  completed_phases: 9
  total_plans: 27
  completed_plans: 26
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-09)

**Core value:** A user declares only their machine-specific parameters and gets a secure, well-documented NixOS system out of the box.
**Current focus:** v2.0 — Stateless Disk Layout (phases 9–12)

## Current Position

Phase: Phase 9 — BTRFS Disko Layout (not started)
Plan: —
Status: Roadmap complete, ready to plan Phase 9
Last activity: 2026-03-09 — v2.0 roadmap created (phases 9–12)

Progress: [░░░░░░░░░░] 0% (v2.0 milestone)

## Performance Metrics

**Velocity:**
- Total plans completed: 0 (v2.0)
- Average duration: —
- Total execution time: 0 hours

**By Phase (v2.0):**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 9. BTRFS Disko Layout | - | - | - |
| 10. initrd BTRFS Rollback Service | - | - | - |
| 11. Impermanence BTRFS Mode | - | - | - |
| 12. Profile Wiring and Documentation | - | - | - |

**Recent Trend:**
- Last 5 plans: —
- Trend: —

*Updated after each plan completion*

**v1.0 Historical (complete):**
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
| Phase 09-btrfs-disko-layout P01 | 2 | 1 tasks | 1 files |
| Phase 09-btrfs-disko-layout P02 | 1 | 2 tasks | 1 files |
| Phase 10-initrd-btrfs-rollback-service P01 | 2 | 2 tasks | 2 files |

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
- [Phase 08-legacy-module-cleanup]: .planning/ copied to NERV.nixos before reset — full project planning context (PROJECT.md, ROADMAP.md, REQUIREMENTS.md, STATE.md, all phase plans/summaries) preserved in public repo for continued GSD workflow
- [Phase 09-btrfs-disko-layout]: nerv.disko.layout has no default — forces explicit declaration per host, consistent with nerv.hostname pattern
- [Phase 09-btrfs-disko-layout]: sharedEsp and sharedLuksOuter let bindings factor shared disk partition config for both BTRFS and LVM branches
- [Phase 09-btrfs-disko-layout]: @root-blank declared as empty attrset with no mountpoint — Phase 10 rollback snapshot baseline
- [Phase 09-btrfs-disko-layout]: All impermanence.mode references removed from disko.nix — depends only on cfg.layout
- [Phase 09-btrfs-disko-layout]: nerv.disko.layout = PLACEHOLDER intentionally invalid — forces operator to set btrfs or lvm before building, same pattern as nerv.hostname
- [Phase 09-btrfs-disko-layout]: nerv.disko.lvm.* declared unconditionally in configuration.nix — self-documenting; module only reads them when layout = lvm
- [Phase 10-initrd-btrfs-rollback-service]: All layout-conditional initrd config lives in disko.nix — co-location prevents LVM initrd hang on BTRFS hosts (lvm.enable, dm-snapshot would scan for non-existent PV)
- [Phase 10-initrd-btrfs-rollback-service]: boot.initrd.luks.devices.cryptroot declared unconditionally in disko.nix third mkMerge entry — preLVM omitted (silently ignored by systemd stage 1)
- [Phase 10-initrd-btrfs-rollback-service]: rollback service ordering: after=dev-mapper-cryptroot.device, before=sysroot.mount — LUKS must be open before BTRFS mount attempt

### v2.0 Decisions (pre-phase)

- [v2.0 pre-phase]: No new flake inputs required — disko v1.13.0 and impermanence already pinned and wired in all nixosConfigurations
- [v2.0 pre-phase]: BTRFS rollback MUST use boot.initrd.systemd.services.rollback — boot.initrd.postDeviceCommands is incompatible with boot.initrd.systemd.enable = true (already set in boot.nix)
- [v2.0 pre-phase]: Rollback script device path is /dev/mapper/cryptroot (not by-label) — BTRFS label is inside LUKS, inaccessible by label until after unlock; "cryptroot" is the LUKS mapping name confirmed in boot.nix
- [v2.0 pre-phase]: No swap in BTRFS layout — BTRFS CoW is incompatible with swap files; simpler to emit no swap device in the btrfs branch
- [v2.0 pre-phase]: @nix is a mandatory separate subvolume — if /nix is on @ it gets deleted by rollback; system becomes unbootable on next boot
- [v2.0 pre-phase]: /var/log excluded from environment.persistence in btrfs mode — @log subvolume handles log persistence; bind-mount would conflict (double-mount)
- [v2.0 pre-phase]: LVM initrd services (lvm.enable, preLVM, dm-snapshot) must be disabled when layout = "btrfs" — device has no LVM PV; unconditional activation causes initrd hang
- [v2.0 pre-phase]: @root-blank must be a read-only snapshot created manually after disko run, before nixos-install — cannot be automated in disko; must be documented in install procedure (PROF-04)

### Pending Todos

- Verify exact systemd device unit name for /dev/mapper/cryptroot in NixOS 25.11 during Phase 10 implementation (`systemctl list-units | grep cryptroot`)
- Verify disko v1.13.0 neededForBoot support on BTRFS subvolume mounts during Phase 11 implementation (may need fileSystems."..." = { neededForBoot = true; } override)

### Blockers/Concerns

None at roadmap creation. Research flags noted above become implementation verification tasks.

## Session Continuity

Last session: 2026-03-10T08:18:17.621Z
Stopped at: Completed 10-01-PLAN.md (Phase 10 Plan 01)
Resume file: None
Next action: /gsd:plan-phase 9
