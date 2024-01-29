args@{ pkgs, lib, ...}:
let
  hostname = import ./local_hostname.nix;
  host_local_settings = ./. + "/local_settings_${hostname}.nix";
in
{
  imports = [
    host_local_settings # import per instance local settings
  ];
  networking.hostName = hostname;
}