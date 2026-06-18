#!/usr/bin/env python3
"""STT sidecar — SenseVoice 本機轉錄,OpenAI-compatible /v1/audio/transcriptions。

gen-ui-hub Phase 11.4 的「耳朵」後端:client 端 VAD 切句後上送一段音訊,
這裡用 sherpa-onnx + SenseVoice(fp32)離線轉錄成文字,回 {"text": ...}。
介面刻意與 OpenAI Audio API 同形 → hub 代理過來幾乎不必改,雲端(Gemini Live)
當 fallback 也自然。只做 I/O、不做決定、不碰硬體(Phase 11 邊界)。

模型走 fp32(model.onnx):實機驗證 int8 會吞掉連續英文技術詞(forward PE/PEG),
fp32 代價僅 +0.1s 無感 → 用 fp32。見 gen-ui-hub TODO.md 11.4「實機驗證」。

環境變數(systemd 注入):
  STT_MODEL_DIR  解開的 SenseVoice 模型目錄(含 model.onnx / tokens.txt)
  STT_HOST       預設 127.0.0.1
  STT_PORT       預設 8231
  STT_THREADS    onnxruntime intra-op 緒數,預設 6
  FFMPEG         ffmpeg 執行檔路徑(解碼任意輸入格式 → 16k mono PCM)
"""
import os
import subprocess

import numpy as np
import sherpa_onnx
import uvicorn
from fastapi import FastAPI, HTTPException, UploadFile

MODEL_DIR = os.environ["STT_MODEL_DIR"]
HOST = os.environ.get("STT_HOST", "127.0.0.1")
PORT = int(os.environ.get("STT_PORT", "8231"))
THREADS = int(os.environ.get("STT_THREADS", "6"))
FFMPEG = os.environ.get("FFMPEG", "ffmpeg")
SAMPLE_RATE = 16000

app = FastAPI(title="gen-ui-hub STT sidecar (SenseVoice)")
_recognizer: sherpa_onnx.OfflineRecognizer | None = None


def recognizer() -> sherpa_onnx.OfflineRecognizer:
    # 啟動時建一次,全域複用(模型載入慢、推理本身快)。
    global _recognizer
    if _recognizer is None:
        _recognizer = sherpa_onnx.OfflineRecognizer.from_sense_voice(
            model=os.path.join(MODEL_DIR, "model.onnx"),  # fp32,非 int8
            tokens=os.path.join(MODEL_DIR, "tokens.txt"),
            num_threads=THREADS,
            use_itn=True,        # 數字/標點正規化(「8点」→「八点」之類)
            language="auto",     # 中英混講自動,不鎖單一語言
        )
    return _recognizer


def decode_to_pcm(raw: bytes) -> np.ndarray:
    """任意輸入(webm/opus、wav、mp3、m4a…)→ 16k mono float32。

    瀏覽器 MediaRecorder 多半吐 webm/opus,sherpa-onnx 只吃裸 PCM,
    交給 ffmpeg 通吃解碼最穩(不引 libsndfile / PyAV)。
    """
    proc = subprocess.run(
        [FFMPEG, "-loglevel", "error", "-i", "pipe:0",
         "-f", "s16le", "-ac", "1", "-ar", str(SAMPLE_RATE), "pipe:1"],
        input=raw, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    if proc.returncode != 0:
        raise HTTPException(status_code=400,
                            detail=f"ffmpeg decode failed: {proc.stderr.decode(errors='replace')[:200]}")
    return np.frombuffer(proc.stdout, dtype=np.int16).astype(np.float32) / 32768.0


@app.get("/health")
def health():
    return {"status": "ok", "model": "sense-voice-fp32", "sample_rate": SAMPLE_RATE}


@app.post("/v1/audio/transcriptions")
async def transcribe(file: UploadFile):
    raw = await file.read()
    if not raw:
        raise HTTPException(status_code=400, detail="empty audio")
    samples = decode_to_pcm(raw)
    if samples.size == 0:
        raise HTTPException(status_code=400, detail="no audio samples after decode")
    rec = recognizer()
    stream = rec.create_stream()
    stream.accept_waveform(SAMPLE_RATE, samples)
    rec.decode_stream(stream)
    return {"text": stream.result.text}


if __name__ == "__main__":
    recognizer()  # 開機就載模型,別等第一個請求才付延遲
    uvicorn.run(app, host=HOST, port=PORT, log_level="info")
