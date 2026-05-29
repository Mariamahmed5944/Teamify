"""Ensure project-linked team chat rooms exist for all project members."""
from __future__ import annotations

from models import db
from models.chat import ChatRoom, ChatRoomMember
from models.project import Project
from models.project_member import ProjectMember


def add_room_member(room_id: int, user_id: int) -> None:
    exists = ChatRoomMember.query.filter_by(
        room_id=room_id, user_id=user_id
    ).first()
    if not exists:
        db.session.add(ChatRoomMember(room_id=room_id, user_id=user_id))


def sync_project_members_to_room(room_id: int, project_id: int) -> None:
    """Ensure all project members can access the linked chat room."""
    for pm in ProjectMember.query.filter_by(project_id=project_id).all():
        add_room_member(room_id, pm.user_id)


def ensure_project_chat_room(project: Project, acting_user_id: int) -> ChatRoom:
    """Return the team chat room for a project, creating it if needed."""
    room = ChatRoom.query.filter_by(project_id=project.id).first()
    if room is None:
        room = ChatRoom(
            name=project.name,
            project_id=project.id,
            is_group=True,
        )
        db.session.add(room)
        db.session.flush()

    add_room_member(room.id, acting_user_id)
    if project.user_id:
        add_room_member(room.id, project.user_id)
    sync_project_members_to_room(room.id, project.id)
    return room


def sync_all_project_rooms_for_user(user_id: int) -> None:
    """Create or refresh chat rooms for every project the user can access."""
    seen_ids: set[int] = set()
    projects: list[Project] = []

    for project in Project.query.filter_by(user_id=user_id).all():
        if project.id not in seen_ids:
            seen_ids.add(project.id)
            projects.append(project)

    for pm in ProjectMember.query.filter_by(user_id=user_id).all():
        if pm.project_id in seen_ids:
            continue
        project = db.session.get(Project, pm.project_id)
        if project is not None:
            seen_ids.add(project.id)
            projects.append(project)

    for project in projects:
        ensure_project_chat_room(project, user_id)
