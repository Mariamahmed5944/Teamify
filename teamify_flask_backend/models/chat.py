"""Chat models: ChatRoom, ChatRoomMember, and Message."""
from datetime import datetime, timezone
from models import db


class ChatRoom(db.Model):
    """A chat room — optionally tied to a project."""

    __tablename__ = "chat_rooms"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    name = db.Column(db.String(150), nullable=True)
    project_id = db.Column(
        db.Integer,
        db.ForeignKey("projects.id", ondelete="SET NULL"),
        nullable=True,
    )
    is_group = db.Column(db.Boolean, default=False, nullable=False)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    # Relationships
    members = db.relationship(
        "ChatRoomMember", backref="room", lazy=True, cascade="all, delete-orphan"
    )
    messages = db.relationship(
        "Message", backref="room", lazy="dynamic", cascade="all, delete-orphan"
    )

    def to_dict(self, include_last_message=False):
        d = {
            "id": self.id,
            "name": self.name,
            "project_id": self.project_id,
            "is_group": self.is_group,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "member_ids": [m.user_id for m in self.members],
        }
        if include_last_message:
            last = (
                Message.query.filter_by(room_id=self.id)
                .order_by(Message.created_at.desc())
                .first()
            )
            d["last_message"] = last.to_dict() if last else None
        return d

    def __repr__(self):
        return f"<ChatRoom {self.id} name={self.name}>"


class ChatRoomMember(db.Model):
    """Tracks which users belong to which chat rooms."""

    __tablename__ = "chat_room_members"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    room_id = db.Column(
        db.Integer,
        db.ForeignKey("chat_rooms.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id = db.Column(
        db.Integer,
        db.ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    joined_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    __table_args__ = (
        db.UniqueConstraint("room_id", "user_id", name="uq_chatroom_member"),
        db.Index("ix_crm_room_id", "room_id"),
        db.Index("ix_crm_user_id", "user_id"),
    )

    def __repr__(self):
        return f"<ChatRoomMember room={self.room_id} user={self.user_id}>"


class Message(db.Model):
    """A single chat message inside a room."""

    __tablename__ = "messages"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    room_id = db.Column(
        db.Integer,
        db.ForeignKey("chat_rooms.id", ondelete="CASCADE"),
        nullable=False,
    )
    sender_id = db.Column(
        db.Integer,
        db.ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    content = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    # Relationship to user
    sender = db.relationship("User", backref="messages", lazy=True)

    __table_args__ = (
        db.Index("ix_msg_room_created", "room_id", "created_at"),
    )

    def to_dict(self):
        sender_name = ""
        if self.sender:
            sender_name = self.sender.full_name or self.sender.display_name or ""
        return {
            "id": self.id,
            "room_id": self.room_id,
            "sender_id": self.sender_id,
            "sender_name": sender_name,
            "content": self.content,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }

    def __repr__(self):
        return f"<Message {self.id} room={self.room_id}>"
