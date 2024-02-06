env:
args@{ pkgs, lib, ...}:

let
  local_settings_production = import ./local_settings_production.nix env;
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
        extraDomainNames = [ "bitcoin.op.energy" ];
      };
    };
  };

  services.nginx = {
    virtualHosts = {
      op-energy = {
        forceSSL = true;
        useACMEHost = "op.energy";
      };
    };
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    443 # ssl backed service
  ];

}
