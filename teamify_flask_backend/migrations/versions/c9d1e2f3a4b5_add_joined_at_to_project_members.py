"""add joined_at to project_members

Revision ID: c9d1e2f3a4b5
Revises: a1b2c3d4e5f6
Create Date: 2026-05-22

Adds the joined_at timestamp to project_members so we can record
when each user joined a project. Existing rows are back-filled with
the current UTC timestamp so NOT NULL is satisfied without data loss.
"""
from alembic import op
import sqlalchemy as sa
from datetime import datetime, timezone
from sqlalchemy import inspect


revision = 'c9d1e2f3a4b5'
down_revision = 'a1b2c3d4e5f6'
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    if 'joined_at' in {c['name'] for c in inspect(bind).get_columns('project_members')}:
        return
    # Add column as nullable first to allow back-fill on existing rows
    with op.batch_alter_table('project_members', schema=None) as batch_op:
        batch_op.add_column(
            sa.Column(
                'joined_at',
                sa.DateTime(),
                nullable=True,
            )
        )

    # Back-fill existing rows with current UTC time
    op.execute(
        "UPDATE project_members SET joined_at = '{}' WHERE joined_at IS NULL".format(
            datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S')
        )
    )

    # Tighten to NOT NULL now that all rows have a value
    with op.batch_alter_table('project_members', schema=None) as batch_op:
        batch_op.alter_column('joined_at', nullable=False)


def downgrade():
    with op.batch_alter_table('project_members', schema=None) as batch_op:
        batch_op.drop_column('joined_at')
