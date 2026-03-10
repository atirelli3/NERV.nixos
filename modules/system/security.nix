# modules/system/security.nix
#
# Security hardening — AppArmor, auditd, ClamAV, and AIDE. Always-on, fully opaque.
{ config, lib, pkgs, ... }:

{
  # Prevent writing to the kernel image at runtime (blocks /dev/mem abuse).
  security.protectKernelImage = true;
  # Enforce Page Table Isolation regardless of CPU vulnerability status.
  security.forcePageTableIsolation = true;

  # Only wheel-group members may run sudo, and only via the setuid wrapper.
  security.sudo.execWheelOnly = true;

  # Mandatory Access Control via AppArmor.
  # Many packages ship profiles automatically; confinement is opt-in by default.
  # Set killUnconfinedConfinables = true for strict mode (may break some apps).
  security.apparmor.enable = true;

  # System call auditing — logs to /var/log/audit/audit.log.
  security.auditd.enable = true;
  security.audit = {
    enable = true;
    rules = [
      # Process and file activity
      "-a exit,always -F arch=b64 -S execve"            # all process executions
      "-a exit,always -F arch=b64 -S openat"            # all file opens
      "-a exit,always -F arch=b64 -S connect"           # outbound network connections
      # Privilege escalation attempts
      "-a exit,always -F arch=b64 -S setuid -S setgid"  # UID/GID changes
      # Critical file modifications
      "-w /etc/passwd -p wa"                             # user database
      "-w /etc/shadow -p wa"                             # password hashes
      "-w /etc/sudoers -p wa"                            # sudo rules
      "-w /etc/ssh/sshd_config -p wa"                   # SSH daemon config
    ];
  };

  # ClamAV antivirus via the NixOS module (handles user, socket, and paths correctly).
  services.clamav = {
    daemon.enable  = true;  # clamd: real-time scanning daemon
    updater.enable = true;  # freshclam: keeps virus definitions current
    updater.frequency = 24; # definition update checks per day
  };

  # Security auditing.
  #   lynis — system hardening auditor; run with: sudo lynis audit system
  #   aide  — file integrity monitor; detects unauthorised changes to binaries
  #           and configs (the primary indicator of rootkit activity on NixOS).
  #           Initialise the database manually after first boot:
  #             sudo aide --init && sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
  environment.systemPackages = with pkgs; [
    lynis
    aide
  ];

  # AIDE configuration — monitor critical system paths, skip the Nix store
  # (it changes on every rebuild and would generate excessive noise).
  environment.etc."aide.conf".text = ''
    database_in=file:/var/lib/aide/aide.db
    database_out=file:/var/lib/aide/aide.db.new
    database_new=file:/var/lib/aide/aide.db.new
    gzip_dbout=yes

    # Rules: p=permissions, i=inode, n=nlinks, u=uid, g=gid,
    #        s=size, b=blocks, m=mtime, c=ctime, sha256/sha512=hashes
    PERMS     = p+i+u+g
    CONTENT   = sha256+sha512
    FULL      = PERMS+n+s+b+m+c+CONTENT

    # Paths to monitor
    /boot       FULL
    /etc        FULL
    /bin        FULL
    /sbin       FULL
    /usr/bin    FULL
    /usr/sbin   FULL
    /lib        FULL
    /usr/lib    FULL

    # Exclude volatile paths
    !/var/log
    !/var/lib/aide
    !/proc
    !/sys
    !/dev
    !/run
    !/nix
    !/tmp
  '';

  # Ensure the AIDE state directory exists.
  systemd.tmpfiles.rules = [
    "d /var/lib/aide 0700 root root -"
  ];

  # Daily integrity check — results go to the journal (journalctl -u aide-check).
  # The service exits non-zero if changes are found; that is expected behaviour.
  systemd.services.aide-check = {
    description = "AIDE file integrity check";
    serviceConfig = {
      Type            = "oneshot";
      ExecStart       = "${pkgs.aide}/bin/aide --check --config /etc/aide.conf";
      User            = "root";
      SuccessExitStatus = [ 0 1 ]; # exit 1 means changes detected, not a unit failure
    };
  };

  systemd.timers.aide-check = {
    description = "Daily AIDE file integrity check";
    wantedBy    = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
