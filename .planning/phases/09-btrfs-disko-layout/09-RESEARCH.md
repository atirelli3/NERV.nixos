# Phase 9: BTRFS Disko Layout - Research

**Researched:** 2026-03-09
**Domain:** disko v1.13.0 BTRFS subvolume content type, NixOS module option patterns
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Layout option:**
- `nerv.disko.layout` has no default — forced declaration, like `nerv.hostname`
- Accepted values: `"btrfs"` | `"lvm"` (enum, eval error if unset)
- Prevents silent misconfiguration; consistent with other nerv.* options that have no safe generic default

**BTRFS layout (nerv.disko.layout = "btrfs"):**
- GPT → 1G ESP (NIXBOOT) → 100% LUKS (cryptroot/NIXLUKS) → BTRFS filesystem
- Subvolumes: @, @root-blank, @home, @nix, @persist, @log — all mandatory
- All BTRFS subvolumes mount with: `compress=zstd:3`, `noatime`, `space_cache=v2`
- No swap in BTRFS branch (BTRFS CoW incompatibility with swap files)
- No per-subvolume size options — BTRFS shares the pool

**LVM layout (nerv.disko.layout = "lvm"):**
- LVM is server-only (full mode): swap LV + /nix LV + /persist LV
- The LVM minimal mode (single root LV for desktop) is dropped
- rootSize option is removed entirely — no dead API surface
- Swap is kept in the LVM branch (server may need swap)
- LVM branch preserves: GPT → ESP → LUKS → LVM PV → VG lvmroot

**Option namespace restructuring:**
- LVM size options move from `nerv.disko.*` to `nerv.disko.lvm.*` sub-namespace:
  - `nerv.disko.lvm.swapSize` (was `nerv.disko.swapSize`)
  - `nerv.disko.lvm.storeSize` (was `nerv.disko.storeSize`)
  - `nerv.disko.lvm.persistSize` (was `nerv.disko.persistSize`)
- `nerv.disko.rootSize` is dropped entirely (no root LV in either layout)
- BTRFS branch has no size options under `nerv.disko.btrfs.*` — not needed

**hosts/configuration.nix updates:**
- Phase 9 updates `hosts/configuration.nix` to reflect the new API
- `nerv.disko.layout = "PLACEHOLDER"; # "btrfs" for desktop/laptop | "lvm" for server`
- Old `nerv.disko.{swapSize,rootSize,storeSize,persistSize}` replaced with `nerv.disko.lvm.{swapSize,storeSize,persistSize}`
- `nerv.disko.lvm.*` entries annotated as relevant only when `nerv.disko.layout = "lvm"`

### Claude's Discretion

- BTRFS filesystem label (e.g. NIXBTRFS or similar)
- Disko content type structure for BTRFS subvolumes (filesystem vs btrfs subvolume content type)
- Whether to use disko's native btrfs subvolume support or raw fileSystems entries
- Comment style and header updates to disko.nix to document new option surface

### Deferred Ideas (OUT OF SCOPE)

- None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DISKO-01 | User can set `nerv.disko.layout = "btrfs"` to get a GPT/LUKS/BTRFS disk with subvolumes @, @root-blank, @home, @nix, @persist, @log declared in `disko.nix` | Disko v1.13.0 `type = "btrfs"` content with `subvolumes` attrset; LUKS wrapper reuses existing pattern |
| DISKO-02 | User can set `nerv.disko.layout = "lvm"` to get the existing GPT/LUKS/LVM layout (swap + store + persist LVs) | Existing LVM logic becomes the "lvm" branch verbatim; only API rename needed |
| DISKO-03 | BTRFS subvolumes use mount options `compress=zstd:3`, `noatime`, `space_cache=v2`; no swap LV emitted in BTRFS layout | Confirmed as disko `mountOptions` list on each subvolume; no disko swap in btrfs branch |
</phase_requirements>

---

## Summary

Phase 9 restructures `modules/system/disko.nix` around a new `nerv.disko.layout` enum option with no default. The BTRFS branch uses disko's native `type = "btrfs"` content type with a `subvolumes` attrset — this is confirmed as the correct approach in disko v1.13.0 (see `example/luks-btrfs-subvolumes.nix`). The LVM branch is the existing code moved wholesale into a `lib.mkIf isBtrfs`/`lib.mkIf isLvm` split, with only the API rename (`nerv.disko.lvm.*` sub-namespace) and removal of dead options (`rootSize`, `isFullMode` binding).

The GPT/ESP/LUKS wrapper is shared across both branches — only the LUKS content type differs: BTRFS branch uses `type = "btrfs"` with subvolumes; LVM branch keeps `type = "lvm_pv"`. The `lvm_vg.lvmroot` block is only emitted in the LVM branch via `lib.mkIf isLvm`.

`hosts/configuration.nix` is updated in the same phase to migrate callers from the old flat `nerv.disko.*` options to the new `nerv.disko.layout` + `nerv.disko.lvm.*` API.

**Primary recommendation:** Use disko's native `type = "btrfs"` content inside the LUKS container, with a `subvolumes` attrset keyed by subvolume path names (e.g., `"/@"`, `"/@home"`). Emit `lvm_vg.lvmroot` only when `isLvm`.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| nix-community/disko | v1.13.0 (pinned in flake.nix) | Declarative disk layout generating NixOS fileSystems | Already wired; provides `type = "btrfs"` with native subvolume support |

No new flake inputs — disko v1.13.0 is already pinned and wired in all three nixosConfigurations.

### Disko Content Type: btrfs

The `type = "btrfs"` content type (used inside a LUKS container or partition) accepts:

| Attribute | Type | Notes |
|-----------|------|-------|
| `type` | `"btrfs"` | Selects the btrfs content handler |
| `extraArgs` | list of strings | Passed to `mkfs.btrfs`; use `[ "-L" "NIXBTRFS" ]` for label |
| `subvolumes` | attrset | Keys are subvolume paths (e.g., `"/@"`); values are subvolume configs |

Each subvolume in the `subvolumes` attrset accepts:

| Attribute | Type | Notes |
|-----------|------|-------|
| `mountpoint` | string or null | Where to mount; omit for unmounted subvolumes (e.g., `@root-blank`) |
| `mountOptions` | list of strings | e.g., `[ "compress=zstd:3" "noatime" "space_cache=v2" ]` |
| `extraArgs` | list of strings | Passed to `btrfs subvolume create` |

**Installation:** No new packages. `nix flake update` not needed — disko already in flake.lock.

---

## Architecture Patterns

### Recommended File Structure

The change is confined to two files:

```
modules/system/disko.nix      # restructured with layout branch
hosts/configuration.nix       # API updated: layout + lvm.* sub-namespace
```

### Pattern 1: `lib.types.enum` with no default (existing project convention)

**What:** An option that forces explicit declaration. Evaluation fails with a type error if the user does not set it.

**When to use:** Whenever a "safe default" doesn't exist and silent misconfiguration causes hardware problems. Already used for `nerv.hardware.cpu`, `nerv.hardware.gpu`, `nerv.hostname`.

**Example:**
```nix
# Source: existing modules/system/impermanence.nix pattern + project convention
nerv.disko.layout = lib.mkOption {
  type        = lib.types.enum [ "btrfs" "lvm" ];
  # intentionally no default — forces explicit declaration per host
  description = ''
    Disk layout type.
      btrfs — GPT/LUKS/BTRFS with subvolumes (desktop/laptop).
      lvm   — GPT/LUKS/LVM with swap, /nix, /persist LVs (server).
  '';
};
```

### Pattern 2: `lib.mkIf` / `lib.mkMerge` for layout branching

**What:** Emit the BTRFS block only when `isBtrfs`, LVM block only when `isLvm`. Matches the existing `lib.mkMerge` pattern in `impermanence.nix`.

**When to use:** Two mutually exclusive hardware configurations in a single module.

**Example:**
```nix
# Source: existing impermanence.nix lib.mkMerge pattern
let
  cfg    = config.nerv.disko;
  isBtrfs = cfg.layout == "btrfs";
  isLvm   = cfg.layout == "lvm";
in {
  config = lib.mkMerge [
    (lib.mkIf isBtrfs {
      disko.devices.disk.main = { ... };  # BTRFS branch only
    })
    (lib.mkIf isLvm {
      disko.devices.disk.main   = { ... };  # LVM branch only
      disko.devices.lvm_vg.lvmroot = { ... };
    })
  ];
}
```

### Pattern 3: disko BTRFS subvolumes inside LUKS

**What:** Replace `type = "lvm_pv"` inside the LUKS content with `type = "btrfs"` + `subvolumes` attrset.

**When to use:** BTRFS branch of the layout.

**Example (from disko v1.13.0 `example/luks-btrfs-subvolumes.nix`):**
```nix
# Source: https://github.com/nix-community/disko/blob/v1.13.0/example/luks-btrfs-subvolumes.nix
content = {
  type = "luks";
  name = "cryptroot";
  settings.allowDiscards = true;
  extraFormatArgs = [ "--label" "NIXLUKS" ];
  passwordFile = "/tmp/luks-password";
  content = {
    type = "btrfs";
    extraArgs = [ "-L" "NIXBTRFS" "-f" ];  # -f forces creation; label NIXBTRFS
    subvolumes = {
      "/@" = {
        mountpoint  = "/";
        mountOptions = [ "compress=zstd:3" "noatime" "space_cache=v2" ];
      };
      "/@root-blank" = {
        # no mountpoint — used as rollback snapshot source by initrd (Phase 10)
      };
      "/@home" = {
        mountpoint  = "/home";
        mountOptions = [ "compress=zstd:3" "noatime" "space_cache=v2" ];
      };
      "/@nix" = {
        mountpoint  = "/nix";
        mountOptions = [ "compress=zstd:3" "noatime" "space_cache=v2" ];
      };
      "/@persist" = {
        mountpoint  = "/persist";
        mountOptions = [ "compress=zstd:3" "noatime" "space_cache=v2" ];
      };
      "/@log" = {
        mountpoint  = "/var/log";
        mountOptions = [ "compress=zstd:3" "noatime" "space_cache=v2" ];
      };
    };
  };
};
```

### Pattern 4: `nerv.disko.lvm.*` sub-namespace

**What:** Move the three LVM size options into a sub-attrset. Nix module system supports nested option declarations naturally.

**Example:**
```nix
# Source: project convention (mirrors nerv.impermanence structure)
options.nerv.disko = {
  layout = lib.mkOption { ... };  # top-level enum

  lvm = {
    swapSize = lib.mkOption {
      type    = lib.types.str;
      default = "PLACEHOLDER";
      description = "Swap LV size. Set to 2x RAM. Find RAM with: free -h";
      example = "16G";
    };
    storeSize = lib.mkOption {
      type    = lib.types.str;
      default = "PLACEHOLDER";
      description = "Nix store LV size (/nix ext4). Inspect with: nix path-info --all | wc -c";
      example = "60G";
    };
    persistSize = lib.mkOption {
      type    = lib.types.str;
      default = "PLACEHOLDER";
      description = "Persist LV size (/persist ext4). Holds SSH keys, service state, etc.";
      example = "20G";
    };
  };
};
```

### Pattern 5: `hosts/configuration.nix` API migration

**What:** Replace the four old `nerv.disko.*` lines with the new `nerv.disko.layout` + `nerv.disko.lvm.*` entries.

**Example:**
```nix
# REMOVE (old API):
nerv.disko.swapSize    = "PLACEHOLDER";
nerv.disko.rootSize    = "PLACEHOLDER";
nerv.disko.storeSize   = "PLACEHOLDER";
nerv.disko.persistSize = "PLACEHOLDER";

# ADD (new API):
nerv.disko.layout = "PLACEHOLDER";  # "btrfs" for desktop/laptop | "lvm" for server

# LVM sizes — relevant only when nerv.disko.layout = "lvm"
nerv.disko.lvm.swapSize    = "PLACEHOLDER";  # e.g. "16G"  (2x RAM; free -h)
nerv.disko.lvm.storeSize   = "PLACEHOLDER";  # e.g. "60G"  (/nix ext4)
nerv.disko.lvm.persistSize = "PLACEHOLDER";  # e.g. "20G"  (/persist ext4)
```

### Anti-Patterns to Avoid

- **Using `type = "filesystem"` with `format = "btrfs"` instead of `type = "btrfs"`:** The `filesystem` content type creates a plain formatted partition without disko's subvolume management. Subvolumes must be declared using `type = "btrfs"` with its `subvolumes` attrset.
- **Mounting `@root-blank`:** This subvolume exists only as the rollback snapshot source (Phase 10 creates the snapshot). It must NOT have a `mountpoint` in the disko declaration — mounting it at a path would interfere with the initrd rollback service.
- **Keeping `isFullMode` let binding:** The old `isFullMode = config.nerv.impermanence.mode == "full"` cross-dependency on impermanence is now dead. Replace with `isBtrfs` and `isLvm` let bindings derived only from `cfg.layout`.
- **Emitting `lvm_vg.lvmroot` unconditionally:** The `disko.devices.lvm_vg.lvmroot` block must be inside `lib.mkIf isLvm`. If emitted when the disk is BTRFS (no LVM PV), disko will attempt to create LVM structures on a non-existent PV — silent failure at install time.
- **Keeping `nerv.disko.rootSize`:** The minimal mode (single root LV) is dropped. No branch uses a root LV. Remove the option entirely to avoid dead API surface.
- **Using `space_cache=v2` as a separate mountOption alongside `subvol=...`:** Disko handles subvol path internally. Do not add `subvol=@` to `mountOptions` — disko injects it automatically.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| BTRFS subvolume declarations | `fileSystems."/" = { options = [ "subvol=@" ]; }` blocks in disko.nix | disko `type = "btrfs"` + `subvolumes` attrset | Disko generates all fileSystems entries including correct subvol options; hand-rolled entries fight disko module merging |
| Subvolume creation at install | Manual `btrfs subvolume create` in install script | disko handles creation via `disko --mode destroy,format,mount` | Disko runs mkfs.btrfs and subvolume creation as part of format step |
| LVM conditional emission | `if` expression inside `disko.devices.lvm_vg` | `lib.mkIf isLvm { disko.devices.lvm_vg = ...; }` | Nix attr-set `if` expressions inside disko device tree cause type errors; use `lib.mkIf` at the config block level |

**Key insight:** Disko's `type = "btrfs"` subvolume handler manages both `btrfs subvolume create` (at format time) and `fileSystems` generation (at eval time). There is no need to touch `fileSystems` manually in disko.nix.

---

## Common Pitfalls

### Pitfall 1: `@root-blank` must NOT have a mountpoint in disko

**What goes wrong:** If `@root-blank` is given a mountpoint (e.g., `"/@root-blank" = { mountpoint = "/btrfs-blank"; }`), disko will generate a `fileSystems` entry for it. This entry would try to mount the blank snapshot at boot — which conflicts with Phase 10's initrd service that snapshots `@root-blank → @`.

**Why it happens:** Developers assume all subvolumes need mountpoints.

**How to avoid:** Declare `"/@root-blank" = {}` (empty attrset) or with only `extraArgs` if needed. No `mountpoint` key.

**Warning signs:** A `fileSystems` entry for `/@root-blank` appearing in `nixos-rebuild build` output.

### Pitfall 2: Flat `lib.mkIf` with two disk.main blocks causes merge conflict

**What goes wrong:** If both the BTRFS and LVM branches unconditionally set `disko.devices.disk.main`, NixOS module merging raises a conflict error because the `content` attrset has different structures.

**Why it happens:** Naive `if isBtrfs then { ... } else { ... }` inside a single `config` block.

**How to avoid:** Use `lib.mkMerge [ (lib.mkIf isBtrfs { disko.devices.disk.main = ...; }) (lib.mkIf isLvm { disko.devices.disk.main = ...; }) ]`. Because only one branch is active at eval time, the merge sees only one definition for `disko.devices.disk.main`.

**Warning signs:** Nix eval error mentioning "conflicting definitions" or "cannot merge" on `disko.devices.disk.main.content.partitions.luks.content`.

### Pitfall 3: `space_cache=v2` is a mount option, not a mkfs option

**What goes wrong:** Adding `space_cache=v2` to `extraArgs` (passed to `mkfs.btrfs`) instead of `mountOptions`. `mkfs.btrfs` does not accept this option and will error.

**Why it happens:** Confusing filesystem creation flags with runtime mount options.

**How to avoid:** Put `"space_cache=v2"` in `mountOptions = [ "compress=zstd:3" "noatime" "space_cache=v2" ]` on each subvolume. The `extraArgs` on the `type = "btrfs"` block are for `mkfs.btrfs` (e.g., `-L NIXBTRFS -f`).

**Warning signs:** disko format step failing with `mkfs.btrfs: unrecognized option 'space_cache=v2'`.

### Pitfall 4: Old `isFullMode` cross-dependency causes evaluation error

**What goes wrong:** The existing `disko.nix` references `config.nerv.impermanence.mode`. If this binding is left in place while the module is restructured, but impermanence mode is no longer the discriminator, it introduces a stale cross-module dependency that could cause cycle errors if impermanence.nix is later changed.

**Why it happens:** Copy-paste from existing code without removing the old binding.

**How to avoid:** Replace `isFullMode = config.nerv.impermanence.mode == "full"` with `isBtrfs = cfg.layout == "btrfs"` and `isLvm = cfg.layout == "lvm"`. The new bindings only depend on `cfg` (the disko config itself).

**Warning signs:** Any remaining reference to `config.nerv.impermanence.mode` in disko.nix after restructuring.

### Pitfall 5: Removing `nerv.disko.swapSize` / `rootSize` / `storeSize` / `persistSize` without updating hosts/configuration.nix

**What goes wrong:** The old options are removed from the module but `hosts/configuration.nix` still references them. Nix evaluation fails with "attribute not found in module option set".

**Why it happens:** Two files must change in coordination — easy to update one and forget the other.

**How to avoid:** Phase 9 explicitly covers both files. The plan must include a task that updates `hosts/configuration.nix` in the same wave as the option rename.

**Warning signs:** `nix flake check` error referencing `nerv.disko.swapSize` or `nerv.disko.rootSize`.

### Pitfall 6: `disko.devices.lvm_vg.lvmroot` emitted for BTRFS layout

**What goes wrong:** If `lvm_vg.lvmroot` is emitted unconditionally (or when `isBtrfs` is true), disko will attempt LVM operations on a disk that has no LVM physical volume — the disk has a BTRFS filesystem instead. At install time (`disko --mode format`), disko will fail to initialize the VG.

**Why it happens:** The existing code emits `disko.devices.lvm_vg.lvmroot` at the top level of `config.disko.devices`. Moving it inside `lib.mkIf isLvm` is the required fix.

**How to avoid:** Wrap the entire `lvm_vg` block in `lib.mkIf isLvm`. Verify with `nix eval .#nixosConfigurations.host.config.disko.devices` that no `lvm_vg` key appears when `layout = "btrfs"`.

**Warning signs:** `disko.devices.lvm_vg` key visible in eval output when testing BTRFS layout path.

---

## Code Examples

Verified patterns from official sources and existing codebase:

### Complete BTRFS branch (disko content inside LUKS)

```nix
# Source: disko v1.13.0 example/luks-btrfs-subvolumes.nix + project CONTEXT.md decisions
luks = {
  size = "100%";
  content = {
    type               = "luks";
    name               = "cryptroot";
    settings.allowDiscards = true;
    extraFormatArgs    = [ "--label" "NIXLUKS" ];
    passwordFile       = "/tmp/luks-password";
    content = {
      type      = "btrfs";
      extraArgs = [ "-L" "NIXBTRFS" "-f" ];
      subvolumes = {
        "/@" = {
          mountpoint   = "/";
          mountOptions = [ "compress=zstd:3" "noatime" "space_cache=v2" ];
        };
        "/@root-blank" = {};  # no mountpoint — rollback snapshot baseline (Phase 10)
        "/@home" = {
          mountpoint   = "/home";
          mountOptions = [ "compress=zstd:3" "noatime" "space_cache=v2" ];
        };
        "/@nix" = {
          mountpoint   = "/nix";
          mountOptions = [ "compress=zstd:3" "noatime" "space_cache=v2" ];
        };
        "/@persist" = {
          mountpoint   = "/persist";
          mountOptions = [ "compress=zstd:3" "noatime" "space_cache=v2" ];
        };
        "/@log" = {
          mountpoint   = "/var/log";
          mountOptions = [ "compress=zstd:3" "noatime" "space_cache=v2" ];
        };
      };
    };
  };
};
```

### Complete LVM branch (existing code, renamed options)

```nix
# Source: existing modules/system/disko.nix — moved into lib.mkIf isLvm block
luks = {
  size = "100%";
  content = {
    type               = "luks";
    name               = "cryptroot";
    settings.allowDiscards = true;
    extraFormatArgs    = [ "--label" "NIXLUKS" ];
    passwordFile       = "/tmp/luks-password";
    content = {
      type = "lvm_pv";
      vg   = "lvmroot";
    };
  };
};
# ... and separately:
disko.devices.lvm_vg.lvmroot = {
  type = "lvm_vg";
  lvs = {
    swap = {
      size    = cfg.lvm.swapSize;
      content = { type = "swap"; extraArgs = [ "-L" "NIXSWAP" ]; };
    };
    store = {
      size    = cfg.lvm.storeSize;
      content = { type = "filesystem"; format = "ext4"; mountpoint = "/nix"; extraArgs = [ "-L" "NIXSTORE" ]; };
    };
    persist = {
      size    = cfg.lvm.persistSize;
      content = { type = "filesystem"; format = "ext4"; mountpoint = "/persist"; extraArgs = [ "-L" "NIXPERSIST" ]; };
    };
  };
};
```

### Module top-level structure with lib.mkMerge branching

```nix
# Source: existing impermanence.nix lib.mkMerge pattern
{ config, lib, ... }:

let
  cfg    = config.nerv.disko;
  isBtrfs = cfg.layout == "btrfs";
  isLvm   = cfg.layout == "lvm";
  # shared ESP + LUKS outer shell (used by both branches)
  sharedPartitions = outerPartitions: {
    ESP = {
      size = "1G";
      type = "EF00";
      content = {
        type         = "filesystem";
        format       = "vfat";
        mountpoint   = "/boot";
        mountOptions = [ "fmask=0077" "dmask=0077" ];
        extraArgs    = [ "-n" "NIXBOOT" ];
      };
    };
    luks = outerPartitions;
  };
in {
  options.nerv.disko = {
    layout = lib.mkOption { type = lib.types.enum [ "btrfs" "lvm" ]; ... };
    lvm = {
      swapSize   = lib.mkOption { ... };
      storeSize  = lib.mkOption { ... };
      persistSize = lib.mkOption { ... };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf isBtrfs {
      disko.devices.disk.main = {
        type    = "disk";
        content = { type = "gpt"; partitions = sharedPartitions { /* btrfs luks content */ }; };
      };
    })
    (lib.mkIf isLvm {
      disko.devices.disk.main = {
        type    = "disk";
        content = { type = "gpt"; partitions = sharedPartitions { /* lvm_pv luks content */ }; };
      };
      disko.devices.lvm_vg.lvmroot = { /* swap + store + persist lvs */ };
    })
  ];
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `isFullMode = config.nerv.impermanence.mode == "full"` binding | `isBtrfs`/`isLvm` from `cfg.layout` | Phase 9 | Removes cross-module dependency; disko layout is independent of impermanence mode |
| `nerv.disko.swapSize` etc. flat namespace | `nerv.disko.lvm.swapSize` sub-namespace | Phase 9 | Makes it clear LVM sizes only apply to LVM layout; cleaner API |
| Single LVM layout (minimal + full modes) | Two explicit layouts (btrfs / lvm, server-only) | Phase 9 | Drops dead minimal mode; forces explicit layout declaration per host |
| `rootSize` option (minimal mode root LV) | Removed entirely | Phase 9 | No root LV in either layout; dead API surface eliminated |

**Deprecated/outdated:**
- `nerv.disko.rootSize`: no root LV exists in either the btrfs or the new lvm (server-only) layout — remove without replacement
- `isFullMode` let binding: replaced by `isBtrfs`/`isLvm`
- Minimal LVM mode (single root LV): dropped; not referenced anywhere after Phase 8 cleanup

---

## Open Questions

1. **Whether disko injects `subvol=@` automatically or requires it in `mountOptions`**
   - What we know: disko's `type = "btrfs"` subvolume handler creates subvolumes and generates `fileSystems` entries; the official example does NOT include `subvol=@` in `mountOptions`
   - What's unclear: Whether disko adds the `subvol=` option automatically to the generated `fileSystems` entry
   - Recommendation: Follow the official example (no explicit `subvol=` in `mountOptions`); disko handles it. Verify with `nix eval .#nixosConfigurations.host.config.fileSystems` after implementation.
   - Confidence: HIGH (confirmed pattern from official example)

2. **Whether `-f` (force) flag is needed in `mkfs.btrfs` extraArgs**
   - What we know: The official disko BTRFS example uses `-f` to overwrite existing data during format
   - What's unclear: Whether omitting it causes disko to fail if run on a previously-formatted disk
   - Recommendation: Include `-f` — it is the standard disko BTRFS pattern and matches the install workflow where disko runs in `destroy,format,mount` mode
   - Confidence: MEDIUM

3. **Exact `nix-instantiate --parse` validation command path**
   - What we know: The existing test stack uses `nix-instantiate --parse modules/system/disko.nix`
   - What's unclear: Whether nix is available on this dev machine for validation
   - Recommendation: Use `nix-instantiate --parse` as smoke test; note in plan that `nixos-rebuild build` requires NixOS target
   - Confidence: HIGH (established pattern from prior phases)

---

## Validation Architecture

> nyquist_validation is true in .planning/config.json — section included.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | nix CLI (nix-instantiate --parse, nix eval, nix flake check) — no traditional test framework |
| Config file | flake.nix |
| Quick run command | `nix-instantiate --parse /home/demon/Developments/nerv.nixos/modules/system/disko.nix` |
| Full suite command | `nix flake check /home/demon/Developments/nerv.nixos` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DISKO-01 | `nerv.disko.layout = "btrfs"` evaluates without error | smoke | `nix-instantiate --parse /home/demon/Developments/nerv.nixos/modules/system/disko.nix` | ✅ |
| DISKO-01 | BTRFS branch declares 6 subvolumes (@, @root-blank, @home, @nix, @persist, @log) | smoke | `nix eval /home/demon/Developments/nerv.nixos#nixosConfigurations.host.config.disko.devices 2>/dev/null \| grep -c '@'` | ✅ |
| DISKO-02 | `nerv.disko.layout = "lvm"` evaluates without error; `lvm_vg.lvmroot` present | smoke | `nix-instantiate --parse /home/demon/Developments/nerv.nixos/modules/system/disko.nix` | ✅ |
| DISKO-03 | All 5 mounted subvolumes have compress=zstd:3, noatime, space_cache=v2 | smoke | `grep -c 'space_cache=v2' /home/demon/Developments/nerv.nixos/modules/system/disko.nix` (expect 5) | ✅ |
| DISKO-03 | No swap declared in BTRFS branch | smoke | Verify via `nix eval` or code inspection: no `type = "swap"` inside isBtrfs block | ✅ |

Note: `nix eval` commands require `nerv.disko.layout` to be set in the evaluated configuration. Since `hosts/configuration.nix` will have `"PLACEHOLDER"` (an invalid enum value), the full `nix eval` path will fail until the value is changed. The parse check and grep checks are the reliable automated checks for this phase.

### Sampling Rate

- **Per task commit:** `nix-instantiate --parse /home/demon/Developments/nerv.nixos/modules/system/disko.nix`
- **Per wave merge:** `nix flake check /home/demon/Developments/nerv.nixos`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

None — `modules/system/disko.nix` and `hosts/configuration.nix` already exist. No new test infrastructure required. The existing `nix-instantiate --parse` pattern covers Nix syntax validation.

---

## Sources

### Primary (HIGH confidence)
- `modules/system/disko.nix` (existing codebase) — current LVM logic that becomes the "lvm" branch verbatim
- `modules/system/impermanence.nix` (existing codebase) — `lib.mkMerge` / `lib.types.enum` / no-default option pattern
- `modules/system/boot.nix` (existing codebase) — confirms LUKS mapping name `cryptroot`, LVM initrd services
- `.planning/phases/09-btrfs-disko-layout/09-CONTEXT.md` — all locked decisions
- `.planning/STATE.md` (v2.0 pre-phase decisions) — confirmed BTRFS device path, no-swap rationale, @nix mandatory

### Secondary (MEDIUM confidence)
- disko v1.13.0 `example/luks-btrfs-subvolumes.nix` (fetched via WebFetch) — confirms `type = "btrfs"`, `subvolumes` attrset, `mountOptions` attribute names; no `subvol=` needed in mountOptions
- disko v1.13.0 `lib/types/btrfs.nix` (fetched via WebFetch) — confirms `type = "btrfs"` enum value, `subvolumes` option type, supported subvolume attributes (`mountpoint`, `mountOptions`, `extraArgs`)
- `.planning/phases/07-flake-hardening-disko-nyquist/07-RESEARCH.md` — disko v1.13.0 confirmed as current pinned version; `disko.nixosModules.disko` module already wired

### Tertiary (LOW confidence)
- None for this phase — all critical claims are backed by primary or secondary sources.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — disko v1.13.0 already pinned; btrfs content type confirmed from official example
- Architecture (BTRFS branch): HIGH — direct from disko official example + CONTEXT.md locked decisions
- Architecture (LVM branch): HIGH — direct from existing codebase code
- Option namespace: HIGH — `lib.types.enum` / no-default pattern confirmed from existing modules
- Pitfalls: HIGH — derived from code reading and known NixOS module system behavior
- Validation: HIGH — established grep/parse pattern from prior phases

**Research date:** 2026-03-09
**Valid until:** 2026-04-09 (disko releases infrequently; btrfs content type API stable since v1.x)
