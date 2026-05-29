"""add project_id to file_metadata

Revision ID: e5f6a7b8c9d0
Revises: d4e5f6a7b8c9
Create Date: 2026-05-22
"""
from alembic import op
import sqlalchemy as sa


revision = 'e5f6a7b8c9d0'
down_revision = 'd4e5f6a7b8c9'
branch_labels = None
depends_on = None


def upgrade():
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
