from datetime import datetime, timezone, date
from models import db


class Task(db.Model):
    """Task model with AI feature fields for delay prediction."""

    __tablename__ = "tasks"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    title = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text, nullable=True)
    status = db.Column(db.String(30), nullable=False, default="pending")
    priority = db.Column(db.String(20), nullable=False, default="medium")
    due_date = db.Column(db.Date, nullable=True)
    project_id = db.Column(db.Integer, db.ForeignKey("projects.id"), nullable=False)
    assigned_to = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=True)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = db.Column(
        db.DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    # ─── AI Feature: Raw fields ──────────────────────────────────────────────
    task_difficulty = db.Column(db.Integer, nullable=False, default=3)       # 1=Easy, 3=Medium, 5=Hard
    estimated_duration_days = db.Column(db.Integer, nullable=True)
    progress_percent = db.Column(db.Float, nullable=False, default=0.0)
    priority_level = db.Column(db.Integer, nullable=False, default=2)       # 1=Low, 2=Medium, 3=High
    complexity_level = db.Column(db.Integer, nullable=False, default=3)
    num_subtasks = db.Column(db.Integer, nullable=False, default=0)
    start_date = db.Column(db.Date, nullable=True)
    completed_date = db.Column(db.DateTime, nullable=True)
    review_score = db.Column(db.Float, nullable=True)
    deadline_days = db.Column(db.Integer, nullable=True)                    # user-specified days until deadline
    ai_category   = db.Column(db.String(50), nullable=True)
    ai_difficulty = db.Column(db.String(20), nullable=True)
    ai_delay_risk = db.Column(db.String(20), nullable=True)
    ai_skills     = db.Column(db.JSON, nullable=True)

    __table_args__ = (
        # Fast lookups by project (most common query pattern)
        db.Index("ix_tasks_project_id", "project_id"),
        # Fast filtering by status within a project
        db.Index("ix_tasks_project_status", "project_id", "status"),
        # Fast filtering by assigned user
        db.Index("ix_tasks_assigned_to", "assigned_to"),
    )

    # ─── AI Calculated Properties ────────────────────────────────────────────

    @property
    def days_since_start(self):
        """days_since_start = today - start_date"""
        if not self.start_date:
            return 0
        delta = date.today() - self.start_date
        return delta.days

    @property
    def days_remaining(self):
        """days_remaining = due_date - today (If < 0, task is delayed)"""
        if not self.due_date:
            return None
        delta = self.due_date - date.today()
        return delta.days

    @property
    def expected_progress_percent(self):
        """expected_progress_percent = (days_since_start / estimated_duration_days) * 100"""
        if not self.estimated_duration_days or self.estimated_duration_days == 0:
            return 0.0
        return (self.days_since_start / self.estimated_duration_days) * 100

    @property
    def progress_gap(self):
        """progress_gap = expected_progress_percent - progress_percent"""
        return self.expected_progress_percent - (self.progress_percent or 0.0)

    def to_dict(self):
        """Serialize task to dictionary."""
        return {
            "id": self.id,
            "title": self.title,
            "description": self.description,
            "status": self.status,
            "priority": self.priority,
            "due_date": self.due_date.isoformat() if self.due_date else None,
            "project_id": self.project_id,
            "assigned_to": self.assigned_to,
            "task_difficulty": self.task_difficulty,
            "estimated_duration_days": self.estimated_duration_days,
            "progress_percent": self.progress_percent,
            "priority_level": self.priority_level,
            "complexity_level": self.complexity_level,
            "num_subtasks": self.num_subtasks,
            "start_date": self.start_date.isoformat() if self.start_date else None,
            "completed_date": self.completed_date.isoformat() if self.completed_date else None,
            "review_score": self.review_score,
            "deadline_days": self.deadline_days,
            "days_since_start": self.days_since_start,
            "days_remaining": self.days_remaining,
            "expected_progress_percent": self.expected_progress_percent,
            "progress_gap": self.progress_gap,
            "ai_category": self.ai_category,
            "ai_difficulty": self.ai_difficulty,
            "ai_delay_risk": self.ai_delay_risk,
            "ai_skills": self.ai_skills,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }

    def __repr__(self):
        return f"<Task {self.title}>"
