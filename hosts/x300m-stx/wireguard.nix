{ config, pkgs, ... }:

# WireGuard VPN Server + Duck DNS
#
# 初次部署步驟：
#   1. 產生伺服器金鑰：
#        sudo mkdir -p /etc/wireguard
#        wg genkey | sudo tee /etc/wireguard/server_private.key | wg pubkey | sudo tee /etc/wireguard/server_public.key
#        sudo chmod 600 /etc/wireguard/server_private.key
#
#   2. 儲存 Duck DNS token：
#        sudo mkdir -p /etc/ddns
#        echo -n "your-duckdns-token" | sudo tee /etc/ddns/duckdns-token
#        sudo chmod 600 /etc/ddns/duckdns-token
#
#   3. 新增手機 peer（見下方 peers 區塊說明）
#
# VPN 網段：10.100.0.1/24
#   x300m-stx (server)  → 10.100.0.1
#   Richard 手機         → 10.100.0.2
#   Alison 手機          → 10.100.0.3
#   thinkpad-t14s-gen6   → 10.100.0.4
#   其他裝置             → 10.100.0.5, 6, ...

{
  # ── WireGuard Server ──────────────────────────────────────────────────
  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.100.0.1/24" ];
    listenPort = 51820;
    privateKeyFile = "/etc/wireguard/server_private.key";

    # 每新增一台裝置加一個 peer
    # 產生 peer 金鑰（在手機以外的機器上執行）：
    #   wg genkey | tee peer_private.key | wg pubkey > peer_public.key
    # 或直接用手機 WireGuard App 的「新增隧道 → 從頭建立」產生
    peers = [
      # Richard 手機
      {
        publicKey = "+o9kVXWdvzeoKW6ZUzYT3mqYn2daZkAY80Do4YG4FXA=";
        allowedIPs = [ "10.100.0.2/32" ];
      }
      # Alison 手機
      {
        publicKey = "VFb+l2bWOpjmehlvrLAkB3/O/LEBI7uCow2/eYRIS3E=";
        allowedIPs = [ "10.100.0.3/32" ];
      }
      # thinkpad-t14s-gen6（client，見 hosts/thinkpad-t14s-gen6/wireguard.nix）
      {
        publicKey = "WU2dsLFU3EChmV3zYjouzM9As3B3meRoJeDFSvHdIHo=";
        allowedIPs = [ "10.100.0.4/32" ];
      }
    ];
  };

  # 允許 VPN 流量進出（UDP 51820）
  networking.firewall.allowedUDPPorts = [ 51820 ];

  # VPN server 必須開啟 IP forwarding，才能轉發客戶端流量
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  # ── nginx：將 WireGuard 流量 proxy 至 gen-ui-hub Wails dev server ──────
  # 手機 WireGuard 連入後開 http://10.100.0.1:34115 即可存取完整 Go bindings
  services.nginx = {
    enable = true;
    virtualHosts."gen-ui-hub-wg" = {
      listen = [{ addr = "10.100.0.1"; port = 34115; }];
      locations."/" = {
        proxyPass = "http://127.0.0.1:34115";
        proxyWebsockets = true;
      };
    };
  };

  # ── Duck DNS（自動更新動態 IP）────────────────────────────────────────
  services.ddclient = {
    enable = true;
    interval = "5min";
    protocol = "duckdns";
    server = "www.duckdns.org";
    username = "nouser";          # Duck DNS 不用 username，填 nouser 即可
    passwordFile = "/etc/ddns/duckdns-token";
    domains = [ "iyun" ];         # iyun.duckdns.org
    usev6 = "";                   # 停用 IPv6 偵測，此機器無 IPv6 連線
  };
}
