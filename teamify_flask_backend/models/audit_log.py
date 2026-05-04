"""
AuditLog DB Model
Mirrors the file-based JSON audit log into a queryable database table.
Every security/AI event is persisted here for compliance and analytics.
"""
from datetime import datetime, timezone
from models import db


class AuditLog(db.Model):
    __tablename__ = "audit_logs"

    id         = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id    = db.Column(db.Integer, nullable=True, index=True)
    action     = db.Column(db.String(100), nullable=False, index=True)
    details    = db.Column(db.Text, nullable=True)
    ip_address = db.Column(db.String(50), nullable=True)
    severity   = db.Column(db.String(20), nullable=False, default="INFO")
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    def to_dict(self) -> dict:
        return {
            "id":         self.id,
            "user_id":    self.user_id,
            "action":     self.action,
            "details":    self.details,
            "ip_address": self.ip_address,
            "severity":   self.severity,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }

    def __repr__(self):
        return f"<AuditLog {self.action} user={self.user_id}>"
