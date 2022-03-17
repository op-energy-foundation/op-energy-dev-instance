{pkgs, lib, ...}:
{
  containers.build = {
    privateNetwork = true;
    hostAddress = "192.168.100.16";
    localAddress = "192.168.100.17";
    config = {
      imports = [
        ./host.nix
      ];
      networking.nameservers = [ "8.8.8.8" "8.8.4.4" ];
      nixpkgs.config.allowUnfree = true;
      environment.systemPackages = with pkgs; [
        wget vim
      ];
    };
  };
}
