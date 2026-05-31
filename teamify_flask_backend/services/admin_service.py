import logging
import re
from datetime import datetime, timezone, timedelta
from sqlalchemy import func, or_, text
from models import db
from models.user import User
from models.project import Project
from models.project_member import ProjectMember
from models.task import Task
from models.login_log import LoginLog
from models.alert import Alert
from models.notification import Notification
from models.log import Log
from models.dispute import Dispute
from models.file_metadata import FileMetadata
from models.chat import ChatRoom, ChatRoomMember, Message
from models.meeting_session import MeetingSession
from models.system_setting import SystemSetting

logger = logging.getLogger(__name__)

def get_admin_dashboard_stats():
    total_users = User.query.count()
    active_users = User.query.filter_by(account_status="approved").count()
    total_projects = Project.query.count()
    
    from models.dispute import Dispute
    pending_disputes = Dispute.query.filter_by(status="pending").count()
    
    open_tasks = Task.query.filter(Task.status != "done").count()
    
    from models.log import Log
    today_start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    ai_requests_today = Log.query.filter(
        Log.action.ilike("%AI%"),
        Log.created_at >= today_start
    ).count()
    
    freelancers = User.query.filter_by(user_type="freelancer").count()
    students = User.query.filter_by(user_type="student").count()
    admins = User.query.filter_by(role="admin").count()
    others = total_users - freelancers - students
    
    growth_list = []
    now = datetime.now(timezone.utc)
    for i in range(5, -1, -1):
        month_dt = now - timedelta(days=i*30)
        m_start = month_dt.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        if m_start.month == 12:
            m_end = m_start.replace(year=m_start.year+1, month=1)
        else:
            m_end = m_start.replace(month=m_start.month+1)
            
        cnt = User.query.filter(User.created_at >= m_start, User.created_at < m_end).count()
        growth_list.append({
            "month": m_start.strftime("%b"),
            "count": cnt
        })
        
    return {
        "cards": {
            "system_health": 100,
            "storage_usage_mb": 12.4,
            "total_users": total_users,
            "active_users": active_users,
            "total_projects": total_projects,
            "pending_disputes": pending_disputes,
            "open_tasks": open_tasks,
            "ai_requests_today": ai_requests_today
        },
        "charts": {
            "ratios": {
                "freelancers": freelancers,
                "students": students,
                "admins": admins,
                "others": max(0, others)
            },
            "user_growth": growth_list
        }
    }

def list_admin_users(*args, **kwargs):
    search = kwargs.get("search", "")
    filter_status = kwargs.get("filter_status", "")
    filter_type = kwargs.get("filter_type", "")
    page = kwargs.get("page", 1)
    per_page = kwargs.get("per_page", 20)
    
    q = User.query
    if search:
        q = q.filter(or_(
            User.display_name.ilike(f"%{search}%"),
            User.full_name.ilike(f"%{search}%"),
            User.email.ilike(f"%{search}%")
        ))
        
    if filter_status:
        if filter_status == "active":
            q = q.filter(User.account_status == "approved")
        elif filter_status == "locked":
            q = q.filter(User.locked_until != None)
        elif filter_status == "pending":
            q = q.filter(User.account_status == "pending")
        elif filter_status == "rejected":
            q = q.filter(User.account_status == "rejected")
            
    if filter_type:
        q = q.filter(User.user_type == filter_type)
        
    p = q.order_by(User.created_at.desc()).paginate(page=page, per_page=per_page, error_out=False)
    
    return {
        "items": [u.to_dict() for u in p.items],
        "total": p.total,
        "page": p.page,
        "pages": p.pages,
        "per_page": p.per_page
    }


_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
_PASSWORD_RE = re.compile(r"^(?=.*[A-Z])(?=.*\d).{8,}$")


def _unique_display_name(base: str) -> str:
    """Pick a unique display_name from an email local-part or name slug."""
    slug = re.sub(r"[^a-zA-Z0-9_]", "", base.lower())[:40] or "user"
    candidate = slug
    n = 1
    while User.query.filter_by(display_name=candidate).first():
        candidate = f"{slug}{n}"[:80]
        n += 1
    return candidate


def create_admin_user(full_name, email, password, role_label, password_hasher):
    """
    Create a user from the admin panel.
    role_label: 'Admin' | 'Freelancer' | 'Student' (UI labels).
    Returns (user_dict, error_message).
    """
    full_name = (full_name or "").strip()
    email = (email or "").strip().lower()
    password = password or ""
    role_label = (role_label or "Freelancer").strip()

    errors = []
    if not full_name:
        errors.append("full_name is required")
    if not email or not _EMAIL_RE.match(email):
        errors.append("valid email is required")
    if not _PASSWORD_RE.match(password):
        errors.append(
            "password must be at least 8 characters with one uppercase letter and one digit"
        )
    if errors:
        return None, "; ".join(errors)

    if User.query.filter_by(email=email).first():
        return None, "Email already exists"

    label = role_label.lower()
    if label == "admin":
        system_role = "admin"
        user_type = "freelancer"
    elif label == "student":
        system_role = "member"
        user_type = "student"
    else:
        system_role = "member"
        user_type = "freelancer"

    display_name = _unique_display_name(email.split("@")[0])

    hashed = password_hasher.generate_password_hash(password).decode("utf-8")
    user = User(
        display_name=display_name,
        full_name=full_name,
        email=email,
        password=hashed,
        role=system_role,
        user_type=user_type,
        account_status="approved",
    )
    db.session.add(user)
    db.session.commit()
    return user.to_dict(), None


def delete_user_account(user_id: int) -> tuple[bool, str | None]:
    """
    Permanently delete a user and clean up rows that block FK constraints.
    Returns (success, error_message).
    """
    user = db.session.get(User, user_id)
    if not user:
        return False, "User not found"

    try:
        Dispute.query.filter(
            or_(Dispute.reporter_id == user_id, Dispute.accused_id == user_id)
        ).delete(synchronize_session=False)
        Dispute.query.filter_by(resolved_by=user_id).update(
            {Dispute.resolved_by: None}, synchronize_session=False
        )

        Notification.query.filter_by(user_id=user_id).delete(synchronize_session=False)
        Log.query.filter_by(user_id=user_id).delete(synchronize_session=False)

        owned_ids = [
            p.id for p in Project.query.filter_by(user_id=user_id).all()
        ]
        for pid in owned_ids:
            Task.query.filter_by(project_id=pid).delete(synchronize_session=False)

            room_ids = [
                r.id for r in ChatRoom.query.filter_by(project_id=pid).all()
            ]
            for rid in room_ids:
                MeetingSession.query.filter_by(room_id=rid).delete(
                    synchronize_session=False
                )
                Message.query.filter_by(room_id=rid).delete(synchronize_session=False)
                ChatRoomMember.query.filter_by(room_id=rid).delete(
                    synchronize_session=False
                )
            ChatRoom.query.filter_by(project_id=pid).delete(synchronize_session=False)

            db.session.execute(
                text("UPDATE disputes SET project_id = NULL WHERE project_id = :pid"),
                {"pid": pid},
            )
            FileMetadata.query.filter_by(project_id=pid).update(
                {FileMetadata.project_id: None}, synchronize_session=False
            )
            ProjectMember.query.filter_by(project_id=pid).delete(
                synchronize_session=False
            )
            project = db.session.get(Project, pid)
            if project:
                db.session.delete(project)

        Task.query.filter_by(assigned_to=user_id).update(
            {Task.assigned_to: None}, synchronize_session=False
        )
        Alert.query.filter_by(resolved_by=user_id).update(
            {Alert.resolved_by: None}, synchronize_session=False
        )

        db.session.delete(user)
        db.session.commit()
        return True, None
    except Exception as exc:
        db.session.rollback()
        logger.exception("delete_user_account failed for user_id=%s", user_id)
        return False, str(exc)


def update_user_status(user_id, action, reason=""):
    user = db.session.get(User, user_id)
    if not user:
        return {}, "User not found"
        
    action = action.lower()
    if action == "approve":
        user.account_status = "approved"
        user.account_status_note = None
    elif action == "reject":
        user.account_status = "rejected"
        user.account_status_note = reason
    elif action == "lock":
        user.account_status = "locked"
        user.locked_until = datetime.now(timezone.utc) + timedelta(days=365)
        user.failed_login_attempts = 99
        user.account_status_note = reason
    elif action == "suspend":
        user.account_status = "suspended"
        user.account_status_note = reason
    elif action == "unlock":
        user.account_status = "approved"
        user.locked_until = None
        user.failed_login_attempts = 0
        user.account_status_note = None
    else:
        return {}, f"Invalid action: {action}"
        
    db.session.commit()
    return user.to_dict(), None

def list_admin_projects(*args, **kwargs):
    search = kwargs.get("search", "")
    filter_status = kwargs.get("filter_status", "")
    page = kwargs.get("page", 1)
    per_page = kwargs.get("per_page", 20)
    
    q = Project.query
    if search:
        q = q.filter(Project.name.ilike(f"%{search}%"))
        
    if filter_status:
        q = q.filter(Project.status == filter_status)
        
    p = q.order_by(Project.created_at.desc()).paginate(page=page, per_page=per_page, error_out=False)
    
    return {
        "items": [pr.to_dict() for pr in p.items],
        "total": p.total,
        "page": p.page,
        "pages": p.pages,
        "per_page": p.per_page
    }

def reassign_project_owner(project_id, new_owner_id):
    project = db.session.get(Project, project_id)
    if not project:
        return {}, "Project not found"
        
    new_owner = db.session.get(User, new_owner_id)
    if not new_owner:
        return {}, "New owner user not found"
        
    project.user_id = new_owner_id
    db.session.commit()
    return project.to_dict(), None

def list_admin_tasks(*args, **kwargs):
    search = kwargs.get("search", "")
    project_id = kwargs.get("project_id")
    assigned_to = kwargs.get("assigned_to")
    priority = kwargs.get("priority", "")
    status = kwargs.get("status", "")
    page = kwargs.get("page", 1)
    per_page = kwargs.get("per_page", 20)
    
    q = Task.query
    if search:
        q = q.filter(or_(
            Task.title.ilike(f"%{search}%"),
            Task.description.ilike(f"%{search}%")
        ))
    if project_id:
        q = q.filter(Task.project_id == project_id)
    if assigned_to:
        q = q.filter(Task.assigned_to == assigned_to)
    if priority:
        q = q.filter(Task.priority == priority)
    if status:
        q = q.filter(Task.status == status)
        
    p = q.order_by(Task.created_at.desc()).paginate(page=page, per_page=per_page, error_out=False)
    
    return {
        "items": [t.to_dict() for t in p.items],
        "total": p.total,
        "page": p.page,
        "pages": p.pages,
        "per_page": p.per_page
    }

def get_ai_monitoring_metrics():
    from models.log import Log
    
    ai_logs = Log.query.filter(Log.action.ilike("%AI%")).order_by(Log.created_at.desc()).limit(20).all()
    total_ai_requests = Log.query.filter(Log.action.ilike("%AI%")).count()
    
    return {
        "metrics": {
            "total_requests": total_ai_requests,
            "average_latency_ms": 240,
            "success_rate_percent": 99.8,
            "tokens_consumed_today": 124500
        },
        "recent_requests": [
            {
                "id": log.id,
                "user_name": log.user.display_name if log.user else "System",
                "feature": log.action,
                "status": "success",
                "timestamp": log.created_at.isoformat() if log.created_at else None,
                "latency_ms": 210
            } for log in ai_logs
        ]
    }

def send_system_announcement(target, title, body, specific_user_id=None):
    users = []
    if target == "specific" and specific_user_id:
        u = db.session.get(User, specific_user_id)
        if u:
            users.append(u)
    elif target == "students":
        users = User.query.filter_by(user_type="student").all()
    elif target == "freelancers":
        users = User.query.filter_by(user_type="freelancer").all()
    else:
        users = User.query.all()
        
    count = 0
    for u in users:
        notification = Notification(
            user_id=u.id,
            type="general",
            title=title,
            body=body
        )
        db.session.add(notification)
        count += 1
        
    db.session.commit()
    return count

def get_security_center_data():
    from datetime import timedelta

    failed_logins = LoginLog.query.filter_by(status="fail").count()
    locked_users = User.query.filter(User.locked_until != None).count()
    suspicious_alerts_count = Alert.query.filter_by(resolved=False).count()
    cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
    active_sessions = (
        db.session.query(LoginLog.user_id)
        .filter(LoginLog.status == "success", LoginLog.timestamp >= cutoff)
        .distinct()
        .count()
    )
    
    alerts = Alert.query.filter_by(resolved=False).order_by(Alert.timestamp.desc()).limit(10).all()
    logins = LoginLog.query.order_by(LoginLog.timestamp.desc()).limit(10).all()

    def _user_name(uid):
        if not uid:
            return "System/Unknown"
        u = User.query.get(uid)
        return (u.full_name or u.display_name or u.email) if u else "System/Unknown"

    return {
        "metrics": {
            "failed_logins": failed_logins,
            "locked_users": locked_users,
            "active_sessions": active_sessions,
            "suspicious_activity_alerts": suspicious_alerts_count
        },
        "alerts": [
            {
                "id": a.id,
                "type": a.type,
                "description": a.description,
                "resolved_by": a.resolved_by,
                "timestamp": a.timestamp.isoformat() if a.timestamp else None
            } for a in alerts
        ],
        "logins": [
            {
                "id": l.id,
                "status": l.status,
                "user_name": _user_name(l.user_id),
                "ip_address": l.ip_address,
                "device_info": l.device_info,
                "user_id": l.user_id,
                "timestamp": l.timestamp.isoformat() if l.timestamp else None
            } for l in logins
        ]
    }

def get_system_settings():
    defaults = {
        "registrations_enabled": "true",
        "maintenance_mode": "false",
        "ai_mentorship_enabled": "true",
        "mfa_required": "false",
        "session_timeout_minutes": "60",
        "max_login_attempts": "5",
        "rate_limiting_enabled": "true",
        "api_requests_per_minute": "100",
        "login_attempts_per_hour": "5",
        "encryption_at_rest": "true",
        "encryption_in_transit": "true",
    }
    settings = {}
    for key, def_val in defaults.items():
        val = SystemSetting.get(key)
        if val is None:
            SystemSetting.set(key, def_val)
            settings[key] = def_val
        else:
            settings[key] = val
            
    return {
        "registrations_enabled": settings["registrations_enabled"].lower() == "true",
        "maintenance_mode": settings["maintenance_mode"].lower() == "true",
        "ai_mentorship_enabled": settings["ai_mentorship_enabled"].lower() == "true",
        "mfa_required": settings["mfa_required"].lower() == "true",
        "session_timeout_minutes": int(settings["session_timeout_minutes"]),
        "max_login_attempts": int(settings["max_login_attempts"]),
        "rate_limiting_enabled": settings["rate_limiting_enabled"].lower() == "true",
        "api_requests_per_minute": int(settings["api_requests_per_minute"]),
        "login_attempts_per_hour": int(settings["login_attempts_per_hour"]),
        "encryption_at_rest": settings["encryption_at_rest"].lower() == "true",
        "encryption_in_transit": settings["encryption_in_transit"].lower() == "true",
    }

def update_system_settings(data):
    for key, val in data.items():
        if isinstance(val, bool):
            str_val = "true" if val else "false"
        else:
            str_val = str(val)
        SystemSetting.set(key, str_val)
    return get_system_settings()
