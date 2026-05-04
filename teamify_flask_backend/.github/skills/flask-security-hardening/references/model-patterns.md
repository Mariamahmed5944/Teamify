# Model Patterns

All models assume the project's `db = SQLAlchemy()` instance from `models/__init__.py`.

## `models/login_log.py`

```python
from datetime import datetime
import uuid
from sqlalchemy.dialects.postgresql import UUID
from models import db


class LoginLog(db.Model):
    __tablename__ = "login_logs"

    id = db.Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = db.Column(UUID(as_uuid=True), db.ForeignKey("users.id"), nullable=True, index=True)
    status = db.Column(db.String(16), nullable=False)  # 'success' | 'fail'
    timestamp = db.Column(db.DateTime, default=datetime.utcnow, nullable=False, index=True)
    ip_address = db.Column(db.String(45), nullable=False, index=True)  # IPv6-safe
    device_info = db.Column(db.String(512), nullable=True)

    __table_args__ = (
        db.Index("ix_loginlogs_ip_time", "ip_address", "timestamp"),
        db.Index("ix_loginlogs_user_time", "user_id", "timestamp"),
    )

    def to_dict(self):
        return {
            "id": str(self.id),
            "user_id": str(self.user_id) if self.user_id else None,
            "status": self.status,
            "timestamp": self.timestamp.isoformat() + "Z",
            "ip_address": self.ip_address,
            "device_info": self.device_info,
        }
```

## `models/alert.py`

```python
from datetime import datetime
import uuid
from sqlalchemy.dialects.postgresql import UUID
from models import db


class Alert(db.Model):
    __tablename__ = "alerts"

    id = db.Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    type = db.Column(db.String(64), nullable=False, index=True)
    description = db.Column(db.Text, nullable=False)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow, nullable=False, index=True)
    resolved = db.Column(db.Boolean, default=False, nullable=False, index=True)
    resolved_at = db.Column(db.DateTime, nullable=True)
    resolved_by = db.Column(UUID(as_uuid=True), db.ForeignKey("users.id"), nullable=True)

    def to_dict(self):
        return {
            "id": str(self.id),
            "type": self.type,
            "description": self.description,
            "timestamp": self.timestamp.isoformat() + "Z",
            "resolved": self.resolved,
            "resolved_at": self.resolved_at.isoformat() + "Z" if self.resolved_at else None,
            "resolved_by": str(self.resolved_by) if self.resolved_by else None,
        }
```

## `models/file_metadata.py`

```python
from datetime import datetime
import uuid
from sqlalchemy.dialects.postgresql import UUID
from models import db


class FileMetadata(db.Model):
    __tablename__ = "file_metadata"

    id = db.Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    owner_id = db.Column(UUID(as_uuid=True), db.ForeignKey("users.id"), nullable=False, index=True)
    original_filename = db.Column(db.String(255), nullable=False)
    mime_type = db.Column(db.String(127), nullable=False)
    size_bytes = db.Column(db.BigInteger, nullable=False)
    encrypted_path = db.Column(db.String(512), nullable=False)
    sha256_hash = db.Column(db.String(64), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)

    def to_dict(self):
        return {
            "id": str(self.id),
            "filename": self.original_filename,
            "mime_type": self.mime_type,
            "size_bytes": self.size_bytes,
            "sha256": self.sha256_hash,
            "created_at": self.created_at.isoformat() + "Z",
        }
```

## Transparent-encryption property pattern

Apply this to a comment, message, or any text field that must be encrypted at rest. The DB column is named with a leading underscore; the public attribute is a `@property` that handles encrypt/decrypt.

```python
from datetime import datetime
import uuid
from sqlalchemy.dialects.postgresql import UUID
from models import db
from utils.crypto import encrypt_text, decrypt_text


class TaskComment(db.Model):
    __tablename__ = "task_comments"

    id = db.Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    task_id = db.Column(UUID(as_uuid=True), db.ForeignKey("tasks.id"), nullable=False, index=True)
    author_id = db.Column(UUID(as_uuid=True), db.ForeignKey("users.id"), nullable=False)
    _content_encrypted = db.Column("content_encrypted", db.Text, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)

    @property
    def content(self) -> str:
        return decrypt_text(self._content_encrypted)

    @content.setter
    def content(self, value: str) -> None:
        self._content_encrypted = encrypt_text(value)

    def to_dict(self):
        return {
            "id": str(self.id),
            "task_id": str(self.task_id),
            "author_id": str(self.author_id),
            "content": self.content,  # decrypted on read
            "created_at": self.created_at.isoformat() + "Z",
        }
```

### Notes

- Never expose `_content_encrypted` in any serializer.
- Filtering/searching on encrypted text in SQL is impossible by design. If you need search, consider a separate searchable hash column over a normalized form, or accept full-table decrypt-in-Python for small datasets.
- For PostgreSQL UUIDs the project already uses `UUID(as_uuid=True)`; mirror that convention. For SQLite test environments, swap to `db.String(36)`.
