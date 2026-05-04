from flask import Blueprint, request, jsonify
from flask_jwt_extended import get_jwt_identity
from middleware.auth import auth_required
from models import db
from models.user import User
from models.project import Project
from models.project_member import ProjectMember
from sqlalchemy import or_, func

search_bp = Blueprint("search", __name__, url_prefix="/api/search")


@search_bp.route("/users", methods=["GET"])
@auth_required
def search_users():
    """
    Search users by name, email, or skill.
    ---
    tags:
      - Search
    security:
      - Bearer: []
    parameters:
      - in: query
        name: q
        type: string
        description: Search query (matches display_name, full_name, email)
      - in: query
        name: skill
        type: string
        description: Filter by skill (partial match)
      - in: query
        name: user_type
        type: string
        description: Filter by user type (freelancer, student, employee, business)
      - in: query
        name: availability
        type: string
        description: Filter by availability
      - in: query
        name: looking_for_team
        type: boolean
        description: Filter users looking for team
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
        description: Search results
        schema:
          type: object
          properties:
            users:
              type: array
              items:
                type: object
            total:
              type: integer
            page:
              type: integer
            per_page:
              type: integer
            pages:
              type: integer
      401:
        description: Unauthorized
        schema:
          type: object
          properties:
            error:
              type: string
    """
    q = request.args.get("q", "").strip()
    skill = request.args.get("skill", "").strip()
    user_type = request.args.get("user_type", "").strip().lower()
    availability = request.args.get("availability", "").strip()
    looking_for_team = request.args.get("looking_for_team", "").strip().lower()
    page = max(1, int(request.args.get("page", 1)))
    
    per_page = min(int(request.args.get("per_page", 20)), 100)

    query = User.query

    if q:
        pattern = f"%{q}%"
        query = query.filter(
            or_(
                User.display_name.ilike(pattern),
                User.full_name.ilike(pattern),
                User.email.ilike(pattern),
            )
        )

    if skill:
        query = query.filter(User.skills.ilike(f"%{skill}%"))

    if user_type:
        query = query.filter(User.user_type == user_type)

    if availability:
        query = query.filter(User.availability.ilike(f"%{availability}%"))

    if looking_for_team == "true":
        query = query.filter(User.looking_for_team == True)

    pagination = (
        query
        .order_by(User.display_name.asc())
        .paginate(page=page, per_page=per_page, error_out=False)
    )

    return jsonify({
        "users": [u.to_dict() for u in pagination.items],
        "total": pagination.total,
        "page": pagination.page,
        "per_page": pagination.per_page,
        "pages": pagination.pages,
    }), 200
  

@search_bp.route("/projects", methods=["GET"])
@auth_required
def search_projects():
    """
    Search projects by name or description.
    ---
    tags:
      - Search
    security:
      - Bearer: []
    parameters:
      - in: query
        name: q
        type: string
        description: Search query
      - in: query
        name: status
        type: string
        description: Filter by status
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
        description: Search results
        schema:
          type: object
          properties:
            projects:
              type: array
              items:
                type: object
            total:
              type: integer
            page:
              type: integer
            per_page:
              type: integer
            pages:
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
    q = request.args.get("q", "").strip()
    status = request.args.get("status", "").strip().lower()
    page = max(1, int(request.args.get("page", 1)))
    per_page = min(int(request.args.get("per_page", 20)), 100)

    # Only return projects the user has access to
    user = User.query.get(user_id)

    if user and user.role == "admin":
        query = Project.query
    else:
        member_project_ids = [
            pm.project_id for pm in ProjectMember.query.filter_by(user_id=user_id).all()
        ]
        query = Project.query.filter(
            or_(
                Project.user_id == user_id,
                Project.id.in_(member_project_ids) if member_project_ids else False,
            )
        )

    if q:
        pattern = f"%{q}%"
        query = query.filter(
            or_(
                Project.name.ilike(pattern),
                Project.description.ilike(pattern),
            )
        )

    if status:
        query = query.filter(Project.status == status)

    pagination = (
        query
        .order_by(Project.updated_at.desc())
        .paginate(page=page, per_page=per_page, error_out=False)
    )

    return jsonify({
        "projects": [p.to_dict() for p in pagination.items],
        "total": pagination.total,
        "page": pagination.page,
        "per_page": pagination.per_page,
        "pages": pagination.pages,
    }), 200
