# NixOS Stateless Disk Layout Refactor

**Automation-Friendly Refactor Plan for Claude Code**

Goal: refactor the current NixOS disk layout to implement a **stateless system design using impermanence**.

Two target architectures must be supported:

* **Desktop systems → BTRFS + impermanence (snapshot rollback)**
* **Server systems → tmpfs root + impermanence**

Reference designs:

* https://www.willbush.dev/blog/impermanent-nixos/
* https://xeiaso.net/blog/paranoid-nixos-2021-07-18/

This document is designed for automated execution by Claude Code using a **get-shit-done workflow**.

---

# 1. Objectives

Refactor the system to achieve:

* Stateless root filesystem
* Explicit persistence declaration
* Reproducible system state
* Minimal configuration drift
* Easy rollback
* Security-friendly environments

Principle:

```
System state = NixOS configuration + explicitly persisted data
```

Everything else is disposable.

---

# 2. Architecture Overview

## Desktop (Workstation)

```
BTRFS + impermanence
```

Features:

* root filesystem reset at boot via snapshot rollback
* persistent nix store
* persistent home
* persistent state stored in `/persist`

Suitable for:

* development
* VM workloads
* container workloads
* security research environments

---

## Server

```
tmpfs root + impermanence
```

Features:

* root filesystem entirely in RAM
* persistent disk storage only for required state
* extremely clean runtime environment

Suitable for:

* infrastructure nodes
* ephemeral workloads
* reproducible servers

---

# 3. Desktop Disk Layout (BTRFS)

Single BTRFS partition with subvolumes.

Example:

```
/dev/nvme0n1p2
└─ btrfs
   ├─ @
   ├─ @root-blank
   ├─ @home
   ├─ @nix
   ├─ @persist
   └─ @log (optional)
```

Subvolume purposes:

| Subvolume   | Purpose                          |
| ----------- | -------------------------------- |
| @           | active root filesystem           |
| @root-blank | pristine snapshot used for reset |
| @home       | user data                        |
| @nix        | nix store                        |
| @persist    | persisted system state           |
| @log        | persistent logs                  |

---

# 4. Desktop Runtime Mount Layout

```
/        -> subvol=@
/home    -> subvol=@home
/nix     -> subvol=@nix
/persist -> subvol=@persist
/var/log -> subvol=@log
```

Root is disposable.

Persistent data lives in dedicated subvolumes.

---

# 5. Desktop Rollback Mechanism

At boot the root filesystem must be reset.

Initrd procedure:

```
mount btrfs root
delete current root subvolume
restore snapshot from @root-blank
continue boot
```

Pseudo implementation:

```
btrfs subvolume delete /btrfs/@
btrfs subvolume snapshot /btrfs/@root-blank /btrfs/@
```

Effect:

Every reboot starts from a clean root filesystem.

---

# 6. Impermanence Persistence

Persistent root:

```
/persist
```

Example persistence declaration:

```
environment.persistence."/persist" = {
  directories = [
    "/etc/nixos"
    "/var/lib"
    "/var/log"
  ];

  files = [
    "/etc/machine-id"
  ];
};
```

Bind mount mapping:

```
/persist/etc/nixos → /etc/nixos
```

This preserves required system state.

---

# 7. Desktop Persistent Data

Minimum required persistence:

```
/persist/etc/nixos
/persist/var/lib
/persist/var/log
/persist/etc/machine-id
```

Also persistent via subvolumes:

```
/home
/nix
```

---

# 8. Server Disk Layout

Example:

```
/dev/sda

sda1 -> /boot
sda2 -> persistent storage
```

Persistent filesystem:

```
/nix
/persist
```

Root filesystem:

```
tmpfs
```

---

# 9. Server Runtime Layout

```
RAM
└─ /

DISK
├─ /boot
├─ /nix
└─ /persist
```

Everything under `/` disappears at reboot.

---

# 10. tmpfs Root Configuration

Example:

```
fileSystems."/" = {
  device = "none";
  fsType = "tmpfs";
  options = [
    "size=4G"
    "mode=755"
  ];
};
```

This prevents RAM exhaustion.

---

# 11. Server Persistence

Example:

```
environment.persistence."/persist" = {
  directories = [
    "/etc/nixos"
    "/var/lib"
  ];

  files = [
    "/etc/machine-id"
  ];
};
```

---

# 12. Claude Code Refactor Tasks

## Task 1 — Detect Environment Type

Determine system role:

```
desktop
server
```

Based on:

* hostname
* configuration profile
* hardware detection

---

## Task 2 — Install Impermanence Module

Add dependency:

```
https://github.com/nix-community/impermanence
```

Flake input example:

```
inputs.impermanence.url = "github:nix-community/impermanence";
```

Import module.

---

## Task 3 — Desktop BTRFS Preparation

If system is desktop:

1. Verify filesystem is BTRFS
2. If not → migrate disk layout
3. Create subvolumes

Commands:

```
btrfs subvolume create @
btrfs subvolume create @root-blank
btrfs subvolume create @home
btrfs subvolume create @nix
btrfs subvolume create @persist
btrfs subvolume create @log
```

---

## Task 4 — Create Root Snapshot

Create baseline snapshot:

```
btrfs subvolume snapshot @ @root-blank
```

This becomes the clean root.

---

## Task 5 — Configure NixOS Mounts

Add to configuration:

```
fileSystems."/" = {
  device = "/dev/nvme0n1p2";
  fsType = "btrfs";
  options = [ "subvol=@" "compress=zstd" ];
};
```

Additional mounts:

```
/home
/nix
/persist
```

---

## Task 6 — Implement Boot Rollback

Add initrd script performing:

```
mount btrfs root
delete subvolume @
snapshot @root-blank → @
```

Ensure this occurs **before root mount**.

---

## Task 7 — Add Persistence Rules

Add persistence configuration:

```
environment.persistence."/persist"
```

Define directories and files.

---

## Task 8 — Server Implementation

For server systems:

1. configure tmpfs root
2. keep persistent storage for:

```
/nix
/persist
```

3. apply impermanence module.

---

# 13. Safety Checks

Before applying refactor verify:

```
backup exists
disk device confirmed
filesystem type validated
```

Abort if conditions are unsafe.

---

# 14. Post-Migration Validation

After reboot verify:

```
root filesystem reset
home persists
nix store persists
persist directory works
machine-id stable
services start correctly
```

Test procedure:

```
touch /testfile
reboot
verify file removed
```

---

# 15. Failure Recovery

If system fails to boot:

1. boot into live ISO
2. mount BTRFS partition
3. restore root snapshot manually

Example:

```
btrfs subvolume delete @
btrfs subvolume snapshot @root-blank @
```

---

# 16. Expected Final System State

Desktop:

```
btrfs rollback root
persistent nix store
persistent home
impermanence persistence layer
```

Server:

```
tmpfs root
persistent nix store
impermanence persistence layer
```

Both systems become **stateless OS with explicit persistence**.

---

# End of Refactor Specification
