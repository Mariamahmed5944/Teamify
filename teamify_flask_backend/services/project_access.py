"""Project visibility helpers — owner OR project_members only."""
from __future__ import annotations

from sqlalchemy import or_

from models import db
from models.project import Project
from models.project_member import ProjectMember


def accessible_projects_query(user_id: int):
    """
    SQLAlchemy query for projects the user may see on user-facing routes.

    Returns projects the user owns or belongs to via ``project_members``.
    Platform admins use ``/admin/projects`` for global visibility.
    """
    return (
        Project.query.outerjoin(
            ProjectMember,
            Project.id == ProjectMember.project_id,
        )
        .filter(
            or_(
                Project.user_id == user_id,
                ProjectMember.user_id == user_id,
            )
        )
        .distinct()
    )


def get_accessible_project_ids(user_id: int) -> list[int]:
    """Return distinct project IDs visible to the user (owner or member)."""
    rows = accessible_projects_query(user_id).with_entities(Project.id).all()
    return [row[0] for row in rows]


def user_has_project_access(user_id: int, project_id: int) -> bool:
    """True when the user owns the project or is listed in project_members."""
    project = db.session.get(Project, project_id)
    if not project:
        return False
    if project.user_id == user_id:
        return True
    return (
        ProjectMember.query.filter_by(
            project_id=project_id,
            user_id=user_id,
        ).first()
        is not None
    )
