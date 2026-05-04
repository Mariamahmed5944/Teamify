from flask import Blueprint, request, jsonify
from flask_jwt_extended import get_jwt_identity
from middleware.auth import auth_required, get_project_role, _READ_ROLES, _WRITE_ROLES, _MEMBER_ROLES
from models import db
from models.task import Task
from models.project import Project
from models.project_member import ProjectMember
from models.log import Log

tasks_bp = Blueprint("tasks", __name__, url_prefix="/api/tasks")

VALID_STATUSES   = {"pending", "in_progress", "done"}
VALID_PRIORITIES = {"low", "medium", "high"}


def get_current_user_id():
    return int(get_jwt_identity())


def _get_task_or_404(task_id):
    task = Task.query.get(task_id)
    if not task:
        return None, (jsonify({"error": "Not Found", "message": "Task not found"}), 404)
    return task, None


def _assert_is_project_member(user_id, project_id, project):
    """Return a 400 response tuple if user_id is NOT a member/owner/admin of the project."""
    from models.user import User
    user = User.query.filter_by(id=user_id).first()
    if not user:
        return jsonify({"error": "Not Found", "message": "Assigned user not found"}), 404
    if user.role == "admin":
        return None  # admins can be assigned to any task
    if project.user_id == user_id:
        return None  # project creator/owner
    is_member = ProjectMember.query.filter_by(
        project_id=project_id, user_id=user_id
    ).first()
    if not is_member:
        return jsonify({"error": "Bad Request", "message": "assigned_to user must be a member of the project"}), 400
    return None


# ─── GET /api/tasks?project_id=<uuid> ────────────────────────────────────────

@tasks_bp.route("", methods=["GET"])
@auth_required
def get_tasks():
    """
    Get all tasks for a specific project (paginated).
    Accessible by: admin, project owner, project member, project guest.
    ---
    tags:
      - Tasks
    security:
      - Bearer: []
    parameters:
      - in: query
        name: project_id
        type: string
        required: true
        description: UUID of the project
      - in: query
        name: page
        type: integer
        default: 1
      - in: query
        name: per_page
        type: integer
        default: 20
      - in: query
        name: status
        type: string
        description: Filter by status (pending, in_progress, done)
      - in: query
        name: priority
        type: string
        description: Filter by priority (low, medium, high)
      - in: query
        name: assigned_to
        type: string
        description: Filter by assigned user UUID
    responses:
      200:
        description: List of tasks
        schema:
          type: object
          properties:
            tasks:
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
      400:
        description: project_id query param missing or invalid
        schema:
          type: object
          properties:
            error:
              type: string
      403:
        description: Forbidden – not a member of this project
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
    project_id_str = request.args.get("project_id")
    page     = max(1, int(request.args.get("page", 1)))
    per_page = min(int(request.args.get("per_page", 20)), 100)
    status_filter   = request.args.get("status", "").strip().lower()
    priority_filter = request.args.get("priority", "").strip().lower()
    assigned_filter = request.args.get("assigned_to", "").strip()

    if not project_id_str:
        return jsonify({"error": "project_id query parameter is required"}), 400

    try:
        project_id = int(project_id_str)
    except ValueError:
        return jsonify({"error": "Invalid project_id format"}), 400

    project = Project.query.get(project_id)
    if not project:
        return jsonify({"error": "Not Found", "message": "Project not found"}), 404

    role = get_project_role(user_id, project_id)
    if role not in _READ_ROLES:
        return jsonify({"error": "Forbidden", "message": "You are not a member of this project"}), 403

    # Parse and validate assigned_to filter UUID
    parsed_assigned = None
    if assigned_filter:
        try:
            parsed_assigned = int(assigned_filter)
        except ValueError:
            return jsonify({"error": "Bad Request", "message": "Invalid assigned_to UUID format"}), 400

    pagination = (
        Task.query
        .filter_by(project_id=project_id)
        .filter(Task.status == status_filter if status_filter else True)
        .filter(Task.priority == priority_filter if priority_filter else True)
        .filter(Task.assigned_to == parsed_assigned if parsed_assigned else True)
        .order_by(Task.created_at.desc())
        .paginate(page=page, per_page=per_page, error_out=False)
    )
    return jsonify({
        "tasks": [t.to_dict() for t in pagination.items],
        "total": pagination.total,
        "page": pagination.page,
        "per_page": pagination.per_page,
        "pages": pagination.pages,
    }), 200


# ─── POST /api/tasks ──────────────────────────────────────────────────────────

@tasks_bp.route("", methods=["POST"])
@auth_required
def create_task():
    """
    Create a new task inside a project.
    Accessible by: admin, project owner. Members → 403.
    ---
    tags:
      - Tasks
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - title
            - project_id
          properties:
            title:
              type: string
              example: Design homepage
            description:
              type: string
            status:
              type: string
              enum: [pending, in_progress, done]
              example: pending
            priority:
              type: string
              enum: [low, medium, high]
              example: medium
            due_date:
              type: string
              format: date
              example: "2025-12-31"
            project_id:
              type: string
              example: "uuid-of-project"
            assigned_to:
              type: string
              example: "uuid-of-user"
    responses:
      201:
        description: Task created
        schema:
          type: object
          properties:
            message:
              type: string
            task:
              type: object
      400:
        description: Validation error
        schema:
          type: object
          properties:
            error:
              type: string
      403:
        description: Forbidden – must be project owner or admin
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
    data = request.get_json(silent=True, force=True)

    if not data:
        return jsonify({"error": "Bad Request", "message": "Request body is required"}), 400

    title = data.get("title", "").strip()
    project_id_str = data.get("project_id", "")

    if not title:
        return jsonify({"error": "Bad Request", "message": "Task title is required"}), 400
    if len(title) > 200:
        return jsonify({"error": "Bad Request", "message": "Task title must be 200 characters or fewer"}), 400
    if not project_id_str:
        return jsonify({"error": "Bad Request", "message": "project_id is required"}), 400

    try:
        project_id = int(project_id_str)
    except ValueError:
        return jsonify({"error": "Bad Request", "message": "Invalid project_id format"}), 400

    project = Project.query.get(project_id)
    if not project:
        return jsonify({"error": "Not Found", "message": "Project not found"}), 404

    role = get_project_role(user_id, project_id)
    if role not in _WRITE_ROLES:
        return jsonify({"error": "Forbidden", "message": "Only the project owner or admin can create tasks"}), 403

    # Validate status
    req_status = data.get("status", "pending")
    if req_status not in VALID_STATUSES:
        return jsonify({"error": "Bad Request", "message": f"status must be one of: {', '.join(sorted(VALID_STATUSES))}"}), 400

    # Validate priority
    req_priority = data.get("priority", "medium")
    if req_priority not in VALID_PRIORITIES:
        return jsonify({"error": "Bad Request", "message": f"priority must be one of: {', '.join(sorted(VALID_PRIORITIES))}"}), 400

    # Parse optional due_date
    due_date = None
    if data.get("due_date"):
        from datetime import date
        try:
            due_date = date.fromisoformat(data["due_date"])
        except ValueError:
            return jsonify({"error": "Bad Request", "message": "Invalid due_date format. Use YYYY-MM-DD"}), 400

    # Parse + validate assigned_to is a project member
    assigned_to = None
    auto_assigned = False
    if data.get("assigned_to"):
        try:
            assigned_to = int(data["assigned_to"])
        except ValueError:
            return jsonify({"error": "Bad Request", "message": "Invalid assigned_to format"}), 400
        err = _assert_is_project_member(assigned_to, project_id, project)
        if err is not None:
            return err
    elif data.get("auto_assign", False):
        # AI auto-assign: pick the least busy member
        from services.ai_service import auto_assign as ai_auto_assign
        suggested_id, reason = ai_auto_assign(project_id, req_priority)
        if suggested_id:
            assigned_to = suggested_id
            auto_assigned = True

    task = Task(
        title=title,
        description=data.get("description", ""),
        status=req_status,
        priority=req_priority,
        due_date=due_date,
        project_id=project_id,
        assigned_to=assigned_to,
    )
    db.session.add(task)
    db.session.flush()

    log = Log(
        action="CREATE",
        entity="Task",
        entity_id=task.id,
        details=f"Task '{task.title}' created",
        user_id=user_id,
    )
    db.session.add(log)

    # Notify the assignee
    if task.assigned_to and task.assigned_to != user_id:
        from routes.notifications import create_notification
        create_notification(
            user_id=task.assigned_to,
            notif_type="task_assigned",
            title="New task assigned",
            body=f"You have been assigned to \"{task.title}\"",
            entity_type="Task",
            entity_id=task.id,
        )

    db.session.commit()

    response = {"message": "Task created successfully", "task": task.to_dict()}
    if auto_assigned:
        response["auto_assigned"] = True
        response["auto_assign_reason"] = reason

    return jsonify(response), 201


# ─── GET /api/tasks/<id> ──────────────────────────────────────────────────────

@tasks_bp.route("/<int:task_id>", methods=["GET"])
@auth_required
def get_task(task_id):
    """
    Get a single task by ID.
    Accessible by: admin, project owner, project member.
    ---
    tags:
      - Tasks
    security:
      - Bearer: []
    parameters:
      - in: path
        name: task_id
        type: string
        required: true
    responses:
      200:
        description: Task data
        schema:
          type: object
          properties:
            task:
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
    task, err = _get_task_or_404(task_id)
    if err:
        return err

    role = get_project_role(user_id, task.project_id)
    if role not in _READ_ROLES:
        return jsonify({"error": "Forbidden", "message": "You are not a member of this project"}), 403

    return jsonify({"task": task.to_dict()}), 200


# ─── PATCH /api/tasks/<id>/status ─────────────────────────────────────────────

@tasks_bp.route("/<int:task_id>/status", methods=["PATCH"])
@auth_required
def update_task_status(task_id):
    """
    Update only the status of a task.
    Accessible by: admin, project owner, project member.
    ---
    tags:
      - Tasks
    security:
      - Bearer: []
    parameters:
      - in: path
        name: task_id
        type: string
        required: true
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - status
          properties:
            status:
              type: string
              enum: [pending, in_progress, done]
              example: in_progress
    responses:
      200:
        description: Task status updated
        schema:
          type: object
          properties:
            message:
              type: string
            task:
              type: object
      400:
        description: Invalid status value
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
        description: Task not found
        schema:
          type: object
          properties:
            error:
              type: string
    """
    user_id = get_current_user_id()
    task, err = _get_task_or_404(task_id)
    if err:
        return err

    role = get_project_role(user_id, task.project_id)
    if role not in _MEMBER_ROLES:
        return jsonify({"error": "Forbidden", "message": "Guests cannot update task status"}), 403

    data = request.get_json(silent=True, force=True) or {}
    new_status = data.get("status")

    if not new_status:
        return jsonify({"error": "Bad Request", "message": "status field is required"}), 400
    if new_status not in VALID_STATUSES:
        return jsonify({
            "error": "Bad Request",
            "message": f"Invalid status. Must be one of: {', '.join(sorted(VALID_STATUSES))}"
        }), 400

    old_status = task.status
    task.status = new_status

    log = Log(
        action="UPDATE_STATUS",
        entity="Task",
        entity_id=task.id,
        details=f"Task '{task.title}' status changed from '{old_status}' to '{new_status}'",
        user_id=user_id,
    )
    db.session.add(log)

    # Notify assignee about status change
    if task.assigned_to and task.assigned_to != user_id:
        from routes.notifications import create_notification
        create_notification(
            user_id=task.assigned_to,
            notif_type="task_updated",
            title="Task updated",
            body=f"Task \"{task.title}\" status changed to '{new_status}'",
            entity_type="Task",
            entity_id=task.id,
        )

    db.session.commit()

    return jsonify({"message": "Task status updated successfully", "task": task.to_dict()}), 200


# ─── PUT /api/tasks/<id> ──────────────────────────────────────────────────────

@tasks_bp.route("/<int:task_id>", methods=["PUT"])
@auth_required
def update_task(task_id):
    """
    Update a task (full update).
    Accessible by: admin, project owner. Members → 403.
    ---
    tags:
      - Tasks
    security:
      - Bearer: []
    parameters:
      - in: path
        name: task_id
        type: string
        required: true
      - in: body
        name: body
        schema:
          type: object
          properties:
            title:
              type: string
            description:
              type: string
            status:
              type: string
              enum: [pending, in_progress, done]
            priority:
              type: string
              enum: [low, medium, high]
            due_date:
              type: string
              format: date
            assigned_to:
              type: string
    responses:
      200:
        description: Task updated
        schema:
          type: object
          properties:
            message:
              type: string
            task:
              type: object
      403:
        description: Forbidden – must be project owner or admin
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
    task, err = _get_task_or_404(task_id)
    if err:
        return err

    role = get_project_role(user_id, task.project_id)
    if role not in _WRITE_ROLES:
        return jsonify({"error": "Forbidden", "message": "Only the project owner or admin can update tasks"}), 403

    data = request.get_json(silent=True, force=True) or {}

    if "title" in data:
        task.title = data["title"].strip()
    if "description" in data:
        task.description = data["description"]
    if "status" in data:
        if data["status"] not in VALID_STATUSES:
            return jsonify({"error": "Bad Request", "message": f"Invalid status. Must be one of: {', '.join(sorted(VALID_STATUSES))}"}), 400
        task.status = data["status"]
    if "priority" in data:
        if data["priority"] not in VALID_PRIORITIES:
            return jsonify({"error": "Bad Request", "message": f"priority must be one of: {', '.join(sorted(VALID_PRIORITIES))}"}), 400
        task.priority = data["priority"]
    if "due_date" in data:
        from datetime import date
        try:
            task.due_date = date.fromisoformat(data["due_date"]) if data["due_date"] else None
        except ValueError:
            return jsonify({"error": "Bad Request", "message": "Invalid due_date format. Use YYYY-MM-DD"}), 400
    if "assigned_to" in data:
        if data["assigned_to"]:
            try:
                new_assignee = int(data["assigned_to"])
            except ValueError:
                return jsonify({"error": "Bad Request", "message": "Invalid assigned_to format"}), 400
            project_obj = Project.query.get(task.project_id)
            err = _assert_is_project_member(new_assignee, task.project_id, project_obj)
            if err:
                return err
            task.assigned_to = new_assignee
        else:
            task.assigned_to = None

    log = Log(
        action="UPDATE",
        entity="Task",
        entity_id=task.id,
        details=f"Task '{task.title}' updated",
        user_id=user_id,
    )
    db.session.add(log)
    db.session.commit()

    return jsonify({"message": "Task updated successfully", "task": task.to_dict()}), 200


# ─── DELETE /api/tasks/<id> ───────────────────────────────────────────────────

@tasks_bp.route("/<int:task_id>", methods=["DELETE"])
@auth_required
def delete_task(task_id):
    """
    Delete a task.
    Accessible by: admin, project owner. Members → 403.
    ---
    tags:
      - Tasks
    security:
      - Bearer: []
    parameters:
      - in: path
        name: task_id
        type: string
        required: true
    responses:
      200:
        description: Task deleted
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
    task, err = _get_task_or_404(task_id)
    if err:
        return err

    role = get_project_role(user_id, task.project_id)
    if role not in _WRITE_ROLES:
        return jsonify({"error": "Forbidden", "message": "Only the project owner or admin can delete tasks"}), 403

    log = Log(
        action="DELETE_TASK",
        entity="Task",
        entity_id=task.id,
        details=f"Task '{task.title}' deleted from project {task.project_id}",
        user_id=user_id,
    )
    db.session.add(log)
    db.session.delete(task)
    db.session.commit()

    return jsonify({"message": "Task deleted successfully"}), 200
