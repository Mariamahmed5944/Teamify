"""Login-anomaly detection.

`check_login_anomalies(ip)` is called inline from the login route after every
failed attempt. It is also safe to call from a periodic scheduler job.

ML augmentation: when anomaly_service_ml is available, every call also
scores the current login against the IsolationForest model. An anomalous
ML score escalates the alert description but does NOT replace the existing
threshold-based logic, so the service degrades gracefully if the model file
is missing.
"""
from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from typing import Optional

from models import db
from models.login_log import LoginLog
from models.alert import Alert

logger = logging.getLogger(__name__)

# Tunables (could be moved to env / config)
WINDOW_MINUTES = 5
FAIL_THRESHOLD = 5
ALERT_TYPE_BRUTE_FORCE = "brute_force_login"


def check_login_anomalies(
    ip_address: str,
    *,
    window_minutes: int = WINDOW_MINUTES,
    threshold: int = FAIL_THRESHOLD,
    user_id: Optional[int] = None,
    device: str = "",
    browser: str = "",
    failed_attempts: int = 0,
) -> Optional[Alert]:
    """If *ip_address* has >= threshold failed logins in the last *window_minutes*,
    create (and return) a brute_force_login Alert. Idempotent within the window.

    When user_id is provided the ML IsolationForest model is also consulted;
    a positive anomaly flag is appended to the alert description.
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

    # ── ML anomaly augmentation ───────────────────────────────────────────────
    ml_anomaly_note = ""
    if user_id is not None:
        try:
            from services.anomaly_service_ml import score_login_from_context
            ml_result = score_login_from_context(
                user_id,
                ip_address,
                device=device,
                browser=browser,
                failed_attempts=failed_attempts,
            )
            if ml_result.get("model_available") and ml_result.get("is_anomaly"):
                score = ml_result.get("anomaly_score", 0)
                ml_anomaly_note = (
                    f" ML anomaly detector flagged this login (score={score})."
                )
        except Exception as exc:
            logger.warning(
                "ML anomaly scoring failed for user %s: %s",
                user_id,
                exc,
            )  # ML scoring is non-critical; never block the auth flow

    if fail_count < threshold and not ml_anomaly_note:
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

    description = (
        f"{fail_count} failed login attempts from {ip_address} "
        f"in the last {window_minutes} minutes.{ml_anomaly_note}"
    )
    alert = Alert(
        type=ALERT_TYPE_BRUTE_FORCE,
        description=description,
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
