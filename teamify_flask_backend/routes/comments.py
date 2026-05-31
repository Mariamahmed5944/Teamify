"""Encrypted task comments. Content is Fernet-encrypted at rest."""
from __future__ import annotations


from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity

from middleware.auth import auth_required, get_project_role, _READ_ROLES, _MEMBER_ROLES
from models import db
from models.task import Task
from models.task_comment import TaskComment

comments_bp = Blueprint("comments", __name__, url_prefix="/api/tasks")


def _load_task_for_user(task_id: str, user_id: int, *, write: bool = False):
    try:
        tid = int(task_id)
    except (ValueError, AttributeError):
        return None, (jsonify({"error": "Invalid task_id"}), 400)

    task = Task.query.filter_by(id=tid).first()
    if not task:
        return None, (jsonify({"error": "Task not found"}), 404)

    role = get_project_role(user_id, task.project_id)
    allowed = _MEMBER_ROLES if write else _READ_ROLES
    if role not in allowed:
        message = (
            "You do not have permission to comment on this task"
            if write
            else "You do not have access to this task's comments"
        )
        return None, (jsonify({"error": "Forbidden", "message": message}), 403)

    return task, None


@comments_bp.route("/<task_id>/comments", methods=["POST"])
@auth_required
def create_comment(task_id: str):
    """
    Create a comment on a task. Content is encrypted before being stored.
    ---
    tags: [Comments]
    security: [{Bearer: []}]
    parameters:
      - {in: path, name: task_id, type: string, required: true}
      - in: body
        name: body
        required: true
        schema:
          type: object
          required: [content]
          properties:
            content: {type: string}
    responses:
      201:
        description: Comment created
      400:
        description: Validation error
      403:
        description: Forbidden
      404:
        description: Task not found
    """
    try:
        author_id = int(get_jwt_identity())
    except (ValueError, TypeError):
        return jsonify({"error": "Invalid token identity"}), 401

    task, error = _load_task_for_user(task_id, author_id, write=True)
    if error:
        return error
    assert task is not None

    data = request.get_json(silent=True) or {}
    content = (data.get("content") or "").strip()
    if not content:
        return jsonify({"error": "content is required"}), 400
    if len(content) > 10_000:
        return jsonify({"error": "content exceeds 10000 chars"}), 400

    comment = TaskComment(task_id=task.id, author_id=author_id)
    comment.content = content
    db.session.add(comment)
    db.session.commit()

    return jsonify({"message": "Comment created", "comment": comment.to_dict()}), 201


@comments_bp.route("/<task_id>/comments", methods=["GET"])
@auth_required
def list_comments(task_id: str):
    """
    List comments for a task. Content is decrypted on-the-fly.
    ---
    tags: [Comments]
    security: [{Bearer: []}]
    parameters:
      - {in: path, name: task_id, type: string, required: true}
    responses:
      200:
        description: List of comments
      403:
        description: Forbidden
    """
    try:
        user_id = int(get_jwt_identity())
    except (ValueError, TypeError):
        return jsonify({"error": "Invalid token identity"}), 401

    task, error = _load_task_for_user(task_id, user_id, write=False)
    if error:
        return error
    assert task is not None

    rows = (
        TaskComment.query.filter_by(task_id=task.id)
        .order_by(TaskComment.created_at.asc())
        .all()
    )
    return jsonify({"items": [c.to_dict() for c in rows]}), 200
