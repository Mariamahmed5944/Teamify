from flask import Blueprint, request, jsonify
from flask_jwt_extended import get_jwt_identity
from middleware.auth import auth_required, admin_required
from models import db
from models.user import User
import re

users_bp = Blueprint("users", __name__, url_prefix="/api/users")

EMAIL_RE = re.compile(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
VALID_USER_TYPES = {"freelancer", "student", "admin"}


@users_bp.route("/profile", methods=["GET"])
@auth_required
def get_profile():
    """
    Get the current authenticated user's profile.
    ---
    tags:
      - Users
    security:
      - Bearer: []
    responses:
      200:
        description: User profile data
        schema:
          type: object
          properties:
            user:
              type: object
              properties:
                id:
                  type: string
                display_name:
                  type: string
                full_name:
                  type: string
                email:
                  type: string
                role:
                  type: string
                user_type:
                  type: string
                created_at:
                  type: string
                updated_at:
                  type: string
      401:
        description: Unauthorized — missing or invalid token
      404:
        description: User not found
    """
    current_user_id = get_jwt_identity()
    user = User.query.filter_by(id=int(current_user_id)).first()

    if not user:
        return jsonify({"error": "Not Found", "message": "User not found"}), 404

    return jsonify({"user": user.to_dict()}), 200


@users_bp.route("/profile", methods=["PUT"])
@auth_required
def update_profile():
    """
    Update the current user's profile.
    ---
    tags:
      - Users
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        schema:
          type: object
          properties:
            display_name:
              type: string
              description: New unique display name
            full_name:
              type: string
              description: Real full name (optional)
            user_type:
              type: string
              enum: [freelancer, student, employee, business]
              description: How the user describes themselves
    responses:
      200:
        description: Profile updated successfully
        schema:
          type: object
          properties:
            message:
              type: string
            user:
              type: object
      400:
        description: Validation error
        schema:
          type: object
          properties:
            error:
              type: string
      409:
        description: Display name already taken
        schema:
          type: object
          properties:
            error:
              type: string
      401:
        description: Unauthorized
        schema:
          type: object
          properties:
            error:
              type: string
    """
    current_user_id = get_jwt_identity()
    user = User.query.filter_by(id=int(current_user_id)).first()

    if not user:
        return jsonify({"error": "Not Found", "message": "User not found"}), 404

    data = request.get_json(silent=True, force=True) or {}
    errors = []

    if "display_name" in data:
        new_name = data["display_name"].strip()
        if not new_name:
            errors.append("display_name cannot be empty")
        else:
            taken = User.query.filter(
                User.display_name == new_name,
                User.id != user.id
            ).first()
            if taken:
                return jsonify({"error": "Conflict", "message": "Display name already taken"}), 409
            user.display_name = new_name

    if "full_name" in data:
        user.full_name = data["full_name"].strip() or None

    if "user_type" in data:
        raw = data["user_type"].strip().lower() if data["user_type"] else ""
        if raw and raw not in VALID_USER_TYPES:
            errors.append(f"user_type must be one of: {', '.join(sorted(VALID_USER_TYPES))}")
        else:
            user.user_type = raw or None

    # Extended profile fields
    PROFILE_FIELD_LIMITS = {
        "professional_field": 50, "experience_level": 20, "availability": 20,
        "current_level": 30, "major": 100, "reason_for_joining": 50,
    }
    for field, max_len in PROFILE_FIELD_LIMITS.items():
        if field in data:
            val = data[field].strip() if data[field] else None
            if val and len(val) > max_len:
                errors.append(f"{field} exceeds {max_len} characters")
            else:
                setattr(user, field, val)

    if "skills" in data:
        raw_skills = data["skills"]
        if isinstance(raw_skills, list):
            user.skills = [str(s).strip() for s in raw_skills if str(s).strip()]
        elif isinstance(raw_skills, str):
            user.skills = [s.strip() for s in raw_skills.split(",") if s.strip()] or None
        else:
            user.skills = None

    if "looking_for_team" in data:
        user.looking_for_team = data["looking_for_team"]

    if errors:
        return jsonify({"error": "Validation failed", "messages": errors}), 400

    db.session.commit()
    return jsonify({"message": "Profile updated successfully", "user": user.to_dict()}), 200


@users_bp.route("/admin-dashboard", methods=["GET"])
@admin_required
def admin_dashboard():
    """
    Admin-only endpoint — returns list of all users.
    ---
    tags:
      - Admin
    security:
      - Bearer: []
    responses:
      200:
        description: List of all users (admin only)
        schema:
          type: object
          properties:
            users:
              type: array
              items:
                type: object
                properties:
                  id:
                    type: string
                  display_name:
                    type: string
                  email:
                    type: string
                  role:
                    type: string
            total:
              type: integer
      401:
        description: Unauthorized — missing or invalid token
      403:
        description: Forbidden — admin access required
    """
    page = max(1, int(request.args.get("page", 1)))
    per_page = min(int(request.args.get("per_page", 20)), 50)
    pagination = User.query.order_by(User.created_at.desc()).paginate(
        page=page, per_page=per_page, error_out=False
    )
    return jsonify({
        "users": [u.to_dict() for u in pagination.items],
        "total": pagination.total,
        "page": pagination.page,
        "per_page": pagination.per_page,
        "pages": pagination.pages,
    }), 200


# ─── GET /api/users/<id>/profile (public view) ───────────────────────────────

@users_bp.route("/<int:user_id>/profile", methods=["GET"])
@auth_required
def get_public_profile(user_id):
    """
    Get a public profile view of any user by ID.
    Returns profile fields but omits sensitive info (email hidden).
    ---
    tags:
      - Users
    security:
      - Bearer: []
    parameters:
      - in: path
        name: user_id
        type: integer
        required: true
    responses:
      200:
        description: Public profile data
        schema:
          type: object
          properties:
            profile:
              type: object
      404:
        description: User not found
        schema:
          type: object
          properties:
            error:
              type: string
            message:
              type: string
    """
    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "Not Found", "message": "User not found"}), 404

    # Public profile — omit email for privacy
    profile = {
        "id":                 user.id,
        "display_name":       user.display_name,
        "full_name":          user.full_name,
        "user_type":          user.user_type,
        "professional_field": user.professional_field,
        "experience_level":   user.experience_level,
        "availability":       user.availability,
        "skills":             user.skills if user.skills else [],
        "current_level":      user.current_level,
        "major":              user.major,
        "looking_for_team":   user.looking_for_team,
        "member_experience_years": user.member_experience_years,
        "tasks_completed":    user.tasks_completed,
        "quality_score":      round(user.quality_score, 2),
        "attendance_rate":    round(user.attendance_rate, 2),
        "member_on_time_rate": user.member_on_time_rate,
        "created_at":         user.created_at.isoformat() if user.created_at else None,
    }
    return jsonify({"profile": profile}), 200


# ─── GET /api/users/<id>/stats ────────────────────────────────────────────────

@users_bp.route("/<int:user_id>/stats", methods=["GET"])
@auth_required
def get_user_stats(user_id):
    """
    Get aggregated statistics for a user: tasks, ratings, feedback.
    ---
    tags:
      - Users
    security:
      - Bearer: []
    parameters:
      - in: path
        name: user_id
        type: integer
        required: true
    responses:
      200:
        description: User statistics
        schema:
          type: object
          properties:
            user_id:
              type: integer
            tasks:
              type: object
            ratings:
              type: object
            feedback:
              type: object
            performance:
              type: object
      404:
        description: User not found
        schema:
          type: object
          properties:
            error:
              type: string
            message:
              type: string
    """
    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "Not Found", "message": "User not found"}), 404

    from models.rating import Rating
    from models.feedback import Feedback

    # Ratings stats
    ratings = Rating.query.filter_by(ratee_id=user_id).all()
    avg_rating = round(sum(r.score for r in ratings) / len(ratings), 2) if ratings else None

    # Feedback stats
    feedbacks = Feedback.query.filter_by(user_id=user_id).all()
    q_scores  = [f.quality_score  for f in feedbacks if f.quality_score  is not None]
    t_scores  = [f.teamwork_score for f in feedbacks if f.teamwork_score is not None]
    avg_quality  = round(sum(q_scores)  / len(q_scores),  2) if q_scores  else None
    avg_teamwork = round(sum(t_scores)  / len(t_scores),  2) if t_scores  else None

    return jsonify({
        "user_id": user_id,
        "tasks": {
            "total":     len(user.assigned_tasks),
            "completed": user.tasks_completed,
            "overdue":   user.overdue_tasks,
            "active":    user.member_current_tasks,
        },
        "ratings": {
            "total":   len(ratings),
            "average": avg_rating,
        },
        "feedback": {
            "total":         len(feedbacks),
            "avg_quality":   avg_quality,
            "avg_teamwork":  avg_teamwork,
        },
        "performance": {
            "on_time_rate":    user.member_on_time_rate,
            "avg_delay_days":  user.member_avg_delay_days,
            "quality_score":   round(user.quality_score, 2),
            "attendance_rate": round(user.attendance_rate, 2),
            "availability_score": round(user.availability_score, 2),
        },
    }), 200
