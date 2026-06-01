"""Track and revoke authenticated user sessions for the Security Center."""
from __future__ import annotations

import re
from datetime import datetime, timezone

from flask_jwt_extended import decode_token

from models import db
from models.admin_panel import AdminSession
from models.token_blocklist import TokenBlocklist

_AUTOMATION_UA = re.compile(
    r"python-requests|axios/|curl/|postman|pytest|httpie|go-http-client|insomnia|java/",
    re.I,
)


def is_automation_agent(device_info: str | None) -> bool:
    return bool(device_info and _AUTOMATION_UA.search(device_info))


def register_session(
    user_id: int,
    access_token: str,
    *,
    ip_address: str | None = None,
    device_info: str | None = None,
) -> None:
    """Persist a live session row keyed by JWT jti."""
    try:
        decoded = decode_token(access_token)
        jti = decoded.get("jti")
        if not jti:
            return
        session = AdminSession(
            user_id=user_id,
            jti=jti,
            ip_address=(ip_address or "unknown")[:50],
            device_info=(device_info or "")[:255] or None,
        )
        db.session.add(session)
        db.session.commit()
    except Exception:
        db.session.rollback()


def revoke_session_jti(jti: str, *, expires_at: datetime | None = None) -> None:
    """Mark one session revoked and blocklist its JWT."""
    if not jti:
        return
    now = datetime.now(timezone.utc)
    session = AdminSession.query.filter_by(jti=jti, revoked_at=None).first()
    if session:
        session.revoked_at = now
    TokenBlocklist.revoke(jti, expires_at=expires_at)
    db.session.commit()


def revoke_all_user_sessions(user_id: int) -> int:
    """Force-logout a user from every tracked device."""
    now = datetime.now(timezone.utc)
    sessions = (
        AdminSession.query.filter_by(user_id=user_id)
        .filter(AdminSession.revoked_at.is_(None))
        .all()
    )
    for session in sessions:
        if session.jti:
            TokenBlocklist.revoke(session.jti)
        session.revoked_at = now
    db.session.commit()
    return len(sessions)


def count_active_sessions() -> int:
    return AdminSession.query.filter(AdminSession.revoked_at.is_(None)).count()
