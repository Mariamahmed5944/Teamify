"""
Full System-Admin blueprint.
Covers all 6 admin domains:
  1. Approve / Reject Users
  2. Manage Platform (users, projects, reports)
  3. Monitor Activity (audit logs, login logs, alerts)
  4. Handle Disputes  (delegated to routes/disputes.py)
  5. Analytics Dashboard
  6. Security & Data Control (data export, config)
"""
from datetime import datetime, timezone
import csv
import io

from flask import Blueprint, jsonify, request, make_response
from flask_jwt_extended import get_jwt_identity

from middleware.auth import admin_required
from models import db
from models.user import User
from models.project import Project
from models.task import Task
from models.login_log import LoginLog
from models.alert import Alert
from models.audit_log import AuditLog
from models.log import Log

admin_bp = Blueprint("admin", __name__, url_prefix="/admin")


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _page_args(default=50, max_pp=200):
    try:
        page = max(1, int(request.args.get("page", 1)))
    except (TypeError, ValueError):
        page = 1
    try:
        per_page = int(request.args.get("per_page", default))
    except (TypeError, ValueError):
        per_page = default
    return page, max(1, min(per_page, max_pp))


# ══════════════════════════════════════════════════════════════════════════════
# 1.  APPROVE / REJECT USERS
# ══════════════════════════════════════════════════════════════════════════════

@admin_bp.route("/users/pending", methods=["GET"])
@admin_required
def list_pending_users():
    """List users awaiting approval (freelancers & students).
    ---
    tags: [Admin]
    security: [{Bearer: []}]
    parameters:
      - {in: query, name: user_type, type: string}
      - {in: query, name: page, type: integer}
      - {in: query, name: per_page, type: integer}
    responses:
      200:
        description: Pending users list
    """
    page, per_page = _page_args(20)
    q = User.query.filter_by(account_status="pending")
    user_type = request.args.get("user_type")
    if user_type:
        q = q.filter(User.user_type == user_type)
    p = q.order_by(User.created_at.desc()).paginate(page=page, per_page=per_page, error_out=False)
    return jsonify({
        "items":    [u.to_dict() for u in p.items],
        "total":    p.total,
        "page":     p.page,
        "pages":    p.pages,
    }), 200


@admin_bp.route("/users/<int:user_id>/approve", methods=["PATCH"])
@admin_required
def approve_user(user_id):
    """Approve a pending user.
    ---
    tags: [Admin]
    security: [{Bearer: []}]
    responses:
      200:
        description: User approved
      404:
        description: Not found
    """
    user = db.session.get(User, user_id)
    if not user:
        return jsonify({"error": "User not found"}), 404
    user.account_status      = "approved"
    user.account_status_note = None
    db.session.add(Log(
        action="ADMIN_APPROVE_USER", entity="User", entity_id=user_id,
        details=f"Approved by admin {get_jwt_identity()}", user_id=int(get_jwt_identity()),
    ))
    db.session.commit()
    return jsonify({"message": "User approved", "user": user.to_dict()}), 200


@admin_bp.route("/users/<int:user_id>/reject", methods=["PATCH"])
@admin_required
def reject_user(user_id):
    """Reject a pending user with an optional reason.
    ---
    tags: [Admin]
    security: [{Bearer: []}]
    parameters:
      - in: body
        name: body
        schema:
          type: object
          properties:
            reason: {type: string}
    responses:
      200:
        description: User rejected
    """
    user = db.session.get(User, user_id)
    if not user:
        return jsonify({"error": "User not found"}), 404
    data = request.get_json(silent=True, force=True) or {}
    user.account_status      = "rejected"
    user.account_status_note = data.get("reason", "Rejected by admin.")
    db.session.add(Log(
        action="ADMIN_REJECT_USER", entity="User", entity_id=user_id,
        details=f"Rejected by admin {get_jwt_identity()}: {user.account_status_note}",
        user_id=int(get_jwt_identity()),
    ))
    db.session.commit()
    return jsonify({"message": "User rejected", "user": user.to_dict()}), 200


# ══════════════════════════════════════════════════════════════════════════════
# 2.  MANAGE PLATFORM  — Users
# ══════════════════════════════════════════════════════════════════════════════

@admin_bp.route("/users", methods=["GET"])
@admin_required
def list_all_users():
    """Paginated list of all users.
    ---
    tags: [Admin]
    security: [{Bearer: []}]
    parameters:
      - {in: query, name: role, type: string}
      - {in: query, name: user_type, type: string}
      - {in: query, name: account_status, type: string}
      - {in: query, name: page, type: integer}
      - {in: query, name: per_page, type: integer}
    responses:
      200:
        description: Users list
    """
    page, per_page = _page_args(20)
    q = User.query
    for field in ("role", "user_type", "account_status"):
        val = request.args.get(field)
        if val:
            q = q.filter(getattr(User, field) == val)
    p = q.order_by(User.created_at.desc()).paginate(page=page, per_page=per_page, error_out=False)
    return jsonify({
        "items":    [u.to_dict() for u in p.items],
        "total":    p.total,
        "page":     p.page,
        "pages":    p.pages,
    }), 200


@admin_bp.route("/users/<int:user_id>", methods=["GET"])
@admin_required
def get_user(user_id):
    """Get full profile of any user.
    ---
    tags: [Admin]
    security: [{Bearer: []}]
    responses:
      200:
        description: User profile
    """
    user = db.session.get(User, user_id)
    if not user:
        return jsonify({"error": "User not found"}), 404
    return jsonify({"user": user.to_dict()}), 200


@admin_bp.route("/users/<int:user_id>", methods=["PUT"])
@admin_required
def update_user(user_id):
    """Update any user's role, status, or basic fields.
    ---
    tags: [Admin]
    security: [{Bearer: []}]
    parameters:
      - in: body
        name: body
        schema:
          type: object
          properties:
            role: {type: string, enum: [member, admin, guest]}
            account_status: {type: string, enum: [pending, approved, rejected]}
            account_status_note: {type: string}
            full_name: {type: string}
    responses:
      200:
        description: User updated
    """
    user = db.session.get(User, user_id)
    if not user:
        return jsonify({"error": "User not found"}), 404
    data = request.get_json(silent=True, force=True) or {}
    allowed_roles    = {"member", "admin", "guest"}
    allowed_statuses = {"pending", "approved", "rejected"}
    if "role" in data:
        if data["role"] not in allowed_roles:
            return jsonify({"error": f"role must be one of {sorted(allowed_roles)}"}), 400
        user.role = data["role"]
    if "account_status" in data:
        if data["account_status"] not in allowed_statuses:
            return jsonify({"error": f"account_status must be one of {sorted(allowed_statuses)}"}), 400
        user.account_status = data["account_status"]
    if "account_status_note" in data:
        user.account_status_note = data["account_status_note"]
    if "full_name" in data:
        user.full_name = (data["full_name"] or "").strip() or None
    db.session.commit()
    return jsonify({"message": "User updated", "user": user.to_dict()}), 200


@admin_bp.route("/users/<int:user_id>", methods=["DELETE"])
@admin_required
def delete_user(user_id):
    """Permanently delete a user account.
    ---
    tags: [Admin]
    security: [{Bearer: []}]
    responses:
      200:
        description: User deleted
    """
    user = db.session.get(User, user_id)
    if not user:
        return jsonify({"error": "User not found"}), 404
    admin_id = int(get_jwt_identity())
    if user_id == admin_id:
        return jsonify({"error": "You cannot delete your own account"}), 400
    db.session.delete(user)
    db.session.commit()
    return jsonify({"message": f"User {user_id} deleted"}), 200


# ─── Manage Platform — Projects ───────────────────────────────────────────────

@admin_bp.route("/projects", methods=["GET"])
@admin_required
def list_all_projects():
    """Paginated list of all projects.
    ---
    tags: [Admin]
    security: [{Bearer: []}]
    parameters:
      - {in: query, name: status, type: string}
      - {in: query, name: page, type: integer}
      - {in: query, name: per_page, type: integer}
    responses:
      200:
        description: Projects list
    """
    page, per_page = _page_args(20)
    q = Project.query
    status = request.args.get("status")
    if status:
        q = q.filter(Project.status == status)
    p = q.order_by(Project.created_at.desc()).paginate(page=page, per_page=per_page, error_out=False)
    return jsonify({
        "items":    [pr.to_dict() for pr in p.items],
        "total":    p.total,
        "page":     p.page,
        "pages":    p.pages,
    }), 200


@admin_bp.route("/projects/<int:project_id>", methods=["DELETE"])
@admin_required
def delete_project(project_id):
    """Force-delete any project.
    ---
    tags: [Admin]
    security: [{Bearer: []}]
    responses:
      200:
        description: Project deleted
    """
    project = db.session.get(Project, project_id)
    if not project:
        return jsonify({"error": "Project not found"}), 404
    db.session.delete(project)
    db.session.commit()
    return jsonify({"message": f"Project {project_id} deleted"}), 200


# ─── Manage Platform — System Reports ─────────────────────────────────────────

@admin_bp.route("/reports/summary", methods=["GET"])
@admin_required
def platform_summary_report():
    """Full platform summary report.
    ---
    tags: [Admin]
    security: [{Bearer: []}]
    responses:
      200:
        description: Platform summary
    """
    from datetime import date
    total_users      = User.query.count()
    pending_users    = User.query.filter_by(account_status="pending").count()
    approved_users   = User.query.filter_by(account_status="approved").count()
    rejected_users   = User.query.filter_by(account_status="rejected").count()
    freelancers      = User.query.filter_by(user_type="freelancer").count()
    students         = User.query.filter_by(user_type="student").count()
    total_projects   = Project.query.count()
    active_projects  = Project.query.filter_by(status="active").count()
    total_tasks      = Task.query.count()
    done_tasks       = Task.query.filter_by(status="done").count()
    overdue_tasks    = Task.query.filter(
        Task.status != "done", Task.due_date < date.today()
    ).count()
    completion_rate  = round(done_tasks / total_tasks * 100, 1) if total_tasks else 0
    return jsonify({
        "users": {
            "total": total_users, "pending": pending_users,
            "approved": approved_users, "rejected": rejected_users,
            "freelancers": freelancers, "students": students,
        },
        "projects": {"total": total_projects, "active": active_projects},
        "tasks": {
            "total": total_tasks, "done": done_tasks,
            "overdue": overdue_tasks, "completion_rate": completion_rate,
        },
    }), 200


# ══════════════════════════════════════════════════════════════════════════════
# 3.  MONITOR ACTIVITY
# ══════════════════════════════════════════════════════════════════════════════

@admin_bp.route("/logs", methods=["GET"])
@admin_required
def list_login_logs():
    """Paginated login logs with filters.
    ---
    tags: [Admin]
    security: [{Bearer: []}]
    parameters:
      - {in: query, name: status, type: string, enum: [success, fail]}
      - {in: query, name: ip, type: string}
      - {in: query, name: user_id, type: integer}
      - {in: query, name: page, type: integer}
      - {in: query, name: per_page, type: integer}
    responses:
      200:
        description: Login logs
    """
    page, per_page = _page_args()
    q = LoginLog.query
    status = request.args.get("status")
    if status in ("success", "fail"):
        q = q.filter(LoginLog.status == status)
    ip = request.args.get("ip")
    if ip:
        q = q.filter(LoginLog.ip_address == ip)
    user_id = request.args.get("user_id")
    if user_id:
        try:
            q = q.filter(LoginLog.user_id == int(user_id))
        except ValueError:
            return jsonify({"error": "Invalid user_id"}), 400
    p = q.order_by(LoginLog.timestamp.desc()).paginate(page=page, per_page=per_page, error_out=False)
    return jsonify({
        "items":    [r.to_dict() for r in p.items],
        "page":     p.page, "per_page": p.per_page,
        "total":    p.total, "pages":    p.pages,
    }), 200


@admin_bp.route("/activity", methods=["GET"])
@admin_required
def list_activity_logs():
    """All system action logs (who did what and when).
    ---
    tags: [Admin]
    security: [{Bearer: []}]
    parameters:
      - {in: query, name: user_id, type: integer}
      - {in: query, name: action, type: string}
      - {in: query, name: entity, type: string}
      - {in: query, name: page, type: integer}
      - {in: query, name: per_page, type: integer}
    responses:
      200:
        description: Activity logs
    """
    page, per_page = _page_args()
    q = Log.query
    user_id = request.args.get("user_id")
    if user_id:
        try:
            q = q.filter(Log.user_id == int(user_id))
        except ValueError:
            return jsonify({"error": "Invalid user_id"}), 400
    action = request.args.get("action")
    if action:
        q = q.filter(Log.action == action.upper())
    entity = request.args.get("entity")
    if entity:
        q = q.filter(Log.entity == entity)
    p = q.order_by(Log.created_at.desc()).paginate(page=page, per_page=per_page, error_out=False)
    return jsonify({
        "items":    [l.to_dict() for l in p.items],
        "page":     p.page, "per_page": p.per_page,
        "total":    p.total, "pages":    p.pages,
    }), 200


@admin_bp.route("/audit-logs", methods=["GET"])
@admin_required
def list_audit_logs():
    """Security audit logs.
    ---
    tags: [Admin]
    security: [{Bearer: []}]
    parameters:
      - {in: query, name: severity, type: string}
      - {in: query, name: action, type: string}
      - {in: query, name: page, type: integer}
      - {in: query, name: per_page, type: integer}
    responses:
      200:
        description: Audit logs
    """
    page, per_page = _page_args()
    q = AuditLog.query
    severity = request.args.get("severity")
    if severity:
        q = q.filter(AuditLog.severity == severity.upper())
    action = request.args.get("action")
    if action:
        q = q.filter(AuditLog.action == action.upper())
    p = q.order_by(AuditLog.created_at.desc()).paginate(page=page, per_page=per_page, error_out=False)
    return jsonify({
        "items":    [a.to_dict() for a in p.items],
        "page":     p.page, "per_page": p.per_page,
        "total":    p.total, "pages":    p.pages,
    }), 200


@admin_bp.route("/alerts", methods=["GET"])
@admin_required
def list_alerts():
    """Security anomaly alerts.
    ---
    tags: [Admin]
    security: [{Bearer: []}]
    parameters:
      - {in: query, name: resolved, type: string, enum: ["true","false"]}
      - {in: query, name: type, type: string}
      - {in: query, name: page, type: integer}
      - {in: query, name: per_page, type: integer}
    responses:
      200:
        description: Alerts list
    """
    page, per_page = _page_args()
    q = Alert.query
    resolved = request.args.get("resolved")
    if resolved is not None:
        q = q.filter(Alert.resolved.is_(resolved.lower() in ("true", "1", "yes")))
    alert_type = request.args.get("type")
    if alert_type:
        q = q.filter(Alert.type == alert_type)
    p = q.order_by(Alert.timestamp.desc()).paginate(page=page, per_page=per_page, error_out=False)
    return jsonify({
        "items":    [a.to_dict() for a in p.items],
        "page":     p.page, "per_page": p.per_page,
        "total":    p.total, "pages":    p.pages,
    }), 200


@admin_bp.route("/alerts/<alert_id>/resolve", methods=["PATCH"])
@admin_required
def resolve_alert(alert_id: str):
    """Resolve a security alert.
    ---
    tags: [Admin]
    security: [{Bearer: []}]
    responses:
      200:
        description: Alert resolved
    """
    try:
        aid = int(alert_id)
    except (ValueError, AttributeError):
        return jsonify({"error": "Invalid alert_id"}), 400
    alert = Alert.query.filter_by(id=aid).first()
    if not alert:
        return jsonify({"error": "Not Found"}), 404
    alert.resolved    = True
    alert.resolved_at = datetime.now(timezone.utc)
    try:
        alert.resolved_by = int(get_jwt_identity())
    except (ValueError, TypeError):
        alert.resolved_by = None
    db.session.commit()
    return jsonify({"message": "Alert resolved", "alert": alert.to_dict()}), 200


# ══════════════════════════════════════════════════════════════════════════════
# 5.  ANALYTICS DASHBOARD
# ══════════════════════════════════════════════════════════════════════════════

@admin_bp.route("/analytics/overview", methods=["GET"])
@admin_required
def analytics_overview():
    """Global analytics overview for the admin dashboard.
    ---
    tags: [Admin]
    security: [{Bearer: []}]
    responses:
      200:
        description: Analytics data
    """
    from datetime import date
    from sqlalchemy import func
    from models.project_member import ProjectMember

    total_users     = User.query.count()
    active_users    = User.query.filter_by(account_status="approved").count()
    total_projects  = Project.query.count()
    active_projects = Project.query.filter_by(status="active").count()
    total_tasks     = Task.query.count()
    done_tasks      = Task.query.filter_by(status="done").count()
    overdue_tasks   = Task.query.filter(
        Task.status != "done", Task.due_date < date.today()
    ).count()
    completion_rate = round(done_tasks / total_tasks * 100, 1) if total_tasks else 0

    # User type breakdown
    user_type_breakdown = {}
    for row in db.session.query(User.user_type, func.count(User.id)).group_by(User.user_type).all():
        user_type_breakdown[row[0] or "unknown"] = row[1]

    # Project status breakdown
    project_status_breakdown = {}
    for row in db.session.query(Project.status, func.count(Project.id)).group_by(Project.status).all():
        project_status_breakdown[row[0]] = row[1]

    # Task status breakdown
    task_status_breakdown = {}
    for row in db.session.query(Task.status, func.count(Task.id)).group_by(Task.status).all():
        task_status_breakdown[row[0]] = row[1]

    return jsonify({
        "users": {
            "total":          total_users,
            "active":         active_users,
            "by_type":        user_type_breakdown,
        },
        "projects": {
            "total":          total_projects,
            "active":         active_projects,
            "by_status":      project_status_breakdown,
        },
        "tasks": {
            "total":          total_tasks,
            "done":           done_tasks,
            "overdue":        overdue_tasks,
            "completion_rate": completion_rate,
            "by_status":      task_status_breakdown,
        },
    }), 200


@admin_bp.route("/analytics/users/growth", methods=["GET"])
@admin_required
def user_growth():
    """Monthly user registration counts.
    ---
    tags: [Admin]
    security: [{Bearer: []}]
    responses:
      200:
        description: User growth data
    """
    from sqlalchemy import func, extract
    rows = (
        db.session.query(
            extract("year",  User.created_at).label("year"),
            extract("month", User.created_at).label("month"),
            func.count(User.id).label("count"),
        )
        .group_by("year", "month")
        .order_by("year", "month")
        .all()
    )
    return jsonify({
        "growth": [
            {"year": int(r.year), "month": int(r.month), "new_users": r.count}
            for r in rows
        ]
    }), 200


# ══════════════════════════════════════════════════════════════════════════════
# 6.  SECURITY & DATA CONTROL
# ══════════════════════════════════════════════════════════════════════════════

@admin_bp.route("/export/users", methods=["GET"])
@admin_required
def export_users_csv():
    """Export all users as CSV.
    ---
    tags: [Admin]
    security: [{Bearer: []}]
    produces: [text/csv]
    responses:
      200:
        description: CSV file download
    """
    users = User.query.order_by(User.id).all()
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["id", "display_name", "full_name", "email",
                     "role", "user_type", "account_status", "created_at"])
    for u in users:
        writer.writerow([
            u.id, u.display_name, u.full_name, u.email,
            u.role, u.user_type, u.account_status,
            u.created_at.isoformat() if u.created_at else "",
        ])
    response = make_response(output.getvalue())
    response.headers["Content-Type"]        = "text/csv"
    response.headers["Content-Disposition"] = "attachment; filename=users_export.csv"
    return response


@admin_bp.route("/export/projects", methods=["GET"])
@admin_required
def export_projects_csv():
    """Export all projects as CSV.
    ---
    tags: [Admin]
    security: [{Bearer: []}]
    produces: [text/csv]
    responses:
      200:
        description: CSV file download
    """
    projects = Project.query.order_by(Project.id).all()
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["id", "name", "status", "category", "user_id", "start_date", "end_date", "created_at"])
    for p in projects:
        writer.writerow([
            p.id, p.name, p.status, p.category, p.user_id,
            p.start_date.isoformat() if p.start_date else "",
            p.end_date.isoformat()   if p.end_date   else "",
            p.created_at.isoformat() if p.created_at else "",
        ])
    response = make_response(output.getvalue())
    response.headers["Content-Type"]        = "text/csv"
    response.headers["Content-Disposition"] = "attachment; filename=projects_export.csv"
    return response


@admin_bp.route("/users/<int:user_id>/lock", methods=["PATCH"])
@admin_required
def lock_user(user_id):
    """Immediately lock a user account (force lockout).
    ---
    tags: [Admin]
    security: [{Bearer: []}]
    responses:
      200:
        description: User locked
    """
    from datetime import timedelta
    user = db.session.get(User, user_id)
    if not user:
        return jsonify({"error": "User not found"}), 404
    user.locked_until          = datetime.now(timezone.utc) + timedelta(days=365)
    user.failed_login_attempts = 99
    db.session.commit()
    return jsonify({"message": f"User {user_id} has been locked"}), 200


@admin_bp.route("/users/<int:user_id>/unlock", methods=["PATCH"])
@admin_required
def unlock_user(user_id):
    """Unlock a locked user account.
    ---
    tags: [Admin]
    security: [{Bearer: []}]
    responses:
      200:
        description: User unlocked
    """
    user = db.session.get(User, user_id)
    if not user:
        return jsonify({"error": "User not found"}), 404
    user.locked_until          = None
    user.failed_login_attempts = 0
    db.session.commit()
    return jsonify({"message": f"User {user_id} has been unlocked"}), 200
