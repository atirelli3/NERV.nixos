# Milestones: nerv.nixos

## v2.0 Stateless NixOS Library (Shipped: 2026-03-12)

**Phases completed:** 13 phases, 35 plans, 0 tasks

**Key accomplishments:**
- (none recorded)

---

## v1.0 — Foundation (Complete)

**Shipped:** 2026-03-08
**Phases:** 1–8 (last phase: 8)
**Requirements:** 21/21 satisfied

### What Shipped

- **Phase 1: Flake Foundation** — root flake.nix with correct inputs, nixosModules exports, hosts/ layout
- **Phase 2: Services Reorganization** — all service modules in modules/services/ with nerv.* options API
- **Phase 3: System Modules** — identity, hardware (cpu/gpu enums), kernel, security, nix in modules/system/
- **Phase 4: Boot Extraction** — boot.nix, impermanence.nix (minimal + full modes), secureboot.nix with enable guard
- **Phase 5: Home Manager Skeleton** — home/default.nix wiring, nerv.home.users option
- **Phase 6: Documentation Sweep** — section-headers on all modules, disko WARNING block, LUKS cross-references
- **Phase 7: Flake Hardening & Disko Wiring** — disko as flake input, explicit option declarations, Nyquist validation
- **Phase 8: NERV.nixos Release** — 9 dead flat modules deleted, host/server/vm profiles, migrated to NERV.nixos repo

### Audit Status

See `.planning/v1.0-MILESTONE-AUDIT.md` for full details.

- Requirements: 21/21 complete
- Integration: 14/16 paths wired
- Nyquist: PARTIAL (validation files exist, none complete)

---
