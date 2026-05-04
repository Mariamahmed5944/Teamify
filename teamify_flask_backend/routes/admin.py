"""Admin-only endpoints for security audit (login logs + anomaly alerts)."""
from datetime import datetime, timezone

from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity

from middleware.auth import admin_required
from models import db
from models.login_log import LoginLog
from models.alert import Alert

admin_bp = Blueprint("admin", __name__, url_prefix="/admin")


def _paginate_args(default_per_page: int = 50, max_per_page: int = 200):
    try:
        page = max(1, int(request.args.get("page", 1)))
    except (TypeError, ValueError):
        page = 1
    try:
        per_page = int(request.args.get("per_page", default_per_page))
    except (TypeError, ValueError):
        per_page = default_per_page
    per_page = max(1, min(per_page, max_per_page))
    return page, per_page


# ─── GET /admin/logs ─────────────────────────────────────────────────────────

@admin_bp.route("/logs", methods=["GET"])
@admin_required
def list_login_logs():
    """
    List login logs (admin only).
    ---
    tags: [Admin]
    security: [{Bearer: []}]
    parameters:
      - {in: query, name: page, type: integer, default: 1}
      - {in: query, name: per_page, type: integer, default: 50}
      - {in: query, name: status, type: string, enum: [success, fail]}
      - {in: query, name: ip, type: string}
      - {in: query, name: user_id, type: string}
    responses:
      200:
        description: Paginated list of login logs
        schema:
          type: object
          properties:
            items:
              type: array
              items:
                type: object
            page:
              type: integer
            per_page:
              type: integer
            total:
              type: integer
            pages:
              type: integer
      401:
        description: Missing or invalid token
        schema:
          type: object
          properties:
            error:
              type: string
      403:
        description: Admin access required
        schema:
          type: object
          properties:
            error:
              type: string
    """
    page, per_page = _paginate_args()
    q = LoginLog.query

    status = request.args.get("status")
    if status in ("success", "fail"):
        q = q.filter(LoginLog.status == status)

    ip = request.args.get("ip")
    if ip:
        q = q.filter(LoginLog.ip_address == ip)

    user_id = request.args.get("user_id")
    if user_id:
        try:
            q = q.filter(LoginLog.user_id == int(user_id))
        except (ValueError, AttributeError):
            return jsonify({"error": "Invalid user_id"}), 400

    pagination = q.order_by(LoginLog.timestamp.desc()).paginate(
        page=page, per_page=per_page, error_out=False
    )
    return jsonify({
        "items": [row.to_dict() for row in pagination.items],
        "page": pagination.page,
        "per_page": pagination.per_page,
        "total": pagination.total,
        "pages": pagination.pages,
    }), 200


# ─── GET /admin/alerts ───────────────────────────────────────────────────────

@admin_bp.route("/alerts", methods=["GET"])
@admin_required
def list_alerts():
    """
    List security alerts (admin only).
    ---
    tags: [Admin]
    security: [{Bearer: []}]
    parameters:
      - {in: query, name: page, type: integer, default: 1}
      - {in: query, name: per_page, type: integer, default: 50}
      - {in: query, name: resolved, type: string, enum: [true, false]}
      - {in: query, name: type, type: string}
    responses:
      200:
        description: Paginated list of alerts
        schema:
          type: object
          properties:
            items:
              type: array
              items:
                type: object
            page:
              type: integer
            per_page:
              type: integer
            total:
              type: integer
            pages:
              type: integer
      401:
        description: Missing or invalid token
        schema:
          type: object
          properties:
            error:
              type: string
      403:
        description: Admin access required
        schema:
          type: object
          properties:
            error:
              type: string
    """
    page, per_page = _paginate_args()
    q = Alert.query

    resolved = request.args.get("resolved")
    if resolved is not None:
        if resolved.lower() in ("true", "1", "yes"):
            q = q.filter(Alert.resolved.is_(True))
        elif resolved.lower() in ("false", "0", "no"):
            q = q.filter(Alert.resolved.is_(False))

    alert_type = request.args.get("type")
    if alert_type:
        q = q.filter(Alert.type == alert_type)

    pagination = q.order_by(Alert.timestamp.desc()).paginate(
        page=page, per_page=per_page, error_out=False
    )
    return jsonify({
        "items": [a.to_dict() for a in pagination.items],
        "page": pagination.page,
        "per_page": pagination.per_page,
        "total": pagination.total,
        "pages": pagination.pages,
    }), 200


# ─── PATCH /admin/alerts/<id>/resolve ────────────────────────────────────────

@admin_bp.route("/alerts/<alert_id>/resolve", methods=["PATCH"])
@admin_required
def resolve_alert(alert_id: str):
    """
    Mark an alert as resolved (admin only).
    ---
    tags: [Admin]
    security: [{Bearer: []}]
    parameters:
      - {in: path, name: alert_id, type: string, required: true}
    responses:
      200:
        description: Alert resolved
        schema:
          type: object
          properties:
            message:
              type: string
            alert:
              type: object
      404:
        description: Alert not found
        schema:
          type: object
          properties:
            error:
              type: string
    """
    try:
        aid = int(alert_id)
    except (ValueError, AttributeError):
        return jsonify({"error": "Invalid alert_id"}), 400

    alert = Alert.query.filter_by(id=aid).first()
    if not alert:
        return jsonify({"error": "Not Found"}), 404

    alert.resolved = True
    alert.resolved_at = datetime.now(timezone.utc)
    try:
        alert.resolved_by = int(get_jwt_identity())
    except (ValueError, TypeError):
        alert.resolved_by = None
    db.session.commit()
    return jsonify({"message": "Alert resolved", "alert": alert.to_dict()}), 200
