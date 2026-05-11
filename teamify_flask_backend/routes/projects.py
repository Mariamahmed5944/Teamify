from flask import Blueprint, request, jsonify
from flask_jwt_extended import get_jwt_identity
from middleware.auth import auth_required, get_project_role, _READ_ROLES, _WRITE_ROLES
from models import db
from models.project import Project
from models.project_member import ProjectMember
from models.log import Log
from datetime import date as date_type

VALID_PROJECT_STATUSES = {"planned", "active", "on_hold", "completed"}

projects_bp = Blueprint("projects", __name__, url_prefix="/api/projects")


def get_current_user_id():
    return int(get_jwt_identity())


# ─── GET /api/projects ────────────────────────────────────────────────────────

@projects_bp.route("", methods=["GET"])
@auth_required
def get_projects():
    """
    Get all accessible projects for the current user (paginated).
    Admins receive every project; others receive projects they own or are members of.
    ---
    tags:
      - Projects
    security:
      - Bearer: []
    parameters:
      - in: query
        name: page
        type: integer
        default: 1
      - in: query
        name: per_page
        type: integer
        default: 20
      - in: query
        name: search
        type: string
        description: Filter projects by name (case-insensitive)
      - in: query
        name: status
        type: string
        description: Filter by status (planned, active, on_hold, completed)
    responses:
      200:
        description: List of projects
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
    user_id = get_current_user_id()
    page     = max(1, int(request.args.get("page", 1)))
    per_page = min(int(request.args.get("per_page", 20)), 100)
    search   = request.args.get("search", "").strip()
    status_filter = request.args.get("status", "").strip().lower()

    from models.user import User
    user = User.query.filter_by(id=user_id).first()

    if user and user.role == "admin":
        q = Project.query
        if search:
            q = q.filter(Project.name.ilike(f"%{search}%"))
        if status_filter:
            q = q.filter(Project.status == status_filter)
        pagination = q.order_by(Project.created_at.desc()).paginate(page=page, per_page=per_page, error_out=False)
    else:
        member_project_ids = [
            pm.project_id
            for pm in ProjectMember.query.filter_by(user_id=user_id).all()
        ]
        from sqlalchemy import or_
        q = Project.query.filter(
            or_(
                Project.user_id == user_id,
                Project.id.in_(member_project_ids) if member_project_ids else False,
            )
        )
        if search:
            q = q.filter(Project.name.ilike(f"%{search}%"))
        if status_filter:
            q = q.filter(Project.status == status_filter)
        pagination = q.order_by(Project.created_at.desc()).paginate(page=page, per_page=per_page, error_out=False)

    return jsonify({
        "projects": [p.to_dict() for p in pagination.items],
        "total": pagination.total,
        "page": pagination.page,
        "per_page": pagination.per_page,
        "pages": pagination.pages,
    }), 200


# ─── POST /api/projects ───────────────────────────────────────────────────────

@projects_bp.route("", methods=["POST"])
@auth_required
def create_project():
    """
    Create a new project. The creator is automatically added as owner in project_members.
    ---
    tags:
      - Projects
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - name
          properties:
            name:
              type: string
              example: My Project
            description:
              type: string
              example: Project description
            status:
              type: string
              enum: [planned, active, on_hold, completed]
              example: active
            start_date:
              type: string
              format: date
              example: '2025-01-01'
            end_date:
              type: string
              format: date
              example: '2025-12-31'
    responses:
      201:
        description: Project created
        schema:
          type: object
          properties:
            message:
              type: string
            project:
              type: object
      400:
        description: Validation error
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
    user_id = get_current_user_id()
    data = request.get_json(silent=True, force=True)

    if not data or not data.get("name", "").strip():
        return jsonify({"error": "Bad Request", "message": "Project name is required"}), 400

    # Input length validation
    name = data["name"].strip()
    if len(name) > 150:
        return jsonify({"error": "Bad Request", "message": "Project name must be 150 characters or fewer"}), 400
    description = data.get("description", "")
    if len(description) > 5000:
        return jsonify({"error": "Bad Request", "message": "Description must be 5000 characters or fewer"}), 400

    # Validate status
    status = data.get("status", "active").lower()
    if status not in VALID_PROJECT_STATUSES:
        return jsonify({"error": "Bad Request", "message": f"status must be one of: {', '.join(sorted(VALID_PROJECT_STATUSES))}"}), 400

    # Parse optional dates
    start_date = end_date = None
    for field in ("start_date", "end_date"):
        raw = data.get(field)
        if raw:
            try:
                val = date_type.fromisoformat(raw)
            except ValueError:
                return jsonify({"error": "Bad Request", "message": f"Invalid {field} format. Use YYYY-MM-DD"}), 400
            if field == "start_date":
                start_date = val
            else:
                end_date = val

    # end_date must be after start_date
    if start_date and end_date and end_date < start_date:
        return jsonify({"error": "Bad Request", "message": "end_date must be after start_date"}), 400

    project = Project(
        name=name,
        description=description,
        status=status,
        start_date=start_date,
        end_date=end_date,
        user_id=user_id,
    )
    db.session.add(project)
    db.session.flush()  # populate project.id

    # Auto-add creator as owner in project_members
    owner_entry = ProjectMember(project_id=project.id, user_id=user_id, role="owner")
    db.session.add(owner_entry)

    log = Log(
        action="CREATE",
        entity="Project",
        entity_id=project.id,
        details=f"Project '{project.name}' created",
        user_id=user_id,
    )
    db.session.add(log)
    db.session.commit()

    return jsonify({"message": "Project created successfully", "project": project.to_dict()}), 201


# ─── GET /api/projects/<id> ───────────────────────────────────────────────────

@projects_bp.route("/<int:project_id>", methods=["GET"])
@auth_required
def get_project(project_id):
    """
    Get a single project by ID.
    Accessible by: admin, project owner, project member. Others → 403.
    ---
    tags:
      - Projects
    security:
      - Bearer: []
    parameters:
      - in: path
        name: project_id
        type: string
        required: true
    responses:
      200:
        description: Project data
        schema:
          type: object
          properties:
            project:
              type: object
      403:
        description: Forbidden – not a member of this project
        schema:
          type: object
          properties:
            error:
              type: string
      404:
        description: Not found
        schema:
          type: object
          properties:
            error:
              type: string
    """
    user_id = get_current_user_id()
    project = Project.query.get(project_id)

    if not project:
        return jsonify({"error": "Not Found", "message": "Project not found"}), 404

    role = get_project_role(user_id, project_id)
    if role not in _READ_ROLES:
        return jsonify({"error": "Forbidden", "message": "You are not a member of this project"}), 403

    return jsonify({"project": project.to_dict()}), 200


# ─── PUT /api/projects/<id> ───────────────────────────────────────────────────

@projects_bp.route("/<int:project_id>", methods=["PUT"])
@auth_required
def update_project(project_id):
    """
    Update a project (name, description, status).
    Accessible by: admin, project owner. Members → 403.
    ---
    tags:
      - Projects
    security:
      - Bearer: []
    parameters:
      - in: path
        name: project_id
        type: string
        required: true
      - in: body
        name: body
        schema:
          type: object
          properties:
            name:
              type: string
            description:
              type: string
            status:
              type: string
              enum: [planned, active, on_hold, completed]
            start_date:
              type: string
              format: date
              example: '2025-01-01'
            end_date:
              type: string
              format: date
              example: '2025-12-31'
    responses:
      200:
        description: Project updated
        schema:
          type: object
          properties:
            message:
              type: string
            project:
              type: object
      403:
        description: Forbidden
        schema:
          type: object
          properties:
            error:
              type: string
      404:
        description: Not found
        schema:
          type: object
          properties:
            error:
              type: string
    """
    user_id = get_current_user_id()
    project = Project.query.get(project_id)

    if not project:
        return jsonify({"error": "Not Found", "message": "Project not found"}), 404

    role = get_project_role(user_id, project_id)
    if role not in _WRITE_ROLES:
        return jsonify({"error": "Forbidden", "message": "Only the project owner or admin can update this project"}), 403

    data = request.get_json(silent=True, force=True) or {}
    if "name" in data:
        new_name = data["name"].strip()
        if not new_name or len(new_name) > 150:
            return jsonify({"error": "Bad Request", "message": "name must be 1-150 characters"}), 400
        project.name = new_name
    if "description" in data:
        if len(data["description"]) > 5000:
            return jsonify({"error": "Bad Request", "message": "Description must be 5000 characters or fewer"}), 400
        project.description = data["description"]
    if "status" in data:
        new_status = data["status"].lower()
        if new_status not in VALID_PROJECT_STATUSES:
            return jsonify({"error": "Bad Request", "message": f"status must be one of: {', '.join(sorted(VALID_PROJECT_STATUSES))}"}), 400
        project.status = new_status
    if "start_date" in data:
        try:
            project.start_date = date_type.fromisoformat(data["start_date"]) if data["start_date"] else None
        except ValueError:
            return jsonify({"error": "Bad Request", "message": "Invalid start_date format. Use YYYY-MM-DD"}), 400
    if "end_date" in data:
        try:
            project.end_date = date_type.fromisoformat(data["end_date"]) if data["end_date"] else None
        except ValueError:
            return jsonify({"error": "Bad Request", "message": "Invalid end_date format. Use YYYY-MM-DD"}), 400

    # end_date must be after start_date (use updated values)
    eff_start = project.start_date
    eff_end = project.end_date
    if eff_start and eff_end and eff_end < eff_start:
        return jsonify({"error": "Bad Request", "message": "end_date must be after start_date"}), 400

    log = Log(
        action="UPDATE",
        entity="Project",
        entity_id=project.id,
        details=f"Project '{project.name}' updated",
        user_id=user_id,
    )
    db.session.add(log)
    db.session.commit()

    return jsonify({"message": "Project updated successfully", "project": project.to_dict()}), 200


# ─── POST /api/projects/<id>/members ─────────────────────────────────────────

@projects_bp.route("/<int:project_id>/members", methods=["POST"])
@auth_required
def add_member(project_id):
    """
    Add a user as a member of this project.
    Accessible by: admin, project owner. Members → 403.
    ---
    tags:
      - Projects
    security:
      - Bearer: []
    parameters:
      - in: path
        name: project_id
        type: string
        required: true
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - user_id
          properties:
            user_id:
              type: string
              example: "uuid-of-user-to-add"
            role:
              type: string
              enum: [member, owner]
              example: member
    responses:
      201:
        description: Member added
        schema:
          type: object
          properties:
            message:
              type: string
            member:
              type: object
      400:
        description: Validation error or user already a member
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
        description: Project or user not found
        schema:
          type: object
          properties:
            error:
              type: string
    """
    current_user_id = get_current_user_id()
    project = Project.query.get(project_id)

    if not project:
        return jsonify({"error": "Not Found", "message": "Project not found"}), 404

    role = get_project_role(current_user_id, project_id)
    if role not in _WRITE_ROLES:
        return jsonify({"error": "Forbidden", "message": "Only the project owner or admin can add members"}), 403

    data = request.get_json(silent=True, force=True) or {}
    target_user_id_str = data.get("user_id", "")
    if not target_user_id_str:
        return jsonify({"error": "Bad Request", "message": "user_id is required"}), 400

    try:
        target_user_id = int(target_user_id_str)
    except ValueError:
        return jsonify({"error": "Bad Request", "message": "Invalid user_id format"}), 400

    from models.user import User
    target_user = User.query.filter_by(id=target_user_id).first()
    if not target_user:
        return jsonify({"error": "Not Found", "message": "User not found"}), 404

    existing = ProjectMember.query.filter_by(
        project_id=project_id, user_id=target_user_id
    ).first()
    if existing:
        return jsonify({"error": "Conflict", "message": "User is already a member of this project"}), 400

    member_role = data.get("role", "member")
    if member_role not in ("owner", "member"):
        return jsonify({"error": "Bad Request", "message": "role must be 'owner' or 'member'"}), 400

    pm = ProjectMember(project_id=project_id, user_id=target_user_id, role=member_role)
    db.session.add(pm)

    log = Log(
        action="ADD_MEMBER",
        entity="Project",
        entity_id=project.id,
        details=f"User '{target_user.display_name}' added as {member_role} to project '{project.name}'",
        user_id=current_user_id,
    )
    db.session.add(log)

    # Notify the added user
    from routes.notifications import create_notification
    create_notification(
        user_id=target_user_id,
        notif_type="team_added",
        title=f"Added to {project.name}",
        body=f"You have been added to the {project.name} team",
        entity_type="Project",
        entity_id=project.id,
    )

    db.session.commit()

    return jsonify({"message": "Member added successfully", "member": pm.to_dict()}), 201


# ─── DELETE /api/projects/<id> ────────────────────────────────────────────────

@projects_bp.route("/<int:project_id>", methods=["DELETE"])
@auth_required
def delete_project(project_id):
    """
    Delete a project.
    Accessible by: admin, project owner. Members → 403.
    ---
    tags:
      - Projects
    security:
      - Bearer: []
    parameters:
      - in: path
        name: project_id
        type: string
        required: true
    responses:
      200:
        description: Project deleted
        schema:
          type: object
          properties:
            message:
              type: string
      403:
        description: Forbidden
        schema:
          type: object
          properties:
            error:
              type: string
      404:
        description: Not found
        schema:
          type: object
          properties:
            error:
              type: string
    """
    user_id = get_current_user_id()
    project = Project.query.get(project_id)

    if not project:
        return jsonify({"error": "Not Found", "message": "Project not found"}), 404

    role = get_project_role(user_id, project_id)
    if role not in _WRITE_ROLES:
        return jsonify({"error": "Forbidden", "message": "Only the project owner or admin can delete this project"}), 403

    log = Log(
        action="DELETE",
        entity="Project",
        entity_id=project.id,
        details=f"Project '{project.name}' deleted",
        user_id=user_id,
    )
    db.session.add(log)
    try:
        db.session.delete(project)
        db.session.commit()
    except Exception:
        db.session.rollback()
        # Nullify FK references (disputes, files, tasks) then retry
        from sqlalchemy import text
        db.session.execute(
            text("UPDATE disputes SET project_id = NULL WHERE project_id = :pid"),
            {"pid": project_id}
        )
        db.session.execute(
            text("UPDATE file_metadata SET project_id = NULL WHERE project_id = :pid"),
            {"pid": project_id}
        )
        db.session.delete(project)
        db.session.commit()

    return jsonify({"message": "Project deleted successfully"}), 200


# ─── GET /api/projects/<id>/members ──────────────────────────────────────────

@projects_bp.route("/<int:project_id>/members", methods=["GET"])
@auth_required
def get_members(project_id):
    """
    List all members of a project with their roles.
    Accessible by: admin, owner, member, guest.
    ---
    tags:
      - Projects
    security:
      - Bearer: []
    parameters:
      - in: path
        name: project_id
        type: string
        required: true
    responses:
      200:
        description: List of project members
        schema:
          type: object
          properties:
            members:
              type: array
              items:
                type: object
            total:
              type: integer
      403:
        description: Forbidden
        schema:
          type: object
          properties:
            error:
              type: string
      404:
        description: Project not found
        schema:
          type: object
          properties:
            error:
              type: string
    """
    user_id = get_current_user_id()
    project = Project.query.get(project_id)

    if not project:
        return jsonify({"error": "Not Found", "message": "Project not found"}), 404

    role = get_project_role(user_id, project_id)
    if role not in _READ_ROLES:
        return jsonify({"error": "Forbidden", "message": "You are not a member of this project"}), 403

    from models.user import User
    members = ProjectMember.query.filter_by(project_id=project_id).all()
    result = []
    for pm in members:
        user = User.query.filter_by(id=pm.user_id).first()
        entry = {
            **pm.to_dict(),
            "display_name": user.display_name if user else None,
            "full_name": user.full_name if user else None,
            "email": user.email if user else None,
            "user_type": user.user_type if user else None,
            "skills": user.skills.split(",") if user and user.skills else [],
            "professional_field": user.professional_field if user else None,
            "availability": user.availability if user else None,
        }
        result.append(entry)

    return jsonify({"members": result, "total": len(result)}), 200


# ─── DELETE /api/projects/<id>/members/<user_id> ─────────────────────────────

@projects_bp.route("/<int:project_id>/members/<int:member_user_id>", methods=["DELETE"])
@auth_required
def remove_member(project_id, member_user_id):
    """
    Remove a member from a project.
    The project owner cannot be removed. Only admin/owner can remove members.
    ---
    tags:
      - Projects
    security:
      - Bearer: []
    parameters:
      - in: path
        name: project_id
        type: string
        required: true
      - in: path
        name: member_user_id
        type: string
        required: true
    responses:
      200:
        description: Member removed
        schema:
          type: object
          properties:
            message:
              type: string
      400:
        description: Cannot remove the project owner
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
        description: Project or member not found
        schema:
          type: object
          properties:
            error:
              type: string
    """
    current_user_id = get_current_user_id()
    project = Project.query.get(project_id)

    if not project:
        return jsonify({"error": "Not Found", "message": "Project not found"}), 404

    role = get_project_role(current_user_id, project_id)
    if role not in _WRITE_ROLES:
        return jsonify({"error": "Forbidden", "message": "Only the project owner or admin can remove members"}), 403

    pm = ProjectMember.query.filter_by(
        project_id=project_id, user_id=member_user_id
    ).first()
    if not pm:
        return jsonify({"error": "Not Found", "message": "Member not found in this project"}), 404

    if pm.role == "owner":
        return jsonify({"error": "Bad Request", "message": "Cannot remove the project owner"}), 400

    from models.user import User
    target_user = User.query.filter_by(id=member_user_id).first()

    log = Log(
        action="REMOVE_MEMBER",
        entity="Project",
        entity_id=project.id,
        details=f"User '{target_user.display_name if target_user else member_user_id}' removed from project '{project.name}'",
        user_id=current_user_id,
    )
    db.session.add(log)
    db.session.delete(pm)
    db.session.commit()

    return jsonify({"message": "Member removed successfully"}), 200


# ─── GET /api/projects/completed ─────────────────────────────────────────────

@projects_bp.route("/completed", methods=["GET"])
@auth_required
def get_completed_projects():
    """
    Get all completed projects accessible to the current user.
    ---
    tags:
      - Projects
    security:
      - Bearer: []
    parameters:
      - in: query
        name: page
        type: integer
        default: 1
      - in: query
        name: per_page
        type: integer
        default: 20
      - in: query
        name: search
        type: string
        description: Filter by project name
    responses:
      200:
        description: List of completed projects
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
            pages:
              type: integer
            per_page:
              type: integer
    """
    user_id  = get_current_user_id()
    page     = max(1, request.args.get("page", 1, type=int))
    per_page = min(request.args.get("per_page", 20, type=int), 100)
    search   = request.args.get("search", "").strip()

    from models.user import User
    from sqlalchemy import or_
    user = User.query.get(user_id)

    if user and user.role == "admin":
        q = Project.query.filter(Project.status == "completed")
    else:
        member_ids = [pm.project_id for pm in ProjectMember.query.filter_by(user_id=user_id).all()]
        q = Project.query.filter(
            Project.status == "completed",
            or_(
                Project.user_id == user_id,
                Project.id.in_(member_ids) if member_ids else False,
            )
        )

    if search:
        q = q.filter(Project.name.ilike(f"%{search}%"))

    pagination = q.order_by(Project.updated_at.desc()).paginate(
        page=page, per_page=per_page, error_out=False
    )
    return jsonify({
        "projects": [p.to_dict() for p in pagination.items],
        "total":    pagination.total,
        "page":     pagination.page,
        "per_page": pagination.per_page,
        "pages":    pagination.pages,
    }), 200


# ─── POST /api/projects/<id>/complete ────────────────────────────────────────

@projects_bp.route("/<int:project_id>/complete", methods=["POST"])
@auth_required
def mark_project_completed(project_id):
    """
    Mark a project as completed.
    Accessible by: admin, project owner.
    ---
    tags:
      - Projects
    security:
      - Bearer: []
    parameters:
      - in: path
        name: project_id
        type: integer
        required: true
    responses:
      200:
        description: Project marked as completed
        schema:
          type: object
          properties:
            message:
              type: string
            project:
              type: object
      403:
        description: Forbidden
        schema:
          type: object
          properties:
            error:
              type: string
            message:
              type: string
      404:
        description: Project not found
        schema:
          type: object
          properties:
            error:
              type: string
            message:
              type: string
      409:
        description: Project is already completed
        schema:
          type: object
          properties:
            error:
              type: string
            message:
              type: string
    """
    user_id = get_current_user_id()
    project = Project.query.get(project_id)
    if not project:
        return jsonify({"error": "Not Found", "message": "Project not found"}), 404

    role = get_project_role(user_id, project_id)
    if role not in _WRITE_ROLES:
        return jsonify({"error": "Forbidden", "message": "Only the project owner or admin can complete this project"}), 403

    if project.status == "completed":
        return jsonify({"error": "Conflict", "message": "Project is already completed"}), 409

    project.status = "completed"

    log = Log(
        action="COMPLETE",
        entity="Project",
        entity_id=project.id,
        details=f"Project '{project.name}' marked as completed",
        user_id=user_id,
    )
    db.session.add(log)
    db.session.commit()
    return jsonify({"message": "Project marked as completed", "project": project.to_dict()}), 200


# ─── POST /api/projects/<id>/reopen ──────────────────────────────────────────

@projects_bp.route("/<int:project_id>/reopen", methods=["POST"])
@auth_required
def reopen_project(project_id):
    """
    Reopen a completed project (sets status back to 'active').
    Accessible by: admin, project owner.
    ---
    tags:
      - Projects
    security:
      - Bearer: []
    parameters:
      - in: path
        name: project_id
        type: integer
        required: true
    responses:
      200:
        description: Project reopened
        schema:
          type: object
          properties:
            message:
              type: string
            project:
              type: object
      403:
        description: Forbidden
        schema:
          type: object
          properties:
            error:
              type: string
            message:
              type: string
      404:
        description: Project not found
        schema:
          type: object
          properties:
            error:
              type: string
            message:
              type: string
      409:
        description: Project is not completed
        schema:
          type: object
          properties:
            error:
              type: string
            message:
              type: string
    """
    user_id = get_current_user_id()
    project = Project.query.get(project_id)
    if not project:
        return jsonify({"error": "Not Found", "message": "Project not found"}), 404

    role = get_project_role(user_id, project_id)
    if role not in _WRITE_ROLES:
        return jsonify({"error": "Forbidden", "message": "Only the project owner or admin can reopen this project"}), 403

    if project.status != "completed":
        return jsonify({"error": "Conflict", "message": f"Project is not completed (current status: {project.status})"}), 409

    project.status = "active"

    log = Log(
        action="REOPEN",
        entity="Project",
        entity_id=project.id,
        details=f"Project '{project.name}' reopened",
        user_id=user_id,
    )
    db.session.add(log)
    db.session.commit()
    return jsonify({"message": "Project reopened successfully", "project": project.to_dict()}), 200
