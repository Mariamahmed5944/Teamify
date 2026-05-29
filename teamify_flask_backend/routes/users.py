from flask import Blueprint, request, jsonify
from flask_jwt_extended import get_jwt_identity
from middleware.auth import auth_required, admin_required
from models import db
from models.user import User
from sqlalchemy import or_
import re

users_bp = Blueprint("users", __name__, url_prefix="/api/users")

EMAIL_RE = re.compile(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
VALID_USER_TYPES = {"freelancer", "student", "admin"}


# ─── GET /api/users/available-members ────────────────────────────────────────
# Registered before /<int:user_id> routes so Flask never mis-matches the path.

@users_bp.route("/available-members", methods=["GET"])
@auth_required
def get_available_members():
    """
    Return all approved, non-guest users suitable for project member assignment.
    Excludes the calling user by default (they will be the project owner).
    """
    current_user_id = int(get_jwt_identity())
    search = request.args.get("search", "").strip()
    exclude_self = request.args.get("exclude_self", "true").lower() != "false"

    q = User.query.filter(User.role != "guest")

    if exclude_self:
        q = q.filter(User.id != current_user_id)

    if search:
        q = q.filter(
            or_(
                User.full_name.ilike(f"%{search}%"),
                User.display_name.ilike(f"%{search}%"),
                User.email.ilike(f"%{search}%"),
            )
        )

    users = q.order_by(User.full_name, User.display_name).all()

    return jsonify({
        "users": [
            {
                "id": u.id,
                "name": u.full_name or u.display_name,
                "display_name": u.display_name,
                "email": u.email,
                "user_type": u.user_type,
            }
            for u in users
        ],
        "total": len(users),
    }), 200


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

    if "email" in data:
        new_email = (data["email"] or "").strip().lower()
        if new_email and new_email != user.email:
            taken = User.query.filter(
                User.email == new_email,
                User.id != user.id,
            ).first()
            if taken:
                return jsonify({"error": "Conflict", "message": "Email already in use"}), 409
            user.email = new_email

    if "phone" in data:
        phone = (data["phone"] or "").strip()
        if phone and len(phone) > 30:
            errors.append("phone exceeds 30 characters")
        else:
            user.phone = phone or None

    if "bio" in data:
        bio = (data["bio"] or "").strip()
        if bio and len(bio) > 2000:
            errors.append("bio exceeds 2000 characters")
        else:
            user.bio = bio or None

    if "avatar_file_id" in data:
        from models.file_metadata import FileMetadata

        raw_id = data["avatar_file_id"]
        if raw_id is None or raw_id == "":
            user.avatar_file_id = None
        else:
            try:
                file_id = int(raw_id)
            except (TypeError, ValueError):
                errors.append("avatar_file_id must be an integer")
            else:
                meta = db.session.get(FileMetadata, file_id)
                if not meta or meta.owner_id != user.id:
                    errors.append("avatar_file_id is invalid or not owned by you")
                else:
                    user.avatar_file_id = file_id

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
        "role":               user.role,
        "professional_field": user.professional_field,
        "experience_level":   user.experience_level,
        "availability":       user.availability,
        "skills":             user.skills if user.skills else [],
        "bio":                user.bio,
        "current_level":      user.current_level,
        "major":              user.major,
        "looking_for_team":   user.looking_for_team,
        "reason_for_joining": user.reason_for_joining,
        "member_experience_years": user.member_experience_years,
        "tasks_completed":    user.tasks_completed,
        "quality_score":      round(user.quality_score, 2),
        "attendance_rate":    round(user.attendance_rate, 2),
        "member_on_time_rate": user.member_on_time_rate,
        "avatar_file_id":     user.avatar_file_id,
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

    from datetime import date
    from models.project import Project
    from models.project_member import ProjectMember
    from models.task import Task
    from models.rating import Rating
    from models.feedback import Feedback

    # Accessible projects (owned + membership), same logic as dashboard
    if user.role == "admin":
        project_ids = [p.id for p in Project.query.all()]
    else:
        owned = [p.id for p in Project.query.filter_by(user_id=user_id).all()]
        member_of = [
            pm.project_id
            for pm in ProjectMember.query.filter_by(user_id=user_id).all()
        ]
        project_ids = list(set(owned + member_of))

    assigned = Task.query.filter_by(assigned_to=user_id).all()
    tasks_completed = sum(
        1 for t in assigned if (t.status or "").lower() in {"done", "completed"}
    )
    tasks_active = sum(1 for t in assigned if t.status != "done")
    today = date.today()
    tasks_overdue = sum(
        1
        for t in assigned
        if t.status != "done"
        and t.due_date is not None
        and t.due_date < today
    )

    # Ratings stats
    ratings = Rating.query.filter_by(ratee_id=user_id).all()
    avg_rating = round(sum(r.score for r in ratings) / len(ratings), 2) if ratings else None

    # Feedback stats
    feedbacks = Feedback.query.filter_by(user_id=user_id).all()
    q_scores  = [f.quality_score  for f in feedbacks if f.quality_score  is not None]
    t_scores  = [f.teamwork_score for f in feedbacks if f.teamwork_score is not None]
    avg_quality  = round(sum(q_scores)  / len(q_scores),  2) if q_scores  else None
    avg_teamwork = round(sum(t_scores)  / len(t_scores),  2) if t_scores  else None

    quality_norm = round(user.quality_score, 2)
    on_time_pct = round((user.member_on_time_rate or 0) * 100)
    commitment = on_time_pct
    teamwork = round((avg_teamwork or 0) * 20) if avg_teamwork else on_time_pct
    quality = round(quality_norm * 100) if quality_norm else (
        round((avg_quality or 0) * 20) if avg_quality else 0
    )

    if avg_rating is not None:
        career_score = avg_rating
    elif quality_norm:
        career_score = round(quality_norm * 5, 1)
    elif assigned:
        career_score = round((tasks_completed / len(assigned)) * 5, 1)
    else:
        career_score = round((user.member_on_time_rate or 0) * 5, 1)

    if user.availability:
        location = user.availability
    elif user.major:
        location = user.major
    else:
        location = "Remote"

    joined = "Member"
    if user.created_at:
        joined = f"Member since {user.created_at.strftime('%b %Y')}"

    role_title = user.professional_field or (
        user.major if user.user_type == "student" else None
    )
    if not role_title:
        role_title = {
            "student": "Student Developer",
            "freelancer": "Freelance Developer",
            "admin": "System Administrator",
        }.get(user.user_type or "", "Member")

    return jsonify({
        "user_id": user_id,
        "tasks": {
            "total":     len(assigned),
            "completed": tasks_completed,
            "overdue":   tasks_overdue,
            "active":    tasks_active,
        },
        "projects": {
            "accessible_count": len(project_ids),
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
            "quality_score":   quality_norm,
            "attendance_rate": round(user.attendance_rate, 2),
            "availability_score": round(user.availability_score, 2),
        },
        "summary": {
            "projects": len(project_ids),
            "completed_projects": len(project_ids),
            "tasks_done": tasks_completed,
            "completed_tasks": tasks_completed,
            "score": career_score,
            "rating": avg_rating if avg_rating is not None else career_score,
            "location": location,
            "joined": joined,
            "role_title": role_title,
            "commitment": commitment,
            "teamwork": teamwork,
            "quality": quality,
        },
    }), 200
