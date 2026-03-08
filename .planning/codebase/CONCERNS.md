# Codebase Concerns

**Analysis Date:** 2026-03-08

## Tech Debt

**autoUpgrade flake target hardcoded to `#host`:**
- Issue: `system.autoUpgrade.flake = "/etc/nixos#host"` in `modules/system/nix.nix` assumes every machine uses the `host` nixosConfiguration. Servers and VMs using `server` or `vm` profiles will silently upgrade using the wrong profile unless manually overridden.
- Files: `modules/system/nix.nix` (line 18), `modules/services/zsh.nix` (lines 91-93)
- Impact: A server running with `serverProfile` will auto-upgrade against the `host` profile, which enables audio, bluetooth, and printing it never asked for. Shell aliases `nrs`, `nrb`, `nrt` also hardcode `#host`.
- Fix approach: Expose `nerv.autoUpgrade.flakeTarget` as a string option defaulting to `"host"`, and thread it through `system.autoUpgrade.flake` and the shell aliases.

**`autoUpgrade` toggle hardcoded — no opt-out without `lib.mkForce`:**
- Issue: `system.autoUpgrade.enable = true` is unconditional in `modules/system/nix.nix`. The comment tags this as roadmap item `OPT-V2-01` but no option exists.
- Files: `modules/system/nix.nix` (lines 15-20)
- Impact: Operators who want to control updates manually or via CI must reach for `lib.mkForce false`, which bypasses the module's public contract and is undiscoverable.
- Fix approach: Add `nerv.autoUpgrade.enable = lib.mkEnableOption "auto nix rebuild" // { default = true; }` gated around the `system.autoUpgrade` block.

**`nerv.home.users` not populated in any profile:**
- Issue: All three profiles in `flake.nix` set `nerv.home.enable = true` (for `host` and `vm`) but none set `nerv.home.users`. The Home Manager NixOS module is wired but zero users are activated by default — the feature does nothing until an operator manually adds users in `configuration.nix`.
- Files: `flake.nix` (lines 35-74), `home/default.nix`
- Impact: New adopters enabling home manager see no activation, no per-user services, and no error. Silent no-op is confusing.
- Fix approach: Document in `hosts/configuration.nix` that `nerv.home.users = [ "PLACEHOLDER" ]` must be set alongside the username declaration. Add an assertion that warns when `nerv.home.enable = true` but `nerv.home.users = []`.

**NIXLUKS label is a string constant repeated across four files without a shared variable:**
- Issue: The disk label `"NIXLUKS"` is hardcoded independently in `hosts/disko-configuration.nix` (line 45), `modules/system/boot.nix` (line 20), `modules/system/secureboot.nix` (lines 92, 112, 117, 146). All four carry a comment saying "must stay in sync" — a manual synchronization requirement.
- Files: `hosts/disko-configuration.nix`, `modules/system/boot.nix`, `modules/system/secureboot.nix`
- Impact: Renaming the LUKS label (e.g. to accommodate a second disk) requires editing four locations and auditing all the sync comments. One missed edit breaks boot or TPM2 unlock.
- Fix approach: Expose `nerv.luks.label` as a string option (default `"NIXLUKS"`) in a small `luks.nix` module, then reference `config.nerv.luks.label` in `boot.nix` and `secureboot.nix`. `disko-configuration.nix` can read it via `config` if it is imported into the same system closure.

**`stateVersion` set to unreleased version `"25.11"`:**
- Issue: `hosts/configuration.nix` sets `system.stateVersion = "25.11"`. As of the analysis date (2026-03-08), NixOS 25.11 has not been released. The flake tracks `nixos-unstable` which may or may not have introduced 25.11 semantics for stateful NixOS modules.
- Files: `hosts/configuration.nix` (line 24)
- Impact: Some NixOS modules gate migration behavior on `stateVersion`. Setting a future version as a placeholder risks skipping state migrations if the machine is ever rebuilt from a current nixos-unstable snapshot that recognises 25.11.
- Fix approach: Set `stateVersion` to the current stable or unstable channel version used at first-boot time, not a projected future release. Document that this value must not be bumped retroactively.

## Known Bugs

**`nerv.hardware.cpu` and `nerv.hardware.gpu` accept only enum values; `configuration.nix` ships `"PLACEHOLDER"` for both:**
- Symptoms: Evaluating the flake as shipped (before operator customization) produces a Nix type error because `"PLACEHOLDER"` is not a member of `[ "amd" "intel" "other" ]` for cpu, or `[ "amd" "nvidia" "intel" "none" ]` for gpu.
- Files: `hosts/configuration.nix` (lines 30-31), `modules/system/hardware.nix`
- Trigger: `nix flake check` or `nixos-rebuild` on the unmodified repo.
- Workaround: Operator must replace `"PLACEHOLDER"` before any evaluation. The README documents this, but there is no automated check to catch an unevaluated placeholder.
- Fix approach: Add an assertion in `hardware.nix` that produces a clear message if the cpu/gpu values still look like placeholders, or change defaults to `"other"` / `"none"` (already the defaults) and remove the explicit PLACEHOLDER assignment from `configuration.nix` entirely, relying on defaults.

**`disko-configuration.nix` contains unevaluable swap size string `"SIZE_RAM * 2"`:**
- Symptoms: Disko will reject `"SIZE_RAM * 2"` as an LVM logical volume size — it is a placeholder comment masquerading as a value.
- Files: `hosts/disko-configuration.nix` (line 61)
- Trigger: Running `disko --mode disko` on the unmodified file.
- Workaround: Operator must replace with a concrete value like `"16G"` before use.
- Fix approach: Comment out the size entirely with a clear `# REPLACE:` marker and provide no default, forcing the operator to fill it in. The current value will likely cause a cryptic disko error rather than a clear message.

## Security Considerations

**AIDE database requires manual initialization after first boot:**
- Risk: The AIDE file integrity monitor is installed and its daily check timer is active, but the database must be manually initialized (`sudo aide --init && sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db`). Until this is done, the daily check exits with an error that could be misread as noise. The window between first boot and initialization is unmonitored.
- Files: `modules/system/security.nix` (lines 54-55, 103-111)
- Current mitigation: Comment in the file documents the manual step. `SuccessExitStatus = [ 0 1 ]` prevents systemd unit failure when changes are found, but a missing database also exits non-zero and is silently suppressed.
- Recommendations: Add a `secureboot-enroll-keys`-style first-boot service that detects the missing database and initializes it automatically, or add a distinct systemd condition to suppress the check timer until the DB exists.

**AppArmor is in permissive mode — `killUnconfinedConfinables = false`:**
- Risk: `security.apparmor.enable = true` is set but the comment explicitly notes `killUnconfinedConfinables = false` (default). Apps without profiles run unconfined. AppArmor provides audit logging but no actual confinement for most user applications.
- Files: `modules/system/security.nix` (lines 22-23)
- Current mitigation: Profiles shipped with packages are applied automatically. auditd logs unconfined activity.
- Recommendations: Document this intentional decision more explicitly. Consider enabling `killUnconfinedConfinables` for the server profile where user-facing apps are absent and the risk of breakage is lower.

**LUKS `passwordFile = "/tmp/luks-password"` in disko configuration:**
- Risk: The disko configuration sources the LUKS encryption password from `/tmp/luks-password`. This is a plaintext password on the installation medium. If the installation medium is retained or re-used, the password is exposed.
- Files: `hosts/disko-configuration.nix` (line 46)
- Current mitigation: The comment documents this as "pre-seeded by the install script." The install medium is ephemeral in standard use.
- Recommendations: Document that the install medium should be securely wiped after installation. Consider using a `passwordFile = "/dev/stdin"` pattern for interactive entry, or document that the `/tmp` file must be populated from a secure source during install.

**Audit ruleset logs ALL `openat` syscalls system-wide:**
- Risk: `-a exit,always -F arch=b64 -S openat` captures every file open operation across all processes. On a busy desktop this generates extreme audit log volume. The `/var/log` exclusion in the AIDE config prevents integrity checking of audit logs themselves.
- Files: `modules/system/security.nix` (lines 30-34)
- Current mitigation: `security.auditd.enable = true` with the current ruleset. Logs go to `/var/log/audit/audit.log`.
- Recommendations: Narrow the `openat` rule with `-F uid>=1000` to limit to user-space file opens, or add `-F success=1` / `-F success=0` filters. Consider rate-limiting via auditctl `-r`.

**`/tmp/luks-password` path hardcoded — LUKS password persists across impermanence minimal mode:**
- Risk: In `minimal` impermanence mode, `/tmp` is mounted as tmpfs, so `/tmp/luks-password` is wiped on reboot. However the disko config references this path at install time, not at runtime. Not a live security risk post-install, but the pattern trains operators to use `/tmp` for secrets.
- Files: `hosts/disko-configuration.nix` (line 46)
- Current mitigation: File is used only during `disko --mode disko` disk provisioning, not at runtime.

## Performance Bottlenecks

**`init_on_alloc=1` and `init_on_free=1` kernel parameters have measurable throughput cost:**
- Problem: Both parameters are unconditional in `modules/system/kernel.nix`. The Zen kernel is optimized for latency, but zero-on-alloc/free adds CPU overhead to every allocation and free — typically 1-5% throughput regression on memory-intensive workloads.
- Files: `modules/system/kernel.nix` (lines 18-19)
- Cause: Security hardening parameters applied unconditionally across all profiles including VMs and desktops where the threat model may not warrant the trade-off.
- Improvement path: These are acceptable on server and security-sensitive profiles. Consider exposing `nerv.kernel.hardening.enable` (default true) that gates the most expensive params for VM or development profiles.

**ClamAV daemon runs unconditionally on all profiles including servers:**
- Problem: `services.clamav.daemon.enable = true` and `services.clamav.updater.enable = true` are always on. The daemon loads virus definitions into memory (several hundred MB). On a server with `serverProfile`, this memory is consumed for a feature that may be irrelevant.
- Files: `modules/system/security.nix` (lines 43-48)
- Cause: `security.nix` is fully opaque with no options — it is all-or-nothing.
- Improvement path: Split ClamAV into an opt-in option `nerv.security.clamav.enable` (default true for `host`, false for `server`).

## Fragile Areas

**`secureboot.nix` must be last in `modules/system/default.nix` import order:**
- Files: `modules/system/default.nix` (line 16), `modules/system/secureboot.nix` (line 22)
- Why fragile: `secureboot.nix` applies `boot.loader.systemd-boot.enable = lib.mkForce false`. If any future module is appended after `secureboot.nix` in the import list and also touches `boot.loader.systemd-boot`, merge priority becomes ambiguous. Adding new modules requires awareness of this ordering constraint.
- Safe modification: Always append new system modules before `secureboot.nix` in the imports list. The comment in `default.nix` documents this, but it is enforced only by convention.
- Test coverage: No automated check verifies the import order.

**`bluetooth.nix` sets `services.pipewire.wireplumber.extraConfig` unconditionally:**
- Files: `modules/services/bluetooth.nix` (lines 42-52)
- Why fragile: WirePlumber config is applied even if `nerv.audio.enable = false`. The comment notes "no effect if PipeWire is not enabled," but if PipeWire is later enabled independently (e.g., via a host override), Bluetooth audio config is silently active from `bluetooth.nix` without any indication. This creates an invisible cross-module dependency.
- Safe modification: Wrap the `wireplumber.extraConfig` block in `lib.mkIf config.nerv.audio.enable` to make the dependency explicit.
- Test coverage: None.

**`printing.nix` and `bluetooth.nix` both set `services.avahi.enable = true` independently:**
- Files: `modules/services/printing.nix` (lines 31-35), `modules/services/bluetooth.nix` (line 38)
- Why fragile: Both modules set `services.avahi.enable = true` without coordination. This is currently harmless because NixOS merges boolean `true` values cleanly. However `printing.nix` also sets `services.avahi.nssmdns4 = true` while `bluetooth.nix` does not. If a future module sets `services.avahi.nssmdns4 = false` with `lib.mkDefault`, the merge behavior will be non-obvious.
- Safe modification: Consider centralizing Avahi configuration in a shared `avahi.nix` module or a `nerv.avahi.enable` option rather than duplicating across service modules.

**Home Manager requires `nixos-rebuild --impure` — not enforced or validated:**
- Files: `home/default.nix` (lines 9-12), `modules/services/zsh.nix` (lines 91-93)
- Why fragile: The `nrs`/`nrb`/`nrt` shell aliases in `zsh.nix` do not include `--impure`. Any user with `nerv.home.enable = true` who uses these aliases will get a build failure when `home-manager.users` tries to import `/home/<name>/home.nix` (an absolute path outside the flake boundary). The aliases silently give the wrong command for the most common use case.
- Safe modification: Either add `--impure` to the aliases unconditionally (acceptable since the flake is always installed locally), or gate the alias definition on whether `nerv.home.enable` is true.

## Scaling Limits

**All `nixosConfigurations` are hardcoded to `"x86_64-linux"`:**
- Current capacity: Three configurations: `host`, `server`, `vm` — all x86_64-linux.
- Limit: ARM64 (e.g., Apple Silicon via UTM, Raspberry Pi, cloud ARM instances) cannot use the provided configurations without forking `flake.nix`.
- Scaling path: Replace `system = "x86_64-linux"` with a `systems` list and generate configurations per system using `nixpkgs.lib.genAttrs`, or expose a `mkNervSystem { system = ...; profile = ...; }` helper function in `nixosModules`.

**Single `hosts/` directory — no per-host isolation:**
- Current capacity: One machine identity file (`hosts/configuration.nix`) shared across all three `nixosConfigurations`. Adding a second machine requires either forking `configuration.nix` or restructuring the `hosts/` layout entirely.
- Limit: A multi-host deployment (e.g., one desktop + one server) cannot be represented without significant flake restructuring.
- Scaling path: Move to `hosts/<hostname>/configuration.nix` and `hosts/<hostname>/hardware-configuration.nix` per-machine layout. The flake profile system already supports this; the directory structure does not.

## Dependencies at Risk

**`nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"` — no pin:**
- Risk: The flake tracks `nixos-unstable` without a specific commit pin beyond what `flake.lock` captures. Routine `nix flake update` pulls the latest unstable commit, which can introduce breaking changes to NixOS module interfaces (e.g., option renames, behavior changes in `services.openssh`, `boot.lanzaboote`, etc.).
- Impact: `system.autoUpgrade` runs daily with `nix flake update` semantics. An unstable NixOS bump can break any of the hardcoded module options.
- Migration plan: Consider pinning to a specific `nixos-unstable` commit in `flake.lock` and updating intentionally, or switching to a stable channel (e.g., `nixos-25.05`) for production machines once it is released.

**`disko` pinned to `v1.13.0` but other inputs float:**
- Risk: `disko` is pinned (`url = "github:nix-community/disko/v1.13.0"`) while `lanzaboote`, `home-manager`, and `impermanence` are unpinned (track default branch). Mixed pinning strategy — one critical input pinned, others floating — creates inconsistency and risk of inter-input API drift.
- Impact: `home-manager` or `lanzaboote` upstream changes can silently break the `host` configuration on next `nix flake update`.
- Migration plan: Either pin all security-sensitive inputs to tags/commits, or explicitly document the upgrade procedure for each floating input.

## Missing Critical Features

**No assertion guards against unmodified PLACEHOLDER values at evaluation time:**
- Problem: `hosts/configuration.nix` ships with `nerv.hostname = "PLACEHOLDER"`, `nerv.primaryUser = [ "PLACEHOLDER" ]`, and `disko.devices.disk.main.device = "/dev/PLACEHOLDER"`. Only `nerv.hostname != ""` is checked (identity.nix assertion). The string `"PLACEHOLDER"` passes this check. The enum types for `cpu` and `gpu` will fail, but `hostname`, `primaryUser`, `timeZone`, `defaultLocale`, and `keyMap` will all silently accept `"PLACEHOLDER"` as a valid value.
- Blocks: A machine that boots with `nerv.hostname = "PLACEHOLDER"` will be assigned that hostname. `nerv.primaryUser = [ "PLACEHOLDER" ]` will create a user named `PLACEHOLDER` with wheel access.
- Fix approach: Add assertions in `identity.nix` that check `config.nerv.hostname != "PLACEHOLDER"`, `config.nerv.primaryUser != [ "PLACEHOLDER" ]`, and similar guards for locale values.

**No multi-disk LUKS support without manual script extension:**
- Problem: The `luks-cryptenroll` helper script in `secureboot.nix` is hardcoded to one LUKS device (`NIXLUKS`). The commented-out extension instructions show how to add more, but it requires editing module code rather than setting an option.
- Blocks: Systems with multiple encrypted disks cannot use the TPM2 auto-unlock feature for secondary disks without modifying `modules/system/secureboot.nix` directly.
- Fix approach: Expose `nerv.secureboot.luksDevices = [ "NIXLUKS" ]` as a list option and generate the `systemd-cryptenroll` calls dynamically.

## Test Coverage Gaps

**No automated evaluation tests:**
- What's not tested: Whether the Nix expressions evaluate without errors across the three profiles (`host`, `server`, `vm`). There are no CI checks, no `nix flake check` invocation in any workflow, and no test that validates all PLACEHOLDER-replaced configurations build successfully.
- Files: All `.nix` files; no test directory exists.
- Risk: Module interface regressions (option type changes, assertion changes, import path errors) are caught only when a human runs `nixos-rebuild`.
- Priority: High — this is the primary risk for a library intended to be adopted by others.

**No test for the secureboot two-boot sequence:**
- What's not tested: The `secureboot-enroll-keys` and `secureboot-enroll-tpm2` systemd services interact via sentinel files in `/var/lib/`. The guard logic (`-f /var/lib/secureboot-keys-enrolled`, Secure Boot active check) is bash embedded in Nix strings. A logic error here could wipe TPM2 slots or fail to bind LUKS on first-boot.
- Files: `modules/system/secureboot.nix` (lines 58-124)
- Risk: Boot failure or permanent LUKS lockout on machines where `nerv.secureboot.enable = true`.
- Priority: High — consequences of a bug here are irreversible without manual recovery.

**No test for impermanence `full` mode and `environment.persistence`:**
- What's not tested: The `full` impermanence path (tmpfs root + environment.persistence) is only activated via `serverProfile` but there are no integration tests confirming that `/etc/machine-id`, SSH host keys, and journal are correctly bound from `/persist` after reboot.
- Files: `modules/system/impermanence.nix` (lines 110-139)
- Risk: A silent misconfiguration could result in fresh SSH host keys on every reboot, breaking known_hosts for all SSH clients.
- Priority: Medium.

---

*Concerns audit: 2026-03-08*
