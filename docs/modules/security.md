# Module: Security

**File:** `modules/system/security.nix`

System security hardening — AppArmor, auditd, ClamAV, AIDE, sudo restrictions. Fully opaque and always-on.

---

## Components

### AppArmor

Mandatory Access Control (MAC) via the NixOS AppArmor module.

- `security.apparmor.enable = true`
- Profiles are loaded from the nixpkgs apparmor-profiles set
- `security.apparmor.killUnconfinedConfinables = false` (default — opt-in to kill unconfined processes)

To check AppArmor status:
```bash
sudo aa-status
```

---

### auditd

Kernel-level syscall auditing. Rules are broad by design — they prioritize completeness over noise.

**Audited syscalls:**

| Syscall | Rationale |
|---------|-----------|
| `execve` (all) | Track all process execution |
| `openat` (all) | Track all file opens |
| `connect` (all) | Track all outbound network connections |
| `setuid`, `setgid` | Track privilege escalation |

**Audited file writes:**

| Path | Rationale |
|------|-----------|
| `/etc/passwd` | User database modification |
| `/etc/shadow` | Password hash modification |
| `/etc/sudoers` | Sudo configuration modification |
| `/etc/ssh/sshd_config` | SSH daemon configuration modification |

**Log location:** `/var/log/audit/audit.log`

```bash
# View audit log
sudo ausearch -ts today
# View recent events
sudo journalctl -u auditd
```

> **Performance note:** Auditing every `execve` and `openat` syscall generates very high log volume on active workstations. If this degrades I/O performance, override the audit rules with `lib.mkForce` in `hosts/configuration.nix`.

---

### ClamAV

Real-time antivirus scanning.

- `services.clamav.daemon.enable = true` — clamd scanning daemon
- `services.clamav.updater.enable = true` — freshclam virus definition updater (24 checks/day)
- clamd maintains approximately 400–600 MB in-memory virus database

```bash
# Manual scan
clamscan -r /home

# Update definitions manually
sudo freshclam

# Check clamd status
systemctl status clamav-daemon
```

---

### AIDE (Advanced Intrusion Detection Environment)

Daily file integrity monitoring.

- **Schedule:** daily systemd timer (`aide-check.timer`)
- **Config:** `/etc/aide.conf`
- **Database:** `/var/lib/aide/aide.db`

**Monitored paths:**
- `/boot`, `/etc`, `/bin`, `/sbin`, `/usr/bin`, `/usr/sbin`, `/lib`, `/usr/lib`

**Excluded paths:**
- `/nix`, `/var/log`, `/proc`, `/sys`, `/dev`, `/run`, `/tmp`

**After first install — initialize the database:**
```bash
sudo aide --init
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

```bash
# Run an integrity check manually
sudo aide --check

# View check results
sudo journalctl -u aide-check
```

---

### lynis

Hardening auditor — installed in `systemPackages`, run manually.

```bash
sudo lynis audit system
```

---

### Sudo restrictions

- `security.sudo.execWheelOnly = true` — only users in the `wheel` group can run `sudo`

---

### Additional hardening

- `security.protectKernelImage = true` — prevents kernel image from being overwritten
- `security.lockKernelModules = false` — module locking disabled (would break NixOS module loading)
- `security.forcePageTableIsolation = true` — enforces PTI unconditionally (Meltdown mitigation)

---

## Override examples

```nix
# hosts/configuration.nix
{ lib, ... }: {
  # Disable ClamAV if resource-constrained (not recommended)
  services.clamav.daemon.enable = lib.mkForce false;

  # Disable auditd (not recommended for production)
  security.auditd.enable = lib.mkForce false;
  boot.kernelParams = lib.mkForce (
    builtins.filter (p: p != "audit=1") config.boot.kernelParams
  );
}
```
