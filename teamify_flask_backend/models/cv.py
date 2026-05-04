"""
CV Model
Stores a single canonical CV per user as a JSON blob.
Each user may have at most one CV row (enforced by the unique index on user_id).
"""
from datetime import datetime, timezone
from models import db


class CV(db.Model):
    __tablename__ = "cvs"

    id          = db.Column(db.Integer, primary_key=True, autoincrement=True)
    # One-to-one relationship: each user owns exactly one CV.
    # SECURITY: user_id is the authoritative ownership field used for IDOR checks.
    user_id     = db.Column(
        db.Integer,
        db.ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,      # enforces one CV per user at the DB level
        index=True,
    )

    # ─── CV Sections stored as JSON ──────────────────────────────────────────
    personal_info   = db.Column(db.JSON, nullable=False, default=dict)
    summary         = db.Column(db.Text, nullable=True)           # AI-generated
    skills          = db.Column(db.JSON, nullable=False, default=list)
    experience      = db.Column(db.JSON, nullable=False, default=list)
    projects        = db.Column(db.JSON, nullable=False, default=list)
    education       = db.Column(db.JSON, nullable=False, default=list)
    certifications  = db.Column(db.JSON, nullable=True, default=list)

    # ─── Visibility flag (guest access control) ───────────────────────────────
    # When True, guests can view basic personal_info + skills only (no export).
    is_public       = db.Column(db.Boolean, nullable=False, default=False)

    created_at  = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at  = db.Column(
        db.DateTime,
        default=lambda:  datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    # Back-reference to owner
    owner = db.relationship("User", backref=db.backref("cv", uselist=False))

    def to_dict(self, public_only: bool = False) -> dict:
        """Serialize CV. When public_only=True (guest view), strip sensitive sections."""
        if public_only:
            return {
                "id":            self.id,
                "user_id":       self.user_id,
                "personal_info": self.personal_info,
                "skills":        self.skills,
                "is_public":     self.is_public,
            }
        return {
            "id":               self.id,
            "user_id":          self.user_id,
            "personal_info":    self.personal_info,
            "summary":          self.summary,
            "skills":           self.skills,
            "experience":       self.experience,
            "projects":         self.projects,
            "education":        self.education,
            "certifications":   self.certifications,
            "is_public":        self.is_public,
            "created_at":       self.created_at.isoformat() if self.created_at else None,
            "updated_at":       self.updated_at.isoformat() if self.updated_at else None,
        }

    def __repr__(self):
        return f"<CV user_id={self.user_id}>"
