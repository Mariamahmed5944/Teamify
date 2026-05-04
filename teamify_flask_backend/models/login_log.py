"""LoginLog: every login attempt (success or fail) is recorded here."""
from datetime import datetime, timezone
from models import db


class LoginLog(db.Model):
    __tablename__ = "login_logs"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id = db.Column(
        db.Integer,
        db.ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    status = db.Column(db.String(16), nullable=False)  # 'success' | 'fail'
    timestamp = db.Column(
        db.DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        index=True,
    )
    ip_address = db.Column(db.String(45), nullable=False, index=True)  # IPv6-safe
    device_info = db.Column(db.String(512), nullable=True)

    __table_args__ = (
        db.Index("ix_login_logs_ip_time", "ip_address", "timestamp"),
        db.Index("ix_login_logs_user_time", "user_id", "timestamp"),
    )

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "user_id": self.user_id,
            "status": self.status,
            "timestamp": self.timestamp.isoformat() if self.timestamp else None,
            "ip_address": self.ip_address,
            "device_info": self.device_info,
        }

    def __repr__(self) -> str:
        return f"<LoginLog {self.status} {self.ip_address} {self.timestamp}>"
