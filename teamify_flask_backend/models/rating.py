"""Rating: star rating given by one project member to another."""
from datetime import datetime, timezone
from models import db


class Rating(db.Model):
    """
    One user (rater) gives a 1-5 star rating to another user (ratee)
    within the context of a specific project.

    Unique constraint ensures each rater can rate a ratee only once per project.
    """

    __tablename__ = "ratings"
    __table_args__ = (
        db.UniqueConstraint("rater_id", "ratee_id", "project_id", name="uq_rating_per_project"),
    )

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)

    # Who is being rated
    ratee_id = db.Column(
        db.Integer,
        db.ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    # Who submitted the rating
    rater_id = db.Column(
        db.Integer,
        db.ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    # Project context (optional but recommended)
    project_id = db.Column(
        db.Integer,
        db.ForeignKey("projects.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )

    score = db.Column(db.Integer, nullable=False)   # 1 – 5
    comment = db.Column(db.Text, nullable=True)

    created_at = db.Column(
        db.DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    updated_at = db.Column(
        db.DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    # Relationships
    ratee   = db.relationship("User", foreign_keys=[ratee_id],   backref="received_ratings")
    rater   = db.relationship("User", foreign_keys=[rater_id],   backref="given_ratings")
    project = db.relationship("Project", backref="ratings")

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    def to_dict(self) -> dict:
        return {
            "id":         self.id,
            "ratee_id":   self.ratee_id,
            "rater_id":   self.rater_id,
            "project_id": self.project_id,
            "score":      self.score,
            "comment":    self.comment,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }

    def __repr__(self) -> str:
        return f"<Rating rater={self.rater_id} → ratee={self.ratee_id} score={self.score}>"
