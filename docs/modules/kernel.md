# Module: Kernel

**File:** `modules/system/kernel.nix`

Zen kernel with comprehensive hardening parameters. Fully opaque — no user-facing options. Use `lib.mkForce` to override.

---

## What it does

### Kernel selection

Sets `boot.kernelPackages = lib.mkForce pkgs.linuxPackages_zen`. The Zen kernel includes optimizations for desktop responsiveness (lower latency, better interactivity under load).

To use a different kernel:
```nix
# hosts/configuration.nix
{ lib, pkgs, ... }: {
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_hardened;
  # or: pkgs.linuxPackages_latest, pkgs.linuxPackages, etc.
}
```

### Kernel boot parameters

Applied via `boot.kernelParams`:

| Category | Parameters |
|----------|-----------|
| Memory hardening | `slab_nomerge`, `init_on_alloc=1`, `init_on_free=1` |
| ASLR | `randomize_kstack_offset=on` |
| CPU mitigations | `pti=on` (Page Table Isolation), `tsx=off` |
| Attack surface reduction | `vsyscall=none`, `debugfs=off`, `oops=panic` |
| Lockdown | `lockdown=confidentiality` (when supported by kernel build) |

### Sysctl hardening

Applied via `boot.kernel.sysctl`:

**Network:**

| Key | Value | Effect |
|-----|-------|--------|
| `net.ipv4.tcp_syncookies` | `1` | SYN flood protection |
| `net.ipv4.conf.all.rp_filter` | `1` | Reverse path filtering |
| `net.ipv4.conf.all.accept_redirects` | `0` | Drop ICMP redirects |
| `net.ipv4.conf.all.send_redirects` | `0` | Don't send redirects |
| `net.ipv4.conf.all.log_martians` | `1` | Log packets with impossible addresses |
| `net.ipv6.conf.all.accept_redirects` | `0` | IPv6 redirect drop |

**Kernel:**

| Key | Value | Effect |
|-----|-------|--------|
| `kernel.dmesg_restrict` | `1` | Restrict dmesg to root |
| `kernel.kptr_restrict` | `2` | Hide kernel pointers in /proc |
| `kernel.unprivileged_bpf_disabled` | `1` | Disable unprivileged BPF |
| `net.core.bpf_jit_harden` | `2` | Harden BPF JIT compiler |
| `kernel.yama.ptrace_scope` | `1` | Restrict ptrace to parent processes |
| `kernel.perf_event_paranoid` | `3` | Restrict perf events to root |
| `kernel.unprivileged_userns_clone` | `0` | Disable unprivileged user namespaces |

**Filesystem:**

| Key | Value | Effect |
|-----|-------|--------|
| `fs.protected_hardlinks` | `1` | Block hardlink attacks |
| `fs.protected_symlinks` | `1` | Block symlink attacks |
| `fs.protected_fifos` | `2` | Protect FIFOs in world-writable dirs |
| `fs.protected_regular` | `2` | Protect regular files in sticky dirs |

### Blacklisted kernel modules

The following modules are blacklisted via `boot.blacklistedKernelModules`:

| Module | Reason |
|--------|--------|
| `cramfs`, `squashfs`, `udf`, `hfs`, `hfsplus`, `jffs2`, `freevxfs` | Rarely used filesystems, reduce attack surface |
| `dccp`, `sctp`, `rds`, `tipc` | Rarely used network protocols with past CVEs |

---

## Override examples

```nix
# hosts/configuration.nix
{ lib, pkgs, ... }: {
  # Use hardened kernel instead of Zen
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_hardened;

  # Re-enable a blacklisted module (e.g. for VirtualBox)
  boot.blacklistedKernelModules = lib.mkForce [];

  # Adjust a sysctl value
  boot.kernel.sysctl."kernel.unprivileged_userns_clone" = lib.mkForce 1;
}
```
