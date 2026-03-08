# modules/system/kernel.nix
#
# Purpose : Kernel selection and generic hardening parameters.
# Options : None — fully opaque. Use lib.mkForce to override any setting.
# Note    : CPU-specific IOMMU params (amd_iommu=on / intel_iommu=on / iommu=pt)
#           live in hardware.nix behind nerv.hardware.cpu — they are NOT here.

{ config, lib, pkgs, ... }:

{
  # Zen kernel: optimised for desktop responsiveness and low latency.
  # Swap to linuxPackages_hardened for stricter security at the cost of compatibility.
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_zen;

  boot.kernelParams = [
    # Memory hardening
    "slab_nomerge"          # prevents heap exploitation via slab cache merging
    "init_on_alloc=1"       # zero memory on allocation (eliminates use-before-init)
    "init_on_free=1"        # zero memory on free (eliminates use-after-free leaks)
    "page_alloc.shuffle=1"  # randomises page allocator freelist order
    "randomize_kstack_offset=on" # randomises kernel stack offset per syscall

    # CPU vulnerability mitigations
    "pti=on"   # Page Table Isolation — mitigates Meltdown (x86)
    "tsx=off"  # disable Intel TSX — mitigates TAA/MDS side-channel attacks

    # Attack surface reduction
    "vsyscall=none" # removes legacy vsyscall page (known ROP gadget source)
    "debugfs=off"   # prevents debug interface exposure in production
  ];

  boot.kernel.sysctl = {
    # ── Network ──────────────────────────────────────────────────────────────

    # Reverse-path filtering: drop packets whose source is unreachable via the incoming interface.
    "net.ipv4.conf.all.rp_filter"     = 1;
    "net.ipv4.conf.default.rp_filter" = 1;

    # SYN flood protection via SYN cookies.
    "net.ipv4.tcp_syncookies" = 1;
    # RFC 1337: drop RSTs arriving on TIME-WAIT sockets.
    "net.ipv4.tcp_rfc1337"   = 1;

    # Disable ICMP redirect acceptance — prevents routing table manipulation.
    "net.ipv4.conf.all.accept_redirects"  = 0;
    "net.ipv4.conf.all.send_redirects"    = 0;
    "net.ipv6.conf.all.accept_redirects"  = 0;

    # Disable source routing — source-routed packets can bypass firewalls.
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;

    # Ignore broadcast pings (smurf attack mitigation) and bogus ICMP errors.
    "net.ipv4.icmp_echo_ignore_broadcasts"       = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;

    # Log packets with impossible (martian) source addresses.
    "net.ipv4.conf.all.log_martians"     = 1;
    "net.ipv4.conf.default.log_martians" = 1;

    # ── Kernel ───────────────────────────────────────────────────────────────

    # Restrict dmesg to root only.
    "kernel.dmesg_restrict" = 1;
    # Hide kernel symbol addresses from unprivileged users.
    "kernel.kptr_restrict" = 2;
    # Disable eBPF for unprivileged users — major attack surface reduction.
    "kernel.unprivileged_bpf_disabled" = 1;
    # Harden the eBPF JIT against JIT-spraying attacks.
    "net.core.bpf_jit_harden" = 2;
    # Restrict ptrace to parent processes only. Use 2 to fully disallow for non-root.
    "kernel.yama.ptrace_scope" = 1;
    # Restrict access to performance events.
    "kernel.perf_event_paranoid" = 3;

    # ── Memory ───────────────────────────────────────────────────────────────

    # Full ASLR for mmap, stack, and VDSO.
    "kernel.randomize_va_space" = 2;
    # Maximise ASLR entropy for 64-bit and 32-bit compat mappings.
    "vm.mmap_rnd_bits"        = 32;
    "vm.mmap_rnd_compat_bits" = 16;

    # ── Filesystem ───────────────────────────────────────────────────────────

    # Prevent hardlink/symlink attacks in world-writable directories (e.g. /tmp).
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks"  = 1;
    # Prevent creating FIFOs or regular files in sticky dirs owned by others.
    "fs.protected_fifos"   = 2;
    "fs.protected_regular" = 2;
  };

  # Blacklist obsolete filesystems and unused network protocols — they're loaded
  # on-demand and would otherwise silently expand the kernel attack surface.
  boot.blacklistedKernelModules = [
    # Unused filesystems
    "cramfs" "freevxfs" "jffs2" "hfs" "hfsplus" "udf"
    # Rarely-used network protocols with a history of vulnerabilities
    "dccp" "sctp" "rds" "tipc"
  ];
}
