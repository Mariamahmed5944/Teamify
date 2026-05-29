from flask import Blueprint, jsonify
from flask_jwt_extended import get_jwt_identity
from middleware.auth import auth_required
from models import db
from models.task import Task
from models.project import Project
from models.project_member import ProjectMember
from models.log import Log
from models.notification import Notification
from services.ai_service import predict_delay
from services.project_access import get_accessible_project_ids
from sqlalchemy import func
from datetime import date, datetime, timezone

dashboard_bp = Blueprint("dashboard", __name__, url_prefix="/api/dashboard")


@dashboard_bp.route("", methods=["GET"])
@auth_required
def get_dashboard():
    """
    Consolidated dashboard data for the Home screen.
    Returns task stats, at-risk tasks, active projects, recent activity, and unread notifications count.
    ---
    tags:
      - Dashboard
    security:
      - Bearer: []
    responses:
      200:
        description: Dashboard data
        schema:
          type: object
          properties:
            user:
              type: object
              properties:
                display_name:
                  type: string
                role:
                  type: string
                user_type:
                  type: string
            stats:
              type: object
              properties:
                total_tasks:
                  type: integer
                completed_tasks:
                  type: integer
                in_progress_tasks:
                  type: integer
                overdue_tasks:
                  type: integer
                tasks_due_today:
                  type: integer
            active_projects:
              type: array
              items:
                type: object
            at_risk_tasks:
              type: array
              items:
                type: object
            recent_activity:
              type: array
              items:
                type: object
            unread_notifications:
              type: integer
      401:
        description: Missing or invalid token
        schema:
          type: object
          properties:
            error:
              type: string
    """
    user_id = int(get_jwt_identity())

    from models.user import User
    user = db.session.get(User, user_id)

    # ── Determine accessible project IDs (owner OR member only) ───────────
    project_ids = get_accessible_project_ids(user_id)

    # ── Task statistics ───────────────────────────────────────────────────
    today = date.today()

    if project_ids:
        base_q = Task.query.filter(Task.project_id.in_(project_ids))
        my_tasks_q = base_q.filter(Task.assigned_to == user_id)
    else:
        base_q = Task.query.filter(Task.project_id.in_([]))
        my_tasks_q = base_q

    total_tasks = my_tasks_q.count()
    tasks_due_today = my_tasks_q.filter(
        Task.due_date == today, Task.status != "done"
    ).count()
    overdue_tasks = my_tasks_q.filter(
        Task.due_date < today, Task.status != "done"
    ).count()
    completed_tasks = my_tasks_q.filter(Task.status == "done").count()
    in_progress_tasks = my_tasks_q.filter(Task.status == "in_progress").count()
    pending_tasks = my_tasks_q.filter(Task.status == "pending").count()

    active_projects_count = (
        Project.query.filter(
            Project.id.in_(project_ids),
            Project.status.in_(["active", "planned"]),
        ).count()
        if project_ids
        else 0
    )

    # ── At-risk tasks (top 5 by delay probability) ────────────────────────
    at_risk_tasks_raw = (
        my_tasks_q
        .filter(Task.status != "done", Task.due_date.isnot(None))
        .order_by(Task.due_date.asc())
        .limit(10)
        .all()
    )

    at_risk_tasks = []
    for t in at_risk_tasks_raw:
        delay_info = predict_delay(task_id=t.id)
        prob = float(delay_info.get("delay_probability", 0) or 0)
        if prob > 20:
            at_risk_tasks.append({
                "id": str(t.id),
                "title": t.title,
                "status": t.status,
                "priority": t.priority,
                "due_date": t.due_date.isoformat() if t.due_date else None,
                "project_id": str(t.project_id),
                "delay_probability": prob,
                "risk_level": delay_info.get("risk_level", "unknown"),
            })
    at_risk_tasks.sort(key=lambda x: x["delay_probability"], reverse=True)
    at_risk_tasks = at_risk_tasks[:5]

    # ── Active projects with progress ─────────────────────────────────────
    active_projects = []
    projects = Project.query.filter(
        Project.id.in_(project_ids),
        Project.status.in_(["active", "planned"]),
    ).order_by(Project.updated_at.desc()).limit(5).all()

    for p in projects:
        task_total = Task.query.filter_by(project_id=p.id).count()
        task_done = Task.query.filter_by(project_id=p.id, status="done").count()
        task_overdue = Task.query.filter(
            Task.project_id == p.id, Task.due_date < today, Task.status != "done"
        ).count()
        member_count = ProjectMember.query.filter_by(project_id=p.id).count()

        # Calculate auto-progress
        progress = int((task_done / task_total * 100)) if task_total > 0 else 0

        risk = "low"
        if task_overdue > 2:
            risk = "high"
        elif task_overdue > 0:
            risk = "medium"

        active_projects.append({
            "id": str(p.id),
            "name": p.name,
            "status": p.status,
            "progress": progress,
            "total_tasks": task_total,
            "completed_tasks": task_done,
            "overdue_tasks": task_overdue,
            "member_count": member_count,
            "risk_level": risk,
            "end_date": p.end_date.isoformat() if p.end_date else None,
        })

    # ── Recent activity (last 10 logs) ────────────────────────────────────
    recent_logs = (
        Log.query
        .filter_by(user_id=user_id)
        .order_by(Log.created_at.desc())
        .limit(10)
        .all()
    )

    # ── Unread notifications count ────────────────────────────────────────
    unread_count = Notification.query.filter_by(user_id=user_id, is_read=False).count()

    return jsonify({
        "user": {
            "display_name": user.display_name if user else None,
            "role": user.role if user else None,
            "user_type": user.user_type if user else None,
        },
        "stats": {
            "total_tasks": total_tasks,
            "tasks_due_today": tasks_due_today,
            "overdue_tasks": overdue_tasks,
            "completed_tasks": completed_tasks,
            "in_progress_tasks": in_progress_tasks,
            "pending_tasks": pending_tasks,
            "active_projects_count": active_projects_count,
            "accessible_projects_count": active_projects_count,
            "my_assigned_tasks": total_tasks,
        },
        "at_risk_tasks": at_risk_tasks,
        "active_projects": active_projects,
        "recent_activity": [l.to_dict() for l in recent_logs],
        "unread_notifications": unread_count,
    }), 200
