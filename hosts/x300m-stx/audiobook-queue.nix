{ config, pkgs, lib, ... }:

# 有聲書背景翻譯佇列 — 在地小模型「鴨子滑水」草稿腿（gen-ui-hub Phase 12.x 背景工）。
# 設計藍圖：~/gen-ui-hub/docs/audiobook_background_queue_design.md（§5 元件落點選 A、§6 Cut-1）。
#
# 它做什麼：每日離峰窗醒來，以 live DB 為準算缺章 → 挑最小一章 → 在地 qwen3-vl:8b-instruct
# 逐段翻草稿 → 機械閘（簡體/code-switch/kana）→ 寫 tl_tier='draft'（播放器顯誠實小標、
# 可聽未校）。產出「草稿腿」，最後一哩忠實度校定才留給訂閱後端（人觸發、非此處）。
#
# 為什麼是 USER 服務（不是 stt/tts 那種 system service）：與 gen-ui-hub 同位階——只讀寫
# richard 家目錄（live DB＝~/gen-ui-hub/docs/hub.db、suspect manifest＝~/.local/share/…）、
# 復用 repo checkout 裡的 Python 工具、不需特權。配既有 linger（見 configuration.nix）開機
# 即可被 timer 觸發；暫停背景工＝`systemctl --user stop audiobook-queue.timer`（零 sudo）。
#
# 🔑「不吵 Kokoro 基線」的主防線＝核心隔離，不是離峰時間。真正的重活（6GB 模型載入＋逐段
# decode）住在「共享的 services.ollama」進程裡——這個 unit 只是對 ollama 發 HTTP 的瘦 client。
# 故 cpuset 設在 ollama 那顆（configuration.nix：`AllowedCPUs = "0-3"`），把整顆 ollama 框在
# CPU 0-3、留 4-11 給 TTS/hub/系統 → 翻譯物理上吃不到 TTS 的核、**隨時跑都不卡朗讀**，離峰
# 窗因此從硬依賴降為單純排程節奏。下方 unit 自己的 Nice/IOSchedulingClass/MemoryMax 綁的是
# 瘦 client（近乎免費、防腳本失控），不影響 inference。跑完仍 `ollama stop` 卸載草稿模型還原
# RSS。見 ref_x300m_hardware_specs。

let
  repo = "/home/richard/gen-ui-hub";
  abQueue = "${repo}/tools/audiobook-tl/ab_queue.py";
  liveDb = "${repo}/docs/hub.db";   # live DB；根目錄三 .db 是假檔（見 ref_delegate_job_ops）
  ncode = "n9669bk";                # 無職轉生
  draftModel = "qwen3-vl:8b-instruct";

  # 每次觸發最多翻幾章。框在 4 核後 ~1.5-2x 慢（大章 ~2h/章）；timer 每 4h 一輪 → 一輪翻
  # 一章最穩（裝得下、模型一載一卸乾淨循環）。缺章清完即自動空轉收工。可調。
  maxPerRun = 1;
in
{
  # oneshot：純由 timer 觸發，不 wantedBy 任何 target（不常駐、不開機自啟）。
  systemd.user.services.audiobook-queue = {
    description = "有聲書背景翻譯佇列 — 在地小模型草稿腿（離峰鴨子滑水）";

    # ab_fetch 用 curl 抓 syosetu、ExecStopPost 用 ollama 卸載模型；python3 跑佇列（純 stdlib）。
    # 用 NixOS `path`（宣告式注入 unit PATH），不在 Environment 手刻 PATH。
    path = [ pkgs.python3 pkgs.curl pkgs.ollama ];

    environment = {
      # curl 抓 syosetu HTTPS 要 CA bundle（與 gen-ui-hub 同理，user env 全系統沒設）。
      SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      # ollama CLI/HTTP 都打同機 server（services.ollama 綁此 host:port）。
      OLLAMA_HOST = "127.0.0.1:11434";
      AB_TL_MODEL = draftModel;
    };

    serviceConfig = {
      Type = "oneshot";
      WorkingDirectory = "${repo}/tools/audiobook-tl";
      ExecStart = "${pkgs.python3}/bin/python3 ${abQueue} ${liveDb} ${ncode} --max ${toString maxPerRun}";

      # 跑完（成功或被 RuntimeMaxSec 砍皆會執行）卸載草稿模型，把 ollama RSS 還原到 Kokoro
      # 基線——絕不讓 6GB 草稿模型在離峰窗後繼續佔記憶體跟 TTS 搶。`-` 前綴：沒載任何模型時
      # stop 是 no-op，別讓它把 unit 標成 failed。
      ExecStopPost = "-${pkgs.ollama}/bin/ollama stop ${draftModel}";

      # 瘦 client 的 cgroup 旋鈕（inference 在 ollama 那顆、靠 cpuset 隔離，見檔頭 🔑 註）。
      Nice = 19;
      CPUWeight = 20;
      IOSchedulingClass = "idle";
      MemoryMax = "1G";        # client 極瘦；純防腳本失控，非限模型記憶體

      # 硬牆：單輪上限，避免卡死的一輪疊到下一個 4h 觸發。逐章原子寫入（中途被砍＝該章不寫、
      # 下次重挑），故中斷無半成品污染。大章 ~2h，留 3h30min 餘裕、仍 < 4h cadence。
      RuntimeMaxSec = "3h30min";
    };
  };

  systemd.user.timers.audiobook-queue = {
    description = "有聲書背景翻譯佇列排程（每 4 小時一輪）";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # 核已隔離（ollama 框 CPU 0-3、不卡 TTS）→ 不挑時間，每 4h 一輪慢慢清缺章 backlog。
      OnCalendar = "0/4:00:00";
      # 抖動避免每次精準同秒；上限 10min 無妨（已不卡 TTS）。
      RandomizedDelaySec = "10min";
      # 不補跑：關機錯過就等下一個 4h 整點；正在跑時 timer 觸發會自動略過（同 unit 不疊跑）。
      Persistent = false;
      Unit = "audiobook-queue.service";
    };
  };
}
