"""Secure file upload/download with at-rest encryption and SHA-256 integrity."""
from __future__ import annotations

import io
import os
import uuid
from datetime import datetime, timezone

from flask import Blueprint, current_app, jsonify, request, send_file
from flask_jwt_extended import get_jwt_identity

from middleware.auth import auth_required
from models import db
from models.alert import Alert
from models.file_metadata import FileMetadata
from models.user import User
from utils.crypto import (
    InvalidToken,
    decrypt_bytes,
    encrypt_bytes,
    sha256_hex,
    verify_hash,
)

files_bp = Blueprint("files", __name__, url_prefix="/api/files")

# Allowlist of MIME types we accept. Adjust to your domain.
ALLOWED_MIME_PREFIXES = ("image/", "application/pdf", "text/")
MAX_UPLOAD_BYTES = 10 * 1024 * 1024  # 10 MB


def _upload_dir() -> str:
    path = os.getenv("UPLOAD_DIR", os.path.join("instance", "uploads"))
    os.makedirs(path, exist_ok=True)
    return path


def _is_allowed_mime(mime: str) -> bool:
    return any(mime.startswith(p) for p in ALLOWED_MIME_PREFIXES)


# ─── POST /api/files ─────────────────────────────────────────────────────────

@files_bp.route("", methods=["POST"])
@auth_required
def upload_file():
    """
    Upload a file. The bytes are SHA-256 hashed (original) and stored
    Fernet-encrypted on disk.
    ---
    tags: [Files]
    security: [{Bearer: []}]
    consumes: [multipart/form-data]
    parameters:
      - {in: formData, name: file, type: file, required: true}
    responses:
    responses:
      201:
        description: File stored
        schema:
          type: object
          properties:
            message:
              type: string
            file:
              type: object
      400:
        description: Validation error
        schema:
          type: object
          properties:
            error:
              type: string
      413:
        description: File too large
        schema:
          type: object
          properties:
            error:
              type: string
      415:
        description: Unsupported media type
        schema:
          type: object
          properties:
            error:
              type: string
    """
    if "file" not in request.files:
        return jsonify({"error": "Missing 'file' part"}), 400

    upload = request.files["file"]
    if not upload or not upload.filename:
        return jsonify({"error": "Empty file"}), 400

    raw = upload.read()
    if not raw:
        return jsonify({"error": "Empty file"}), 400
    if len(raw) > MAX_UPLOAD_BYTES:
        return jsonify({"error": "File exceeds 10 MB limit"}), 413

    mime = upload.mimetype or "application/octet-stream"
    if not _is_allowed_mime(mime):
        return jsonify({"error": f"Unsupported media type: {mime}"}), 415

    # 1. Hash ORIGINAL bytes
    digest = sha256_hex(raw)

    # 2. Encrypt
    try:
        ciphertext = encrypt_bytes(raw)
    except RuntimeError as exc:
        return jsonify({"error": str(exc)}), 500

    # 3. Write to a server-generated path (no client-controlled names)
    file_id = uuid.uuid4()
    enc_filename = f"{file_id}.enc"
    enc_path = os.path.join(_upload_dir(), enc_filename)
    # O_EXCL prevents clobbering an existing file with the same name.
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    fd = os.open(enc_path, flags, 0o600)
    try:
        with os.fdopen(fd, "wb") as fh:
            fh.write(ciphertext)
    except Exception:
        # Make sure no partial file is left behind
        try:
            os.unlink(enc_path)
        except OSError:
            pass
        raise

    # 4. Persist metadata
    try:
        owner_id = int(get_jwt_identity())
    except (ValueError, TypeError):
        os.unlink(enc_path)
        return jsonify({"error": "Invalid token identity"}), 401

    meta = FileMetadata(
        owner_id=owner_id,
        original_filename=os.path.basename(upload.filename)[:255],
        mime_type=mime[:127],
        size_bytes=len(raw),
        encrypted_path=enc_path,
        sha256_hash=digest,
        created_at=datetime.now(timezone.utc),
    )
    db.session.add(meta)
    db.session.commit()

    return jsonify({"message": "File stored", "file": meta.to_dict()}), 201


# ─── GET /api/files/<id> ─────────────────────────────────────────────────────

@files_bp.route("/<file_id>", methods=["GET"])
@auth_required
def download_file(file_id: str):
    """
    Download a file. The on-disk ciphertext is decrypted and the SHA-256 of the
    plaintext is verified against the hash stored at upload time.  A mismatch
    raises a `file_integrity_failure` Alert and returns HTTP 409.
    ---
    tags: [Files]
    security: [{Bearer: []}]
    parameters:
      - {in: path, name: file_id, type: string, required: true}
    responses:
    responses:
      200:
        description: Decrypted file stream
        produces:
          - application/octet-stream
        schema:
          type: file
      403:
        description: Not the owner
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
      409:
        description: Integrity check failed
        schema:
          type: object
          properties:
            error:
              type: string
    """
    try:
        fid = int(file_id)
    except (ValueError, AttributeError):
        return jsonify({"error": "Invalid file_id"}), 400

    meta = FileMetadata.query.filter_by(id=fid).first()
    if not meta:
        return jsonify({"error": "Not Found"}), 404

    # Owner-or-admin only
    try:
        caller_id = int(get_jwt_identity())
    except (ValueError, TypeError):
        return jsonify({"error": "Invalid token identity"}), 401

    caller = User.query.filter_by(id=caller_id).first()
    is_admin = bool(caller and caller.role == "admin")
    if meta.owner_id != caller_id and not is_admin:
        return jsonify({"error": "Forbidden"}), 403

    # Read ciphertext from disk
    try:
        with open(meta.encrypted_path, "rb") as fh:
            ciphertext = fh.read()
    except FileNotFoundError:
        # The encrypted file is gone but the row exists → integrity failure.
        _raise_integrity_alert(meta, reason="encrypted file missing on disk")
        return jsonify({"error": "Integrity check failed"}), 409

    # Decrypt
    try:
        plaintext = decrypt_bytes(ciphertext)
    except InvalidToken:
        _raise_integrity_alert(meta, reason="ciphertext failed Fernet validation")
        return jsonify({"error": "Integrity check failed"}), 409

    # Verify SHA-256 (constant-time)
    if not verify_hash(meta.sha256_hash, plaintext):
        _raise_integrity_alert(meta, reason="SHA-256 hash mismatch on download")
        return jsonify({"error": "Integrity check failed"}), 409

    return send_file(
        io.BytesIO(plaintext),
        mimetype=meta.mime_type,
        as_attachment=True,
        download_name=meta.original_filename,
    )


def _raise_integrity_alert(meta: FileMetadata, *, reason: str) -> None:
    """Persist a tamper-detection alert. Never raises."""
    try:
        alert = Alert(
            type="file_integrity_failure",
            description=(
                f"Integrity check failed for file {meta.id} "
                f"(owner={meta.owner_id}, name={meta.original_filename}): {reason}"
            ),
        )
        db.session.add(alert)
        db.session.commit()
    except Exception:
        db.session.rollback()
        try:
            current_app.logger.exception("Failed to write integrity alert")
        except Exception:
            pass
