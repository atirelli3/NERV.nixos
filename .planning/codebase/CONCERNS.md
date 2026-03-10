# Codebase Concerns

**Analysis Date:** 2026-03-10

---

## Tech Debt

**Hardcoded `#host` nixosConfiguration in auto-upgrade and zsh aliases:**
- Issue: `system.autoUpgrade.flake` is hardcoded to `/etc/nixos#host` in `modules/system/nix.nix`. Any host using the `server` nixosConfiguration will silently auto-upgrade using the wrong profile. The zsh aliases `nrs`, `nrb`, `nrt` in `modules/services/zsh.nix` are also hardcoded to `#host`.
- Files: `modules/system/nix.nix` line 15, `modules/services/zsh.nix` lines 88–90
- Impact: A server host running daily auto-upgrades applies `hostProfile` settings (audio, bluetooth, BTRFS rollback) instead of `serverProfile` (LVM, full impermanence). This is a silent misconfiguration that becomes dangerous if auto-upgrade fires on a headless server with a different disk layout.
- Fix approach: Expose a `nerv.nix.autoUpgradeFlake` option (already listed as future requirement `OPT-V3-01`) or default the flake path to a configurable `nerv.hostname`-derived value. Short-term: document as "set manually per host".

**LVM option defaults are string `"PLACEHOLDER"` (not `null` or assertion-guarded):**
- Issue: `nerv.disko.lvm.swapSize`, `nerv.disko.lvm.storeSize`, and `nerv.disko.lvm.persistSize` default to the string `"PLACEHOLDER"` in `modules/system/disko.nix` lines 51, 57, 63. There is no assertion that catches a literal `"PLACEHOLDER"` value reaching disko. A host using `nerv.disko.layout = "lvm"` without filling in sizes will pass a nonsensical string to `mkswap` and `mkfs.ext4`.
- Files: `modules/system/disko.nix` lines 48–67
- Impact: Silent disk provisioning failure at install time. The string `"PLACEHOLDER"` will be passed to disko partition size calculations and cause a cryptic error only at `nixos-install` time, not at `nix flake check` time.
- Fix approach: Change defaults to `null` and add a `lib.optional (cfg.layout == "lvm")` assertion that rejects `null` or the literal string `"PLACEHOLDER"`.

**Stale cross-references in `secureboot.nix` comments:**
- Issue: Five inline comments in `modules/system/secureboot.nix` reference `disko-configuration.nix and boot.nix` — a file path that no longer exists (deleted in Phase 8) and a description that is inaccurate (LUKS is no longer in `boot.nix`). The correct reference is `modules/system/disko.nix` only.
- Files: `modules/system/secureboot.nix` lines 85, 105, 110, 139 (inline comments)
- Impact: Maintainers following the comment to locate the LUKS label sync point will look in a deleted file. Zero runtime impact.
- Fix approach: Replace all `# must match disko-configuration.nix and boot.nix` comments with `# must match modules/system/disko.nix`.

**Stale comments in `modules/system/default.nix`:**
- Issue: Line 14 describes `boot.nix` as `"initrd + LUKS + bootloader (opaque)"`. LUKS was moved out of `boot.nix` in Phase 10 into `disko.nix`. Line 16 describes `disko.nix` as `"conditional LVM LVs based on impermanence mode"` — predating Phase 9 where the condition became `nerv.disko.layout`, not impermanence mode.
- Files: `modules/system/default.nix` lines 11, 13
- Impact: Misleads maintainers about module responsibilities. Zero runtime impact.
- Fix approach: Update line 14 to `"initrd + bootloader (opaque)"` and line 16 to `"declarative disk layout — BTRFS or LVM branch based on nerv.disko.layout"`.

**Four VALIDATION.md files in draft/nyquist_compliant:false state:**
- Issue: Phases 9, 10, 11, and 12 each have a `VALIDATION.md` with `status: draft` and `nyquist_compliant: false`. These represent incomplete process compliance records for completed implementation phases.
- Files: `.planning/phases/09-btrfs-disko-layout/09-VALIDATION.md`, `.planning/phases/10-initrd-btrfs-rollback-service/10-VALIDATION.md`, `.planning/phases/11-impermanence-btrfs-mode/11-VALIDATION.md`, `.planning/phases/12-profile-wiring-and-documentation/12-VALIDATION.md`
- Impact: Process compliance gap — no functional impact on the deployed NixOS system.
- Fix approach: Run `/gsd:validate-phase` for phases 9, 10, 11, and 12 in order.

**`disk-layout-refactor.md` superseded design document at repo root:**
- Issue: `disk-layout-refactor.md` is a pre-GSD planning document that describes the refactor work now completed in Phases 9–11. It contains task lists and pseudo-implementation notes that do not match the final implementation (e.g. uses `btrfs subvolume delete @` without the LUKS layer, references `/btrfs/@` instead of `/btrfs_tmp/@`, no `@root-blank` snapshot step).
- Files: `disk-layout-refactor.md`
- Impact: New contributors reading this file get an incorrect picture of the rollback mechanism. Zero runtime impact.
- Fix approach: Delete the file — the README Section B and PROF-04 documentation fully cover the current install procedure. Alternatively, add a header note that this document is a historical artifact superseded by Phase 9–11 implementation.

**REQUIREMENTS.md OPT-07 text imprecision:**
- Issue: `OPT-07` text says `default 22` for the SSH port. The implementation uses `default = 2222` for the SSH daemon port, with port 22 reserved for the endlessh tarpit (`tarpitPort`).
- Files: `.planning/REQUIREMENTS.md` line 25
- Impact: Documentation-only inaccuracy. Zero runtime impact.
- Fix approach: Amend OPT-07 text to `default 2222 (port 22 reserved for endlessh tarpit)`.

---

## Known Bugs

**No PLACEHOLDER enum validation on `nerv.hardware.cpu` and `nerv.hardware.gpu` in `hosts/configuration.nix`:**
- Symptoms: The template `hosts/configuration.nix` sets `nerv.hardware.cpu = "PLACEHOLDER"`. The option type is `lib.types.enum [ "amd" "intel" "other" ]` which will reject `"PLACEHOLDER"` at eval time with a type error. This is the intended guard behavior, but the error message is generic and does not hint at valid values prominently.
- Files: `hosts/configuration.nix` lines 22–23, `modules/system/hardware.nix` lines 11–19
- Trigger: Running `nix flake check` or `nixos-rebuild` without filling in the PLACEHOLDER values.
- Workaround: The enum type error fires early, before any disk operations.

**BTRFS rollback service mounts at `/btrfs_tmp` without cleanup on error:**
- Symptoms: The rollback initrd script in `modules/system/disko.nix` mounts BTRFS at `/btrfs_tmp`, runs subvolume operations, then `umount /btrfs_tmp`. If `btrfs subvolume delete /btrfs_tmp/@` fails and the `|| true` suppression is insufficient (e.g. the subvolume is in use), the mount is still unmounted and `@` may be in an inconsistent state.
- Files: `modules/system/disko.nix` lines 123–133
- Trigger: First boot after a failed partial subvolume deletion, or if `/btrfs_tmp` already exists from a prior aborted initrd.
- Workaround: Manual recovery via live ISO — `btrfs subvolume delete`, then restore snapshot manually. The `|| true` on the delete is intentional to handle first-boot where `@` may not yet exist, but it also swallows genuine errors.

---

## Security Considerations

**SSH host keys persisted via `environment.persistence` bind-mounts require `/persist` to be unlocked before sshd starts:**
- Risk: Both btrfs and full impermanence modes persist `ssh_host_ed25519_key` and `ssh_host_rsa_key` from `/persist`. If `/persist` is not available before sshd's first activation (e.g. if the bind-mount fails silently), sshd will generate new host keys at `/etc/ssh/`, which disappear on next rollback. This causes an SSH fingerprint mismatch for clients, not a security breach.
- Files: `modules/system/impermanence.nix` lines 115–121, 144–150
- Current mitigation: `fileSystems."/persist".neededForBoot = true` ensures the mount attempt is made before sshd. If the mount fails, the system will fail to boot (safe fail-closed behavior).
- Recommendations: No change required — the `neededForBoot` guard is the correct defense. Document the recovery procedure (live ISO, `mount /persist`, verify bind-mounts) in the README or a dedicated troubleshooting section.

**`secureboot-enroll-keys` service runs with `User = "root"` and no `ProtectSystem` hardening:**
- Risk: The two systemd services (`secureboot-enroll-keys`, `secureboot-enroll-tpm2`) in `modules/system/secureboot.nix` run as root with no `PrivateTmp`, `NoNewPrivileges`, or `ProtectSystem` constraints.
- Files: `modules/system/secureboot.nix` lines 45–48, 80–83
- Current mitigation: Both services are one-shot with sentinel files (`/var/lib/secureboot-keys-enrolled`, `/var/lib/secureboot-setup-done`) — they exit immediately on subsequent boots. The risk window is only the two-boot enrollment sequence.
- Recommendations: Low priority given the one-shot nature and the fact that Secure Boot enrollment inherently requires full hardware access. Adding `ProtectSystem = "strict"` would conflict with the service's need to write sentinel files to `/var/lib`.

**`hardware.enableAllFirmware = true` allows arbitrary proprietary firmware blobs:**
- Risk: `modules/system/hardware.nix` line 30 sets `hardware.enableAllFirmware = true`, which loads firmware blobs from `linux-firmware` for all detected hardware. This is a broad trust grant to upstream firmware vendors.
- Files: `modules/system/hardware.nix` line 30
- Current mitigation: NixOS pins firmware to a specific nixpkgs revision. `fwupd` is also enabled for runtime updates.
- Recommendations: Acceptable risk for a desktop/laptop base library. Server deployments could consider replacing with the more targeted `hardware.enableRedistributableFirmware = true` only.

**Audit rules are very broad — high-volume noise risk:**
- Risk: `modules/system/security.nix` lines 26–28 audit every `execve`, `openat`, and `connect` syscall system-wide. On an active desktop, this generates extremely high audit log volume and may fill `/var/log/audit/` rapidly, or degrade I/O performance on write-intensive workloads.
- Files: `modules/system/security.nix` lines 24–37
- Current mitigation: `/var/log` is excluded from AIDE monitoring. Audit log volume is not rate-limited.
- Recommendations: Consider adding `-F uid!=root` filters to `execve` and `openat` rules, or adding `auditctl -r` rate limits to the audit configuration. This is a known trade-off; the current configuration prioritizes completeness over noise reduction.

---

## Fragile Areas

**`avahi.enable` is set independently by both `bluetooth.nix` and `printing.nix`:**
- Files: `modules/services/bluetooth.nix` line 34, `modules/services/printing.nix` lines 28–31
- Why fragile: Both modules set `services.avahi.enable = true` unconditionally within their respective `mkIf` blocks. NixOS merges these cleanly (true || true = true), but if a host wants to disable avahi for one service without the other it cannot do so without `lib.mkForce false` overriding both. If a future module ever tries to set `services.avahi.enable = false` for security reasons, it will conflict with both modules simultaneously.
- Safe modification: Do not add `services.avahi.enable = false` to any other module without `lib.mkForce`. Understand that enabling either bluetooth or printing implies avahi is on.
- Test coverage: No automated test. Verified only by build success (nix eval).

**`home-manager` users require `nixos-rebuild --impure` and per-user `~/home.nix` files outside the flake boundary:**
- Files: `home/default.nix` lines 44, 47
- Why fragile: The `imports = [ /home/${name}/home.nix ]` path is an absolute filesystem reference outside the flake. If a listed user's `~/home.nix` does not exist, `nixos-rebuild` fails with an import error. The `home-manager.backupFileExtension = "backup"` guard prevents hard failures on conflicting unmanaged files, but cannot protect against the missing-file case.
- Safe modification: Always ensure `~/home.nix` exists for every user listed in `nerv.home.users` before running `nixos-rebuild`. If removing a user from `nerv.home.users`, the `~/home.nix` file can be left in place without harm.
- Test coverage: Not testable without a running NixOS system with actual user home directories.

**`@root-blank` snapshot must be created manually during installation — not automated:**
- Files: `modules/system/disko.nix` lines 89, 116–133
- Why fragile: The initrd rollback service snapshots `@root-blank → @` on every boot. If `@root-blank` does not exist (e.g. installer skipped step 5 in README Section B), the rollback service exits 1 and the system may fail to mount `/`. This is a purely manual step with no automated guard at install time.
- Safe modification: README Section B warns of this at the top of the section. Do not remove or reorder the `@root-blank` creation step from the install procedure.
- Test coverage: None — install procedure is a manual process.

**`secureboot.nix` must be the last import in `modules/system/default.nix`:**
- Files: `modules/system/default.nix` line 14, `modules/system/secureboot.nix` line 15
- Why fragile: `secureboot.nix` uses `boot.loader.systemd-boot.enable = lib.mkForce false` to override the unconditional `boot.loader.systemd-boot.enable = true` set in `boot.nix`. If any future module in the system imports list sets `systemd-boot.enable` after `secureboot.nix` without `lib.mkForce`, the override will hold correctly because `mkForce` always wins regardless of order. However, if `secureboot.nix` is moved earlier in the list, the semantic intent becomes harder to follow and future developers may add conflicting bootloader configuration expecting it to take precedence.
- Safe modification: Keep `secureboot.nix` as the last entry in `modules/system/default.nix` imports list. The comment on line 2 of `default.nix` documents this constraint.
- Test coverage: Verified by `nix flake check` presence of lanzaboote module.

**`luks-cryptenroll` helper script is a plain bash one-liner with no safety checks:**
- Files: `modules/system/secureboot.nix` lines 138–142
- Why fragile: The `luks-cryptenroll` script runs `systemd-cryptenroll --wipe-slot=tpm2` unconditionally. If run on a system where TPM2 was never enrolled (e.g. after a fresh reinstall with Secure Boot disabled), `--wipe-slot=tpm2` will succeed vacuously but the subsequent boot will require manual LUKS password entry. There is no user-facing warning before destructive wipe.
- Safe modification: Only run `luks-cryptenroll` after verifying `sbctl status` shows Secure Boot enabled and `systemd-cryptenroll /dev/disk/by-label/NIXLUKS` shows an existing TPM2 slot.
- Test coverage: None.

---

## Performance Bottlenecks

**ClamAV daemon (`clamd`) running continuously on desktop hosts:**
- Problem: `modules/system/security.nix` enables `services.clamav.daemon.enable = true` unconditionally for all profiles, including the desktop host profile. `clamd` maintains an in-memory virus database (typically 400–600 MB RAM) and performs real-time file scanning hooks.
- Files: `modules/system/security.nix` lines 40–44
- Cause: Fully opaque module — no option to disable per-profile.
- Improvement path: Expose `nerv.security.clamav.enable` option. A server-only or on-demand scan approach (`clamscan` in a cron job) may be more appropriate for desktops without file-sharing workloads.

**Aggressive audit rule breadth impacts I/O-bound workloads:**
- Problem: Auditing every `openat` syscall on a development workstation performing compiler builds generates thousands of audit events per second, serialized through the kernel audit subsystem.
- Files: `modules/system/security.nix` line 27
- Cause: Opaque module design — no per-rule toggle available.
- Improvement path: Add `auditctl -r 100` (rate-limit to 100 events/second) or scope `openat` to specific paths (`-F dir=/etc -F dir=/boot`).

---

## Scaling Limits

**`fileSystems."/" tmpfs size=2G` is hardcoded for full (server) impermanence mode:**
- Current capacity: 2 GB RAM for the root tmpfs.
- Limit: Server workloads with large ephemeral working sets (container images, build artifacts) will exhaust the root tmpfs and cause OOM or write failures.
- Files: `modules/system/impermanence.nix` line 99
- Scaling path: Expose as `nerv.disko.tmpfsSize` option (already listed as future requirement `DISKO-V3-01`).

---

## Dependencies at Risk

**`nixpkgs` pinned to `nixos-unstable`:**
- Risk: All inputs follow `nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"`. Unstable channel packages can have breaking changes between `nix flake update` runs — this is by design for a base library, but host operators may be surprised by silent API changes in modules they override.
- Files: `flake.nix` line 5
- Impact: Any `nix flake update` on a host may pull breaking changes in nixpkgs that affect NERV modules (e.g. renamed service options, changed module defaults).
- Migration plan: Consider providing a `nixos-25.11` stable-channel alternative reference. The `disko` input is already pinned to `v1.13.0`, which sets a good precedent.

**`disko` pinned to `v1.13.0` — may miss upstream fixes:**
- Risk: Disko is pinned to a specific tag. The known limitation that `neededForBoot` is not supported on BTRFS subvolume mounts (issues #192, #594) is worked around inline. A newer disko version might fix this and allow removing the workaround, or might introduce new breaking changes.
- Files: `flake.nix` line 21
- Impact: Minimal — the workaround in `modules/system/impermanence.nix` line 129 is correct and self-documenting.
- Migration plan: Periodically check disko changelog before bumping the pin.

---

## Missing Critical Features

**No validation that `nerv.disko.layout` matches the installed disk filesystem:**
- Problem: If an operator sets `nerv.disko.layout = "lvm"` on a machine that has a BTRFS layout (or vice versa), the initrd will try to activate LVM on a device with no LVM PV, causing an initrd hang, or the BTRFS rollback service will not run on a machine that needs it.
- Blocks: Safe profile switching without reinstallation.
- Files: `modules/system/disko.nix` (no cross-validation with hardware state)

**No `nerv.nix.autoUpgrade` toggle — auto-upgrade is always on:**
- Problem: `system.autoUpgrade` is unconditionally enabled in `modules/system/nix.nix`. Hosts where automatic upgrades are undesirable (e.g. production servers, machines with manual deployment workflows) have no supported way to disable it without `lib.mkForce`.
- Blocks: Adopting NERV for servers where upgrades must be coordinated.
- Files: `modules/system/nix.nix` lines 12–17
- Future requirement: `OPT-V3-01` covers this.

**No kernel package toggle — Zen kernel is mandatory:**
- Problem: `modules/system/kernel.nix` uses `lib.mkForce pkgs.linuxPackages_zen`. While `lib.mkForce` is documented as the escape hatch, the Zen kernel may not be desirable on server profiles (server-optimized or `linuxPackages_hardened` would be more appropriate).
- Files: `modules/system/kernel.nix` line 10
- Future requirement: `OPT-V3-02` covers this.

---

## Test Coverage Gaps

**No automated `nix flake check` in CI:**
- What is not tested: Nix expression correctness, option type validation, and import chain completeness are never automatically verified. All validation is manual and developer-machine-dependent.
- Files: All `.nix` files
- Risk: A syntax error or type mismatch in any module goes undetected until a human runs `nix flake check` on a NixOS machine.
- Priority: High — a CI pipeline running `nix flake check` in a nix-enabled GitHub Actions or Hydra environment would catch all eval-time errors.

**No runtime integration tests for impermanence behavior:**
- What is not tested: That the BTRFS rollback service actually deletes `@` and snapshots `@root-blank → @` correctly; that `environment.persistence` bind-mounts are available before sshd and NetworkManager start; that `machine-id` survives reboots.
- Files: `modules/system/disko.nix` lines 116–133, `modules/system/impermanence.nix` lines 135–150
- Risk: Regression in rollback ordering (e.g. `before`/`after` unit changes) goes undetected until first-boot failure on a physical machine.
- Priority: High — NixOS `nixosTest` VM-based tests can exercise the full boot sequence including initrd services.

**No test coverage for Secure Boot two-boot enrollment sequence:**
- What is not tested: That `secureboot-enroll-keys` correctly detects Setup Mode and does not re-run after the sentinel file is written; that `secureboot-enroll-tpm2` correctly orders after `secureboot-enroll-keys` and respects the TPM2-already-enrolled check.
- Files: `modules/system/secureboot.nix` lines 39–118
- Risk: A regression in the sentinel file path or the `sbctl status` grep pattern causes re-enrollment on every boot, which re-seals TPM2 to a different PCR state and breaks auto-unlock.
- Priority: Medium — Secure Boot Setup Mode cannot be reliably mocked in NixOS VM tests, but the service logic can be unit-tested in isolation.

**`hosts/hardware-configuration.nix` is an empty placeholder:**
- What is not tested: Any hardware-specific kernel module, driver, or filesystem configuration that would normally be generated by `nixos-generate-config`. The tracked placeholder `{ ... }: { }` means the flake builds in the repo but the built system has no hardware-specific modules.
- Files: `hosts/hardware-configuration.nix`
- Risk: Not a concern for the library itself, but consumers who forget to replace this file with the actual `nixos-generate-config` output will have a system that may fail to detect hardware at boot.
- Priority: Low — this is by design for the template; the README documents the replacement step.

---

*Concerns audit: 2026-03-10*
