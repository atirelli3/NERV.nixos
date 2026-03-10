# Service: Printing

**File:** `modules/services/printing.nix`

CUPS printing with Avahi/mDNS network printer discovery. Disabled by default.

---

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.printing.enable` | `bool` | `false` | Enable CUPS printing with Avahi network discovery. |

---

## What it enables

| Feature | Details |
|---------|---------|
| CUPS daemon | `services.printing.enable = true` |
| Default drivers | `services.printing.drivers = [ pkgs.gutenprint ]` |
| Avahi/mDNS | `services.avahi.enable = true`, `services.avahi.nssmdns4 = true` |
| Network discovery | Printers on the local network are auto-discovered via mDNS |

---

## Example

```nix
nerv.printing.enable = true;
```

---

## Adding printer drivers

Override the drivers list in `hosts/configuration.nix`:

```nix
{ pkgs, lib, ... }: {
  services.printing.drivers = lib.mkForce [
    pkgs.gutenprint
    pkgs.gutenprintBin
    pkgs.hplip          # HP printers
    pkgs.brlaser        # Brother laser printers
    pkgs.cnijfilter2    # Canon inkjet printers
  ];
}
```

---

## Usage

```bash
# Open CUPS web interface
xdg-open http://localhost:631

# Add a printer via command line
lpadmin -p MyPrinter -E -v ipp://192.168.1.50/ipp/print -m everywhere

# List available printers
lpstat -p -d

# Print a file
lp -d MyPrinter /path/to/file.pdf

# Check CUPS status
systemctl status cups
```

---

## Notes

- Enabling Printing also enables `services.avahi`. This is shared with the Bluetooth module — enabling either implies Avahi is on.
- `nssmdns4 = true` enables mDNS hostname resolution (`.local` domains) via NSS, which is required for AirPrint discovery.
