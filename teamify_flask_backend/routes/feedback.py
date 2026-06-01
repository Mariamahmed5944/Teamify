"""
Feedback API  —  /api/feedback
-------------------------------
POST   /api/feedback                     Submit feedback for a user in a project
GET    /api/feedback/user/<id>           All feedback received by a user
GET    /api/feedback/project/<id>        All feedback in a project
GET    /api/feedback/<id>                Single feedback entry
PUT    /api/feedback/<id>                Update your own feedback
DELETE /api/feedback/<id>                Delete your own feedback
"""
from flask import Blueprint, request, jsonify
from flask_jwt_extended import get_jwt_identity
from middleware.auth import auth_required, get_project_role, _READ_ROLES
from models import db
from models.feedback import Feedback
from models.user import User
from models.project import Project
from services.project_access import user_has_project_access, can_view_user_stats
from utils.pagination import parse_pagination

feedback_bp = Blueprint("feedback", __name__, url_prefix="/api/feedback")


# ─── Helpers ─────────────────────────────────────────────────────────────────

def _validate_score(value, field_name):
    """Validate a 0-5 float score.  Returns (float|None, error_str|None)."""
    if value is None:
        return None, None
    try:
        score = float(value)
    except (TypeError, ValueError):
        return None, f"{field_name} must be a number"
    if not 0.0 <= score <= 5.0:
        return None, f"{field_name} must be between 0 and 5"
    return score, None


# ─── POST /api/feedback ──────────────────────────────────────────────────────

@feedback_bp.route("", methods=["POST"])
@auth_required
def create_feedback():
    """
    Submit feedback for a user within a project.
    ---
    tags:
      - Feedback
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - user_id
            - project_id
          properties:
            user_id:
              type: integer
              description: ID of the user being reviewed
            project_id:
              type: integer
              description: Project context
            quality_score:
              type: number
              minimum: 0
              maximum: 5
            teamwork_score:
              type: number
              minimum: 0
              maximum: 5
            avg_rating:
              type: integer
              minimum: 0
              maximum: 5
            feedback_text:
              type: string
    responses:
      201:
        description: Feedback submitted
        schema:
          type: object
          properties:
            message:
              type: string
            feedback:
              type: object
      400:
        description: Validation error
        schema:
          type: object
          properties:
            error:
              type: string
            messages:
              type: array
              items:
                type: string
      404:
        description: User or project not found
        schema:
          type: object
          properties:
            error:
              type: string
    """
    reviewer_id = int(get_jwt_identity())
    data = request.get_json(silent=True, force=True) or {}

    user_id    = data.get("user_id")
    project_id = data.get("project_id")

    # --- Required fields ---
    if not user_id:
        return jsonify({"error": "user_id is required"}), 400
    if not project_id:
        return jsonify({"error": "project_id is required"}), 400

    user = User.query.get(int(user_id))
    if not user:
        return jsonify({"error": "User not found"}), 404

    project = Project.query.get(int(project_id))
    if not project:
        return jsonify({"error": "Project not found"}), 404

    if not user_has_project_access(reviewer_id, int(project_id)):
        return jsonify({
            "error": "Forbidden",
            "message": "You must be a member of this project to submit feedback",
        }), 403

    if not user_has_project_access(int(user_id), int(project_id)):
        return jsonify({
            "error": "Bad Request",
            "message": "The reviewed user is not a member of this project",
        }), 400

    # --- Optional scores ---
    quality_score,  err1 = _validate_score(data.get("quality_score"),  "quality_score")
    teamwork_score, err2 = _validate_score(data.get("teamwork_score"), "teamwork_score")
    errors = [e for e in [err1, err2] if e]
    if errors:
        return jsonify({"error": "Validation failed", "messages": errors}), 400

    avg_raw = data.get("avg_rating")
    if avg_raw is not None:
        try:
            avg_rating = int(avg_raw)
            if not 0 <= avg_rating <= 5:
                raise ValueError()
        except (TypeError, ValueError):
            return jsonify({"error": "avg_rating must be an integer between 0 and 5"}), 400
    else:
        avg_rating = None

    feedback_text = (data.get("feedback_text") or "").strip() or None

    feedback = Feedback(
        user_id=int(user_id),
        project_id=int(project_id),
        reviewer_id=reviewer_id,
        quality_score=quality_score,
        teamwork_score=teamwork_score,
        avg_rating=avg_rating,
        feedback_text=feedback_text,
    )
    db.session.add(feedback)
    db.session.commit()
    from services.ai_mentor_service import invalidate_mentor_cache
    invalidate_mentor_cache(int(user_id))
    return jsonify({"message": "Feedback submitted", "feedback": feedback.to_dict()}), 201


# ─── GET /api/feedback/user/<user_id> ────────────────────────────────────────

@feedback_bp.route("/user/<int:user_id>", methods=["GET"])
@auth_required
def get_user_feedback(user_id):
    """
    Get all feedback received by a user.
    ---
    tags:
      - Feedback
    security:
      - Bearer: []
    parameters:
      - in: path
        name: user_id
        type: integer
        required: true
      - in: query
        name: project_id
        type: integer
      - in: query
        name: page
        type: integer
        default: 1
      - in: query
        name: per_page
        type: integer
        default: 20
    responses:
      200:
        description: List of feedback entries
        schema:
          type: object
          properties:
            user_id:
              type: integer
            feedback:
              type: array
              items:
                type: object
            total:
              type: integer
            page:
              type: integer
            pages:
              type: integer
            per_page:
              type: integer
            avg_quality:
              type: number
            avg_teamwork:
              type: number
      404:
        description: User not found
        schema:
          type: object
          properties:
            error:
              type: string
    """
    viewer_id = int(get_jwt_identity())
    viewer = User.query.get(viewer_id)
    if not viewer:
        return jsonify({"error": "User not found"}), 404

    if not can_view_user_stats(viewer_id, user_id, viewer.role):
        return jsonify({
            "error": "Forbidden",
            "message": "You are not authorized to view this user's feedback",
        }), 403

    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "User not found"}), 404

    query = Feedback.query.filter_by(user_id=user_id)
    project_id = request.args.get("project_id", type=int)
    if project_id:
        query = query.filter_by(project_id=project_id)

    page, per_page, page_err = parse_pagination()
    if page_err:
        return page_err
    pagination = query.order_by(Feedback.created_at.desc()).paginate(
        page=page, per_page=per_page, error_out=False
    )

    entries = pagination.items
    avg_quality  = (sum(f.quality_score  for f in entries if f.quality_score  is not None) /
                    max(1, sum(1 for f in entries if f.quality_score  is not None))) if entries else None
    avg_teamwork = (sum(f.teamwork_score for f in entries if f.teamwork_score is not None) /
                    max(1, sum(1 for f in entries if f.teamwork_score is not None))) if entries else None

    return jsonify({
        "user_id":        user_id,
        "feedback":       [f.to_dict() for f in entries],
        "total":          pagination.total,
        "page":           pagination.page,
        "pages":          pagination.pages,
        "per_page":       pagination.per_page,
        "avg_quality":    round(avg_quality,  2) if avg_quality  is not None else None,
        "avg_teamwork":   round(avg_teamwork, 2) if avg_teamwork is not None else None,
    }), 200


# ─── GET /api/feedback/project/<project_id> ──────────────────────────────────

@feedback_bp.route("/project/<int:project_id>", methods=["GET"])
@auth_required
def get_project_feedback(project_id):
    """
    Get all feedback entries for a project.
    ---
    tags:
      - Feedback
    security:
      - Bearer: []
    parameters:
      - in: path
        name: project_id
        type: integer
        required: true
      - in: query
        name: page
        type: integer
        default: 1
      - in: query
        name: per_page
        type: integer
        default: 20
    responses:
      200:
        description: List of feedback entries for the project
        schema:
          type: object
          properties:
            project_id:
              type: integer
            feedback:
              type: array
              items:
                type: object
            total:
              type: integer
            page:
              type: integer
            pages:
              type: integer
            per_page:
              type: integer
      404:
        description: Project not found
        schema:
          type: object
          properties:
            error:
              type: string
    """
    viewer_id = int(get_jwt_identity())
    project = Project.query.get(project_id)
    if not project:
        return jsonify({"error": "Project not found"}), 404

    if not user_has_project_access(viewer_id, project_id):
        return jsonify({
            "error": "Forbidden",
            "message": "You do not have access to this project's feedback",
        }), 403

    page, per_page, page_err = parse_pagination()
    if page_err:
        return page_err
    pagination = (
        Feedback.query.filter_by(project_id=project_id)
        .order_by(Feedback.created_at.desc())
        .paginate(page=page, per_page=per_page, error_out=False)
    )

    return jsonify({
        "project_id": project_id,
        "feedback":   [f.to_dict() for f in pagination.items],
        "total":      pagination.total,
        "page":       pagination.page,
        "pages":      pagination.pages,
        "per_page":   pagination.per_page,
    }), 200


# ─── GET /api/feedback/<id> ──────────────────────────────────────────────────

@feedback_bp.route("/<int:feedback_id>", methods=["GET"])
@auth_required
def get_feedback(feedback_id):
    """
    Get a single feedback entry.
    ---
    tags:
      - Feedback
    security:
      - Bearer: []
    parameters:
      - in: path
        name: feedback_id
        type: integer
        required: true
    responses:
      200:
        description: Feedback entry
        schema:
          type: object
          properties:
            feedback:
              type: object
      404:
        description: Not found
        schema:
          type: object
          properties:
            error:
              type: string
    """
    viewer_id = int(get_jwt_identity())
    fb = Feedback.query.get(feedback_id)
    if not fb:
        return jsonify({"error": "Feedback not found"}), 404

    if not user_has_project_access(viewer_id, fb.project_id):
        return jsonify({
            "error": "Forbidden",
            "message": "You do not have access to this feedback",
        }), 403
    return jsonify({"feedback": fb.to_dict()}), 200


# ─── PUT /api/feedback/<id> ──────────────────────────────────────────────────

@feedback_bp.route("/<int:feedback_id>", methods=["PUT"])
@auth_required
def update_feedback(feedback_id):
    """
    Update your own feedback entry.
    ---
    tags:
      - Feedback
    security:
      - Bearer: []
    parameters:
      - in: path
        name: feedback_id
        type: integer
        required: true
      - in: body
        name: body
        schema:
          type: object
          properties:
            quality_score:
              type: number
            teamwork_score:
              type: number
            avg_rating:
              type: integer
            feedback_text:
              type: string
    responses:
      200:
        description: Feedback updated
        schema:
          type: object
          properties:
            message:
              type: string
            feedback:
              type: object
      403:
        description: Not your feedback
        schema:
          type: object
          properties:
            error:
              type: string
            message:
              type: string
      404:
        description: Not found
        schema:
          type: object
          properties:
            error:
              type: string
    """
    reviewer_id = int(get_jwt_identity())
    fb = Feedback.query.get(feedback_id)
    if not fb:
        return jsonify({"error": "Feedback not found"}), 404
    if fb.reviewer_id != reviewer_id:
        return jsonify({"error": "Forbidden", "message": "You can only edit your own feedback"}), 403

    data = request.get_json(silent=True, force=True) or {}
    errors = []

    if "quality_score" in data:
        score, err = _validate_score(data["quality_score"], "quality_score")
        if err:
            errors.append(err)
        else:
            fb.quality_score = score

    if "teamwork_score" in data:
        score, err = _validate_score(data["teamwork_score"], "teamwork_score")
        if err:
            errors.append(err)
        else:
            fb.teamwork_score = score

    if "avg_rating" in data:
        try:
            avg = int(data["avg_rating"])
            if not 0 <= avg <= 5:
                raise ValueError()
            fb.avg_rating = avg
        except (TypeError, ValueError):
            errors.append("avg_rating must be an integer between 0 and 5")

    if errors:
        return jsonify({"error": "Validation failed", "messages": errors}), 400

    if "feedback_text" in data:
        fb.feedback_text = (data["feedback_text"] or "").strip() or None

    db.session.commit()
    from services.ai_mentor_service import invalidate_mentor_cache
    invalidate_mentor_cache(int(fb.user_id))
    return jsonify({"message": "Feedback updated", "feedback": fb.to_dict()}), 200


# ─── DELETE /api/feedback/<id> ───────────────────────────────────────────────

@feedback_bp.route("/<int:feedback_id>", methods=["DELETE"])
@auth_required
def delete_feedback(feedback_id):
    """
    Delete your own feedback entry.
    ---
    tags:
      - Feedback
    security:
      - Bearer: []
    parameters:
      - in: path
        name: feedback_id
        type: integer
        required: true
    responses:
      200:
        description: Feedback deleted
        schema:
          type: object
          properties:
            message:
              type: string
      403:
        description: Not your feedback
        schema:
          type: object
          properties:
            error:
              type: string
            message:
              type: string
      404:
        description: Not found
        schema:
          type: object
          properties:
            error:
              type: string
    """
    reviewer_id = int(get_jwt_identity())
    fb = Feedback.query.get(feedback_id)
    if not fb:
        return jsonify({"error": "Feedback not found"}), 404
    if fb.reviewer_id != reviewer_id:
        return jsonify({"error": "Forbidden", "message": "You can only delete your own feedback"}), 403

    db.session.delete(fb)
    db.session.commit()
    from services.ai_mentor_service import invalidate_mentor_cache
    invalidate_mentor_cache(int(fb.user_id))
    return jsonify({"message": "Feedback deleted"}), 200
