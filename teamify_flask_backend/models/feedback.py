"""Feedback: peer/reviewer feedback for project members (AI Rating feature)."""
from datetime import datetime, timezone
from models import db


class Feedback(db.Model):
    """Stores quality, teamwork, and overall rating feedback for a user in a project."""

    __tablename__ = "feedbacks"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_id = db.Column(
        db.Integer,
        db.ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    project_id = db.Column(
        db.Integer,
        db.ForeignKey("projects.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    reviewer_id = db.Column(
        db.Integer,
        db.ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    quality_score = db.Column(db.Float, nullable=True)       # 0.0 - 5.0
    teamwork_score = db.Column(db.Float, nullable=True)      # 0.0 - 5.0
    feedback_text = db.Column(db.Text, nullable=True)
    avg_rating = db.Column(db.Integer, nullable=True)        # overall rating 0 - 5
    created_at = db.Column(
        db.DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )

    # Relationships
    user = db.relationship("User", foreign_keys=[user_id], backref="received_feedbacks")
    reviewer = db.relationship("User", foreign_keys=[reviewer_id], backref="given_feedbacks")
    project = db.relationship("Project", backref="feedbacks")

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "user_id": self.user_id,
            "project_id": self.project_id,
            "reviewer_id": self.reviewer_id,
            "quality_score": self.quality_score,
            "teamwork_score": self.teamwork_score,
            "feedback_text": self.feedback_text,
            "avg_rating": self.avg_rating,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }

    def __repr__(self) -> str:
        return f"<Feedback user={self.user_id} project={self.project_id} rating={self.avg_rating}>"
