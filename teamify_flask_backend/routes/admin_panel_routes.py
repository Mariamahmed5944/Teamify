"""Extended admin panel routes (audit logs, analytics, roles, export, leaderboard)."""
from __future__ import annotations

import csv
import io
from datetime import date, datetime, timedelta, timezone

from flask import jsonify, make_response, request
from flask_jwt_extended import get_jwt_identity
from sqlalchemy import or_

from middleware.auth import admin_required
from models import db
from models.admin_panel import AdminAnalyticsSnapshot, BroadcastHistory, RolePermission
from models.audit_log import AuditLog
from models.dispute import Dispute
from models.feedback import Feedback
from models.project import Project
from models.user import User
from routes.admin import admin_bp, _page_args
from services.analytics_snapshot_service import (
    compute_user_retention,
    create_daily_snapshot,
    get_time_series,
)
from utils.admin_audit import log_admin_action


@admin_bp.route("/audit-logs", methods=["GET"])
@admin_required
def list_audit_logs():
    """Paginated security audit log query."""
    page, per_page, page_err = _page_args(50)
    if page_err:
        return page_err
    action = request.args.get("action", "").strip()
    severity = request.args.get("severity", "").strip()
    user_id = request.args.get("user_id", type=int)
    search = request.args.get("search", "").strip()
    from_date = request.args.get("from_date", "").strip()
    to_date = request.args.get("to_date", "").strip()

    q = AuditLog.query
    if action:
        q = q.filter(AuditLog.action.ilike(f"%{action}%"))
    if severity:
        q = q.filter(AuditLog.severity == severity.upper())
    if user_id:
        q = q.filter(AuditLog.user_id == user_id)
    if search:
        pattern = f"%{search}%"
        q = q.filter(or_(AuditLog.action.ilike(pattern), AuditLog.details.ilike(pattern)))
    if from_date:
        try:
            q = q.filter(AuditLog.created_at >= datetime.fromisoformat(from_date))
        except ValueError:
            pass
    if to_date:
        try:
            q = q.filter(AuditLog.created_at <= datetime.fromisoformat(to_date))
        except ValueError:
            pass

    p = q.order_by(AuditLog.created_at.desc()).paginate(page=page, per_page=per_page, error_out=False)
    items = []
    for row in p.items:
        d = row.to_dict()
        if row.user_id:
            u = db.session.get(User, row.user_id)
            d["user_name"] = (u.full_name or u.display_name or u.email) if u else "Unknown"
        items.append(d)

    return jsonify({
        "items": items,
        "total": p.total,
        "page": p.page,
        "pages": p.pages,
        "per_page": p.per_page,
    }), 200


@admin_bp.route("/analytics/time-series", methods=["GET"])
@admin_required
def analytics_time_series():
    metric = request.args.get("metric", "users").strip()
    days = request.args.get("days", 30, type=int)
    to_d = date.today()
    from_d = to_d - timedelta(days=max(1, min(days, 365)))
    return jsonify({
        "metric": metric,
        "from_date": from_d.isoformat(),
        "to_date": to_d.isoformat(),
        "data": get_time_series(metric, from_d, to_d),
    }), 200


@admin_bp.route("/analytics/snapshot", methods=["POST"])
@admin_required
def analytics_create_snapshot():
    row = create_daily_snapshot()
    return jsonify({"message": "Snapshot created", "snapshot": row.to_dict()}), 201


@admin_bp.route("/analytics/export", methods=["GET"])
@admin_required
def analytics_export():
    export_type = request.args.get("type", "logs").strip().lower()
    fmt = request.args.get("format", "csv").strip().lower()
    if fmt != "csv":
        return jsonify({"error": "Only csv format is supported currently"}), 400

    output = io.StringIO()
    writer = csv.writer(output)

    if export_type == "logs":
        writer.writerow(["id", "action", "entity", "entity_id", "details", "user_id", "created_at"])
        from models.log import Log

        for log in Log.query.order_by(Log.created_at.desc()).limit(5000):
            writer.writerow([
                log.id, log.action, log.entity, log.entity_id,
                log.details, log.user_id,
                log.created_at.isoformat() if log.created_at else "",
            ])
        filename = "admin_logs.csv"
    elif export_type == "audit":
        writer.writerow(["id", "user_id", "action", "details", "ip_address", "severity", "created_at"])
        for row in AuditLog.query.order_by(AuditLog.created_at.desc()).limit(5000):
            writer.writerow([
                row.id, row.user_id, row.action, row.details,
                row.ip_address, row.severity,
                row.created_at.isoformat() if row.created_at else "",
            ])
        filename = "audit_logs.csv"
    elif export_type == "disputes":
        writer.writerow(["id", "reporter_id", "accused_id", "status", "category", "subject", "created_at"])
        for d in Dispute.query.order_by(Dispute.created_at.desc()).limit(5000):
            writer.writerow([
                d.id, d.reporter_id, d.accused_id, d.status,
                d.category, d.subject,
                d.created_at.isoformat() if d.created_at else "",
            ])
        filename = "disputes.csv"
    else:
        writer.writerow(["date", "total_users", "new_users", "tasks_completed"])
        for snap in AdminAnalyticsSnapshot.query.order_by(AdminAnalyticsSnapshot.snapshot_date.desc()).limit(365):
            writer.writerow([
                snap.snapshot_date.isoformat(),
                snap.total_users,
                snap.new_users,
                snap.tasks_completed,
            ])
        filename = "analytics.csv"

    resp = make_response(output.getvalue())
    resp.headers["Content-Type"] = "text/csv"
    resp.headers["Content-Disposition"] = f"attachment; filename={filename}"
    return resp


@admin_bp.route("/disputes/<int:dispute_id>", methods=["GET"])
@admin_required
def get_dispute_detail(dispute_id):
    dispute = db.session.get(Dispute, dispute_id)
    if not dispute:
        return jsonify({"error": "Dispute not found"}), 404

    reporter = db.session.get(User, dispute.reporter_id)
    accused = db.session.get(User, dispute.accused_id)
    project = db.session.get(Project, dispute.project_id) if dispute.project_id else None
    resolver = db.session.get(User, dispute.resolved_by) if dispute.resolved_by else None

    payload = dispute.to_dict()
    payload["reporter"] = reporter.to_dict() if reporter else None
    payload["accused"] = accused.to_dict() if accused else None
    payload["project_name"] = project.name if project else None
    payload["resolver_name"] = (
        (resolver.full_name or resolver.display_name) if resolver else None
    )
    return jsonify({"dispute": payload}), 200


@admin_bp.route("/roles", methods=["GET"])
@admin_required
def list_role_permissions():
    rows = RolePermission.query.order_by(RolePermission.role).all()
    if not rows:
        defaults = {
            "admin": {"manage_users": True, "manage_projects": True, "manage_settings": True},
            "member": {"manage_users": False, "manage_projects": False, "manage_settings": False},
            "guest": {"manage_users": False, "manage_projects": False, "manage_settings": False},
        }
        return jsonify({"roles": [{"role": k, "permissions": v} for k, v in defaults.items()]}), 200
    return jsonify({"roles": [r.to_dict() for r in rows]}), 200


@admin_bp.route("/roles/<role>", methods=["PUT"])
@admin_required
def update_role_permissions(role):
    data = request.get_json(silent=True) or {}
    permissions = data.get("permissions")
    if not isinstance(permissions, dict):
        return jsonify({"error": "permissions object is required"}), 400

    admin_id = int(get_jwt_identity())
    row = RolePermission.query.filter_by(role=role.lower()).first()
    if not row:
        row = RolePermission(role=role.lower(), permissions=permissions, updated_by=admin_id)
        db.session.add(row)
    else:
        row.permissions = permissions
        row.updated_by = admin_id
        row.updated_at = datetime.now(timezone.utc)

    log_admin_action(
        admin_id=admin_id,
        action="UPDATE_ROLE_PERMISSIONS",
        entity="RolePermission",
        entity_id=row.id,
        details=f"Updated permissions for role {role}",
        severity="WARNING",
    )
    db.session.commit()
    return jsonify({"message": "Role permissions updated", "role": row.to_dict()}), 200


@admin_bp.route("/notifications/history", methods=["GET"])
@admin_required
def list_broadcast_history():
    page, per_page, page_err = _page_args(20)
    if page_err:
        return page_err
    p = BroadcastHistory.query.order_by(BroadcastHistory.sent_at.desc()).paginate(
        page=page, per_page=per_page, error_out=False
    )
    items = []
    for row in p.items:
        d = row.to_dict()
        if row.admin_id:
            u = db.session.get(User, row.admin_id)
            d["admin_name"] = (u.full_name or u.display_name) if u else None
        items.append(d)
    return jsonify({
        "items": items,
        "total": p.total,
        "page": p.page,
        "pages": p.pages,
        "per_page": p.per_page,
    }), 200


@admin_bp.route("/ratings/leaderboard", methods=["GET"])
@admin_required
def ratings_leaderboard():
    """Top-rated users by peer feedback star rating (Feedback.avg_rating)."""
    page, per_page, page_err = _page_args(20)
    if page_err:
        return page_err
    from sqlalchemy import func as sqlfunc

    q = (
        db.session.query(
            Feedback.user_id,
            sqlfunc.avg(Feedback.avg_rating).label("avg_score"),
            sqlfunc.count(Feedback.id).label("rating_count"),
        )
        .filter(Feedback.avg_rating.isnot(None))
        .group_by(Feedback.user_id)
        .order_by(sqlfunc.avg(Feedback.avg_rating).desc())
    )
    total = q.count()
    rows = q.offset((page - 1) * per_page).limit(per_page).all()
    items = []
    for user_id, avg_score, rating_count in rows:
        u = db.session.get(User, user_id)
        items.append({
            "user_id": user_id,
            "user_name": (u.full_name or u.display_name or u.email) if u else f"User {user_id}",
            "email": u.email if u else "",
            "avg_score": round(float(avg_score or 0), 2),
            "rating_count": rating_count,
            "skills": u.skills if u and u.skills else [],
        })
    pages = max(1, (total + per_page - 1) // per_page)
    return jsonify({
        "items": items,
        "total": total,
        "page": page,
        "pages": pages,
        "per_page": per_page,
    }), 200


@admin_bp.route("/feedback/leaderboard", methods=["GET"])
@admin_required
def feedback_leaderboard():
    """Top users by average quality + teamwork feedback scores."""
    page, per_page, page_err = _page_args(20)
    if page_err:
        return page_err
    from sqlalchemy import func as sqlfunc

    q = (
        db.session.query(
            Feedback.user_id,
            sqlfunc.avg(
                (Feedback.quality_score + Feedback.teamwork_score) / 2.0
            ).label("avg_rating"),
            sqlfunc.count(Feedback.id).label("feedback_count"),
        )
        .filter(
            Feedback.quality_score.isnot(None),
            Feedback.teamwork_score.isnot(None),
        )
        .group_by(Feedback.user_id)
        .order_by(
            sqlfunc.avg((Feedback.quality_score + Feedback.teamwork_score) / 2.0).desc()
        )
    )
    total = q.count()
    rows = q.offset((page - 1) * per_page).limit(per_page).all()
    items = []
    for user_id, avg_rating, feedback_count in rows:
        u = db.session.get(User, user_id)
        items.append({
            "user_id": user_id,
            "user_name": (u.full_name or u.display_name or u.email) if u else f"User {user_id}",
            "avg_rating": round(float(avg_rating or 0), 2),
            "feedback_count": feedback_count,
        })
    pages = max(1, (total + per_page - 1) // per_page)
    return jsonify({
        "items": items,
        "total": total,
        "page": page,
        "pages": pages,
        "per_page": per_page,
    }), 200


def patch_analytics_retention():
    """Monkey-patch helper: compute_user_retention replaces hardcoded value."""
    return compute_user_retention()
