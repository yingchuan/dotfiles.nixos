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
    wg0.allowedTCPPorts = [ 22 80 443 ]; # 80→443 轉址 + HTTPS（nginx → gen-ui-hub :8088）
  };

  # Ollama for gen-ui-hub embedding (bge-m3)；無 GPU 用純 CPU package，
  # 綁 localhost — gen-ui-hub 同機呼叫，不對外開放。
  services.ollama = {
    enable = true;
    package = pkgs.ollama;
    host = "127.0.0.1";
    port = 11434;
  };

  # gen-ui-hub（AI 智能管家調度器，Go net/http :8088；nginx 反代見 wireguard.nix）。
  # binary 由手動 go build 產出（工作流：git pull → go build；前端動了再 npm ci
  # && npm run build），systemd 只負責常駐／開機自啟／崩潰重啟，不在 Nix 內建置。
  # app 自己讀 WorkingDirectory 下的 .env（憑證 / FINMIND / UNIFI / GEMINI /
  # SMARTPOWER_ALLOWED_OUTLETS 全在那）。
  systemd.services.gen-ui-hub = {
    description = "Gen-UI Hub — AI 智能管家調度器 (Go net/http :8088)";
    after = [ "network-online.target" "ollama.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "richard";
      WorkingDirectory = "/home/richard/gen-ui-hub";
      ExecStart = "/home/richard/gen-ui-hub/gen-ui-hub";
      Restart = "on-failure";
      RestartSec = 3;
      # agy(~/.local/bin) 與 opencode(~/.bun/bin) 是 exec 出去的子行程，systemd
      # 精簡 PATH 撈不到 → 顯式補（含 nix profile / 系統）。HOME 由 User=richard
      # 自動設成 /home/richard，agy/opencode 靠它找各自的設定 / 訂閱憑證。
      Environment = "PATH=/home/richard/.local/bin:/home/richard/.bun/bin:/home/richard/.nix-profile/bin:/run/current-system/sw/bin:/usr/bin:/bin";
    };
  };
}
