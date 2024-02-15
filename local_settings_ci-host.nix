env:
args@{ pkgs, lib, ...}:

let
  local_settings_production = import ./local_settings_production.nix env;
in
{
  imports = [
    local_settings_production # this node is production
  ];

  system.stateVersion = "22.05";

}
