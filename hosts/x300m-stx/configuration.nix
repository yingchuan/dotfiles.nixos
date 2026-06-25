{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../shared/system-module.nix
    ./wireguard.nix
    ./stt.nix
    ./tts.nix
    ./audiobook-queue.nix
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
    # 整顆 ollama 框死在 CPU 0-3（4 執行緒）—— 由有聲書背景翻譯工驅動的決策
    # （見 audiobook-queue.nix）。重活（草稿 decode）在 ollama 進程裡，框核才真節流；
    # 留 CPU 4-11 給 Kokoro TTS / hub / 系統，故翻譯隨時跑都吃不到 TTS 的核、不必卡離峰窗。
    # 代價＝embedding(bge-m3) 白天也只在這 4 核（短脈衝、無感）、翻譯慢 ~1.5-2x（背景工無妨）。
    environmentVariables = {
      # 別讓進行中的翻譯段 head-of-line block 住互動 embedding 召回：放行 2 路並行，
      # 短 embedding 請求可與長翻譯段同時在 0-3 上跑、不必排隊等整段 decode 完。
      OLLAMA_NUM_PARALLEL = "2";
    };
  };
  # cpuset 設在生成的 ollama unit 上（services.ollama 沒有對應高階旋鈕）。
  systemd.services.ollama.serviceConfig.AllowedCPUs = "0-3";

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
      #
      # SSL_CERT_FILE：opencode（bun runtime）做 HTTPS 不會自動找 /etc/ssl/certs，
      # 缺 CA bundle 時 TLS 靜默卡死 → 子行程逾時回空（Phase 11.5 STT 術語修正每條轉錄
      # 都 fallback 回原文的真兇）。這份 systemd user env 全系統沒設 SSL_CERT_FILE，
      # 故在此指向 pinned cacert bundle；newOpencodeCmd 的白名單已放行此變數會轉發進沙盒。
      Environment = [
        "PATH=/home/richard/.local/bin:/home/richard/.bun/bin:/home/richard/.nix-profile/bin:/run/current-system/sw/bin:/usr/bin:/bin"
        "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      ];
    };
  };

  # 讓 richard 的 systemd user 實例開機即啟動（免登入），user service 才能在無
  # 互動 session 時常駐／開機自啟。等價於 `loginctl enable-linger richard`，宣告式。
  users.users.richard.linger = true;
}
