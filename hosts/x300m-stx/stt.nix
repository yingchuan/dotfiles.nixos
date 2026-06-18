{ config, pkgs, ... }:

# STT sidecar — SenseVoice 本機轉錄(gen-ui-hub Phase 11.4 的「耳朵」後端)。
#
# 與 services.ollama 同位階:純宣告式、Nix 全管、開機即起、綁 localhost,hub 同機
# 呼叫不對外。刻意做 system service(非 gen-ui-hub 那種 user service)——它不像
# hub binary 要手動 build/部署,整包(python env + 腳本 + 模型)都在 /nix/store,
# nixos-rebuild 一把產出 + 原子切換,沒有「零 sudo 重啟」的部署迴路需求。
#
# 介面 OpenAI-compatible(/v1/audio/transcriptions),fp32 模型(int8 吞英文技術詞)。
# 詳見 hosts/x300m-stx/stt_server.py 與 gen-ui-hub TODO.md 11.4。

let
  # SenseVoice ONNX 模型(中英日韓粵)。只取 fp32 model.onnx + tokens.txt 進 store
  # (丟掉 int8 229M 與 export 腳本),由 STT_MODEL_DIR 指給 sidecar。
  sttModel = pkgs.stdenvNoCC.mkDerivation {
    pname = "sense-voice-onnx";
    version = "2024-07-17";
    src = pkgs.fetchurl {
      url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17.tar.bz2";
      sha256 = "06m7kr5yv5dss2cj2z35qjajmjvbds4cvz2c9mv7mb5iphpagcpn";
    };
    dontConfigure = true;
    dontBuild = true;
    # stdenv 解開單一目錄 tar 後 cwd 已是該 sourceRoot,直接 cp。
    installPhase = ''
      mkdir -p $out
      cp model.onnx  $out/model.onnx
      cp tokens.txt  $out/tokens.txt
    '';
  };

  # nixpkgs 1.12.38 已驗 API 相容、從 /nix/store 載入(不碰 uv/nix-ld)。
  # python-multipart 是 FastAPI UploadFile 解析 multipart form 所需。
  pyEnv = pkgs.python3.withPackages (ps: with ps; [
    sherpa-onnx
    numpy
    fastapi
    uvicorn
    python-multipart
  ]);
in
{
  systemd.services.stt-sidecar = {
    description = "gen-ui-hub STT sidecar — SenseVoice 本機轉錄 (127.0.0.1:8231)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    environment = {
      STT_MODEL_DIR = "${sttModel}";
      FFMPEG = "${pkgs.ffmpeg}/bin/ffmpeg";
      STT_HOST = "127.0.0.1";
      STT_PORT = "8231";
      STT_THREADS = "6";
    };
    serviceConfig = {
      ExecStart = "${pyEnv}/bin/python ${./stt_server.py}";
      # 無狀態、只讀 store、綁 localhost → 動態使用者 + 收緊權限。
      DynamicUser = true;
      Restart = "on-failure";
      RestartSec = 3;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };
}
