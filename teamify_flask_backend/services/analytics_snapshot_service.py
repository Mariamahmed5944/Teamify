"""Daily admin analytics snapshot aggregation."""
from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

from sqlalchemy import func

from models import db
from models.admin_panel import AdminAnalyticsSnapshot
from models.dispute import Dispute
from models.project import Project
from models.task import Task
from models.user import User


def create_daily_snapshot(for_date: date | None = None) -> AdminAnalyticsSnapshot:
    """Aggregate platform KPIs for a single day and upsert snapshot row."""
    snap_date = for_date or date.today()
    day_start = datetime(snap_date.year, snap_date.month, snap_date.day, tzinfo=timezone.utc)
    day_end = day_start + timedelta(days=1)

    total_users = User.query.count()
    active_users = User.query.filter(User.account_status == "approved").count()
    new_users = User.query.filter(
        User.created_at >= day_start,
        User.created_at < day_end,
    ).count()

    total_projects = Project.query.count()
    active_projects = Project.query.filter(Project.status != "completed").count()
    tasks_completed = Task.query.filter(
        Task.status == "done",
        Task.updated_at >= day_start,
        Task.updated_at < day_end,
    ).count()

    disputes_opened = Dispute.query.filter(
        Dispute.created_at >= day_start,
        Dispute.created_at < day_end,
    ).count()
    disputes_resolved = Dispute.query.filter(
        Dispute.resolved_at >= day_start,
        Dispute.resolved_at < day_end,
    ).count()

    # Approximate AI usage from audit logs when dedicated counter unavailable
    from models.audit_log import AuditLog

    ai_requests = AuditLog.query.filter(
        AuditLog.action.ilike("%AI%"),
        AuditLog.created_at >= day_start,
        AuditLog.created_at < day_end,
    ).count()

    row = AdminAnalyticsSnapshot.query.filter_by(snapshot_date=snap_date).first()
    if not row:
        row = AdminAnalyticsSnapshot(snapshot_date=snap_date)
        db.session.add(row)

    row.total_users = total_users
    row.active_users = active_users
    row.new_users = new_users
    row.total_projects = total_projects
    row.active_projects = active_projects
    row.tasks_completed = tasks_completed
    row.disputes_opened = disputes_opened
    row.disputes_resolved = disputes_resolved
    row.ai_requests = ai_requests
    db.session.commit()
    return row


def get_time_series(metric: str, from_date: date, to_date: date) -> list[dict]:
    """Return daily values for a metric between two dates."""
    rows = (
        AdminAnalyticsSnapshot.query.filter(
            AdminAnalyticsSnapshot.snapshot_date >= from_date,
            AdminAnalyticsSnapshot.snapshot_date <= to_date,
        )
        .order_by(AdminAnalyticsSnapshot.snapshot_date.asc())
        .all()
    )
    field_map = {
        "users": "total_users",
        "active_users": "active_users",
        "new_users": "new_users",
        "projects": "total_projects",
        "active_projects": "active_projects",
        "tasks_completed": "tasks_completed",
        "disputes_opened": "disputes_opened",
        "disputes_resolved": "disputes_resolved",
        "ai_requests": "ai_requests",
    }
    attr = field_map.get(metric, "total_users")
    return [
        {"date": r.snapshot_date.isoformat(), "value": getattr(r, attr, 0)}
        for r in rows
    ]


def compute_user_retention() -> float:
    """Simple 30-day retention: users active in last 30d / users created 30+ days ago."""
    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(days=30)
    older_users = User.query.filter(User.created_at <= cutoff).count()
    if older_users == 0:
        return 100.0
    from models.login_log import LoginLog

    active_recent = (
        db.session.query(func.count(func.distinct(LoginLog.user_id)))
        .filter(LoginLog.timestamp >= cutoff, LoginLog.status == "success")
        .scalar()
        or 0
    )
    return round(min(100.0, (active_recent / older_users) * 100), 1)
