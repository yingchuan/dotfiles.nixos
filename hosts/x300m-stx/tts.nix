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

  # ExecStartPre:把鎖檔/原始碼放進可寫的 StateDirectory,uv 從 lock 建 venv(--frozen
  # 不改 lock;首跑下載 wheel 需網路,之後走 CacheDirectory)。
  syncScript = pkgs.writeShellScript "tts-sidecar-sync" ''
    set -eu
    install -m644 ${src}/pyproject.toml ./pyproject.toml
    install -m644 ${src}/uv.lock        ./uv.lock
    install -m644 ${src}/server.py       ./server.py
    # 一次性遷移:舊 venv 是 hardlink 模式(沙箱裡 .so mmap 失敗)。沒有 copy 模式
    # 標記就砍掉重建,讓下面的 uv sync 以 UV_LINK_MODE=copy 放獨立複本。
    if [ ! -e .venv/.copymode ]; then
      rm -rf .venv
    fi
    ${pkgs.uv}/bin/uv sync --frozen --no-dev
    touch .venv/.copymode
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
      # DynamicUser 沒有真 $HOME → 指到 StateDirectory,uv cache 指 CacheDirectory。
      HOME = "%S/tts-sidecar";
      UV_CACHE_DIR = "%C/tts-sidecar";
      # uv 預設 hardlink venv .so 到 cache(共享 inode);在 systemd 沙箱 namespace 下
      # 後段 PT_LOAD segment mmap 會失敗(numpy .so「failed to map segment」)。改 copy
      # 模式放獨立複本,沙箱外能跑、沙箱內也能跑。
      UV_LINK_MODE = "copy";
    };

    serviceConfig = {
      Type = "simple";
      StateDirectory = "tts-sidecar";
      CacheDirectory = "tts-sidecar";
      WorkingDirectory = "%S/tts-sidecar";
      ExecStartPre = syncScript;
      # 直接跑 venv python(不經 uv run,免執行期再對 lock/網路)。
      ExecStart = "%S/tts-sidecar/.venv/bin/python server.py";
      Restart = "on-failure";
      RestartSec = 5;
      # 無對外、只寫 state/cache → 動態使用者 + 收緊權限(比照 stt/舊 tts)。
      DynamicUser = true;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
    };
  };
}
