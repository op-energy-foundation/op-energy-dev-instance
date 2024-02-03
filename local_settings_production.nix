env@{
, bitcoind-mainnet-rpc-psk ? builtins.readFile ( "/etc/nixos/private/bitcoind-mainnet-rpc-psk.txt")
, bitcoind-mainnet-rpc-pskhmac ? builtins.readFile ( "/etc/nixos/private/bitcoind-mainnet-rpc-pskhmac.txt")
, op-energy-db-psk-mainnet ? builtins.readFile ( "/etc/nixos/private/op-energy-db-psk-mainnet.txt")
, op-energy-db-salt-mainnet ? builtins.readFile ( "/etc/nixos/private/op-energy-db-salt-mainnet.txt")
, tg-alerts-chat-id ? builtins.readFile ("/etc/nixos/private/op-energy-tg-alerts-chat-id")
, tg-alerts-bot-token ? builtins.readFile ("/etc/nixos/private/op-energy-tg-alerts-bot-token")
, mainnet_volume ? builtins.readFile ("/etc/nixos/private/mainnet-volume")
}:
args@{ pkgs, lib, ...}:

let
  btc_volume_alert = pkgs.writeText "btc_volume_alert" ''
    groups:
    - name: node.rules
      rules:
      - alert: mainnet volume free space is less than 10 GiB
        expr: node_filesystem_avail_bytes{mountpoint="${mainnet_volume}"} < 10737418240
        for: 5m
        labels:
          severity: average
      - alert: mainnet volume free space is less than 5 GiB
        expr: node_filesystem_avail_bytes{mountpoint="${mainnet_volume}"} < 5368709120
        for: 5m
        labels:
          severity: critical
  '';
  telegram_template = pkgs.writeText "telegram_template" ''
    {{ define "telegram.default" }}
    {{ range .Alerts }}
    {{ if eq .Status "firing"}}&#x1F525<b>{{ .Status | toUpper }}</b>&#x1F525{{ else }}&#x2705<b>{{ .Status | toUpper }}</b>&#x2705{{ end }}
    <b>{{ .Labels.alertname }}</b>
    {{- if .Labels.severity }}
    <b>Severity:</b> {{ .Labels.severity }}
    {{- end }}
    {{- if .Labels.ds_name }}
    <b>Database:</b> {{ .Labels.ds_name }}
    {{- if .Labels.ds_group }}
    <b>Database group:</b> {{ .Labels.ds_group }}
    {{- end }}
    {{- end }}
    {{- if .Labels.ds_id }}
    <b>Cluster UUID: </b>
    <code>{{ .Labels.ds_id }}</code>
    {{- end }}
    {{- if .Labels.instance }}
    <b>instance:</b> {{ .Labels.instance }}
    {{- end }}
    {{- if .Annotations.message }}
    {{ .Annotations.message }}
    {{- end }}
    {{- if .Annotations.summary }}
    {{ .Annotations.summary }}
    {{- end }}
    {{- if .Annotations.description }}
    {{ .Annotations.description }}
    {{- end }}
    {{ end }}
    {{ end }}
  '';
in
{
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
      rpcallowip=127.0.0.1
    '';
    rpc.users = {
      op-energy = {
        name = "op-energy";
        passwordHMAC = "${bitcoind-mainnet-rpc-pskhmac}";
      };
    };
  };

  # bitcoin storage monitoring
  services.prometheus = {
    enable = true;
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            targets = [
              "localhost:9100"
            ];
          }
        ];
      }
    ];
    exporters.node = {
      enable = true;
    };
    ruleFiles = [
      btc_volume_alert
    ];
    alertmanagers = [
      { scheme = "http";
        path_prefix = "/";
        static_configs = [
          { targets = [
              "localhost:9093"
            ];
          }
        ];
      }
    ];
    alertmanager = {
      enable = true;
      port = 9093;
      configText = ''
        global:
         resolve_timeout: 5m
         telegram_api_url: "https://api.telegram.org"

        templates:
          - '${telegram_template}'

        receivers:
         - name: blackhole
         - name: telegram-test
           telegram_configs:
            - chat_id: ${tg-alerts-chat-id}
              bot_token: "${tg-alerts-bot-token}"
              api_url: "https://api.telegram.org"
              send_resolved: true
              parse_mode: HTML
              message: '{{ template "telegram.default" . }}'


        route:
         group_by: ['ds_id']
         group_wait: 15s
         group_interval: 30s
         repeat_interval: 12h
         receiver: telegram-test
         routes:
          - receiver: telegram-test
            continue: true
            matchers:
             - severity=~"average|critical"
          - receiver: blackhole
            matchers:
             - alertname="Watchdog"
      '';
    };
  };

}
