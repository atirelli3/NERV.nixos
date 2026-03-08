# Phase 7: Flake Hardening, Disko Wiring, and Nyquist Validation - Context

**Gathered:** 2026-03-08
**Status:** Ready for planning

<domain>
## Phase Boundary

Remove or document the unused `impermanence` flake input; make secureboot/impermanence intent explicit in `hosts/nixos-base/configuration.nix`; wire `disko` as a proper flake input for declarative disk management; complete Nyquist-compliant VALIDATION.md for all 6 existing phases.

This is tech debt closure only — no new v1.0 requirements.

</domain>

<decisions>
## Implementation Decisions

### impermanence flake input
- Remove the `impermanence` input entirely from `flake.nix` inputs and the `outputs` function signature
- Rationale: `modules/system/impermanence.nix` is self-contained (uses native fileSystems + tmpfs); it explicitly does not use the upstream nixos-community/impermanence module
- The module continues to exist and function — only the unused flake input is removed

### disko wiring
- Add `disko` as a flake input with `inputs.nixpkgs.follows = "nixpkgs"` in `flake.nix`
- Add `disko.nixosModules.disko` to the `nixosConfigurations.nixos-base` modules list in `flake.nix`
- Import `./hosts/nixos-base/disko-configuration.nix` in the nixosConfigurations entry in `flake.nix` (not in configuration.nix)
- Remove the `fileSystems` and `swapDevices` overrides from `configuration.nix` — let disko control disk declarations
- Before removing overrides: audit `disko-configuration.nix` and ensure security-relevant mount options are present (fmask=0077, dmask=0077 on /boot, correct ext4 options on /)

### secureboot/impermanence in configuration.nix
- Add `nerv.secureboot.enable = false` and `nerv.impermanence.enable = false` explicitly in `configuration.nix`
- Placement: grouped with other disabled `nerv.*` service options (near the end with the existing `nerv.audio.enable = false` etc.)
- Each declaration gets a brief inline comment pointing to the relevant module and explaining what enabling it requires
  - e.g. `# enable in modules/system/secureboot.nix — requires TPM2 + UEFI firmware`
  - e.g. `# enable in modules/system/impermanence.nix — mounts /tmp, /var/tmp as tmpfs`
- Grouped under a `# Disabled features — explicitly declared to make activation path visible to operators` comment header

### Nyquist validation approach
- Use hybrid approach: run what is runnable in the dev environment (nix flake show, grep-based commands), mark remaining checks based on code review for tasks that require a real NixOS machine
- Update ALL sections of each VALIDATION.md — Wave 0 requirements checklist, task status rows (pending → ✅ green or ❌ red), Validation Sign-Off checkboxes, and frontmatter (`nyquist_compliant: true`)
- Add missing automated test commands where gaps exist (tasks with no `Automated Command` entry)
- Scope: strictly the 6 existing VALIDATION.md files (phases 1–6) — no new test infrastructure

### Claude's Discretion
- Exact pinned tag/URL for the disko flake input (look up nix-community/disko current stable)
- Order of modules in nixosConfigurations.nixos-base (keep existing order, append disko + disko-configuration.nix)
- Exact syntax for importing disko-configuration.nix as a module in nixosConfigurations

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `flake.nix`: existing input pattern with `inputs.nixpkgs.follows = "nixpkgs"` — apply same pattern for disko
- `hosts/nixos-base/disko-configuration.nix`: already exists, likely needs mount option audit
- `modules/system/impermanence.nix`: self-contained, no upstream dependency — safe to remove flake input

### Established Patterns
- flake inputs: `url` + `inputs.nixpkgs.follows = "nixpkgs"` (see lanzaboote, home-manager)
- nixosConfigurations modules list order: lanzaboote → home-manager → self.nixosModules.default → configuration.nix
- lib.mkForce pattern in configuration.nix: currently used for fileSystems overrides (will be removed)
- Disabled service options in configuration.nix use `= false` with inline comment explaining reason

### Integration Points
- `flake.nix` outputs function: needs disko added to destructured args and modules list
- `hosts/nixos-base/configuration.nix`: fileSystems + swapDevices blocks removed; two new disabled-feature declarations added
- `.planning/phases/0{1-6}-*/0{1-6}-VALIDATION.md`: 6 files to update to compliant status

</code_context>

<specifics>
## Specific Ideas

- The existing comment in `configuration.nix` that says "lib.mkForce overrides the Disko-generated mounts" is the thing being removed — once disko module is wired, the override comment becomes obsolete
- VALIDATION.md format reference: Phase 1 VALIDATION.md has the standard structure (frontmatter, Test Infrastructure, Sampling Rate, Per-Task Verification Map, Wave 0 Requirements, Manual-Only Verifications, Validation Sign-Off)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 07-flake-hardening-disko-nyquist*
*Context gathered: 2026-03-08*
