# Phase 10: initrd BTRFS Rollback Service - Research

**Researched:** 2026-03-10
**Domain:** NixOS systemd initrd — BTRFS subvolume rollback, LVM initrd migration, LUKS handling
**Confidence:** HIGH (core service pattern verified from multiple community sources and NixOS discourse; storePaths/initrdBin distinction verified from nixpkgs source)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Module organization:**
- Rollback logic extends boot.nix — no new dedicated rollback.nix file
- All layout-conditional initrd config (both BTRFS and LVM) moves to disko.nix, appended to the existing `mkIf isBtrfs` and `mkIf isLvm` blocks
- boot.nix becomes purely layout-agnostic: only shared settings remain (`boot.initrd.systemd.enable`, `systemd-boot`, `efi.canTouchEfiVariables`)
- boot.nix header updated to reflect layout-agnostic role with cross-reference note

**LVM initrd migration:**
- LVM initrd settings (`boot.initrd.services.lvm.enable`, `preLVM = true`, `dm-snapshot`) move out of boot.nix into the `mkIf isLvm` block in disko.nix
- `dm-snapshot` kernel module is moved inside `mkIf isLvm`
- `boot.initrd.luks.devices."cryptroot"` also moves to disko.nix; added to both `mkIf isBtrfs` and `mkIf isLvm` blocks (or extracted as shared config at the disko.nix module level)

**BTRFS initrd additions (in mkIf isBtrfs block of disko.nix):**
- `boot.initrd.supportedFilesystems = [ "btrfs" ]`
- `boot.initrd.systemd.storePaths = [ pkgs.btrfs-progs ]`
- `boot.initrd.systemd.services.rollback` unit

**Rollback service details:**
- Type: `oneshot`, no `RemainAfterExit`
- Ordering: `After = "dev-mapper-cryptroot.device"`, `Before = "sysroot.mount"`
- `wantedBy = [ "initrd.target" ]`
- `unitConfig.DefaultDependencies = "no"`
- Execution sequence:
  1. Mount `/dev/mapper/cryptroot` to `/btrfs_tmp` (subvolid=5)
  2. If `/btrfs_tmp/@` exists: `btrfs subvolume delete /btrfs_tmp/@`
  3. `btrfs subvolume snapshot -r /btrfs_tmp/@root-blank /btrfs_tmp/@`
  4. Unmount `/btrfs_tmp`
- First-boot handling: skip silently if `@` doesn't exist (guard with `|| true` or existence check)

**Module header updates:**
- disko.nix header: note it now contains layout-conditional initrd config
- boot.nix header: update Purpose; add note; remove LUKS reference

### Claude's Discretion

- Exact NixOS attribute path for the rollback service script (inline `pkgs.writeShellScript` vs `script = "..."`)
- Whether `luks.devices.cryptroot` is shared at disko.nix module level (outside mkIf blocks) or duplicated in both branches
- Exact wording of updated header comments

### Deferred Ideas (OUT OF SCOPE)

- None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| BOOT-01 | When `nerv.disko.layout = "btrfs"`, initrd includes btrfs-progs via `boot.initrd.supportedFilesystems = ["btrfs"]` and `boot.initrd.systemd.storePaths = [pkgs.btrfs-progs]` | Verified: supportedFilesystems enables kernel module; storePaths copies binary store path. Script must reference btrfs via `${pkgs.btrfs-progs}/bin/btrfs` for PATH-independence. |
| BOOT-02 | When `nerv.disko.layout = "btrfs"`, a `boot.initrd.systemd.services.rollback` unit runs after `dev-mapper-cryptroot.device`, before `sysroot.mount`, deletes `@`, snapshots `@root-blank → @` | Verified: `dev-mapper-cryptroot.device` is the correct After= target (device unit requires cryptsetup service automatically). `sysroot.mount` is the correct Before= target. Pattern confirmed from community implementations. |
| BOOT-03 | LVM initrd services (`boot.initrd.services.lvm.enable`, `preLVM = true`, `dm-snapshot` kernel module) are only active when `nerv.disko.layout = "lvm"` — disabled for BTRFS to prevent initrd hang | Verified: move these settings into the `mkIf isLvm` block in disko.nix. `preLVM` is silently ignored by systemd stage 1 (but setting it inside isLvm is still correct — it guards against scripted stage1 if ever used). |
</phase_requirements>

---

## Summary

Phase 10 adds a systemd-based BTRFS rollback service to the initrd that resets the root subvolume on every boot. The core mechanism: a oneshot service mounts the raw BTRFS top-level (subvolid=5) at `/btrfs_tmp`, deletes the `@` subvolume (current root), snapshots `@root-blank` (the clean baseline established during install) to `@`, then unmounts. This runs after LUKS is unlocked (`dev-mapper-cryptroot.device`) and before root is mounted (`sysroot.mount`).

Concurrently, all layout-conditional initrd config is migrated out of boot.nix into disko.nix to co-locate disk layout decisions with the initrd config that depends on them. LVM initrd settings move into `mkIf isLvm`; BTRFS initrd settings (supportedFilesystems, storePaths, rollback service) go into `mkIf isBtrfs`. LUKS unlock config (`boot.initrd.luks.devices."cryptroot"`) also moves to disko.nix. boot.nix is left with only layout-agnostic settings.

**Primary recommendation:** Use `script = ''...''` with binaries referenced via full nix store path interpolation (`${pkgs.btrfs-progs}/bin/btrfs`), add `boot.initrd.systemd.storePaths = [ pkgs.btrfs-progs ]` to include the store closure, and set `unitConfig.DefaultDependencies = "no"` to prevent circular dependency issues during early boot.

---

## Standard Stack

### Core
| Library/Option | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| `boot.initrd.systemd.enable` | NixOS built-in | Enables systemd stage 1 initrd | Already set in boot.nix; required for `.services.*` |
| `boot.initrd.systemd.services.<name>` | NixOS built-in | Declares custom oneshot systemd units in initrd | Official NixOS mechanism; `postDeviceCommands` asserts error when systemd initrd is enabled |
| `boot.initrd.supportedFilesystems` | NixOS built-in | Includes btrfs kernel module in initrd | Required for `mount -t btrfs` to work in initrd |
| `boot.initrd.systemd.storePaths` | NixOS built-in | Copies nix store paths into initrd | Makes btrfs-progs binary available; does NOT add to PATH |
| `pkgs.btrfs-progs` | nixpkgs current | btrfs userspace tools | Provides `btrfs subvolume delete/snapshot` commands |
| `boot.initrd.luks.devices."cryptroot"` | NixOS built-in | LUKS device declaration for initrd unlock | Still required with systemd initrd; processed by systemd-cryptsetup-generator |

### Supporting
| Option | Purpose | When to Use |
|--------|---------|-------------|
| `boot.initrd.services.lvm.enable` | Enables LVM in initrd | Only when `isLvm`; causes hang on BTRFS disk with no LVM PV |
| `boot.initrd.kernelModules = [ "dm-snapshot" ]` | LVM snapshot kernel module | Only when `isLvm` |
| `unitConfig.DefaultDependencies = "no"` | Disables automatic Before/After systemd deps | Required for early-boot services to avoid dep cycles |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `script = ''...''` | `pkgs.writeShellScript` + `serviceConfig.ExecStart` | `writeShellScript` is more explicit; `script = ` is a NixOS convenience wrapper that generates a shell script automatically. Both work. |
| `dev-mapper-cryptroot.device` | `systemd-cryptsetup@cryptroot.service` | Both work: the device unit requires the cryptsetup service automatically. Device unit is more stable/conventional for ordering. |
| Shared LUKS config at module level | Duplicate in both isBtrfs/isLvm blocks | Module-level is DRY; duplication is more explicit. Either is valid. |

---

## Architecture Patterns

### Recommended Project Structure (Post-Phase-10)
```
modules/system/
├── boot.nix         # Layout-agnostic only: initrd.systemd.enable, systemd-boot, efi
├── disko.nix        # Disk layout + ALL layout-conditional initrd config
│   ├── mkIf isBtrfs # BTRFS disk + supportedFilesystems + storePaths + rollback service
│   └── mkIf isLvm   # LVM disk + lvm.enable + preLVM + dm-snapshot + luks.devices
└── ...
```

### Pattern 1: Rollback Service Declaration

**What:** A oneshot systemd unit in the initrd that deletes and re-creates the `@` subvolume from the `@root-blank` snapshot before root is mounted.

**When to use:** Inside `lib.mkIf isBtrfs` block in disko.nix.

**Verified pattern (composite from community implementations — NixOS Discourse April 2024):**
```nix
boot.initrd.systemd.services.rollback = {
  description = "Rollback BTRFS root subvolume to a pristine state";
  wantedBy = [ "initrd.target" ];
  after    = [ "dev-mapper-cryptroot.device" ];
  before   = [ "sysroot.mount" ];
  unitConfig.DefaultDependencies = "no";
  serviceConfig.Type = "oneshot";
  script = ''
    mkdir -p /btrfs_tmp
    mount -o subvol=/ /dev/mapper/cryptroot /btrfs_tmp
    if [ -e /btrfs_tmp/@ ]; then
      ${pkgs.btrfs-progs}/bin/btrfs subvolume delete /btrfs_tmp/@
    fi
    ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot /btrfs_tmp/@root-blank /btrfs_tmp/@
    umount /btrfs_tmp
  '';
};
```

**Critical notes:**
- `@root-blank` must be a read-only snapshot created manually during install (Phase 9 already declared the subvolume; `btrfs subvolume snapshot -r /mnt/@ /mnt/@root-blank` runs post-disko per PROF-04)
- The `snapshot` command in the script does NOT use `-r` (creates a read-write snapshot of the read-only baseline) so the new `@` is writable
- Alternatively, `-r` can be used if you want the new `@` to also be read-only initially, but standard pattern omits `-r` for the destination
- Mount uses `subvol=/` (or `subvolid=5`) to mount the BTRFS top level, not a subvolume
- `/btrfs_tmp` is created inline — the directory does not need to pre-exist in the disko layout

### Pattern 2: storePaths + Binary Reference

**What:** Include btrfs-progs in the initrd closure and reference binaries by nix store path in scripts.

**Why:** initrd-builder performs reference-removal (nuke-refs); bare `btrfs` in a script string is not a nix store reference, but `${pkgs.btrfs-progs}/bin/btrfs` is — and must be included in `storePaths`.

```nix
# Makes the btrfs-progs closure available in initrd /nix/store:
boot.initrd.systemd.storePaths = [ pkgs.btrfs-progs ];

# In the service script, reference by full path:
script = ''
  ${pkgs.btrfs-progs}/bin/btrfs subvolume delete /btrfs_tmp/@
'';
```

**Note:** `storePaths` does NOT add to PATH. Using full nix store paths in the script is required.

### Pattern 3: LUKS Unlock Placement (Shared Config)

**What:** `boot.initrd.luks.devices."cryptroot"` moves from boot.nix to disko.nix. Both layout branches need it.

**Options:**
1. Shared at disko.nix module level (outside mkIf blocks) — DRY, always active regardless of layout
2. Duplicated in both `mkIf isBtrfs` and `mkIf isLvm` blocks — explicit per-branch

**Recommendation (Claude's discretion):** Place LUKS config as a third entry in `lib.mkMerge [...]` at the disko.nix module level — shared between both layouts. Both BTRFS and LVM use the same outer LUKS container with label NIXLUKS/device name "cryptroot", so sharing is correct.

```nix
config = lib.mkMerge [
  (lib.mkIf isBtrfs { ... })
  (lib.mkIf isLvm { ... })
  # Shared: both layouts use same outer LUKS container
  {
    boot.initrd.luks.devices."cryptroot" = {
      device        = "/dev/disk/by-label/NIXLUKS";
      allowDiscards = true;
      # preLVM is ignored by systemd stage 1; safe to omit here
    };
  }
];
```

### Anti-Patterns to Avoid

- **Using `boot.initrd.postDeviceCommands`:** NixOS asserts an error when `boot.initrd.systemd.enable = true` and `postDeviceCommands` is used. This project already has `systemd.enable = true`.
- **Bare binary names in script (`btrfs subvolume delete`):** Without full nix store path interpolation, the binary may not be found in the initrd environment.
- **Unconditional LVM settings:** `boot.initrd.services.lvm.enable` without `mkIf isLvm` causes initrd hang on BTRFS-only disk — no LVM PV to scan.
- **`wantedBy = [ "basic.target" ]` or `after = [ "sysroot.mount" ]`:** These are incorrect. `basic.target` is too late; `after = sysroot.mount` runs after root mount (backwards).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| BTRFS snapshot/rollback in initrd | Custom boot scripts | `boot.initrd.systemd.services.*` | NixOS provides typed service declaration; postDeviceCommands is incompatible with systemd initrd |
| Making packages available in initrd | Custom extraUtils | `boot.initrd.systemd.storePaths` | Official mechanism for adding closures to systemd initrd |
| LUKS unlock in initrd | cryptsetup imperative calls | `boot.initrd.luks.devices."name"` | NixOS translates this to crypttab; systemd-cryptsetup-generator handles unlock automatically |

**Key insight:** All custom initrd work in this phase uses NixOS-native options. No custom `extraInitrdCommands` or bash injection at the initrd builder level.

---

## Common Pitfalls

### Pitfall 1: storePaths vs initrdBin Confusion
**What goes wrong:** Adding `pkgs.btrfs-progs` to `storePaths` and expecting `btrfs` to work in the service script by name.
**Why it happens:** `storePaths` copies closures into `/nix/store` inside the initrd; it does not add to PATH. `initrdBin` adds to `/bin` (and therefore PATH).
**How to avoid:** Always use `${pkgs.btrfs-progs}/bin/btrfs` in scripts when relying on storePaths. Alternatively, add to `boot.initrd.systemd.initrdBin` for PATH availability — but storePaths + full path is the documented pattern for service-specific binaries.
**Warning signs:** `btrfs: command not found` in initrd journal.

### Pitfall 2: Unconditional LVM initrd Settings
**What goes wrong:** `boot.initrd.services.lvm.enable = true` applies on BTRFS disk, which has no LVM Physical Volume — initrd hangs scanning for LVM.
**Why it happens:** boot.nix currently sets this unconditionally; it must move to `mkIf isLvm`.
**How to avoid:** Exactly the migration this phase performs — move all LVM-specific initrd config into the `mkIf isLvm` block in disko.nix.
**Warning signs:** System hangs at boot after enabling BTRFS layout; initrd journal shows LVM PV scan timing out.

### Pitfall 3: Device Unit Name for LUKS Mapper
**What goes wrong:** Using wrong unit name in `after =` clause.
**Why it happens:** Two plausible names: `dev-mapper-cryptroot.device` (device unit) and `systemd-cryptsetup@cryptroot.service` (service unit).
**How to avoid:** Use `dev-mapper-cryptroot.device` — this is the device unit created after LUKS unlock, and it correctly requires the cryptsetup service automatically. The naming convention is: `/dev/mapper/<name>` → `dev-mapper-<name>.device` (dashes replace slashes, device suffix).
**Research flag from STATE.md:** Verify with `systemctl list-units | grep cryptroot` on the target system during implementation — both unit names should appear, confirming the device unit exists.
**Warning signs:** Rollback service starts before LUKS is unlocked; `/dev/mapper/cryptroot` not found.

### Pitfall 4: Snapshot Command Semantics
**What goes wrong:** Using `-r` flag when creating the new `@` from `@root-blank`, making `@` read-only — system fails to write to root.
**Why it happens:** `@root-blank` is a read-only snapshot; a snapshot of a read-only subvolume may inherit read-only status.
**How to avoid:** `btrfs subvolume snapshot /btrfs_tmp/@root-blank /btrfs_tmp/@` (no `-r`) creates a read-write subvolume. Confirm behavior during testing.
**Warning signs:** Root filesystem is read-only after first boot using BTRFS layout.

### Pitfall 5: Missing @root-blank Baseline
**What goes wrong:** Rollback service runs but `@root-blank` doesn't exist (install skipped the snapshot step) — snapshot command fails, boot may hang.
**Why it happens:** `@root-blank` must be created manually after `nixos-disko` and before `nixos-install` (PROF-04). disko declares the subvolume definition but doesn't create a snapshot.
**How to avoid:** The service's existence check (`if [ -e /btrfs_tmp/@ ]; then`) guards against missing `@`, but if `@root-blank` is also missing, snapshot still fails. Document install procedure clearly. The install guide must include: `btrfs subvolume snapshot -r /mnt/@ /mnt/@root-blank`.
**Warning signs:** Service fails at snapshot step with "subvolume not found".

### Pitfall 6: DefaultDependencies Omission
**What goes wrong:** Service has circular dependencies or runs too late because systemd adds default ordering deps.
**Why it happens:** Default systemd service deps include ordering against several targets that may create cycles during initrd's compressed startup.
**How to avoid:** `unitConfig.DefaultDependencies = "no"` — confirmed as standard for early-boot rollback services (verified from community implementations).

---

## Code Examples

Verified patterns from community implementations and NixOS discourse:

### Complete BTRFS Initrd Block (for disko.nix mkIf isBtrfs)
```nix
# Inside (lib.mkIf isBtrfs { ... })
boot.initrd.supportedFilesystems = [ "btrfs" ];
boot.initrd.systemd.storePaths   = [ pkgs.btrfs-progs ];

boot.initrd.systemd.services.rollback = {
  description = "Rollback BTRFS root subvolume to a pristine state";
  wantedBy    = [ "initrd.target" ];
  after       = [ "dev-mapper-cryptroot.device" ];
  before      = [ "sysroot.mount" ];
  unitConfig.DefaultDependencies = "no";
  serviceConfig.Type = "oneshot";
  script = ''
    mkdir -p /btrfs_tmp
    mount -o subvol=/ /dev/mapper/cryptroot /btrfs_tmp
    if [ -e /btrfs_tmp/@ ]; then
      ${pkgs.btrfs-progs}/bin/btrfs subvolume delete /btrfs_tmp/@ || true
    fi
    ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot \
      /btrfs_tmp/@root-blank /btrfs_tmp/@
    umount /btrfs_tmp
  '';
};
```

### Complete LVM Initrd Block (for disko.nix mkIf isLvm)
```nix
# Inside (lib.mkIf isLvm { ... })
# Migrated from boot.nix:
boot.initrd.services.lvm.enable  = true;
boot.initrd.kernelModules         = [ "dm-snapshot" "cryptd" ];
```

### Shared LUKS Config (disko.nix module level, outside mkIf blocks)
```nix
# Shared: applies to both layouts (both use same outer LUKS container)
boot.initrd.luks.devices."cryptroot" = {
  device        = "/dev/disk/by-label/NIXLUKS";
  allowDiscards = true;
  # preLVM = true is ignored by systemd stage 1 — omit here
};
```

### Updated boot.nix (layout-agnostic only)
```nix
# After Phase 10 migration — only shared settings remain
{
  boot.kernelPackages           = pkgs.linuxPackages_latest;  # overridden by kernel.nix
  boot.initrd.systemd.enable    = true;
  boot.loader.systemd-boot.enable      = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `boot.initrd.postDeviceCommands` | `boot.initrd.systemd.services.*` | NixOS asserts error when systemd initrd is enabled | postDeviceCommands is completely incompatible with `initrd.systemd.enable = true` |
| `extraUtilsCommands` for binaries | `storePaths` + `initrdBin` | systemd initrd era | Two distinct mechanisms: storePaths (closure in store) vs initrdBin (PATH) |
| LVM preLVM = true | Not used in systemd initrd | NixOS systemd initrd | `preLVM` is silently ignored; LVM ordering is handled by systemd-udev dependencies |

**Deprecated/outdated:**
- `boot.initrd.postDeviceCommands`: Asserts error with `initrd.systemd.enable = true`. Do not use.
- `preLVM = true`: Silently ignored by systemd stage 1. Still valid to set inside `mkIf isLvm` for documentation, but has no runtime effect.

---

## Open Questions

1. **Exact systemd device unit name for cryptroot in NixOS 25.11**
   - What we know: Convention is `dev-mapper-cryptroot.device`; systemd cryptsetup-generator creates this automatically from the LUKS mapper name "cryptroot"
   - What's unclear: Whether NixOS 25.11 changed any naming; whether the unit actually appears in `systemctl list-units` during initrd
   - Recommendation: Implement with `dev-mapper-cryptroot.device` per convention; verify with `rd.systemd.debug_shell` or `rd.systemd.unit=rescue.target` kernel params during first boot test. STATE.md lists this as a pending todo — implementation task should include this verification step.

2. **boot.initrd.luks.devices placement: shared vs duplicated**
   - What we know: Both BTRFS and LVM branches use the same LUKS container with mapping name "cryptroot" and label NIXLUKS
   - What's unclear: Whether a third `lib.mkMerge` entry (unconditional) is cleaner than duplicating in both branches
   - Recommendation: Shared unconditional block at disko.nix module level (three entries in mkMerge). This is Claude's discretion per CONTEXT.md.

3. **@root-blank subvolume snapshot: read-write or read-only destination**
   - What we know: `btrfs subvolume snapshot SRC DEST` creates a read-write snapshot of SRC even if SRC is read-only. Omitting `-r` in the rollback service is standard.
   - What's unclear: Whether any NixOS mount behavior depends on the `@` subvolume being read-only or read-write at the BTRFS level
   - Recommendation: Omit `-r` (create read-write `@`); this matches the community pattern. Confirm during boot test.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None — NixOS configuration; validation is boot-time functional testing |
| Config file | none — see Wave 0 |
| Quick run command | `nix flake check /home/demon/Developments/nerv.nixos` (static analysis only) |
| Full suite command | `nixos-rebuild dry-build --flake /home/demon/Developments/nerv.nixos#nixos-base` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BOOT-01 | supportedFilesystems + storePaths present in btrfs config | smoke | `nix eval .#nixosConfigurations.nixos-base.config.boot.initrd.supportedFilesystems` | ❌ Wave 0 |
| BOOT-01 | btrfs-progs in storePaths when layout=btrfs | smoke | `nix eval .#nixosConfigurations.nixos-base.config.boot.initrd.systemd.storePaths` | ❌ Wave 0 |
| BOOT-02 | rollback service declared with correct ordering | smoke | `nix eval .#nixosConfigurations.nixos-base.config.boot.initrd.systemd.services.rollback` | ❌ Wave 0 |
| BOOT-03 | lvm.enable absent when layout=btrfs | smoke | `nix eval .#nixosConfigurations.nixos-base.config.boot.initrd.services.lvm.enable` (expect false) | ❌ Wave 0 |
| BOOT-03 | dm-snapshot absent from initrd modules when layout=btrfs | smoke | `nix eval .#nixosConfigurations.nixos-base.config.boot.initrd.kernelModules` (expect no dm-snapshot) | ❌ Wave 0 |
| All | Config evaluates without errors | static | `nix flake check /home/demon/Developments/nerv.nixos` | ❌ Wave 0 |
| All | Actual rollback works on boot | manual | Physical/VM boot test; check that previous-session files are absent | manual-only |

### Sampling Rate
- **Per task commit:** `nix flake check /home/demon/Developments/nerv.nixos` (or `nix eval` for specific attribute)
- **Per wave merge:** `nixos-rebuild dry-build --flake /home/demon/Developments/nerv.nixos#nixos-base`
- **Phase gate:** Full dry-build green + manual boot test (or `rd.systemd.debug_shell` inspection) before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] Verify `nix flake check` works from dev machine (may need `--override-input nixpkgs` or similar if hardware-config is missing)
- [ ] Confirm eval commands work against correct nixosConfiguration attribute name

*(Both are documentation gaps, not code gaps — the test commands are standard nix eval patterns)*

---

## Sources

### Primary (HIGH confidence)
- NixOS Discourse, April 2024 — `boot.initrd.systemd.services` rollback with `before = ["sysroot.mount"]`, `wantedBy = ["initrd.target"]`, `unitConfig.DefaultDependencies = "no"`, `serviceConfig.Type = "oneshot"` — confirmed by multiple threads
- NixOS Discourse: "Impermanence vs systemd initrd w/ TPM" — confirmed `before = ["sysroot.mount"]`; BTRFS variant uses `after = ["systemd-cryptsetup@enc.service"]` (enc = mapper name)
- systemd man pages / cryptsetup-generator: `dev-mapper-<name>.device` is generated by systemd-cryptsetup-generator; device unit requires cryptsetup service automatically — `After = dev-mapper-cryptroot.device` is the correct ordering directive
- MyNixOS options reference: `boot.initrd.systemd.storePaths` — confirmed type and purpose (copies closures into initrd /nix/store, does NOT add to PATH)
- NixOS Discourse "Auto-unlock root on LUKS with systemd initrd": `boot.initrd.luks.devices` still required with systemd initrd; `preLVM` ignored by systemd stage 1
- nixpkgs issue #309316: initrd builder performs nuke-refs — store references in scripts must be in storePaths for closure correctness

### Secondary (MEDIUM confidence)
- mt-caret blog "Encrypted Btrfs Root with Opt-in State on NixOS": Original pattern using `postDeviceCommands` — predates systemd initrd. Shows script logic (mount subvol=/, delete nested subvols, delete root, snapshot root-blank). Device path: `/dev/mapper/enc`. Script logic confirmed as correct approach; initrd mechanism differs.
- notashelf.dev "Full Disk Encryption and Impermanence on NixOS" (2025): Confirms `wantedBy = ["initrd.target"]`, `before = ["sysroot.mount"]`, `serviceConfig.Type = "oneshot"` pattern.

### Tertiary (LOW confidence — verify during implementation)
- Community consensus on `systemd-cryptsetup@cryptroot.service` as alternative After= target — use device unit instead per systemd documentation
- `@root-blank` snapshot behavior (read-write destination) — assumed from btrfs documentation; confirm on actual system

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — NixOS options verified from official docs and nixpkgs source
- Architecture: HIGH — Service pattern verified from multiple community implementations and NixOS discourse
- Pitfalls: HIGH — Most derived from confirmed NixOS behavior (systemd initrd incompatibility with postDeviceCommands, nuke-refs behavior, LVM hang)
- Device unit naming: MEDIUM — Convention is well-established from systemd docs; live system verification flagged as implementation task

**Research date:** 2026-03-10
**Valid until:** 2026-06-10 (stable NixOS options; check if nixpkgs changes storePaths semantics)
