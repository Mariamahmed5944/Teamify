"""REST endpoints for chat rooms and message history."""
from __future__ import annotations

from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity

from middleware.auth import auth_required
from models import db
from models.chat import ChatRoom, ChatRoomMember, Message
from models.user import User

chat_bp = Blueprint("chat", __name__, url_prefix="/api/chat")


# ── List rooms the current user belongs to ────────────────────────────────────
@chat_bp.route("/rooms", methods=["GET"])
@auth_required
def list_rooms():
    """
    List chat rooms the authenticated user belongs to.
    ---
    tags: [Chat]
    security: [{Bearer: []}]
    responses:
      200:
        description: Array of rooms
        schema:
          type: object
          properties:
            rooms:
              type: array
              items:
                type: object
    """
    user_id = int(get_jwt_identity())
    memberships = ChatRoomMember.query.filter_by(user_id=user_id).all()
    room_ids = [m.room_id for m in memberships]

    if not room_ids:
        return jsonify({"rooms": []}), 200

    rooms = ChatRoom.query.filter(ChatRoom.id.in_(room_ids)).all()
    return jsonify({
        "rooms": [r.to_dict(include_last_message=True) for r in rooms]
    }), 200


# ── Create a new chat room ────────────────────────────────────────────────────
@chat_bp.route("/rooms", methods=["POST"])
@auth_required
def create_room():
    """
    Create a new chat room and add the creator as a member.
    ---
    tags: [Chat]
    security: [{Bearer: []}]
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          properties:
            name: {type: string}
            project_id: {type: integer}
            is_group: {type: boolean}
            member_ids:
              type: array
              items: {type: integer}
    responses:
      201:
        description: Room created
      400:
        description: Validation error
    """
    user_id = int(get_jwt_identity())
    data = request.get_json(silent=True) or {}

    room = ChatRoom(
        name=data.get("name"),
        project_id=data.get("project_id"),
        is_group=data.get("is_group", False),
    )
    db.session.add(room)
    db.session.flush()  # get room.id

    # Add creator
    db.session.add(ChatRoomMember(room_id=room.id, user_id=user_id))

    # Add extra members
    for mid in data.get("member_ids", []):
        try:
            mid = int(mid)
        except (ValueError, TypeError):
            continue
        if mid != user_id and User.query.filter_by(id=mid).first():
            db.session.add(ChatRoomMember(room_id=room.id, user_id=mid))

    db.session.commit()
    return jsonify({"message": "Room created", "room": room.to_dict()}), 201


# ── Get message history for a room ────────────────────────────────────────────
@chat_bp.route("/rooms/<int:room_id>/messages", methods=["GET"])
@auth_required
def get_messages(room_id):
    """
    Fetch historical messages for a chat room, ordered by created_at ascending.
    Supports pagination via ?page=1&per_page=50
    ---
    tags: [Chat]
    security: [{Bearer: []}]
    parameters:
      - {in: path, name: room_id, type: integer, required: true}
      - {in: query, name: page, type: integer, required: false}
      - {in: query, name: per_page, type: integer, required: false}
    responses:
      200:
        description: Paginated messages
      403:
        description: Not a member of this room
      404:
        description: Room not found
    """
    user_id = int(get_jwt_identity())

    room = db.session.get(ChatRoom, room_id)
    if not room:
        return jsonify({"error": "Room not found"}), 404

    # Verify membership
    membership = ChatRoomMember.query.filter_by(
        room_id=room_id, user_id=user_id
    ).first()
    if not membership:
        return jsonify({"error": "You are not a member of this room"}), 403

    page = request.args.get("page", 1, type=int)
    per_page = min(request.args.get("per_page", 50, type=int), 100)

    pagination = (
        Message.query.filter_by(room_id=room_id)
        .order_by(Message.created_at.asc())
        .paginate(page=page, per_page=per_page, error_out=False)
    )

    return jsonify({
        "messages": [m.to_dict() for m in pagination.items],
        "page": pagination.page,
        "per_page": pagination.per_page,
        "total": pagination.total,
        "pages": pagination.pages,
    }), 200
