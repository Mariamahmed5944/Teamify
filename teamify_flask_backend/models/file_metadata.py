"""FileMetadata: pointer to an encrypted file on disk + integrity hash."""
from datetime import datetime, timezone
from models import db


class FileMetadata(db.Model):
    __tablename__ = "file_metadata"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    owner_id = db.Column(
        db.Integer,
        db.ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    original_filename = db.Column(db.String(255), nullable=False)
    mime_type = db.Column(db.String(127), nullable=False)
    size_bytes = db.Column(db.BigInteger, nullable=False)
    encrypted_path = db.Column(db.String(512), nullable=False)
    sha256_hash = db.Column(db.String(64), nullable=False)
    created_at = db.Column(
        db.DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "owner_id": self.owner_id,
            "filename": self.original_filename,
            "mime_type": self.mime_type,
            "size_bytes": self.size_bytes,
            "sha256": self.sha256_hash,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }

    def __repr__(self) -> str:
        return f"<FileMetadata {self.original_filename} ({self.size_bytes}B)>"
