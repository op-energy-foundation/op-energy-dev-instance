env:
args@{ pkgs, lib, ...}:

let
  local_settings_development = import ./local_settings_development.nix env;
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
        forceSSL = true;
        useACMEHost = "dev-exchange.op.energy";
      };
    };
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    443 # ssl backed service
  ];
}
