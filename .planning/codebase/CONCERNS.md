# Codebase Concerns

**Analysis Date:** 2026-03-10

## Tech Debt

**Stale cross-references in secureboot.nix (5 occurrences):**
- Issue: Header comment at line 7 still references `hosts/nixos-base/disko-configuration.nix` which was deleted in Phase 8. Inline comments at lines 92, 112, 117, and 146 repeat `must match disko-configuration.nix and boot.nix` — the file no longer exists and boot.nix no longer holds LUKS config.
- Files: `modules/system/secureboot.nix`
- Impact: Misleads maintainers tracing NIXLUKS label ownership. No runtime impact — NIXLUKS label values are actually correct and consistent across `disko.nix` and `secureboot.nix`.
- Fix approach: Replace all five occurrences of `disko-configuration.nix` and `boot.nix` with `modules/system/disko.nix`. The header line 7 should read: `LUKS : NIXLUKS label must stay in sync with modules/system/disko.nix`.

**Stale inline comment in default.nix (line 14):**
- Issue: Line 14 describes `boot.nix` as "initrd + LUKS + bootloader (opaque)" — LUKS unlock was moved to `disko.nix` in Phase 10. boot.nix is now layout-agnostic and contains only initrd systemd enable + systemd-boot config.
- Files: `modules/system/default.nix`
- Impact: Misleads readers about what `boot.nix` owns. No runtime impact.
- Fix approach: Update line 14 comment to "initrd (systemd stage 1) + bootloader (opaque)".

**Stale inline comment in default.nix (line 16):**
- Issue: Line 16 describes `disko.nix` as "declarative disk layout — conditional LVM LVs based on impermanence mode". Since Phase 9, disko.nix branches on `nerv.disko.layout` not on impermanence mode.
- Files: `modules/system/default.nix`
- Impact: Misleads readers about the layout selection logic.
- Fix approach: Update to "declarative disk layout — layout-conditional BTRFS/LVM config".

**Stale inline comment in disko.nix (line 52):**
- Issue: Line 52 reads `must stay in sync with boot.nix and secureboot.nix` inside `sharedLuksOuter.extraFormatArgs`. boot.nix no longer holds LUKS config since Phase 10.
- Files: `modules/system/disko.nix`
- Impact: Misleads readers about which files share the NIXLUKS label.
- Fix approach: Change to `must stay in sync with modules/system/secureboot.nix`.

**Nyquist-non-compliant VALIDATION.md files (4 phases):**
- Issue: Phases 9, 10, 11, and 12 have `VALIDATION.md` files still in `status: draft` with `nyquist_compliant: false`. The implementation work is complete; the validation documents were never promoted.
- Files: `.planning/phases/09-btrfs-disko-layout/`, `.planning/phases/10-initrd-btrfs-rollback-service/`, `.planning/phases/11-impermanence-btrfs-mode/`, `.planning/phases/12-profile-wiring-and-documentation/`
- Impact: GSD tooling treats these phases as incomplete for Nyquist compliance audits. The v2.0 milestone audit is marked `status: tech_debt` instead of fully compliant. Does not affect NixOS build.
- Fix approach: Run `/gsd:validate-phase` for each of phases 9–12 to retroactively promote VALIDATION.md to `nyquist_compliant: true`.

**REQUIREMENTS.md OPT-07 text imprecision:**
- Issue: OPT-07 says "default 22" for SSH port but the implementation default is 2222 (with port 22 reserved for the endlessh tarpit). The design is intentional and correct; the requirement text is imprecise.
- Files: `.planning/REQUIREMENTS.md`
- Impact: Documentation confusion only. Implementation is correct and the option description in `modules/services/openssh.nix` is accurate.
- Fix approach: Update OPT-07 text to read "default 2222 (port 22 reserved for endlessh tarpit)".

**Stale disk-layout-refactor.md at repo root:**
- Issue: `disk-layout-refactor.md` is a pre-implementation planning document that predates the GSD workflow and describes tasks using imperative commands. All described work is now implemented in modules.
- Files: `disk-layout-refactor.md`
- Impact: Confuses orientation for new contributors — looks like outstanding work when it is superseded history.
- Fix approach: Delete or move to `.planning/research/` with a note that it is a pre-GSD design document.

## Known Bugs

**autoUpgrade flake hardcodes `#host` — wrong for serverProfile:**
- Symptoms: A machine deployed with `serverProfile` (i.e. `nixosConfigurations.server`) auto-upgrades using `nixosConfigurations.host` — a different configuration that includes `nerv.audio`, `nerv.bluetooth`, `nerv.printing`, BTRFS disk layout, and different impermanence mode.
- Files: `modules/system/nix.nix` line 18
- Trigger: `system.autoUpgrade.enable = true` is hardcoded on with `flake = "/etc/nixos#host"`. Any server deployment inherits this.
- Workaround: Override at the host level: `system.autoUpgrade.flake = lib.mkForce "/etc/nixos#server";` in the server's configuration. Or disable auto-upgrade: `system.autoUpgrade.enable = lib.mkForce false;`.

**nix.nix autoUpgrade assumes `/etc/nixos` path — flake may live elsewhere:**
- Symptoms: If the operator clones the repo to any path other than `/etc/nixos`, auto-upgrades fail silently or pull the wrong flake. The alias also assumes this path (`nrs`, `nrb`, `nrt` in zsh.nix).
- Files: `modules/system/nix.nix` line 18, `modules/services/zsh.nix` lines 91–93
- Trigger: Any deployment where the flake is not at `/etc/nixos`.
- Workaround: Override `system.autoUpgrade.flake` with `lib.mkForce` in `hosts/configuration.nix`.

## Security Considerations

**hosts/configuration.nix ships with all PLACEHOLDER values — invalid enum values will fail at evaluation:**
- Risk: `nerv.disko.layout = "PLACEHOLDER"` and `nerv.hardware.cpu = "PLACEHOLDER"` are not valid enum values. If a user builds without replacing placeholders, NixOS evaluation fails with an enum type error. This is intentional as a forcing function but has no runtime bypass.
- Files: `hosts/configuration.nix`
- Current mitigation: Enum type enforcement at evaluation time provides a hard fail. Warning comments on every placeholder line.
- Recommendations: No change needed — this is the intended behavior. Users should follow the README install procedure.

**LVM swapSize/storeSize/persistSize default to "PLACEHOLDER" — accepted string type:**
- Risk: `nerv.disko.lvm.*` options use `lib.types.str` with `default = "PLACEHOLDER"`. The string type accepts "PLACEHOLDER" without error; unlike enum options, this will only fail at disko execution time (partitioning), not at `nix flake check` or `nixos-rebuild`. A BTRFS deployment never reads these values but they remain in `hosts/configuration.nix` and could mislead operators.
- Files: `modules/system/disko.nix` lines 73–88, `hosts/configuration.nix` lines 46–48
- Current mitigation: Comment instructs replacement before first boot. Values are only read when `isLvm = true`.
- Recommendations: Consider adding an assertion in the LVM branch: `assert cfg.lvm.swapSize != "PLACEHOLDER" → "nerv.disko.lvm.swapSize must be set"`. This would catch the error at evaluation time rather than partition time.

**secureboot.nix: first-boot key enrollment runs automatically if UEFI Setup Mode is detected:**
- Risk: `systemd.services.secureboot-enroll-keys` fires on every boot until the sentinel file `/var/lib/secureboot-keys-enrolled` exists. On a system freshly installed with `nerv.secureboot.enable = true`, it will auto-enroll and reboot without operator interaction if the machine happens to be in Setup Mode.
- Files: `modules/system/secureboot.nix` lines 46–76
- Current mitigation: The service checks `sbctl status | grep "Setup Mode.*Enabled"` and skips silently if not in Setup Mode. The sentinel file prevents re-enrollment.
- Recommendations: This is documented intentional behavior. The risk is limited to machines deployed fresh with Secure Boot intentionally enabled. No action required.

**`/var/lib/secureboot-keys-enrolled` and `/var/lib/secureboot-setup-done` sentinel files are on root `/`:**
- Risk: In BTRFS impermanence mode, `/` is reset on every reboot by the rollback service. These sentinel files are not in `environment.persistence`, so they disappear after each rollback, causing the secureboot enrollment services to re-run after every rollback — re-enrolling keys every boot and rebooting in a loop.
- Files: `modules/system/secureboot.nix` lines 72, 122; `modules/system/impermanence.nix`
- Current mitigation: `hostProfile` has `nerv.secureboot.enable = false` by default. The comment in `flake.nix` line 34 says "Enable nerv.secureboot.enable = true after running sbctl enroll-keys on the target machine". So in practice a user who enables secureboot on the host profile would hit this.
- Recommendations: Add the sentinel files to `environment.persistence` when `mode = "btrfs"` and `secureboot.enable = true`. This should be a dedicated fix in `impermanence.nix` or `secureboot.nix`. The existing sbctl sbctlCovered warning in `impermanence.nix` (btrfs block) correctly catches `/var/lib/sbctl` but does NOT catch these two sentinel files.

**AIDE database initialization is manual — no first-boot automation:**
- Risk: `security.nix` installs AIDE and schedules daily checks but the comment explicitly says "Initialise the database manually after first boot: `sudo aide --init && sudo mv ...`". Without this, the daily `aide-check` service exits with no reference database, and changes go undetected.
- Files: `modules/system/security.nix` lines 54–55
- Current mitigation: Comment documents the manual step. Daily timer exists but is effectively inert until database is initialized.
- Recommendations: Add a `systemd.services.aide-init` oneshot that runs on first boot (sentinel file gate) to create the initial database automatically, similar to the secureboot enrollment pattern.

## Performance Bottlenecks

**`security.audit` rules audit ALL execve and openat syscalls system-wide:**
- Problem: Lines 30–31 in `security.nix` enable `exit,always -F arch=b64 -S execve` and `exit,always -F arch=b64 -S openat` unconditionally. On a busy desktop or server this generates very high audit log volume and can saturate `/var/log/audit/audit.log` rapidly.
- Files: `modules/system/security.nix` lines 29–41
- Cause: Broad catch-all rules without process filter (`-F exe=...` or `-F uid!=...`), applied to all users and all processes.
- Improvement path: Narrow the rules with UID or executable filters, or accept the volume. On the BTRFS impermanence host, audit logs go to `@log` subvolume (no size cap).

**ClamAV daemon runs in real-time on all hosts including desktop:**
- Problem: `services.clamav.daemon.enable = true` is unconditional in `security.nix`. On a desktop with large downloads or many files, clamd consumes substantial CPU and RAM.
- Files: `modules/system/security.nix` lines 44–48
- Cause: Fully opaque module — no `nerv.security.clamav` option to disable it.
- Improvement path: Future `OPT-V3` item: add `nerv.security.clamav.enable` option (default true) to allow disabling on low-resource machines.

## Fragile Areas

**BTRFS rollback: `@root-blank` must be created manually before nixos-install:**
- Files: `modules/system/disko.nix` lines 22–23
- Why fragile: The rollback service (`initrd.systemd.services.rollback`) snapshots `@root-blank → @` on every boot. If `@root-blank` was never created (i.e., the operator skipped the manual step), the rollback service fails at the `btrfs subvolume snapshot` line. The `|| true` on the delete step means failure is partially silent — the system may boot with a partially-broken root.
- Safe modification: Do not remove or rename `@root-blank`. The `|| true` on line 149 of `disko.nix` means a missing `@` is tolerated but a missing `@root-blank` is not (the snapshot command will fail without `|| true`). Adding `|| true` to the snapshot command would hide failures.
- Test coverage: No automated test — requires live BTRFS hardware. Must be manually verified per install.

**`home/default.nix` requires `/home/<name>/home.nix` to exist before nixos-rebuild:**
- Files: `home/default.nix` line 53
- Why fragile: The import `[ /home/${name}/home.nix ]` is an absolute path import that NixOS evaluates at build time with `--impure`. If the file does not exist on the target machine, `nixos-rebuild` fails with an import error that references a path outside the flake — confusing for new users.
- Safe modification: Always create a minimal `~/home.nix` (as shown in the module comment) before running `nixos-rebuild --impure` when `nerv.home.enable = true`.
- Test coverage: Static analysis cannot catch this — only fails at runtime on the target machine.

**`impermanence.nix` `full` mode: tmpfs root is hardcoded at `size=2G`:**
- Files: `modules/system/impermanence.nix` line 110
- Why fragile: Server deployments with high in-memory workloads (many services, large journals before flush) can exhaust the 2G tmpfs. This silently causes OOM or ENOSPC errors mid-boot or during service operation.
- Safe modification: Override at host level with `lib.mkForce`. Tracked in `REQUIREMENTS.md` as future requirement `DISKO-V3-01`.
- Test coverage: Not testable without running the server profile on real hardware.

**`bluetooth.nix`: WirePlumber config applied unconditionally — no PipeWire guard:**
- Files: `modules/services/bluetooth.nix` lines 42–53
- Why fragile: `services.pipewire.wireplumber.extraConfig` is set inside `lib.mkIf cfg.enable` (bluetooth enabled) but without a guard on `nerv.audio.enable`. If a user enables bluetooth without audio (e.g. a server with BT only), NixOS will emit the WirePlumber config into a system with no PipeWire daemon. The comment on line 41 says "no effect if PipeWire is not enabled" but this is an untested assumption — WirePlumber config may cause a warning or evaluation issue depending on NixOS version. This was explicitly noted as a known deviation from the original plan in the v2.0 audit.
- Safe modification: Treat as low-risk cosmetic debt. Adding `lib.mkIf config.nerv.audio.enable { ... }` around the WirePlumber block would be a clean fix.
- Test coverage: Not tested in isolation (no audio-off/bluetooth-on profile exists).

**`avahi.enable` is owned by both `bluetooth.nix` and `printing.nix` independently:**
- Files: `modules/services/bluetooth.nix` line 38, `modules/services/printing.nix` line 33
- Why fragile: Both modules set `services.avahi.enable = true` independently. NixOS module merging handles this safely (both true merges to true). However, if one module sets a conflicting Avahi option in the future, the merge may fail silently or override unexpectedly. The two-owner design was an explicit Phase 2 decision to allow independence.
- Safe modification: The current state is intentional and safe with NixOS merging semantics. No action required unless an Avahi option conflict arises.
- Test coverage: Merge correctness is implicit in NixOS evaluation — no dedicated test.

## Scaling Limits

**`nerv.disko.layout` enum has no BTRFS+LVM hybrid option:**
- Current capacity: Two profiles — `btrfs` (desktop) and `lvm` (server). The enum in `disko.nix` is locked to these two values.
- Limit: A user wanting BTRFS on a server, or a mixed layout (e.g. LVM with BTRFS data volumes), cannot express that through the current API.
- Scaling path: Add additional enum values or a more flexible `nerv.disko` option surface in a v3.0 phase.

**`nerv.impermanence.mode` enum has no opt-out for BTRFS-layout-only without impermanence:**
- Current capacity: Mode must be set if `nerv.impermanence.enable = true`. For a BTRFS deployment without environment.persistence, there is no "btrfs-raw" mode.
- Limit: Users who want BTRFS rollback without the bind-mount persistence layer cannot express this without overriding the impermanence module entirely.
- Scaling path: Future `mode = "btrfs-raw"` option or making `nerv.impermanence.enable` independently optional from `nerv.disko.layout`.

## Dependencies at Risk

**`disko` pinned to `v1.13.0` — known issue with `neededForBoot` on BTRFS subvolume mounts:**
- Risk: The pin at `v1.13.0` is a deliberate workaround documented in `impermanence.nix` lines 137–140: "disko v1.13.0 does not support neededForBoot on subvolume mounts (issues #192, #594 closed as 'use fileSystems directly')". The workaround (`fileSystems."${cfg.persistPath}".neededForBoot = lib.mkDefault true` in impermanence.nix) is the current fix.
- Impact: Upgrading disko past v1.13.0 requires re-validating whether neededForBoot behavior changed. The workaround may become redundant or conflict with a future disko version.
- Migration plan: Before upgrading disko, check disko changelog for neededForBoot BTRFS subvolume support. If resolved upstream, the override in impermanence.nix may be removed.

**`nixpkgs` on `nixos-unstable` — rolling input:**
- Risk: `flake.nix` pins to `github:NixOS/nixpkgs/nixos-unstable`. Unstable receives constant updates including kernel, driver, and security patches that may break existing module configurations without warning.
- Impact: Any `nix flake update` could introduce regressions in kernel module names, driver API changes, or module option renames.
- Migration plan: Consider switching to a stable NixOS channel (`nixos-25.11`) for production server deployments. The current `system.stateVersion = "25.11"` in `hosts/configuration.nix` suggests this was the intended stable target.

## Missing Critical Features

**No `nerv.nix.autoUpgrade` toggle option:**
- Problem: `system.autoUpgrade.enable = true` is hardcoded in `modules/system/nix.nix`. There is no `nerv.*` option to disable it. Users must use `lib.mkForce` at the host level.
- Blocks: Clean declarative disable of auto-upgrade without knowing NixOS internals.
- Tracked as future requirement `OPT-V3-01` in `REQUIREMENTS.md`.

**No `nerv.kernel.package` option — kernel hardcoded to Zen:**
- Problem: `modules/system/kernel.nix` hardcodes `lib.mkForce pkgs.linuxPackages_zen`. There is no option to select the kernel package without editing the module file or using `lib.mkForce` at host level.
- Blocks: Server deployments that need `linuxPackages_latest` or `linuxPackages_hardened` without forking modules.
- Tracked as future requirement `OPT-V3-02` in `REQUIREMENTS.md`.

## Test Coverage Gaps

**No automated NixOS build test in CI:**
- What's not tested: `nix flake check` and `nixos-rebuild build` for all three nixosConfigurations (`host`, `server`, and any future profiles) — these cannot run on the macOS development machine where this repo is maintained.
- Files: `flake.nix`, all `modules/`
- Risk: Regressions in module evaluation (type errors, assertion failures, import chain breaks) are only caught at deployment time on a real NixOS machine.
- Priority: High — add a GitHub Actions workflow using `nixos-rebuild build` or `nix build .#nixosConfigurations.host.config.system.build.toplevel` on a Linux runner.

**No tests for PLACEHOLDER sentinel values:**
- What's not tested: Whether building with all-PLACEHOLDER `hosts/configuration.nix` fails at evaluation (correct behavior) versus silently producing a broken system (incorrect behavior). The LVM size PLACEHOLDER values are `lib.types.str`, which accepts any string — they only fail at partition time.
- Files: `hosts/configuration.nix`, `modules/system/disko.nix`
- Risk: A BTRFS user who forgets to update LVM sizes (all three default to "PLACEHOLDER") will get a configuration that evaluates cleanly but would fail if ever switched to LVM layout. Low actual risk given the enum guard on layout.
- Priority: Medium — add assertions for LVM size options being non-PLACEHOLDER when `isLvm = true`.

**No integration test for the secureboot enrollment → reboot → TPM2 bind flow:**
- What's not tested: The two-service enrollment sequence in `secureboot.nix` (Boot 1: key enrollment + reboot; Boot 2: TPM2 bind). The sentinel file logic has never been exercised in an automated test.
- Files: `modules/system/secureboot.nix`
- Risk: Regression in the two-step flow (e.g., ordering changes, `sbctl status` output format change in a nixpkgs update) would only be caught on hardware during first deployment.
- Priority: Medium — this is inherently hard to automate and low-frequency (first-boot only), but a changelog monitor for sbctl output format would mitigate the risk.

---

*Concerns audit: 2026-03-10*
