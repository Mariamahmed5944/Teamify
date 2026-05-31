"""admin panel tables and indexes

Revision ID: l2m3n4o5p6q7
Revises: k1l2m3n4o5p6
Create Date: 2026-05-31
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "l2m3n4o5p6q7"
down_revision = "k1l2m3n4o5p6"
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    tables = inspect(bind).get_table_names()

    if "admin_analytics_snapshots" not in tables:
        op.create_table(
            "admin_analytics_snapshots",
            sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
            sa.Column("snapshot_date", sa.Date(), nullable=False),
            sa.Column("total_users", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("active_users", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("new_users", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("total_projects", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("active_projects", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("tasks_completed", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("disputes_opened", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("disputes_resolved", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("ai_requests", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("created_at", sa.DateTime(), nullable=True),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("snapshot_date"),
        )
        op.create_index("ix_admin_analytics_snapshots_date", "admin_analytics_snapshots", ["snapshot_date"])

    if "broadcast_history" not in tables:
        op.create_table(
            "broadcast_history",
            sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
            sa.Column("admin_id", sa.Integer(), nullable=True),
            sa.Column("target_audience", sa.String(length=50), nullable=False),
            sa.Column("title", sa.String(length=255), nullable=False),
            sa.Column("body", sa.Text(), nullable=False),
            sa.Column("recipient_count", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("sent_at", sa.DateTime(), nullable=True),
            sa.ForeignKeyConstraint(["admin_id"], ["users.id"], ondelete="SET NULL"),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index("ix_broadcast_history_sent_at", "broadcast_history", ["sent_at"])

    if "role_permissions" not in tables:
        op.create_table(
            "role_permissions",
            sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
            sa.Column("role", sa.String(length=30), nullable=False),
            sa.Column("permissions", sa.JSON(), nullable=False),
            sa.Column("updated_by", sa.Integer(), nullable=True),
            sa.Column("updated_at", sa.DateTime(), nullable=True),
            sa.ForeignKeyConstraint(["updated_by"], ["users.id"], ondelete="SET NULL"),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("role"),
        )
        op.create_index("ix_role_permissions_role", "role_permissions", ["role"])

    if "admin_sessions" not in tables:
        op.create_table(
            "admin_sessions",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column("user_id", sa.Integer(), nullable=False),
            sa.Column("jti", sa.String(length=64), nullable=True),
            sa.Column("ip_address", sa.String(length=50), nullable=True),
            sa.Column("device_info", sa.String(length=255), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=True),
            sa.Column("revoked_at", sa.DateTime(), nullable=True),
            sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        )
        op.create_index("ix_admin_sessions_user_id", "admin_sessions", ["user_id"])
        op.create_index("ix_admin_sessions_jti", "admin_sessions", ["jti"])

    # Performance indexes (skip if already exist)
    _safe_index("logs", "ix_logs_user_created", ["user_id", "created_at"])
    _safe_index("logs", "ix_logs_action_created", ["action", "created_at"])
    _safe_index("audit_logs", "ix_audit_logs_user_created", ["user_id", "created_at"])
    _safe_index("audit_logs", "ix_audit_logs_action_severity", ["action", "severity", "created_at"])
    _safe_index("disputes", "ix_disputes_status_created", ["status", "created_at"])
    _safe_index("disputes", "ix_disputes_parties", ["reporter_id", "accused_id"])
    _safe_index("feedbacks", "ix_feedbacks_user_created", ["user_id", "created_at"])


def _safe_index(table, name, columns):
    bind = op.get_bind()
    existing = {idx["name"] for idx in inspect(bind).get_indexes(table)}
    if name not in existing:
        op.create_index(name, table, columns)


def downgrade():
    for name in (
        "ix_feedbacks_user_created",
        "ix_disputes_parties",
        "ix_disputes_status_created",
        "ix_audit_logs_action_severity",
        "ix_audit_logs_user_created",
        "ix_logs_action_created",
        "ix_logs_user_created",
    ):
        try:
            op.drop_index(name)
        except Exception:
            pass
    for table in ("admin_sessions", "role_permissions", "broadcast_history", "admin_analytics_snapshots"):
        try:
            op.drop_table(table)
        except Exception:
            pass
