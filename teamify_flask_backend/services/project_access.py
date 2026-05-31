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


def users_share_project(user_a: int, user_b: int) -> bool:
    """True when both users belong to at least one common project."""
    if user_a == user_b:
        return True
    a_ids = set(get_accessible_project_ids(user_a))
    if not a_ids:
        return False
    b_ids = set(get_accessible_project_ids(user_b))
    return bool(a_ids & b_ids)


def can_view_user_stats(viewer_id: int, target_id: int, viewer_role: str | None = None) -> bool:
    """Self, platform admin, or users who share a project may view stats."""
    if viewer_id == target_id:
        return True
    if (viewer_role or "").lower() == "admin":
        return True
    return users_share_project(viewer_id, target_id)


def search_user_dict(user) -> dict:
    """Redacted user payload for directory/search (no email, phone, or security fields)."""
    skills = user.skills if isinstance(user.skills, list) else []
    if isinstance(user.skills, str) and user.skills:
        skills = [s.strip() for s in user.skills.split(",") if s.strip()]
    return {
        "id": user.id,
        "display_name": user.display_name,
        "full_name": user.full_name,
        "user_type": user.user_type,
        "role": user.role,
        "skills": skills,
        "professional_field": user.professional_field,
        "experience_level": user.experience_level,
        "availability": user.availability,
        "major": user.major,
        "current_level": user.current_level,
        "looking_for_team": user.looking_for_team,
        "avatar_file_id": user.avatar_file_id,
        "member_experience_years": user.member_experience_years,
    }
