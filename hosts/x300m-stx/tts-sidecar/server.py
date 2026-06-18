#!/usr/bin/env python3
"""kokoro-onnx TTS sidecar — gen-ui-hub Phase 11.2 的「嘴巴」後端(取代 Piper)。

介面與舊 Piper sidecar 一致:POST / 帶 {"text": "..."} → 回 audio/wav。hub 端
(handleVoiceSpeak)零改。嗓音定值:Kokoro 女聲 zf_xiaoxiao(用戶 A/B 試聽選定,
比 Piper huayan 自然)。中文 G2P 走 misaki[zh](onnx 內建 espeak 不支援中文)。

啟動參數(環境變數,給 systemd 設):
  KOKORO_MODEL   kokoro-v1.0.onnx 路徑
  KOKORO_VOICES  voices-v1.0.bin 路徑
  TTS_HOST/TTS_PORT  預設 127.0.0.1:8232
模型/G2P 在啟動時載入一次,請求只做合成。
"""
import io
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import soundfile as sf
from kokoro_onnx import Kokoro
from misaki import zh

VOICE = "zf_xiaoxiao"
SPEED = 1.0

MODEL = os.environ.get("KOKORO_MODEL", "kokoro-v1.0.onnx")
VOICES = os.environ.get("KOKORO_VOICES", "voices-v1.0.bin")
HOST = os.environ.get("TTS_HOST", "127.0.0.1")
PORT = int(os.environ.get("TTS_PORT", "8232"))

print(f"[tts] loading kokoro model={MODEL} voices={VOICES}", flush=True)
_kokoro = Kokoro(MODEL, VOICES)
_g2p = zh.ZHG2P()
print("[tts] ready", flush=True)


def synth_wav(text: str) -> bytes:
    phonemes, _ = _g2p(text)
    samples, sr = _kokoro.create(phonemes, voice=VOICE, speed=SPEED, is_phonemes=True)
    buf = io.BytesIO()
    sf.write(buf, samples, sr, format="WAV", subtype="PCM_16")
    return buf.getvalue()


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body=b"", ctype="text/plain"):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if body:
            self.wfile.write(body)

    def do_GET(self):
        # 健康探測(hub /api/voice/health 對稱用得上)。
        if self.path == "/health":
            self._send(200, b'{"ok":true}', "application/json")
        else:
            self._send(404, b"not found")

    def do_POST(self):
        try:
            n = int(self.headers.get("Content-Length", "0"))
            payload = json.loads(self.rfile.read(n) or b"{}")
            text = (payload.get("text") or "").strip()
            if not text:
                self._send(400, b"empty text")
                return
            self._send(200, synth_wav(text), "audio/wav")
        except Exception as e:  # noqa: BLE001
            self._send(500, f"synth failed: {e}".encode())

    def log_message(self, *a):  # 靜音預設 access log
        pass


if __name__ == "__main__":
    print(f"[tts] serving on {HOST}:{PORT}", flush=True)
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
