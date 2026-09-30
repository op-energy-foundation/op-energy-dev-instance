env:
args@{ pkgs, lib, ...}:

let
  local_settings_production = import ./local_settings_production.nix env;
  local_settings_lnbits_instance = import ./local_settings_lnbits_instance.nix env;
in
{
  imports = [
    local_settings_production # this node is production
    local_settings_lnbits_instance
  ];

  system.stateVersion = "22.05";

}
