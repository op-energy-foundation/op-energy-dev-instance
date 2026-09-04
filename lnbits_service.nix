{ config, lib, pkgs, ... }:

let
  lnbitsFlake = builtins.getFlake "github:lnbits/lnbits";
in
{
  imports = [
    # Import LNBits service module directly from GitHub
    "${lnbitsFlake}/nix/modules/lnbits-service.nix"
  ];

  # Enable flakes (required)
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Configure LNBits service
  services.lnbits = {
    enable = true;
    host = "127.0.0.1";        # Listen on all interfaces
    port = 5000;             # Default port
    openFirewall = false;

    # Use package from the same flake (adjust system architecture as needed)
    package = lnbitsFlake.packages.x86_64-linux.lnbits;

    env = {
      LNBITS_ADMIN_UI = "true";
      # Configure your Lightning backend:
      # LNBITS_BACKEND_WALLET_CLASS = "LndRestWallet";
      # LND_REST_ENDPOINT = "https://localhost:8080";
      # LND_REST_CERT = "/path/to/tls.cert";
      # LND_REST_MACAROON = "/path/to/admin.macaroon";
    };
  };
}
