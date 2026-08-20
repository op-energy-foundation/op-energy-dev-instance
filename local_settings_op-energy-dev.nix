env@
{ GIT_COMMIT_HASH ? ""
}:
args@
{ pkgs
, lib
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
  args1 = args // { GIT_COMMIT_HASH = GIT_COMMIT_HASH OPENERGY_FRONTEND_PROTOTYPE_REPO_LOCATION;};
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
      op-energy-mvp = {
        serverName = "dev-exchange.op-energy.info";
        forceSSL = true;
        useACMEHost = "dev-exchange.op.energy";
        # The prototype stays reachable at /prototype for comparison. It is
        # rebuilt with vite base=/prototype/ (see the overlay below), so its
        # index.html asks for /prototype/assets/... rather than /assets/...,
        # which would otherwise collide with the MVP served at the root.
        locations."/prototype" = {
          return = "301 /prototype/";
        };
        locations."/prototype/" = {
          alias = "${pkgs.op-energy-frontend-prototype}/";
          index = "index.html";
          tryFiles = "$uri $uri/ /prototype/index.html =404";
        };
      };
    };
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    443 # ssl backed service
  ];
  system.stateVersion = "22.05";
}
