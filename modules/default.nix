# modules/default.nix
#
# Purpose  : Top-level aggregator — imports all nerv module subtrees.
# Modules  : modules/system (system-level config), modules/services (service config),
#            home (Home Manager wiring)
# Note     : ../home resolves to <repo-root>/home relative to this file's location.
{ imports = [ ./system ./services ../home ]; }
