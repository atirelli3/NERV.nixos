# Phase 10: initrd BTRFS Rollback Service - Context

**Gathered:** 2026-03-10
**Status:** Ready for planning

<domain>
## Phase Boundary

When `nerv.disko.layout = "btrfs"`, the initrd must include btrfs-progs and a systemd one-shot service that resets the root subvolume (`@`) from the blank snapshot (`@root-blank`) on every boot — before the root filesystem is mounted. When `nerv.disko.layout = "lvm"`, the existing LVM initrd settings remain active. Layout-agnostic initrd config (systemd-boot, EFI, shared LUKS unlock) stays or moves to the appropriate file. Boot rollback for BTRFS and impermanence wiring are separate from Phase 9's disk layout work.

</domain>

<decisions>
## Implementation Decisions

### Module organization

- Rollback logic **extends boot.nix** — no new dedicated rollback.nix file
- All layout-conditional initrd config (both BTRFS and LVM) moves to **disko.nix**, appended to the existing `mkIf isBtrfs` and `mkIf isLvm` blocks
- boot.nix becomes **purely layout-agnostic**: only shared settings remain (`boot.initrd.systemd.enable`, `systemd-boot`, `efi.canTouchEfiVariables`)
- boot.nix header updated to: reflect layout-agnostic role and add a cross-reference note: "Layout-specific initrd (BTRFS rollback, LVM lvm.enable) lives in modules/system/disko.nix"

### LVM initrd migration

- LVM initrd settings (`boot.initrd.services.lvm.enable`, `preLVM = true`, `dm-snapshot`) move out of boot.nix and into the **`mkIf isLvm` block in disko.nix**
- `dm-snapshot` kernel module is moved inside `mkIf isLvm` — it's LVM-specific and not needed for BTRFS
- `boot.initrd.luks.devices."cryptroot"` (LUKS unlock) also moves to **disko.nix** to co-locate NIXLUKS label creation with the unlock reference; both layouts share the same outer LUKS container, so this entry is added to both `mkIf isBtrfs` and `mkIf isLvm` blocks (or extracted as shared config at the disko.nix module level)
- BTRFS LUKS unlock mechanism: **research needed** — confirm whether `boot.initrd.luks.devices."cryptroot"` is still required under systemd initrd with BTRFS, or if systemd-cryptsetup handles it automatically via crypttab/label discovery

### BTRFS initrd additions (in mkIf isBtrfs block of disko.nix)

- `boot.initrd.supportedFilesystems = [ "btrfs" ]`
- `boot.initrd.systemd.storePaths = [ pkgs.btrfs-progs ]`
- `boot.initrd.systemd.services.rollback` unit (see Rollback service details)

### Rollback service details

- **Type**: `oneshot`, no `RemainAfterExit` — exits cleanly after completion
- **Ordering**: `After = "dev-mapper-cryptroot.device"`, `Before = "sysroot.mount"` — after LUKS unlock, before root is mounted
- **Dependency**: `After = dev-mapper-cryptroot.device` is sufficient; no additional BTRFS mount dependency
- **Execution sequence** (all in ExecStart or as a script):
  1. Mount `/dev/mapper/cryptroot` to `/btrfs_tmp` (subvolid=5, top-level BTRFS)
  2. If `/btrfs_tmp/@` exists: `btrfs subvolume delete /btrfs_tmp/@`
  3. `btrfs subvolume snapshot -r /btrfs_tmp/@root-blank /btrfs_tmp/@`
  4. Unmount `/btrfs_tmp`
- **First-boot / missing @ handling**: Skip silently — only delete `@` if it exists (guard with `|| true` or existence check). Idempotent.
- **Unmount**: Explicit `umount /btrfs_tmp` as part of the service script (self-contained)

### Module header updates

- `disko.nix` header: update to note it now also contains layout-conditional initrd config
- `boot.nix` header: update Purpose to "layout-agnostic initrd and bootloader"; add note that layout-specific config lives in disko.nix; remove LUKS reference from header (LUKS moves to disko.nix)

### Claude's Discretion

- Exact NixOS attribute path for the rollback service script (inline `pkgs.writeShellScript` vs `script = "..."`)
- Whether `luks.devices.cryptroot` is shared at disko.nix module level (outside mkIf blocks) or duplicated in both branches
- Exact wording of updated header comments

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets

- `modules/system/disko.nix`: Already has `isBtrfs`/`isLvm` let-bindings and `lib.mkMerge [ (mkIf isBtrfs {...}) (mkIf isLvm {...}) ]` structure. BTRFS and LVM initrd config appends directly to these blocks.
- `boot.initrd.systemd.enable = true` (boot.nix): Already set — required for `boot.initrd.systemd.services.*` used by the rollback unit.
- `disko.nix` BTRFS branch: `@root-blank` subvolume already declared with comment `# rollback snapshot baseline (see Phase 10)` — Phase 9 anticipated this exactly.

### Established Patterns

- `lib.mkIf isBtrfs` / `lib.mkIf isLvm`: Phase 9 pattern — all layout-conditional config uses these guards
- `lib.mkMerge [...]`: disko.nix uses this for the two layout branches; initrd config appended to existing branches
- NIXLUKS label: shared constant between disko.nix (creation) and boot.nix (currently). After Phase 10, both creation and reference live in disko.nix.

### Integration Points

- `disko.nix` `mkIf isBtrfs` block: receives BTRFS initrd additions + rollback unit + LUKS unlock
- `disko.nix` `mkIf isLvm` block: receives LVM initrd settings (migrated from boot.nix) + LUKS unlock
- `boot.nix`: loses `services.lvm.enable`, `preLVM`, `dm-snapshot`, `luks.devices.cryptroot`; retains `initrd.systemd.enable`, `systemd-boot`, `efi.canTouchEfiVariables`, `kernelPackages`
- `modules/system/default.nix`: no changes expected — both files already imported

</code_context>

<specifics>
## Specific Ideas

- No specific references — approach follows NixOS community BTRFS rollback patterns (Erase Your Darlings / Graham Christensen pattern)

</specifics>

<deferred>
## Deferred Ideas

- None — discussion stayed within phase scope

</deferred>

---

*Phase: 10-initrd-btrfs-rollback-service*
*Context gathered: 2026-03-10*
