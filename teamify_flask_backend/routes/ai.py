"""
AI Routes — Flask Blueprint
Endpoints:
  GET  /api/ai/predict-delay/<task_id>
  POST /api/ai/classify-task
  POST /api/ai/assign-members
  POST /api/ai/summarize-chat
  POST /api/ai/transcribe
  GET  /api/ai/mentor-report/<user_id>
  GET  /api/ai/predict-rating/<user_id>
  POST /api/ai/recommend-teammates
"""
import os
import logging

import requests
from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import get_jwt_identity
from middleware.auth import auth_required

from services.delay_predictor_service import predict_task_delay
from services.task_pipeline_service import classify_task, assign_best_members
from services.chat_summarization_service import summarize_chat
from services.ai_mentor_service import generate_mentor_report
from services.profile_rating_service import predict_user_rating, recommend_teammates
from services.anomaly_service_ml import detect_anomaly
from services.cv_builder_service import build_cv_for_user
from services.ai_service import (
    auto_assign,
    suggest_priority,
    suggest_deadline,
    predict_delay,
    calculate_workload,
)

# Models and auth — imported at module level so @patch("routes.ai.X") works in tests
from models.project import Project
from models.task import Task
from models import db
from middleware.auth import get_project_role

# Marshmallow validation (reused from existing validators)
from marshmallow import Schema, fields, validates, ValidationError
from validators.cv_validator import cv_build_schema

logger = logging.getLogger(__name__)
ai_bp = Blueprint("ai", __name__, url_prefix="/api/ai")


# ─── Predict Task Delay ───────────────────────────────────────────────────────

@ai_bp.route("/predict-delay/<int:task_id>", methods=["GET"])
@auth_required
def api_predict_delay(task_id):
    """
    Predict if a specific task will be delayed.
    ---
    tags:
      - AI
    security:
      - Bearer: []
    parameters:
      - in: path
        name: task_id
        type: integer
        required: true
    responses:
      200:
        description: Delay prediction result
      404:
        description: Task not found
    """
    from models.task import Task
    from models.user import User
    from models import db

    task = db.session.get(Task, task_id)
    if not task:
        return jsonify({"error": "Task not found"}), 404

    task_data = {
        "estimated_duration_days": task.estimated_duration_days or 5,
        "progress_percent": task.progress_percent or 0,
        "priority_level": task.priority_level or 2,
        "complexity_level": task.complexity_level or 3,
        "num_subtasks": task.num_subtasks or 0,
        "days_since_start": task.days_since_start or 0,
        "days_remaining": task.days_remaining or 0,
        "expected_progress_percent": task.expected_progress_percent or 0,
        "progress_gap": task.progress_gap or 0,
    }

    user_data = {}
    if task.assigned_to:
        user = db.session.get(User, task.assigned_to)
        if user:
            user_data = {
                "experience_years": getattr(user, "experience_years", 2),
                "on_time_rate": 0.9,
                "avg_delay_days": 0,
                "max_allowed_tasks": 5,
                "current_tasks": 1,
                "projects_completed": getattr(user, "projects_completed", 1),
                "technical_skill": 3,
                "communication_skill": 3,
            }

    result = predict_task_delay(task_data, user_data)
    # Store delay risk back on the task
    task.ai_delay_risk = result.get("risk_level")
    from models import db
    db.session.commit()

    return jsonify({"task_id": task_id, **result}), 200


# ─── Classify Task ────────────────────────────────────────────────────────────

@ai_bp.route("/classify-task", methods=["POST"])
@auth_required
def api_classify_task():
    """
    Classify a task by text → category, difficulty, required skills.
    ---
    tags:
      - AI
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        schema:
          type: object
          required: [text]
          properties:
            text:
              type: string
    responses:
      200:
        description: Classification result
      400:
        description: Missing text
    """
    data = request.get_json(silent=True) or {}
    text = data.get("text", "").strip()
    if not text:
        return jsonify({"error": "text field is required"}), 400

    result = classify_task(text)
    return jsonify(result), 200


# ─── Assign Members ───────────────────────────────────────────────────────────

@ai_bp.route("/assign-members", methods=["POST"])
@auth_required
def api_assign_members():
    """
    Rank members for a task using domain matching and workload score.
    ---
    tags:
      - AI
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        schema:
          type: object
          properties:
            task_info:
              type: object
            members:
              type: array
    responses:
      200:
        description: Ranked member assignments
    """
    data = request.get_json(silent=True) or {}
    task_info = data.get("task_info", {})
    members_list = data.get("members", [])

    assignments = assign_best_members(task_info, members_list)
    return jsonify({"assignments": assignments}), 200


# ─── Summarize Chat ───────────────────────────────────────────────────────────

@ai_bp.route("/summarize-chat", methods=["POST"])
@auth_required
def api_summarize_chat():
    """
    Summarize a chat conversation and extract action items.
    ---
    tags:
      - AI
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        schema:
          type: object
          required: [chat_text]
          properties:
            chat_text:
              type: string
    responses:
      200:
        description: Chat summary
      400:
        description: Missing chat_text
    """
    data = request.get_json(silent=True) or {}
    chat_text = data.get("chat_text", "").strip()
    if not chat_text:
        return jsonify({"error": "chat_text is required"}), 400

    result = summarize_chat(chat_text)
    return jsonify(result), 200


# ─── Transcribe Audio (proxy to FastAPI STT) ──────────────────────────────────

@ai_bp.route("/transcribe", methods=["POST"])
@auth_required
def api_transcribe():
    """
    Forward an audio file to the Speech-to-Text microservice.
    ---
    tags:
      - AI
    security:
      - Bearer: []
    consumes:
      - multipart/form-data
    parameters:
      - in: formData
        name: audio
        type: file
        required: true
    responses:
      200:
        description: Transcribed text
      400:
        description: No audio file provided
      502:
        description: STT service unavailable
    """
    audio_file = request.files.get("audio")
    if not audio_file:
        return jsonify({"error": "No audio file provided"}), 400

    stt_url = os.getenv("STT_SERVICE_URL", "http://localhost:8000") + "/transcribe"
    try:
        resp = requests.post(
            stt_url,
            files={"file": (audio_file.filename, audio_file.stream, audio_file.mimetype)},
            timeout=30
        )
        return jsonify(resp.json()), resp.status_code
    except requests.exceptions.ConnectionError:
        return jsonify({"error": "STT microservice is not running. Start it with: uvicorn app:app --port 8000"}), 502
    except requests.exceptions.Timeout:
        return jsonify({"error": "STT service timed out"}), 504
    except Exception as exc:
        logger.error(f"[AI/transcribe] Unexpected error: {exc}")
        return jsonify({"error": str(exc)}), 500


# ─── Mentor Report ────────────────────────────────────────────────────────────

@ai_bp.route("/mentor-report/<int:user_id>", methods=["GET"])
@auth_required
def api_mentor_report(user_id):
    """
    Generate an AI career progression and mentoring report for a user.
    ---
    tags:
      - AI
    security:
      - Bearer: []
    parameters:
      - in: path
        name: user_id
        type: integer
        required: true
    responses:
      200:
        description: Mentor report
    """
    result = generate_mentor_report(user_id)
    return jsonify(result), 200


# ─── Predict User Rating ──────────────────────────────────────────────────────

@ai_bp.route("/predict-rating/<int:user_id>", methods=["GET"])
@auth_required
def api_predict_rating(user_id):
    """
    Predict a user's AI performance rating.
    ---
    tags:
      - AI
    security:
      - Bearer: []
    parameters:
      - in: path
        name: user_id
        type: integer
        required: true
    responses:
      200:
        description: Predicted rating
    """
    from models.user import User
    from models import db

    user = db.session.get(User, user_id)
    if not user:
        return jsonify({"error": "User not found"}), 404

    def _safe(attr, default):
        """Return scalar attribute value; fall back to default for methods/None."""
        val = getattr(user, attr, default)
        return default if callable(val) or val is None else val

    # Build stats from the user model — fill defaults for missing/method fields
    user_stats = {
        "tasks_assigned":   _safe("tasks_assigned",   10),
        "tasks_completed":  _safe("tasks_completed",   7),
        "overdue_tasks":    _safe("overdue_tasks",      1),
        "quality_score":    _safe("quality_score",    3.5),
        "teamwork_score":   _safe("teamwork_score",   3.5),
        "attendance_rate":  _safe("attendance_rate",  0.9),
        "skill_match_score":_safe("skill_match_score",0.7),
        "avg_rating":       _safe("avg_rating",       3.5),
        "availability_score":_safe("availability_score",0.8),
        "project_similarity":_safe("project_similarity",0.6),
    }

    rating_result = predict_user_rating(user_stats)
    teammates = recommend_teammates(user_stats, top_n=3)

    return jsonify({
        "user_id": user_id,
        **rating_result,
        "teammate_recommendations": teammates
    }), 200


# ─── Recommend Teammates ──────────────────────────────────────────────────────

@ai_bp.route("/recommend-teammates", methods=["POST"])
@auth_required
def api_recommend_teammates():
    """
    Find the most compatible teammates based on user stats.
    ---
    tags:
      - AI
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        schema:
          type: object
          properties:
            user_stats:
              type: object
            top_n:
              type: integer
              default: 5
    responses:
      200:
        description: Recommended teammates
    """
    data = request.get_json(silent=True) or {}
    user_stats = data.get("user_stats", {})
    top_n = int(data.get("top_n", 5))

    teammates = recommend_teammates(user_stats, top_n=top_n)
    return jsonify({"recommendations": teammates}), 200


# ─── Detect Login Anomaly (internal) ─────────────────────────────────────────

@ai_bp.route("/detect-anomaly", methods=["POST"])
@auth_required
def api_detect_anomaly():
    """
    Run the Isolation Forest anomaly detector on a login event.
    ---
    tags:
      - AI
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        schema:
          type: object
          properties:
            user_id:
              type: integer
            failed_attempts:
              type: integer
    responses:
      200:
        description: Anomaly detection result
    """
    data = request.get_json(silent=True) or {}
    result = detect_anomaly(data)
    return jsonify(result), 200


# ─── Helper ──────────────────────────────────────────────────────────────────

def _extract_section(text: str, heading: str) -> str:
    """Extract the text body of a markdown section identified by *heading*."""
    lines = text.split("\n")
    in_section = False
    result: list = []
    for line in lines:
        if line.strip().startswith(heading):
            in_section = True
            continue
        if in_section:
            if line.strip().startswith("##"):
                break
            result.append(line)
    return "\n".join(result).strip()


# ─── POST /api/ai/assign ──────────────────────────────────────────────────────

@ai_bp.route("/assign", methods=["POST"])
@auth_required
def api_assign():
    """
    Auto-assign the best available project member for a new task.
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
          required: [project_id]
          properties:
            project_id:
              type: string
    responses:
      200:
        description: Suggested user
      400:
        description: Missing project_id
      403:
        description: Not a project owner or admin
      404:
        description: Project not found
    """
    current_user_id = int(get_jwt_identity())
    data = request.get_json(silent=True) or {}
    project_id = data.get("project_id")
    if not project_id:
        return jsonify({"error": "project_id is required"}), 400

    project = Project.query.get(int(project_id))
    if not project:
        return jsonify({"error": "Project not found"}), 404

    role = get_project_role(current_user_id, int(project_id))
    if role not in ("owner", "admin"):
        return jsonify({"error": "Only project owners or admins can auto-assign members"}), 403

    suggested_user_id, reason = auto_assign(int(project_id))
    return jsonify({"suggested_user_id": suggested_user_id, "reason": reason}), 200


# ─── POST /api/ai/suggest-priority ───────────────────────────────────────────

@ai_bp.route("/suggest-priority", methods=["POST"])
@auth_required
def api_suggest_priority():
    """
    Suggest a task priority based on project context and keywords.
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
          required: [project_id]
          properties:
            project_id:
              type: string
            title:
              type: string
            description:
              type: string
            due_date:
              type: string
    responses:
      200:
        description: Suggested priority and reasons
      400:
        description: Missing project_id
      403:
        description: Not a project member
    """
    current_user_id = int(get_jwt_identity())
    data = request.get_json(silent=True) or {}
    project_id = data.get("project_id")
    if not project_id:
        return jsonify({"error": "project_id is required"}), 400

    role = get_project_role(current_user_id, int(project_id))
    if not role:
        return jsonify({"error": "Not a project member"}), 403

    priority_val, reasons = suggest_priority(
        int(project_id),
        title=data.get("title", ""),
        description=data.get("description", ""),
        due_date_str=data.get("due_date"),
    )
    return jsonify({"priority": priority_val, "reasons": reasons}), 200


# ─── POST /api/ai/suggest-deadline ───────────────────────────────────────────

@ai_bp.route("/suggest-deadline", methods=["POST"])
@auth_required
def api_suggest_deadline():
    """
    Suggest a task deadline based on priority and project history.
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
          required: [project_id]
          properties:
            project_id:
              type: string
            priority:
              type: string
            title:
              type: string
            description:
              type: string
    responses:
      200:
        description: Suggested deadline date and reasons
      400:
        description: Missing project_id
      403:
        description: Not a project member
    """
    current_user_id = int(get_jwt_identity())
    data = request.get_json(silent=True) or {}
    project_id = data.get("project_id")
    if not project_id:
        return jsonify({"error": "project_id is required"}), 400

    role = get_project_role(current_user_id, int(project_id))
    if not role:
        return jsonify({"error": "Not a project member"}), 403

    suggested_date, reasons = suggest_deadline(
        int(project_id),
        priority=data.get("priority", "medium"),
        title=data.get("title", ""),
        description=data.get("description", ""),
    )
    return jsonify({"suggested_date": suggested_date, "reasons": reasons}), 200


# ─── POST /api/ai/delay ───────────────────────────────────────────────────────

@ai_bp.route("/delay", methods=["POST"])
@auth_required
def api_delay():
    """
    Predict delay risk for a task or an entire project.
    ---
    tags:
      - AI
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        schema:
          type: object
          properties:
            task_id:
              type: string
            project_id:
              type: string
    responses:
      200:
        description: Delay risk result
      400:
        description: Missing task_id and project_id
      403:
        description: Not a project member
      404:
        description: Task not found
    """
    current_user_id = int(get_jwt_identity())
    data = request.get_json(silent=True) or {}
    task_id = data.get("task_id")
    project_id = data.get("project_id")

    if not task_id and not project_id:
        return jsonify({"error": "task_id or project_id is required"}), 400

    if task_id:
        task = Task.query.get(int(task_id))
        if not task:
            return jsonify({"error": "Task not found"}), 404
        role = get_project_role(current_user_id, task.project_id)
        if not role:
            return jsonify({"error": "Not a project member"}), 403
        result = predict_delay(task_id=int(task_id))
    else:
        role = get_project_role(current_user_id, int(project_id))
        if not role:
            return jsonify({"error": "Not a project member"}), 403
        result = predict_delay(project_id=int(project_id))

    return jsonify(result), 200


# ─── GET /api/ai/workload ─────────────────────────────────────────────────────

@ai_bp.route("/workload", methods=["GET"])
@auth_required
def api_workload():
    """
    Get workload details for a user (defaults to the caller).
    Admins may query any user via ?user_id=<id>.
    ---
    tags:
      - AI
    security:
      - Bearer: []
    parameters:
      - in: query
        name: user_id
        type: integer
    responses:
      200:
        description: Workload summary
      403:
        description: Non-admin requesting another user's workload
    """
    from models.user import User
    current_user_id = int(get_jwt_identity())
    user_id = request.args.get("user_id", type=int)

    if user_id and user_id != current_user_id:
        caller = db.session.get(User, current_user_id)
        if not caller or caller.role != "admin":
            return jsonify({"error": "Forbidden"}), 403

    target_id = user_id or current_user_id
    result = calculate_workload(target_id)
    return jsonify(result), 200


# ─── GET /api/ai/mentor/recommendations/<user_id> ────────────────────────────

@ai_bp.route("/mentor/recommendations/<int:user_id>", methods=["GET"])
@auth_required
def api_mentor_recommendations(user_id: int):
    """
    Career recommendations and next steps for a user.
    Only the user themselves or an admin may access.
    ---
    tags:
      - AI
    security:
      - Bearer: []
    parameters:
      - in: path
        name: user_id
        type: integer
        required: true
    responses:
      200:
        description: Career summary, next steps, career path percentage
      403:
        description: Forbidden
      404:
        description: User not found
    """
    from models.user import User
    current_user_id = int(get_jwt_identity())
    current_user = db.session.get(User, current_user_id)
    if not current_user:
        return jsonify({"error": "User not found"}), 404
    if current_user.role != "admin" and current_user_id != user_id:
        return jsonify({"error": "Forbidden"}), 403

    report = generate_mentor_report(user_id)
    if "error" in report:
        return jsonify(report), 404

    mentor_text = report.get("mentor_report", "")
    career_summary = _extract_section(mentor_text, "## Career Summary") or mentor_text[:250]
    gaps = report.get("skill_gaps", {})

    return jsonify({
        "career_summary": career_summary,
        "next_steps": gaps.get("missing_skills", [])[:3],
        "career_path_percentage": report.get("career_progress", {}).get("score", 0),
    }), 200


# ─── GET /api/ai/mentor/performance/<user_id> ────────────────────────────────

@ai_bp.route("/mentor/performance/<int:user_id>", methods=["GET"])
@auth_required
def api_mentor_performance(user_id: int):
    """
    Performance scores and AI coaching tip for a user.
    Only the user themselves or an admin may access.
    ---
    tags:
      - AI
    security:
      - Bearer: []
    parameters:
      - in: path
        name: user_id
        type: integer
        required: true
    responses:
      200:
        description: Scores, overall rating, AI tip, trend
      403:
        description: Forbidden
      404:
        description: User not found
    """
    from models.user import User
    current_user_id = int(get_jwt_identity())
    current_user = db.session.get(User, current_user_id)
    if not current_user:
        return jsonify({"error": "User not found"}), 404
    if current_user.role != "admin" and current_user_id != user_id:
        return jsonify({"error": "Forbidden"}), 403

    report = generate_mentor_report(user_id)
    if "error" in report:
        return jsonify(report), 404

    progress = report.get("career_progress", {})
    weaknesses = report.get("weaknesses", [])
    ai_tip = (
        weaknesses[0]["message"]
        if weaknesses
        else "Keep up the great work — no critical issues detected."
    )

    return jsonify({
        "scores": progress.get("breakdown", {}),
        "overall": progress.get("score", 0),
        "ai_tip": ai_tip,
        "trend": "stable",
    }), 200


# ─── GET /api/ai/mentor/courses/<user_id> ────────────────────────────────────

@ai_bp.route("/mentor/courses/<int:user_id>", methods=["GET"])
@auth_required
def api_mentor_courses(user_id: int):
    """
    Recommended learning courses tailored to a user's skill gaps.
    Only the user themselves or an admin may access.
    ---
    tags:
      - AI
    security:
      - Bearer: []
    parameters:
      - in: path
        name: user_id
        type: integer
        required: true
    responses:
      200:
        description: List of recommended courses
      403:
        description: Forbidden
      404:
        description: User not found
    """
    from models.user import User
    current_user_id = int(get_jwt_identity())
    current_user = db.session.get(User, current_user_id)
    if not current_user:
        return jsonify({"error": "User not found"}), 404
    if current_user.role != "admin" and current_user_id != user_id:
        return jsonify({"error": "Forbidden"}), 403

    report = generate_mentor_report(user_id)
    if "error" in report:
        return jsonify(report), 404

    return jsonify({"recommended_courses": report.get("top_courses", [])}), 200


# ─── POST /api/ai/chat/summarize ─────────────────────────────────────────────

@ai_bp.route("/chat/summarize", methods=["POST"])
@auth_required
def api_chat_summarize():
    """
    Summarize a chat transcript and extract action items.
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
          required: [text]
          properties:
            text:
              type: string
              description: 'Raw chat/meeting transcript in "Name: message" format'
            top_n:
              type: integer
              default: 3
              description: Number of key sentences to extract
    responses:
      200:
        description: Summarized result
        schema:
          type: object
          properties:
            participants:
              type: array
              items:
                type: string
            key_points:
              type: array
              items:
                type: string
            action_items:
              type: array
              items:
                type: object
            word_count:
              type: integer
            source:
              type: string
      400:
        description: Missing or empty text
    """
    data = request.get_json(silent=True, force=True) or {}
    text = data.get("text", "").strip()
    if not text:
        # also accept legacy field name used by /summarize-chat
        text = data.get("chat_text", "").strip()
    if not text:
        return jsonify({"error": "text field is required"}), 400

    top_n = int(data.get("top_n", 3))
    result = summarize_chat(text, top_n=top_n)
    return jsonify(result), 200


# ─── GET /api/ai/mentor/analyse/<user_id> ────────────────────────────────────

@ai_bp.route("/mentor/analyse/<int:target_user_id>", methods=["GET"])
@auth_required
def api_mentor_analyse(target_user_id: int):
    """
    Full AI mentor analysis — career score, weaknesses, skill gaps, and
    course recommendations for a user.
    SECURITY: only the user themselves or an admin can view.
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
        description: Full mentor analysis
        schema:
          type: object
          properties:
            user_id:
              type: integer
            career_progress:
              type: object
            weaknesses:
              type: array
              items:
                type: object
            strengths:
              type: array
              items:
                type: object
            skill_gaps:
              type: object
            top_courses:
              type: array
              items:
                type: object
            mentor_report:
              type: string
      403:
        description: Forbidden
      404:
        description: User not found
    """
    from flask_jwt_extended import get_jwt_identity
    from models import db
    from models.user import User

    current_user_id = int(get_jwt_identity())
    current_user = db.session.get(User, current_user_id)
    if not current_user:
        return jsonify({"error": "User not found"}), 404

    if current_user.role != "admin" and current_user_id != target_user_id:
        return jsonify({
            "error": "Forbidden",
            "detail": "You are not authorized to view this user's analysis",
        }), 403

    result = generate_mentor_report(target_user_id)

    if "error" in result:
        return jsonify(result), 404

    from services.audit_log_service import log_ai_event
    log_ai_event(
        "MENTOR_ANALYSE",
        user_id=current_user_id,
        ip=request.remote_addr or "unknown",
        details={"target_user_id": target_user_id},
    )

    return jsonify(result), 200


# ─── POST /api/ai/cv/build ────────────────────────────────────────────────────

@ai_bp.route("/cv/build", methods=["POST"])
@auth_required
def api_cv_build():
    """
    Build an AI-generated CV for the calling user (or an admin-specified user).
    ---
    tags:
      - AI
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        required: false
        schema:
          type: object
          properties:
            target_user_id:
              type: integer
              description: >
                Admin-only: generate CV for this user instead of the caller.
                Non-admins receive 403 if this differs from their own id.
            include_pdf:
              type: boolean
              default: false
              description: Reserved — PDF generation is not yet exposed.
    responses:
      200:
        description: Structured CV JSON
        schema:
          type: object
          properties:
            generated_at:
              type: string
            user:
              type: object
            summary:
              type: string
            skills:
              type: object
              properties:
                technical:
                  type: array
                  items:
                    type: string
                soft:
                  type: array
                  items:
                    type: string
            projects:
              type: array
              items:
                type: object
            achievements:
              type: array
              items:
                type: string
            metadata:
              type: object
            source:
              type: string
      400:
        description: Validation error
      403:
        description: Forbidden — non-admin requesting another user's CV
      404:
        description: Target user not found
    """
    from models import db
    from models.user import User
    from marshmallow import ValidationError as MarshmallowError

    current_user_id = int(get_jwt_identity())

    body = request.get_json(silent=True, force=True) or {}
    try:
        data = cv_build_schema.load(body)
    except MarshmallowError as exc:
        return jsonify({"error": "Validation failed", "details": exc.messages}), 400

    target_id = data.get("target_user_id") or current_user_id

    # RBAC: only admins may request another user's CV
    if target_id != current_user_id:
        caller = db.session.get(User, current_user_id)
        if not caller or caller.role != "admin":
            return jsonify({
                "error": "Forbidden",
                "detail": "Only admins may generate CVs for other users.",
            }), 403

    result = build_cv_for_user(target_id)

    if "error" in result:
        status_code = 404 if "not found" in result["error"].lower() else 500
        return jsonify(result), status_code

    from services.audit_log_service import log_ai_event
    log_ai_event(
        "CV_BUILD",
        user_id=current_user_id,
        ip=request.remote_addr or "unknown",
        details={"target_user_id": target_id, "source": result.get("source")},
    )

    return jsonify(result), 200
