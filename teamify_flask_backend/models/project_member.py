from models import db


class ProjectMember(db.Model):
    """Maps users to projects with a role (owner | member)."""

    __tablename__ = "project_members"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    project_id = db.Column(
        db.Integer,
        db.ForeignKey("projects.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id = db.Column(
        db.Integer,
        db.ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    # "owner" or "member"
    role = db.Column(db.String(20), nullable=False, default="member")

    __table_args__ = (
        db.UniqueConstraint("project_id", "user_id", name="uq_project_member"),
        # Fast lookups: all members of a project, all projects of a user
        db.Index("ix_pm_project_id", "project_id"),
        db.Index("ix_pm_user_id", "user_id"),
    )

    def to_dict(self):
        return {
            "id": self.id,
            "project_id": self.project_id,
            "user_id": self.user_id,
            "role": self.role,
        }

    def __repr__(self):
        return f"<ProjectMember user={self.user_id} project={self.project_id} role={self.role}>"
