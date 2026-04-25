# 🎙️ Teamify — Speech-to-Text Module

A fast, mobile-friendly Speech-to-Text backend for the **Teamify** collaboration app, powered by **OpenAI Whisper** and **FastAPI**.

---

## ✨ Features

| Feature | Detail |
|---|---|
| 🧠 **Model** | OpenAI Whisper (`base` by default) |
| 🌍 **Languages** | English (`en`) & Arabic (`ar`) |
| 🧹 **Text cleaning** | Removes fillers, stutters, normalises punctuation |
| ⚡ **Low latency** | `base` model ~1-3 s on CPU for a 10 s clip |
| 📱 **Mobile-ready** | CORS enabled, JSON responses, multipart upload |
| 📄 **Auto docs** | Swagger UI at `http://localhost:8000/docs` |

---

## 🗂️ Project Structure

```
teamify-stt/
├── app.py            ← FastAPI application & /transcribe endpoint
├── text_cleaner.py   ← Post-processing & normalisation utilities
├── test_api.py       ← End-to-end test script
├── requirements.txt  ← Python dependencies
└── README.md
```

---

## 🚀 Quick Start

### 1 · Prerequisites

- Python 3.9+
- `ffmpeg` (required by Whisper for audio decoding)

**Install ffmpeg:**

```bash
# macOS
brew install ffmpeg

# Ubuntu / Debian
sudo apt update && sudo apt install ffmpeg -y

# Windows  (use Chocolatey)
choco install ffmpeg
```

---

### 2 · Install Python dependencies

```bash
# Clone / enter the project folder
cd teamify-stt

# (Recommended) create a virtual environment
python -m venv .venv
source .venv/bin/activate       # Windows: .venv\Scripts\activate

# Install packages
pip install -r requirements.txt
```

> **First run** will download the Whisper model weights (~74 MB for `base`).

---

### 3 · Start the server

```bash
python app.py
```

Expected output:
```
INFO  Loading Whisper model: 'base' — this may take a moment…
INFO  Whisper model loaded ✓
INFO  Uvicorn running on http://0.0.0.0:8000
```

---

### 4 · Test the API

```bash
# Run the automated test script
python test_api.py

# Test with YOUR OWN audio file
python test_api.py path/to/my_recording.mp3 en

# Arabic audio
python test_api.py path/to/arabic_clip.wav ar
```

---

## 📡 API Reference

### `GET /health`
Liveness probe — returns `200 OK` if the server is up.

```json
{ "status": "ok", "model": "base" }
```

---

### `POST /transcribe`

Transcribe an uploaded audio file.

**Query parameters:**

| Param | Type | Default | Options |
|---|---|---|---|
| `language` | string | `en` | `en`, `ar` |
| `task` | string | `transcribe` | `transcribe`, `translate` |

> `translate` converts any language → English.

**Request (multipart/form-data):**

```
file: <audio file>
```

**Response:**

```json
{
  "success": true,
  "language": "en",
  "language_name": "English",
  "task": "transcribe",
  "raw_text": "uh I I want to schedule a meeting today",
  "text": "I want to schedule a meeting today.",
  "processing_time_seconds": 1.842,
  "model": "base",
  "filename": "recording.wav"
}
```

**cURL example:**

```bash
curl -X POST "http://localhost:8000/transcribe?language=en" \
     -F "file=@/path/to/audio.mp3"
```

**Python example:**

```python
import requests

with open("audio.mp3", "rb") as f:
    response = requests.post(
        "http://localhost:8000/transcribe?language=en",
        files={"file": ("audio.mp3", f, "audio/mpeg")},
    )

data = response.json()
print(data["text"])   # cleaned transcription
```

**JavaScript / mobile fetch example:**

```javascript
const formData = new FormData();
formData.append("file", audioBlob, "recording.webm");

const res = await fetch("http://YOUR_SERVER:8000/transcribe?language=en", {
  method: "POST",
  body: formData,
});

const { text, processing_time_seconds } = await res.json();
console.log("Transcript:", text);
```

---

## ⚙️ Configuration

| Environment variable | Default | Description |
|---|---|---|
| `WHISPER_MODEL` | `base` | Whisper model size |

### Choosing a model

| Model | Size | Speed (CPU) | Accuracy |
|---|---|---|---|
| `tiny` | 39 MB | ⚡ Fastest | ★★☆ |
| `base` | 74 MB | ⚡ Fast | ★★★ — **recommended** |
| `small` | 244 MB | 🐢 Moderate | ★★★★ |
| `medium` | 769 MB | 🐢 Slow | ★★★★★ |
| `large` | 1.5 GB | 🐌 Very slow | ★★★★★ |

```bash
# Use a smaller model for even lower latency
WHISPER_MODEL=tiny python app.py

# Use a larger model for better accuracy
WHISPER_MODEL=small python app.py
```

---

## 🛡️ Production Tips

1. **Use a GPU** — Whisper is dramatically faster with CUDA (`pip install torch --index-url https://download.pytorch.org/whl/cu118`).
2. **Run with Gunicorn** — `gunicorn app:app -w 1 -k uvicorn.workers.UvicornWorker` (keep workers=1 to share the loaded model).
3. **Restrict CORS** — Replace `allow_origins=["*"]` with your mobile app's domain.
4. **Add auth** — Protect `/transcribe` with an API key header or JWT.
5. **Limit file size** — Add `nginx` in front with `client_max_body_size 25m`.
6. **Cache the model** — The model is loaded once at startup and reused for all requests — no per-request reload cost.

---

## 🧹 Text Cleaning Details

`text_cleaner.py` applies these transformations automatically:

| Rule | Example |
|---|---|
| Collapse whitespace | `"hello   world"` → `"hello world"` |
| Remove stutters | `"I I I want"` → `"I want"` |
| Remove English fillers | `"um uh you know"` → `""` |
| Remove Arabic fillers | `"أه أريد"` → `"أريد"` |
| Fix punctuation spacing | `"Hello , world ."` → `"Hello, world."` |
| Capitalise sentences | `"hello. how are you"` → `"Hello. How are you"` |
| Normalise Arabic Unicode | Removes tatweel (ـ), applies NFC |

---

## 📜 License

MIT — free to use in commercial and open-source projects.
