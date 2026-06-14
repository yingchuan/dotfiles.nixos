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
#   4. 建立 Let's Encrypt（lego）用的 DuckDNS token 環境檔（沿用既有 token）：
#        sudo sh -c 'printf "DUCKDNS_TOKEN=%s\n" "$(cat /etc/ddns/duckdns-token)" \
#          > /etc/ddns/duckdns-lego.env && chmod 600 /etc/ddns/duckdns-lego.env'
#      （security.acme 的 environmentFile 需 KEY=VALUE 格式，與 ddclient 的
#       raw-token passwordFile 不同，故另存一檔。）
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

  # ── nginx：TLS 終結 + reverse proxy 至 gen-ui-hub（Go net/http :8088）──
  # 手機/桌機經 WireGuard 連 https://gen-ui-hub.duckdns.org（綠鎖；HTTPS 是
  # 瀏覽器開放麥克風 getUserMedia 的前提，內網 http 不算 secure context）。
  # 憑證由下方 security.acme 走 DuckDNS DNS-01 自動簽發＋續簽。
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;   # 帶上 Host / X-Forwarded-* 標頭
    virtualHosts."gen-ui-hub.duckdns.org" = {
      listenAddresses = [ "10.100.0.1" ];  # 只綁 wg0，不對 LAN/公網開放
      forceSSL = true;                     # http → https 轉址
      # 用下方 security.acme 以 DNS-01 簽好的憑證；不可用 enableACME（那會強制
      # HTTP-01 webroot，與 dnsProvider 互斥）。useACMEHost 只「取用」憑證。
      useACMEHost = "gen-ui-hub.duckdns.org";
      locations."/" = {
        proxyPass = "http://127.0.0.1:8088";
        proxyWebsockets = true;
        # SSE（/api/chat 串流、進度圖）必須關 buffering，否則前端收不到即時
        # token；串流連線久，read timeout 拉長避免被 nginx 中途砍斷。
        extraConfig = ''
          proxy_buffering off;
          proxy_read_timeout 3600s;
        '';
      };
    };
  };

  # ── Let's Encrypt 憑證（DuckDNS DNS-01，無需對外開 80）──────────────────
  # lego 用 DUCKDNS_TOKEN 自動建 _acme-challenge TXT 記錄完成驗證；token 不可
  # 進 nix store（會 world-readable），放 environmentFile（見部署註記步驟 4）。
  security.acme = {
    acceptTerms = true;
    defaults.email = "yingchuan.chen.2007@gmail.com";
    certs."gen-ui-hub.duckdns.org" = {
      dnsProvider = "duckdns";
      environmentFile = "/etc/ddns/duckdns-lego.env";
      group = "nginx";   # 讓 nginx 進程讀得到私鑰
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
