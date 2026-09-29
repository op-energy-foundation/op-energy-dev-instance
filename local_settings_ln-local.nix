# Local host for developing against the Lightning stack: the production service set plus litd and
# LNbits on a regtest chain, so nothing has to sync. Shared hosts run the same modules on signet.
env@{
  bitcoind-regtest-rpc-pskhmac ? builtins.readFile ( "/etc/nixos/private/bitcoind-regtest-rpc-pskhmac.txt")
, ...
}:
args@{ pkgs, lib, ...}:

let
  local_settings_production = import ./local_settings_production.nix env;
in
{
  imports = [
    local_settings_production
  ];

  system.stateVersion = "22.05";

  services.bitcoind.regtest = {
    enable = true;
    rpc.port = 18443;
    rpc.users.op-energy = {
      name = "op-energy";
      passwordHMAC = bitcoind-regtest-rpc-pskhmac;
    };
    extraConfig = ''
      regtest=1
      server=1
      txindex=1
      [regtest]
      rpcbind=127.0.0.1
      zmqpubrawblock=tcp://127.0.0.1:28332
      zmqpubrawtx=tcp://127.0.0.1:28333
      fallbackfee=0.0002
    '';
  };

  services.litd = {
    enable = true;
    network = "regtest";
    noSeedBackup = true;
    groupReadableCredentials = true;
    uiPasswordFile = "/etc/nixos/private/litd-ui-password.txt";
    requires = [ "bitcoind-regtest.service" ];
    bitcoind = {
      rpcPort = 18443;
      rpcPasswordFile = "/etc/nixos/private/bitcoind-regtest-rpc-psk.txt";
    };
  };

  services.lnbits = {
    enable = true;
    firstInstallTokenFile = "/etc/nixos/private/lnbits-first-install-token.txt";
    # The backend receives payment webhooks on loopback; upstream's default rules only accept
    # public domains.
    extraEnv = {
      LNBITS_CALLBACK_URL_RULES = builtins.toJSON [ "http://127\\.0\\.0\\.1(:\\d+)?" ];
      LNBITS_CALLBACK_ALLOW_PRIVATE_IPS = "true";
    };
  };
}
