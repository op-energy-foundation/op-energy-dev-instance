env@{
  litd_ui_password ? builtins.readFile ( "/etc/nixos/private/litd_ui_password.txt")
, bitcoind-signet-rpc-psk
, ...
}:
args@{ pkgs, lib, config, ...}:

let
  cfg = config.services.litd_terminal_service;
in
{
  options.services.litd_terminal_service = {
    enable = lib.mkEnableOption "litd_terminal service";

    http_port = lib.mkOption {
      type = lib.types.int;
      example = 7000;
      default = 7000;
      description = ''
        defines port for litd
      '';
    };

    lnd_port = lib.mkOption {
      type = lib.types.int;
      example = 9735;
      default = 9735;
      description = ''
        defines LND port
      '';
    };

    lnd_rpc_port = lib.mkOption {
      type = lib.types.int;
      example = 10009;
      default = 10009;
      description = ''
        defines LND rpc port
      '';
    };

  };

  config = lib.mkIf cfg.enable {

    environment.systemPackages = with pkgs;
      [ lightning-terminal
      ];
    systemd.services.litd = {
      wantedBy = [ "multi-user.target" ];
      after = [ "postgresql.service" ];
      requires = [ "postgresql.service" ];
      serviceConfig = {
        Type = "simple";
        LoadCredential =
          [ "litd_ui_password:/etc/nixos/private/litd_ui_password.pass"
            "bitcoind-signet-rpc-psk:/etc/nixos/private/bitcoind-signet-rpc-psk.pass"
          ];
      };
      path = with pkgs; [
        lightning-terminal postgresql systemd
      ];

      script = ''
       set -x
       env | grep CREDENTIALS_DIRECTORY
       echo $(cat $CREDENTIALS_DIRECTORY/litd_ui_password)
       systemd-creds decrypt $CREDENTIALS_DIRECTORY/litd_ui_password -
       litd \
         --insecure-httplisten=127.0.0.1:${toString cfg.http_port} \
         --uipassword=$(systemd-creds decrypt --name=litd_ui_password $CREDENTIALS_DIRECTORY/litd_ui_password -) \
         --network=signet \
         --lnd-mode=integrated \
         --lnd.lnddir=/root/.lnd \
         --lnd.alias=merchant \
         --lnd.externalip=${config.services.nginx.virtualHosts.op-energy-mvp.serverName} \
         --lnd.rpclisten=127.0.0.1:${toString cfg.lnd_rpc_port} \
         --lnd.listen=127.0.0.1:${toString cfg.lnd_port} \
         --lnd.bitcoin.node=bitcoind \
         --lnd.bitcoind.rpchost=localhost \
         --lnd.bitcoind.rpcuser=sop-energy \
         --lnd.bitcoind.rpcpass=$(cat $CREDENTIALS_DIRECTORY/bitcoind-signet-rpc-psk) \
         --lnd.bitcoind.zmqpubrawblock=localhost:28332 \
         --lnd.bitcoind.zmqpubrawtx=localhost:28333 \
         --lnd.debuglevel=debug \
         --loop.loopoutmaxparts=5 \
         --faraday.min_monitored=48h \
         --faraday.connect_bitcoin \
         --faraday.bitcoin.host=localhost \
         --faraday.bitcoin.user=sop-energy \
         --faraday.bitcoin.password=$(cat $CREDENTIALS_DIRECTORY/bitcoind-signet-rpc-psk)
      '';
    };
  };

}
