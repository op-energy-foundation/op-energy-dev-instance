env@{
  GIT_COMMIT_HASH ? ""
}:
args@
{ pkgs
, lib
, CYPHER_REPO_LOCATION ? /etc/nixos/.git/modules/overlays/cypher-block
, ...
}:

let
  local_settings_development = import ./local_settings_development.nix env;
  internal_blocktime_api_port = import ./internal_blocktime_api_port.nix;
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
  args1 = args // { GIT_COMMIT_HASH = GIT_COMMIT_HASH CYPHER_REPO_LOCATION;};
in
{
  imports = [
    local_settings_development # this instance is development
    (import ./scheduled_strike_creation_module.nix { internal_blocktime_api_port = internal_blocktime_api_port; })
    (import ./module-cypher-block.nix env)
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
        forceSSL = true;
        useACMEHost = "dev-exchange.op.energy";
      };
      cypher-block = {
        forceSSL = true;
        useACMEHost = "dev-exchange.op.energy";
      };
    };
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    443 # ssl backed service
    444 # cypher-block
  ];
  system.stateVersion = "22.05";
}
