{ internal_blocktime_api_port}:
{ pkgs
, ...
}:
{
  systemd.services.guessable_strike_creation = {
    description = "ensures there are always guessable strikes available";
    serviceConfig.Type = "oneshot";
    path = with pkgs; [ curl jq ];
    script =
        ''
        #!${pkgs.stdenv.shell} -e
        curl 'http://localhost:${toString internal_blocktime_api_port}/api/v1/blocktime/currenttip'
        '';
    startAt = "*:0/1"; # run every 1 minute
  };
}
