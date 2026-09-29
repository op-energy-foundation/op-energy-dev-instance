args@{ pkgs, lib, config, ...}:

let
  cfg = config.services.litd_terminal_service;
  # lit.conf is rendered with placeholder tokens (LITD_UI_PASSWORD_SECRET, BTC_PASSWORD_SECRET)
  # that are replaced with the real values from $CREDENTIALS_DIRECTORY at runtime,
  # so the secret values never enter the Nix closure.
  lit_conf = pkgs.writeText "lit.conf" ''
    # Application Options
    insecure-httplisten=${cfg.insecure-httplisten}
    uipassword=LITD_UI_PASSWORD_SECRET
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
    lnd.bitcoind.rpcpass=BTC_PASSWORD_SECRET
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
    faraday.bitcoin.password=BTC_PASSWORD_SECRET
  '';
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

    credentials_locations = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = {
        BTC_PASSWORD_SECRET = "/etc/nixos/private/BTC_PASSWORD_SECRET";
        LITD_UI_PASSWORD_SECRET = "/etc/nixos/private/LITD_UI_PASSWORD_SECRET";
      };
      description = ''
        Maps var->secret_file for systemd-credentials.
        The files are loaded via LoadCredential and substituted into lit.conf at runtime,
        so the secret values never enter the Nix closure.
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
          [ "BTC_PASSWORD_SECRET:${cfg.credentials_locations.BTC_PASSWORD_SECRET}"
            "LITD_UI_PASSWORD_SECRET:${cfg.credentials_locations.LITD_UI_PASSWORD_SECRET}"
          ];
        User = "litd";
        Group = "litd";
      };
      path = with pkgs; [
        lightning-terminal postgresql systemd gnused
      ];

      script = ''
       set -e
       rm ~/.lit/lit.conf || true
       mkdir -p ~/.lit || true
       cp ${lit_conf} ~/.lit/lit.conf
       sed -i "s|BTC_PASSWORD_SECRET|$(cat $CREDENTIALS_DIRECTORY/BTC_PASSWORD_SECRET)|g" ~/.lit/lit.conf
       sed -i "s|LITD_UI_PASSWORD_SECRET|$(cat $CREDENTIALS_DIRECTORY/LITD_UI_PASSWORD_SECRET)|g" ~/.lit/lit.conf
       litd
      '';

    };
  };

}
