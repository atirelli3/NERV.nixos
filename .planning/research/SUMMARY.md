# Project Research Summary

**Project:** nerv.nixos — NixOS module library refactor
**Domain:** NixOS flake / module system infrastructure
**Researched:** 2026-03-06
**Confidence:** HIGH

## Executive Summary

nerv.nixos is a hardened NixOS module library whose core value proposition is letting a user declare only machine-specific parameters and receive a secure, well-documented NixOS system. The refactor converts an existing working-but-flat module tree into a properly structured library: `modules/system/` for kernel-space and boot-critical concerns, `modules/services/` for safely-togglable daemons, and a `home/` skeleton for Home Manager integration. The primary deliverable is a typed NixOS module options API under the `nerv.*` namespace that replaces hardcoded values and gives consumers a documented, type-checked override surface.

The recommended approach is a build-order-aware incremental migration: move lower-risk service modules first, extract boot/hardware last, add `options.nerv.*` blocks as each file is touched. All three integrations — Home Manager, impermanence, and lanzaboote — require one-time flake.nix changes that must happen before module work begins. The aggregator pattern (`default.nix` per subdirectory, named module sets in `nixosModules`) keeps host flakes clean: a single `nerv.nixosModules.default` import and a handful of `nerv.*` option assignments.

The key risks are concentrated in two areas: boot-chain ordering (lanzaboote vs systemd-boot `lib.mkForce` conflicts, TPM2 enrollment sequencing, LUKS label consistency) and SSH lockout via `AllowUsers`. Both are fully preventable with correct import ordering, inline documentation, and safe defaults (`allowUsers = []`). Impermanence introduces one non-obvious mandatory persistence entry (`/var/lib/sbctl`) that must be wired before secureboot is enabled. All other pitfalls are correctness issues (deprecated types, Avahi implicit dependency) that are caught at evaluation time if types are used properly.

---

## Key Findings

### Recommended Stack

The project is pure NixOS flakes — no non-Nix tooling. The NixOS module options API (`lib.mkOption`, `lib.types`, `lib.mkIf`, `lib.mkDefault`, `lib.mkForce`) is stable through NixOS 25.11 and is the canonical pattern for this refactor. Three external inputs are required: `nixpkgs`, `home-manager` (with `inputs.nixpkgs.follows = "nixpkgs"` mandatory to avoid double evaluation), and `impermanence`. Lanzaboote must be pinned to a specific tag (`v0.4.1` or current) rather than floating `main` for reproducibility.

**Core technologies:**
- `lib.mkOption` / `lib.types`: typed option declarations — stable NixOS core, self-documenting API surface
- `home-manager` (NixOS module mode): single `nixos-rebuild switch` workflow, no separate HM switch command
- `impermanence` (nix-community): tmpfs root persistence control — tracks `main` branch, no pin needed
- `lanzaboote` (pinned tag): secure boot integration — must be pinned to a specific release tag
- `disko`: declarative disk partitioning — existing in repo, contains placeholder strings that need documentation

### Expected Features

Research identified a clear priority ordering for the `options.nerv.*` API. Identity/locale options and hardware options are needed by every host. SSH options are high-value because they are the most common security customization point. Audio/bluetooth are common desktop toggles. Impermanence and Home Manager are advanced opt-in features. Secureboot is hardware-dependent.

**Must have (table stakes) — every host sets these:**
- `nerv.hostname`, `nerv.locale.*`, `nerv.primaryUser` — identity; maps to standard NixOS options
- `nerv.hardware.cpu` (enum: amd/intel/other), `nerv.hardware.gpu` (enum: amd/nvidia/intel/none) — drives microcode and kernel params
- `nerv.openssh.*` (enable, allowUsers, passwordAuth, port) — security-critical, most common override target

**Should have (differentiating opt-in features):**
- `nerv.audio.enable`, `nerv.bluetooth.enable`, `nerv.printing.enable` — common desktop toggles, default false
- `nerv.impermanence.*` (enable, persistPath, extraDirs, users) — tmpfs root persistence control
- `nerv.home.enable`, `nerv.home.users` — Home Manager integration
- `nerv.kernel.package`, `nerv.nix.gcInterval`, `nerv.nix.autoUpdate` — tuning knobs

**Defer / anti-features (deliberately not exposed):**
- `PasswordAuthentication = true` toggle — users who need it use `lib.mkForce`; exposing is a security regression
- Per-sysctl boolean toggles, DE/WM/DM config, full home impermanence, audit rule tuning, `AllowRoot` SSH

### Architecture Approach

The target structure uses two module subdirectories with a strict separation rule: anything whose misconfiguration can cause boot failure or requires a live USB to fix goes in `modules/system/`; anything that can be toggled without risk to the boot chain goes in `modules/services/`. Each subdirectory has a `default.nix` aggregator with only `imports`. The root `flake.nix` exports named module sets (`system`, `services`, `home`, `default`) so host flakes import one attribute and configure via options.

**Major components:**
1. `modules/system/` — boot.nix, hardware.nix, kernel.nix, secureboot.nix, security.nix, nix.nix, impermanence.nix (boot-chain critical)
2. `modules/services/` — openssh.nix, pipewire.nix, bluetooth.nix, printing.nix, zsh.nix (safely togglable)
3. `home/` — default.nix skeleton setting global HM defaults; per-user config stays in host flake
4. `flake.nix` — input declarations (HM follows nixpkgs), `nixosModules` named exports, aggregator wiring

### Critical Pitfalls

1. **sbctl on tmpfs root (CRITICAL)** — `/var/lib/sbctl` is lost every reboot without explicit persistence, causing infinite re-enrollment loops and TPM2 slot destruction. Prevention: `environment.persistence."/persist".directories = [ "/var/lib/sbctl" ]` must be in `impermanence.nix` before secureboot is enabled.

2. **LUKS label typo (CRITICAL)** — mismatch between `disko-configuration.nix` label and `configuration.nix` `luks.devices` reference causes silent boot failure. Prevention: cross-reference comment in `boot.nix` and verify string equality during extraction.

3. **AllowUsers SSH lockout (CRITICAL)** — a typo in `nerv.openssh.allowUsers` blocks all SSH logins immediately on `nixos-rebuild switch`. Prevention: default `allowUsers = []` (empty = all users), recommend `nixos-rebuild test` before `switch` when changing this option, document in module.

4. **lanzaboote vs systemd-boot mkForce conflict (MODERATE)** — both modules use `lib.mkForce` on the bootloader; import order in `modules/system/default.nix` determines which wins. Prevention: import `secureboot.nix` last in system aggregator, document ordering constraint.

5. **Disko placeholder strings (CRITICAL)** — `/dev/DISK` and `SIZE_RAM * 2` survive `nix build` and only fail at runtime. Prevention: prominent warning comment block at top of `disko-configuration.nix`.

---

## Implications for Roadmap

The build order from ARCHITECTURE.md drives the phase structure. Lower-risk service modules come first. Boot-critical system modules come last within the reorganization work. The one-time flake.nix changes are a prerequisite for everything else and must be isolated in Phase 1.

### Phase 1: Foundation — flake.nix + directory skeleton

**Rationale:** All subsequent phases depend on correct flake inputs (HM follows nixpkgs) and the aggregator directory structure existing. Do this once, correctly, before touching module files.
**Delivers:** Updated `flake.nix` with HM and impermanence inputs; empty `modules/system/`, `modules/services/`, `home/` directories with stub `default.nix` aggregators; `nixosModules` export block in flake.
**Addresses:** `nerv.home.enable`, `nerv.impermanence.enable` infrastructure prerequisites
**Avoids:** MOD-8 (lanzaboote floating pin — fix during flake update), home-manager double nixpkgs evaluation

### Phase 2: Services reorganization — modules/services/

**Rationale:** Service modules have no boot-chain dependency. Moving them first lets the module options pattern be developed and tested on lower-risk files before touching anything that can brick the system.
**Delivers:** `openssh.nix`, `pipewire.nix`, `bluetooth.nix`, `printing.nix`, `zsh.nix` each with `options.nerv.*` blocks, section-header documentation, and correct `lib.mkDefault`/`lib.mkForce` usage.
**Implements:** `modules/services/` component, `modules/services/default.nix` aggregator
**Avoids:** CRITICAL-5 (AllowUsers lockout — correct default), MOD-4 (Avahi implicit dependency — printing.nix declares its own), MOD-2 (deprecated type strings)

### Phase 3: System reorganization — modules/system/ (non-boot files)

**Rationale:** System modules that don't directly touch the boot chain (nix.nix, security.nix, hardware.nix, kernel.nix) can be reorganized next. The `nerv.hardware.cpu` and `nerv.hardware.gpu` options are high-value and drive kernel param gating.
**Delivers:** `nix.nix`, `security.nix`, `hardware.nix`, `kernel.nix` with `options.nerv.*` blocks; AMD/Intel kernel param gating; `modules/system/default.nix` aggregator (partial).
**Avoids:** MOD-3 (AMD params applied unconditionally), MIN-1 (GC config tradeoff documented), MIN-2 (audit rule scope documented), MIN-3 (AIDE initialization documented), MIN-4 (zsh store path audit)

### Phase 4: Boot extraction — boot.nix, impermanence.nix, secureboot.nix

**Rationale:** These are the highest-risk files. Boot extraction from `base/configuration.nix` happens last within the system reorganization. Import ordering in `default.nix` aggregator must be correct before these land. sbctl persistence must be wired in `impermanence.nix` before `secureboot.nix` is tested.
**Delivers:** `boot.nix` extracted with LUKS label cross-reference comment; `impermanence.nix` with `options.nerv.impermanence.*` including sbctl persistence; `secureboot.nix` with TPM2 enrollment ordering documentation; finalized `modules/system/default.nix` with secureboot imported last.
**Avoids:** CRITICAL-1 (sbctl on tmpfs), CRITICAL-2 (LUKS label mismatch), CRITICAL-4 (TPM2 enrollment ordering), MOD-1 (mkForce conflict via import ordering)

### Phase 5: Home Manager skeleton — home/

**Rationale:** Home Manager integration is the final structural addition. It requires the flake inputs from Phase 1 but does not block any system module work. Delivered last because per-user config is intentionally left to host flakes — the skeleton is minimal.
**Delivers:** `home/default.nix` with `home.stateVersion` inherited from system, global HM defaults (`useGlobalPkgs`, `useUserPackages`), `options.nerv.home.*` wiring, documentation of `nixpkgs.config.allowUnfree` limitation.
**Avoids:** MOD-6 (HM stateVersion unset), MOD-7 (useGlobalPkgs silently ignoring per-user nixpkgs.config)

### Phase 6: Documentation and disko warning pass

**Rationale:** Cross-cutting documentation that doesn't fit within any single module: disko placeholder warning, inline module headers, override path documentation for anti-features.
**Delivers:** Disko warning block (CRITICAL-3); section-header + inline comment style applied to all files; documented `lib.mkForce` escape hatch for anti-features.
**Addresses:** All remaining PITFALLS.md documentation items

### Phase Ordering Rationale

- Phase 1 before everything: flake inputs and directory structure are prerequisites for all module work
- Phase 2 before Phase 3/4: service modules validate the options pattern at low risk before boot-critical files are touched
- Phase 4 last in system work: boot.nix/impermanence.nix/secureboot.nix are the highest blast-radius files; the sbctl → impermanence → secureboot dependency chain must be respected within this phase
- Phase 5 after system work: HM skeleton is independent but benefits from the established `options.nerv.*` pattern being stable
- Phase 6 as a sweep: documentation is a cross-cutting concern best done after structure is finalized

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 4 (boot/impermanence/secureboot):** TPM2 enrollment sequencing and lanzaboote current tag need online verification; LUKS label consistency requires manual audit of existing `disko-configuration.nix` and `configuration.nix` before touching anything

Phases with standard patterns (skip research-phase):
- **Phase 1:** Flake input declarations are well-documented; aggregator pattern is standard Nix
- **Phase 2:** Service module options follow the established NixOS module pattern exactly
- **Phase 3:** Same pattern as Phase 2 with hardware enum gating — no novel territory
- **Phase 5:** HM NixOS module mode is well-documented; skeleton is minimal
- **Phase 6:** Documentation — no research needed

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM | `lib.mkOption` API is HIGH confidence; HM `nixosModules` attribute name and `useGlobalPkgs`/`useUserPackages` need `nix flake show` verification; lanzaboote tag currency needs online check |
| Features | HIGH | Derived directly from codebase analysis of existing modules; option table is complete and correctly prioritized |
| Architecture | HIGH | Based on stable NixOS module system behavior and existing repo layout; aggregator pattern is idiomatic and well-understood |
| Pitfalls | HIGH | All critical pitfalls derived from direct codebase analysis of existing files and known NixOS module system behaviors |

**Overall confidence:** HIGH

### Gaps to Address

- **Lanzaboote current tag:** `v0.4.1` may not be current. Run `gh release list -R nix-community/lanzaboote` or check upstream before pinning in Phase 1.
- **Home Manager `nixosModules` attribute name:** Run `nix flake show github:nix-community/home-manager` to confirm exact attribute before Phase 1 flake update.
- **`home-manager.backupFileExtension` option name:** Verify this is still the correct option name in 25.11-era HM before using it in Phase 5.
- **Existing LUKS label audit:** Before Phase 4, manually verify the label string in `disko-configuration.nix` and `configuration.nix` match exactly. This cannot be caught by `nix build`.

---

## Sources

### Primary (HIGH confidence)
- Existing codebase: `base/configuration.nix`, `base/disko-configuration.nix`, `base/flake.nix`, `modules/*.nix`, `.template/` files — direct analysis of existing implementation
- NixOS module system: `lib.mkOption`, `lib.types`, `lib.mkIf`, `lib.mkForce`, `lib.mkDefault` — stable core API
- NixOS wiki SSH hardening, PipeWire, Bluetooth, fail2ban patterns — referenced in PROJECT.md

### Secondary (MEDIUM confidence)
- `github:nix-community/home-manager` documentation — HM NixOS module mode, `useGlobalPkgs`, `useUserPackages`, `stateVersion` behavior
- `github:nix-community/impermanence` — `environment.persistence` API, user-level persistence
- `github:nix-community/lanzaboote` releases — `v0.4.1` tag present in repo; currency unverified

### Tertiary (needs verification)
- Exact `nixosModules` attribute in HM flake — run `nix flake show` to confirm
- `home-manager.backupFileExtension` option name for 25.11 era — verify before use

---
*Research completed: 2026-03-06*
*Ready for roadmap: yes*
