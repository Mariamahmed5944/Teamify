from datetime import datetime, timezone

from models import db


class ProjectInvitation(db.Model):
    """Pending invite for a user to join a project (accept / decline)."""

    __tablename__ = "project_invitations"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    project_id = db.Column(
        db.Integer,
        db.ForeignKey("projects.id", ondelete="CASCADE"),
        nullable=False,
    )
    inviter_id = db.Column(
        db.Integer,
        db.ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    invitee_id = db.Column(
        db.Integer,
        db.ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    status = db.Column(db.String(20), nullable=False, default="pending")
    created_at = db.Column(
        db.DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    responded_at = db.Column(db.DateTime, nullable=True)

    __table_args__ = (
        db.UniqueConstraint("project_id", "invitee_id", name="uq_project_invitee"),
        db.Index("ix_pi_invitee_status", "invitee_id", "status"),
        db.Index("ix_pi_project_status", "project_id", "status"),
    )

    def to_dict(self, project_name: str | None = None, inviter_name: str | None = None):
        return {
            "id": self.id,
            "project_id": self.project_id,
            "inviter_id": self.inviter_id,
            "invitee_id": self.invitee_id,
            "status": self.status,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "responded_at": self.responded_at.isoformat() if self.responded_at else None,
            "project_name": project_name,
            "inviter_name": inviter_name,
        }
