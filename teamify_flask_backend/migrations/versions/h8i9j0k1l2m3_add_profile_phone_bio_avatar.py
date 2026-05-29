"""add phone, bio, avatar_file_id to users

Revision ID: h8i9j0k1l2m3
Revises: g7h8i9j0k1l2
Create Date: 2026-05-24

"""
from alembic import op
import sqlalchemy as sa


revision = "h8i9j0k1l2m3"
down_revision = "g7h8i9j0k1l2"
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.add_column(sa.Column("phone", sa.String(length=30), nullable=True))
        batch_op.add_column(sa.Column("bio", sa.Text(), nullable=True))
        batch_op.add_column(sa.Column("avatar_file_id", sa.Integer(), nullable=True))
        batch_op.create_foreign_key(
            "fk_users_avatar_file_id",
            "file_metadata",
            ["avatar_file_id"],
            ["id"],
            ondelete="SET NULL",
        )


def downgrade():
    with op.batch_alter_table("users", schema=None) as batch_op:
        batch_op.drop_constraint("fk_users_avatar_file_id", type_="foreignkey")
        batch_op.drop_column("avatar_file_id")
        batch_op.drop_column("bio")
        batch_op.drop_column("phone")
