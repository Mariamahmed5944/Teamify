"""
TOTP Two-Factor Authentication Service (Week 6)

Uses the pyotp library to generate and verify RFC 6238-compliant
Time-based One-Time Passwords (TOTP). Each user gets a unique
base32 secret stored (encrypted) in their DB row.
"""
import pyotp
import qrcode
import io
import base64

APP_NAME = "Teamify"
# TOTP window: accept ±1 interval (30s each) to tolerate slight clock skew
TOTP_VALID_WINDOW = 1


def generate_totp_secret() -> str:
    """Generate a new cryptographically random base32 TOTP secret."""
    return pyotp.random_base32()


def get_totp_uri(secret: str, user_email: str) -> str:
    """Build the otpauth:// URI used by authenticator apps (Google Authenticator, Authy, etc.)."""
    totp = pyotp.TOTP(secret)
    return totp.provisioning_uri(name=user_email, issuer_name=APP_NAME)


def generate_qr_code_base64(secret: str, user_email: str) -> str:
    """
    Render the otpauth:// URI as a QR code PNG and return it as a base64 string
    so the frontend can embed it directly in an <img> tag.
    """
    uri = get_totp_uri(secret, user_email)
    img = qrcode.make(uri)
    buffer = io.BytesIO()
    img.save(buffer, format="PNG")
    encoded = base64.b64encode(buffer.getvalue()).decode("utf-8")
    return f"data:image/png;base64,{encoded}"


def verify_totp(secret: str, token: str) -> bool:
    """
    Verify a user-supplied TOTP token against the stored secret.
    The window=1 allows ±1 time-step (30s) to tolerate clock drift.
    Returns True on success, False on any failure.
    """
    if not secret or not token:
        return False
    try:
        totp = pyotp.TOTP(secret)
        return totp.verify(token.strip(), valid_window=TOTP_VALID_WINDOW)
    except Exception:
        return False
