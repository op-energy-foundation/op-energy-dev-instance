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

  systemd.services = {
    ssh_tunnel = { # we use ssh tunnel to production instance in order to reuse connection to mainnet node. This service's goal is just to keep ssh tunnel alive all the time
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
        openssh
      ];
      script = ''
        ssh proxy@exchange.op-energy.info -L8332:127.0.0.1:8332 -oServerAliveInterval=60 -n "while true; do sleep 10s; done"
      '';
    };
  };

  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = true;
  networking.firewall.logRefusedConnections = false; # we are not interested in a logs of refused connections

}