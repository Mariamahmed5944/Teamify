"""add token_blocklist table

Revision ID: a1b2c3d4e5f6
Revises: f423c35e5f2a
Create Date: 2026-05-21 00:00:00.000000

Replaces the in-memory BLACKLISTED_TOKENS set() with a durable DB table.
On server restart the blocklist is preserved.
"""
from alembic import op
import sqlalchemy as sa

revision = 'a1b2c3d4e5f6'
down_revision = 'f423c35e5f2a'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'token_blocklist',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('jti', sa.String(36), nullable=False),
        sa.Column('revoked_at', sa.DateTime(), nullable=False,
                  server_default=sa.func.now()),
        sa.Column('expires_at', sa.DateTime(), nullable=True),
    )
    op.create_index('ix_token_blocklist_jti', 'token_blocklist', ['jti'],
                    unique=True)
    op.create_index('ix_token_blocklist_revoked_at', 'token_blocklist',
                    ['revoked_at'])


def downgrade():
    op.drop_index('ix_token_blocklist_revoked_at', table_name='token_blocklist')
    op.drop_index('ix_token_blocklist_jti', table_name='token_blocklist')
    op.drop_table('token_blocklist')
