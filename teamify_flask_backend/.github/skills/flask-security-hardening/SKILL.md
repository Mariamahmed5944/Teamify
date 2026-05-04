---
name: flask-security-hardening
description: 'Implement security, audit logging, payload/file encryption, hashing-based integrity, and login anomaly detection in a Flask + SQLAlchemy backend. Use when the user asks to add LoginLog, admin audit endpoints, Fernet encryption for messages/comments, secure file upload/download with SHA-256 verification, or anomaly/alerting on failed logins.'
argument-hint: '[feature subset, e.g. "logs+alerts" or "all"]'
---

# Flask Security Hardening

A reusable workflow for adding production-grade security primitives to a Flask + SQLAlchemy + Flask-Migrate project: audit logging, symmetric payload encryption, encrypted-at-rest file storage with hash integrity checks, and brute-force anomaly detection — exposed via admin-only endpoints.

## When to Use

Trigger this skill when the user asks for any of:

- Login/audit logging (`LoginLog`, `/admin/logs`)
- Field-level encryption for messages, comments, or PII (Fernet)
- Encrypted file upload + SHA-256 integrity verification on download
- Failed-login anomaly detection / brute-force alerts (`Alert`, `/admin/alerts`)
- "Hashing vs. encryption" documentation or a security architecture diagram

If the user lists several of these together (as in a security epic), implement all of them as one cohesive change set.

## Prerequisites Check

Before writing code, verify the project has:

1. `Flask`, `flask_sqlalchemy`, `flask_migrate`, `flask_jwt_extended` configured (look in `app.py` and `models/__init__.py`).
2. An existing admin role check decorator (commonly `middleware/auth.py`). If absent, add one that requires `User.role == "admin"`.
3. A `.env` loader (`python-dotenv` or `Config` reading `os.getenv`). Encryption keys MUST come from env, never hardcoded.
4. `cryptography` and `python-magic` (or fallback) in `requirements.txt`. Add if missing.

If any prerequisite is missing, install/scaffold it before proceeding.

## Procedure

Follow these steps in order. Each step is independently testable.

### Step 1 — Key management & utilities

Create `utils/crypto.py` with:

- `get_fernet()` — lazily builds a `Fernet` from `FERNET_KEY` env var; raises a clear error if missing.
- `encrypt_text(plaintext: str) -> str` and `decrypt_text(token: str) -> str`.
- `encrypt_bytes(data: bytes) -> bytes` and `decrypt_bytes(token: bytes) -> bytes`.
- `sha256_hex(data: bytes) -> str` for integrity hashing.

Also add a one-shot CLI helper `scripts/generate_fernet_key.py` that prints `Fernet.generate_key().decode()` so the user can populate `.env`. Document the env var in `.env.example`.

See [crypto patterns](./references/crypto-patterns.md) for the canonical implementation.

### Step 2 — Models

Create the following SQLAlchemy models under `models/`. Wire each into `models/__init__.py` if the project re-exports models there, then generate a migration with `flask db migrate -m "..."` and apply with `flask db upgrade`.

- **`models/login_log.py`** → `LoginLog(id, user_id NULLABLE FK→users.id, status ENUM('success','fail'), timestamp, ip_address, device_info)`. Index on `(ip_address, timestamp)` and `(user_id, timestamp)` for fast anomaly queries.
- **`models/alert.py`** → `Alert(id, type, description, timestamp, resolved BOOLEAN default False, resolved_at NULLABLE, resolved_by NULLABLE FK→users.id)`. Index `(resolved, timestamp)`.
- **`models/file_metadata.py`** → `FileMetadata(id, owner_id FK→users.id, original_filename, mime_type, size_bytes, encrypted_path, sha256_hash, created_at)`.
- **Encrypted comment field** → either a new `models/task_comment.py` with a `_content_encrypted` column + a `content` Python `@property` that transparently encrypts/decrypts, OR retrofit an existing `Message`/`Comment` model the same way. Never expose `_content_encrypted` in serializers.

See [model patterns](./references/model-patterns.md) for the transparent-encryption property pattern.

### Step 3 — Auth flow integration (logging hook)

In the existing `routes/auth.py` login handler:

1. On every login attempt — success or failure — append a `LoginLog` row with `request.remote_addr` and `request.headers.get('User-Agent', '')[:512]`.
2. Commit the log even when the auth itself fails (use a `try/except` so a logging failure never blocks the auth response).
3. Immediately after a `fail` log is written, call `check_login_anomalies(ip)` (Step 5) synchronously — it is cheap and gives instant alerting without a scheduler dependency.

### Step 4 — Secure file upload/download

Create `routes/files.py` with:

- `POST /api/files` (JWT-required, `multipart/form-data`):
  1. Validate MIME and size against an allowlist (e.g. ≤ 10 MB; reject executables).
  2. Read raw bytes → compute `sha256_hex` of the **original** bytes.
  3. Encrypt bytes with `encrypt_bytes`.
  4. Write to `UPLOAD_DIR/<uuid4>.enc` with `os.open(..., O_WRONLY|O_CREAT|O_EXCL, 0o600)` to avoid path traversal/clobbering.
  5. Persist `FileMetadata` row; return its id + original filename.
- `GET /api/files/<id>` (JWT-required, owner or admin only):
  1. Load metadata, read encrypted bytes, `decrypt_bytes`.
  2. Recompute SHA-256 and compare to stored hash with `hmac.compare_digest`.
  3. On mismatch → write an `Alert(type='file_integrity_failure')` and return HTTP 409. Do NOT return the file.
  4. On match → `send_file(BytesIO(plain), download_name=metadata.original_filename, mimetype=metadata.mime_type)`.

`UPLOAD_DIR` comes from env (`UPLOAD_DIR`, default `./instance/uploads`). Ensure the directory exists at app startup and is excluded from version control.

### Step 5 — Anomaly detection

Add `services/anomaly.py` with `check_login_anomalies(ip: str, window_minutes: int = 5, threshold: int = 5) -> Alert | None`:

- Count `LoginLog` rows where `status='fail'` AND `ip_address=ip` AND `timestamp >= now - window`.
- If count ≥ threshold, look up whether an *unresolved* `Alert` of `type='brute_force_login'` already exists for that IP within the window (dedupe). If not, create one with a description like `"5 failed logins from <ip> in 5 minutes"`.
- Return the created `Alert` (or `None`).

Optionally register a periodic job in `services/scheduler.py` that scans the last 5 minutes across all IPs — but the inline call from Step 3 is the primary trigger.

### Step 6 — Admin endpoints

Create `routes/admin.py` (or extend an existing admin blueprint), all guarded by an `@admin_required` decorator (reuse the project's role check):

- `GET /admin/logs?page=1&per_page=50&status=&ip=&user_id=` — paginated `LoginLog` list, newest first. Use `db.paginate(...)` and return `{items, page, per_page, total, pages}`.
- `GET /admin/alerts?page=1&per_page=50&resolved=false&type=` — paginated `Alert` list.
- `PATCH /admin/alerts/<id>/resolve` — sets `resolved=True`, `resolved_at=now()`, `resolved_by=current_user`.

Register the blueprint in `app.py`'s `create_app()`.

### Step 7 — Documentation

Add (or append to) `docs/SECURITY.md` containing:

- A "Hashing vs. Encryption" section — see [docs template](./references/security-doc-template.md).
- The Mermaid architecture flowchart from the same template.
- A "Key rotation" subsection explaining that rotating `FERNET_KEY` requires a `MultiFernet` migration step.

### Step 8 — Tests

Add tests under the project's existing test layout (`test_*.py` at repo root in this codebase):

- Round-trip: encrypt → decrypt returns original (text and bytes).
- Tampered ciphertext raises `InvalidToken`.
- Login failures create `LoginLog` rows with correct IP/UA.
- 5 failed logins from one IP within the window create exactly one `Alert` (idempotent).
- File upload persists an encrypted file (bytes on disk ≠ original) and download returns identical bytes.
- File integrity check rejects a tampered on-disk file with HTTP 409.
- `/admin/logs` and `/admin/alerts` return 403 for non-admin users.

## Quality Checklist

Before declaring the work complete, verify:

- [ ] `FERNET_KEY` is read from env; absence raises a startup-time error, not a runtime 500.
- [ ] No plaintext sensitive content is ever logged (scrub `request.json` from error logs).
- [ ] Hash comparison uses `hmac.compare_digest`, never `==`.
- [ ] File paths are server-generated UUIDs — the client never controls the on-disk path.
- [ ] All admin endpoints reject non-admin JWTs with 403, and unauthenticated requests with 401.
- [ ] Anomaly detection is deduplicated (one alert per IP per window, not one per failed attempt).
- [ ] A migration was generated and `flask db upgrade` runs cleanly.
- [ ] `.env.example` documents every new env var (`FERNET_KEY`, `UPLOAD_DIR`).

## References

- [crypto-patterns.md](./references/crypto-patterns.md) — Fernet utility code and key-rotation guidance
- [model-patterns.md](./references/model-patterns.md) — transparent-encryption property pattern and model skeletons
- [security-doc-template.md](./references/security-doc-template.md) — Hashing vs. Encryption explainer + Mermaid diagram
