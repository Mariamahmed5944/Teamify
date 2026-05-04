from flask import Blueprint, request, jsonify
from flask_jwt_extended import get_jwt_identity
from middleware.auth import auth_required
from models import db
from models.log import Log

reminders_bp = Blueprint("reminders", __name__, url_prefix="/api/reminders")


@reminders_bp.route("", methods=["GET"])
@auth_required
def get_my_reminders():
    """
    Get task reminders for the current user (due today, due tomorrow, overdue).
    ---
    tags:
      - Reminders
    security:
      - Bearer: []
    parameters:
      - in: query
        name: limit
        type: integer
        default: 50
        description: Max number of reminders to return
      - in: query
        name: type
        type: string
        description: Filter by type (DUE_TODAY, DUE_TOMORROW, OVERDUE)
    responses:
      200:
        description: List of reminders
        schema:
          type: object
          properties:
            reminders:
              type: array
              items:
                type: object
            total:
              type: integer
      401:
        description: Unauthorized
        schema:
          type: object
          properties:
            error:
              type: string
    """
    user_id = int(get_jwt_identity())
    limit = min(int(request.args.get("limit", 50)), 200)
    reminder_type = request.args.get("type", "").strip().upper()

    query = Log.query.filter(
        Log.user_id == user_id,
        Log.entity == "Reminder",
    )

    valid_types = {"DUE_TODAY", "DUE_TOMORROW", "OVERDUE"}
    if reminder_type and reminder_type in valid_types:
        query = query.filter(Log.action == reminder_type)
    else:
        query = query.filter(Log.action.in_(valid_types))

    reminders = (
        query
        .order_by(Log.created_at.desc())
        .limit(limit)
        .all()
    )

    return jsonify({
        "reminders": [r.to_dict() for r in reminders],
        "total": len(reminders),
    }), 200
