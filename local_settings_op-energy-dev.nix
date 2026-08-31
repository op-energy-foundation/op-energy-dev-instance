env@
{ GIT_COMMIT_HASH ? ""
, ...
}:
args@
{ pkgs
, lib
, config
, ...
}:

let
  local_settings_development = import ./local_settings_development.nix env;
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
      ( lib.recursiveUpdate
        (pkgs.op-energy-account-service-nginx-vhost-config {config = config; } "${subroute}/" "http://127.0.0.1:8899")
        (pkgs.op-energy-api-swagger-ui-nginx-vhost-config { config = config; } "${subroute}/" "http://127.0.0.1:8998" )
      )
    )
    ;
in
{
  imports = [
    local_settings_development # this instance is development
  ];

  users.users.nginx.extraGroups = [ "acme" ];
  security.acme = {
    acceptTerms = true;
    defaults.email = "ice.redmine+oe+acme@gmail.com";
    certs = {
      "dev-exchange.op.energy" = {
        webroot = "/var/lib/acme/acme-challenge/";
        email = "ice.redmine+oe+acme@gmail.com";
        # Ensure that the web server you use can read the generated certs
        # Take a look at the group option for the web server you choose.
        group = "nginx";
        # Since we have a wildcard vhost to handle port 80,
        # we can generate certs for anything!
        # Just make sure your DNS resolves them.
        extraDomainNames = [ "dev-exchange.op-energy.info" ];
      };
    };
  };

  services.nginx = {
    virtualHosts = {
      op-energy = {
        serverName = "dev-exchange.op.energy";
        forceSSL = true;
        useACMEHost = "dev-exchange.op.energy";
      };
      op-energy-mvp = lib.recursiveUpdate
        {
          serverName = "dev-exchange.op-energy.info";
          forceSSL = true;
          useACMEHost = "dev-exchange.op.energy";
        }
        ( lib.recursiveUpdate
          (op-energy-frontend-prototype-subroute "/prototype")
          ( lib.recursiveUpdate
            (pkgs.op-energy-api-swagger-ui-nginx-vhost-config { config = config; } "/" "http://127.0.0.1:8998")
            ( lib.recursiveUpdate
              (pkgs.op-energy-account-service-nginx-vhost-config { config = config; } "/" "http://127.0.0.1:8899")
              ( lib.recursiveUpdate
                (pkgs.op-energy-blockspans-service-nginx-vhost-config { config = config; } "/" "http://127.0.0.1:8999")
                (pkgs.op-energy-offer-service-nginx-vhost-config { config = config; } "/" "http://127.0.0.1:8909")
              )
            )
          )
        );
    };
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    443 # ssl backed service
  ];
  users.users.erik = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCl3sFieaXO8pLDGxvpPt3Erx0fgQyFuLkDSIfSdklGtM0UxPmmarSKnSzaVgdEHRfJqcPUxkA+43Wba+j84wqmnPVuHX7IpiZh4gzpfcE2xuBrgh7fwerVCexq7wZhQRcBCMfjE6f0Qvrgpmj5+2Uax1ngL+LE8Mqr6dJJlHhVN27/wx9XcQM1+Z+P5NfbDhhvGNEzRILYrbujqZFEAQlO5wTVRCVhGv8ma45jjVCcl5EvRn0OLHlOkesU8tlqpbfKmAFY5CPrGnu6h2Hu83LtpXmobLKWolATkayYr8hvgB+Mgw6jLqRfh4l+BPDvQ7WdsSAeIFzmEUWKWkgg316Y4tJxTX2iKJzZo7dZh391iF5adVvst93fcCF8S7js/tPHdhqFPEgq89HsNHf46RLtTqJBpT9YFOJuLgO+p307+wmpR2k1LCxi6Yovr9EKqGArXrDMogUmdtr6A+VQgXtA2qTtVZX600PsVV/mFCtcthlTO6uGhxpzH1apDs1rPPbYmUfdF1P5YVF97MWIwqYfDwUDgtl7UQqaUNYI2ufuX4xmA+5vm5mJ3HFWdbjYR27yiAv5I2jccd0YqrGyLm+vwoTC19SVNC6WnUZRxx0pRZX6JSeu4GaLa3lBKHdqfq9BsjJ6H4GbBCxNiR4XqKv/qAe5C10VejyBIk17IGO3rQ== erik@velascommerce.com" # 2025.11.19
    ];
  };
  users.users.user = {
    isNormalUser = true;
  };
  system.stateVersion = "22.05";
}
