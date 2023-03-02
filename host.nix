args@{ pkgs, lib
  # import psk from out-of-git file
  # TODO: switch to secrets-manager and change to make it more secure
, bitcoind-signet-rpc-psk ? builtins.readFile ( "/etc/nixos/private/bitcoind-signet-rpc-psk.txt")
  # TODO: refactor to autogenerate HMAC from the password above
, bitcoind-signet-rpc-pskhmac ? builtins.readFile ( "/etc/nixos/private/bitcoind-signet-rpc-pskhmac.txt")
, op-energy-db-psk-signet ? builtins.readFile ( "/etc/nixos/private/op-energy-db-psk-signet.txt")
, op-energy-db-salt-signet ? builtins.readFile ( "/etc/nixos/private/op-energy-db-salt-signet.txt")
, bitcoind-mainnet-rpc-psk ? builtins.readFile ( "/etc/nixos/private/bitcoind-mainnet-rpc-psk.txt")
, op-energy-db-psk-mainnet ? builtins.readFile ( "/etc/nixos/private/op-energy-db-psk-mainnet.txt")
, op-energy-db-salt-mainnet ? builtins.readFile ( "/etc/nixos/private/op-energy-db-salt-mainnet.txt")
, mainnet_node_ssh_tunnel ? true # by default we want ssh tunnel to main node, but this is useless for github actions as they are using only signet node
, ...
}:

let
  sourceWithGit = pkgs.copyPathToStore ./overlays/op-energy;
  GIT_COMMIT_HASH = builtins.readFile ( # if git commit is empty, then try to get it from git
    pkgs.runCommand "get-rev1" {
      nativeBuildInputs = [ pkgs.git ];
    } ''
      HASH=$(GIT_DIR=${sourceWithGit}/.git git rev-parse --short HEAD | tr -d '\n' || echo 'NOT A GIT REPO')
      echo $HASH > $out
    ''
  );

in
{
  imports = [
    # module, which enables automatic update of the configuration from git
    ./auto-apply-config.nix
    # custom module for op-energy
    (./overlays/op-energy/nix/module.nix args // { GIT_COMMIT_HASH = GIT_COMMIT_HASH; })
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
  #          "BACKEND": "none",
  #          "HTTP_PORT": 8997,
  #          "API_URL_PREFIX": "/api/v1/",
  #          "POLL_RATE_MS": 2000
  #        },
  #        "CORE_RPC": {
  #          "USERNAME": "top-energy",
  #          "PASSWORD": "${bitcoind-testnet-rpc-psk}",
  #          "PORT": 18332
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
        block_spans_db_name = "${db}_block_spans";
      in {
      db_user = "sopenergy";
      db_name = db;
      account_db_name = "${db}acc";
      block_spans_db_name = block_spans_db_name;
      db_psk = op-energy-db-psk-signet;
      config = ''
        {
          "MEMPOOL": {
            "NETWORK": "signet",
            "BACKEND": "none",
            "HTTP_PORT": 8995,
            "API_URL_PREFIX": "/api/v1/",
            "INDEXING_BLOCKS_AMOUNT": 0,
            "BLOCKS_SUMMARIES_INDEXING": false,
            "POLL_RATE_MS": 2000
          },
          "CORE_RPC": {
            "USERNAME": "sop-energy",
            "PASSWORD": "${bitcoind-signet-rpc-psk}",
            "PORT": 38332
          },
          "DATABASE": {
            "ENABLED": true,
            "HOST": "127.0.0.1",
            "PORT": 3306,
            "DATABASE": "${db}",
            "ACCOUNT_DATABASE": "${db}acc",
            "OP_ENERGY_BLOCKCHAIN_DATABASE": "${block_spans_db_name}",
            "USERNAME": "sopenergy",
            "PASSWORD": "${op-energy-db-psk-signet}",
            "SECRET_SALT": "${op-energy-db-salt-signet}"
          },
          "STATISTICS": {
            "ENABLED": true,
            "TX_PER_SECOND_SAMPLE_PERIOD": 150
          }
        }
      '';
    };
  } // lib.mkIf mainnet_node_ssh_tunnel {
    mainnet =
      let
        db = "openergy";
        block_spans_db_name = "${db}_block_spans";
      in {
      db_user = "openergy";
      db_name = db;
      account_db_name = "${db}acc";
      block_spans_db_name = block_spans_db_name;
      db_psk = op-energy-db-psk-mainnet;
      config = ''
        {
          "MEMPOOL": {
            "NETWORK": "mainnet",
            "BACKEND": "none",
            "HTTP_PORT": 8999,
            "API_URL_PREFIX": "/api/v1/",
            "POLL_RATE_MS": 2000
          },
          "CORE_RPC": {
            "USERNAME": "op-energy",
            "PASSWORD": "${bitcoind-mainnet-rpc-psk}"
          },
          "DATABASE": {
            "ENABLED": true,
            "HOST": "127.0.0.1",
            "PORT": 3306,
            "DATABASE": "${db}",
            "ACCOUNT_DATABASE": "${db}acc",
            "OP_ENERGY_BLOCKCHAIN_DATABASE": "${block_spans_db_name}",
            "USERNAME": "openergy",
            "PASSWORD": "${op-energy-db-psk-mainnet}",
            "SECRET_SALT": "${op-energy-db-salt-mainnet}"
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
  systemd.services = lib.mkIf mainnet_node_ssh_tunnel {
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
