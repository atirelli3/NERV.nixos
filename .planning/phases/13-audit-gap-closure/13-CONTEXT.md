# Phase 13: Audit Gap Closure — Context

**Gathered:** 2026-03-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Close the four concrete gaps identified by the v2.0 milestone audit:
1. Wire `nixosConfigurations.server` (and its `server` let-binding) into `flake.nix`
2. Insert the mandatory `@root-blank` BTRFS snapshot step into the README BTRFS install walkthrough
3. Add `# Profiles :` cross-reference comments to `disko.nix`, `boot.nix`, and `impermanence.nix` headers
4. Fix the stale comment on `modules/system/default.nix` line 13

No module logic, no option changes, no new features. Wiring + documentation only.

</domain>

<decisions>
## Implementation Decisions

### server nixosConfiguration structure

- Add a `server` let-binding in the `let` block, **immediately after the `host` let-binding**
- `server` contains: `nerv.disko.layout = "lvm"` and `nerv.impermanence.mode = "full"` (plus `nerv.impermanence.enable = true`)
- All other server options left at defaults (openssh, secureboot, audio, bluetooth, printing stay at defaults)
- `nixosConfigurations.server` mirrors `nixosConfigurations.host` exactly: same module list
  (`lanzaboote`, `home-manager`, `impermanence`, `disko`, `self.nixosModules.default`, the `server` let-binding, `./hosts/configuration.nix`)
- `nerv.secureboot.enable` defaults to `false` so lanzaboote is imported but Secure Boot is off — no special handling needed

### # Profiles : cross-reference comments

Use **key=value format** for files that have profile-specific values; bare names for files that are layout-agnostic.

- `disko.nix` header: `# Profiles : host layout=btrfs | server layout=lvm`
- `impermanence.nix` header: `# Profiles : host mode=btrfs | server mode=full`
- `boot.nix` header: `# Profiles : host | server` (boot.nix is layout-agnostic — no values to show)

Comment goes as an additional line in the existing header block (after the current description line).

### @root-blank snapshot step

- Inserted as a **standalone numbered step** between current step 6 (disko) and current step 7 (copy repo)
- Becomes new step 7; subsequent steps shift by +1 (old 7→8, 8→9, ... 13→14)
- Architecture: `@root-blank` is the **clean-root template** for the "delete your darlings" rollback.
  On every boot, the initrd service deletes `@` and recreates it from `@root-blank`, giving a
  stateless `/`. This is NOT impermanence/persist — it is a full clean-state reset on boot.
  Without `@root-blank` created during install, the rollback service has no template → broken first boot.
- Include a brief inline comment:
  ```bash
  # Required: @root-blank is the clean-root template — initrd deletes @ and restores from this on every boot.
  btrfs subvolume snapshot -r /mnt/@ /mnt/@root-blank
  ```

### modules/system/default.nix line 13 comment

- Change the stale comment on the `disko.nix` import line to read exactly:
  `# declarative disk layout (btrfs/lvm) with layout-conditional initrd services`

### Claude's Discretion

- Exact alignment/padding of the `server` let-binding (follow existing aligned `=` style from `host`)
- Whether to add a `nerv.openssh.enable = true` to `server` let-binding for explicitness (or leave at default)
- Exact placement of the `# Profiles :` line within each header block (after description, before blank line)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets

- `flake.nix` `host` let-binding: direct template for `server` let-binding — same structure, different values
- `nixosConfigurations.host` module list: copy verbatim for `nixosConfigurations.server`, swap `host` → `server`
- README `### A — New system (BTRFS layout, host profile)` step numbering: steps 7–13 shift to 8–14 after snapshot insertion

### Established Patterns

- `flake.nix` profile alignment: existing profiles use aligned `=` padding — maintain this style in `server` let-binding
- Module headers: single-line format `# Description text` — `# Profiles :` line follows same style
- README step format: `# N. Description.\ncommand` — snapshot step follows this convention

### Integration Points

- `flake.nix` outputs.nixosConfigurations: both `host` and `server` must be present for `nix eval .#nixosConfigurations.server.*` to work
- `modules/system/default.nix` import list: line 13 is the `disko.nix` import — comment change is cosmetic only, no functional effect

</code_context>

<specifics>
## Specific Ideas

- Architecture principle: `@root-blank` / BTRFS rollback is "delete your darlings" — every boot gives a
  fresh `/`, not impermanence-style persistence. The README comment should reflect this framing.
- `nixosConfigurations.server` mirrors host exactly so `nix eval .#nixosConfigurations.server.config.nerv.disko.layout`
  resolves cleanly without errors.

</specifics>

<deferred>
## Deferred Ideas

- None — discussion stayed within phase scope

</deferred>

---

*Phase: 13-audit-gap-closure*
*Context gathered: 2026-03-12*
