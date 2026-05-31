"""
Ratings API  —  /api/ratings
-------------------------------
POST   /api/ratings                  Rate a user in a project (auth required)
GET    /api/ratings/user/<id>        All ratings received by a user
GET    /api/ratings/user/<id>/avg    Average score for a user
PUT    /api/ratings/<id>             Update your own rating
DELETE /api/ratings/<id>             Delete your own rating
"""
from flask import Blueprint, request, jsonify
from flask_jwt_extended import get_jwt_identity
from middleware.auth import auth_required
from models import db
from models.rating import Rating
from models.user import User
from models.project import Project
from services.project_access import user_has_project_access, users_share_project
from utils.pagination import parse_pagination

ratings_bp = Blueprint("ratings", __name__, url_prefix="/api/ratings")


# ─── Helpers ────────────────────────────────────────────────────────────────

def _validate_score(value):
    """Return (score_int, error_str).  error_str is None on success."""
    try:
        score = int(value)
    except (TypeError, ValueError):
        return None, "score must be an integer"
    if not 1 <= score <= 5:
        return None, "score must be between 1 and 5"
    return score, None


# ─── POST /api/ratings ───────────────────────────────────────────────────────

@ratings_bp.route("", methods=["POST"])
@auth_required
def create_rating():
    """
    Submit a star rating (1-5) for a user in a project.
    ---
    tags:
      - Ratings
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - ratee_id
            - score
          properties:
            ratee_id:
              type: integer
              description: ID of the user being rated
            project_id:
              type: integer
              description: Project context (optional)
            score:
              type: integer
              minimum: 1
              maximum: 5
            comment:
              type: string
    responses:
      201:
        description: Rating created
        schema:
          type: object
          properties:
            message:
              type: string
            rating:
              type: object
      400:
        description: Validation error
        schema:
          type: object
          properties:
            error:
              type: string
      409:
        description: You have already rated this user in this project
        schema:
          type: object
          properties:
            error:
              type: string
            message:
              type: string
            rating_id:
              type: integer
    """
    rater_id = int(get_jwt_identity())
    data = request.get_json(silent=True, force=True) or {}

    ratee_id   = data.get("ratee_id")
    project_id = data.get("project_id")
    score_raw  = data.get("score")
    comment    = (data.get("comment") or "").strip() or None

    # --- Validate ratee ---
    if not ratee_id:
        return jsonify({"error": "ratee_id is required"}), 400
    ratee = User.query.get(int(ratee_id))
    if not ratee:
        return jsonify({"error": "Rated user not found"}), 404

    if int(ratee_id) == rater_id:
        return jsonify({"error": "You cannot rate yourself"}), 400

    # --- Validate project (required for context) ---
    if not project_id:
        return jsonify({"error": "project_id is required"}), 400
    project = Project.query.get(int(project_id))
    if not project:
        return jsonify({"error": "Project not found"}), 404

    if not user_has_project_access(rater_id, int(project_id)):
        return jsonify({
            "error": "Forbidden",
            "message": "You must be a member of this project to submit a rating",
        }), 403

    if not user_has_project_access(int(ratee_id), int(project_id)):
        return jsonify({
            "error": "Bad Request",
            "message": "The rated user is not a member of this project",
        }), 400

    project_id = int(project_id)

    # --- Validate score ---
    score, err = _validate_score(score_raw)
    if err:
        return jsonify({"error": err}), 400

    # --- Duplicate check ---
    existing = Rating.query.filter_by(
        rater_id=rater_id, ratee_id=int(ratee_id), project_id=project_id
    ).first()
    if existing:
        return jsonify({
            "error": "Conflict",
            "message": "You have already rated this user in this project",
            "rating_id": existing.id,
        }), 409

    # --- Persist ---
    rating = Rating(
        rater_id=rater_id,
        ratee_id=int(ratee_id),
        project_id=project_id,
        score=score,
        comment=comment,
    )
    db.session.add(rating)
    db.session.commit()
    return jsonify({"message": "Rating submitted", "rating": rating.to_dict()}), 201


# ─── GET /api/ratings/user/<ratee_id> ────────────────────────────────────────

@ratings_bp.route("/user/<int:ratee_id>", methods=["GET"])
@auth_required
def get_user_ratings(ratee_id):
    """
    Get all ratings received by a user.
    ---
    tags:
      - Ratings
    security:
      - Bearer: []
    parameters:
      - in: path
        name: ratee_id
        type: integer
        required: true
      - in: query
        name: project_id
        type: integer
        description: Filter by project
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
        description: List of ratings
        schema:
          type: object
          properties:
            user_id:
              type: integer
            ratings:
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
        description: User not found
        schema:
          type: object
          properties:
            error:
              type: string
    """
    user = User.query.get(ratee_id)
    if not user:
        return jsonify({"error": "User not found"}), 404

    query = Rating.query.filter_by(ratee_id=ratee_id)

    project_id = request.args.get("project_id", type=int)
    if project_id:
        query = query.filter_by(project_id=project_id)

    page, per_page, page_err = parse_pagination()
    if page_err:
        return page_err
    pagination = query.order_by(Rating.created_at.desc()).paginate(
        page=page, per_page=per_page, error_out=False
    )

    return jsonify({
        "user_id":  ratee_id,
        "ratings":  [r.to_dict() for r in pagination.items],
        "total":    pagination.total,
        "page":     pagination.page,
        "pages":    pagination.pages,
        "per_page": pagination.per_page,
    }), 200


# ─── GET /api/ratings/user/<ratee_id>/avg ────────────────────────────────────

@ratings_bp.route("/user/<int:ratee_id>/avg", methods=["GET"])
@auth_required
def get_user_avg_rating(ratee_id):
    """
    Get average rating for a user (optionally filtered by project).
    ---
    tags:
      - Ratings
    security:
      - Bearer: []
    parameters:
      - in: path
        name: ratee_id
        type: integer
        required: true
      - in: query
        name: project_id
        type: integer
    responses:
      200:
        description: Average rating stats
        schema:
          type: object
          properties:
            user_id:
              type: integer
            average_score:
              type: number
            total_ratings:
              type: integer
            distribution:
              type: object
              additionalProperties:
                type: integer
      404:
        description: User not found
        schema:
          type: object
          properties:
            error:
              type: string
    """
    user = User.query.get(ratee_id)
    if not user:
        return jsonify({"error": "User not found"}), 404

    query = Rating.query.filter_by(ratee_id=ratee_id)
    project_id = request.args.get("project_id", type=int)
    if project_id:
        query = query.filter_by(project_id=project_id)

    ratings = query.all()
    total = len(ratings)
    avg   = round(sum(r.score for r in ratings) / total, 2) if total else None

    # Score distribution 1-5
    distribution = {str(i): sum(1 for r in ratings if r.score == i) for i in range(1, 6)}

    return jsonify({
        "user_id":      ratee_id,
        "average_score": avg,
        "total_ratings": total,
        "distribution":  distribution,
    }), 200


# ─── PUT /api/ratings/<id> ───────────────────────────────────────────────────

@ratings_bp.route("/<int:rating_id>", methods=["PUT"])
@auth_required
def update_rating(rating_id):
    """
    Update your own rating.
    ---
    tags:
      - Ratings
    security:
      - Bearer: []
    parameters:
      - in: path
        name: rating_id
        type: integer
        required: true
      - in: body
        name: body
        schema:
          type: object
          properties:
            score:
              type: integer
            comment:
              type: string
    responses:
      200:
        description: Rating updated
        schema:
          type: object
          properties:
            message:
              type: string
            rating:
              type: object
      403:
        description: Not your rating
        schema:
          type: object
          properties:
            error:
              type: string
            message:
              type: string
      404:
        description: Rating not found
        schema:
          type: object
          properties:
            error:
              type: string
    """
    rater_id = int(get_jwt_identity())
    rating = Rating.query.get(rating_id)
    if not rating:
        return jsonify({"error": "Rating not found"}), 404
    if rating.rater_id != rater_id:
        return jsonify({"error": "Forbidden", "message": "You can only edit your own ratings"}), 403

    data = request.get_json(silent=True, force=True) or {}

    if "score" in data:
        score, err = _validate_score(data["score"])
        if err:
            return jsonify({"error": err}), 400
        rating.score = score

    if "comment" in data:
        rating.comment = (data["comment"] or "").strip() or None

    db.session.commit()
    return jsonify({"message": "Rating updated", "rating": rating.to_dict()}), 200


# ─── DELETE /api/ratings/<id> ────────────────────────────────────────────────

@ratings_bp.route("/<int:rating_id>", methods=["DELETE"])
@auth_required
def delete_rating(rating_id):
    """
    Delete your own rating.
    ---
    tags:
      - Ratings
    security:
      - Bearer: []
    parameters:
      - in: path
        name: rating_id
        type: integer
        required: true
    responses:
      200:
        description: Rating deleted
        schema:
          type: object
          properties:
            message:
              type: string
      403:
        description: Not your rating
        schema:
          type: object
          properties:
            error:
              type: string
            message:
              type: string
      404:
        description: Rating not found
        schema:
          type: object
          properties:
            error:
              type: string
    """
    rater_id = int(get_jwt_identity())
    rating = Rating.query.get(rating_id)
    if not rating:
        return jsonify({"error": "Rating not found"}), 404
    if rating.rater_id != rater_id:
        return jsonify({"error": "Forbidden", "message": "You can only delete your own ratings"}), 403

    db.session.delete(rating)
    db.session.commit()
    return jsonify({"message": "Rating deleted"}), 200
