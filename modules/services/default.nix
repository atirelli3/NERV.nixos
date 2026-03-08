# modules/services/default.nix
#
# Purpose  : Aggregates all nerv service modules.
# Modules  : openssh, pipewire, bluetooth, printing, zsh
# Note     : All modules are disabled by default. Enable via nerv.<module>.enable.
{ imports = [
    ./openssh.nix
    ./pipewire.nix
    ./bluetooth.nix
    ./printing.nix
    ./zsh.nix
  ];
}
