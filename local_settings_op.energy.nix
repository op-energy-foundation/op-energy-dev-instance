args@{ pkgs, lib, ...}:

let
in
{
  imports = [
    ./local_settings_production.nix # this node is production
  ];

  system.stateVersion = "22.05";

}