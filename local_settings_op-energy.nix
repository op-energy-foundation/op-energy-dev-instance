env@
{ tg-alerts-chat-id ? builtins.readFile ("/etc/nixos/private/op-energy-tg-alerts-chat-id")
, tg-alerts-bot-token ? builtins.readFile ("/etc/nixos/private/op-energy-tg-alerts-bot-token")
, mainnet_volume ? builtins.readFile ("/etc/nixos/private/mainnet-volume")
, ...
}:
args@{ pkgs, lib, config, ...}:

let
  local_settings_production = import ./local_settings_production.nix env;
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
  op-energy-frontend-prototype-subroute = subroute:
    lib.recursiveUpdate
    {
      locations."${subroute}" = {
        return = "301 ${subroute}/";
      };
      locations."${subroute}/" = {
        alias = "${pkgs.op-energy-frontend-prototype "${subroute}/"}/";
        index = "index.html";
        tryFiles = "$uri $uri/ ${subroute}/index.html =404";
      };
    }
    ( lib.recursiveUpdate
      (pkgs.op-energy-blockspans-service-nginx-vhost-config {config = config; } "${subroute}/" "http://127.0.0.1:8999")
      (pkgs.op-energy-account-service-nginx-vhost-config {config = config; } "${subroute}/" "http://127.0.0.1:8899")
    )
    ;
in
{
  imports = [
    local_settings_production # this node is production
  ];

  system.stateVersion = "22.05";

  users.users.nginx.extraGroups = [ "acme" ];
  security.acme = {
    acceptTerms = true;
    defaults.email = "ice.redmine+oe+acme@gmail.com";
    certs = {
      "op.energy" = {
        webroot = "/var/lib/acme/acme-challenge/";
        email = "ice.redmine+oe+acme@gmail.com";
        # Ensure that the web server you use can read the generated certs
        # Take a look at the group option for the web server you choose.
        group = "nginx";
        # Since we have a wildcard vhost to handle port 80,
        # we can generate certs for anything!
        # Just make sure your DNS resolves them.
        extraDomainNames = [ "bitcoin.op.energy" "exchange.op-energy.info" ];
      };
    };
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    443 # ssl backed service
  ];

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

  # use zero tier instead of ssh vpn, which is slow
  services.zerotierone = {
    enable = true;
    joinNetworks = [
      "41d49af6c2442cb2" # administrated by dambaev
    ];
  };
  nixpkgs.config.allowUnfree = true; # for zerotier
  networking.firewall.extraCommands = ''
    iptables -t filter -A nixos-fw -m conntrack --ctstate NEW -i ztw4ln5wtq -p tcp --dport 8332 -j ACCEPT # allow btc node through zerotier
  '';
  networking.nat.enable = true;
  networking.nat.extraCommands = ''
    iptables -t nat -A nixos-nat-pre -i ztw4ln5wtq -d 10.243.0.1 -p tcp --dport 8332 -j DNAT --to-destination 127.0.0.1:8332 # from zerotier to node
  '';
  services.nginx = {
    virtualHosts = {
      op-energy = {
        serverName = "op.energy";
        forceSSL = true;
        useACMEHost = "op.energy";
      };
      op-energy-mvp = lib.recursiveUpdate {
        serverName = "exchange.op-energy.info";
        forceSSL = true;
        useACMEHost = "op.energy";
      } (op-energy-frontend-prototype-subroute "/prototype");
    };
  };
  users.users.proxy = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCkkpIFU1cyqPiecRarmjfDjZKvYXGj2/Et2Bj1IhwSgNJTaEg6rjdBUd1JubEWOjqg3YPpD/wvQyGZMeIsgpBF8pDwUFa15PQrjLD6UUxW64fUk+N/zDmafI4lKcgA5Y8IXxV0OgCmflrOSIXH3VP9vqxyek4GLpHOPZrrih8B55ByZ5LlCrZ3eX0gonbArHIiMOEnB/eIzhArlw6Ud38Ccr8bJE18U9jON7SkFsbr7zOZKJPwVMLFArMvUr0XmTqbztxXO2vb6UEYCyE5MRDlWiKFnksEg56nrMhFsfpdNShCBv7mxcQA+dbVRPSAmMnWcUCU6cAj0QHHrrbpgbzOxj6kRz359qgM5Gn55p2x54m2kbG/sGhqZNuVO17avLTG+FrgH+xNK3Vl1K1UEqeZfTdwu8FdRCfJX3bRiH9XSPzCSzT7N/8xEOn19NcIOrT+vDBpGwvEHU3hOVag6rq2WrFMjop0lHSxVZUJ5BZsOS5bVBUkUwqXjrD+iIdoZq5uXDR91aiixNNh8YRD632saoy/jByoGyxA/zyAftHsTIdAMZ1mqpIo22JeGYgzsG6EhfnbyNzlBY7dO011zd7q8e0Ju/Ia6c2DNWVLssP6o3Vp9XBQlXH9/f3mbq9XMl+PIXbmZHRuA5GV8QVBTvepXS17MBZeP2LhsiFU6BCVpw== root@build" # dambaev's dev
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC7venNAKELBvcIs6ucdRdSM2vOEtBaGS87jgGFnDhdDaICxLsaHrxhsYHKKTrBn5DTWsQ+xDvetV5/9yxZtQUby7AxVF39zAQk9kO3Jt7hkz85n7gWOWIAq3msMTbJQDOzXEZR/Ddpf4jQjEeGgIGYTpKXmY923qog1qQvnuhhYAID2oVTmbT/c4xPvOxWkeDe30ue2/Cl0HQhf6ilSTLAfx6X3WpTVLK+l+xmWLWB/9rmVtJqo/TPuq+cD7DoWTuZ9o+jR1CGafYtH7puxi8mpu6c75D37P5KofE8Ae/jnDAPzzp7APT/bm1uNqsvhEO4dU9wkIDUdXpO48L0mgIrxLlKFnfVe0yWFUns11iqTiw5XDxcIKJVSBjaiCblbJok71746CXF06HwJENNb/Y9Ak+VaezTprThFGESf5fUBpL+I3rHK5CgTZJlf2YS0dWASZCqoda++ocdO6suaIyL9C6yk1yBfnpUt4ePI834iqn6kOiwAYiKAFy4BTfOK3tArX2pOagnjhOij4GhwYassk8WNpUtkOXj1wzpmI0i6fhgvt00YOY07oZnDg6/xg1vx7jFoPIAvzW8HmXUnP3K+aBSq37HBx0zqXvylBsqLE2Mah8c+/YeGMNXE0k4UEU489HpTCY8H0LXa/iHpqfd9SurwbDiQnJy1Q+VCvJJ7Q== root@op-energy-dev" # dev instance
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDFsWtJfIRIeSTZBlALW13bGt6wHX1pQtqXuzImHyOZkyPxL/kWaSQW+KGpzeWpwh3qq6LFbEvOOEoSYU38s7pJvuxcB36Q1DDGbMSM2RHJmwsMtzcSDG76eXKuMaRuM6ELtZELryLnsWcQdqkE/ZH3cMrCrFOT59vcVcOaTjxDRaPh4xrzfz2wJle86rmNhG1mY8J0qgCpa4ckBvgOLTSqgP5wi5BBNBDw7FqZe6lz9UhfwPr+tYap1eX0iCDxyl3h+rVd0emErLghBoHFi6riSslIq0dW2W/399j+dNEUD9ok+pmNPDjfw6wQeLzJ3XO0GKhA4c6Lg5PJQExeHVs3tudx9GpB1iYCxeCvqoRameDDIOkF8JfWjRiCy4i4D6kFp+e3bfkKTC9/u8OOKdVKSCi128TsKx0QpOXJ5fisu17JmsFpJh6mF/8k8HkdaEOMPmy3DxRnkKNJpOeib6WHjPpfR7sL5Ahb5xiz/qFUlTTGhaAKqFqziZdY+mMDdSJpqT5AwqMriu3RsJALBHa9r8/EnmkEjiTnAFP6drSaCYr25OWf9EjBrMBlXYpYd0A8vqGxPVxKNoEEuKlZZcaRetAxi13GZnTssPSpraVqZa7FvG+9r2WNYemfnIAuBnGSn9QENPKS4jv68u/3St/olOLtFJubmXX06tfWfn1rSQ== root@op-energy-dev" # dev instance
    ];
  };
}
