from flask import Blueprint, request, jsonify
from flask_jwt_extended import get_jwt_identity
from middleware.auth import auth_required, admin_required
from models.log import Log

logs_bp = Blueprint("logs", __name__, url_prefix="/api/logs")


# ─── GET /api/logs/my ────────────────────────────────────────────────────────

@logs_bp.route("/my", methods=["GET"])
@auth_required
def get_my_logs():
    """
    Get the activity logs for the current authenticated user.
    ---
    tags:
      - Logs
    security:
      - Bearer: []
    parameters:
      - in: query
        name: limit
        type: integer
        default: 50
        description: Max number of logs to return
    responses:
      200:
        description: User's activity logs
        schema:
          type: object
          properties:
            logs:
              type: array
              items:
                type: object
                properties:
                  id:
                    type: string
                  action:
                    type: string
                  entity:
                    type: string
                  entity_id:
                    type: string
                  details:
                    type: string
                  user_id:
                    type: string
                  created_at:
                    type: string
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

    logs = (
        Log.query
        .filter_by(user_id=user_id)
        .order_by(Log.created_at.desc())
        .limit(limit)
        .all()
    )
    return jsonify({"logs": [l.to_dict() for l in logs], "total": len(logs)}), 200


# ─── GET /api/logs/all  (admin only) ─────────────────────────────────────────

@logs_bp.route("/all", methods=["GET"])
@admin_required
def get_all_logs():
    """
    Get all system activity logs — admin only.
    ---
    tags:
      - Logs
    security:
      - Bearer: []
    parameters:
      - in: query
        name: limit
        type: integer
        default: 100
      - in: query
        name: action
        type: string
        description: Filter by action (e.g. LOGIN, CREATE, DELETE)
      - in: query
        name: entity
        type: string
        description: Filter by entity (e.g. User, Project, Task)
    responses:
      200:
        description: All logs
        schema:
          type: object
          properties:
            logs:
              type: array
              items:
                type: object
                properties:
                  id:
                    type: string
                  action:
                    type: string
                  entity:
                    type: string
                  entity_id:
                    type: string
                  details:
                    type: string
                  user_id:
                    type: string
                  created_at:
                    type: string
            total:
              type: integer
      401:
        description: Unauthorized
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
    limit = min(int(request.args.get("limit", 100)), 500)
    action_filter = request.args.get("action")
    entity_filter = request.args.get("entity")

    query = Log.query
    if action_filter:
        query = query.filter(Log.action == action_filter.upper())
    if entity_filter:
        query = query.filter(Log.entity == entity_filter)

    logs = query.order_by(Log.created_at.desc()).limit(limit).all()
    return jsonify({"logs": [l.to_dict() for l in logs], "total": len(logs)}), 200
