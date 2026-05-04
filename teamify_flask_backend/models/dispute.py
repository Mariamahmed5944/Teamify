"""
Dispute model — tracks conflicts raised between platform users.
Admins can view, comment, and resolve disputes.
"""
from datetime import datetime, timezone
from models import db


class Dispute(db.Model):
    __tablename__ = "disputes"

    id          = db.Column(db.Integer, primary_key=True, autoincrement=True)
    # Who raised the dispute
    reporter_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    # Who the dispute is against
    accused_id  = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    # Optional: related project context
    project_id  = db.Column(db.Integer, db.ForeignKey("projects.id"), nullable=True)
    # Short category: payment | behaviour | quality | deadline | other
    category    = db.Column(db.String(50), nullable=False, default="other")
    subject     = db.Column(db.String(255), nullable=False)
    description = db.Column(db.Text, nullable=False)
    # open | under_review | resolved | dismissed
    status      = db.Column(db.String(30), nullable=False, default="open", index=True)
    # Admin resolution notes
    resolution  = db.Column(db.Text, nullable=True)
    resolved_by = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=True)
    resolved_at = db.Column(db.DateTime, nullable=True)

    created_at  = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at  = db.Column(
        db.DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    # Relationships (use string refs to avoid circular imports)
    reporter    = db.relationship("User", foreign_keys=[reporter_id], backref="filed_disputes", lazy=True)
    accused     = db.relationship("User", foreign_keys=[accused_id],  backref="received_disputes", lazy=True)
    resolver    = db.relationship("User", foreign_keys=[resolved_by], backref="resolved_disputes", lazy=True)

    VALID_STATUSES   = {"open", "under_review", "resolved", "dismissed"}
    VALID_CATEGORIES = {"payment", "behaviour", "quality", "deadline", "other"}

    def to_dict(self) -> dict:
        return {
            "id":            self.id,
            "reporter_id":   self.reporter_id,
            "accused_id":    self.accused_id,
            "project_id":    self.project_id,
            "category":      self.category,
            "subject":       self.subject,
            "description":   self.description,
            "status":        self.status,
            "resolution":    self.resolution,
            "resolved_by":   self.resolved_by,
            "resolved_at":   self.resolved_at.isoformat() if self.resolved_at else None,
            "created_at":    self.created_at.isoformat() if self.created_at else None,
            "updated_at":    self.updated_at.isoformat() if self.updated_at else None,
        }

    def __repr__(self):
        return f"<Dispute #{self.id} {self.status}>"
