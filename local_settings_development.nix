env@{...}:
args@{ pkgs, lib, ...}:

{
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    screen
    atop # process monitor
    tcpdump # traffic sniffer
    iftop # network usage monitor
    git
  ];

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    22
    80
  ];

  # use zero tier instead of ssh vpn, which is slow
  services.zerotierone = {
    enable = true;
    joinNetworks = [
      "41d49af6c2442cb2" # administrated by dambaev
    ];
  };
  nixpkgs.config.allowUnfree = true; # for zerotier

  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = true;
  networking.firewall.logRefusedConnections = false; # we are not interested in a logs of refused connections

}
