env@{
  bitcoind-mainnet-rpc-psk ? builtins.readFile ( "/etc/nixos/private/bitcoind-mainnet-rpc-psk.txt")
, bitcoind-mainnet-rpc-pskhmac ? builtins.readFile ( "/etc/nixos/private/bitcoind-mainnet-rpc-pskhmac.txt")
, op-energy-db-psk-mainnet ? builtins.readFile ( "/etc/nixos/private/op-energy-db-psk-mainnet.txt")
, op-energy-db-salt-mainnet ? builtins.readFile ( "/etc/nixos/private/op-energy-db-salt-mainnet.txt")
, ...
}:
args@{ pkgs, lib, ...}:

let
in
{
  imports = [
    # module, which enables automatic update of the configuration from git
    ./auto-apply-config.nix
  ];
  system.stateVersion = "22.05";

  # bitcoind mainnet instance
  services.bitcoind.mainnet = {
    enable = true;
    dataDir = "/mnt/bitcoind-mainnet";
    extraConfig = ''
      txindex = 1
      server=1
      listen=1
      discover=1
    '';
    rpc.users = {
      op-energy = {
        name = "op-energy";
        passwordHMAC = "${bitcoind-mainnet-rpc-pskhmac}";
      };
    };
  };


}
