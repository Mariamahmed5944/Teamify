"""Normalize user skills from DB (JSON list, comma string, or corrupted char-list)."""
from __future__ import annotations

from typing import Any


def normalize_skills_list(raw: Any) -> list[str]:
    """
    Return a clean list of skill labels.

    Handles:
    - None / empty
    - Comma-separated string
    - Proper JSON list of strings
    - Legacy bug: string saved as list of single characters
    """
    if raw is None:
        return []
    if isinstance(raw, str):
        text = raw.strip()
        if not text:
            return []
        return [part.strip() for part in text.split(",") if part.strip()]

    if isinstance(raw, list):
        items = [str(x).strip() for x in raw if x is not None and str(x).strip()]
        if not items:
            return []
        short = sum(1 for i in items if len(i) <= 2)
        if len(items) >= 5 and short / len(items) > 0.6:
            rebuilt = "".join(items)
            return [part.strip() for part in rebuilt.split(",") if part.strip()]
        return [i for i in items if len(i) > 1]

    return []
