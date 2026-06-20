#!/usr/bin/env python3
"""kokoro-onnx TTS sidecar — gen-ui-hub Phase 11.2 的「嘴巴」後端(取代 Piper)。

介面與舊 Piper sidecar 一致:POST / 帶 {"text": "..."} → 回 audio/wav。hub 端
(handleVoiceSpeak)零改。嗓音定值:Kokoro 女聲 zf_xiaoxiao(用戶 A/B 試聽選定,
比 Piper huayan 自然)。

G2P(中英混句):**中文走 misaki[zh] legacy IPA**(onnx 內建 espeak 不支援中文)、
**英文段走 kokoro 內建 espeak phonemizer**,兩者皆為 Kokoro vocab 內的音素、拼成
一串以 zf_xiaoxiao 單一聲線念(英文帶中文口音但可懂)。
踩坑:曾試 misaki version='1.1' + en_callable 想一次解英文,但 1.1 ZHFrontend 在此版
會把部分中文韻母漏成「生漢字」(阴/言/十…)→ 出 vocab → 中文幾乎發不出聲(「耶一聲就沒」)。
故改回 legacy 中文(原本就 OK)+ 自己分段把英文字詞抽出走 espeak,不碰 1.1 前端。

啟動參數(環境變數,給 systemd 設):
  KOKORO_MODEL   kokoro-v1.0.onnx 路徑
  KOKORO_VOICES  voices-v1.0.bin 路徑
  TTS_HOST/TTS_PORT  預設 127.0.0.1:8232
模型/G2P 在啟動時載入一次,請求只做合成。
"""
import io
import json
import os
import re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import cn2an
import jieba
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
print("[tts] ready", flush=True)

# 英文字詞:一段連續的拉丁字母(允許內含 ' 與 -,如 don't / e-mail)。逐詞丟 kokoro
# 內建 espeak phonemizer 轉 IPA(回傳已濾成 Kokoro vocab 的音素);標點/空白/數字原樣留。
_EN_WORD = re.compile(r"[A-Za-z][A-Za-z'\-]*")
# 漢字區段(對齊 misaki legacy_call 的切法)。
_ZH_RUN = re.compile(r"[一-鿿]+|[^一-鿿]+")


def _en_to_ipa(m: "re.Match") -> str:
    return _kokoro.tokenizer.phonemize(m.group(0), lang="en-us")


def text_to_phonemes(text: str) -> str:
    """中英混句 → Kokoro 音素串。中文沿用 misaki[zh] legacy IPA(原本就 OK),非中文段
    把英文字詞換 espeak IPA、其餘(標點/空白/數字符)原樣保留。刻意不走 misaki 1.1
    前端(會漏生漢字弄壞中文,見模組註解)。前處理(數字轉中文 + 標點正規化)沿用 misaki。"""
    text = cn2an.transform(text, "an2cn")
    text = zh.ZHG2P.map_punctuation(text)
    if not text:
        return ""
    is_zh = bool(re.match(r"[一-鿿]", text[0]))
    out = []
    for seg in _ZH_RUN.findall(text):
        if is_zh:
            words = jieba.lcut(seg, cut_all=False)
            out.append(" ".join(zh.ZHG2P.word2ipa(w) for w in words))
        else:
            out.append(_EN_WORD.sub(_en_to_ipa, seg))
        is_zh = not is_zh
    return "".join(out).replace(chr(815), "")


def synth_wav(text: str) -> bytes:
    phonemes = text_to_phonemes(text)
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
