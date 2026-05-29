from __future__ import annotations

import logging

from flask import Blueprint, request, jsonify
from flask_jwt_extended import get_jwt_identity
from middleware.auth import auth_required
from models import db
from models.notification import Notification

logger = logging.getLogger(__name__)

notifications_bp = Blueprint("notifications", __name__, url_prefix="/api/notifications")


# ─── GET /api/notifications ──────────────────────────────────────────────────

@notifications_bp.route("", methods=["GET"])
@auth_required
def get_notifications():
    """
    Get notifications for the current user.
    ---
    tags:
      - Notifications
    security:
      - Bearer: []
    parameters:
      - in: query
        name: limit
        type: integer
        default: 50
      - in: query
        name: unread_only
        type: boolean
        default: false
      - in: query
        name: type
        type: string
        description: Filter by notification type
    responses:
      200:
        description: List of notifications
        schema:
          type: object
          properties:
            notifications:
              type: array
              items:
                type: object
            total:
              type: integer
            unread_count:
              type: integer
      401:
        description: Unauthorized
        schema:
          type: object
          properties:
            error:
              type: string
    """
    user_id = int(get_jwt_identity())
    limit = min(int(request.args.get("limit", 50)), 200)
    unread_only = request.args.get("unread_only", "false").lower() == "true"
    notif_type = request.args.get("type", "").strip()

    query = Notification.query.filter_by(user_id=user_id)

    if unread_only:
        query = query.filter_by(is_read=False)

    if notif_type:
        query = query.filter_by(type=notif_type)

    notifications = (
        query
        .order_by(Notification.created_at.desc())
        .limit(limit)
        .all()
    )

    unread_count = Notification.query.filter_by(user_id=user_id, is_read=False).count()

    return jsonify({
        "notifications": [n.to_dict() for n in notifications],
        "total": len(notifications),
        "unread_count": unread_count,
    }), 200


# ─── GET /api/notifications/unread-count ─────────────────────────────────────

@notifications_bp.route("/unread-count", methods=["GET"])
@auth_required
def unread_count():
    """
    Get the count of unread notifications.
    ---
    tags:
      - Notifications
    security:
      - Bearer: []
    responses:
      200:
        description: Unread notification count
        schema:
          type: object
          properties:
            unread_count:
              type: integer
      401:
        description: Unauthorized
        schema:
          type: object
          properties:
            error:
              type: string
    """
    user_id = int(get_jwt_identity())
    count = Notification.query.filter_by(user_id=user_id, is_read=False).count()
    return jsonify({"unread_count": count}), 200


# ─── PATCH /api/notifications/<id>/read ──────────────────────────────────────

@notifications_bp.route("/<int:notif_id>/read", methods=["PATCH"])
@auth_required
def mark_as_read(notif_id):
    """
    Mark a single notification as read.
    ---
    tags:
      - Notifications
    security:
      - Bearer: []
    parameters:
      - in: path
        name: notif_id
        type: string
        required: true
    responses:
      200:
        description: Notification marked as read
        schema:
          type: object
          properties:
            message:
              type: string
            notification:
              type: object
      404:
        description: Notification not found
        schema:
          type: object
          properties:
            error:
              type: string
    """
    user_id = int(get_jwt_identity())
    notif = Notification.query.filter_by(id=notif_id, user_id=user_id).first()
    if not notif:
        return jsonify({"error": "Notification not found"}), 404

    notif.is_read = True
    db.session.commit()
    return jsonify({"message": "Marked as read", "notification": notif.to_dict()}), 200


# ─── POST /api/notifications/mark-all-read ───────────────────────────────────

@notifications_bp.route("/mark-all-read", methods=["POST"])
@auth_required
def mark_all_read():
    """
    Mark all notifications as read for the current user.
    ---
    tags:
      - Notifications
    security:
      - Bearer: []
    responses:
      200:
        description: All notifications marked as read
        schema:
          type: object
          properties:
            message:
              type: string
      401:
        description: Unauthorized
        schema:
          type: object
          properties:
            error:
              type: string
    """
    user_id = int(get_jwt_identity())
    updated = (
        Notification.query
        .filter_by(user_id=user_id, is_read=False)
        .update({"is_read": True})
    )
    db.session.commit()
    return jsonify({"message": f"Marked {updated} notifications as read"}), 200


# ─── Helper: create notification (used by other routes) ──────────────────────

def create_notification(
    user_id: int,
    notif_type: str,
    title: str,
    body: str | None = None,
    entity_type: str | None = None,
    entity_id: int | None = None,
) -> Notification:
    """
    Persist a Notification row AND emit a real-time Socket.IO event to the
    user's personal room (``user_<user_id>``).

    The caller is responsible for calling ``db.session.commit()`` after this
    function returns (or the caller can rely on an enclosing commit).
    """
    notif = Notification(
        user_id=user_id,
        type=notif_type,
        title=title,
        body=body,
        entity_type=entity_type,
        entity_id=entity_id,
    )
    db.session.add(notif)

    # Flush so notif.id is populated before we serialise
    try:
        db.session.flush()
    except Exception:
        pass  # caller's commit will surface the error

    # Emit real-time event to the user's personal Socket.IO room
    _emit_notification(user_id, notif)

    return notif


def _emit_notification(user_id: int, notif: Notification) -> None:
    """Push ``new_notification`` to the user's personal room. Never raises."""
    try:
        from app import socketio
        unread_count = Notification.query.filter_by(
            user_id=user_id, is_read=False
        ).count()
        payload = {
            **notif.to_dict(),
            "unread_count": unread_count,
        }
        socketio.emit("new_notification", payload, to=f"user_{user_id}")
        logger.debug(
            "Emitted new_notification to user_%s id=%s", user_id, notif.id
        )
    except Exception as exc:
        # Non-fatal — the notification is already saved in DB
        logger.warning("Failed to emit new_notification for user %s: %s", user_id, exc)
