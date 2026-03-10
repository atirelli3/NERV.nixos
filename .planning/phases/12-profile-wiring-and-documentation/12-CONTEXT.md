# Phase 12: Profile Wiring and Documentation - Context

**Gathered:** 2026-03-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Wire `nerv.disko.layout` and the correct `nerv.impermanence.mode` into the two remaining
profiles in `flake.nix` (hostProfile, serverProfile); remove vmProfile and
`nixosConfigurations.vm` entirely; update module headers on `disko.nix`, `boot.nix`, and
`impermanence.nix` with Phase 12 profile cross-references; update `README.md` with a
BTRFS-specific install subsection (full walkthrough, mandatory @root-blank snapshot step)
and a corrected Repository Layout section; clean up `hosts/configuration.nix` header.
Profile behavior or module logic is NOT changed here — this is wiring + documentation only.

</domain>

<decisions>
## Implementation Decisions

### vmProfile removal

- Remove `vmProfile` let-binding entirely from `flake.nix`
- Remove `nixosConfigurations.vm` entirely from `flake.nix`
- No inline replacement — clean removal, not folded into another config

### hostProfile wiring

- Add `nerv.disko.layout = "btrfs"` to hostProfile
- Change `nerv.impermanence.mode` from `"minimal"` → `"btrfs"`
- All other hostProfile options remain unchanged

### serverProfile wiring

- Add `nerv.disko.layout = "lvm"` to serverProfile
- `nerv.impermanence.mode = "full"` stays as-is (no change)
- All other serverProfile options remain unchanged

### nerv.impermanence.mode ownership

- Mode stays **profile-level only** (set in flake.nix profiles)
- `hosts/configuration.nix` does NOT get a `nerv.impermanence.mode` PLACEHOLDER
- Machine identity stays disk-level only; feature modes stay in profiles

### hosts/configuration.nix header

- Remove `vmProfile` references from the Role/comments section
- No other changes to `configuration.nix` content

### Module headers (disko.nix, boot.nix, impermanence.nix)

- Update all three headers to add Phase 12 profile cross-references:
  - Note which profile consumes which layout/mode
  - e.g. "hostProfile: layout=btrfs, mode=btrfs | serverProfile: layout=lvm, mode=full"
- No new option documentation needed — headers already current from Phases 9–11

### README.md — BTRFS install subsection

- Add `### B — BTRFS layout (hostProfile)` subsection inside the existing Installation section
- Full walkthrough: same steps as Section A, but with an explicit step after disko:
  ```
  btrfs subvolume snapshot -r /mnt/@ /mnt/@root-blank
  ```
- Order explicitly documented: run disko → create @root-blank → nixos-install
- Include pre-requisites and full commands with flags (user requested full walkthrough)
- nixos-install target: `#host`

### README.md — Profiles table and stale content

- Remove `vm` row from the Profiles table
- Update the Profiles table descriptions for host/server to reflect btrfs/lvm layout
- Update "What NERV provides" description for impermanence: replace `minimal` mode
  references with `btrfs` mode (BTRFS rollback-on-boot for desktop)

### README.md — Repository Layout

- Update Repository Layout section to reflect actual current file structure:
  - Replace `disko-configuration.nix` with `disko.nix` (in `modules/system/`)
  - Add `impermanence.nix` to module list
  - Update `boot.nix` description to "layout-agnostic initrd + bootloader"
  - Remove any references to removed or renamed files

### Claude's Discretion

- Exact wording of the BTRFS install subsection prose and callout formatting
- Whether to add a Warning block (like Section A) for the snapshot step
- Exact cross-reference wording in module headers
- Order of steps within the BTRFS README subsection (can mirror Section A structure)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets

- `flake.nix` hostProfile/serverProfile blocks: straightforward attribute additions; existing
  structure (aligned = signs) should be preserved for readability
- README.md `### A — New system (NixOS Live ISO)` section: template for Section B structure;
  BTRFS section mirrors it with an additional snapshot step between disko and nixos-install
- `disko.nix` header LUKS block already has the one-liner `@root-blank` note — Section B
  README prose can reference this and expand it

### Established Patterns

- flake.nix profile alignment: existing profiles use aligned `=` padding — maintain this style
- README section headers: `### X — Description` pattern (see `### A — New system`)
- Module headers: `# Options :` and `# Note :` sections are the right place for cross-references

### Integration Points

- `flake.nix` `nixosConfigurations.vm` block references `vmProfile` — both must be removed together
- README Profiles table references vm — must be removed; Impermanence description must drop "minimal"
- `hosts/configuration.nix` header comments reference `vmProfile` by name — update to hostProfile/serverProfile only

</code_context>

<specifics>
## Specific Ideas

- Install procedure: full walkthrough (not minimal). Mirror the structure of `### A — New system`
  in README but add the explicit BTRFS snapshot step between disko run and nixos-install.
- vmProfile: clean removal — no stub, no comment, no inline replacement.

</specifics>

<deferred>
## Deferred Ideas

- None — discussion stayed within phase scope

</deferred>

---

*Phase: 12-profile-wiring-and-documentation*
*Context gathered: 2026-03-10*
