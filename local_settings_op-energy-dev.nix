args@{ pkgs, lib, ...}:

{
  users.users.nginx.extraGroups = [ "acme" ];
  security.acme = {
    acceptTerms = true;
    defaults.email = "ice.redmine+oe+acme@gmail.com";
    certs = {
      "dev-exchange.op-energy.info" = {
        webroot = "/var/lib/acme/acme-challenge/";
        email = "ice.redmine+oe+acme@gmail.com";
        # Ensure that the web server you use can read the generated certs
        # Take a look at the group option for the web server you choose.
        group = "nginx";
        # Since we have a wildcard vhost to handle port 80,
        # we can generate certs for anything!
        # Just make sure your DNS resolves them.
        extraDomainNames = [ "dev-exchange.op.energy" ];
      };
    };
  };
  services.nginx = {
    virtualHosts = {
      op-energy = {
        forceSSL = true;
        useACMEHost = "dev-exchange.op-energy.info";
      };
    };
  };
}