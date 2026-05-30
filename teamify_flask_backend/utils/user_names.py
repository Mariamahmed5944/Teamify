"""Username (display_name) helpers — unique handle vs display full name."""
from __future__ import annotations

import re
import secrets

USERNAME_RE = re.compile(r"^[a-zA-Z0-9_]{3,30}$")


def validate_username(raw: str) -> str | None:
    """Return an error message if [raw] is not a valid username, else None."""
    name = (raw or "").strip()
    if not name:
        return "username cannot be empty"
    if len(name) < 3:
        return "username must be at least 3 characters"
    if len(name) > 30:
        return "username must be 30 characters or fewer"
    if not USERNAME_RE.match(name):
        return "username may only contain letters, numbers, and underscores"
    return None


def generate_unique_display_name() -> str:
    """Auto-generated unique handle until the user picks a username in profile."""
    from models.user import User

    for _ in range(32):
        candidate = f"user_{secrets.token_hex(4)}"
        if not User.query.filter_by(display_name=candidate).first():
            return candidate
    return f"user_{secrets.token_hex(8)}"
