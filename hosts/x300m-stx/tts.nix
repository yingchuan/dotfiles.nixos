{ config, pkgs, ... }:

# TTS sidecar — Piper 本機語音合成(gen-ui-hub Phase 11.2 的「嘴巴」後端)。
#
# 與 stt.nix(耳朵)對稱:純宣告式、Nix 全管、開機即起、綁 localhost,hub 同機
# 呼叫不對外。合成完全在地(零按量雲端成本),雲端 Gemini Live TTS 只在 hub 端
# 當 sidecar 不可用時的低頻 fallback。詳見 gen-ui-hub TODO.md 11.2。
#
# 嗓音定值(用戶 A/B 試聽選定):huayan-medium 女聲原色 + length-scale 1.2(微慢)。
# 不降調、不過 ffmpeg —— sidecar 內就一個 piper http_server,零後處理。
#
# 介面:piper 內建 flask http server(POST / 帶 {"text": "..."} → 回 audio/wav)。

let
  # Piper 官方中文女聲(huayan medium)。onnx + 同名 .json 必須並置同一目錄,
  # piper 以 -m 指 onnx、自動讀旁邊的 .json。兩檔各自 fetchurl 後組進單一 store path。
  ttsVoiceDir = pkgs.stdenvNoCC.mkDerivation {
    pname = "piper-voice-zh-huayan-medium";
    version = "1.0.0";
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    onnx = pkgs.fetchurl {
      url = "https://huggingface.co/rhasspy/piper-voices/resolve/main/zh/zh_CN/huayan/medium/zh_CN-huayan-medium.onnx";
      hash = "sha256-mSmRe/jKuyb9Uo6kTTpmmcEehzF6FHZTEkIL4jC+Dz0=";
    };
    config = pkgs.fetchurl {
      url = "https://huggingface.co/rhasspy/piper-voices/resolve/main/zh/zh_CN/huayan/medium/zh_CN-huayan-medium.onnx.json";
      hash = "sha256-1SHcRVBKjMyZ4yWCKzWUbdcBhAv7B+PbsxpAkp7WqCs=";
    };
    installPhase = ''
      mkdir -p $out
      cp $onnx   $out/zh_CN-huayan-medium.onnx
      cp $config $out/zh_CN-huayan-medium.onnx.json
    '';
  };

  # piper-tts 是 top-level buildPythonApplication(不在 python3Packages),用
  # toPythonModule 轉回 module 才能進 withPackages 組出含全 deps 的 python 環境,
  # 以執行非預設入口 `python -m piper.http_server`(piper bin wrapper 只跑 -m piper)。
  pyEnv = pkgs.python3.withPackages (ps: [ (ps.toPythonModule pkgs.piper-tts) ]);
in
{
  systemd.services.tts-sidecar = {
    description = "gen-ui-hub TTS sidecar — Piper 本機語音合成 (127.0.0.1:8232)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = ''
        ${pyEnv}/bin/python -m piper.http_server \
          --model ${ttsVoiceDir}/zh_CN-huayan-medium.onnx \
          --host 127.0.0.1 --port 8232 \
          --length-scale 1.2
      '';
      # 無狀態、只讀 store、綁 localhost → 動態使用者 + 收緊權限(同 stt-sidecar)。
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
