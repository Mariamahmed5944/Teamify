"""Shared helpers for listing users in project member pickers."""
from __future__ import annotations

from sqlalchemy import String, cast, or_

from models.user import User


def available_member_dict(user: User) -> dict:
    """Full public profile fields for invite / member picker UIs."""
    payload = user.to_dict()
    payload["name"] = user.full_name or user.display_name
    return payload


def query_available_members(
    *,
    current_user_id: int,
    search: str = "",
    exclude_self: bool = True,
) -> list[User]:
    q = User.query.filter(User.role != "guest", User.role != "admin")
    if exclude_self:
        q = q.filter(User.id != current_user_id)
    if search:
        pattern = f"%{search}%"
        q = q.filter(
            or_(
                User.full_name.ilike(pattern),
                User.display_name.ilike(pattern),
                User.email.ilike(pattern),
                User.professional_field.ilike(pattern),
                User.experience_level.ilike(pattern),
                User.major.ilike(pattern),
                cast(User.skills, String).ilike(pattern),
            )
        )
    return q.order_by(User.full_name, User.display_name).all()
