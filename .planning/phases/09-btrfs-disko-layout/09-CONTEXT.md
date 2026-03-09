# Phase 9: BTRFS Disko Layout - Context

**Gathered:** 2026-03-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Add `nerv.disko.layout` option to `modules/system/disko.nix`. Setting `"btrfs"` produces a GPT/LUKS/BTRFS disk with 6 subvolumes. Setting `"lvm"` produces the existing LVM layout (now server-only: swap + /nix + /persist LVs). Boot rollback initrd service, impermanence BTRFS mode, and profile wiring are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Layout option

- `nerv.disko.layout` has **no default** — forced declaration, like `nerv.hostname`
- Accepted values: `"btrfs"` | `"lvm"` (enum, eval error if unset)
- Prevents silent misconfiguration; consistent with other nerv.* options that have no safe generic default

### BTRFS layout (nerv.disko.layout = "btrfs")

- GPT → 1G ESP (NIXBOOT) → 100% LUKS (cryptroot/NIXLUKS) → BTRFS filesystem
- Subvolumes: @, @root-blank, @home, @nix, @persist, @log — all mandatory
- All BTRFS subvolumes mount with: `compress=zstd:3`, `noatime`, `space_cache=v2`
- **No swap** in BTRFS branch (BTRFS CoW incompatibility with swap files)
- No per-subvolume size options — BTRFS shares the pool

### LVM layout (nerv.disko.layout = "lvm")

- LVM is **server-only** (full mode): swap LV + /nix LV + /persist LV
- The LVM minimal mode (single root LV for desktop) is **dropped**
- rootSize option is **removed entirely** — no dead API surface
- Swap is kept in the LVM branch (server may need swap)
- LVM branch preserves: GPT → ESP → LUKS → LVM PV → VG lvmroot

### Option namespace restructuring

- LVM size options move from `nerv.disko.*` to `nerv.disko.lvm.*` sub-namespace:
  - `nerv.disko.lvm.swapSize` (was `nerv.disko.swapSize`)
  - `nerv.disko.lvm.storeSize` (was `nerv.disko.storeSize`)
  - `nerv.disko.lvm.persistSize` (was `nerv.disko.persistSize`)
- `nerv.disko.rootSize` is dropped entirely (no root LV in either layout)
- BTRFS branch has no size options under `nerv.disko.btrfs.*` — not needed

### hosts/configuration.nix updates

- Phase 9 updates `hosts/configuration.nix` to reflect the new API
- `nerv.disko.layout = "PLACEHOLDER"; # "btrfs" for desktop/laptop | "lvm" for server`
- Old `nerv.disko.{swapSize,rootSize,storeSize,persistSize}` replaced with `nerv.disko.lvm.{swapSize,storeSize,persistSize}`
- `nerv.disko.lvm.*` entries annotated as relevant only when `nerv.disko.layout = "lvm"`

### Claude's Discretion

- BTRFS filesystem label (e.g. NIXBTRFS or similar)
- Disko content type structure for BTRFS subvolumes (filesystem vs btrfs subvolume content type)
- Whether to use disko's native btrfs subvolume support or raw fileSystems entries
- Comment style and header updates to disko.nix to document new option surface

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets

- `modules/system/disko.nix`: The existing LVM logic becomes the "lvm" branch. The GPT/ESP/LUKS wrapper is shared structure — BTRFS branch reuses the same outer partitioning (ESP + LUKS container), replacing the LVM PV content with a BTRFS filesystem.
- `isFullMode` let binding in disko.nix: Becomes dead code once LVM is server-only (full mode always). Replace with `isLvm = cfg.layout == "lvm"` and `isBtrfs = cfg.layout == "btrfs"`.

### Established Patterns

- `lib.mkOption` with `lib.types.enum` and no default: used for `nerv.disko.layout` (consistent with `nerv.hardware.cpu`, `nerv.hardware.gpu`)
- `lib.mkIf` / `lib.mkMerge` branching: existing pattern in `impermanence.nix` — applicable for layout-conditional config blocks
- Section-header comment block: all modules have `# Purpose`, `# Options`, `# Defaults`, `# Override` headers — disko.nix header needs updating

### Integration Points

- `modules/system/impermanence.nix`: References `config.nerv.impermanence.mode == "full"` for its own logic. The new `nerv.disko.layout` is orthogonal — disko.nix and impermanence.nix remain separate concerns. No cross-wiring needed in Phase 9.
- `hosts/configuration.nix`: Direct consumer of `nerv.disko.*` options — updated in this phase
- `flake.nix` profiles: `hostProfile` and `serverProfile` still have `nerv.impermanence.mode` but no `nerv.disko.layout` yet — Phase 12 adds those

</code_context>

<specifics>
## Specific Ideas

- No specific references — open to standard disko btrfs patterns

</specifics>

<deferred>
## Deferred Ideas

- None — discussion stayed within phase scope

</deferred>

---

*Phase: 09-btrfs-disko-layout*
*Context gathered: 2026-03-09*
