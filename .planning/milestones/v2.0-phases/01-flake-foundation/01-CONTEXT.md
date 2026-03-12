# Phase 1: Flake Foundation - Context

**Gathered:** 2026-03-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Update flake.nix inputs, create the directory skeleton (modules/system/, modules/services/, home/), and wire nixosModules exports. No module migration happens here — this is purely structural scaffolding. The existing system must continue to build throughout.

Requirements: STRUCT-01, STRUCT-04, STRUCT-05

</domain>

<decisions>
## Implementation Decisions

### Flake location
- Create a new root-level `flake.nix` — this is where `nixosModules.*` exports live
- `base/flake.nix` is kept and becomes the host example flake (not removed)
- `base/flake.nix` switches from importing individual module files to using `inputs.nerv.url = "path:.."` and consuming `nerv.nixosModules.default` — this validates the export path end-to-end

### Inputs
- All inputs (nixpkgs, lanzaboote, home-manager, impermanence) live in the root `flake.nix` only — no duplication into `base/flake.nix`
- `home-manager` and `impermanence` added with `inputs.nixpkgs.follows = "nixpkgs"` on both
- `lanzaboote` moves to root flake (secureboot.nix is part of the nerv library, so its dependency belongs there)

### nixosModules exports
- `nixosModules.default` = all three: system + services + home aggregated
- `nixosModules.system`, `nixosModules.services`, `nixosModules.home` exported individually for granular host flake use
- Root `modules/default.nix` imports `./system`, `./services`, and `../home` — no legacy flat module re-export

### Stub content
- `modules/system/default.nix`, `modules/services/default.nix`, and `home/default.nix` are all `{ imports = []; }` — minimal empty stubs
- `home/default.nix` has no option skeleton yet — HM wiring is Phase 5's job
- Real modules get added to the stubs in Phase 2 (services) and Phase 3 (system)

### Claude's Discretion
- Exact formatting and comment style within stub files
- Whether to add a placeholder comment in stubs noting which phase populates them

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `base/flake.nix`: Current inputs/outputs pattern — the lanzaboote `inputs.nixpkgs.follows` style is already established and should be replicated for home-manager and impermanence
- `modules/` (flat, 10 .nix files): All remain in place during Phase 1; none are moved yet

### Established Patterns
- `inputs.X.inputs.nixpkgs.follows = "nixpkgs"` — already used for lanzaboote, apply to all new inputs
- Individual module imports via path — Phase 1 replaces this in `base/flake.nix` with the aggregated `nixosModules.default`

### Integration Points
- `base/flake.nix` → root `flake.nix` via `inputs.nerv.url = "path:.."` — the host example consumes the library output
- `nixosConfigurations.nixos-base` remains in `base/flake.nix` for the test/verification build
- Root `modules/default.nix` → `modules/system/`, `modules/services/`, `home/` stubs

</code_context>

<specifics>
## Specific Ideas

- The `base/flake.nix` post-Phase-1 shape:
  ```nix
  inputs.nerv.url = "path:..";
  modules = [
    nerv.nixosModules.default
    ./configuration.nix
  ];
  ```
- Root `flake.nix` outputs shape:
  ```nix
  nixosModules = {
    default  = import ./modules/default.nix;
    system   = import ./modules/system;
    services = import ./modules/services;
    home     = import ./home;
  };
  ```

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 01-flake-foundation*
*Context gathered: 2026-03-06*
