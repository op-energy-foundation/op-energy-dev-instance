{pkgs, lib, ...}:
let
  # import psk from out-of-git file
  # TODO: switch to secrets-manager and change to make it more secure
  bitcoind-signet-rpc-psk = builtins.readFile ( "/etc/nixos/private/bitcoind-signet-rpc-psk.txt");
  # TODO: refactor to autogenerate HMAC from the password above
  bitcoind-signet-rpc-pskhmac = builtins.readFile ( "/etc/nixos/private/bitcoind-signet-rpc-pskhmac.txt");
  op-energy-db-psk-signet = builtins.readFile ( "/etc/nixos/private/op-energy-db-psk-signet.txt");
in
{
  imports = [
    # module, which enables automatic update of the configuration from git
    ./auto-apply-config.nix
    # custom module for already existing electrs derivation
    ./overlays/electrs-overlay/module.nix
    # custom module for op-energy
    ./overlays/op-energy/nix/module.nix
  ];
  system.stateVersion = "22.05";
  # op-energy part
  services.op-energy-backend = {
  # keeping testnet commented to have testnet ports in quick access
  #  testnet = {
  #    db_user = "topenergy";
  #    db_name = "topenergy";
  #    db_psk = op-energy-db-psk-testnet;
  #    config = ''
  #      {
  #        "MEMPOOL": {
  #          "NETWORK": "testnet",
  #          "BACKEND": "electrum",
  #          "HTTP_PORT": 8997,
  #          "API_URL_PREFIX": "/api/v1/",
  #          "POLL_RATE_MS": 2000
  #        },
  #        "CORE_RPC": {
  #          "USERNAME": "top-energy",
  #          "PASSWORD": "${bitcoind-testnet-rpc-psk}",
  #          "PORT": 18332
  #        },
  #        "ELECTRUM": {
  #          "HOST": "127.0.0.1",
  #          "PORT": 60001,
  #          "TLS_ENABLED": false
  #        },
  #        "DATABASE": {
  #          "ENABLED": true,
  #          "HOST": "127.0.0.1",
  #          "PORT": 3306,
  #          "DATABASE": "topenergy",
  #          "ACCOUNT_DATABASE": "topenergyacc",
  #          "USERNAME": "topenergy",
  #          "PASSWORD": "${op-energy-db-psk-testnet}"
  #        },
  #        "STATISTICS": {
  #          "ENABLED": true,
  #          "TX_PER_SECOND_SAMPLE_PERIOD": 150
  #        }
  #      }
  #    '';
  #  };
    signet =
      let
        db = "sopenergy";
      in {
      db_user = "sopenergy";
      db_name = db;
      account_db_name = "${db}acc";
      db_psk = op-energy-db-psk-signet;
      config = ''
        {
          "MEMPOOL": {
            "NETWORK": "signet",
            "BACKEND": "electrum",
            "HTTP_PORT": 8995,
            "API_URL_PREFIX": "/api/v1/",
            "POLL_RATE_MS": 2000
          },
          "CORE_RPC": {
            "USERNAME": "sop-energy",
            "PASSWORD": "${bitcoind-signet-rpc-psk}",
            "PORT": 38332
          },
          "ELECTRUM": {
            "HOST": "127.0.0.1",
            "PORT": 60601,
            "TLS_ENABLED": false
          },
          "DATABASE": {
            "ENABLED": true,
            "HOST": "127.0.0.1",
            "PORT": 3306,
            "DATABASE": "${db}",
            "ACCOUNT_DATABASE": "${db}acc",
            "USERNAME": "sopenergy",
            "PASSWORD": "${op-energy-db-psk-signet}"
          },
          "STATISTICS": {
            "ENABLED": true,
            "TX_PER_SECOND_SAMPLE_PERIOD": 150
          }
        }
      '';
    };
  };
  # enable op-energy-frontend service
  services.op-energy-frontend = {
    enable = true;
    signet_enabled = true;
  };

  # enable electrs service
  services.electrs = {
    signet = { # signet instance
      db_dir = "/mnt/electrs-signet";
      cookie_file = "/mnt/bitcoind-signet/signet/.cookie";
      blocks_dir = "/mnt/bitcoind-signet/signet/blocks";
      network = "signet";
      rpc_listen = "127.0.0.1:60601";
      daemon_rpc_addr = "127.0.0.1:38332";
    };
  };

  # bitcoind signet instance
  services.bitcoind.signet = {
    enable = true;
    dataDir = "/mnt/bitcoind-signet";
    extraConfig = ''
      txindex = 1
      server=1
      listen=1
      discover=1
      rpcallowip=127.0.0.1
      # those option affects memory footprint of the instance, so changing the default value
      # will affect the ability to shrink the node's resources.
      # default value is 450 MiB
      # dbcache=3700
      # default value is 125, affects RAM occupation
      # maxconnections=1337
      signet = 1
      [signet]
    '';
    rpc.users = {
      sop-energy = {
        name = "sop-energy";
        passwordHMAC = "${bitcoind-signet-rpc-pskhmac}";
      };
    };
  };

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
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = true;
  networking.firewall.logRefusedConnections = false; # we are not interested in a logs of refused connections
}
