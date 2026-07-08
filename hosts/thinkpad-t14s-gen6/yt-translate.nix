{ config, pkgs, lib, ... }:

# yt-translate — YouTube 英文技術影片雙語字幕服務(thinkpad NPU 首個落地應用)。
# 抓 YouTube 英文自動字幕 → 句子重組 → NPU(lemonade qwen3-8b + 技術詞表)翻繁中 →
# Tampermonkey userscript 疊雙語字幕。全本機:yt-dlp 抓字幕 + lemond NPU 翻譯,不碰
# x300m、不用 STT。詳見 ~/yt-translate/README.md 與記憶 project_yt_translate。
#
# 為什麼是 USER 服務(非 system):只讀寫 richard 家目錄(~/yt-translate/cache、glossary)、
# 對 lemond(:13305)發 HTTP、不需特權。配 linger(見下)開機即起、免登入。零 sudo 運維:
#   build:  cd ~/yt-translate && go build -o yt-translate .
#   重啟:  systemctl --user restart yt-translate
# 這沿用 gen-ui-hub 的既有慣例(service 指向本機 build 的 binary、快速迭代免 sudo rebuild)。
# 待穩定後可升級成 buildGoModule 純宣告式(yt-translate 零外部 Go 依賴、vendorHash 好處理),
# 但開發期用 binary 路徑迭代最省摩擦。

let
  repo = "/home/richard/yt-translate";
  bin = "${repo}/yt-translate";
in
{
  # yt-dlp 也放 systemPackages 方便 CLI 直接用(抓字幕、debug);服務自身另走 unit path。
  environment.systemPackages = [ pkgs.yt-dlp ];

  systemd.user.services.yt-translate = {
    description = "yt-translate — YouTube 雙語字幕(NPU qwen3-8b 翻譯,:8477)";
    wantedBy = [ "default.target" ];   # 開機/登入即起(配 linger 免登入也起)
    after = [ "network.target" ];

    # yt-dlp 宣告式注入 unit PATH(服務靠它抓字幕),免程式碼 fallback 的 `nix run` 冷啟延遲。
    # bash 必須也在:服務用 `sh -c` 呼叫 yt-dlp(容多字 YTT_YTDLP),systemd user service
    # 的 PATH 極簡不含 sh,漏了會 `exec: "sh": not found`(手動跑有互動 shell 才沒事)。
    path = [ pkgs.yt-dlp pkgs.bash ];

    environment = {
      # unit path 已有 yt-dlp,直接用命令名(蓋掉程式預設的 `nix run nixpkgs#yt-dlp --`)。
      YTT_YTDLP = "yt-dlp";
      # lemond OpenAI 相容端點(本機 NPU),與 hardware.amd-npu 的 lemonade 預設 port 一致。
      YTT_NPU = "http://localhost:13305/api/v1";
      YTT_MODEL = "qwen3-8b-FLM";
      # yt-dlp 抓 YouTube HTTPS 要 CA bundle(user env 全系統沒設,同 audiobook-queue 理)。
      SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    };

    serviceConfig = {
      Type = "simple";
      WorkingDirectory = repo;
      ExecStart = bin;
      Restart = "on-failure";
      RestartSec = 3;
    };

    # binary 尚未 build(首次部署)時別無限重啟刷 log;失敗計數上限後停手,build 完手動起。
    # 屬 [Unit] 段(非 serviceConfig=[Service]),故走 unitConfig。
    unitConfig = {
      StartLimitIntervalSec = 60;
      StartLimitBurst = 3;
    };
  };

  # user service 開機即起、免登入(等價 `loginctl enable-linger richard`,宣告式)。
  users.users.richard.linger = true;
}
