"""
test_api.py — Teamify STT
==========================
A standalone test script that:
  1. Generates a short WAV audio file using TTS (gTTS) or a sine-wave tone.
  2. Posts it to the running /transcribe endpoint.
  3. Prints the JSON response.

Run AFTER starting the server:
    python app.py          # terminal 1
    python test_api.py     # terminal 2
"""

import sys
import wave
import struct
import math
import requests

# ── Configuration ─────────────────────────────────────────────────────────────
BASE_URL  = "http://localhost:8000"
AUDIO_OUT = "test_sample.wav"       # generated test file

# ── 1. Generate a simple sine-wave WAV (works without any TTS library) ────────

def generate_sine_wav(filename: str, freq: float = 440.0, duration: float = 2.0,
                      sample_rate: int = 16_000) -> None:
    """
    Write a pure-tone WAV file.
    Whisper will transcribe silence/tones as empty or near-empty text — that's
    fine for a connectivity / pipeline test.
    Use a real recorded .wav/.mp3 for meaningful transcription output.
    """
    n_samples  = int(sample_rate * duration)
    amplitude  = 32767  # max 16-bit signed

    with wave.open(filename, "w") as wf:
        wf.setnchannels(1)           # mono
        wf.setsampwidth(2)           # 16-bit
        wf.setframerate(sample_rate)
        for i in range(n_samples):
            value = int(amplitude * math.sin(2 * math.pi * freq * i / sample_rate))
            wf.writeframes(struct.pack("<h", value))

    print(f"[✓] Generated test WAV → {filename}")


# ── 2. Helper: post audio to /transcribe ──────────────────────────────────────

def transcribe(audio_path: str, language: str = "en", task: str = "transcribe") -> dict:
    url = f"{BASE_URL}/transcribe?language={language}&task={task}"
    with open(audio_path, "rb") as f:
        response = requests.post(
            url,
            files={"file": (audio_path, f, "audio/wav")},
            timeout=120,             # Whisper can be slow on first run
        )
    response.raise_for_status()
    return response.json()


# ── 3. Health check ───────────────────────────────────────────────────────────

def check_health() -> bool:
    try:
        r = requests.get(f"{BASE_URL}/health", timeout=5)
        data = r.json()
        print(f"[✓] Server healthy — model: {data.get('model')}")
        return True
    except Exception as exc:
        print(f"[✗] Server not reachable: {exc}")
        print("    → Make sure the server is running:  python app.py")
        return False


# ── 4. Main ───────────────────────────────────────────────────────────────────

def main():
    print("=" * 55)
    print("  Teamify STT — API Test Script")
    print("=" * 55)

    # Health check first
    if not check_health():
        sys.exit(1)

    # Generate (or use existing) test audio
    import os
    if not os.path.exists(AUDIO_OUT):
        generate_sine_wav(AUDIO_OUT)
    else:
        print(f"[i] Using existing file: {AUDIO_OUT}")

    # ── Test 1: English transcription ─────────────────────────────────────────
    print("\n[Test 1] English transcription…")
    result_en = transcribe(AUDIO_OUT, language="en")
    print(f"  Raw text  : {result_en['raw_text']!r}")
    print(f"  Clean text: {result_en['text']!r}")
    print(f"  Duration  : {result_en['processing_time_seconds']}s")

    # ── Test 2: Arabic transcription ──────────────────────────────────────────
    print("\n[Test 2] Arabic transcription…")
    result_ar = transcribe(AUDIO_OUT, language="ar")
    print(f"  Raw text  : {result_ar['raw_text']!r}")
    print(f"  Clean text: {result_ar['text']!r}")
    print(f"  Duration  : {result_ar['processing_time_seconds']}s")

    # ── Test 3: Custom file (if provided as CLI argument) ─────────────────────
    if len(sys.argv) > 1:
        custom_file = sys.argv[1]
        lang        = sys.argv[2] if len(sys.argv) > 2 else "en"
        print(f"\n[Test 3] Custom file: {custom_file!r}  lang={lang}")
        result_custom = transcribe(custom_file, language=lang)
        print(f"  Raw text  : {result_custom['raw_text']!r}")
        print(f"  Clean text: {result_custom['text']!r}")
        print(f"  Duration  : {result_custom['processing_time_seconds']}s")

    print("\n[✓] All tests passed!")


if __name__ == "__main__":
    main()
