"""
Task reminders scheduler.

Uses APScheduler to periodically check for tasks approaching their deadline
and tasks that are overdue, generating reminder logs that can be consumed
by the frontend notifications system.
"""

from datetime import date, datetime, timezone
from apscheduler.schedulers.background import BackgroundScheduler
from models import db
from models.task import Task
from models.log import Log
from models.notification import Notification


def check_reminders(app):
    """
    Check all active tasks and create reminder logs for:
      - Tasks due today
      - Tasks due tomorrow
      - Tasks overdue (past due_date and not done)
    """
    with app.app_context():
        today = date.today()

        # --- Tasks due today ---
        due_today = Task.query.filter(
            Task.due_date == today,
            Task.status != "done",
        ).all()

        for task in due_today:
            if not task.assigned_to:
                continue
            # Avoid duplicate reminders: check if we already logged today
            existing = Log.query.filter(
                Log.entity == "Reminder",
                Log.entity_id == task.id,
                Log.action == "DUE_TODAY",
                Log.created_at >= datetime(today.year, today.month, today.day, tzinfo=timezone.utc),
            ).first()
            if existing:
                continue

            log = Log(
                action="DUE_TODAY",
                entity="Reminder",
                entity_id=task.id,
                details=f"Task '{task.title}' is due today",
                user_id=task.assigned_to,
            )
            db.session.add(log)
            db.session.add(Notification(
                user_id=task.assigned_to,
                type="deadline_approaching",
                title="Deadline approaching",
                body=f"Task '{task.title}' is due today",
                entity_type="Task",
                entity_id=task.id,
            ))

        # --- Tasks due tomorrow ---
        from datetime import timedelta
        tomorrow = today + timedelta(days=1)
        due_tomorrow = Task.query.filter(
            Task.due_date == tomorrow,
            Task.status != "done",
        ).all()

        for task in due_tomorrow:
            if not task.assigned_to:
                continue
            existing = Log.query.filter(
                Log.entity == "Reminder",
                Log.entity_id == task.id,
                Log.action == "DUE_TOMORROW",
                Log.created_at >= datetime(today.year, today.month, today.day, tzinfo=timezone.utc),
            ).first()
            if existing:
                continue

            log = Log(
                action="DUE_TOMORROW",
                entity="Reminder",
                entity_id=task.id,
                details=f"Task '{task.title}' is due tomorrow",
                user_id=task.assigned_to,
            )
            db.session.add(log)
            db.session.add(Notification(
                user_id=task.assigned_to,
                type="deadline_approaching",
                title="Deadline approaching",
                body=f"Task '{task.title}' is due tomorrow",
                entity_type="Task",
                entity_id=task.id,
            ))

        # --- Overdue tasks ---
        overdue_tasks = Task.query.filter(
            Task.due_date < today,
            Task.status != "done",
        ).all()

        for task in overdue_tasks:
            if not task.assigned_to:
                continue
            existing = Log.query.filter(
                Log.entity == "Reminder",
                Log.entity_id == task.id,
                Log.action == "OVERDUE",
                Log.created_at >= datetime(today.year, today.month, today.day, tzinfo=timezone.utc),
            ).first()
            if existing:
                continue

            days_overdue = (today - task.due_date).days
            log = Log(
                action="OVERDUE",
                entity="Reminder",
                entity_id=task.id,
                details=f"Task '{task.title}' is overdue by {days_overdue} day(s)",
                user_id=task.assigned_to,
            )
            db.session.add(log)
            db.session.add(Notification(
                user_id=task.assigned_to,
                type="delay_warning",
                title="AI Delay Warning",
                body=f"Task '{task.title}' is overdue by {days_overdue} day(s)",
                entity_type="Task",
                entity_id=task.id,
            ))

        db.session.commit()


def init_scheduler(app):
    """
    Initialize and start the APScheduler background scheduler.
    Runs check_reminders every hour.
    """
    scheduler = BackgroundScheduler()
    scheduler.add_job(
        func=lambda: check_reminders(app),
        trigger="interval",
        hours=1,
        id="task_reminders",
        name="Check task deadlines and send reminders",
        replace_existing=True,
    )
    scheduler.add_job(
        func=lambda: _run_analytics_snapshot(app),
        trigger="cron",
        hour=2,
        minute=0,
        id="admin_analytics_snapshot",
        name="Daily admin analytics snapshot",
        replace_existing=True,
    )
    scheduler.start()
    # Run once immediately at startup
    check_reminders(app)
    _run_analytics_snapshot(app)
    return scheduler


def _run_analytics_snapshot(app):
    with app.app_context():
        from services.analytics_snapshot_service import create_daily_snapshot
        try:
            create_daily_snapshot()
        except Exception:
            pass
