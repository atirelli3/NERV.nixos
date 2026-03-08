# Pitfalls Research: nerv.nixos

**Project:** nerv.nixos — NixOS module library refactor
**Focus:** Critical mistakes with impermanence, module options design, HM integration
**Confidence:** HIGH (based on direct codebase analysis of existing files)

---

## Critical Pitfalls (boot failures, lockouts, data loss)

### CRITICAL-1: Secureboot flag files on tmpfs root

**Problem:** Lanzaboote writes enrollment state files under `/var/lib/sbctl/`. On a tmpfs root, these are lost every reboot, causing infinite re-enrollment loops and TPM2 slot destruction.

**Prevention:** Persist `/var/lib/sbctl` explicitly:
```nix
environment.persistence."/persist".directories = [ "/var/lib/sbctl" ];
```
**Phase:** Must be addressed in impermanence module (Phase: system/ reorganization).

---

### CRITICAL-2: Disko label typo (NIKLUKS vs NIXLUKS)

**Problem:** Existing repo has inconsistency risk between `disko-configuration.nix` labels and `configuration.nix` `luks.devices` references. A label mismatch causes boot failure with no NixOS build-time error.

**Prevention:** Ensure labels are identical strings across both files. Add a comment cross-referencing them:
```nix
# Keep label in sync with disko-configuration.nix extraFormatArgs
luks.devices."cryptroot".device = "/dev/disk/by-label/NIXLUKS";
```
**Phase:** Phase 1 (boot.nix extraction).

---

### CRITICAL-3: Disko placeholder strings in production

**Problem:** `disko-configuration.nix` contains `device = "/dev/DISK"` and `size = "SIZE_RAM * 2"` as literal strings. These survive `nix build` with no error and only fail at runtime.

**Prevention:** Add a comment block at the top of `disko-configuration.nix`:
```nix
# BEFORE USE: Replace /dev/DISK with actual device (e.g. /dev/nvme0n1)
# and SIZE_RAM * 2 with actual value (e.g. "32G" for 16 GB RAM)
```
**Phase:** Documentation pass (any phase).

---

### CRITICAL-4: TPM2 PCR 7 enrollment ordering

**Problem:** TPM2 PCR 7 captures the secure boot state at enrollment time. Enrolling before the final signed bootloader is in place captures the wrong state, requiring re-enrollment.

**Prevention:** Always enroll keys AFTER the signed bootloader is installed and the system has booted once with it. Document this in `secureboot.nix` header.
**Phase:** secureboot.nix documentation (Phase: system/ reorganization).

---

### CRITICAL-5: `AllowUsers` locking out all SSH on deploy

**Problem:** Setting `nerv.openssh.allowUsers = [ "myUser" ]` with a typo or wrong username blocks all SSH logins immediately on `nixos-rebuild switch` — no recovery without console access.

**Prevention:**
- Default `allowUsers = []` (empty = all users allowed)
- Add warning in module documentation
- Recommend testing with `nixos-rebuild test` before `switch` when changing this option

**Phase:** openssh.nix module options (Phase: services/ reorganization).

---

## Moderate Pitfalls

### MOD-1: lib.mkForce conflict on systemd-boot / lanzaboote

**Problem:** `base/configuration.nix` enables `systemd-boot` while `secureboot.nix` switches to lanzaboote. Both use `lib.mkForce` — last import wins. Import order in `default.nix` aggregators is critical.

**Prevention:** In `modules/system/default.nix`, import `secureboot.nix` AFTER anything that touches boot loader. Document the ordering constraint with a comment.

---

### MOD-2: lib.mkOption type mistakes

**Problem:**
- `types.string` is deprecated → use `types.str`
- `types.attrs` bypasses type validation → use `types.attrsOf`
- Nullable options need `lib.mkIf (cfg.x != null)` guards in config

**Prevention:** Use canonical types only:
```nix
type = lib.types.str;              # not types.string
type = lib.types.listOf lib.types.str;
type = lib.types.nullOr lib.types.str;  # with mkIf guard in config
```

---

### MOD-3: AMD-specific kernel params applied to all hosts

**Problem:** `kernel.nix` likely has `amd_iommu=on` or similar unconditionally. On Intel hosts this is ignored but clutters kernel cmdline and may warn.

**Prevention:** Gate behind `nerv.hardware.cpu` option:
```nix
boot.kernelParams = lib.mkIf (cfg.cpu == "amd") [ "amd_iommu=on" ];
```

---

### MOD-4: `printing.nix` implicit dependency on Avahi

**Problem:** `printing.nix` requires Avahi (mDNS for network printer discovery). `pipewire.nix` may also enable Avahi. If `pipewire.nix` is disabled, printing breaks silently.

**Prevention:** `printing.nix` should declare its own `services.avahi.enable = true` rather than relying on a sibling module.

---

### MOD-5: `system.autoUpgrade.flake` hardcoded to wrong output

**Problem:** If `autoUpgrade` is used, the flake output name must match (`nixos` vs `nixos-base` vs the actual hostname). Wrong name causes silent no-op or error.

**Prevention:** Leave `autoUpgrade` disabled by default; document configuration in comments.

---

### MOD-6: Home Manager `stateVersion` unset

**Problem:** HM requires `home.stateVersion` set per-user. If unset, evaluation fails with a hard error. If set wrong (different from system stateVersion), NixOS warns loudly.

**Prevention:** `home/default.nix` skeleton should include:
```nix
home.stateVersion = config.system.stateVersion;  # inherit from system
```

---

### MOD-7: HM `useGlobalPkgs` silently ignoring per-user nixpkgs.config

**Problem:** With `useGlobalPkgs = true`, per-user `nixpkgs.config` in HM is silently ignored. Users who set `allowUnfree = true` in HM config won't get unfree packages.

**Prevention:** Document in `home/default.nix` header. Set system-level `nixpkgs.config.allowUnfree` in the nerv base if needed.

---

### MOD-8: `lanzaboote` pinned to floating branch

**Problem:** Floating `main` branch input breaks reproducibility. On cache miss it re-evaluates from HEAD.

**Prevention:** Pin to a specific tag:
```nix
lanzaboote.url = "github:nix-community/lanzaboote/v0.4.1";
```
Verify current tag at: `github.com/nix-community/lanzaboote/releases`

---

## Minor Pitfalls

### MIN-1: `keep-outputs + keep-derivations` defeating GC

**Problem:** `nix.gc` with `keep-outputs = true` and `keep-derivations = true` retains all build inputs. Combined with short GC intervals, disk fills up.

**Prevention:** Either remove these flags or increase GC interval. Document the tradeoff in `nix.nix`.

---

### MIN-2: Audit rules logging all execve/openat system-wide

**Problem:** Auditing every `execve` or `openat` on a desktop system creates unmanageable log volume and degrades performance.

**Prevention:** Scope audit rules to specific paths/UIDs. Document which rules are active and why in `security.nix`.

---

### MIN-3: AIDE database never initialized

**Problem:** AIDE (if enabled) requires `aide --init` after first install. Without it, integrity monitoring is silently inactive.

**Prevention:** Document the post-install step in `security.nix` header. Consider an activation script.

---

### MIN-4: `zsh.nix` hardcoded store path

**Problem:** Any hardcoded `/nix/store/...` path in `zsh.nix` breaks on nixpkgs update.

**Prevention:** Use `${pkgs.somePackage}/bin/tool` interpolation only. Audit `zsh.nix` during reorganization.

---

## Phase Mapping

| Pitfall | Phase |
|---------|-------|
| CRITICAL-1 (sbctl persistence) | impermanence.nix implementation |
| CRITICAL-2 (label sync) | boot.nix extraction |
| CRITICAL-3 (disko placeholders) | Documentation pass |
| CRITICAL-4 (TPM2 ordering) | secureboot.nix docs |
| CRITICAL-5 (AllowUsers lockout) | openssh module options |
| MOD-1 (mkForce conflict) | default.nix aggregator ordering |
| MOD-2 (type mistakes) | All module options implementation |
| MOD-3 (AMD params) | hardware.nix module options |
| MOD-4 (Avahi dependency) | services/ reorganization |
| MOD-6 (HM stateVersion) | home/ skeleton |
| MOD-8 (lanzaboote pin) | flake.nix update |
