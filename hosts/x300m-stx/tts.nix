{ config, pkgs, ... }:

# TTS sidecar — Kokoro 本機語音合成(gen-ui-hub Phase 11.2 的「嘴巴」後端)。
#
# 與 stt.nix(耳朵)對稱:開機即起、綁 localhost、hub 同機呼叫不對外。合成完全在地
# (零按量雲端成本),雲端 Gemini Live TTS 只在 hub 端當 sidecar 不可用時的低頻 fallback。
#
# 嗓音定值(用戶 A/B 試聽選定):Kokoro 女聲 zf_xiaoxiao —— 比舊 Piper huayan 自然
# (用戶嫌 Piper 機械)。中文 G2P 走 misaki[zh](kokoro-onnx 內建 espeak 不支援中文)。
# 介面與舊 Piper sidecar 一致:POST / 帶 {"text": "..."} → 回 audio/wav,hub 端零改。
#
# 打包(用戶選「pinned uv venv」):Kokoro 與 misaki 都不在 nixpkgs,故不走純 Nix,
# 改用 uv 從鎖死的 pyproject.toml + uv.lock 建 venv。base python 用 nixpkgs python312
# (非 uv 自下載),wheel 的 native .so(onnxruntime/libstdc++ 等)靠 LD_LIBRARY_PATH 指
# 進 nix store 解決 —— 不必開全域 nix-ld。模型檔仍走 fetchurl pin(下方)。

let
  # Kokoro v1.0 權重 + voices(zf_xiaoxiao 等含在 voices bin)。兩檔各自 fetchurl 後
  # 組進單一 store path,server.py 以 KOKORO_MODEL/KOKORO_VOICES 環境變數指過去。
  ttsModelDir = pkgs.stdenvNoCC.mkDerivation {
    pname = "kokoro-onnx-model";
    version = "1.0.0";
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    onnx = pkgs.fetchurl {
      url = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx";
      hash = "sha256-fV347PfUsYeAFaMmhgU/0O6+K8N3I0YIdkzA7zY2psU=";
    };
    voices = pkgs.fetchurl {
      url = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin";
      hash = "sha256-vKYQuDCOjZnzLm/kGX5+wBZ5Jk7+0MrJFA/pwp8fv30=";
    };
    installPhase = ''
      mkdir -p $out
      cp $onnx   $out/kokoro-v1.0.onnx
      cp $voices $out/voices-v1.0.bin
    '';
  };

  # server.py + pyproject.toml + uv.lock(進 store)。
  src = ./tts-sidecar;

  pyBase = pkgs.python312;

  # manylinux wheel 的 native .so 執行期要找得到的共用庫(onnxruntime 要 libstdc++/
  # libgcc_s/libgomp,都在 cc.cc.lib;zlib 常用)。LD_LIBRARY_PATH 注入,免開 nix-ld。
  libPath = pkgs.lib.makeLibraryPath [
    pkgs.stdenv.cc.cc.lib
    pkgs.zlib
  ];

  # 可寫工作目錄。刻意「不用」systemd StateDirectory/CacheDirectory:非 root user 的
  # 那些目錄走 idmapped bind-mount、被強制 nosuid,nodev,noexec,venv 裡編譯出的原生 .so
  # 無法 mmap-exec → numpy「failed to map segment」(DynamicUser 與靜態 User 皆中)。改用
  # tmpfiles 自管目錄 + ReadWritePaths 暴露給服務,該掛載是純 rw,relatime(可執行)。
  stateDir = "/var/lib/tts-sidecar";

  # ExecStartPre:把鎖檔/原始碼放進 stateDir,uv 從 lock 建 venv(--frozen 不改 lock;
  # 首跑下載 wheel 需網路,之後走 UV_CACHE_DIR)。
  syncScript = pkgs.writeShellScript "tts-sidecar-sync" ''
    set -eu
    install -m644 ${src}/pyproject.toml ./pyproject.toml
    install -m644 ${src}/uv.lock        ./uv.lock
    install -m644 ${src}/server.py       ./server.py
    ${pkgs.uv}/bin/uv sync --frozen --no-dev
  '';
in
{
  systemd.services.tts-sidecar = {
    description = "gen-ui-hub TTS sidecar — Kokoro 本機語音合成 (127.0.0.1:8232)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    environment = {
      KOKORO_MODEL = "${ttsModelDir}/kokoro-v1.0.onnx";
      KOKORO_VOICES = "${ttsModelDir}/voices-v1.0.bin";
      TTS_HOST = "127.0.0.1";
      TTS_PORT = "8232";
      LD_LIBRARY_PATH = libPath;
      # uv 用 nixpkgs python、絕不自己下載 interpreter。
      UV_PYTHON = "${pyBase}/bin/python3.12";
      UV_PYTHON_DOWNLOADS = "never";
      UV_NO_PROGRESS = "1";
      # 靜態 tts user 無登入 $HOME → 指到 stateDir;uv cache 收進同一可寫樹(同理避開
      # CacheDirectory 的 idmapped noexec)。
      HOME = stateDir;
      UV_CACHE_DIR = "${stateDir}/.uv-cache";
      # venv .so 與 cache 各自獨立複本(非 hardlink),省去跨檔案系統共享 inode 的眉角。
      UV_LINK_MODE = "copy";
    };

    serviceConfig = {
      Type = "simple";
      WorkingDirectory = stateDir;
      # 用 ReadWritePaths 暴露自管目錄(見上方 stateDir 註解:不走 StateDirectory 以避開
      # 非 root user 的 idmapped noexec 掛載)。目錄由下方 tmpfiles 宣告式建立。
      ReadWritePaths = [ stateDir ];
      ExecStartPre = syncScript;
      # 直接跑 venv python(不經 uv run,免執行期再對 lock/網路)。
      ExecStart = "${stateDir}/.venv/bin/python server.py";
      Restart = "on-failure";
      RestartSec = 5;
      # CPU 軟優先：播放時搶贏背景翻譯（ollama CPUWeight=20，見 configuration.nix）。
      # TTS 是脈衝式（合成 ~1s → 播放數秒 TTS 閒置），高權重確保每次合成即時搶到核、
      # 播放順不卡。實測：翻譯吃滿核時 TTS 仍 ~1.1s/句（無此權重時被拖到 3.0s）。
      CPUWeight = 1000;
      # 無對外、只寫自管目錄 → 靜態系統使用者 + 收緊權限。
      # 不用 DynamicUser:它(及任何非 root User)的 StateDirectory 走 idmapped bind-mount
      # 會帶 noexec,venv 編譯出的原生 .so 無法 mmap-exec → numpy「failed to map segment」。
      # (STT 沒中招是因為它整包 python env 在 /nix/store=exec,沒落可寫 StateDirectory。)
      User = "tts";
      Group = "tts";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
    };
  };

  # venv/cache 落腳的可寫目錄(取代 StateDirectory,見上方 stateDir 註解)。
  systemd.tmpfiles.rules = [ "d /var/lib/tts-sidecar 0750 tts tts -" ];

  # tts.nix 專屬靜態系統使用者(取代 DynamicUser,見上方 serviceConfig 註解)。
  users.groups.tts = { };
  users.users.tts = {
    isSystemUser = true;
    group = "tts";
    description = "gen-ui-hub TTS sidecar";
  };
}
