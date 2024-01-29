env@{
  GIT_COMMIT_HASH ? ""
, OP_ENERGY_REPO_LOCATION ? /etc/nixos/.git/modules/overlays/op-energy/modules/oe-blockspan-service
, OP_ENERGY_ACCOUNT_REPO_LOCATION ? /etc/nixos/.git/modules/overlays/op-energy
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
, op-energy-account-token-encryption-key ? builtins.readFile ( "/etc/nixos/private/op-energy-account-token-encryption-key.txt")
, mainnet_node_ssh_tunnel ? true # by default we want ssh tunnel to main node, but this is useless for github actions as they are using only signet node
}:
args@{ pkgs, lib, config, ...}:

let
  GIT_COMMIT_HASH = REPO_LOCATION: if builtins.hasAttr "GIT_COMMIT_HASH" env
    then env.GIT_COMMIT_HASH
    else
      let
        sourceWithGit = pkgs.copyPathToStore REPO_LOCATION;
      in
      builtins.readFile ( # if git commit is empty, then try to get it from git
      pkgs.runCommand "get-rev1" {
        nativeBuildInputs = [ pkgs.git ];
      } ''
        echo "OP_ENERGY_REPO_LOCATION = ${REPO_LOCATION}"
        HASH=$(cat ${sourceWithGit}/HEAD | cut -c 1-8 | tr -d '\n' || printf 'NOT A GIT REPO')
        printf $HASH > $out
      ''
    );
  opEnergyFrontendModule = import ./overlays/op-energy/oe-blockspan-service/frontend/module-frontend.nix { GIT_COMMIT_HASH = GIT_COMMIT_HASH OP_ENERGY_REPO_LOCATION; };
  opEnergyBackendModule = import ./overlays/op-energy/oe-blockspan-service/op-energy-backend/module-backend.nix { GIT_COMMIT_HASH = GIT_COMMIT_HASH OP_ENERGY_REPO_LOCATION; };
  opEnergyAccountServiceModule = import ./overlays/op-energy/oe-account-service/op-energy-account-service/module-backend.nix { GIT_COMMIT_HASH = GIT_COMMIT_HASH OP_ENERGY_ACCOUNT_REPO_LOCATION; };
  # calculate path to the local settings file
in
{
  imports = [
    # module, which enables automatic update of the configuration from git
    ./auto-apply-config.nix
    # custom module for op-energy
    opEnergyFrontendModule
    opEnergyBackendModule
    opEnergyAccountServiceModule
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
      in {
      db_user = "sopenergy";
      db_name = db;
      db_psk = op-energy-db-psk-signet;
      account_db_name = "${db}acc";
      config = ''
        {
          "DB_PORT": 5432,
          "DB_HOST": "127.0.0.1",
          "DB_USER": "${db}",
          "DB_NAME": "${db}",
          "DB_PASSWORD": "${op-energy-db-psk-signet}",
          "SECRET_SALT": "${op-energy-db-salt-signet}",
          "API_HTTP_PORT": 8995,
          "BTC_URL": "http://127.0.0.1:38332",
          "BTC_USER": "sop-energy",
          "BTC_PASSWORD": "${bitcoind-signet-rpc-psk}",
          "BTC_POLL_RATE_SECS": 10,
          "PROMETHEUS_PORT": 7995,
          "SCHEDULER_POLL_RATE_SECS": 10
        }
      '';
    };
  } // (if !mainnet_node_ssh_tunnel
    then {}
    else {
    mainnet =
      let
        db = "openergy";
      in {
      db_user = "openergy";
      db_name = db;
      db_psk = op-energy-db-psk-mainnet;
      account_db_name = "${db}acc";
      config = ''
        {
          "DB_PORT": 5432,
          "DB_HOST": "127.0.0.1",
          "DB_USER": "${db}",
          "DB_NAME": "${db}",
          "DB_PASSWORD": "${op-energy-db-psk-mainnet}",
          "SECRET_SALT": "${op-energy-db-salt-mainnet}",
          "API_HTTP_PORT": 8999,
          "BTC_URL": "http://127.0.0.1:8332",
          "BTC_USER": "op-energy",
          "BTC_PASSWORD": "${bitcoind-mainnet-rpc-psk}",
          "BTC_POLL_RATE_SECS": 10,
          "PROMETHEUS_PORT": 7999,
          "SCHEDULER_POLL_RATE_SECS": 10
        }
      '';
    };
  });
  # enable op-energy-frontend service
  services.op-energy-frontend = {
    enable = true;
    signet_enabled = true;
  };
  services.op-energy-account-service = {
    enable = true;
    db_name = "openergyacc";
    db_user = "openergy";
    db_psk = op-energy-db-psk-mainnet;
    config = ''
      {
        "DB_PORT": 5432,
        "DB_HOST": "127.0.0.1",
        "DB_USER": "openergy",
        "DB_NAME": "openergyacc",
        "DB_PASSWORD": "${op-energy-db-psk-mainnet}",
        "SECRET_SALT": "${op-energy-db-salt-mainnet}",
        "ACCOUNT_TOKEN_ENCRYPTION_PRIVATE_KEY": "${op-energy-account-token-encryption-key}",
        "API_HTTP_PORT": 8899,
        "PROMETHEUS_PORT": 7899,
        "LOG_LEVEL_MIN": "Debug",
        "SCHEDULER_POLL_RATE_SECS": 10
      }
    '';
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
  systemd.services = if !mainnet_node_ssh_tunnel
    then {}
    else {
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
