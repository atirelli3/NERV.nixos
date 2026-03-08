# Codebase Concerns

**Analysis Date:** 2026-03-06

## Tech Debt

**server/configuration.nix is incomplete and non-deployable:**
- Issue: Multiple literal placeholder strings remain in the file — `size=SIZE` for tmpfs, `by-partuuid/UUID` for swap, empty `console = {}`, and an explicit `# TODO: For all users (also root) use zsh.` comment.
- Files: `server/configuration.nix`
- Impact: This configuration cannot be deployed as-is. Attempting a `nixos-rebuild switch` would either fail at evaluation or mount a tmpfs with the string "SIZE" as the size argument, causing a kernel mount error.
- Fix approach: Fill in the three SIZE values with actual byte amounts (e.g., `"8G"`), replace the UUID placeholder with the real partition UUID, add the zsh user shell configuration, and populate the `console` attribute set.

**server/disko-configuration.nix has five unresolved placeholder values:**
- Issue: `device = "/dev/DISK"`, `size = "SIZE_RAM * 2"`, and three `size = "SIZE"` entries are literal strings, not valid values. There is also an in-line design question comment: `# I really need it with tmpfs ??`.
- Files: `server/disko-configuration.nix`
- Impact: Running `disko` against this file will either fail parsing or attempt to create partitions with nonsensical sizes. The root LV is an ext4 partition while `server/configuration.nix` mounts it as tmpfs — these two files are architecturally inconsistent with each other.
- Fix approach: Decide whether `/` should be tmpfs (as in `server/configuration.nix`) or ext4 (as in the disko file), then align both files. Replace all SIZE/DISK placeholders with real values.

**base/disko-configuration.nix has unresolved placeholder values:**
- Issue: `device = "/dev/DISK"` and `size = "SIZE_RAM * 2"` remain as literal placeholder strings.
- Files: `base/disko-configuration.nix`
- Impact: Not deployable. Disko will fail when attempting to identify `/dev/DISK` or allocate a swap LV with the string `"SIZE_RAM * 2"`.
- Fix approach: Replace with the target disk path (e.g., `/dev/nvme0n1`) and a concrete size (e.g., `"16G"`).

**modules/openssh.nix uses a generic placeholder username:**
- Issue: `AllowUsers = [ "myUser" ]` and all commented key examples reference `"myUser"` instead of the actual system username (`demon0` as defined in the configurations).
- Files: `modules/openssh.nix`
- Impact: If deployed without editing, `AllowUsers` will whitelist a non-existent user, effectively blocking all SSH logins while the daemon runs.
- Fix approach: Replace `"myUser"` with `"demon0"` (or parameterize via a NixOS option) and add an authorized key.

**Three versions of the secureboot setup service with diverging logic:**
- Issue: Three separate implementations exist: `modules/secureboot.nix` (two-phase split across reboots), `.template/secureboot-configuration.nix` (single-phase, uses `systemctl disable` to self-disable), and `.template/configuration.nix` (single-phase with a `sleep 2` and flag file in `/persist`). These have different idempotency strategies, different PCR-enrollment timing assumptions, and different flag file paths.
- Files: `modules/secureboot.nix`, `.template/secureboot-configuration.nix`, `.template/configuration.nix`
- Impact: Confusion about which implementation is canonical. The `.template/secureboot-configuration.nix` version has a critical flaw: it attempts to bind LUKS to TPM2 in the same boot that enrolls Secure Boot keys. Because PCR 7 has not yet settled to its active-Secure-Boot value, the TPM2 slot will seal against the wrong measurement, causing auto-unlock to fail on all subsequent boots.
- Fix approach: Adopt the two-phase approach from `modules/secureboot.nix` as the canonical implementation and remove or clearly mark the template variants as deprecated.

**`base/flake.nix` imports `modules/secureboot.nix` and `modules/openssh.nix` but `base/configuration.nix` hardcodes `systemd-boot.enable = true`:**
- Issue: `modules/secureboot.nix` forces `systemd-boot.enable = lib.mkForce false` and enables lanzaboote. `base/configuration.nix` sets `systemd-boot.enable = true`. The `lib.mkForce` in the module wins, but the explicit `true` in `configuration.nix` is misleading and will produce a NixOS warning about conflicting definitions.
- Files: `base/configuration.nix`, `modules/secureboot.nix`, `base/flake.nix`
- Impact: Developer confusion; potential for build warnings being silently ignored.
- Fix approach: Remove `boot.loader.systemd-boot.enable = true` from `base/configuration.nix` since `modules/secureboot.nix` manages this setting.

**`base/flake.nix` does not include `modules/kernel.nix`, `modules/nix.nix`, `modules/security.nix`, or `modules/bluetooth.nix`:**
- Issue: Several hardening and configuration modules exist but are not wired into any flake output. `modules/kernel.nix` in particular overrides `kernelPackages` with `lib.mkForce pkgs.linuxPackages_zen`, which would conflict with the `pkgs.linuxPackages_latest` set in `base/configuration.nix` — but since `kernel.nix` is never imported, this conflict is latent rather than active.
- Files: `base/flake.nix`, `modules/kernel.nix`, `modules/nix.nix`, `modules/security.nix`, `modules/bluetooth.nix`
- Impact: Security hardening from `modules/security.nix` and `modules/kernel.nix` (AppArmor, auditd, sysctl hardening, kernel blacklists) is not applied to the `nixos-base` system. The `server/` profile also has no flake entry point at all.
- Fix approach: Create a server flake or extend `base/flake.nix`. Decide which modules each profile requires and explicitly compose them.

**`server/` profile has no flake entry point:**
- Issue: There is no `server/flake.nix`. The server configuration exists as orphaned `.nix` files with no way to build, test, or deploy them with `nixos-rebuild`.
- Files: `server/configuration.nix`, `server/disko-configuration.nix`
- Impact: The server profile is unreachable from the Nix toolchain without manually writing a flake or modifying `base/flake.nix`.
- Fix approach: Either add a `nixos-server` output to `base/flake.nix` importing `../server/configuration.nix`, or create a dedicated `server/flake.nix`.

**`vm/` directory is empty with only a `.gitkeep`:**
- Issue: The `vm/` directory exists as a placeholder with no content.
- Files: `vm/.gitkeep`
- Impact: Implied future work that is not implemented. Any references to VM configurations will fail.
- Fix approach: Either implement VM configurations or remove the directory to reduce confusion.

## Known Bugs

**`.template/secureboot-configuration.nix` TPM2 enrollment runs in wrong boot phase:**
- Symptoms: After installation, LUKS auto-unlock via TPM2 fails on every subsequent boot, requiring manual passphrase entry.
- Files: `.template/secureboot-configuration.nix`
- Trigger: Using this template as the secureboot setup implementation. The script enrolls Secure Boot keys and immediately enrolls TPM2 in the same boot session without rebooting in between, capturing the pre-Secure-Boot PCR 7 value.
- Workaround: Use `modules/secureboot.nix` (two-phase approach) or manually re-enroll using the `luks-cryptenroll` helper script after a reboot.

**`server/disko-configuration.nix` label typo:**
- Symptoms: LUKS device label mismatch — disko formats with label `NIKLUKS` (line 26) while `server/configuration.nix` and all other references expect `NIXLUKS`.
- Files: `server/disko-configuration.nix` (line 26: `extraFormatArgs = [ "--label" "NIKLUKS" ]`)
- Trigger: Running disko with `server/disko-configuration.nix` and then booting with `server/configuration.nix`.
- Workaround: None — the system will fail to decrypt at boot because `by-label/NIXLUKS` will not exist.

**`server/configuration.nix` uses `import` (singular) instead of `imports`:**
- Symptoms: Nix evaluation error: `error: attribute 'import' missing`.
- Files: `server/configuration.nix` (line 4: `import = [ ./hardware-configuration.nix ]`)
- Trigger: Any `nixos-rebuild` or `nix flake check` evaluation of this configuration.
- Workaround: Correct `import` to `imports`.

**`server/configuration.nix` mounts `/` and `/home` as tmpfs but disko allocates them as ext4:**
- Symptoms: The `fileSystems` block in `server/configuration.nix` sets `/` and `/home` to `fsType = "tmpfs"` and references labels `NIXROOT`/`NIXHOME`, yet `server/disko-configuration.nix` creates `NIXROOT` and `NIXHOME` as ext4 LVs. Kernel will mount the ext4 device and ignore the `fsType = "tmpfs"` directive, or mounting will fail entirely.
- Files: `server/configuration.nix`, `server/disko-configuration.nix`
- Trigger: Deploying the server profile.
- Workaround: Decide on the intended filesystem type for `/` and align both files.

## Security Considerations

**`modules/openssh.nix` — `AllowUsers = [ "myUser" ]` blocks all logins until edited:**
- Risk: SSH daemon is running but no valid user is whitelisted. An administrator who forgets to update the placeholder is locked out of the machine remotely.
- Files: `modules/openssh.nix`
- Current mitigation: None — this is an unfilled template placeholder.
- Recommendations: Parameterize with a NixOS option (`options.myOrg.sshUsers`) or hardcode the real username. Add a local console login path that does not depend on SSH.

**LUKS password passed via `/tmp/luks-password` during Disko install:**
- Risk: The LUKS passphrase is written to `/tmp/luks-password` (world-readable tmpfs) during installation. Any process running during install can read it.
- Files: `base/disko-configuration.nix` (line 27), `server/disko-configuration.nix` (line 27), `.template/disko-configuration.nix` (line 32)
- Current mitigation: This is a standard Disko pattern; the file is only present during the installation environment. It should be deleted immediately after.
- Recommendations: Document explicit cleanup (`rm /tmp/luks-password`) in installation instructions. Consider using a named pipe or systemd credential instead.

**`.template/configuration.nix` hardcodes a swap partition UUID:**
- Risk: File `5d5825bc-603b-487d-9d11-5965fbbaaaf4` (line 126) is a real partition UUID committed to the repository. If this corresponds to a real device, its existence in a public repo leaks infrastructure topology.
- Files: `.template/configuration.nix`
- Current mitigation: None.
- Recommendations: Replace with a placeholder comment or use `by-label` for consistency with the rest of the codebase.

**`modules/security.nix` AIDE database is not initialized automatically:**
- Risk: The daily `aide-check` timer will fail silently with "database not found" until the administrator manually runs `sudo aide --init`. Until initialized, file integrity monitoring provides no protection.
- Files: `modules/security.nix`
- Current mitigation: A comment documents the manual steps. The service `SuccessExitStatus = [ 0 1 ]` prevents journal errors from the failed check.
- Recommendations: Add a one-shot systemd service that runs `aide --init` on first boot if the database file does not exist, and activates `aide-check.timer` only after initialization.

**AppArmor is in permissive mode (default):**
- Risk: `security.apparmor.enable = true` enables AppArmor in complain/permissive mode. `killUnconfinedConfinables` is explicitly left false (commented). Processes not matched by a profile run unconfined.
- Files: `modules/security.nix`
- Current mitigation: AppArmor is enabled and profiles shipped by packages are loaded.
- Recommendations: Enable `security.apparmor.killUnconfinedConfinables = true` once application compatibility is validated, or document the threat model that accepts permissive mode.

**`modules/kernel.nix` includes AMD-specific parameters (`amd_iommu=on`) but `modules/hardware.nix` also enables Intel-incompatible settings:**
- Risk: `tsx=off` (disabling Intel TSX) is a no-op on AMD but harmless. `amd_iommu=on` on an Intel system will produce a boot warning but not fail. However, `hardware.cpu.amd.updateMicrocode = true` on an Intel system may cause `nixos-rebuild` evaluation errors depending on the nixpkgs version.
- Files: `modules/kernel.nix`, `modules/hardware.nix`
- Current mitigation: None — no CPU-architecture guard is in place.
- Recommendations: Wrap CPU-specific settings in `lib.mkIf (config.hardware.cpu.amd.updateMicrocode or false)` guards or split into separate AMD/Intel hardware modules.

## Performance Bottlenecks

**Audit rules log every `execve` and `openat` syscall system-wide:**
- Problem: The audit rules in `modules/security.nix` and `.template/configuration.nix` capture all process executions and all file opens on a 64-bit system. On a busy desktop or server this generates enormous audit log volume.
- Files: `modules/security.nix`, `.template/configuration.nix`
- Cause: `-a exit,always -F arch=b64 -S execve` and `-a exit,always -F arch=b64 -S openat` are unconditional.
- Improvement path: Scope rules with `-F uid!=root` exclusions or `-F key=` filters. For a server, consider restricting to specific paths or users rather than system-wide syscall tracing.

**`nix.gc` runs `--delete-older-than 20d` weekly but `keep-outputs = true` and `keep-derivations = true` retain all build-time closure:**
- Problem: With `keep-outputs` and `keep-derivations` both enabled, the GC will not reclaim build dependencies even when they are older than 20 days, as long as any GC root references them transitively. On an active development machine the store will grow unboundedly.
- Files: `modules/nix.nix`
- Cause: Interaction between `keep-outputs`/`keep-derivations` and time-based GC options.
- Improvement path: Consider disabling `keep-outputs` on systems that are not used for active development, or add explicit `nix-collect-garbage -d` runs that bypass the retention flags.

## Fragile Areas

**Two-phase secureboot setup depends on flag files in `/var/lib/`:**
- Files: `modules/secureboot.nix`
- Why fragile: Flag files `/var/lib/secureboot-keys-enrolled` and `/var/lib/secureboot-setup-done` survive only on persistent storage. On the impermanence/tmpfs setups described in `.template/configuration.nix`, `/var/lib/` on tmpfs is wiped each boot unless explicitly listed in `environment.persistence`. If not persisted, both services will attempt re-enrollment on every boot, re-enrolling keys that are already enrolled and potentially corrupting the TPM2 slot.
- Safe modification: Ensure `/var/lib/sbctl`, `/var/lib/secureboot-keys-enrolled`, and `/var/lib/secureboot-setup-done` are listed under `environment.persistence."/persist".directories` or `.files` when using impermanence.
- Test coverage: No tests exist for this logic.

**`bluetooth.nix` overrides `systemd.user.services.obex.serviceConfig.ExecStart` with a prepended empty string:**
- Files: `modules/bluetooth.nix`
- Why fragile: The pattern `ExecStart = [ "" "${pkgs.bluez}/libexec/bluetooth/obexd --root=%h/Downloads --auto-accept" ]` relies on the NixOS convention that an empty string clears the previous `ExecStart` list before the new value. This is correct NixOS behavior but is non-obvious. If the upstream NixOS module ever changes the service name or drops the default `ExecStart`, this override will silently stop working or produce a double-ExecStart unit.
- Safe modification: Add a comment explaining the empty-string-clear idiom. Pin or verify against the NixOS module source when updating nixpkgs.
- Test coverage: None.

**`modules/printing.nix` assumes `services.avahi.enable` is already set by `pipewire.nix`:**
- Files: `modules/printing.nix`, `modules/pipewire.nix`
- Why fragile: `printing.nix` sets `services.avahi.nssmdns4 = true` but does not set `services.avahi.enable = true`, relying on `pipewire.nix` to enable Avahi first. If `printing.nix` is imported without `pipewire.nix`, mDNS printer discovery will silently not work (nssmdns4 enabled but daemon not running).
- Safe modification: Add `services.avahi.enable = true` directly in `printing.nix` — Nix's attribute merge makes this idempotent.
- Test coverage: None.

**`modules/zsh.nix` disables `syntaxHighlighting.enable` then sources it manually in `interactiveShellInit`:**
- Files: `modules/zsh.nix`
- Why fragile: Setting `syntaxHighlighting.enable = false` prevents the NixOS module from managing load order, then `interactiveShellInit` re-adds it manually. This works correctly, but if `pkgs.zsh-syntax-highlighting` is removed from nixpkgs or its store path changes, the hardcoded `source` path will break with a cryptic "no such file" error at shell startup rather than a build-time failure.
- Safe modification: This is a known intentional pattern (load order enforcement). Document that updating nixpkgs may require verifying the source paths still exist.
- Test coverage: None.

## Scaling Limits

**`nixos-unstable` pinning with no flake lock file visible in repo:**
- Current capacity: Depends entirely on whatever `nixos-unstable` resolves to at `nix flake update` time.
- Limit: Using `nixos-unstable` means any `nix flake update` can pull in breaking changes. There is no `flake.lock` committed to the repository (not visible in the file listing).
- Scaling path: Commit `flake.lock` to the repository to ensure reproducible builds. Consider switching to a stable NixOS channel (`nixos-25.05` once released) for production server use.

## Dependencies at Risk

**`nixos-unstable` as the sole nixpkgs input:**
- Risk: `nixos-unstable` is a rolling-release channel. NixOS modules, package APIs, and option names can change without notice.
- Impact: Any `nix flake update` can silently break configurations. The `system.autoUpgrade` with `dates = "daily"` in `modules/nix.nix` will automatically apply these updates daily.
- Migration plan: Pin to a stable channel for the server profile. Use `nixos-unstable` only for workstation/development profiles where bleeding-edge packages are needed.

**`lanzaboote` pinned to floating `main` branch in `base/flake.nix` and `.template/flake.nix`:**
- Risk: `url = "github:nix-community/lanzaboote"` without a version tag follows `main`, meaning any upstream breaking change is picked up on the next `flake update`.
- Impact: Secure Boot may break after an update if lanzaboote changes its module interface or sbctl compatibility.
- Migration plan: Pin to a release tag as done in `.template/flake2.nix` (`lanzaboote/v0.4.1`).

## Missing Critical Features

**No authorized SSH keys configured anywhere:**
- Problem: `modules/openssh.nix` documents how to add keys but provides no actual key. `AllowUsers` references `"myUser"`. No configuration file in the repo sets `openssh.authorizedKeys`.
- Blocks: Remote access to any deployed machine built from this configuration.

**No user password configured in the base or server profiles:**
- Problem: `base/configuration.nix` defines `users.users.demon0` with no `hashedPassword`, `hashedPasswordFile`, or `initialPassword`. The server `.template/configuration.nix` references `/persist/passwords/demon0` which must exist before first boot.
- Blocks: Local console login on first boot for the base profile.

**`server/` profile has no flake entry point:**
- Problem: No flake references `server/configuration.nix`. There is no way to build the server configuration without manual intervention.
- Blocks: Any attempt to deploy, test, or `nix flake check` the server profile.

**`vm/` directory is entirely empty:**
- Problem: The `vm/` directory exists with only a `.gitkeep`, implying planned VM configuration that has not been implemented.
- Blocks: Any VM-related use cases the project intends to support.

## Test Coverage Gaps

**No NixOS tests exist for any module:**
- What's not tested: Boot sequence (LUKS unlock, Secure Boot enrollment, TPM2 binding), SSH access restrictions, firewall rules, AIDE initialization, zsh configuration load order.
- Files: All files in `modules/`, `base/`, `server/`
- Risk: Regressions in the secureboot two-phase setup, the openssh AllowUsers restriction, or the impermanence persistence list go undetected until a real system fails to boot or is inaccessible.
- Priority: High — NixOS supports `nixosTest` via `pkgs.nixosTest` which can test these scenarios in a VM.

---

*Concerns audit: 2026-03-06*
