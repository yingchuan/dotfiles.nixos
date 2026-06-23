{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../shared/system-module.nix
    ./wireguard.nix
    ./stt.nix
    ./tts.nix
  ];

  networking.hostName = "x300m-stx";

  # SSH 只允許 LAN (enp2s0) 和 WireGuard (wg0) 連入
  networking.firewall.interfaces = {
    enp2s0.allowedTCPPorts = [ 22 ];
    wg0.allowedTCPPorts = [ 22 80 443 ]; # 80→443 轉址 + HTTPS（nginx → gen-ui-hub :8088）
  };

  # Swap：24GB RAM 原本無 swap，服務尖峰會被 OOM killer 直接 hard-kill（曾因
  # 同時常駐兩顆 Gemma 把 ollama 砍掉、連帶 bge-m3 embedding 召回降級）。開 16GiB
  # swapfile 當「緩衝墊」，讓突發尖峰外溢、保護 ollama / hub / 語音不被硬殺。
  # ⚠️ swap 不是拿來多跑一顆大模型——LLM 權重一旦落 swap 推論會慢到不能用；
  # swappiness=10 讓內核盡量留實體 RAM、只有壓力下才動 swap。
  swapDevices = [
    { device = "/swapfile"; size = 16 * 1024; } # 16 GiB（size 單位 MiB）
  ];
  boot.kernel.sysctl."vm.swappiness" = 10;

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
  #
  # 為什麼是 user service（不是 system service）：app 完全不需特權——以 richard
  # 跑、綁非特權埠 8088、只讀寫自己家目錄的檔。設成 user service 後，部署重啟
  # 走 `systemctl --user restart gen-ui-hub`（零 sudo），把部署迴路最後一個 sudo
  # 消掉。配 linger（見下）讓 user 實例開機即起、免登入。
  #
  # ordering 取捨：user 實例無法 order 在 system unit（network-online / ollama）
  # 之後——但 user manager 本就在系統起來後才啟動，加上 Restart=on-failure +
  # RestartSec=3，ollama 還沒好就重試幾輪，不需顯式依賴。
  systemd.user.services.gen-ui-hub = {
    description = "Gen-UI Hub — AI 智能管家調度器 (Go net/http :8088)";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      WorkingDirectory = "/home/richard/gen-ui-hub";
      ExecStart = "/home/richard/gen-ui-hub/gen-ui-hub";
      Restart = "on-failure";
      RestartSec = 3;
      # agy(~/.local/bin) 與 opencode(~/.bun/bin) 是 exec 出去的子行程，systemd
      # 精簡 PATH 撈不到 → 顯式補（含 nix profile / 系統）。user service 的 HOME
      # 本就是 /home/richard，agy/opencode 靠它找各自的設定 / 訂閱憑證。
      Environment = "PATH=/home/richard/.local/bin:/home/richard/.bun/bin:/home/richard/.nix-profile/bin:/run/current-system/sw/bin:/usr/bin:/bin";
    };
  };

  # 讓 richard 的 systemd user 實例開機即啟動（免登入），user service 才能在無
  # 互動 session 時常駐／開機自啟。等價於 `loginctl enable-linger richard`，宣告式。
  users.users.richard.linger = true;
}
