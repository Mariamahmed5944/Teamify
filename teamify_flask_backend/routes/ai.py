from flask import Blueprint, request, jsonify
from flask_jwt_extended import get_jwt_identity
from marshmallow import ValidationError
from middleware.auth import auth_required, get_project_role, _READ_ROLES, _WRITE_ROLES
from validators.ai_validator import assign_task_schema, delay_request_schema
from services.ai_service import (
    auto_assign, suggest_priority, suggest_deadline,
    predict_delay, calculate_workload,
)
from services.audit_log_service import log_ai_event
from models import db
from models.task import Task
from models.project import Project

ai_bp = Blueprint("ai", __name__, url_prefix="/api/ai")


def _get_user_id():
    return int(get_jwt_identity())


# ─── POST /api/ai/assign ─────────────────────────────────────────────────────

@ai_bp.route("/assign", methods=["POST"])
@auth_required
def ai_assign():
    """
    Auto-assign the best team member for a task based on workload.
    ---
    tags:
      - AI
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - project_id
          properties:
            project_id:
              type: string
              description: UUID of the project
            task_id:
              type: string
              description: Optional task UUID — if provided, the task will be assigned automatically
            priority:
              type: string
              enum: [low, medium, high]
              default: medium
    responses:
      200:
        description: Suggested assignee returned
        schema:
          type: object
          properties:
            suggested_user_id:
              type: string
            reason:
              type: string
            task_id:
              type: string
            assigned:
              type: boolean
      400:
        description: Validation error
        schema:
          type: object
          properties:
            error:
              type: string
      403:
        description: Forbidden
        schema:
          type: object
          properties:
            error:
              type: string
      404:
        description: Project or task not found
        schema:
          type: object
          properties:
            error:
              type: string
    """
    user_id = _get_user_id()

    # ─── Strict schema validation (Task 2) ──────────────────────────────────────
    try:
        data = assign_task_schema.load(request.get_json(silent=True, force=True) or {})
    except ValidationError as err:
        return jsonify({"error": "Validation failed", "messages": err.messages}), 400

    project_id = data["project_id"]

    project = Project.query.get(project_id)
    if not project:
        return jsonify({"error": "Project not found"}), 404

    role = get_project_role(user_id, project_id)
    if role not in _WRITE_ROLES:
        return jsonify({"error": "Forbidden", "message": "Only project owner or admin can use auto-assign"}), 403

    priority = data.get("priority", "medium")
    assigned_user_id, reason = auto_assign(project_id, priority)

    if not assigned_user_id:
        return jsonify({"error": reason}), 400

    result = {
        "suggested_user_id": str(assigned_user_id),
        "reason": reason,
    }

    # If task_id provided, assign the task immediately
    task_id = data.get("task_id")
    if task_id:
        task = Task.query.get(task_id)
        if not task:
            return jsonify({"error": "Task not found"}), 404
        if task.project_id != project_id:
            return jsonify({"error": "Task does not belong to this project"}), 400

        task.assigned_to = assigned_user_id
        db.session.commit()
        result["task_id"] = str(task_id)
        result["assigned"] = True

    # ─── Structured audit log (Task 3) ─────────────────────────────────────────
    log_ai_event(
        "AUTO_ASSIGN",
        user_id=user_id,
        ip=request.remote_addr or "unknown",
        details={"project_id": project_id, "assigned_to": assigned_user_id},
    )
    return jsonify(result), 200


# ─── POST /api/ai/suggest-priority ───────────────────────────────────────────

@ai_bp.route("/suggest-priority", methods=["POST"])
@auth_required
def ai_suggest_priority():
    """
    Suggest a priority level for a task based on context.
    ---
    tags:
      - AI
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - project_id
          properties:
            project_id:
              type: string
            title:
              type: string
              example: Fix critical login bug
            description:
              type: string
            due_date:
              type: string
              format: date
              example: "2026-04-20"
    responses:
      200:
        description: Suggested priority with reasoning
        schema:
          type: object
          properties:
            suggested_priority:
              type: string
            reasons:
              type: array
              items:
                type: string
      400:
        description: Validation error
        schema:
          type: object
          properties:
            error:
              type: string
      403:
        description: Forbidden
        schema:
          type: object
          properties:
            error:
              type: string
    """
    user_id = _get_user_id()
    data = request.get_json(silent=True, force=True) or {}

    project_id_str = data.get("project_id", "")
    if not project_id_str:
        return jsonify({"error": "project_id is required"}), 400

    try:
        project_id = int(project_id_str)
    except ValueError:
        return jsonify({"error": "Invalid project_id format"}), 400

    role = get_project_role(user_id, project_id)
    if role not in _READ_ROLES:
        return jsonify({"error": "Forbidden", "message": "You are not a member of this project"}), 403

    priority, reasons = suggest_priority(
        project_id,
        title=data.get("title", ""),
        description=data.get("description", ""),
        due_date_str=data.get("due_date"),
    )

    return jsonify({
        "suggested_priority": priority,
        "reasons": reasons,
    }), 200


# ─── POST /api/ai/suggest-deadline ───────────────────────────────────────────

@ai_bp.route("/suggest-deadline", methods=["POST"])
@auth_required
def ai_suggest_deadline():
    """
    Suggest a deadline for a task based on priority and project context.
    ---
    tags:
      - AI
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - project_id
          properties:
            project_id:
              type: string
            priority:
              type: string
              enum: [low, medium, high]
              default: medium
            title:
              type: string
            description:
              type: string
    responses:
      200:
        description: Suggested deadline with reasoning
        schema:
          type: object
          properties:
            suggested_deadline:
              type: string
            reasons:
              type: array
              items:
                type: string
      400:
        description: Validation error
        schema:
          type: object
          properties:
            error:
              type: string
      403:
        description: Forbidden
        schema:
          type: object
          properties:
            error:
              type: string
    """
    user_id = _get_user_id()
    data = request.get_json(silent=True, force=True) or {}

    project_id_str = data.get("project_id", "")
    if not project_id_str:
        return jsonify({"error": "project_id is required"}), 400

    try:
        project_id = int(project_id_str)
    except ValueError:
        return jsonify({"error": "Invalid project_id format"}), 400

    role = get_project_role(user_id, project_id)
    if role not in _READ_ROLES:
        return jsonify({"error": "Forbidden", "message": "You are not a member of this project"}), 403

    suggested_date, reasons = suggest_deadline(
        project_id,
        priority=data.get("priority", "medium"),
        title=data.get("title", ""),
        description=data.get("description", ""),
    )

    return jsonify({
        "suggested_deadline": suggested_date,
        "reasons": reasons,
    }), 200


# ─── POST /api/ai/delay ──────────────────────────────────────────────────────

@ai_bp.route("/delay", methods=["POST"])
@auth_required
def ai_delay():
    """
    Predict delay risk for a project or a specific task.
    ---
    tags:
      - AI
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          properties:
            project_id:
              type: string
              description: UUID of the project (returns project-level prediction)
            task_id:
              type: string
              description: UUID of a task (returns task-level prediction)
    responses:
      200:
        description: Delay prediction with risk level and reasons
        schema:
          type: object
          properties:
            risk_level:
              type: string
            reasons:
              type: array
              items:
                type: string
      400:
        description: Validation error
        schema:
          type: object
          properties:
            error:
              type: string
      403:
        description: Forbidden
        schema:
          type: object
          properties:
            error:
              type: string
    """
    user_id = _get_user_id()

    # ─── Strict schema validation (Task 2) ──────────────────────────────────────
    try:
        data = delay_request_schema.load(request.get_json(silent=True, force=True) or {})
    except ValidationError as err:
        return jsonify({"error": "Validation failed", "messages": err.messages}), 400

    project_id = data.get("project_id")
    task_id = data.get("task_id")

    # Determine project_id for RBAC check
    if task_id:
        task = Task.query.get(task_id)
        if not task:
            return jsonify({"error": "Task not found"}), 404
        project_id = task.project_id
    else:
        if not project_id:
            return jsonify({"error": "project_id is required"}), 400

    role = get_project_role(user_id, project_id)
    if role not in _READ_ROLES:
        return jsonify({"error": "Forbidden", "message": "You are not a member of this project"}), 403

    result = predict_delay(project_id=project_id if not task_id else None, task_id=task_id)

    if "error" in result:
        return jsonify({"error": result["error"]}), 404

    # ─── Structured audit log (Task 3) ─────────────────────────────────────────
    log_ai_event(
        "DELAY_PREDICT",
        user_id=user_id,
        ip=request.remote_addr or "unknown",
        details={"project_id": project_id, "task_id": task_id, "risk_level": result.get("risk_level")},
    )
    return jsonify(result), 200


# ─── GET /api/ai/workload ────────────────────────────────────────────────────

@ai_bp.route("/workload", methods=["GET"])
@auth_required
def ai_workload():
    """
    Get workload for the current user, a specific user, or all users (admin).
    ---
    tags:
      - AI
    security:
      - Bearer: []
    parameters:
      - in: query
        name: user_id
        type: string
        description: UUID of user (admin can query any user; members see own data)
    responses:
      200:
        description: Workload data
        schema:
          type: object
          properties:
            workload:
              type: object
            workloads:
              type: array
              items:
                type: object
      403:
        description: Forbidden
        schema:
          type: object
          properties:
            error:
              type: string
      404:
        description: User not found
        schema:
          type: object
          properties:
            error:
              type: string
    """
    from models.user import User

    current_user_id = _get_user_id()
    target_id_str = request.args.get("user_id")

    current_user = db.session.get(User, current_user_id)
    if not current_user:
        return jsonify({"error": "User not found"}), 404

    # Admin can see all workloads
    if current_user.role == "admin" and not target_id_str:
        result = calculate_workload()
        return jsonify({"workloads": result}), 200

    if target_id_str:
        try:
            target_id = int(target_id_str)
        except ValueError:
            return jsonify({"error": "Invalid user_id format"}), 400

        # Non-admin can only see own workload
        if current_user.role != "admin" and target_id != current_user_id:
            return jsonify({"error": "Forbidden", "message": "You can only view your own workload"}), 403

        result = calculate_workload(target_id)
    else:
        result = calculate_workload(current_user_id)

    if isinstance(result, dict) and "error" in result:
        return jsonify({"error": result["error"]}), 404

    return jsonify({"workload": result}), 200


# ─── GET /api/ai/mentor/recommendations/<user_id> ────────────────────────────

@ai_bp.route("/mentor/recommendations/<int:target_user_id>", methods=["GET"])
@auth_required
def mentor_recommendations(target_user_id: int):
    """
    Get AI career recommendations for a user.
    SECURITY: Only the user themselves or an admin can view.
    ---
    tags:
      - AI
    security:
      - Bearer: []
    parameters:
      - in: path
        name: target_user_id
        type: integer
        required: true
    responses:
      200:
        description: AI career recommendations
        schema:
          type: object
          properties:
            career_summary:
              type: string
            next_steps:
              type: array
              items:
                type: string
            career_path_percentage:
              type: number
      403:
        description: Not authorized to view another user's recommendations
      404:
        description: User not found
    """
    from models.user import User

    current_user_id = _get_user_id()
    current_user = db.session.get(User, current_user_id)
    if not current_user:
        return jsonify({"error": "User not found"}), 404

    # SECURITY: ownership check — members can only see their own mentor data
    if current_user.role != "admin" and current_user_id != target_user_id:
        return jsonify({"error": "Forbidden", "detail": "You are not authorized to view this user's recommendations"}), 403

    target_user = db.session.get(User, target_user_id)
    if not target_user:
        return jsonify({"error": "User not found"}), 404

    # Build recommendations from user profile data
    skills = target_user.skills or []
    completed = target_user.tasks_completed
    total_tasks = len(target_user.assigned_tasks) if target_user.assigned_tasks else 0
    career_pct = min(100, int((completed / max(total_tasks, 1)) * 100))

    next_steps = []
    if target_user.experience_level in (None, "Beginner"):
        next_steps.append("Complete 5 projects to build your portfolio.")
        next_steps.append("Consider learning a backend framework (Flask, Django).")
    elif target_user.experience_level == "Intermediate":
        next_steps.append("Start leading a project to develop management skills.")
        next_steps.append("Contribute to open-source to expand your network.")
    else:
        next_steps.append("Mentor junior team members to solidify expertise.")
        next_steps.append("Explore system design and architecture certifications.")

    if len(skills) < 3:
        next_steps.append("Add more skills to your profile to improve matching.")

    career_summary = (
        f"{target_user.display_name} has completed {completed} tasks with a "
        f"quality score of {target_user.quality_score:.0%}. "
        f"Current focus: {target_user.professional_field or 'not specified'}."
    )

    log_ai_event(
        "MENTOR_RECOMMENDATIONS",
        user_id=current_user_id,
        ip=request.remote_addr or "unknown",
        details={"target_user_id": target_user_id},
    )

    return jsonify({
        "career_summary": career_summary,
        "next_steps": next_steps,
        "career_path_percentage": career_pct,
    }), 200


# ─── GET /api/ai/mentor/performance/<user_id> ────────────────────────────────

@ai_bp.route("/mentor/performance/<int:target_user_id>", methods=["GET"])
@auth_required
def mentor_performance(target_user_id: int):
    """
    Get AI performance analysis for a user.
    SECURITY: Only the user themselves or an admin can view.
    ---
    tags:
      - AI
    security:
      - Bearer: []
    parameters:
      - in: path
        name: target_user_id
        type: integer
        required: true
    responses:
      200:
        description: Performance scores and AI tip
        schema:
          type: object
          properties:
            scores:
              type: object
            overall:
              type: number
            ai_tip:
              type: string
            trend:
              type: string
      403:
        description: Not authorized
      404:
        description: User not found
    """
    from models.user import User

    current_user_id = _get_user_id()
    current_user = db.session.get(User, current_user_id)
    if not current_user:
        return jsonify({"error": "User not found"}), 404

    if current_user.role != "admin" and current_user_id != target_user_id:
        return jsonify({"error": "Forbidden", "detail": "You are not authorized to view this user's performance"}), 403

    target_user = db.session.get(User, target_user_id)
    if not target_user:
        return jsonify({"error": "User not found"}), 404

    on_time      = target_user.member_on_time_rate
    quality      = target_user.quality_score
    availability = target_user.availability_score
    attendance   = target_user.attendance_rate
    overall      = round((on_time + quality + availability + attendance) / 4, 2)

    # Determine trend from on-time rate
    if on_time >= 0.8:
        trend = "improving"
    elif on_time >= 0.5:
        trend = "stable"
    else:
        trend = "declining"

    # AI tip based on weakest metric
    scores_map = {
        "on_time": on_time,
        "quality": quality,
        "availability": availability,
        "attendance": attendance,
    }
    weakest = min(scores_map, key=scores_map.get)
    tips = {
        "on_time":      "Focus on breaking tasks into smaller milestones to improve delivery rate.",
        "quality":      "Request code reviews from senior team members to boost quality scores.",
        "availability": "Consider delegating or declining low-priority tasks to free capacity.",
        "attendance":   "Set calendar reminders 15 minutes before meetings to improve attendance.",
    }

    return jsonify({
        "scores": scores_map,
        "overall": overall,
        "ai_tip": tips[weakest],
        "trend": trend,
    }), 200


# ─── GET /api/ai/mentor/courses/<user_id> ─────────────────────────────────────

@ai_bp.route("/mentor/courses/<int:target_user_id>", methods=["GET"])
@auth_required
def mentor_courses(target_user_id: int):
    """
    Get AI-recommended courses for a user based on their skill gaps.
    SECURITY: Only the user themselves or an admin can view.
    ---
    tags:
      - AI
    security:
      - Bearer: []
    parameters:
      - in: path
        name: target_user_id
        type: integer
        required: true
    responses:
      200:
        description: List of recommended courses
        schema:
          type: object
          properties:
            recommended_courses:
              type: array
              items:
                type: object
                properties:
                  title:
                    type: string
                  provider:
                    type: string
                  reason:
                    type: string
                  url:
                    type: string
      403:
        description: Not authorized
      404:
        description: User not found
    """
    from models.user import User

    current_user_id = _get_user_id()
    current_user = db.session.get(User, current_user_id)
    if not current_user:
        return jsonify({"error": "User not found"}), 404

    if current_user.role != "admin" and current_user_id != target_user_id:
        return jsonify({"error": "Forbidden", "detail": "You are not authorized to view this user's courses"}), 403

    target_user = db.session.get(User, target_user_id)
    if not target_user:
        return jsonify({"error": "User not found"}), 404

    skills = {s.lower() for s in (target_user.skills or [])}

    # Course catalogue — recommend courses for skills the user lacks
    course_catalogue = [
        {"title": "Docker & Kubernetes Masterclass",      "provider": "Udemy",    "skill": "docker",      "url": "https://udemy.com/docker-kubernetes"},
        {"title": "AWS Certified Solutions Architect",     "provider": "Coursera", "skill": "aws",         "url": "https://coursera.org/aws-architect"},
        {"title": "React - The Complete Guide",            "provider": "Udemy",    "skill": "react",       "url": "https://udemy.com/react-complete"},
        {"title": "Machine Learning Specialization",       "provider": "Coursera", "skill": "machine learning", "url": "https://coursera.org/ml-spec"},
        {"title": "System Design for Interviews",          "provider": "Educative","skill": "system design","url": "https://educative.io/system-design"},
        {"title": "Flask Mega-Tutorial",                   "provider": "Blog",     "skill": "flask",       "url": "https://blog.miguelgrinberg.com/post/the-flask-mega-tutorial"},
        {"title": "PostgreSQL Performance Tuning",         "provider": "Pluralsight","skill": "postgresql", "url": "https://pluralsight.com/pg-perf"},
        {"title": "Git & GitHub Crash Course",             "provider": "YouTube",  "skill": "git",         "url": "https://youtube.com/git-crash"},
        {"title": "Python Testing with pytest",            "provider": "Pragmatic","skill": "pytest",      "url": "https://pragprog.com/pytest"},
        {"title": "Leadership & Team Management",          "provider": "LinkedIn", "skill": "leadership",  "url": "https://linkedin.com/learning/leadership"},
    ]

    recommended = []
    for course in course_catalogue:
        if course["skill"] not in skills:
            recommended.append({
                "title":    course["title"],
                "provider": course["provider"],
                "reason":   f"You don't have '{course['skill']}' in your profile yet.",
                "url":      course["url"],
            })

    # Cap at 5 recommendations
    recommended = recommended[:5]

    log_ai_event(
        "MENTOR_COURSES",
        user_id=current_user_id,
        ip=request.remote_addr or "unknown",
        details={"target_user_id": target_user_id, "courses_count": len(recommended)},
    )

    return jsonify({"recommended_courses": recommended}), 200

