"""
Symmetric encryption + integrity-hashing helpers.

- Fernet (AES-128-CBC + HMAC-SHA256) for confidentiality of text/bytes at rest.
- SHA-256 for integrity verification (file tamper detection).

The key is loaded from the FERNET_KEY environment variable.  An optional
FERNET_KEY_OLD enables zero-downtime key rotation via cryptography.MultiFernet.
"""
from __future__ import annotations

import hashlib
import hmac
import os
from functools import lru_cache
from typing import Optional

from cryptography.fernet import Fernet, MultiFernet, InvalidToken

__all__ = [
    "get_fernet",
    "encrypt_text",
    "decrypt_text",
    "encrypt_bytes",
    "decrypt_bytes",
    "sha256_hex",
    "verify_hash",
    "InvalidToken",
]


@lru_cache(maxsize=1)
def get_fernet() -> MultiFernet:
    """Build (and cache) a MultiFernet from FERNET_KEY [+ FERNET_KEY_OLD]."""
    primary = os.getenv("FERNET_KEY")
    if not primary:
        raise RuntimeError(
            "FERNET_KEY is not set. Generate one with "
            "`python scripts/generate_fernet_key.py` and add it to .env."
        )
    keys = [Fernet(primary.encode())]
    old = os.getenv("FERNET_KEY_OLD")
    if old:
        keys.append(Fernet(old.encode()))
    return MultiFernet(keys)


# ─── Text helpers ────────────────────────────────────────────────────────────

def encrypt_text(plaintext: Optional[str]) -> Optional[str]:
    """Encrypt a UTF-8 string. Returns ASCII-safe ciphertext, or None."""
    if plaintext is None:
        return None
    return get_fernet().encrypt(plaintext.encode("utf-8")).decode("ascii")


def decrypt_text(token: Optional[str]) -> Optional[str]:
    """Decrypt a Fernet token back to a UTF-8 string, or None."""
    if token is None:
        return None
    return get_fernet().decrypt(token.encode("ascii")).decode("utf-8")


# ─── Binary helpers (files) ──────────────────────────────────────────────────

def encrypt_bytes(data: bytes) -> bytes:
    return get_fernet().encrypt(data)


def decrypt_bytes(token: bytes) -> bytes:
    return get_fernet().decrypt(token)


# ─── Integrity hashing ───────────────────────────────────────────────────────

def sha256_hex(data: bytes) -> str:
    """SHA-256 of *data* as a lowercase hex string."""
    return hashlib.sha256(data).hexdigest()


def verify_hash(expected_hex: str, data: bytes) -> bool:
    """Constant-time comparison of SHA-256(data) against expected_hex."""
    return hmac.compare_digest(expected_hex, sha256_hex(data))
