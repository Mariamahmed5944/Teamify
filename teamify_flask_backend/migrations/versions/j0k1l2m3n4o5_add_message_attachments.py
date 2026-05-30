"""add message_type and file_id to messages

Revision ID: j0k1l2m3n4o5
Revises: i9j0k1l2m3n4
Create Date: 2026-05-29
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "j0k1l2m3n4o5"
down_revision = "i9j0k1l2m3n4"
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    insp = inspect(bind)
    cols = {c["name"] for c in insp.get_columns("messages")}
    if "message_type" in cols and "file_id" in cols:
        return
    with op.batch_alter_table("messages", schema=None) as batch_op:
        if "message_type" not in cols:
            batch_op.add_column(
                sa.Column(
                    "message_type",
                    sa.String(length=20),
                    nullable=False,
                    server_default="text",
                )
            )
        if "file_id" not in cols:
            batch_op.add_column(sa.Column("file_id", sa.Integer(), nullable=True))
    fks = {fk["name"] for fk in insp.get_foreign_keys("messages")}
    if "fk_messages_file_id" not in fks:
        with op.batch_alter_table("messages", schema=None) as batch_op:
            batch_op.create_foreign_key(
                "fk_messages_file_id",
                "file_metadata",
                ["file_id"],
                ["id"],
                ondelete="SET NULL",
            )


def downgrade():
    with op.batch_alter_table("messages", schema=None) as batch_op:
        batch_op.drop_constraint("fk_messages_file_id", type_="foreignkey")
        batch_op.drop_column("file_id")
        batch_op.drop_column("message_type")
