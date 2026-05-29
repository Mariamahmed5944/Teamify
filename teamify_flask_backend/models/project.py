from datetime import datetime, timezone
from typing import Iterable, cast

from models import db
from models.project_member import ProjectMember


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

    @property
    def owner_id(self) -> int | None:
        """Alias for user_id — the project creator is always the owner."""
        return self.user_id

    def _compute_progress(self):
        """Calculate progress from task completion rate."""
        total = len(self.tasks)  # type: ignore[arg-type]
        if total == 0:
            return 0
        done = sum(1 for t in self.tasks if t.status == "done")  # type: ignore[attr-defined]
        return int(done / total * 100)


    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    def _member_user_ids(self):
        """Return distinct member user IDs, always including the project owner."""
        ids: list[int] = []
        seen: set[int] = set()

        if self.user_id:
            seen.add(self.user_id)
            ids.append(self.user_id)

        if self.id is not None:
            memberships: Iterable[ProjectMember] = ProjectMember.query.filter_by(
                project_id=self.id
            ).all()
        else:
            memberships = cast(Iterable[ProjectMember], self.members or [])

        for membership in memberships:
            uid = membership.user_id
            if uid not in seen:
                seen.add(uid)
                ids.append(uid)

        return ids

    def to_dict(self):
        """Serialize project to dictionary."""
        member_user_ids = self._member_user_ids()
        member_count = len(member_user_ids)

        # Resolve owner as a rich object for the Flutter client
        owner_dict: dict | None = None
        owner_name: str = "Unknown"
        try:
            from models.user import User  # noqa: PLC0415
            owner = User.query.filter_by(id=self.user_id).first()
            if owner:
                owner_name = (
                    owner.full_name
                    or owner.display_name
                    or f"User {self.user_id}"
                )
                owner_dict = {
                    "id": owner.id,
                    "full_name": owner.full_name or "",
                    "display_name": owner.display_name or "",
                }
        except Exception:
            pass

        return {
            "id": self.id,
            "name": self.name,
            "description": self.description,
            "status": self.status,
            "progress": self._compute_progress(),
            "start_date": self.start_date.isoformat() if self.start_date else None,
            "end_date": self.end_date.isoformat() if self.end_date else None,
            "user_id": self.user_id,
            "owner_id": self.user_id,   # explicit alias for clarity
            "owner_name": owner_name,   # backward compat (flat string)
            "owner": owner_dict,        # rich nested object for Flutter
            "category": self.category,
            "member_count": member_count,
            "member_ids": member_user_ids,
            "members": [str(uid) for uid in member_user_ids],
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }

    def __repr__(self):
        return f"<Project {self.name}>"
