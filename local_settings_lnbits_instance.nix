env@{
  bitcoind-signet-rpc-pskhmac ? builtins.readFile ( "/etc/nixos/private/bitcoind-signet-rpc-pskhmac.txt")
, bitcoind-signet-rpc-psk ? builtins.readFile ( "/etc/nixos/private/bitcoind-signet-rpc-psk.txt")
, litd_ui_password ? builtins.readFile ( "/etc/nixos/private/litd_ui_password.txt")
, ...
}:
args@{
  config
, ...
}:

let
  lnbitsFlake = builtins.getFlake "github:lnbits/lnbits";
in
{
  imports = [
    "${lnbitsFlake}/nix/modules/lnbits-service.nix"
    ./litd_service.nix
  ];
  services.bitcoind = {
    signet = {
      enable = true;
      extraCmdlineOptions = [ "-signet" ];
      extraConfig = ''
        [signet]
        txindex = 1
        server=1
        listen=1
        discover=1
        rpcallowip=127.0.0.1/32
        rpcbind=127.0.0.1
      '';
      rpc.users = {
        op-energy = {
          name = "sop-energy";
          passwordHMAC = "${bitcoind-signet-rpc-pskhmac}";
        };
      };
    };
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  services.lnbits = {
    enable = true;
    host = "127.0.0.1";        # Listen on all interfaces
    port = 5000;             # Default port
    openFirewall = false;

    # Use package from the same flake (adjust system architecture as needed)
    package = lnbitsFlake.packages.x86_64-linux.lnbits;

    env = {
      LNBITS_ADMIN_UI = "true";
      # Configure your Lightning backend:
      # LNBITS_BACKEND_WALLET_CLASS = "LndRestWallet";
      # LND_REST_ENDPOINT = "https://localhost:8080";
      # LND_REST_CERT = "/path/to/tls.cert";
      # LND_REST_MACAROON = "/path/to/admin.macaroon";
    };
  };
  services.litd_terminal_service = {
    enable = true;
    bitcoin_network = "signet";
    bitcoin_user = "sop-energy";
    bitcoin_pass = bitcoind-signet-rpc-psk;
    lnd_external_ip = config.services.nginx.virtualHosts.op-energy-mvp.serverName;
    litd_ui_password = litd_ui_password;
  };
}
