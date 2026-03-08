# Phase 3: System Modules (non-boot) - Context

**Gathered:** 2026-03-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Migrate `hardware.nix`, `kernel.nix`, `security.nix`, and `nix.nix` into `modules/system/` and expose identity, locale, primary user, and hardware options via the `nerv.*` API. The `modules/system/default.nix` aggregator (currently an empty stub from Phase 1) is populated with the migrated modules. Boot/LUKS/initrd configuration stays in `hosts/nixos-base/configuration.nix` — that is Phase 4's job.

Requirements: OPT-01, OPT-02, OPT-03, OPT-04

</domain>

<decisions>
## Implementation Decisions

### security.nix — fully opaque
- All hardening stays always-on: AppArmor, auditd, ClamAV (daemon + updater), AIDE (daily check timer)
- No `nerv.*` options exposed for security.nix — consistent with Phase 2 fail2ban/endlessh decision
- AIDE runs daily; freshclam runs 24×/day — frequencies hardcoded, not exposed as options
- Baseline audit ruleset (execve, openat, connect, setuid/setgid, critical file writes) is locked in
- `lib.mkForce` is the documented escape hatch for any overrides

### nix.nix — path fix, autoUpgrade stays on
- Fix stale `system.autoUpgrade.flake` from `/etc/nixos#nixos` → `/etc/nerv#nixos-base`
- `system.autoUpgrade.enable = true` remains — stays default-on, `allowReboot = false`
- `nixpkgs.config.allowUnfree = true` stays hardcoded — required for firmware/microcode packages; not exposed as option
- No `nerv.*` options added to nix.nix in Phase 3 — the v2 roadmap item `OPT-V2-01` (nerv.nix.autoUpdate toggle) covers future optionisation
- GC and optimise settings (weekly, 20-day retention) stay hardcoded

### nerv.primaryUser — list, groups + shell wiring
- `nerv.primaryUser` is a **list of strings** (e.g. `[ "demon0" ]`) — supports multi-user from v1
- Wires **groups only**: each listed user gets `extraGroups = [ "wheel" "networkmanager" ]` via `users.users.<name>` extension
- Does **not** own full user declaration — host flake still provides `users.users.<name> = { isNormalUser = true; ... }`
- **Shell auto-wiring**: when `nerv.zsh.enable = true` and `nerv.primaryUser` is non-empty, each listed user gets `shell = pkgs.zsh` set automatically
- Type: `types.listOf types.str`, default `[]`

### hardware.nix — CPU-conditional params
- `hardware.nix` owns **both** microcode **and** CPU-specific kernel params (removed from kernel.nix)
- `nerv.hardware.cpu` enum: `"amd"` | `"intel"` | `"other"`
  - `"amd"`: `hardware.cpu.amd.updateMicrocode = true` + kernel params `amd_iommu=on iommu=pt`
  - `"intel"`: `hardware.cpu.intel.updateMicrocode = true` + kernel params `intel_iommu=on iommu=pt`
  - `"other"`: no microcode, no IOMMU kernel params; firmware blobs still applied (they are CPU-agnostic)
- `nerv.hardware.gpu` enum: `"amd"` | `"nvidia"` | `"intel"` | `"none"`
  - `"nvidia"`: `services.xserver.videoDrivers = [ "nvidia" ]` + `hardware.nvidia.open = true` (open kernel module — Turing+ / RTX 20xx+)
  - `"amd"`: `services.xserver.videoDrivers = [ "amdgpu" ]`
  - `"intel"`: `services.xserver.videoDrivers = [ "intel" ]` (or modesetting)
  - `"none"`: no GPU driver configuration
- Firmware blobs (`hardware.enableRedistributableFirmware`, `hardware.enableAllFirmware`) and `services.fwupd` / `services.fstrim` remain unconditional (hardware-agnostic utilities)

### kernel.nix — generic hardening only after CPU param removal
- Remove `amd_iommu=on` and `iommu=pt` from kernel.nix (moved to hardware.nix behind cpu option)
- All other boot.kernelParams (memory hardening, CPU vulnerability mitigations, attack surface reduction) stay hardcoded
- `boot.kernel.sysctl` (network, kernel, memory, filesystem hardening) stays hardcoded
- `boot.blacklistedKernelModules` stays hardcoded
- `boot.kernelPackages = lib.mkForce pkgs.linuxPackages_zen` stays — no option to change kernel package in v1 (v2: OPT-V2-02)

### identity module — new file
- New file `modules/system/identity.nix` handles hostname + locale options
- `nerv.hostname` (type: `types.str`, no default — required) sets `networking.hostName`
- `nerv.locale.timeZone` (type: `types.str`, default `"UTC"`) sets `time.timeZone`
- `nerv.locale.defaultLocale` (type: `types.str`, default `"en_US.UTF-8"`) sets `i18n.defaultLocale`
- `nerv.locale.keyMap` (type: `types.str`, default `"us"`) sets `console.keyMap`

### Claude's Discretion
- Exact NixOS module option descriptions and example values
- Whether to use `lib.mkMerge` or `lib.optionalAttrs` for the CPU-conditional group extension in primaryUser
- Whether identity.nix includes `console.font` / `console.packages` (terminus) or leaves that to host flake
- Order of imports in `modules/system/default.nix`
- Whether to assert `nerv.hostname != ""` or rely on type constraints

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `modules/hardware.nix`: firmware blobs + AMD microcode + fwupd + fstrim — wrap microcode and IOMMU params behind `nerv.hardware.cpu` mkIf; rest stays unconditional
- `modules/kernel.nix`: remove `amd_iommu=on` / `iommu=pt` lines; all other params carry over verbatim
- `modules/security.nix`: migrate as-is — fully opaque, no option wrapping needed; just move to modules/system/
- `modules/nix.nix`: migrate with single path fix (`/etc/nixos#nixos` → `/etc/nerv#nixos-base`); no structural changes
- `hosts/nixos-base/configuration.nix`: has identity fields (hostname, timeZone, locale, keyMap, users.users.demon0) that will be replaced by `nerv.*` option calls after Phase 3

### Established Patterns
- Phase 2 options pattern: `options.nerv.<service>.<opt> = lib.mkOption { type = ...; default = ...; description = "..."; };` — same for hardware and identity options
- `mkIf cfg.enable` guard for enable-only modules; `mkIf (cfg.cpu == "amd")` for conditional hardware params
- `modules/services/default.nix` is the aggregator pattern — `modules/system/default.nix` follows identically
- Phase 2 confirmed: `lib.mkForce` is the documented escape hatch, not fine-grained options

### Integration Points
- `modules/system/default.nix` (currently `{ imports = []; }`) will grow: identity.nix, hardware.nix, kernel.nix, security.nix, nix.nix
- `hosts/nixos-base/configuration.nix` sets `nerv.*` options — after Phase 3, identity and hardware options are declared there (same pattern as `nerv.openssh.*`, `nerv.audio.enable` etc.)
- `nerv.primaryUser` shell wiring cross-references `nerv.zsh.enable` — both modules are in scope (services/zsh.nix already exists)
- Build verification: `nixos-rebuild build --flake .#nixos-base` must pass after all migrations

</code_context>

<specifics>
## Specific Ideas

- `nerv.primaryUser` as a list enables the common pattern `nerv.primaryUser = [ "demon0" ]` with room for a second user without API changes
- The CPU param split keeps kernel.nix as a pure hardening file and hardware.nix as the machine identity file — reviewers can read hardware.nix to understand the full hardware profile without scanning kernel.nix
- nvidia-open path: `hardware.nvidia.open = true` is the NVIDIA recommendation for Turing+ — document in the module that Maxwell/Pascal users must override with `hardware.nvidia.open = lib.mkForce false`

</specifics>

<deferred>
## Deferred Ideas

- `nerv.nix.autoUpdate` toggle (default false) — v2 roadmap OPT-V2-01
- `nerv.kernel.package` option to override kernel package — v2 roadmap OPT-V2-02
- `nerv.nix.gcInterval` option — v2 roadmap OPT-V2-03
- `nerv.security.audit.extraRules` additive option — considered but deferred; lib.mkForce covers edge cases for v1
- Per-service security toggles (ClamAV, AppArmor, audit) — deferred; opaque posture is v1 intent

</deferred>

---

*Phase: 03-system-modules-non-boot*
*Context gathered: 2026-03-07*
