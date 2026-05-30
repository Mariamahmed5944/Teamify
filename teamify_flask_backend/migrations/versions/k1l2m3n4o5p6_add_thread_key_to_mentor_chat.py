"""add thread_key to mentor_chat_messages

Revision ID: k1l2m3n4o5p6
Revises: j0k1l2m3n4o5
Create Date: 2026-05-30
"""
from alembic import op
import sqlalchemy as sa


revision = "k1l2m3n4o5p6"
down_revision = "j0k1l2m3n4o5"
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    insp = sa.inspect(bind)
    if "mentor_chat_messages" not in insp.get_table_names():
        return
    cols = {c["name"] for c in insp.get_columns("mentor_chat_messages")}
    if "thread_key" in cols:
        return
    with op.batch_alter_table("mentor_chat_messages", schema=None) as batch_op:
        batch_op.add_column(
            sa.Column(
                "thread_key",
                sa.String(length=120),
                nullable=False,
                server_default="general",
            )
        )
        batch_op.create_index(
            "ix_mentor_chat_messages_thread_key",
            ["thread_key"],
            unique=False,
        )


def downgrade():
    with op.batch_alter_table("mentor_chat_messages", schema=None) as batch_op:
        batch_op.drop_index("ix_mentor_chat_messages_thread_key")
        batch_op.drop_column("thread_key")
