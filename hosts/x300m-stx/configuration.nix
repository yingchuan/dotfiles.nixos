{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../shared/system-module.nix
    ./wireguard.nix
  ];

  networking.hostName = "x300m-stx";

  # SSH 只允許 LAN (enp2s0) 和 WireGuard (wg0) 連入
  networking.firewall.interfaces = {
    enp2s0.allowedTCPPorts = [ 22 ];
    wg0.allowedTCPPorts = [ 22 34115 ]; # 34115: gen-ui-hub via nginx proxy
  };

  # Ollama for gen-ui-hub embedding (bge-m3)；無 GPU 用純 CPU package，
  # 綁 localhost — gen-ui-hub 同機呼叫，不對外開放。
  services.ollama = {
    enable = true;
    package = pkgs.ollama;
    host = "127.0.0.1";
    port = 11434;
  };
}
