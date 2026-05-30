"""add project_id to file_metadata

Revision ID: e5f6a7b8c9d0
Revises: c9d1e2f3a4b5
Create Date: 2026-05-22
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = 'e5f6a7b8c9d0'
down_revision = 'c9d1e2f3a4b5'
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    if 'project_id' in {c['name'] for c in inspect(bind).get_columns('file_metadata')}:
        return
    with op.batch_alter_table('file_metadata', schema=None) as batch_op:
        batch_op.add_column(sa.Column('project_id', sa.Integer(), nullable=True))
        batch_op.create_foreign_key(
            'fk_file_metadata_project_id',
            'projects',
            ['project_id'],
            ['id'],
            ondelete='CASCADE',
        )
        batch_op.create_index('ix_file_metadata_project_id', ['project_id'])


def downgrade():
    with op.batch_alter_table('file_metadata', schema=None) as batch_op:
        batch_op.drop_index('ix_file_metadata_project_id')
        batch_op.drop_constraint('fk_file_metadata_project_id', type_='foreignkey')
        batch_op.drop_column('project_id')
