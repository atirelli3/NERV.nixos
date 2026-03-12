# Codebase Concerns

**Analysis Date:** 2026-03-12

## Tech Debt

**Hard-Coded LUKS Label Synchronization:**
- Issue: The LUKS device label "NIXLUKS" is duplicated across three modules without a canonical source. Changes to disko partition labels must be manually propagated.
- Files: `modules/system/disko.nix` (line 30), `modules/system/secureboot.nix` (lines 87, 107, 112, 141)
- Impact: If someone changes the LUKS label in disko.nix, Secure Boot and TPM2 binding will silently fail because systemd-cryptenroll targets the wrong device label. This could brick systems with Secure Boot enabled.
- Fix approach: Extract the LUKS label as a shared NixOS option at the top level (e.g., `config.nerv.disko.luksLabel`) and reference it in both disko.nix and secureboot.nix via `config.nerv.disko.luksLabel`. This creates a single source of truth.

**Placeholder Configuration Trap:**
- Issue: `hosts/configuration.nix` contains eight PLACEHOLDER values that must be manually replaced. Failure to replace them causes silent errors (empty hostname, wrong disk device, wrong layout type).
- Files: `hosts/configuration.nix` (lines 14, 19-27, 31, 34, 37-39)
- Impact: Users can successfully rebuild without modifying these values, resulting in systems with empty hostnames, mismatched disk layouts, or the wrong user. The only indication is a build error on hostname assertion (line 49 in identity.nix), but disko and LVM size errors are silent.
- Fix approach: Create a validation script or pre-check that runs before nixos-rebuild to ensure no PLACEHOLDERs remain. Alternatively, use lib.mkDefault with an assertion that fires if any critical value is still the default.

**Audit Rules as Custom Service (audit 4.x Compatibility):**
- Issue: The NixOS `security.audit` module generates `-b/-f/-r` flags that were removed in audit 4.x. Rather than using the module, custom audit rules are loaded via `audit-rules` oneshot service.
- Files: `modules/system/security.nix` (lines 21-50)
- Impact: If someone tries to use `security.audit.*` options (which look normal in NixOS modules), they will override these manually-loaded rules, causing audit-rules-nixos.service to fail silently. The system runs without audit logging and users won't notice.
- Fix approach: Add a hard assertion that `security.audit.enable == false` when `security.auditd.enable == true`. Document why the module can't be used. Consider filing an issue with NixOS to deprecate the incompatible options.

**Home Manager File Imports Outside Flake Boundary:**
- Issue: Home Manager imports `/home/<user>/home.nix` which exists outside the flake and Git. This requires `nixos-rebuild --impure`.
- Files: `home/default.nix` (line 44)
- Impact: Flake purity is lost. `nix flake check` will fail unless `--impure` is added. CI/CD pipelines and unattended rebuilds fail. Users on machines without a user home.nix will get a configuration evaluation error.
- Fix approach: Create per-user fallback stubs. If `/home/<user>/home.nix` doesn't exist, import a default minimal module that doesn't break the system. Alternatively, provide `hm-template/home.nix` as the default and document how to customize it.

## Known Bugs

**Secure Boot First-Boot Race Condition (Documented but Unresolved):**
- Symptoms: TPM2 LUKS auto-unlock fails after Secure Boot key enrollment if someone doesn't reboot between boot 1 and boot 2.
- Files: `modules/system/secureboot.nix` (lines 32-39)
- Trigger: User enrolls Secure Boot keys, the service attempts to bind LUKS to TPM2 in the same boot before reboot.
- Workaround: The code checks if step 1 is done and exits (line 90-92). Subsequent boots attempt TPM2 binding. This works but is fragile — if someone disables the second service, the check never runs.
- Root cause: PCR 7 (Secure Boot policy) doesn't reflect the active Secure Boot state until the next boot after key enrollment. Binding TPM2 before the reboot captures the wrong PCR 7 hash.
- Improvement path: Automate the two-boot flow: make the first service do only enrollment and mandatory reboot, then validate that the second service only runs after reboot and PCR 7 is stable. Add systemd dependencies to prevent the second service from even starting until boot 2.

**BTRFS Rollback @root-blank Snapshot Must Exist Beforehand:**
- Symptoms: Boot fails with "no subvolume found" if the @root-blank snapshot doesn't exist before the rollback service runs.
- Files: `modules/system/disko.nix` (line 126-130, rollback service script)
- Trigger: First boot when disko creates the BTRFS layout. The script looks for @root-blank but disko only creates it as an empty entry (no content) — the initial creation happens during partitioning, but if rollback service runs before disko finishes setup, it can fail.
- Workaround: The script uses `|| true` on the delete command (line 127), so a missing snapshot doesn't fail the service, but a missing @root-blank source (line 130) will cause the snapshot to fail.
- Root cause: Race between disko setup (which creates @root-blank) and the initrd rollback service.
- Improvement path: Make the rollback service explicitly depend on the disko setup completing. Verify that @root-blank exists and is readable before attempting to snapshot it. Provide a clearer error message if it's missing.

**Home Manager stateVersion Inheritance Assumes osConfig is Always Available:**
- Symptoms: If a Home Manager user module doesn't pass osConfig correctly, `osConfig.system.stateVersion` will be undefined, causing a cryptic evaluation error.
- Files: `home/default.nix` (line 46)
- Trigger: Manually importing a user module outside the normal nixos-rebuild flow or testing Home Manager in isolation.
- Workaround: None. The module assumes osConfig will always be available.
- Root cause: Home Manager user modules aren't guaranteed to have osConfig in all evaluation contexts.
- Improvement path: Use `lib.mkDefault` with a fallback stateVersion (e.g., "25.11") so the module is more forgiving if osConfig is unavailable. Document that osConfig is required in the options description.

## Security Considerations

**SSH Tarpit Port Bound to All Interfaces:**
- Risk: The endlessh tarpit listens on all network interfaces (0.0.0.0:22). If a machine has multiple NICs, port 22 is exposed on all of them without filtering.
- Files: `modules/services/openssh.nix` (line 72)
- Current mitigation: The tarpit is slow and harmless — it just wastes bot connections. The real SSH daemon runs on a different port (2222 by default), so attackers can't log in via the tarpit.
- Recommendations: Consider adding a per-NIC binding option (e.g., `nerv.openssh.tarpitBindAddr`) to restrict the tarpit to specific interfaces (e.g., WAN-facing only). Document the trade-offs: binding to all interfaces slows down port scanners globally, but adds noise if you have internal NICs.

**Audit Logging Scoped by auid (audit-rules Service):**
- Risk: The audit rules skip processes without an auid (system/kernel processes) to avoid `audit_log_subj_ctx` errors. This means rootkits running as system processes without a login session won't be logged.
- Files: `modules/system/security.nix` (lines 36-40)
- Current mitigation: AIDE file integrity monitoring (daily timer) will detect tampering by rootkits even if they bypass audit logging.
- Recommendations: Document this limitation in the code. Consider adding supplementary logging for system calls from pid 1 (init) or other critical daemons, even though they lack auid. Test if AppArmor confinement + audit on specific syscalls (like setuid/setgid on line 42) catches privilege escalation in system services.

**Secure Boot Keys Persisted in /var/lib/sbctl Without Backup:**
- Risk: If a user enables Secure Boot, sbctl creates the PKI bundle in `/var/lib/sbctl`. If impermanence mode is "full" (/ as tmpfs), this directory is reset on every reboot unless explicitly persisted.
- Files: `modules/system/impermanence.nix` (lines 73-85), `modules/system/secureboot.nix` (line 22)
- Current mitigation: The impermanence module asserts that `/var/lib/sbctl` is not in tmpfs extraDirs (IMPL-02, line 73-85). If someone tries to add `/var/lib/sbctl` to impermanence tmpfs paths, the assertion catches it.
- Recommendations: The assertion is defensive but doesn't prevent a user from disabling the assertion with lib.mkForce. Add a warning (already present on line 164-165 for BTRFS mode) to FULL mode as well. Recommend backing up `/var/lib/sbctl` after first enrollment: `sudo cp -r /var/lib/sbctl ~/sbctl-backup`.

**LUKS Encryption with allowDiscards=true Leaks Trim Hints:**
- Risk: TRIM (Secure Erase) pass-through is enabled for SSDs (disko.nix line 29). While this improves SSD performance, TRIM commands leak information about which sectors have been erased, which can help an attacker infer file deletions.
- Files: `modules/system/disko.nix` (line 29)
- Current mitigation: TRIM is necessary for SSD longevity and doesn't expose plaintext data. An attacker with physical access can already extract keys from memory or side-channels.
- Recommendations: Document this trade-off in disko.nix. For highly sensitive deployments (e.g., servers handling classified data), consider disabling allowDiscards and accepting lower SSD lifespan. For consumer laptops, the current setting is appropriate.

**ClamAV Daemon Runs with Update Frequency of 24x per Day:**
- Risk: Virus definitions are checked 24 times per day, which means frequent updates from the virus database upstream. If the upstream CDN is compromised or uses an insecure transport, definitions could be poisoned. However, ClamAV has signature verification on updates.
- Files: `modules/system/security.nix` (lines 54-57)
- Current mitigation: ClamAV uses cryptographic verification for definition signatures. The frequency is reasonable for a desktop system.
- Recommendations: If running on a server with no internet access, disable the updater and manually manage definitions via cold updates. Document the update frequency and what it means in comments.

## Performance Bottlenecks

**BTRFS Rollback Service Runs on Every Boot (IO-Bound):**
- Problem: The rollback service snapshots @root-blank to @ on every single boot, regardless of whether the root was modified. On SSDs with many files, this I/O (especially listing all subvolumes) could add noticeable boot time.
- Files: `modules/system/disko.nix` (lines 116-133)
- Cause: The service doesn't check if @ already matches @root-blank before deleting and re-snapshotting. It's defensive (always reset) but not optimized.
- Improvement path: Before deleting @, check if it's already a snapshot of @root-blank or if / still contains the expected system files. If so, skip the rollback. Alternatively, snapshot incrementally (only copy changed blocks) using BTRFS send/receive for faster resets. Benchmark the impact on typical drives (NVMe vs. spinning disk) and document expected boot time overhead.

**ClamAV Daemon Scans All Files on Disk (Optional but Enabled):**
- Problem: Real-time scanning via clamd can impact system responsiveness if the machine has many files or if a large copy operation happens (e.g., `git clone`, downloading large archives).
- Files: `modules/system/security.nix` (lines 54-57)
- Cause: ClamAV is enabled by default with no exclusions (e.g., /nix, /var/cache).
- Improvement path: Add excludes for the Nix store and other high-churn directories. Alternatively, make the daemon configurable (e.g., `nerv.security.clamd.enable = true` with options for maxthreads, maxfiles, etc.). Benchmark impact on a system with a large /nix store.

**Audit Rules with `connect` Syscall Logging (Every Network Connection):**
- Problem: Logging every `connect()` syscall for auid>=1000 (line 40 in security.nix) creates a massive audit log, especially on servers with many clients.
- Files: `modules/system/security.nix` (line 40)
- Cause: Complete transparency for debugging, but the log will grow rapidly.
- Improvement path: For servers, replace the broad `connect` rule with a rule for specific high-risk ports or services (e.g., only log if connect() targets privileged ports <1024). For desktops, the current setting is reasonable. Document this in comments.

## Fragile Areas

**Secure Boot TPM2 Binding Depends on Label-Based Device Lookup:**
- Files: `modules/system/secureboot.nix` (lines 107-112)
- Why fragile: The service uses `/dev/disk/by-label/NIXLUKS` to bind LUKS to TPM2. If the label is changed (in disko.nix) without updating secureboot.nix, the binding silently fails and the system falls back to password-protected LUKS. This isn't obviously wrong — the system still boots.
- Safe modification: Always update the `luksDevice01` variable in secureboot.nix when changing the label in disko.nix. Add a validation script that checks both labels match. Or, extract the label to a shared NixOS option (see Tech Debt section).
- Test coverage: No tests verify that TPM2 binding succeeds or that the label is consistent across modules.

**Impermanence Mode Coupling (btrfs vs. full):**
- Files: `modules/system/impermanence.nix` (lines 35-47), `modules/system/disko.nix` (lines 73-134)
- Why fragile: The impermanence mode determines which directories are persisted and how. BTRFS mode expects disko layout to be "btrfs" (with subvolumes). Full mode expects / to be tmpfs. If someone sets `nerv.impermanence.mode = "full"` but `nerv.disko.layout = "btrfs"`, the result is two different persistence strategies competing (BTRFS subvolume @persist vs. tmpfs @ with bind mounts). This causes a boot-time conflict.
- Safe modification: Add an assertion that enforces mode/layout matching: `(cfg.mode == "btrfs" && config.nerv.disko.layout == "btrfs") || (cfg.mode == "full" && config.nerv.disko.layout == "lvm")`. Document this coupling clearly.
- Test coverage: No tests validate the mode/layout pairing.

**ZSH Activation Script Depends on /etc/passwd Format:**
- Files: `modules/services/zsh.nix` (lines 149-158)
- Why fragile: The script reads `/etc/passwd` with `IFS=:` to extract usernames and home directories. If NixOS changes the passwd format or someone uses a non-standard userdb backend (e.g., LDAP), this script could silently skip users or fail.
- Safe modification: Check that the script handles edge cases: users with colons in their home directory names, users with login shells that don't exist. Add error handling and logging to the activation script.
- Test coverage: No tests verify that ~/.zshrc is created for all users with zsh as their shell.

**Home Manager users Imported from Filesystem Outside NixOS Evaluation:**
- Files: `home/default.nix` (line 44)
- Why fragile: Importing `/home/<user>/home.nix` requires the file to exist during evaluation. If a user is listed in `nerv.home.users` but their home.nix doesn't exist, the entire system evaluation fails with a "file not found" error. There's no fallback.
- Safe modification: Use `builtins.pathExists /home/${name}/home.nix` to check before importing, and provide a default minimal module if the file is missing. Or, require that a `hm-template/home.nix` is provided as a fallback.
- Test coverage: No tests verify that all users in nerv.home.users have valid home.nix files.

**disko.nix Depends on Device Path Provided in hosts/configuration.nix:**
- Files: `modules/system/disko.nix` (lines 74-75), `hosts/configuration.nix` (line 31)
- Why fragile: The disko config requires `disko.devices.disk.main.device` to be set in hosts/configuration.nix. If it's left as `/dev/PLACEHOLDER`, disko will attempt to partition `/dev/PLACEHOLDER` (which doesn't exist) or fail cryptically.
- Safe modification: Add validation in disko.nix that asserts the device path doesn't contain "PLACEHOLDER" and is a recognized device (e.g., `/dev/nvme*`, `/dev/sd*`, `/dev/vd*`). Test that the assertion fires during dry-run evaluation.
- Test coverage: No tests verify that the disko device path is valid before partitioning.

## Scaling Limits

**AIDE File Integrity Database Growth on Large Filesystems:**
- Current capacity: AIDE is configured to monitor `/boot`, `/etc`, `/bin`, `/sbin`, `/usr/bin`, `/usr/sbin`, `/lib`, `/usr/lib` — approximately 50K-200K files on a typical NixOS system.
- Limit: If these directories exceed 1M files (rare), AIDE database generation and checks will become memory-intensive and slow. Gzip compression helps but there's a practical limit.
- Scaling path: For large enterprise deployments, consider replacing AIDE with a real-time file integrity service (e.g., Samhain, TripWire) or using a centralized log collection system (e.g., ELK stack) to aggregate audit events.

**Audit Log Retention (No Rotation Policy Configured):**
- Current capacity: Audit logs go to `/var/log/audit/audit.log`. No rotation policy is set, so logs will grow unbounded until disk fills.
- Limit: On a busy server with the current audit rules, the log can grow at 10-100 MB/day. On a 100 GB root partition, logs would fill in 1-10 years depending on activity.
- Scaling path: Configure `auditd.log_file` with a rotation policy (e.g., rotate every 1GB or 7 days). Or, forward audit logs to a remote syslog server for centralized retention. Document the expected log growth rate.

**OpenSSH fail2ban Jail on High-Traffic Servers:**
- Current capacity: fail2ban tracks IP addresses and ban times in memory. For a server receiving 10K+ SSH connection attempts per second, the ban table could grow to millions of entries.
- Limit: On a 4GB RAM system, fail2ban's memory usage could spike if the ban table isn't pruned. The default bantime of "24h" means old bans accumulate.
- Scaling path: For high-traffic servers, increase bantime-increment to longer intervals and reduce bantime-increment.overalljails scope. Use a faster intrusion detection system (e.g., nftables with stateless rules) for DDoS mitigation. Or, switch to a more scalable solution like fail2ban with a database backend.

**ClamAV Definition Updates on Bandwidth-Constrained Networks:**
- Current capacity: With freshclam checking 24 times per day, update traffic is roughly 5-20 MB per check (full or delta definition download).
- Limit: On a metered connection (e.g., 4G mobile), definitions could consume significant bandwidth. On a fully air-gapped network, freshclam will fail 24 times per day, filling logs.
- Scaling path: Make update frequency configurable. For bandwidth-constrained deployments, reduce to once-daily checks. For air-gapped networks, disable the updater entirely and use offline definition packages.

## Dependencies at Risk

**Lanzaboote (Secure Boot Bootloader) at Risk of Becoming Unmaintained:**
- Risk: Lanzaboote is a relatively new project (active but single-maintainer). If maintainership lapses, Secure Boot support in NixOS could bitrot. The flake pins a specific version (lanzaboote, no version specified — uses latest), so updates are automatic but unvetted.
- Impact: Secure Boot stops working after a major NixOS release if Lanzaboote isn't updated. Machines with Secure Boot enabled could fail to boot.
- Migration plan: Monitor the Lanzaboote GitHub repo for maintenance signals. Have a fallback plan to disable Secure Boot and use systemd-boot if Lanzaboote becomes unmaintained. Test Secure Boot disablement on a non-critical machine to verify the fallback works.

**disko Version Pinned to v1.13.0 (Could Diverge from nixpkgs):**
- Risk: The flake pins disko to a specific version (v1.13.0) while nixpkgs is on unstable. If disko has a major breaking change in a future release, the system can't use the latest disko without manual flake updates. Conversely, if disko has a critical bug in v1.13.0, the system is stuck with it until the flake is updated.
- Impact: Disk initialization may fail on new hardware if disko doesn't support the latest disk technologies or partition schemes. Existing systems may be vulnerable to disk-related bugs in the pinned version.
- Migration plan: Periodically test newer disko versions in a branch. Use `nix flake update disko` to bump the version, but do so on a test system first. Monitor disko's changelog for bug fixes and breaking changes.

**Home Manager Input Follows nixpkgs (Tight Coupling):**
- Risk: The flake makes home-manager.nixpkgs follow nixpkgs. This means Home Manager is always on the same nixpkgs version as the system. If nixpkgs has a regression, both fail together.
- Impact: A breaking change in nixpkgs could break both system and user home configurations simultaneously, with no way to roll back independently.
- Migration plan: Consider decoupling home-manager's nixpkgs from the system's in future phases (e.g., allow pinning home-manager to a slightly older nixpkgs if needed for stability). For now, test nixpkgs updates in a branch before applying to production.

**Linux Latest Kernel (Always Upgrading):**
- Risk: `boot.kernelPackages = pkgs.linuxPackages_latest;` in boot.nix means every nixos-rebuild pulls the absolute latest kernel from nixpkgs. If a kernel has a regression (e.g., breaks a driver), all systems rebuild into the broken kernel.
- Impact: Systems could become unbootable after a simple nixos-rebuild if the latest kernel has a critical bug.
- Migration plan: Test kernel upgrades on a non-critical machine first. Consider switching to `linuxPackages_6_12` (pinned LTS version) for production systems. Make kernel version configurable per-host if stability is a priority.

## Test Coverage Gaps

**Untested: Secure Boot Two-Boot Enrollment Sequence:**
- What's not tested: The actual flow of TPM2 enrollment across two boots. The secureboot-enroll-keys and secureboot-enroll-tpm2 services have interdependencies (step 1 must complete, then reboot, then step 2 can run) that aren't validated.
- Files: `modules/system/secureboot.nix` (lines 41-120)
- Risk: If a user disables one of the services or has a systemd ordering issue, the second step may never run, and LUKS will stay on password-only mode. No test catches this.
- Improvement: Create a NixOS test (using nixosTest framework) that simulates the two-boot flow: first boot enrolls keys, reboots, second boot binds TPM2, and verifies the LUKS device has the tpm2 slot. Add a test that verifies the assertion for PCR 7 stability.

**Untested: Impermanence Mode / Disko Layout Coupling:**
- What's not tested: The interaction between impermanence.mode (btrfs vs. full) and disko.layout. No test verifies that mismatched modes cause an error or that matched modes work correctly.
- Files: `modules/system/impermanence.nix`, `modules/system/disko.nix`
- Risk: A user could accidentally create an unsupported configuration (e.g., mode="full" with layout="btrfs") and discover it only at boot time.
- Improvement: Add a NixOS assertion (or test) that validates the pairing at evaluation time, not boot time.

**Untested: LUKS Device Label Consistency:**
- What's not tested: Verification that the LUKS label in disko.nix matches the label used by boot.nix and secureboot.nix.
- Files: `modules/system/disko.nix`, `modules/system/secureboot.nix`, `modules/system/boot.nix`
- Risk: Label mismatches can cause silent failures in Secure Boot TPM2 binding.
- Improvement: Add a test that parses disko.nix and secureboot.nix to extract the label and asserts they're equal. Or, extract the label to a shared NixOS option and test that it's used consistently.

**Untested: BTRFS Rollback Snapshot Creation:**
- What's not tested: The rollback service (in disko.nix initrd) successfully creates the @ snapshot from @root-blank on the first boot.
- Files: `modules/system/disko.nix` (lines 116-133)
- Risk: If @root-blank doesn't exist or the snapshot command fails, the initrd hangs or panics. No test catches this.
- Improvement: Create a NixOS test that mounts a BTRFS volume with @root-blank and verifies the rollback service creates @ correctly. Test both successful rollback and error conditions (missing @root-blank, permissions issues).

**Untested: Home Manager File Import Fallback:**
- What's not tested: Home Manager evaluation when `/home/<user>/home.nix` doesn't exist.
- Files: `home/default.nix` (line 44)
- Risk: If a user is added to `nerv.home.users` but their home.nix doesn't exist, the system fails to evaluate. No test prevents this.
- Improvement: Create a test that evaluates a NixOS config with a user in nerv.home.users but without a home.nix file, and verify it either errors gracefully or uses a fallback.

**Untested: ZSH Activation Script Edge Cases:**
- What's not tested: The ~/.zshrc creation script (zsh.nix lines 149-158) handles unusual /etc/passwd formats, special characters in home directories, or missing home directories.
- Files: `modules/services/zsh.nix`
- Risk: For a user with a colon or newline in their home directory path, the script could silently skip them or create .zshrc in the wrong location.
- Improvement: Create a test that adds users with edge-case home directories and verifies ~/.zshrc is created correctly for all.

**Untested: SSH Tarpit Endlessh Binding to All Interfaces:**
- What's not tested: Verification that endlessh successfully binds to port 22 on all interfaces.
- Files: `modules/services/openssh.nix` (line 72)
- Risk: If port 22 is already in use (e.g., from a previous SSH daemon), endlessh fails to bind silently, and the "tarpit" is ineffective.
- Improvement: Add a test that starts the services, verifies port 22 responds with a slow SSH banner (endlessh), and port 2222 responds with a real SSH daemon.

---

*Concerns audit: 2026-03-12*
