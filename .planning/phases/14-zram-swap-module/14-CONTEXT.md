# Phase 14: zram Swap Module - Context

**Gathered:** 2026-03-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Add `nerv.disko.btrfs.zram.{enable,memoryPercent}` options to `disko.nix` so operators on the BTRFS host profile can enable in-memory compressed swap with a single option. LVM layout + zram.enable = true must fail at evaluation with a clear error. This phase touches only `modules/system/disko.nix` — zero dependencies on Phase 15 (starship).

</domain>

<decisions>
## Implementation Decisions

### Module file placement
- Extend `modules/system/disko.nix` (not a new swap.nix) — option namespace `nerv.disko.btrfs.zram.*` is already scoped to disko; co-location makes the BTRFS constraint self-documenting
- Add `btrfs.zram` as a sub-attribute inside the existing `options.nerv.disko` block, alongside `lvm.*`
- zram config (`zramSwap = { ... }`) is appended inside the existing `lib.mkIf isBtrfs` branch — co-located with the layout it belongs to

### Options structure
- `nerv.disko.btrfs.zram.enable` — `lib.types.bool`, default `false`
- `nerv.disko.btrfs.zram.memoryPercent` — `lib.types.ints.between 1 100`, default `50`
- memoryPercent (not MB) — avoids nixpkgs #435071 memoryMax+memoryPercent interaction bug; MB-based option deferred to v4.0 (SWAP-05)

### zramSwap configuration
- `zramSwap.priority = 100` — explicitly prefer zram over any other swap source; inline comment: `# prefer zram over any other swap source`
- `zramSwap.algorithm = "zstd"` — hardcoded in v3.0; `lib.mkForce` escape hatch for users who need to override; v4.0 exposes this as `nerv.disko.btrfs.zram.algorithm`
- No device count option — single `/dev/zram0` is sufficient; nixpkgs `numDevices` default is fine

### Assertion / error message
- Top-level in `config = lib.mkMerge [ ... ]` as the first entry: `(lib.mkIf cfg.btrfs.zram.enable (lib.mkAssert (isBtrfs) "…"))` — evaluated on all layouts, not just LVM branch
- Error message (informative, multi-line):
  ```
  nerv: nerv.disko.btrfs.zram.enable requires
    nerv.disko.layout = "btrfs".
    The LVM layout provides disk-based swap via the swap LV.
    Disable zram or switch to the btrfs layout.
  ```

### Documentation
- Module header `# Profiles` cross-reference already present — no change needed
- Inline comment on priority explaining the non-default value
- `init_on_free=1` CPU tradeoff note: add a comment in disko.nix near the zram block noting that kernel.nix sets `init_on_free=1` and that heavy zram usage under zstd adds CPU overhead — document, do not change behavior

### Claude's Discretion
- Exact option description wording for `memoryPercent` (nixpkgs-style prose vs brief)
- Whether to include a `example` value in the option definition for `memoryPercent`
- Ordering of zramSwap attributes within the config block

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `isBtrfs` / `isLvm` let-bindings already in disko.nix — reuse directly for the assertion and config guard
- `cfg` alias (`config.nerv.disko`) already established — `cfg.btrfs.zram.enable` follows the pattern

### Established Patterns
- `options.nerv.disko.lvm.*` block — mirrors the structure for `btrfs.zram.*`
- `lib.mkIf isBtrfs { ... }` branch structure — append zram config inside this block
- Comment style: `# inline comment for non-obvious lines`, section headers with `# ── SECTION ──`
- `lib.mkMerge [ (lib.mkIf ...) (lib.mkIf ...) ]` — assertion goes as first entry in this list

### Integration Points
- `zramSwap` is a top-level NixOS option (no import needed — `nixpkgs` provides it)
- No changes to `modules/system/default.nix` (disko.nix already imported)
- No changes to `flake.nix` or any other module

</code_context>

<specifics>
## Specific Ideas

- Assertion should be a `lib.mkIf cfg.btrfs.zram.enable (lib.mkAssert isBtrfs "…")` pattern — catches the error regardless of which layout is set
- zram block appended to the BTRFS `lib.mkIf` — visually clear that it's BTRFS-only without an extra nesting level

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 14-zram-swap-module*
*Context gathered: 2026-03-12*
