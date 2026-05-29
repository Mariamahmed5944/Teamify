from datetime import datetime, timezone
from models import db


class Log(db.Model):
    """Activity log model for auditing user actions."""

    __tablename__ = "logs"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    action = db.Column(db.String(100), nullable=False)
    entity = db.Column(db.String(50), nullable=False)
    entity_id = db.Column(db.Integer, nullable=True)
    details = db.Column(db.Text, nullable=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))


    def __init__(self, **kwargs):
        super().__init__(**kwargs)
    def to_dict(self):
        """Serialize log to dictionary."""
        return {
            "id": self.id,
            "action": self.action,
            "entity": self.entity,
            "entity_id": self.entity_id,
            "details": self.details,
            "user_id": self.user_id,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }

    def __repr__(self):
        return f"<Log {self.action} on {self.entity}>"
