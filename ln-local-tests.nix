# The whole host with the Lightning stack enabled, in a VM: checks that litd and LNbits coexist
# with the Op Energy services and stay unreachable from other machines. Expects the same layout
# as CI: submodules populated under overlays/ and local_hostname.nix containing "ln-local".
{ GIT_COMMIT_HASH ? "dev" }:
let
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/archive/8c50a710ddca43d7a530fb805ad55bde8d0141c5.tar.gz";
  pkgs = import nixpkgs {};

  bitcoind-rpc-psk = "bcb61e8b0a2c6f998e9996ae1d9da4d650b44a91150d8650be6a9e5c0b67d2d4";
  bitcoind-rpc-pskhmac = "6cd1a9449750a15c9f6d64b96ee089b9$9f5a5378a4ee0785fae6621c8506168af4b9e2211b2e7a1555012f5d6638744c";

  # The dummy values op-energy-blockspan-service uses in its own ci-tests.nix.
  env = {
    bitcoind-mainnet-rpc-psk = bitcoind-rpc-psk;
    bitcoind-mainnet-rpc-pskhmac = bitcoind-rpc-pskhmac;
    bitcoind-regtest-rpc-pskhmac = bitcoind-rpc-pskhmac;
    op-energy-db-psk-mainnet = "91794224aff99af7f36ee0bb8f210cc99242b15803651fffe68adca52b191416";
    op-energy-db-salt-mainnet = "a9a5fc93af271ae890a28d3cf0f056c8a07e8e6d0326913909707c319fd890d4";
    op-energy-account-token-encryption-key = "gzHQ1xTkFevavJ3xxd1fLA4PPxa7rQFXvivEFeEMNfYz99e4WBrywVJEnE/7KGrRYKvkSrSWh5tN/ZsE3cqKj4L57Vhm+hRyoR4oXFxtMVr9Tef2axGSijxQFvp6hocE";
    op-energy-internal-service-shared-secret = "mEVAVgAB1LJ1FO93ZL6cdWGp0dnUc9jtQ3zAS785uxjvkV1H7r2GnwTlRUbFGRScQc3QqDun/4X+PkDlci9NboZzCf1TCAEv0tj5GrfpNICytfFlKe5cxaVa13UdR4Ww";
    GIT_COMMIT_HASH = GIT_COMMIT_HASH;
  };
in
pkgs.testers.nixosTest {
  name = "ln-local";

  nodes = {
    server = args@{ config, pkgs, ... }: {
      imports = [ (import ./host.nix env) ];
      virtualisation.graphics = false;
      virtualisation.memorySize = 6144;
      virtualisation.diskSize = 12288;
      virtualisation.cores = 4;
      environment.systemPackages = [ pkgs.curl pkgs.jq ];
      environment.etc = {
        "nixos/private/bitcoind-regtest-rpc-psk.txt".text = bitcoind-rpc-psk;
        "nixos/private/litd-ui-password.txt".text = "local-only-not-a-secret";
        "nixos/private/lnbits-first-install-token.txt".text = "local-only-first-install-token";
      };
    };

    client = {
      virtualisation.graphics = false;
    };
  };

  skipLint = true;

  testScript = ''
    start_all()

    with subtest("the Op Energy services come up next to the Lightning stack"):
        server.wait_for_open_port(8899)
        server.wait_for_open_port(8909)
        server.wait_for_open_port(80)
        server.wait_for_unit("litd.service")
        server.wait_for_unit("lnbits.service")
        server.wait_for_open_port(8231)
        server.wait_until_succeeds(
            "journalctl -u lnbits.service | grep -q 'Backend LndRestWallet connected'", timeout=300
        )

    with subtest("LNbits and LND answer only on loopback"):
        # Reachability first, so a resolution failure cannot pass for a closed port.
        client.succeed("curl -s --max-time 5 -o /dev/null http://ln-local:80/")
        for port in (8231, 8080, 10009, 8443):
            code = client.execute(f"curl -s --max-time 5 http://ln-local:{port}/")[0]
            assert code in (7, 28), f"port {port}: expected refused or timed out, curl exited {code}"

    with subtest("resource snapshot"):
        print(server.succeed("free -m"))
        print(server.succeed(
            "for u in bitcoind-regtest litd lnbits op-energy-account-service op-energy-offer-service "
            "postgresql nginx; do printf '%s ' $u; systemctl show -p MemoryCurrent --value $u; done"
        ))
        print(server.succeed("systemctl --failed --no-legend || true"))
  '';
}
