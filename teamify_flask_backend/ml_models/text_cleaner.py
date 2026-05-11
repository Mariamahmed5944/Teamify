"""
text_cleaner.py — Teamify STT
==============================
Post-processes raw Whisper output into clean, normalised text
suitable for display inside the Teamify collaboration app.
"""

import re
import unicodedata


def clean_and_normalize(text: str, language: str = "en") -> str:
    """
    Clean and normalise raw transcribed text.

    Steps applied (language-aware):
      1. Strip leading/trailing whitespace
      2. Collapse multiple spaces / newlines
      3. Remove stutter repetitions  (e.g. "I I I want" → "I want")
      4. Fix basic punctuation spacing
      5. Capitalise the first letter of each sentence (English only)
      6. Normalise Arabic Unicode (NFC) and remove tatweel (ـ)
      7. Remove filler words (English: uh, um / Arabic: أه، آه)

    Parameters
    ----------
    text     : Raw string from Whisper
    language : ISO 639-1 code — 'en' or 'ar'

    Returns
    -------
    Cleaned string
    """

    if not text:
        return ""

    # Step 1 — Strip surrounding whitespace
    text = text.strip()

    # Step 2 — Collapse whitespace
    text = re.sub(r"[ \t]+", " ", text)       # multiple spaces → one
    text = re.sub(r"\n{2,}", "\n", text)       # multiple newlines → one

    # Step 3 — Remove word-level stutters ("I I want" → "I want")
    # Works for any language (matches any repeated word token)
    text = re.sub(r"\b(\w+)( \1\b)+", r"\1", text, flags=re.IGNORECASE)

    # Step 4 — Punctuation spacing
    # Remove space before , . ! ? ; :
    text = re.sub(r"\s+([,\.!?;:])", r"\1", text)
    # Ensure single space after sentence-ending punctuation
    text = re.sub(r"([.!?])([^\s\"\'\)])", r"\1 \2", text)

    if language == "en":
        text = _clean_english(text)
    elif language == "ar":
        text = _clean_arabic(text)

    return text.strip()


# ── English-specific ──────────────────────────────────────────────────────────

_EN_FILLERS = re.compile(
    r"\b(uh+|um+|hmm+|err+|like,?\s*you\s*know|you\s*know|i\s*mean)\b",
    flags=re.IGNORECASE,
)

def _clean_english(text: str) -> str:
    """English-specific cleaning."""

    # Remove filler words
    text = _EN_FILLERS.sub("", text)

    # Capitalise the first letter of each sentence
    sentences = re.split(r"(?<=[.!?])\s+", text)
    sentences = [s[0].upper() + s[1:] if s else s for s in sentences]
    text = " ".join(sentences)

    # Capitalise standalone "i"
    text = re.sub(r"\bi\b", "I", text)

    # Collapse any double-spaces left by filler removal
    text = re.sub(r" {2,}", " ", text)

    return text


# ── Arabic-specific ───────────────────────────────────────────────────────────

_AR_FILLERS = re.compile(r"\b(أه+|آه+|إه+|يعني\s*يعني|هممم+)\b")

# Tatweel (kashida) — decorative elongation character, not needed in plain text
_TATWEEL = re.compile(r"\u0640+")

def _clean_arabic(text: str) -> str:
    """Arabic-specific cleaning."""

    # NFC normalisation — ensures canonical Unicode form
    text = unicodedata.normalize("NFC", text)

    # Remove tatweel
    text = _TATWEEL.sub("", text)

    # Remove filler words
    text = _AR_FILLERS.sub("", text)

    # Collapse extra spaces
    text = re.sub(r" {2,}", " ", text)

    return text


# ── Quick self-test ───────────────────────────────────────────────────────────
if __name__ == "__main__":
    samples = [
        ("en", " uh I I I want to  schedule a meeting   today ."),
        ("ar", "أريد أريد أن أُجدولـــ اجتماعاً  أه   اليوم ."),
    ]
    for lang, raw in samples:
        print(f"[{lang}] RAW  : {raw!r}")
        print(f"[{lang}] CLEAN: {clean_and_normalize(raw, lang)!r}")
        print()
