from datetime import datetime, timezone, date as date_type
from models import db


class Project(db.Model):
    """Project model belonging to a user."""

    __tablename__ = "projects"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    name = db.Column(db.String(150), nullable=False)
    description = db.Column(db.Text, nullable=True)
    status = db.Column(db.String(30), nullable=False, default="active")
    start_date = db.Column(db.Date, nullable=True)
    end_date = db.Column(db.Date, nullable=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    category = db.Column(db.String(100), nullable=True)  # AI: needed for skill_match / project_similarity
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = db.Column(
        db.DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    # Relationships
    tasks = db.relationship("Task", backref="project", lazy=True, cascade="all, delete-orphan")
    members = db.relationship(
        "ProjectMember", backref="project", lazy=True, cascade="all, delete-orphan"
    )

    def _compute_progress(self):
        """Calculate progress from task completion rate."""
        total = len(self.tasks)
        if total == 0:
            return 0
        done = sum(1 for t in self.tasks if t.status == "done")
        return int(done / total * 100)

    def to_dict(self):
        """Serialize project to dictionary."""
        return {
            "id": self.id,
            "name": self.name,
            "description": self.description,
            "status": self.status,
            "progress": self._compute_progress(),
            "start_date": self.start_date.isoformat() if self.start_date else None,
            "end_date": self.end_date.isoformat() if self.end_date else None,
            "user_id": self.user_id,
            "category": self.category,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }

    def __repr__(self):
        return f"<Project {self.name}>"
