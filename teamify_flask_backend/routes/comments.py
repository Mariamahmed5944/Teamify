"""Encrypted task comments. Content is Fernet-encrypted at rest."""
from __future__ import annotations


from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity

from middleware.auth import auth_required
from models import db
from models.task import Task
from models.task_comment import TaskComment

comments_bp = Blueprint("comments", __name__, url_prefix="/api/tasks")


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
    responses:
      201:
        description: Comment created
        schema:
          type: object
          properties:
            message:
              type: string
            comment:
              type: object
      400:
        description: Validation error
        schema:
          type: object
          properties:
            error:
              type: string
      404:
        description: Task not found
        schema:
          type: object
          properties:
            error:
              type: string
    """
    try:
        tid = int(task_id)
    except (ValueError, AttributeError):
        return jsonify({"error": "Invalid task_id"}), 400

    if not Task.query.filter_by(id=tid).first():
        return jsonify({"error": "Task not found"}), 404

    data = request.get_json(silent=True) or {}
    content = (data.get("content") or "").strip()
    if not content:
        return jsonify({"error": "content is required"}), 400
    if len(content) > 10_000:
        return jsonify({"error": "content exceeds 10000 chars"}), 400

    try:
        author_id = int(get_jwt_identity())
    except (ValueError, TypeError):
        return jsonify({"error": "Invalid token identity"}), 401

    comment = TaskComment(task_id=tid, author_id=author_id)
    comment.content = content  # transparently encrypted by the property setter
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
    responses:
      200:
        description: List of comments
        schema:
          type: object
          properties:
            items:
              type: array
              items:
                type: object
      401:
        description: Unauthorized
        schema:
          type: object
          properties:
            error:
              type: string
    """
    try:
        tid = int(task_id)
    except (ValueError, AttributeError):
        return jsonify({"error": "Invalid task_id"}), 400

    rows = (
        TaskComment.query.filter_by(task_id=tid)
        .order_by(TaskComment.created_at.asc())
        .all()
    )
    return jsonify({"items": [c.to_dict() for c in rows]}), 200
