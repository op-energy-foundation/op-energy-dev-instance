args@{ pkgs, lib, ...}:
let
  hostname = import ./local_hostname.nix;
  host_local_settings = ./. + "/local_settings_${hostname}.nix";
  hostModule = import host_local_settings {};
in
{
  imports = [
    hostModule # import per instance local settings
  ];
  networking.hostName = hostname;
}
