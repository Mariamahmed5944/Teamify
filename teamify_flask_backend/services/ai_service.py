"""
AI helper functions for task assignment, priority suggestion,
deadline suggestion and delay prediction.

These use heuristic / rule-based logic that can later be swapped
for real ML models without changing the API contract.
"""

from datetime import date, timedelta
from models import db
from models.task import Task
from models.user import User
from models.project import Project
from models.project_member import ProjectMember


# ──────────────────────────────────────────────────────────────────────────────
# 1. Auto-assign: pick the best member for a task inside a project
# ──────────────────────────────────────────────────────────────────────────────

def get_user_workload(user_id):
    """Return the number of non-done tasks currently assigned to a user."""
    return (
        Task.query
        .filter(Task.assigned_to == user_id, Task.status != "done")
        .count()
    )


def auto_assign(project_id, priority="medium"):
    """
    Pick the project member with the lightest current workload.
    Returns (user_id, reason) or (None, reason).
    """
    project = Project.query.get(project_id)
    if not project:
        return None, "Project not found"

    member_ids = set()
    member_ids.add(project.user_id)  # owner

    members = ProjectMember.query.filter_by(project_id=project_id).all()
    for m in members:
        member_ids.add(m.user_id)

    if not member_ids:
        return None, "No members in this project"

    # Calculate workload for each member
    candidates = []
    for uid in member_ids:
        user = User.query.get(uid)
        if not user:
            continue
        workload = get_user_workload(uid)
        candidates.append({"user_id": uid, "display_name": user.display_name, "workload": workload})

    if not candidates:
        return None, "No valid users found"

    # Sort by workload ascending (least busy first)
    candidates.sort(key=lambda c: c["workload"])
    best = candidates[0]

    return best["user_id"], f"Assigned to '{best['display_name']}' (current workload: {best['workload']} tasks)"


# ──────────────────────────────────────────────────────────────────────────────
# 2. Suggest priority based on project context
# ──────────────────────────────────────────────────────────────────────────────

def suggest_priority(project_id, title="", description="", due_date_str=None):
    """
    Suggest a priority (low / medium / high) based on:
      - How close the due date is
      - How many tasks are already pending/in_progress in the project
      - Keywords in title/description
    Returns (priority, reasons).
    """
    reasons = []
    score = 0  # negative = lower, positive = higher

    # -- Due date proximity --
    if due_date_str:
        try:
            due = date.fromisoformat(due_date_str)
            days_left = (due - date.today()).days
            if days_left <= 2:
                score += 3
                reasons.append(f"Due in {days_left} day(s) — very urgent")
            elif days_left <= 7:
                score += 2
                reasons.append(f"Due in {days_left} day(s) — upcoming soon")
            elif days_left <= 14:
                score += 1
                reasons.append(f"Due in {days_left} day(s)")
            else:
                reasons.append(f"Due in {days_left} day(s) — plenty of time")
        except ValueError:
            pass

    # -- Project load --
    pending_count = Task.query.filter(
        Task.project_id == project_id,
        Task.status.in_(["pending", "in_progress"]),
    ).count()

    if pending_count >= 10:
        score += 1
        reasons.append(f"Project already has {pending_count} active tasks — high load")
    elif pending_count >= 5:
        reasons.append(f"Project has {pending_count} active tasks — moderate load")

    # -- Keyword analysis --
    text = f"{title} {description}".lower()
    high_keywords = ["urgent", "critical", "blocker", "asap", "hotfix", "bug", "crash", "security"]
    low_keywords = ["nice to have", "optional", "cleanup", "refactor", "docs", "documentation"]

    for kw in high_keywords:
        if kw in text:
            score += 2
            reasons.append(f"Keyword '{kw}' detected — indicates high priority")
            break

    for kw in low_keywords:
        if kw in text:
            score -= 1
            reasons.append(f"Keyword '{kw}' detected — indicates lower priority")
            break

    # -- Map score to priority --
    if score >= 3:
        priority = "high"
    elif score >= 1:
        priority = "medium"
    else:
        priority = "low"

    if not reasons:
        reasons.append("No strong signals — defaulting to medium")

    return priority, reasons


# ──────────────────────────────────────────────────────────────────────────────
# 3. Suggest deadline
# ──────────────────────────────────────────────────────────────────────────────

def suggest_deadline(project_id, priority="medium", title="", description=""):
    """
    Suggest a deadline based on:
      - Priority level
      - Project end date
      - Average task completion time in the project
    Returns (suggested_date_iso, reasons).
    """
    reasons = []

    # Base days by priority
    base_days = {"high": 3, "medium": 7, "low": 14}
    days = base_days.get(priority, 7)
    reasons.append(f"Base estimate: {days} days for '{priority}' priority")

    # Adjust based on project end_date
    project = Project.query.get(project_id)
    if project and project.end_date:
        days_to_end = (project.end_date - date.today()).days
        if days_to_end > 0 and days > days_to_end:
            days = max(1, days_to_end - 1)
            reasons.append(f"Adjusted to fit project deadline ({project.end_date.isoformat()})")

    # Look at average completion time for done tasks in this project
    done_tasks = Task.query.filter(
        Task.project_id == project_id,
        Task.status == "done",
        Task.due_date.isnot(None),
    ).all()

    if done_tasks:
        durations = []
        for t in done_tasks:
            created = t.created_at.date() if t.created_at else None
            if created and t.due_date:
                diff = (t.due_date - created).days
                if diff > 0:
                    durations.append(diff)
        if durations:
            avg = sum(durations) / len(durations)
            days = int((days + avg) / 2)
            reasons.append(f"Blended with average task duration ({avg:.0f} days) from {len(durations)} completed tasks")

    suggested = date.today() + timedelta(days=days)
    return suggested.isoformat(), reasons


# ──────────────────────────────────────────────────────────────────────────────
# 4. Delay prediction
# ──────────────────────────────────────────────────────────────────────────────

def predict_delay(project_id=None, task_id=None):
    """
    Predict delay risk for a project or a specific task.
    Returns a dict with risk_level, delay_probability, and reasons.
    """
    if task_id:
        return _predict_task_delay(task_id)
    if project_id:
        return _predict_project_delay(project_id)
    return {"error": "project_id or task_id is required"}


def _predict_task_delay(task_id):
    task = Task.query.get(task_id)
    if not task:
        return {"error": "Task not found"}

    score = 0
    reasons = []

    if not task.due_date:
        reasons.append("No due date set — cannot predict delay")
        return {"task_id": str(task_id), "risk_level": "unknown", "delay_probability": 0, "reasons": reasons}

    days_left = (task.due_date - date.today()).days

    if days_left < 0:
        score += 5
        reasons.append(f"Task is already overdue by {abs(days_left)} day(s)")
    elif days_left == 0:
        score += 4
        reasons.append("Task is due today")
    elif days_left <= 2:
        score += 3
        reasons.append(f"Due in {days_left} day(s)")
    elif days_left <= 5:
        score += 1
        reasons.append(f"Due in {days_left} day(s)")

    if task.status == "pending" and days_left <= 3:
        score += 2
        reasons.append("Status is still 'pending' with deadline approaching")
    elif task.status == "in_progress" and days_left <= 1:
        score += 1
        reasons.append("In progress but very close to deadline")

    if task.priority == "high" and task.status != "done":
        score += 1
        reasons.append("High priority task still not done")

    if task.assigned_to:
        workload = get_user_workload(task.assigned_to)
        if workload >= 5:
            score += 2
            reasons.append(f"Assignee has {workload} active tasks — heavy workload")
        elif workload >= 3:
            score += 1
            reasons.append(f"Assignee has {workload} active tasks")

    probability = min(100, score * 15)
    if probability >= 70:
        risk = "high"
    elif probability >= 40:
        risk = "medium"
    else:
        risk = "low"

    return {
        "task_id": str(task_id),
        "risk_level": risk,
        "delay_probability": probability,
        "reasons": reasons,
    }


def _predict_project_delay(project_id):
    project = Project.query.get(project_id)
    if not project:
        return {"error": "Project not found"}

    tasks = Task.query.filter_by(project_id=project_id).all()
    if not tasks:
        return {
            "project_id": str(project_id),
            "risk_level": "low",
            "delay_probability": 0,
            "reasons": ["No tasks in project"],
            "task_risks": [],
        }

    task_risks = []
    total_score = 0

    for t in tasks:
        if t.status == "done":
            continue
        risk = _predict_task_delay(t.id)
        task_risks.append(risk)
        total_score += risk.get("delay_probability", 0)

    active_count = len(task_risks)
    if active_count == 0:
        return {
            "project_id": str(project_id),
            "risk_level": "low",
            "delay_probability": 0,
            "reasons": ["All tasks are done"],
            "task_risks": [],
        }

    avg_probability = total_score / active_count
    reasons = []

    overdue = Task.query.filter(
        Task.project_id == project_id,
        Task.status != "done",
        Task.due_date < date.today(),
    ).count()
    if overdue:
        reasons.append(f"{overdue} task(s) are overdue")

    if project.end_date:
        days_to_end = (project.end_date - date.today()).days
        if days_to_end < 0:
            reasons.append(f"Project deadline passed {abs(days_to_end)} day(s) ago")
        elif days_to_end <= 7:
            reasons.append(f"Project deadline in {days_to_end} day(s)")

    done_count = sum(1 for t in tasks if t.status == "done")
    total = len(tasks)
    completion_pct = round(done_count / total * 100) if total else 0
    reasons.append(f"Completion rate: {completion_pct}% ({done_count}/{total} tasks done)")

    if avg_probability >= 70:
        risk = "high"
    elif avg_probability >= 40:
        risk = "medium"
    else:
        risk = "low"

    return {
        "project_id": str(project_id),
        "risk_level": risk,
        "delay_probability": round(avg_probability),
        "reasons": reasons,
        "task_risks": task_risks,
    }


# ──────────────────────────────────────────────────────────────────────────────
# 5. Workload per user
# ──────────────────────────────────────────────────────────────────────────────

def calculate_workload(user_id=None):
    """Return workload details for one user or all users."""
    if user_id:
        return _single_user_workload(user_id)
    return _all_users_workload()


def _single_user_workload(user_id):
    user = User.query.get(user_id)
    if not user:
        return {"error": "User not found"}

    total = Task.query.filter(Task.assigned_to == user_id).count()
    pending = Task.query.filter(Task.assigned_to == user_id, Task.status == "pending").count()
    in_progress = Task.query.filter(Task.assigned_to == user_id, Task.status == "in_progress").count()
    done = Task.query.filter(Task.assigned_to == user_id, Task.status == "done").count()
    overdue = Task.query.filter(
        Task.assigned_to == user_id,
        Task.status != "done",
        Task.due_date < date.today(),
    ).count()

    high_priority = Task.query.filter(
        Task.assigned_to == user_id,
        Task.status != "done",
        Task.priority == "high",
    ).count()

    active = pending + in_progress
    if active >= 8:
        load_level = "overloaded"
    elif active >= 5:
        load_level = "heavy"
    elif active >= 2:
        load_level = "moderate"
    else:
        load_level = "light"

    return {
        "user_id": str(user_id),
        "display_name": user.display_name,
        "total_tasks": total,
        "pending": pending,
        "in_progress": in_progress,
        "done": done,
        "overdue": overdue,
        "high_priority_active": high_priority,
        "active_tasks": active,
        "load_level": load_level,
    }


def _all_users_workload():
    users = User.query.all()
    result = []
    for u in users:
        w = _single_user_workload(u.id)
        if "error" not in w:
            result.append(w)
    result.sort(key=lambda x: x["active_tasks"], reverse=True)
    return result


# ──────────────────────────────────────────────────────────────────────────────
# 6. Statistics: completion rate, workload distribution
# ──────────────────────────────────────────────────────────────────────────────

def get_project_stats(project_id):
    """Completion rate and task breakdown for a project."""
    project = Project.query.get(project_id)
    if not project:
        return {"error": "Project not found"}

    tasks = Task.query.filter_by(project_id=project_id).all()
    total = len(tasks)
    if total == 0:
        return {
            "project_id": str(project_id),
            "project_name": project.name,
            "total_tasks": 0,
            "completion_rate": 0,
            "status_breakdown": {"pending": 0, "in_progress": 0, "done": 0},
            "priority_breakdown": {"low": 0, "medium": 0, "high": 0},
            "overdue_tasks": 0,
            "member_workloads": [],
        }

    status_breakdown = {"pending": 0, "in_progress": 0, "done": 0}
    priority_breakdown = {"low": 0, "medium": 0, "high": 0}
    overdue = 0

    for t in tasks:
        status_breakdown[t.status] = status_breakdown.get(t.status, 0) + 1
        priority_breakdown[t.priority] = priority_breakdown.get(t.priority, 0) + 1
        if t.status != "done" and t.due_date and t.due_date < date.today():
            overdue += 1

    done_count = status_breakdown.get("done", 0)
    completion_rate = round(done_count / total * 100, 1)

    # Member workloads within this project
    member_ids = set()
    member_ids.add(project.user_id)
    pms = ProjectMember.query.filter_by(project_id=project_id).all()
    for pm in pms:
        member_ids.add(pm.user_id)

    member_workloads = []
    for uid in member_ids:
        user = User.query.get(uid)
        if not user:
            continue
        user_tasks = [t for t in tasks if t.assigned_to == uid]
        user_done = sum(1 for t in user_tasks if t.status == "done")
        user_active = sum(1 for t in user_tasks if t.status != "done")
        member_workloads.append({
            "user_id": str(uid),
            "display_name": user.display_name,
            "total": len(user_tasks),
            "done": user_done,
            "active": user_active,
            "completion_rate": round(user_done / len(user_tasks) * 100, 1) if user_tasks else 0,
        })

    return {
        "project_id": str(project_id),
        "project_name": project.name,
        "total_tasks": total,
        "completion_rate": completion_rate,
        "status_breakdown": status_breakdown,
        "priority_breakdown": priority_breakdown,
        "overdue_tasks": overdue,
        "member_workloads": member_workloads,
    }


def get_global_stats():
    """System-wide statistics."""
    total_users = User.query.count()
    total_projects = Project.query.count()
    total_tasks = Task.query.count()

    tasks_done = Task.query.filter_by(status="done").count()
    tasks_pending = Task.query.filter_by(status="pending").count()
    tasks_in_progress = Task.query.filter_by(status="in_progress").count()

    overdue = Task.query.filter(
        Task.status != "done",
        Task.due_date < date.today(),
    ).count()

    completion_rate = round(tasks_done / total_tasks * 100, 1) if total_tasks else 0

    return {
        "total_users": total_users,
        "total_projects": total_projects,
        "total_tasks": total_tasks,
        "completion_rate": completion_rate,
        "status_breakdown": {
            "pending": tasks_pending,
            "in_progress": tasks_in_progress,
            "done": tasks_done,
        },
        "overdue_tasks": overdue,
    }
