args@{ pkgs, lib, config, ...}:

let
  cfg = config.services.litd_terminal_service;
in
{
  options.services.litd_terminal_service = {
    enable = lib.mkEnableOption "litd_terminal service";

    insecure-httplisten = lib.mkOption {
      type = lib.types.str;
      example = "localhost:7000";
      default = "localhost:7000";
      description = ''
        defines http listen for litd
      '';
    };

    litd_ui_password = lib.mkOption {
      type = lib.types.str;
      example = "pwd";
      description = ''
        defines LND UI password
      '';
    };

    lnd_host_port = lib.mkOption {
      type = lib.types.str;
      example = "localhost:9735";
      default = "localhost:9735";
      description = ''
        defines LND host:port
      '';
    };

    lnd_rpc_host_port = lib.mkOption {
      type = lib.types.str;
      example = "localhost:10009";
      default = "localhost:10009";
      description = ''
        defines LND rpc host:port
      '';
    };

    bitcoin_network = lib.mkOption {
      type = lib.types.str;
      example = "mainnet";
      default = "signet";
      description = ''
        defines bitcoin network to connect to
      '';
    };

    bitcoin_host = lib.mkOption {
      type = lib.types.str;
      example = "localhost";
      default = "localhost";
      description = ''
        defines bitcoind host to connect to
      '';
    };

    bitcoin_user = lib.mkOption {
      type = lib.types.str;
      example = "op-energy";
      default = "op-energy";
      description = ''
        defines bitcoind user name to connect to bitcoin node with
      '';
    };

    bitcoin_pass = lib.mkOption {
      type = lib.types.str;
      example = "pwd";
      description = ''
        defines bitcoind user's password to connect to bitcoin node with
      '';
    };

    lnd_external_ip = lib.mkOption {
      type = lib.types.str;
      example = "2.2.2.2";
      description = ''
        defines external host name / IP to which user connecting to access lnd
      '';
    };

  };

  config = lib.mkIf cfg.enable {

    users.users.litd = {
      isNormalUser = true;
      group = "litd";
      createHome = true;
    };
    users.groups.litd = { };
    environment.etc."lit/lit.conf" = {
      mode = "0600";
      text = ''
        # Application Options
        insecure-httplisten=${cfg.insecure-httplisten}
        uipassword=${cfg.litd_ui_password}
        #httpslisten=0.0.0.0:8443
        #tlscertpath=~/.lit/tls.cert
        #tlskeypath=~/.lit/tls.key
        #letsencrypt=true
        #letsencrypthost=loop.merchant.com
        lnd-mode=integrated
        network=${cfg.bitcoin_network}

        # Lnd
        lnd.lnddir=~/.lnd
        lnd.alias=merchant
        lnd.externalip=${cfg.lnd_external_ip}
        lnd.rpclisten=${cfg.lnd_rpc_host_port}
        lnd.listen=${cfg.lnd_host_port}
        lnd.debuglevel=debug

        # Lnd - bitcoin
        lnd.bitcoin.node=bitcoind

        # Lnd - bitcoind
        lnd.bitcoind.rpchost=${cfg.bitcoin_host}
        lnd.bitcoind.rpcuser=${cfg.bitcoin_user}
        lnd.bitcoind.rpcpass=bitcoind-signet-rpc-psk
        lnd.bitcoind.zmqpubrawblock=localhost:28332
        lnd.bitcoind.zmqpubrawtx=localhost:28333

        # Loop
        loop.loopoutmaxparts=5

        # Pool
        pool.newnodesonly=true

        # Faraday
        faraday.min_monitored=48h

        # Faraday - bitcoin
        faraday.connect_bitcoin=true
        faraday.bitcoin.host=${cfg.bitcoin_host}
        faraday.bitcoin.user=${cfg.bitcoin_user}
        faraday.bitcoin.password=bitcoind-signet-rpc-psk
      '';
    };

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
          [ "lit.conf:/etc/lit/lit.conf"
            "bitcoind-signet-rpc-psk:/etc/nixos/private/bitcoind-signet-rpc-psk.txt"
            "litd_ui_password:/etc/nixos/private/litd_ui_password.txt"
          ];
        User = "litd";
        Group = "litd";
      };
      path = with pkgs; [
        lightning-terminal postgresql systemd gnused
      ];

      script = ''
       set -ex
       ls -la $CREDENTIALS_DIRECTORY/
       rm ~/.lit/lit.conf || true
       mkdir -p ~/.lit || true
       cp $CREDENTIALS_DIRECTORY/lit.conf ~/.lit/lit.conf
       sed -i "s/bitcoind-signet-rpc-psk/$(cat $CREDENTIALS_DIRECTORY/bitcoind-signet-rpc-psk)/g" ~/.lit/lit.conf
       sed -i "s/litd_ui_password/$(cat $CREDENTIALS_DIRECTORY/litd_ui_password)/g" ~/.lit/lit.conf
       litd
      '';

    };
  };

}
