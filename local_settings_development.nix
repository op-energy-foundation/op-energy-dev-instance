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
  systemd.services = {
    node_tunnel = { # we use tunnel to production instance in order to reuse connection to mainnet node. This service's goal is just to keep tunnel alive all the time
      wantedBy = [ "multi-user.target" ];
      before = [ "op-energy-backend-mainnet.service" ];
      after = [
        "network-online.target"
      ];
      requires = [
        "network-online.target"
      ];
      serviceConfig = {
        Type = "simple";
        Restart = "always"; # we want to keep service always running
        StartLimitIntervalSec = 0;
        StartLimitBurst = 0;
      };
      path = with pkgs; [
        socat
      ];
      script = ''
        socat TCP4-LISTEN:8332,bind=127.0.0.1,fork,reuseaddr TCP4:10.243.0.1:8332
      '';
    };
  };

  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = true;
  networking.firewall.logRefusedConnections = false; # we are not interested in a logs of refused connections

}
