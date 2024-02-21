env@{
  GIT_COMMIT_HASH ? ""
, OP_ENERGY_REPO_LOCATION ? /etc/nixos/.git/modules/overlays/op-energy/modules/oe-blockspan-service
, OP_ENERGY_ACCOUNT_REPO_LOCATION ? /etc/nixos/.git/modules/overlays/op-energy
  # import psk from out-of-git file
, bitcoind-mainnet-rpc-psk ? builtins.readFile ( "/etc/nixos/private/bitcoind-mainnet-rpc-psk.txt")
, op-energy-db-psk-mainnet ? builtins.readFile ( "/etc/nixos/private/op-energy-db-psk-mainnet.txt")
, op-energy-db-salt-mainnet ? builtins.readFile ( "/etc/nixos/private/op-energy-db-salt-mainnet.txt")
, op-energy-account-token-encryption-key ? builtins.readFile ( "/etc/nixos/private/op-energy-account-token-encryption-key.txt")
, ...
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
in
{
  imports = [
    # custom module for op-energy
    opEnergyFrontendModule
    opEnergyBackendModule
    opEnergyAccountServiceModule
  ];
  system.stateVersion = "22.05";

  # op-energy part
  services.op-energy-backend = {
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

  # enable op-energy-frontend service
  services.op-energy-frontend = {
    enable = true;
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
    443 # ssl backed service
  ];

  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = true;
  networking.firewall.logRefusedConnections = false; # we are not interested in a logs of refused connections

}
