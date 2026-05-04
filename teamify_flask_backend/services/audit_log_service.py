"""
Structured JSON Audit Logging Service (Week 3)

Creates two named loggers that write newline-delimited JSON to:
  - logs/security.log  → authentication events, lockouts, permission denials
  - logs/ai.log        → AI feature usage (assign, delay, priority, workload)

Usage:
    from services.audit_log_service import log_security_event, log_ai_event

    log_security_event("LOGIN_FAILED", user_id=3, ip="1.2.3.4", severity="WARNING")
    log_ai_event("AUTO_ASSIGN", user_id=5, ip="1.2.3.4", details={"project_id": 7})
"""
from __future__ import annotations

import json
import logging
import os
from datetime import datetime, timezone
from logging.handlers import RotatingFileHandler
from typing import Any, Optional

# ─── Log directory ────────────────────────────────────────────────────────────

LOG_DIR = os.getenv("AUDIT_LOG_DIR", os.path.join(os.getcwd(), "logs"))
os.makedirs(LOG_DIR, exist_ok=True)

# ─── JSON formatter ───────────────────────────────────────────────────────────

class _JsonFormatter(logging.Formatter):
    """
    Formats every log record as a single-line JSON object.
    Standard fields are merged with any extras passed via the `extra` dict.
    """
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "severity":  record.levelname,
            "logger":    record.name,
            "action":    record.getMessage(),
        }
        # Merge any extra fields (user_id, ip, details, etc.)
        for key, value in record.__dict__.items():
            if key not in logging.LogRecord.__dict__ and not key.startswith("_"):
                payload[key] = value
        return json.dumps(payload, default=str)


def _build_logger(name: str, filename: str) -> logging.Logger:
    """
    Create (or retrieve) a named logger that writes JSON to a rotating file.
    Max file size: 10 MB; keeps 5 backups.
    """
    logger = logging.getLogger(name)
    if logger.handlers:
        # Already configured (e.g. app reloaded in dev mode) — skip setup
        return logger

    logger.setLevel(logging.DEBUG)
    logger.propagate = False  # Don't bubble up to Flask's root logger

    handler = RotatingFileHandler(
        os.path.join(LOG_DIR, filename),
        maxBytes=10 * 1024 * 1024,  # 10 MB
        backupCount=5,
        encoding="utf-8",
    )
    handler.setFormatter(_JsonFormatter())
    logger.addHandler(handler)
    return logger


# ─── Named loggers ────────────────────────────────────────────────────────────

_security_logger = _build_logger("teamify.security", "security.log")
_ai_logger       = _build_logger("teamify.ai",       "ai.log")


# ─── DB persistence helper ───────────────────────────────────────────────────

def _persist_to_db(
    action: str,
    *,
    user_id: Optional[int] = None,
    ip: Optional[str] = None,
    severity: str = "INFO",
    details: Optional[dict] = None,
) -> None:
    """
    Write an audit event to the AuditLog DB table.
    Wrapped in try/except so a DB failure never breaks the calling route.
    """
    try:
        from flask import has_app_context
        if not has_app_context():
            return
        from models.audit_log import AuditLog
        from models import db
        log_entry = AuditLog(
            user_id=user_id,
            action=action,
            details=json.dumps(details or {}, default=str),
            ip_address=ip,
            severity=severity.upper(),
        )
        db.session.add(log_entry)
        db.session.commit()
    except Exception:
        # Never let audit persistence crash the main request
        pass


# ─── Public API ───────────────────────────────────────────────────────────────

def log_security_event(
    action: str,
    *,
    user_id: Optional[int] = None,
    ip: Optional[str] = None,
    severity: str = "INFO",
    details: Optional[dict] = None,
) -> None:
    """
    Record a security-relevant event to BOTH the JSON log file AND the DB.
    """
    level = getattr(logging, severity.upper(), logging.INFO)
    _security_logger.log(
        level, action,
        extra={
            "user_id": user_id,
            "ip_address": ip,
            "details": details or {},
        },
    )
    # Dual-write: persist to AuditLog DB table for queryable compliance trail
    _persist_to_db(action, user_id=user_id, ip=ip, severity=severity, details=details)


def log_ai_event(
    action: str,
    *,
    user_id: Optional[int] = None,
    ip: Optional[str] = None,
    severity: str = "INFO",
    details: Optional[dict] = None,
) -> None:
    """
    Record an AI feature usage event to BOTH the JSON log file AND the DB.
    """
    level = getattr(logging, severity.upper(), logging.INFO)
    _ai_logger.log(
        level, action,
        extra={
            "user_id": user_id,
            "ip_address": ip,
            "details": details or {},
        },
    )
    _persist_to_db(action, user_id=user_id, ip=ip, severity=severity, details=details)

