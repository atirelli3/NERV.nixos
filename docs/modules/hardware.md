# Module: Hardware

**File:** `modules/system/hardware.nix`

CPU microcode, GPU drivers, firmware loading, TRIM, and firmware updates. Always active.

---

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.hardware.cpu` | `"amd" \| "intel" \| "other"` | `"other"` | CPU vendor. Enables microcode and IOMMU kernel params. |
| `nerv.hardware.gpu` | `"amd" \| "nvidia" \| "intel" \| "none"` | `"none"` | GPU vendor. Enables the appropriate driver. |

---

## What it always enables

Regardless of CPU/GPU choice, these are always on:

| Feature | NixOS option |
|---------|-------------|
| Redistributable firmware | `hardware.enableAllFirmware = true` |
| Firmware updates (LVFS) | `services.fwupd.enable = true` |
| Weekly SSD TRIM | `services.fstrim.enable = true` |

---

## CPU selection

| Value | Effect |
|-------|--------|
| `"amd"` | `hardware.cpu.amd.updateMicrocode = true`; IOMMU (`amd_iommu=on iommu=pt`) |
| `"intel"` | `hardware.cpu.intel.updateMicrocode = true`; IOMMU (`intel_iommu=on iommu=pt`) |
| `"other"` | No microcode or IOMMU configuration |

---

## GPU selection

| Value | Effect |
|-------|--------|
| `"amd"` | `hardware.amdgpu.enable = true` |
| `"nvidia"` | `hardware.nvidia.modesetting.enable = true`; `hardware.nvidia.open = true` (Turing+ open kernel module) |
| `"intel"` | `hardware.intel.gpu.enable = true` |
| `"none"` | No GPU driver configured |

**NVIDIA note:** `hardware.nvidia.open = true` targets Turing+ (RTX 20xx and newer). For Maxwell or Pascal GPUs, override in `hosts/configuration.nix`:

```nix
{ lib, ... }: {
  hardware.nvidia.open = lib.mkForce false;
}
```

---

## Example

```nix
nerv.hardware.cpu = "amd";
nerv.hardware.gpu = "nvidia";
```

---

## Using fwupd

```bash
# List available firmware updates
fwupdmgr get-updates

# Apply firmware updates
fwupdmgr update
```
