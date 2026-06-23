{ config, pkgs, ... }:

# WireGuard VPN Client（連入 x300m-stx）
#
# 對應 server：hosts/x300m-stx/wireguard.nix
# VPN 網段：10.100.0.1/24
#   x300m-stx (server)  → 10.100.0.1
#   Richard 手機         → 10.100.0.2
#   Alison 手機          → 10.100.0.3
#   thinkpad (本機)      → 10.100.0.4   ← 這台
#
# 初次部署步驟（金鑰不進 git，比照 server 慣例放 /etc/wireguard）：
#   1. 安裝本機私鑰（公鑰已登記在 server peers）：
#        sudo install -d -m 700 /etc/wireguard
#        sudo install -m 600 /tmp/thinkpad_private.key /etc/wireguard/thinkpad_private.key
#      （或自行產生：wg genkey | sudo tee /etc/wireguard/thinkpad_private.key | wg pubkey
#        然後把印出的公鑰填回 server 的 peers）
#   2. 重建本機：sudo nixos-rebuild switch --flake .#thinkpad-t14s-gen6
#   3. 重建 server：在 x300m-stx 上 sudo nixos-rebuild switch --flake .#x300m-stx
#
# 路由模式：split tunnel —— 只有 10.100.0.0/24 走 WireGuard，
#           一般上網 / LAN 維持原本路由。

{
  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.100.0.4/24" ];
    privateKeyFile = "/etc/wireguard/thinkpad_private.key";

    peers = [
      # x300m-stx (server)
      {
        publicKey = "KsQJuINwy2CojRLohQ2eR2YqXXn/ZKr/XCnUqRS/im4=";
        endpoint = "iyun.duckdns.org:51820";
        # split tunnel：只把 VPN 內網導進隧道
        allowedIPs = [ "10.100.0.0/24" ];
        # 本機在 NAT 後面，需定期送 keepalive 維持 NAT 對應
        persistentKeepalive = 25;
        # x300m 是 HiNet 動態公網 IP（iyun.duckdns.org 會跟著換）。WireGuard 只在
        # 啟動時解析一次 endpoint 就快取，IP 輪替後不會自動重解 →「0 B received」、
        # tunnel 死掉（持續 keepalive 也救不了，因為打的是舊 IP）。此選項讓 NixOS
        # 產生一個 timer 週期性重跑 `wg set ... endpoint`、跟著 DDNS 走，IP 換了自癒。
        dynamicEndpointRefreshSeconds = 60;
      }
    ];
  };
}
