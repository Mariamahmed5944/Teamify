"""TaskComment: comment text is encrypted at rest (Fernet)."""
from datetime import datetime, timezone
from models import db
from utils.crypto import encrypt_text, decrypt_text


class TaskComment(db.Model):
    __tablename__ = "task_comments"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    task_id = db.Column(
        db.Integer,
        db.ForeignKey("tasks.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    author_id = db.Column(
        db.Integer,
        db.ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    # Stored encrypted; never expose this column directly.
    _content_encrypted = db.Column("content_encrypted", db.Text, nullable=False)
    created_at = db.Column(
        db.DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    # ─── Transparent encrypt/decrypt ─────────────────────────────────────────

    @property
    def content(self) -> str:
        return decrypt_text(self._content_encrypted) or ""

    @content.setter
    def content(self, value: str) -> None:
        if value is None or not str(value).strip():
            raise ValueError("Comment content cannot be empty")
        self._content_encrypted = encrypt_text(str(value))

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "task_id": self.task_id,
            "author_id": self.author_id,
            "content": self.content,  # decrypted on read
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }

    def __repr__(self) -> str:
        return f"<TaskComment task={self.task_id} author={self.author_id}>"
