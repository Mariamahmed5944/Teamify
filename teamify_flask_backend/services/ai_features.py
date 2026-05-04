"""
AI Feature Calculation Service
===============================

Centralised computation of all AI-derived features for the Delay Prediction
and AI Rating models.  Each function takes ORM objects and returns plain
Python values that can be serialised to JSON or fed directly into ML pipelines.

All formulas match the feature specifications in:
  - Delay_Prediction_Features_Updated.pdf
  - AI Rating Feature.pdf
  - Untitled document(7).pdf
"""
from __future__ import annotations

from datetime import date
from typing import TYPE_CHECKING, List, Optional

if TYPE_CHECKING:
    from models.user import User
    from models.task import Task
    from models.project import Project


# ─── Task-level calculations ─────────────────────────────────────────────────

def calc_days_since_start(task: "Task") -> int:
    """days_since_start = today - start_date"""
    if not task.start_date:
        return 0
    return (date.today() - task.start_date).days


def calc_days_remaining(task: "Task") -> Optional[int]:
    """days_remaining = due_date - today  (negative ⇒ already delayed)"""
    if not task.due_date:
        return None
    return (task.due_date - date.today()).days


def calc_expected_progress(task: "Task") -> float:
    """expected_progress_percent = (days_since_start / estimated_duration_days) * 100"""
    if not task.estimated_duration_days or task.estimated_duration_days == 0:
        return 0.0
    return (calc_days_since_start(task) / task.estimated_duration_days) * 100


def calc_progress_gap(task: "Task") -> float:
    """progress_gap = expected_progress_percent - progress_percent"""
    return calc_expected_progress(task) - (task.progress_percent or 0.0)


# ─── Member-level calculations ───────────────────────────────────────────────

def calc_tasks_assigned(user: "User", project: "Project" = None) -> int:
    """tasks_assigned = len(member.assigned_tasks_in_project)"""
    tasks = user.assigned_tasks
    if project:
        tasks = [t for t in tasks if t.project_id == project.id]
    return len(tasks)


def calc_tasks_completed(user: "User", project: "Project" = None) -> int:
    """tasks_completed = len(tasks where status == 'Completed')"""
    tasks = user.assigned_tasks
    if project:
        tasks = [t for t in tasks if t.project_id == project.id]
    return len([t for t in tasks if t.status == "Completed"])


def calc_overdue_tasks(user: "User") -> int:
    """overdue_tasks = len(tasks where completed_date > deadline)"""
    return len([
        t for t in user.assigned_tasks
        if t.completed_date and t.due_date and t.completed_date.date() > t.due_date
    ])


def calc_quality_score(user: "User") -> float:
    """quality_score = Average(task.review_score) / 5"""
    scores = [t.review_score for t in user.assigned_tasks if t.review_score is not None]
    if not scores:
        return 0.0
    return (sum(scores) / len(scores)) / 5.0


def calc_teamwork_score(user: "User") -> float:
    """teamwork_score = Average(peer_ratings) / 5
    Uses the Feedback model's teamwork_score field."""
    feedbacks = getattr(user, "received_feedbacks", [])
    scores = [f.teamwork_score for f in feedbacks if f.teamwork_score is not None]
    if not scores:
        return 0.0
    return (sum(scores) / len(scores)) / 5.0


def calc_attendance_rate(user: "User") -> float:
    """attendance_rate = meetings_attended / total_meetings"""
    if not user.total_meetings:
        return 0.0
    return user.meetings_attended / user.total_meetings


def calc_skill_match(user: "User", project: "Project") -> int:
    """skill_match = 1 if project.category in member.skills else 0"""
    if not user.skills or not project or not getattr(project, "category", None):
        return 0
    return 1 if project.category in user.skills else 0


def calc_project_similarity(user: "User", project: "Project") -> int:
    """project_similarity = 1 if project.category in member.previous_categories else 0"""
    if not user.previous_categories or not project or not getattr(project, "category", None):
        return 0
    return 1 if project.category in user.previous_categories else 0


def calc_member_current_tasks(user: "User") -> int:
    """member_current_tasks = count(tasks where status != 'Completed')"""
    return len([t for t in user.assigned_tasks if t.status != "Completed"])


def calc_availability_score(user: "User") -> float:
    """availability_score = 1 - (member.current_tasks / max_capacity)"""
    if not user.max_capacity:
        return 0.0
    score = 1.0 - (calc_member_current_tasks(user) / user.max_capacity)
    return max(0.0, score)


def calc_workload_ratio(user: "User") -> float:
    """workload_ratio = member_current_tasks / max_allowed_tasks"""
    if not user.max_allowed_tasks:
        return 0.0
    return calc_member_current_tasks(user) / user.max_allowed_tasks


def calc_avg_rating(user: "User") -> float:
    """avg_rating = Sum(member.project_ratings) / len(member.project_ratings)"""
    feedbacks = getattr(user, "received_feedbacks", [])
    ratings = [f.avg_rating for f in feedbacks if f.avg_rating is not None]
    if not ratings:
        return 0.0
    return sum(ratings) / len(ratings)


# ─── Aggregated feature vectors ──────────────────────────────────────────────

def get_task_features(task: "Task") -> dict:
    """Return all AI features for a single task."""
    return {
        "estimated_duration_days": task.estimated_duration_days,
        "progress_percent": task.progress_percent,
        "priority_level": task.priority_level,
        "complexity_level": task.complexity_level,
        "num_subtasks": task.num_subtasks,
        "task_difficulty": task.task_difficulty,
        "deadline_days": task.deadline_days,
        "days_since_start": calc_days_since_start(task),
        "days_remaining": calc_days_remaining(task),
        "expected_progress_percent": calc_expected_progress(task),
        "progress_gap": calc_progress_gap(task),
    }


def get_member_features(user: "User", project: "Project" = None) -> dict:
    """Return all AI features for a member, optionally scoped to a project."""
    features = {
        "member_on_time_rate": user.member_on_time_rate,
        "member_avg_delay_days": user.member_avg_delay_days,
        "member_experience_years": user.member_experience_years,
        "max_allowed_tasks": user.max_allowed_tasks,
        "max_capacity": user.max_capacity,
        "tasks_assigned": calc_tasks_assigned(user, project),
        "tasks_completed": calc_tasks_completed(user, project),
        "overdue_tasks": calc_overdue_tasks(user),
        "quality_score": calc_quality_score(user),
        "teamwork_score": calc_teamwork_score(user),
        "attendance_rate": calc_attendance_rate(user),
        "member_current_tasks": calc_member_current_tasks(user),
        "availability_score": calc_availability_score(user),
        "workload_ratio": calc_workload_ratio(user),
        "avg_rating": calc_avg_rating(user),
    }
    if project:
        features["skill_match"] = calc_skill_match(user, project)
        features["project_similarity"] = calc_project_similarity(user, project)
    return features
