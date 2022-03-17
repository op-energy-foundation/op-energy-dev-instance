{pkgs, lib, ...}:
{
  containers.build = {
    imports = [
      ./host.nix
    ];
    privateNetwork = true;
    hostAddress = "192.168.100.16";
    localAddress = "192.168.100.17";
    networking.nameservers = [ "8.8.8.8" "8.8.4.4" ];
    nixpkgs.config.allowUnfree = true;
    environment.systemPackages = with pkgs; [
      wget vim
    ];
  };
}
