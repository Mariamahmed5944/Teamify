"""
TokenBlocklist — persists revoked JWT identifiers (jti) in PostgreSQL.

Every JTI added here is checked by @jwt.token_in_blocklist_loader on each
request.  The table survives server restarts, unlike the in-memory set()
that was used previously.

Indexes
-------
- ix_token_blocklist_jti  (UNIQUE) — fast O(1) lookup per request
- ix_token_blocklist_exp  — allows a background job to purge expired rows
"""
from datetime import datetime, timezone
from models import db


class TokenBlocklist(db.Model):
    __tablename__ = "token_blocklist"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    # unique=True + index=True → one unique index on jti (do not duplicate in __table_args__)
    jti = db.Column(db.String(36), nullable=False, unique=True, index=True)
    revoked_at = db.Column(
        db.DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        index=True,
    )
    # Optional: store expiry so a cleanup job can prune old rows
    expires_at = db.Column(db.DateTime, nullable=True)

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    def __repr__(self):
        return f"<TokenBlocklist jti={self.jti} revoked_at={self.revoked_at}>"

    @staticmethod
    def revoke(jti: str, expires_at: datetime | None = None) -> None:
        """Insert a JTI into the blocklist. Idempotent — safe to call twice."""
        existing = TokenBlocklist.query.filter_by(jti=jti).first()
        if existing:
            return
        entry = TokenBlocklist(jti=jti, expires_at=expires_at)
        db.session.add(entry)
        db.session.commit()

    @staticmethod
    def is_revoked(jti: str) -> bool:
        """Return True if the jti is in the blocklist."""
        return TokenBlocklist.query.filter_by(jti=jti).first() is not None
