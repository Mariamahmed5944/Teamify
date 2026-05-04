"""Login-anomaly detection.

`check_login_anomalies(ip)` is called inline from the login route after every
failed attempt. It is also safe to call from a periodic scheduler job.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Optional

from models import db
from models.login_log import LoginLog
from models.alert import Alert

# Tunables (could be moved to env / config)
WINDOW_MINUTES = 5
FAIL_THRESHOLD = 5
ALERT_TYPE_BRUTE_FORCE = "brute_force_login"


def check_login_anomalies(
    ip_address: str,
    *,
    window_minutes: int = WINDOW_MINUTES,
    threshold: int = FAIL_THRESHOLD,
) -> Optional[Alert]:
    """If *ip_address* has >= threshold failed logins in the last *window_minutes*,
    create (and return) a brute_force_login Alert. Idempotent within the window.
    """
    if not ip_address:
        return None

    # Use timezone-aware UTC datetime.
    now = datetime.now(timezone.utc)
    window_start = now - timedelta(minutes=window_minutes)

    fail_count = (
        db.session.query(LoginLog)
        .filter(
            LoginLog.status == "fail",
            LoginLog.ip_address == ip_address,
            LoginLog.timestamp >= window_start,
        )
        .count()
    )

    if fail_count < threshold:
        return None

    # Dedupe: don't create another alert if an unresolved one for this IP
    # already exists within the same window.
    existing = (
        db.session.query(Alert)
        .filter(
            Alert.type == ALERT_TYPE_BRUTE_FORCE,
            Alert.resolved.is_(False),
            Alert.timestamp >= window_start,
            Alert.description.like(f"%{ip_address}%"),
        )
        .first()
    )
    if existing:
        return existing

    alert = Alert(
        type=ALERT_TYPE_BRUTE_FORCE,
        description=(
            f"{fail_count} failed login attempts from {ip_address} "
            f"in the last {window_minutes} minutes."
        ),
    )
    db.session.add(alert)
    try:
        db.session.commit()
    except Exception:
        db.session.rollback()
        return None
    return alert


def scan_recent_failures(
    *,
    window_minutes: int = WINDOW_MINUTES,
    threshold: int = FAIL_THRESHOLD,
) -> list[Alert]:
    """Scheduler-friendly: scan all IPs with recent failures and create alerts."""
    now = datetime.now(timezone.utc)
    window_start = now - timedelta(minutes=window_minutes)

    rows = (
        db.session.query(LoginLog.ip_address, db.func.count(LoginLog.id))
        .filter(
            LoginLog.status == "fail",
            LoginLog.timestamp >= window_start,
        )
        .group_by(LoginLog.ip_address)
        .having(db.func.count(LoginLog.id) >= threshold)
        .all()
    )

    created: list[Alert] = []
    for ip, _count in rows:
        alert = check_login_anomalies(
            ip, window_minutes=window_minutes, threshold=threshold
        )
        if alert is not None:
            created.append(alert)
    return created
