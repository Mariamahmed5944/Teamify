"""
Flask-SocketIO event handlers for real-time chat.

Events:
  connect       – Authenticate via JWT token in the query string or auth dict.
  join_chat     – Join a SocketIO room (requires membership).
  send_message  – Broadcast a message to all room members + persist to DB.
  disconnect    – Cleanup.
"""
from flask import request
from flask_socketio import emit, join_room, disconnect
from flask_jwt_extended import decode_token
from models import db
from models.chat import ChatRoom, ChatRoomMember, Message
from models.user import User


# Mapping: SocketIO session id → user id (for cleanup on disconnect)
_sid_to_uid: dict[str, int] = {}


def register_chat_events(socketio):
    """Register all chat SocketIO event handlers."""

    @socketio.on("connect")
    def handle_connect(auth=None):
        """
        Authenticate the WebSocket connection.
        The client sends the JWT token in ONE of these ways:
          1. Query string: ?token=<JWT>
          2. Auth dict:    io.connect(url, { auth: { token: "<JWT>" } })
        """
        token = None

        # Try auth dict first (Socket.IO v4+)
        if auth and isinstance(auth, dict):
            token = auth.get("token")

        # Fall back to query string
        if not token:
            token = request.args.get("token")

        if not token:
            print("[WS] Connection rejected — no token provided")
            disconnect()
            return False

        try:
            decoded = decode_token(token)
            user_id = int(decoded["sub"])
        except Exception as e:
            print(f"[WS] Connection rejected — invalid token: {e}")
            disconnect()
            return False

        # Verify user exists
        user = db.session.get(User, user_id)
        if not user:
            print(f"[WS] Connection rejected — user {user_id} not found")
            disconnect()
            return False

        _sid_to_uid[request.sid] = user_id
        print(f"[WS] User {user_id} ({user.display_name}) connected — sid={request.sid}")
        return True

    @socketio.on("disconnect")
    def handle_disconnect():
        uid = _sid_to_uid.pop(request.sid, None)
        print(f"[WS] Disconnected — sid={request.sid}, user={uid}")

    @socketio.on("join_chat")
    def handle_join(data):
        """
        Client sends: { "room_id": <int> }
        Server joins the socket to the room if the user is a member.
        """
        user_id = _sid_to_uid.get(request.sid)
        if user_id is None:
            emit("error", {"message": "Not authenticated"})
            return

        room_id = data.get("room_id") if isinstance(data, dict) else None
        if room_id is None:
            emit("error", {"message": "room_id is required"})
            return

        try:
            room_id = int(room_id)
        except (ValueError, TypeError):
            emit("error", {"message": "Invalid room_id"})
            return

        # Verify membership
        membership = ChatRoomMember.query.filter_by(
            room_id=room_id, user_id=user_id
        ).first()
        if not membership:
            emit("error", {"message": "You are not a member of this room"})
            return

        room_name = f"chat_{room_id}"
        join_room(room_name)
        emit("joined", {"room_id": room_id, "user_id": user_id}, to=room_name)
        print(f"[WS] User {user_id} joined room {room_name}")

    @socketio.on("send_message")
    def handle_send_message(data):
        """
        Client sends: { "room_id": <int>, "content": "<text>" }
        Server persists the message, then emits 'receive_message' to the room.
        """
        user_id = _sid_to_uid.get(request.sid)
        if user_id is None:
            emit("error", {"message": "Not authenticated"})
            return

        if not isinstance(data, dict):
            emit("error", {"message": "Invalid payload"})
            return

        room_id = data.get("room_id")
        content = (data.get("content") or "").strip()

        if not room_id:
            emit("error", {"message": "room_id is required"})
            return
        if not content:
            emit("error", {"message": "content is required"})
            return

        try:
            room_id = int(room_id)
        except (ValueError, TypeError):
            emit("error", {"message": "Invalid room_id"})
            return

        # Verify membership
        membership = ChatRoomMember.query.filter_by(
            room_id=room_id, user_id=user_id
        ).first()
        if not membership:
            emit("error", {"message": "You are not a member of this room"})
            return

        # Persist
        msg = Message(room_id=room_id, sender_id=user_id, content=content)
        db.session.add(msg)
        db.session.commit()

        # Broadcast to room
        room_name = f"chat_{room_id}"
        emit("receive_message", msg.to_dict(), to=room_name)
        print(f"[WS] Message from user {user_id} in room {room_id}: {content[:60]}")
