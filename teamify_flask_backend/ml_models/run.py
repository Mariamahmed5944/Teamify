"""
Teamify - Speech-to-Text Module
================================
A FastAPI-based backend that uses OpenAI Whisper to transcribe
audio files into text. Supports English and Arabic languages.
"""

import os
import time
import tempfile
import logging
from pathlib import Path

import whisper
import uvicorn
from fastapi import FastAPI, File, UploadFile, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from text_cleaner import clean_and_normalize

# ── Logging setup ────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)

# ── App & CORS ────────────────────────────────────────────────────────────────
app = FastAPI(
    title="Teamify Speech-to-Text API",
    description="Convert audio to text using OpenAI Whisper. Supports English & Arabic.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],          # Tighten this in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Whisper model ─────────────────────────────────────────────────────────────
# "base" gives a good speed/accuracy balance for mobile use.
# Options (slowest → fastest): large | medium | small | base | tiny
MODEL_NAME = os.getenv("WHISPER_MODEL", "base")

logger.info(f"Loading Whisper model: '{MODEL_NAME}' — this may take a moment…")
model = whisper.load_model(MODEL_NAME)
logger.info("Whisper model loaded ✓")

# Allowed audio MIME types
ALLOWED_TYPES = {
    "audio/mpeg", "audio/mp3", "audio/wav", "audio/x-wav",
    "audio/ogg", "audio/webm", "audio/mp4", "audio/m4a",
    "audio/flac", "audio/aac", "video/webm",          # webm mic recordings
}

# Supported language codes
SUPPORTED_LANGUAGES = {"en": "English", "ar": "Arabic"}


# ── Health check ──────────────────────────────────────────────────────────────
@app.get("/health", tags=["System"])
def health_check():
    """Quick liveness probe for load balancers / mobile clients."""
    return {"status": "ok", "model": MODEL_NAME}


# ── Transcription endpoint ────────────────────────────────────────────────────
@app.post("/transcribe", tags=["Speech-to-Text"])
async def transcribe_audio(
    file: UploadFile = File(..., description="Audio file to transcribe"),
    language: str = Query(
        default="en",
        description="Language code: 'en' for English, 'ar' for Arabic",
    ),
    task: str = Query(
        default="transcribe",
        description="'transcribe' keeps the original language; 'translate' converts to English",
    ),
):
    """
    Upload an audio file and receive the transcribed text as JSON.

    - **file**: Any common audio format (mp3, wav, ogg, webm, m4a, flac …)
    - **language**: `en` (English) or `ar` (Arabic)
    - **task**: `transcribe` or `translate`
    """

    # ── Validate language ────────────────────────────────────────────────────
    if language not in SUPPORTED_LANGUAGES:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported language '{language}'. Choose from: {list(SUPPORTED_LANGUAGES.keys())}",
        )

    # ── Validate task ────────────────────────────────────────────────────────
    if task not in ("transcribe", "translate"):
        raise HTTPException(
            status_code=400,
            detail="Invalid task. Use 'transcribe' or 'translate'.",
        )

    # ── Validate content type ────────────────────────────────────────────────
    content_type = (file.content_type or "").lower()
    if content_type not in ALLOWED_TYPES:
        # Be lenient: some mobile browsers send generic types
        logger.warning(f"Unrecognised content-type '{content_type}' — proceeding anyway.")

    logger.info(f"Received file: {file.filename!r} | lang={language} | task={task}")

    # ── Save upload to a temp file ───────────────────────────────────────────
    suffix = Path(file.filename).suffix if file.filename else ".audio"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp_path = tmp.name
        contents = await file.read()
        tmp.write(contents)

    try:
        start = time.perf_counter()

        # ── Run Whisper ──────────────────────────────────────────────────────
        # fp16=False avoids warnings on CPU-only machines
        result = model.transcribe(
            tmp_path,
            language=language,
            task=task,
            fp16=False,
            verbose=False,
        )

        elapsed = round(time.perf_counter() - start, 3)

        raw_text = result.get("text", "").strip()

        # ── Clean & normalise ────────────────────────────────────────────────
        clean_text = clean_and_normalize(raw_text, language=language)

        logger.info(f"Transcription done in {elapsed}s | chars={len(clean_text)}")

        return JSONResponse(
            content={
                "success": True,
                "language": language,
                "language_name": SUPPORTED_LANGUAGES[language],
                "task": task,
                "raw_text": raw_text,
                "text": clean_text,
                "processing_time_seconds": elapsed,
                "model": MODEL_NAME,
                "filename": file.filename,
            }
        )

    except Exception as exc:
        logger.exception("Transcription failed")
        raise HTTPException(status_code=500, detail=f"Transcription error: {str(exc)}")

    finally:
        # Always clean up the temp file
        os.unlink(tmp_path)


import webbrowser
import threading

def open_browser():
    # بنعمل تأخير ثانية واحدة عشان السيرفر يلحق يقوم
    import time
    time.sleep(1)
    webbrowser.open("http://127.0.0.1:8000/docs")

if __name__ == "__main__":
    # تشغيل المتصفح في الخلفية
    threading.Thread(target=open_browser).start()
    
    print("🚀 Server is starting... Browser will open automatically!")
    uvicorn.run("run:app", host="127.0.0.1", port=8000, reload=True)