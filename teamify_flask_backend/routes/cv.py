"""
CV Routes  (/api/cv)

RBAC enforcement summary:
  POST   /api/cv                 – member creates/overwrites own CV
  GET    /api/cv/<id>            – member: own CV only | admin: any | guest: public CVs only
  PATCH  /api/cv/<id>            – member: own CV only | admin: any  | guest: 403
  GET    /api/cv/<id>/export/pdf – member: own CV only | admin: any  | guest: 403
                                   PDF delivered from RAM, never from disk.

IDOR protection:  every route resolves the CV's owner_id from the DB row
                  and compares it against the JWT identity before proceeding.
"""
from __future__ import annotations

import io
from functools import wraps

from flask import Blueprint, jsonify, request, send_file
from flask_jwt_extended import jwt_required, get_jwt_identity
from marshmallow import ValidationError

from app import limiter                          # module-level limiter (no circular import)
from middleware.auth import auth_required
from models import db
from models.cv import CV
from models.cv_download_token import CVDownloadToken
from models.user import User
from services.audit_log_service import log_security_event
from services.cv_ai_service import enhance_cv
from services.cv_pdf_service import build_cv_pdf
from validators.cv_validator import cv_create_schema

cv_bp = Blueprint("cv", __name__, url_prefix="/api/cv")


# ─── RBAC Helper ──────────────────────────────────────────────────────────────

def _resolve_caller() -> tuple[int, str]:
    """Return (user_id: int, role: str) for the current JWT identity."""
    uid  = int(get_jwt_identity())
    user = User.query.filter_by(id=uid).first()
    if not user:
        raise ValueError("User not found")
    return uid, user.role


def _can_write_cv(caller_id: int, caller_role: str, cv_owner_id: int) -> bool:
    """Returns True if the caller is allowed to create/update/delete this CV."""
    # SECURITY: admin has global write access; member only touches own CV; guest never writes.
    return caller_role == "admin" or (caller_role == "member" and caller_id == cv_owner_id)


def _can_read_cv(caller_id: int, caller_role: str, cv: CV) -> bool:
    """Returns True if the caller may read this CV (full detail)."""
    if caller_role == "admin":
        return True
    if caller_role == "member":
        return caller_id == cv.user_id
    # guest: only if the CV owner has set is_public = True
    if caller_role == "guest":
        return cv.is_public
    return False


# ─── POST /api/cv  — Create or replace own CV ─────────────────────────────────

@cv_bp.route("", methods=["POST"])
@jwt_required()
def create_or_update_cv():
    """
    Create (or fully replace) the authenticated user's CV.
    Runs AI enhancement (summary generation + relevance ranking) before saving.
    ---
    tags: [CV]
    security: [{Bearer: []}]
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
    responses:
      201:
        description: CV created / replaced successfully
      400:
        description: Validation error
      403:
        description: Guests cannot create CVs
    """
    try:
        caller_id, caller_role = _resolve_caller()
    except ValueError as exc:
        return jsonify({"error": "Unauthorized", "message": str(exc)}), 401

    # SECURITY: guests may never create or replace CVs
    if caller_role == "guest":
        return jsonify({"error": "Forbidden", "message": "Guests cannot create CVs."}), 403

    raw = request.get_json(silent=True, force=True) or {}

    # Validate + sanitize via Marshmallow (XSS stripped inside schema's @pre_load)
    try:
        data = cv_create_schema.load(raw)
    except ValidationError as err:
        return jsonify({"error": "Validation Error", "messages": err.messages}), 400

    # ── AI Enhancement ─────────────────────────────────────────────────────
    enhanced = enhance_cv(data)

    # ── Upsert: one CV per user ─────────────────────────────────────────────
    cv = CV.query.filter_by(user_id=caller_id).first()
    is_new = cv is None
    if is_new:
        cv = CV(user_id=caller_id)
        db.session.add(cv)

    cv.personal_info  = enhanced.get("personal_info", {})
    cv.summary        = enhanced.get("summary")
    cv.skills         = enhanced.get("skills", [])
    cv.experience     = enhanced.get("experience", [])
    cv.projects       = enhanced.get("projects", [])
    cv.education      = enhanced.get("education", [])
    cv.certifications = enhanced.get("certifications", [])
    cv.is_public      = enhanced.get("is_public", False)
    db.session.commit()

    log_security_event(
        "CV_GENERATED",
        user_id=caller_id,
        ip=request.remote_addr or "unknown",
        details={"cv_id": cv.id, "role": caller_role, "is_new": is_new},
    )

    return jsonify({"message": "CV saved successfully.", "cv": cv.to_dict()}), 201 if is_new else 200


# ─── GET /api/cv/<id>  — Read a CV ────────────────────────────────────────────

@cv_bp.route("/<int:cv_id>", methods=["GET"])
@jwt_required()
def get_cv(cv_id: int):
    """
    Retrieve a CV by ID.
    Members see only their own. Admins see any. Guests see public CVs only (redacted).
    ---
    tags: [CV]
    security: [{Bearer: []}]
    parameters:
      - in: path
        name: cv_id
        type: integer
        required: true
    responses:
      200:
        description: CV data
      403:
        description: Access denied (IDOR guard)
      404:
        description: CV not found
    """
    try:
        caller_id, caller_role = _resolve_caller()
    except ValueError as exc:
        return jsonify({"error": "Unauthorized", "message": str(exc)}), 401

    cv = CV.query.filter_by(id=cv_id).first()
    if not cv:
        return jsonify({"error": "Not Found", "message": "CV not found."}), 404

    # SECURITY: IDOR check — can this caller see this CV?
    if not _can_read_cv(caller_id, caller_role, cv):
        return jsonify({"error": "Forbidden", "message": "Access denied."}), 403

    # Guests receive a redacted public view
    public_only = (caller_role == "guest")
    return jsonify(cv.to_dict(public_only=public_only)), 200


# ─── PATCH /api/cv/<id>  — Partial update ────────────────────────────────────

@cv_bp.route("/<int:cv_id>", methods=["PATCH"])
@jwt_required()
def update_cv(cv_id: int):
    """
    Partially update a CV (merge patch).
    Only the fields supplied are overwritten; omitted fields are preserved.
    ---
    tags: [CV]
    security: [{Bearer: []}]
    parameters:
      - in: path
        name: cv_id
        type: integer
        required: true
    responses:
      200:
        description: CV updated
      403:
        description: Forbidden (not owner or guest)
      404:
        description: CV not found
    """
    try:
        caller_id, caller_role = _resolve_caller()
    except ValueError as exc:
        return jsonify({"error": "Unauthorized", "message": str(exc)}), 401

    cv = CV.query.filter_by(id=cv_id).first()
    if not cv:
        return jsonify({"error": "Not Found", "message": "CV not found."}), 404

    # SECURITY: IDOR + role guard
    if not _can_write_cv(caller_id, caller_role, cv.user_id):
        return jsonify({"error": "Forbidden", "message": "You cannot edit this CV."}), 403

    raw = request.get_json(silent=True, force=True) or {}

    # Validate only the supplied fields
    try:
        data = cv_create_schema.load(raw, partial=True)
    except ValidationError as err:
        return jsonify({"error": "Validation Error", "messages": err.messages}), 400

    # Merge patch: only overwrite fields that were explicitly submitted
    field_map = {
        "personal_info": "personal_info",
        "skills":        "skills",
        "experience":    "experience",
        "projects":      "projects",
        "education":     "education",
        "certifications":"certifications",
        "is_public":     "is_public",
    }
    for key, col in field_map.items():
        if key in data:
            setattr(cv, col, data[key])

    # Re-run AI ranking after any structural update
    if any(k in data for k in ("experience", "projects")):
        from services.cv_ai_service import rank_by_relevance
        ranked = rank_by_relevance(cv.to_dict())
        cv.experience = ranked["experience"]
        cv.projects   = ranked["projects"]

    db.session.commit()
    return jsonify({"message": "CV updated.", "cv": cv.to_dict()}), 200


# ─── GET /api/cv/<id>/export/pdf  — Secure PDF export ────────────────────────
#
# SECURITY: Rate-limited per IP (5 exports per minute) to prevent DoS /
# resource exhaustion from ReportLab's CPU-bound rendering loop.
# The PDF buffer lives entirely in RAM; no temp file is created.

@cv_bp.route("/<int:cv_id>/export/pdf", methods=["GET"])
@jwt_required()
@limiter.limit("5 per minute; 20 per hour")   # strict per-IP throttle on the expensive op
def export_cv_pdf(cv_id: int):
    """
    Generate and stream a CV as a PDF.
    Authentication + authorisation are verified BEFORE any rendering begins.
    PDF is served in-memory via send_file — never written to a public path.
    ---
    tags: [CV]
    security: [{Bearer: []}]
    parameters:
      - in: path
        name: cv_id
        type: integer
        required: true
    responses:
      200:
        description: PDF file download
        content:
          application/pdf:
            schema:
              type: string
              format: binary
      403:
        description: Forbidden (not owner, guest, or wrong role)
      404:
        description: CV not found
      429:
        description: Rate limit exceeded
    """
    try:
        caller_id, caller_role = _resolve_caller()
    except ValueError as exc:
        return jsonify({"error": "Unauthorized", "message": str(exc)}), 401

    # SECURITY: guests are explicitly blocked from PDF export
    if caller_role == "guest":
        log_security_event(
            "CV_EXPORT_DENIED",
            user_id=caller_id,
            ip=request.remote_addr or "unknown",
            severity="WARNING",
            details={"cv_id": cv_id, "reason": "guest role", "role": caller_role},
        )
        return jsonify({"error": "Forbidden", "message": "Guests cannot export PDFs."}), 403

    cv = CV.query.filter_by(id=cv_id).first()
    if not cv:
        return jsonify({"error": "Not Found", "message": "CV not found."}), 404

    # SECURITY: IDOR check — member may only export their own CV
    if not _can_write_cv(caller_id, caller_role, cv.user_id):
        log_security_event(
            "CV_EXPORT_DENIED",
            user_id=caller_id,
            ip=request.remote_addr or "unknown",
            severity="WARNING",
            details={"cv_id": cv_id, "owner_id": cv.user_id, "reason": "not owner"},
        )
        return jsonify({"error": "Forbidden", "message": "You cannot export this CV."}), 403

    # ── Build PDF in RAM ────────────────────────────────────────────────────
    pdf_buffer = build_cv_pdf(cv.to_dict())

    # Audit-log the successful export
    log_security_event(
        "CV_EXPORTED_PDF",
        user_id=caller_id,
        ip=request.remote_addr or "unknown",
        details={"cv_id": cv_id, "owner_id": cv.user_id, "role": caller_role},
    )

    owner_name = (cv.personal_info.get("full_name") or f"user_{cv.user_id}").replace(" ", "_")
    filename   = f"cv_{owner_name}.pdf"

    # SECURITY: Content-Disposition=attachment forces a download (no inline rendering).
    # X-Content-Type-Options is set globally in app.py (nosniff).
    return send_file(
        pdf_buffer,
        mimetype="application/pdf",
        as_attachment=True,
        download_name=filename,
    )


# ─── POST /api/cv/<id>/export  — Generate signed download link ───────────────

@cv_bp.route("/<int:cv_id>/export", methods=["POST"])
@jwt_required()
@limiter.limit("5 per minute")
def create_cv_download_link(cv_id: int):
    """
    Generate a time-limited signed download URL for a CV PDF.
    Returns a token valid for 15 minutes. Use GET /api/cv/download/<token>.
    ---
    tags: [CV]
    security: [{Bearer: []}]
    responses:
      201:
        description: Download link created
      403:
        description: Forbidden
      404:
        description: CV not found
    """
    try:
        caller_id, caller_role = _resolve_caller()
    except ValueError as exc:
        return jsonify({"error": "Unauthorized", "message": str(exc)}), 401

    if caller_role == "guest":
        return jsonify({"error": "Forbidden", "message": "Guests cannot export PDFs."}), 403

    cv = CV.query.filter_by(id=cv_id).first()
    if not cv:
        return jsonify({"error": "Not Found", "message": "CV not found."}), 404

    if not _can_write_cv(caller_id, caller_role, cv.user_id):
        log_security_event(
            "UNAUTHORIZED_CV_EXPORT_ATTEMPT",
            user_id=caller_id,
            ip=request.remote_addr or "unknown",
            severity="WARNING",
            details={"cv_id": cv_id, "owner_id": cv.user_id},
        )
        return jsonify({"error": "Forbidden", "message": "You cannot export this CV."}), 403

    token_obj = CVDownloadToken.create_token(user_id=caller_id, cv_id=cv_id)

    log_security_event(
        "CV_EXPORT_TOKEN_CREATED",
        user_id=caller_id,
        ip=request.remote_addr or "unknown",
        details={"cv_id": cv_id, "token_id": token_obj.id},
    )

    return jsonify({
        "message": "CV generated successfully",
        "download_url": f"/api/cv/download/{token_obj.token}",
        "expires_in": "15 minutes",
    }), 201


# ─── GET /api/cv/download/<token>  — Secure token-based PDF download ─────────

@cv_bp.route("/download/<string:token>", methods=["GET"])
@jwt_required()
@limiter.limit("10 per minute")
def download_cv_by_token(token: str):
    """
    Download a CV PDF using a signed token.
    Verifies token ownership, expiry, and single-use before streaming.
    ---
    tags: [CV]
    security: [{Bearer: []}]
    responses:
      200:
        description: PDF file download
      403:
        description: Token belongs to another user
      404:
        description: Invalid download link
      410:
        description: Download link expired
    """
    try:
        caller_id, caller_role = _resolve_caller()
    except ValueError as exc:
        return jsonify({"error": "Unauthorized", "message": str(exc)}), 401

    token_obj = CVDownloadToken.query.filter_by(token=token).first()
    if not token_obj:
        return jsonify({"error": "Not Found", "message": "Invalid download link"}), 404

    # SECURITY: ownership check — only the token creator can download
    if token_obj.user_id != caller_id and caller_role != "admin":
        log_security_event(
            "UNAUTHORIZED_CV_DOWNLOAD_ATTEMPT",
            user_id=caller_id,
            ip=request.remote_addr or "unknown",
            severity="WARNING",
            details={"token_id": token_obj.id, "owner_id": token_obj.user_id},
        )
        return jsonify({"error": "Forbidden", "message": "Forbidden"}), 403

    if token_obj.is_expired:
        return jsonify({"error": "Gone", "message": "Download link expired"}), 410

    if token_obj.used:
        return jsonify({"error": "Gone", "message": "Download link already used"}), 410

    cv = CV.query.filter_by(id=token_obj.cv_id).first()
    if not cv:
        return jsonify({"error": "Not Found", "message": "CV not found"}), 404

    # Mark token as consumed (single-use)
    token_obj.used = True
    db.session.commit()

    pdf_buffer = build_cv_pdf(cv.to_dict())

    log_security_event(
        "CV_DOWNLOADED",
        user_id=caller_id,
        ip=request.remote_addr or "unknown",
        details={"cv_id": cv.id, "token_id": token_obj.id},
    )

    owner_name = (cv.personal_info.get("full_name") or f"user_{cv.user_id}").replace(" ", "_")
    return send_file(
        pdf_buffer,
        mimetype="application/pdf",
        as_attachment=True,
        download_name=f"cv_{owner_name}.pdf",
    )

