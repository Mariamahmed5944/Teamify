"""End-to-end test of all new security endpoints via Flask's test client.

Exercises:
  - LoginLog written for both successful and failed logins
  - Brute-force anomaly detection -> Alert created
  - GET /admin/logs       (admin only, paginated)
  - GET /admin/alerts     (admin only, paginated)
  - PATCH /admin/alerts/<id>/resolve
  - 403 for non-admin on /admin/*
  - POST /api/files       (encrypts on disk, stores SHA-256)
  - GET  /api/files/<id>  (decrypts + verifies hash)
  - File-tamper -> 409 + Alert created
  - POST /api/tasks/<id>/comments  (encrypted at rest)
  - GET  /api/tasks/<id>/comments  (decrypted on read)
"""
from __future__ import annotations

import io
import os
import secrets
import sys
import uuid

# Make sure the project root is on sys.path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app
from models import db
from models.alert import Alert
from models.file_metadata import FileMetadata
from models.login_log import LoginLog
from models.project import Project
from models.task import Task
from models.task_comment import TaskComment
from models.user import User
from flask_bcrypt import Bcrypt


PASSED: list[str] = []
FAILED: list[tuple[str, str]] = []


def check(name: str, condition: bool, detail: str = "") -> None:
    if condition:
        print(f"  [PASS] {name}")
        PASSED.append(name)
    else:
        print(f"  [FAIL] {name}  {detail}")
        FAILED.append((name, detail))


def section(title: str) -> None:
    print(f"\n=== {title} ===")


def main() -> int:
    app = create_app()
    bcrypt = Bcrypt(app)
    client = app.test_client()

    # Unique suffix so reruns don't collide on unique constraints
    suffix = secrets.token_hex(3)
    admin_email = f"admin_{suffix}@test.local"
    user_email = f"user_{suffix}@test.local"
    password = "Passw0rd1"

    # ─── Set up users + a project + a task ────────────────────────────────────
    section("Setup: create admin, user, project, task")
    with app.app_context():
        admin = User(
            display_name=f"admin_{suffix}",
            email=admin_email,
            password=bcrypt.generate_password_hash(password).decode(),
            role="admin",
        )
        user = User(
            display_name=f"user_{suffix}",
            email=user_email,
            password=bcrypt.generate_password_hash(password).decode(),
            role="member",
        )
        db.session.add_all([admin, user])
        db.session.flush()

        project = Project(name=f"proj_{suffix}", user_id=user.id)
        db.session.add(project)
        db.session.flush()

        task = Task(title=f"task_{suffix}", project_id=project.id, assigned_to=user.id)
        db.session.add(task)
        db.session.commit()

        admin_id = str(admin.id)
        user_id = str(user.id)
        task_id = str(task.id)
        print(f"  admin={admin_id}  user={user_id}  task={task_id}")

    # ─── Login flow ───────────────────────────────────────────────────────────
    section("Auth: login (success + fail) writes LoginLog")
    rv = client.post("/api/auth/login", json={"email": admin_email, "password": password})
    check("admin login 200", rv.status_code == 200, f"got {rv.status_code} {rv.get_data(as_text=True)[:200]}")
    admin_token = rv.get_json().get("access_token") if rv.status_code == 200 else None

    rv = client.post("/api/auth/login", json={"email": user_email, "password": password})
    check("user login 200", rv.status_code == 200)
    user_token = rv.get_json().get("access_token") if rv.status_code == 200 else None

    # One deliberate failure to make sure failures are logged
    rv = client.post("/api/auth/login", json={"email": user_email, "password": "wrong"})
    check("bad password -> 401", rv.status_code == 401)

    with app.app_context():
        success_logs = LoginLog.query.filter_by(status="success").count()
        fail_logs = LoginLog.query.filter_by(status="fail").count()
        check("LoginLog has success rows", success_logs >= 2, f"have {success_logs}")
        check("LoginLog has fail rows", fail_logs >= 1, f"have {fail_logs}")

    # ─── Brute force -> Alert ────────────────────────────────────────────────
    section("Anomaly: 5 failed logins from same IP -> Alert(brute_force_login)")
    for i in range(5):
        client.post("/api/auth/login", json={"email": user_email, "password": f"wrong{i}"})

    with app.app_context():
        alert = (
            Alert.query.filter_by(type="brute_force_login")
            .order_by(Alert.timestamp.desc())
            .first()
        )
        check("brute-force Alert created", alert is not None,
              "no Alert(type=brute_force_login) found")
        if alert:
            print(f"    -> '{alert.description}'")

    # ─── Admin endpoints ─────────────────────────────────────────────────────
    section("Admin: /admin/logs and /admin/alerts (admin vs non-admin)")
    auth_admin = {"Authorization": f"Bearer {admin_token}"} if admin_token else {}
    auth_user = {"Authorization": f"Bearer {user_token}"} if user_token else {}

    rv = client.get("/admin/logs?per_page=5", headers=auth_admin)
    check("admin GET /admin/logs 200", rv.status_code == 200, str(rv.status_code))
    body = rv.get_json() if rv.status_code == 200 else {}
    check("logs paginated payload", isinstance(body, dict) and "items" in body and "total" in body)

    rv = client.get("/admin/logs", headers=auth_user)
    check("non-admin GET /admin/logs -> 403", rv.status_code == 403)

    rv = client.get("/admin/logs")
    check("anon GET /admin/logs -> 401", rv.status_code == 401)

    rv = client.get("/admin/alerts?resolved=false&per_page=5", headers=auth_admin)
    check("admin GET /admin/alerts 200", rv.status_code == 200)
    alerts_body = rv.get_json() if rv.status_code == 200 else {}
    alert_id = alerts_body["items"][0]["id"] if alerts_body.get("items") else None

    if alert_id:
        rv = client.patch(f"/admin/alerts/{alert_id}/resolve", headers=auth_admin)
        check("admin resolve alert 200", rv.status_code == 200)
        check("alert.resolved == True", rv.get_json().get("alert", {}).get("resolved") is True)

    rv = client.get("/admin/alerts", headers=auth_user)
    check("non-admin GET /admin/alerts -> 403", rv.status_code == 403)

    # ─── Encrypted comments ──────────────────────────────────────────────────
    section("Comments: encrypted at rest, decrypted on read")
    plain = "Top secret comment with PII: 555-12-1234"
    rv = client.post(
        f"/api/tasks/{task_id}/comments",
        json={"content": plain},
        headers=auth_user,
    )
    check("POST comment 201", rv.status_code == 201, str(rv.status_code))
    comment_id = rv.get_json().get("comment", {}).get("id") if rv.status_code == 201 else None

    with app.app_context():
        if comment_id:
            row = TaskComment.query.filter_by(id=uuid.UUID(comment_id)).first()
            check("ciphertext != plaintext in DB",
                  row is not None and row._content_encrypted != plain,
                  "stored value equals plaintext!")
            check("decrypted property == plaintext",
                  row is not None and row.content == plain)

    rv = client.get(f"/api/tasks/{task_id}/comments", headers=auth_user)
    check("GET comments 200", rv.status_code == 200)
    items = rv.get_json().get("items", []) if rv.status_code == 200 else []
    check("decrypted content returned via API",
          any(c.get("content") == plain for c in items),
          "plaintext not found in response")

    # ─── File upload + integrity ─────────────────────────────────────────────
    section("Files: upload (encrypted+hashed), download, tamper detection")
    payload = b"hello, this is the secret file contents! " * 10
    data = {"file": (io.BytesIO(payload), "secret.txt", "text/plain")}
    rv = client.post(
        "/api/files",
        data=data,
        headers=auth_user,
        content_type="multipart/form-data",
    )
    check("POST /api/files 201", rv.status_code == 201, str(rv.status_code))
    file_id = rv.get_json().get("file", {}).get("id") if rv.status_code == 201 else None
    sha_returned = rv.get_json().get("file", {}).get("sha256") if rv.status_code == 201 else None

    enc_path = None
    if file_id:
        with app.app_context():
            meta = FileMetadata.query.filter_by(id=uuid.UUID(file_id)).first()
            enc_path = meta.encrypted_path if meta else None
            disk_bytes = open(enc_path, "rb").read() if enc_path and os.path.exists(enc_path) else b""
            check("encrypted file exists on disk", bool(disk_bytes))
            check("disk bytes != plaintext (encrypted)", disk_bytes != payload)
            import hashlib
            check("stored SHA-256 matches plaintext",
                  sha_returned == hashlib.sha256(payload).hexdigest())

    rv = client.get(f"/api/files/{file_id}", headers=auth_user)
    check("GET /api/files/<id> 200", rv.status_code == 200, str(rv.status_code))
    check("download bytes == original plaintext", rv.data == payload)

    # Owner-or-admin enforcement: admin can also download
    rv = client.get(f"/api/files/{file_id}", headers=auth_admin)
    check("admin can download any file 200", rv.status_code == 200)

    # Tamper the on-disk encrypted file -> integrity check should fail with 409
    if enc_path and os.path.exists(enc_path):
        with open(enc_path, "rb") as fh:
            buf = bytearray(fh.read())
        # Flip a byte in the middle of the ciphertext to break the HMAC
        mid = len(buf) // 2
        buf[mid] = buf[mid] ^ 0xFF
        with open(enc_path, "wb") as fh:
            fh.write(buf)
        rv = client.get(f"/api/files/{file_id}", headers=auth_user)
        check("tampered file -> 409", rv.status_code == 409, str(rv.status_code))
        with app.app_context():
            tamper_alert = (
                Alert.query.filter_by(type="file_integrity_failure")
                .order_by(Alert.timestamp.desc())
                .first()
            )
            check("file_integrity_failure Alert created", tamper_alert is not None)

    # ─── Cleanup ──────────────────────────────────────────────────────────────
    section("Cleanup")
    from models.log import Log as AuditLog
    with app.app_context():
        TaskComment.query.filter_by(task_id=uuid.UUID(task_id)).delete()
        for fm in FileMetadata.query.filter_by(owner_id=uuid.UUID(user_id)).all():
            try:
                if fm.encrypted_path and os.path.exists(fm.encrypted_path):
                    os.unlink(fm.encrypted_path)
            except OSError:
                pass
            db.session.delete(fm)
        Task.query.filter_by(id=uuid.UUID(task_id)).delete()
        Project.query.filter_by(name=f"proj_{suffix}").delete()
        # Existing audit-Log table has FKs to users with no SET NULL; clear those first
        AuditLog.query.filter(
            AuditLog.user_id.in_([uuid.UUID(admin_id), uuid.UUID(user_id)])
        ).delete(synchronize_session=False)
        LoginLog.query.filter(
            LoginLog.user_id.in_([uuid.UUID(admin_id), uuid.UUID(user_id)])
        ).delete(synchronize_session=False)
        User.query.filter(
            User.id.in_([uuid.UUID(admin_id), uuid.UUID(user_id)])
        ).delete(synchronize_session=False)
        db.session.commit()
        print("  cleaned")

    # ─── Summary ──────────────────────────────────────────────────────────────
    print("\n" + "=" * 60)
    print(f"PASSED: {len(PASSED)}    FAILED: {len(FAILED)}")
    if FAILED:
        print("\nFailures:")
        for name, detail in FAILED:
            print(f"  - {name}: {detail}")
        return 1
    print("All endpoint checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
