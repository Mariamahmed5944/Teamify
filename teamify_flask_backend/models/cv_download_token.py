"""
CV Download Token Model
Stores time-limited, single-use secure tokens for PDF downloads.
Each token is tied to a specific CV and user, and expires after 15 minutes.
"""
from datetime import datetime, timezone, timedelta
import secrets
from models import db


class CVDownloadToken(db.Model):
    __tablename__ = "cv_download_tokens"

    id         = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id    = db.Column(
        db.Integer,
        db.ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    cv_id      = db.Column(
        db.Integer,
        db.ForeignKey("cvs.id", ondelete="CASCADE"),
        nullable=False,
    )
    # SECURITY: cryptographically random token (32 bytes → 64 hex chars)
    token      = db.Column(db.String(100), unique=True, nullable=False, index=True)
    expires_at = db.Column(db.DateTime, nullable=False)
    # Track whether the token has already been consumed (single-use)
    used       = db.Column(db.Boolean, nullable=False, default=False)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    # Relationships
    owner = db.relationship("User", backref=db.backref("cv_download_tokens", lazy=True))
    cv    = db.relationship("CV",   backref=db.backref("download_tokens",    lazy=True))

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    @staticmethod
    def create_token(user_id: int, cv_id: int, ttl_minutes: int = 15) -> "CVDownloadToken":
        """Generate a secure, time-limited download token."""
        token = CVDownloadToken(
            user_id=user_id,
            cv_id=cv_id,
            token=secrets.token_hex(32),
            expires_at=datetime.now(timezone.utc) + timedelta(minutes=ttl_minutes),
        )
        db.session.add(token)
        db.session.commit()
        return token

    @property
    def is_expired(self) -> bool:
        """Check if the token has passed its expiry time."""
        now = datetime.now(timezone.utc)
        exp = self.expires_at
        if exp.tzinfo is None:
            exp = exp.replace(tzinfo=timezone.utc)
        return now > exp

    def to_dict(self) -> dict:
        return {
            "id":         self.id,
            "user_id":    self.user_id,
            "cv_id":      self.cv_id,
            "token":      self.token,
            "expires_at": self.expires_at.isoformat() if self.expires_at else None,
            "used":       self.used,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }

    def __repr__(self):
        return f"<CVDownloadToken user_id={self.user_id} cv_id={self.cv_id}>"
