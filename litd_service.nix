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

  };

  config = lib.mkIf cfg.enable {

    environment.systemPackages = with pkgs;
      [ lightning-terminal
      ];
    systemd.services.litd = {
      script = ''
       litd \
         --httpslisten=0.0.0.0:8443 \
         --uipassword=${litd_ui_password} \
         --network=signet \
         --lnd-mode=integrated \
         --lnd.lnddir=/root/.lnd \
         --lnd.alias=merchant \
         --lnd.externalip=${config.services.nginx.virtualHosts.op-energy-mvp.serverName} \
         --lnd.rpclisten=127.0.0.1:10009 \
         --lnd.listen=127.0.0.1:9735 \
         --lnd.bitcoin.node=bitcoind \
         --lnd.bitcoind.rpchost=localhost \
         --lnd.bitcoind.rpcuser=sop-energy \
         --lnd.bitcoind.rpcpass=${bitcoind-signet-rpc-psk} \
         --lnd.bitcoind.zmqpubrawblock=localhost:28332 \
         --lnd.bitcoind.zmqpubrawtx=localhost:28333 \
         --lnd.debuglevel=debug \
         --loop.loopoutmaxparts=5 \
         --faraday.min_monitored=48h \
         --faraday.connect_bitcoin \
         --faraday.bitcoin.host=localhost \
         --faraday.bitcoin.user=sop-energy \
         --faraday.bitcoin.password=${bitcoind-signet-rpc-psk}
      '';
    };
  };

}
