{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../shared/system-module.nix
    ./wireguard.nix
    ./stt.nix
    ./tts.nix
    ./audiobook-queue.nix
    ./audiobook-review.nix
    ./litestream.nix
    ./telemetry.nix
  ];

  networking.hostName = "x300m-stx";

  # SSH 只允許 LAN (enp2s0) 和 WireGuard (wg0) 連入
  networking.firewall.interfaces = {
    enp2s0.allowedTCPPorts = [ 22 ];
    wg0.allowedTCPPorts = [
      22
      80
      443
    ]; # 80→443 轉址 + HTTPS（nginx → gen-ui-hub :8088）
  };

  # Swap：24GB RAM 原本無 swap，服務尖峰會被 OOM killer 直接 hard-kill（曾因
  # 同時常駐兩顆 Gemma 把 ollama 砍掉、連帶 bge-m3 embedding 召回降級）。開 16GiB
  # swapfile 當「緩衝墊」，讓突發尖峰外溢、保護 ollama / hub / 語音不被硬殺。
  # ⚠️ swap 不是拿來多跑一顆大模型——LLM 權重一旦落 swap 推論會慢到不能用；
  # swappiness=10 讓內核盡量留實體 RAM、只有壓力下才動 swap。
  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024;
    } # 16 GiB（size 單位 MiB）
  ];
  boot.kernel.sysctl."vm.swappiness" = 10;

  # ── 永不自動睡眠 ──────────────────────────────────────────────────────────────
  # x300m 是常駐伺服器（SSH + nginx 反代對外），睡了就 SSH 斷、hub/ollama/語音全停。
  # 它雖 headless 操作，卻仍跑 GNOME（system-module → desktop.nix 的 GDM + gnome）：
  # gnome-settings-daemon 預設 AC 閒置 ~20 分自動 suspend——沒人登入桌面時，**GDM greeter
  # 自己**就會把整台機器睡掉。最硬的宣告式保證＝遮蔽 systemd 的四個睡眠 target：不論誰
  # （GNOME / GDM / logind / 手動 systemctl suspend）發起，最終都收束到這些 target，遮了整條
  # 路徑一律 no-op。伺服器不需要手動 suspend，副作用可接受。scoped 在 x300m——筆電照常會睡。
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  # Ollama for gen-ui-hub embedding (bge-m3)；無 GPU 用純 CPU package，
  # 綁 localhost — gen-ui-hub 同機呼叫，不對外開放。
  services.ollama = {
    enable = true;
    package = pkgs.ollama;
    host = "127.0.0.1";
    port = 11434;
    # CPU 分配走「軟優先」而非硬框核：ollama 給低 CPUWeight、Kokoro TTS 給高 CPUWeight
    # （見 tts.nix）。閒置時 ollama 吃滿全 12 核快翻草稿（實測 ~4.3 tok/s）；TTS 一播放，
    # CFS 依權重讓 TTS 搶贏、把背景翻譯壓下去（實測 TTS 合成回到 ~1.1s/句、近閒置基線），
    # 翻譯只在你聽書當下放慢、句子間空檔又搶回核心。被犧牲的永遠是不痛不癢的背景翻譯。
    # 取代舊「硬釘 CPU 0-3 四核」：那是單邊框 ollama（TTS/hub 仍會擠進 0-3、沒真隔離），
    # 把翻譯永遠餓到 ~0.39 tok/s（慢 11x）只換播放順——代價太大。軟優先實測兩全其美。
    environmentVariables = {
      # 別讓進行中的翻譯段 head-of-line block 住互動 embedding 召回：放行 2 路並行，
      # 短 embedding 請求可與長翻譯段同時跑、不必排隊等整段 decode 完。
      OLLAMA_NUM_PARALLEL = "2";
    };
  };
  # 軟優先：低權重，讓 TTS（高權重）在 CPU 競爭時搶贏（services.ollama 無對應高階旋鈕）。
  systemd.services.ollama.serviceConfig.CPUWeight = 20;

  # gen-ui-hub 在地判題（刷題教練 §6）的沙盒工具鏈。judge/ 薄 Go runner 疊 bubblewrap
  # 跑學習者/oracle 的 Python：`exec.LookPath` 要撈得到 `bwrap` 與 `python3`（`bash` 已在
  # 系統）。落 systemPackages → /run/current-system/sw/bin，正在 hub user service 的 PATH 上
  # （見下方 Environment）。bwrap 本體在 /nix/store、judge 綁 /nix 故其動態庫齊全；python3
  # 只用到 sys/json stdlib，毋須額外套件。開發機靠 `nix-shell -p bubblewrap`，此處是 production 常駐。
  #
  # clang：C++ 判題（§7-3）。judge 在**主機上**（非沙盒內）用 clang++ 編學習者的 C++——nix
  # cc-wrapper 需自己的 env/bash，撐不過沙盒 --clearenv，故只把產出的 binary 丟進 bwrap 跑
  # （動態庫走 /nix bind 齊全）。wrapper 路徑已內烘，bare-PATH 呼叫（無 nix-shell）照樣編得起來。
  environment.systemPackages = with pkgs; [
    bubblewrap
    python3
    clang
  ];

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
