{ config, pkgs, lib, ... }:

# 有聲書「自動校閱佇列」— Cut-3 最後一哩的離峰批次（gen-ui-hub 背景工，姊妹於 audiobook-queue.nix）。
# 設計藍圖：~/gen-ui-hub/docs/audiobook_background_queue_design.md（§6 Cut-3）。
#
# 它做什麼：每日離峰醒來，以 live DB 為準掃出所有 tl_tier='draft' 完成章 → 逐章 spawn
# ab_review.py 把機械中標段送 claude Sonnet 主／agy Flash 援校定 → 全段過機械閘才升
# tl_tier='verified'（角標由「−草稿」轉「✓已校」）。把在地草稿的最後一哩忠實度自動補上。
#
# 與 audiobook-queue（草稿腿）的關鍵差異——**走雲端訂閱、不碰 ollama**：
#   - 無 GPU/inference，不與 Kokoro TTS 爭核（不需 CPUWeight 那套基線保護的理由）。
#   - 不取草稿佇列的 ab_queue flock＝可與 in-local drain 安全並行（改不同列：drain 翻
#     complete=0 缺章、校閱升 complete=1 草稿章）。自己一把 ab_review_queue per-key flock 去重。
#   - 成本＝claude 訂閱池 + agy 援，**非按 call 計費**（見 feedback_audiobook_use_agy_pipeline）；
#     只校機械中標段（每章 ~5 段）故 token 量極小（清完整 backlog ~160k token）。序列跑不炸週限額。
#
# 為何 USER 服務：同 audiobook-queue——只讀寫 richard 家目錄（live DB、suspect manifest）、
# 復用 repo checkout 的 Python 工具、claude/agy 在 ~/.bun/bin·~/.local/bin（user 自裝）、不需特權。
# 暫停＝`systemctl --user stop audiobook-review.timer`（零 sudo）。

let
  repo = "/home/richard/gen-ui-hub";
  reviewQueue = "${repo}/tools/audiobook-tl/ab_review_queue.py";
  liveDb = "${repo}/docs/hub.db";   # live DB；根目錄三 .db 是假檔（見 ref_delegate_job_ops）

  # claude/agy 是 user 自裝二進位（非 nix 套件）；ab_review.py 預設 bare command 靠 PATH 解，
  # 但 systemd user unit 的 PATH 不含這兩個 dir → 顯式經 env 傳絕對路徑（鏡像 Go 端
  # findClaudePath/findAgyPath 的作法），不靠 PATH 找 CLI。
  claudeBin = "/home/richard/.bun/bin/claude";
  agyBin = "/home/richard/.local/bin/agy";

  # 每輪最多校幾章。校閱 ~12s/章（只校 ~5 中標段），drain 每日約產出數十章草稿 → 一輪 30
  # 足以清掉前一日 backlog；清完即自動空轉收工。可調。
  maxPerRun = 30;
in
{
  # oneshot：純由 timer 觸發，不常駐、不開機自啟。
  systemd.user.services.audiobook-review = {
    description = "有聲書自動校閱佇列 — claude/agy 校定 draft 升 verified（離峰批次）";

    # python3 跑佇列（純 stdlib）；curl 給 SSL CA（claude/agy 自帶 HTTPS，但留 CA bundle 保險）。
    path = [ pkgs.python3 pkgs.curl ];

    environment = {
      SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      AB_REVIEW_CLAUDE_BIN = claudeBin;
      AB_REVIEW_AGY_BIN = agyBin;
    };

    serviceConfig = {
      Type = "oneshot";
      WorkingDirectory = "${repo}/tools/audiobook-tl";
      # --all-ncodes 跨書清全部草稿；--max 封頂單輪量（自然封頂於 draft 數）。
      ExecStart = "${pkgs.python3}/bin/python3 ${reviewQueue} ${liveDb} --all-ncodes --max ${toString maxPerRun}";

      # 瘦 client（subprocess orchestration + 等雲端回應）的 cgroup 旋鈕，純防腳本失控。
      # MemoryMax 給 2G＝容 claude headless 的 node 進程（非校閱 inference，那在雲端）。
      Nice = 19;
      CPUWeight = 20;
      IOSchedulingClass = "idle";
      MemoryMax = "2G";

      # 硬牆：30 章 × 每章數分鐘上限，給 2h 餘裕；逐章子進程隔離＝中斷無半成品（章未升即留 draft、
      # 下輪重校），故砍掉安全。
      RuntimeMaxSec = "2h";
    };
  };

  systemd.user.timers.audiobook-review = {
    description = "有聲書自動校閱排程（每日離峰一輪）";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # 每日 05:30 一輪（drain 整夜產出的草稿，清晨一次校完）。走雲端不卡 TTS、不挑硬離峰窗。
      OnCalendar = "05:30";
      RandomizedDelaySec = "10min";
      # 不補跑：關機錯過等明天；正在跑時觸發自動略過（同 unit 不疊跑）。
      Persistent = false;
      Unit = "audiobook-review.service";
    };
  };
}
