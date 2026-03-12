# Testing Patterns

**Analysis Date:** 2026-03-12

## Test Framework

**Status:** Not detected

**Language-specific observation:**
- nerv.nixos is a NixOS flake library written in the Nix language
- No traditional test framework (Jest, Vitest, Mocha, pytest, etc.) is used
- Nix does not have a standard unit testing framework in the ecosystem
- Testing is performed through NixOS system builds and manual validation

**Verification Approach:**
- No `*.test.nix`, `*.spec.nix`, or test directory detected
- No test configuration files found: `jest.config.*`, `vitest.config.*`, `pytest.ini`, etc.
- No test package dependencies in `flake.nix` (only nixpkgs, lanzaboote, home-manager, disko, impermanence)

## Test File Organization

**Location:** Not applicable — no dedicated test files exist

**Testing Strategy:**
- Testing is implicit through NixOS system builds
- Each module is evaluated and built as part of the full system configuration
- Manual validation occurs through real system installation and runtime verification

## Configuration Validation

**Assertions (evaluating phase validation):**
- NixOS assertions used to validate configuration correctness at evaluation time
- Caught before system build begins
- No runtime tests to verify behavior after build completes

**Assertion Locations:**
- `modules/services/openssh.nix:48-51` — validates `tarpitPort != port`
- `modules/system/impermanence.nix:74-85` — validates `/var/lib/sbctl` is not in tmpfs paths when secure boot enabled

## Build-Time Verification

**System Build:**
- Full system evaluation and build serves as the primary test
- `nixos-rebuild switch --flake /etc/nixos#host` builds and switches to new configuration
- Build failures indicate configuration errors

**Hardware Configuration:**
- `nixos-generate-config --no-filesystems --show-hardware-config` auto-generates hardware-specific settings
- Generated to `hosts/hardware-configuration.nix` per-host
- Validates that generated config aligns with actual system hardware

## Installation Verification

**Multi-phase Installation (documented in MEMORY.md):**

1. **Disko layout generation:** `nix run github:nix-community/disko/v1.13.0 -- --mode destroy,format,mount --flake /tmp/nixos#host` validates disk layout declarations and applies them
2. **NixOS installation:** `nixos-install --flake /mnt/etc/nixos#host` evaluates all modules and builds the system
3. **Secure Boot keys:** `sbctl create-keys` and key verification validate Secure Boot integration
4. **Post-boot validation:** Manual system startup and function verification

**Known Fragile Points:**
- Secure Boot key placement: must exist in three locations (`/var/lib/sbctl`, `/mnt/var/lib/sbctl`, `/mnt/persist/var/lib/sbctl`) — see MEMORY.md
- LUKS password handling via `/tmp/luks-password` file requires careful environment setup
- Disko auto-generation of `boot.initrd.luks.devices.cryptroot.device` must not be overridden explicitly

## Manual Validation Patterns

**Installation Flow Testing:**
1. Clone to `/tmp/nixos` (NOT `/mnt` as disko wipes `/mnt`)
2. Edit `hosts/configuration.nix` with target hostname, users, hardware, and disk device
3. Set disk layout: `nerv.disko.layout = "btrfs"` (desktop) or `"lvm"` (server)
4. Run disko to format and mount: `disko --mode destroy,format,mount`
5. Generate hardware config: `nixos-generate-config --no-filesystems`
6. Run nixos-install with flake: `nixos-install --flake /mnt/etc/nixos#host`
7. Post-install: set user password, copy config to `/mnt/persist/etc/nixos` if using impermanence
8. Reboot and verify system comes up cleanly

**Service Validation:**
- OpenSSH: SSH connection test to port 2222 (or configured port), verify tarpit on port 22
- PipeWire audio: `pactl list sinks` or `pwvucontrol` for audio routing
- Zsh: verify shell aliases work (`nrs`, `gs`, `gaa` git commands), fzf integration (`Ctrl+R` history search)
- Impermanence: verify `/persist` mounts correctly, verify `/` is tmpfs in full mode, verify BTRFS rollback works

## Configuration Error Patterns

**Missing Required Options:**
- `nerv.hostname` — assertion fails with "must not be empty string"
- `nerv.disko.layout` — must be explicitly set to "btrfs" or "lvm"; no default
- `disko.devices.disk.main.device` — must point to actual disk (e.g., `/dev/nvme0n1`)
- `nerv.hardware.cpu` and `nerv.hardware.gpu` — required for proper microcode and driver selection

**Type Mismatches:**
- Port numbers must be integers; fail2ban settings expect strings (`toString cfg.port`)
- Size strings must follow format: "16G", "60G" (see `modules/system/disko.nix:49-66`)
- Boolean flags must be true/false, not strings

**Logic Errors:**
- Setting `nerv.impermanence.extraDirs` with `/var/lib/sbctl` when secure boot enabled triggers assertion error
- Setting `nerv.openssh.tarpitPort` equal to `nerv.openssh.port` triggers assertion error
- Conflicting kernel parameters can cause boot failures (none detected in current code)

## Known Test Scenarios

**BTRFS Desktop Installation:**
1. Set `nerv.disko.layout = "btrfs"`
2. Set `nerv.impermanence.mode = "btrfs"` (default)
3. Verify rollback service runs at boot: `/var/log/boot.log` or `journalctl -b`
4. Create a test file in `/home`, reboot, verify file is gone

**LVM Server Installation:**
1. Set `nerv.disko.layout = "lvm"`
2. Set `nerv.disko.lvm.swapSize = "16G"` (2x RAM), `storeSize = "60G"`, `persistSize = "20G"`
3. Set `nerv.impermanence.mode = "full"` (/ as tmpfs)
4. Verify `/` is tmpfs: `mount | grep tmpfs`
5. Verify `/nix` and `/persist` are ext4: `mount | grep ext4`

**Secure Boot Validation:**
1. Set `nerv.secureboot.enable = true` in flake
2. Ensure sbctl keys created: `sbctl list-keys`
3. Boot into UEFI Setup Mode before first boot with secure boot enabled
4. Verify signed boot: `bootctl status`

**SSH Hardening Validation:**
1. Set `nerv.openssh.enable = true`
2. Attempt SSH connections within 10 minutes: should be rate-limited after 3 failures
3. Verify tarpit on port 22: `timeout 2 curl -v telnet://localhost:22` (should hang)
4. Verify SSH daemon on configured port: `ssh -p 2222 user@localhost` succeeds

## Coverage Notes

**What IS validated:**
- Configuration syntax (NixOS evaluation)
- Assertion conditions (pre-build validation)
- Module composition and option inheritance
- System build completion
- Hardware compatibility (via auto-generated hardware-configuration.nix)
- Installation process flow

**What IS NOT validated:**
- Runtime functionality after system starts (e.g., services actually listening on configured ports)
- Performance characteristics (boot time, memory usage, disk I/O)
- Edge cases in initrd scripts (rollback, encryption, LVM activation)
- Behavior under stress or failure conditions
- Interactions between independently-enabled optional services

**Why:**
- Nix is a declarative configuration language; runtime behavior is determined by NixOS and the packages themselves
- Comprehensive unit/integration testing would require a separate test harness (NixOS VM test suite)
- Current validation model relies on successful system build + manual installation validation
- Testing changes requires rebuilding and rebooting actual hardware

## Reproducibility

**Locked Dependencies:**
- Flake inputs pinned via `flake.nix` with specific versions: `disko v1.13.0`, `lanzaboote`, `home-manager` from `nixos-unstable`
- `flake.lock` file (not readable, stores exact revisions) ensures bit-for-bit reproducibility
- System builds are reproducible given the same flake.lock state

**Testing Reproducibility:**
- Installation manual (see MEMORY.md) is the source of truth for tested flow
- Each installation is a fresh system with identical configuration (minus host-specific values)
- Same flake + same hardware = same system state at boot

---

*Testing analysis: 2026-03-12*
