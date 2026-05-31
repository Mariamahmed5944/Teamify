"""Dual-write admin actions to Log + AuditLog tables."""
from __future__ import annotations

import json
from typing import Any

from flask import request

from models import db
from models.audit_log import AuditLog
from models.log import Log


def log_admin_action(
    *,
    admin_id: int,
    action: str,
    entity: str,
    entity_id: int | None = None,
    details: str = "",
    severity: str = "INFO",
    extra: dict[str, Any] | None = None,
) -> None:
    """Persist an admin mutation to both application and security audit trails."""
    detail_text = details
    if extra:
        detail_text = f"{details} | {json.dumps(extra, default=str)}" if details else json.dumps(extra, default=str)

    db.session.add(
        Log(
            action=action,
            entity=entity,
            entity_id=entity_id,
            details=detail_text or action,
            user_id=admin_id,
        )
    )
    audit = AuditLog()
    audit.user_id = admin_id
    audit.action = action
    audit.details = detail_text or action
    audit.ip_address = (request.remote_addr or "")[:50] or None
    audit.severity = severity.upper()
    db.session.add(audit)
