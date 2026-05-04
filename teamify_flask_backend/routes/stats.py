from flask import Blueprint, request, jsonify
from flask_jwt_extended import get_jwt_identity
from middleware.auth import auth_required, admin_required, get_project_role, _READ_ROLES
from services.ai_service import get_project_stats, get_global_stats, calculate_workload

stats_bp = Blueprint("stats", __name__, url_prefix="/api/stats")


# ─── GET /api/stats/project/<project_id> ─────────────────────────────────────

@stats_bp.route("/project/<int:project_id>", methods=["GET"])
@auth_required
def project_stats(project_id):
    """
    Get statistics for a specific project (completion rate, workload, etc.).
    ---
    tags:
      - Statistics
    security:
      - Bearer: []
    parameters:
      - in: path
        name: project_id
        type: string
        required: true
    responses:
      200:
        description: Project statistics
        schema:
          type: object
          properties:
            project_id:
              type: string
            project_name:
              type: string
            total_tasks:
              type: integer
            completion_rate:
              type: number
            status_breakdown:
              type: object
            priority_breakdown:
              type: object
            overdue_tasks:
              type: integer
            member_workloads:
              type: array
      403:
        description: Forbidden
      404:
        description: Project not found
    """
    user_id = int(get_jwt_identity())

    role = get_project_role(user_id, project_id)
    if role not in _READ_ROLES:
        return jsonify({"error": "Forbidden", "message": "You are not a member of this project"}), 403

    result = get_project_stats(project_id)
    if "error" in result:
        return jsonify({"error": result["error"]}), 404

    return jsonify(result), 200


# ─── GET /api/stats/global ───────────────────────────────────────────────────

@stats_bp.route("/global", methods=["GET"])
@admin_required
def global_stats():
    """
    Get system-wide statistics — admin only.
    ---
    tags:
      - Statistics
    security:
      - Bearer: []
    responses:
      200:
        description: Global system statistics
        schema:
          type: object
          properties:
            total_users:
              type: integer
            total_projects:
              type: integer
            total_tasks:
              type: integer
            completion_rate:
              type: number
            status_breakdown:
              type: object
            overdue_tasks:
              type: integer
      403:
        description: Admin access required
    """
    return jsonify(get_global_stats()), 200


# ─── GET /api/stats/workload-overview ────────────────────────────────────────

@stats_bp.route("/workload-overview", methods=["GET"])
@admin_required
def workload_overview():
    """
    Get workload overview for all users — admin only.
    ---
    tags:
      - Statistics
    security:
      - Bearer: []
    responses:
      200:
        description: Workload overview for all users
        schema:
          type: object
          properties:
            workloads:
              type: array
              items:
                type: object
            total_users:
              type: integer
      403:
        description: Admin access required
        schema:
          type: object
          properties:
            error:
              type: string
    """
    result = calculate_workload()
    return jsonify({"workloads": result, "total_users": len(result)}), 200
