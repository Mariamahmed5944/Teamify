"""add ai_summary to meeting_sessions

Revision ID: g7h8i9j0k1l2
Revises: f6a7b8c9d0e1
Create Date: 2026-05-22
"""
from alembic import op
import sqlalchemy as sa


revision = "g7h8i9j0k1l2"
down_revision = "a7b8c9d0e1f2"
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table("meeting_sessions", schema=None) as batch_op:
        batch_op.add_column(sa.Column("ai_summary", sa.JSON(), nullable=True))


def downgrade():
    with op.batch_alter_table("meeting_sessions", schema=None) as batch_op:
        batch_op.drop_column("ai_summary")
