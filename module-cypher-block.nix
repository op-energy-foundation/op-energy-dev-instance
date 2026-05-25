env@{
  GIT_COMMIT_HASH ? ""
, ...
}:
args@{ pkgs, lib, ...}:

let
  cypher-block-overlay = import ./overlays/cypher-block/overlay.nix {
      GIT_COMMIT_HASH = GIT_COMMIT_HASH;
    };
in {
  nixpkgs.overlays = [
      cypher-block-overlay
    ];
  services.nginx.virtualHosts.cypher-block = {
    listen =
      [ { addr = "0.0.0.0"; port = 444; ssl = true; }
      ];
    root = "${pkgs.cypher-block}";
    locations."/" = {
      index = "index.html";
      tryFiles = "$uri $uri/ /index.html =404";
    };
  };
}

