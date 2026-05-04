"""Disputes endpoints — users file disputes, admins manage them."""
from datetime import datetime, timezone
from flask import Blueprint, request, jsonify
from flask_jwt_extended import get_jwt_identity
from middleware.auth import auth_required, admin_required
from models import db
from models.dispute import Dispute

disputes_bp = Blueprint("disputes", __name__, url_prefix="/api/disputes")


@disputes_bp.route("", methods=["POST"])
@auth_required
def file_dispute():
    """File a new dispute against another user.
    ---
    tags: [Disputes]
    security: [{Bearer: []}]
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required: [accused_id, subject, description]
          properties:
            accused_id: {type: integer}
            project_id: {type: integer}
            category: {type: string, enum: [payment, behaviour, quality, deadline, other]}
            subject: {type: string}
            description: {type: string}
    responses:
      201:
        description: Dispute filed
      400:
        description: Validation error
    """
    data = request.get_json(silent=True, force=True) or {}
    reporter_id = int(get_jwt_identity())

    accused_id  = data.get("accused_id")
    subject     = (data.get("subject") or "").strip()
    description = (data.get("description") or "").strip()
    category    = (data.get("category") or "other").strip()

    if not accused_id or not subject or not description:
        return jsonify({"error": "accused_id, subject, and description are required"}), 400
    if category not in Dispute.VALID_CATEGORIES:
        return jsonify({"error": f"category must be one of {sorted(Dispute.VALID_CATEGORIES)}"}), 400
    if int(accused_id) == reporter_id:
        return jsonify({"error": "You cannot file a dispute against yourself"}), 400

    dispute = Dispute(
        reporter_id=reporter_id,
        accused_id=int(accused_id),
        project_id=data.get("project_id"),
        category=category,
        subject=subject,
        description=description,
    )
    db.session.add(dispute)
    db.session.commit()
    return jsonify({"message": "Dispute filed successfully", "dispute": dispute.to_dict()}), 201


@disputes_bp.route("/my", methods=["GET"])
@auth_required
def my_disputes():
    """List disputes filed by or against the current user.
    ---
    tags: [Disputes]
    security: [{Bearer: []}]
    responses:
      200:
        description: List of disputes
    """
    user_id = int(get_jwt_identity())
    filed    = Dispute.query.filter_by(reporter_id=user_id).all()
    received = Dispute.query.filter_by(accused_id=user_id).all()
    return jsonify({
        "filed":    [d.to_dict() for d in filed],
        "received": [d.to_dict() for d in received],
    }), 200


@disputes_bp.route("", methods=["GET"])
@admin_required
def list_all_disputes():
    """List all disputes — admin only.
    ---
    tags: [Disputes]
    security: [{Bearer: []}]
    parameters:
      - {in: query, name: status, type: string}
      - {in: query, name: page, type: integer}
      - {in: query, name: per_page, type: integer}
    responses:
      200:
        description: Paginated disputes
    """
    page     = max(1, int(request.args.get("page", 1)))
    per_page = min(int(request.args.get("per_page", 20)), 100)
    q = Dispute.query
    status = request.args.get("status")
    if status and status in Dispute.VALID_STATUSES:
        q = q.filter(Dispute.status == status)
    p = q.order_by(Dispute.created_at.desc()).paginate(page=page, per_page=per_page, error_out=False)
    return jsonify({
        "items":    [d.to_dict() for d in p.items],
        "total":    p.total,
        "page":     p.page,
        "pages":    p.pages,
        "per_page": p.per_page,
    }), 200


@disputes_bp.route("/<int:dispute_id>", methods=["GET"])
@admin_required
def get_dispute(dispute_id):
    """Get a single dispute — admin only.
    ---
    tags: [Disputes]
    security: [{Bearer: []}]
    responses:
      200:
        description: Dispute detail
      404:
        description: Not found
    """
    d = db.session.get(Dispute, dispute_id)
    if not d:
        return jsonify({"error": "Dispute not found"}), 404
    return jsonify({"dispute": d.to_dict()}), 200


@disputes_bp.route("/<int:dispute_id>/status", methods=["PATCH"])
@admin_required
def update_dispute_status(dispute_id):
    """Update dispute status — admin only.
    ---
    tags: [Disputes]
    security: [{Bearer: []}]
    parameters:
      - in: body
        name: body
        schema:
          type: object
          properties:
            status: {type: string, enum: [open, under_review, resolved, dismissed]}
            resolution: {type: string}
    responses:
      200:
        description: Dispute updated
    """
    d = db.session.get(Dispute, dispute_id)
    if not d:
        return jsonify({"error": "Dispute not found"}), 404

    data   = request.get_json(silent=True, force=True) or {}
    status = (data.get("status") or "").strip()

    if status and status not in Dispute.VALID_STATUSES:
        return jsonify({"error": f"status must be one of {sorted(Dispute.VALID_STATUSES)}"}), 400

    if status:
        d.status = status
    if "resolution" in data:
        d.resolution = data["resolution"]
    if status in ("resolved", "dismissed"):
        d.resolved_by = int(get_jwt_identity())
        d.resolved_at = datetime.now(timezone.utc)

    db.session.commit()
    return jsonify({"message": "Dispute updated", "dispute": d.to_dict()}), 200
