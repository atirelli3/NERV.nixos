# Phase 4: Boot Extraction - Context

**Gathered:** 2026-03-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Extract boot/LUKS/initrd/loader configuration from `hosts/nixos-base/configuration.nix` into a new `modules/system/boot.nix` library module. Create `modules/system/impermanence.nix` with selective per-directory tmpfs mounts for system and user dirs. Migrate `modules/secureboot.nix` (old flat location) to `modules/system/secureboot.nix` and wrap it with the `nerv.secureboot.enable` guard. Wire all three into `modules/system/default.nix` (secureboot last).

Requirements: STRUCT-02, IMPL-01, IMPL-02, IMPL-03

</domain>

<decisions>
## Implementation Decisions

### boot.nix — fully opaque, initrd+loader+LUKS only
- Fully opaque module — no `nerv.boot.*` options exposed; `lib.mkForce` is the documented escape hatch
- Consistent with kernel.nix, security.nix posture
- **Scope:** owns `boot.initrd.*` (systemd, lvm, kernelModules, luks device) and `boot.loader.*` (systemd-boot + EFI)
- **Does NOT own:** `fileSystems` (NIXBOOT/NIXROOT) and `swapDevices` (NIXSWAP) — these stay in `hosts/nixos-base/configuration.nix` as they are host-specific hardware labels and Disko overrides
- `boot.kernelPackages = pkgs.linuxPackages_latest` is set in boot.nix (matches current configuration.nix); `kernel.nix` overrides it with `lib.mkForce pkgs.linuxPackages_zen` — comment in boot.nix documents this intentional override relationship

### LUKS label — hardcoded + cross-reference comments
- No `nerv.boot.luksLabel` option — `NIXLUKS` stays hardcoded in all files
- **Cross-reference comments required in all three files:**
  - `modules/system/boot.nix`: comment noting label must match `disko-configuration.nix`
  - `hosts/nixos-base/disko-configuration.nix`: comment noting label must match `boot.nix` and `secureboot.nix`
  - `modules/system/secureboot.nix`: comment noting label must match `boot.nix` and `disko-configuration.nix`
- Satisfies DOCS-04 requirement

### impermanence.nix — selective per-directory tmpfs
- Architecture: **selective per-directory tmpfs mounts** — NOT full root-on-tmpfs
  - Root `/` stays on disk (ext4); specific directories are mounted as tmpfs
  - The upstream NixOS impermanence module (`environment.persistence`) is NOT used
- **`nerv.impermanence.persistPath`** (default `/persist`) is kept in the options API for forward compatibility but documented as unused/limited in the selective model
- **`nerv.impermanence.extraDirs`** is a list of absolute system paths to mount as tmpfs (additive to the hardcoded defaults)
- **Default system tmpfs mounts** (active when `nerv.impermanence.enable = true`):
  - `/tmp` — size 25% RAM
  - `/var/tmp` — size 25% RAM
- **Default user tmpfs mounts** (active for all users in `nerv.primaryUser` when enable = true):
  - `~/Desktop` — size 25% RAM
  - `~/Downloads` — size 25% RAM
- **Default tmpfs size:** `size=25%` (standard Linux tmpfs default; scales with RAM) unless overridden per-dir

### nerv.impermanence.users.<name> — attrset with size overrides
- Type: `types.attrsOf types.str` — keys are absolute paths, values are size strings
- Example: `nerv.impermanence.users.demon0 = { "/home/demon0/Videos" = "8G"; "/home/demon0/Projects" = "4G"; };`
- These are additional per-user tmpfs mounts beyond the default Desktop/Downloads

### IMPL-02 — sbctl safety assertion
- In the selective tmpfs model, `/var/lib/sbctl` is on disk by default and safe
- When `nerv.impermanence.enable = true AND nerv.secureboot.enable = true`: module adds an assertion that `/var/lib/sbctl` (or any prefix of it) is NOT present in `extraDirs` or any `users.<name>` value
- Prevents accidental sbctl wipe via misconfigured impermanence config
- Evaluation fails with a clear error message if violated

### secureboot.nix migration
- Migrated from `modules/secureboot.nix` (flat, unconditional) to `modules/system/secureboot.nix`
- Wrapped with `nerv.secureboot.enable` guard (`mkIf cfg.enable`) — completes OPT-08
- LUKS label `NIXLUKS` stays hardcoded in TPM2 enrollment scripts with cross-reference comment
- Imported **last** in `modules/system/default.nix` (prevents `lib.mkForce false` conflict with systemd-boot set in boot.nix)

### Claude's Discretion
- Exact NixOS module option descriptions and example values for impermanence options
- Whether per-user default Desktop/Downloads mounts use `boot.initrd.postMountCommands` or `fileSystems` entries with `neededForBoot = false`
- Mount option flags beyond `size=` (e.g. `mode=`, `nosuid`, `nodev`)
- Order of imports in `modules/system/default.nix` (boot, impermanence before secureboot)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `modules/secureboot.nix`: full implementation exists — migrate as-is to `modules/system/secureboot.nix`, add `nerv.secureboot.enable` guard, add LUKS label cross-reference comments
- `hosts/nixos-base/configuration.nix`: boot section (lines 25–41) is the exact source for boot.nix content — migrate verbatim, add cross-reference comment for LUKS label
- `hosts/nixos-base/disko-configuration.nix`: defines `NIXLUKS`, `NIXBOOT`, `NIXROOT`, `NIXSWAP` labels — needs cross-reference comment added

### Established Patterns
- Opaque modules (kernel.nix, security.nix, nix.nix): no options, `lib.mkForce` escape hatch — boot.nix follows the same pattern
- Option modules (hardware.nix, identity.nix): `lib.mkOption` with type + default + description — impermanence.nix follows this pattern
- `mkIf cfg.enable` guard for enable-only modules — secureboot.nix gets this wrapper
- `modules/system/default.nix` aggregator pattern — add boot, impermanence, secureboot imports in correct order

### Integration Points
- `hosts/nixos-base/configuration.nix`: boot section removed after boot.nix extraction; fileSystems/swapDevices remain
- `modules/system/default.nix`: add `./boot.nix`, `./impermanence.nix`, and `./secureboot.nix` (last) to imports
- `nerv.secureboot.enable` cross-references `nerv.impermanence.enable` for IMPL-02 assertion
- `nerv.primaryUser` (list of strings) used by impermanence.nix to determine which users get default Desktop/Downloads tmpfs mounts
- Build verification: `nixos-rebuild build --flake .#nixos-base` must pass after all migrations

</code_context>

<specifics>
## Specific Ideas

- boot.nix comment: `# boot.kernelPackages set here but overridden by kernel.nix (lib.mkForce pkgs.linuxPackages_zen) — kernel.nix is the authoritative source for the kernel package`
- disko-configuration.nix cross-reference: `# NIXLUKS label — must stay in sync with modules/system/boot.nix and modules/system/secureboot.nix`
- IMPL-02 assertion message example: `"nerv: /var/lib/sbctl is in impermanence tmpfs paths — this would wipe Secure Boot keys on every reboot. Remove it from impermanence configuration."`

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 04-boot-extraction*
*Context gathered: 2026-03-07*
