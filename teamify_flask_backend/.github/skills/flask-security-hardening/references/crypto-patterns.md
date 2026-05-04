# Crypto Patterns

## `utils/crypto.py`

```python
import hashlib
import os
from functools import lru_cache
from cryptography.fernet import Fernet, MultiFernet, InvalidToken

__all__ = [
    "get_fernet", "encrypt_text", "decrypt_text",
    "encrypt_bytes", "decrypt_bytes", "sha256_hex", "InvalidToken",
]


@lru_cache(maxsize=1)
def get_fernet() -> MultiFernet:
    """Build a MultiFernet from FERNET_KEY (and optional FERNET_KEY_OLD).

    Using MultiFernet from day one makes future key rotation a one-line change:
    set FERNET_KEY to the new key and FERNET_KEY_OLD to the previous one; new
    writes use the new key, old ciphertexts still decrypt.
    """
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


def encrypt_text(plaintext: str) -> str:
    if plaintext is None:
        return None
    return get_fernet().encrypt(plaintext.encode("utf-8")).decode("ascii")


def decrypt_text(token: str) -> str:
    if token is None:
        return None
    return get_fernet().decrypt(token.encode("ascii")).decode("utf-8")


def encrypt_bytes(data: bytes) -> bytes:
    return get_fernet().encrypt(data)


def decrypt_bytes(token: bytes) -> bytes:
    return get_fernet().decrypt(token)


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()
```

## `scripts/generate_fernet_key.py`

```python
from cryptography.fernet import Fernet
print(Fernet.generate_key().decode())
```

## `.env.example` additions

```
# 32-byte url-safe base64 key. Generate via: python scripts/generate_fernet_key.py
FERNET_KEY=
# Optional: previous key during rotation
FERNET_KEY_OLD=
# Where encrypted uploads are stored
UPLOAD_DIR=./instance/uploads
```

## Key rotation procedure

1. Generate a new key.
2. Set `FERNET_KEY_OLD` = current key, `FERNET_KEY` = new key. Restart.
3. Optionally run a one-off script that reads each encrypted record, calls `MultiFernet.rotate()`, and writes it back.
4. Once rotation is complete, unset `FERNET_KEY_OLD`.

## Anti-patterns

- Storing the key in `config.py` source. Always env.
- Calling `Fernet(key)` per request — use the `lru_cache`'d `get_fernet()`.
- Catching `InvalidToken` and returning the ciphertext as-is. Always raise/alert.
- Using the same key for short-lived tokens and at-rest data — keep them separate vars if both are needed.
