"""End-to-end test of EVERY backend endpoint via Flask's test client.

Covers:
  Health, Auth (register/login/me/refresh/logout/forgot/verify-otp/reset),
  Users (profile GET/PUT, admin-dashboard),
  Projects (CRUD + members),
  Tasks (CRUD + status patch),
  AI (suggest-priority/suggest-deadline/assign/delay/workload),
  Stats (project/global/workload-overview),
  Reminders, Logs (my/all),
  Notifications (list/unread-count/mark-all-read/single-read),
  Dashboard, Search (users/projects),
  Admin (logs/alerts/resolve),
  Comments (POST/GET, encrypted),
  Files (POST/GET, encrypted + sha256).

Run: .\.venv\Scripts\python.exe test_all_endpoints.py
"""
from __future__ import annotations

import hashlib
import io
import os
import secrets
import sys
import uuid

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app
from models import db
from models.alert import Alert
from models.user import User
from models.notification import Notification
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


def hit(client, method, path, *, expect, headers=None, json=None, data=None,
        content_type=None, name=None):
    """Issue a request and assert status code; return parsed json (if any)."""
    label = name or f"{method.upper()} {path} -> {expect}"
    kwargs = {}
    if headers:
        kwargs["headers"] = headers
    if json is not None:
        kwargs["json"] = json
    if data is not None:
        kwargs["data"] = data
    if content_type is not None:
        kwargs["content_type"] = content_type
    rv = getattr(client, method)(path, **kwargs)
    ok = rv.status_code == expect
    check(label, ok, f"got {rv.status_code} body={rv.get_data(as_text=True)[:200]}")
    try:
        return rv, rv.get_json(silent=True) or {}
    except Exception:
        return rv, {}


def main() -> int:
    app = create_app()
    bcrypt = Bcrypt(app)
    client = app.test_client()
    suffix = secrets.token_hex(3)

    admin_email = f"admin_{suffix}@test.local"
    user_email = f"user_{suffix}@test.local"
    other_email = f"other_{suffix}@test.local"
    password = "Passw0rd1"

    # ─── Setup users directly ────────────────────────────────────────────────
    section("Setup")
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
        db.session.commit()
        admin_id = str(admin.id)
        user_id = str(user.id)
    print(f"  admin={admin_id}  user={user_id}")

    # ─── Health ──────────────────────────────────────────────────────────────
    section("Health")
    hit(client, "get", "/api/health", expect=200)

    # ─── Auth ────────────────────────────────────────────────────────────────
    section("Auth")
    # Register a fresh "other" account so duplicate-email path is also tested
    reg = {
        "display_name": f"other_{suffix}",
        "email": other_email,
        "password": password,
        "full_name": "Other User",
        "user_type": "freelancer",
        "professional_field": "Designer",
        "experience_level": "Intermediate",
        "availability": "Full Time",
        "skills": "UI,UX",
    }
    hit(client, "post", "/api/auth/register", json=reg, expect=201,
        name="register new user 201")
    hit(client, "post", "/api/auth/register", json=reg, expect=409,
        name="register duplicate -> 409")

    _, body = hit(client, "post", "/api/auth/login",
                  json={"email": user_email, "password": password}, expect=200,
                  name="login user 200")
    user_token = body.get("access_token", "")
    refresh_token = body.get("refresh_token", "")
    user_h = {"Authorization": f"Bearer {user_token}"}

    _, body = hit(client, "post", "/api/auth/login",
                  json={"email": admin_email, "password": password}, expect=200,
                  name="login admin 200")
    admin_token = body.get("access_token", "")
    admin_h = {"Authorization": f"Bearer {admin_token}"}

    hit(client, "post", "/api/auth/login",
        json={"email": user_email, "password": "WRONG"}, expect=401,
        name="login wrong password -> 401")

    hit(client, "get", "/api/auth/me", headers=user_h, expect=200)

    if refresh_token:
        hit(client, "post", "/api/auth/refresh",
            headers={"Authorization": f"Bearer {refresh_token}"}, expect=200,
            name="refresh token 200")

    hit(client, "post", "/api/auth/logout", headers=user_h, expect=200)

    # OTP flow (forgot -> verify -> reset). Tolerate 400/404 if the DB lacks
    # OTP support; we only check the route is reachable, not the side effects.
    rv, _ = hit(client, "post", "/api/auth/forgot-password",
                json={"email": user_email}, expect=200,
                name="forgot-password 200")
    hit(client, "post", "/api/auth/verify-otp",
        json={"email": user_email, "otp": "000000"}, expect=400,
        name="verify-otp wrong -> 400")
    hit(client, "post", "/api/auth/reset-password",
        json={"email": user_email, "otp": "000000", "new_password": "NewPass1!"},
        expect=400, name="reset-password wrong otp -> 400")

    # Re-login (since we logged out)
    _, body = hit(client, "post", "/api/auth/login",
                  json={"email": user_email, "password": password}, expect=200,
                  name="re-login user 200")
    user_token = body.get("access_token", "")
    user_h = {"Authorization": f"Bearer {user_token}"}

    # ─── Users ───────────────────────────────────────────────────────────────
    section("Users")
    hit(client, "get", "/api/users/profile", headers=user_h, expect=200)
    hit(client, "put", "/api/users/profile", headers=user_h,
        json={"full_name": "Updated", "skills": "React,Node"}, expect=200)
    hit(client, "get", "/api/users/admin-dashboard", headers=admin_h, expect=200)
    hit(client, "get", "/api/users/admin-dashboard", headers=user_h, expect=403,
        name="non-admin admin-dashboard -> 403")

    # ─── Projects ────────────────────────────────────────────────────────────
    section("Projects")
    _, body = hit(client, "post", "/api/projects", headers=user_h, expect=201,
                  json={"name": f"proj_{suffix}", "description": "d",
                        "status": "active",
                        "start_date": "2025-01-01", "end_date": "2025-12-31"},
                  name="create project 201")
    project_id = body.get("project", {}).get("id", "")
    hit(client, "get", "/api/projects", headers=user_h, expect=200)
    hit(client, "get", f"/api/projects/{project_id}", headers=user_h, expect=200)
    hit(client, "put", f"/api/projects/{project_id}", headers=user_h,
        json={"description": "updated"}, expect=200)
    hit(client, "get", f"/api/projects/{project_id}/members", headers=user_h,
        expect=200)
    hit(client, "get", f"/api/projects/{uuid.uuid4()}", headers=user_h,
        expect=404, name="project 404")

    # ─── Tasks ───────────────────────────────────────────────────────────────
    section("Tasks")
    _, body = hit(client, "post", "/api/tasks", headers=user_h, expect=201,
                  json={"title": f"task_{suffix}", "project_id": project_id,
                        "priority": "high", "status": "pending",
                        "due_date": "2025-07-15"},
                  name="create task 201")
    task_id = body.get("task", {}).get("id", "")
    hit(client, "get", f"/api/tasks?project_id={project_id}", headers=user_h,
        expect=200)
    hit(client, "get", f"/api/tasks/{task_id}", headers=user_h, expect=200)
    hit(client, "patch", f"/api/tasks/{task_id}/status", headers=user_h,
        json={"status": "in_progress"}, expect=200)
    hit(client, "put", f"/api/tasks/{task_id}", headers=user_h,
        json={"title": "Updated", "priority": "medium"}, expect=200)
    hit(client, "get", f"/api/tasks/{uuid.uuid4()}", headers=user_h, expect=404,
        name="task 404")

    # ─── AI ──────────────────────────────────────────────────────────────────
    section("AI")
    hit(client, "post", "/api/ai/suggest-priority", headers=user_h, expect=200,
        json={"project_id": project_id, "title": "urgent fix",
              "due_date": "2025-07-10"})
    hit(client, "post", "/api/ai/suggest-deadline", headers=user_h, expect=200,
        json={"project_id": project_id, "priority": "high"})
    hit(client, "post", "/api/ai/assign", headers=user_h, expect=200,
        json={"project_id": project_id, "priority": "high"})
    hit(client, "post", "/api/ai/delay", headers=user_h, expect=200,
        json={"task_id": task_id})
    hit(client, "get", "/api/ai/workload", headers=user_h, expect=200)

    # ─── Stats / Reminders / Logs ────────────────────────────────────────────
    section("Stats / Reminders / Logs")
    hit(client, "get", f"/api/stats/project/{project_id}", headers=user_h,
        expect=200)
    hit(client, "get", "/api/stats/global", headers=admin_h, expect=200)
    hit(client, "get", "/api/stats/workload-overview", headers=admin_h, expect=200)
    hit(client, "get", "/api/reminders", headers=user_h, expect=200)
    hit(client, "get", "/api/logs/my", headers=user_h, expect=200)
    hit(client, "get", "/api/logs/all", headers=admin_h, expect=200)
    hit(client, "get", "/api/logs/all", headers=user_h, expect=403,
        name="non-admin /logs/all -> 403")

    # ─── Notifications ───────────────────────────────────────────────────────
    section("Notifications")
    # Seed a notification for the user so single-read works.
    with app.app_context():
        n = Notification(user_id=uuid.UUID(user_id), type="general",
                         title="hello", body="test")
        db.session.add(n)
        db.session.commit()
        notif_id = str(n.id)

    hit(client, "get", "/api/notifications", headers=user_h, expect=200)
    hit(client, "get", "/api/notifications/unread-count", headers=user_h,
        expect=200)
    hit(client, "patch", f"/api/notifications/{notif_id}/read", headers=user_h,
        expect=200)
    hit(client, "post", "/api/notifications/mark-all-read", headers=user_h,
        expect=200)

    # ─── Dashboard / Search ──────────────────────────────────────────────────
    section("Dashboard / Search")
    hit(client, "get", "/api/dashboard", headers=user_h, expect=200)
    hit(client, "get", f"/api/search/users?q=other_{suffix}", headers=user_h,
        expect=200)
    hit(client, "get", "/api/search/users?skill=React", headers=user_h, expect=200)
    hit(client, "get", "/api/search/users?user_type=freelancer", headers=user_h,
        expect=200)
    hit(client, "get", f"/api/search/projects?q=proj_{suffix}", headers=user_h,
        expect=200)

    # ─── Comments (encrypted) ────────────────────────────────────────────────
    section("Comments (encrypted)")
    secret = f"secret-{uuid.uuid4()}"
    hit(client, "post", f"/api/tasks/{task_id}/comments", headers=user_h,
        json={"content": secret}, expect=201, name="create comment 201")
    rv, body = hit(client, "get", f"/api/tasks/{task_id}/comments",
                   headers=user_h, expect=200, name="list comments 200")
    items = body.get("items") or body.get("comments") or []
    check("comment plaintext returned via API",
          any(secret in (c.get("content") or "") for c in items))

    # ─── Files (encrypted + sha256) ──────────────────────────────────────────
    section("Files (encrypted + sha256)")
    payload = b"PDF-DATA-" + os.urandom(2048)
    expected_sha = hashlib.sha256(payload).hexdigest()
    rv, body = hit(client, "post", "/api/files", headers=user_h, expect=201,
                   data={"file": (io.BytesIO(payload), "doc.pdf",
                                  "application/pdf")},
                   content_type="multipart/form-data",
                   name="upload pdf 201")
    file_id = body.get("id") or body.get("file", {}).get("id") or ""
    check("file id returned", bool(file_id))
    if file_id:
        rv = client.get(f"/api/files/{file_id}", headers=user_h)
        check("download file 200", rv.status_code == 200, str(rv.status_code))
        got_sha = hashlib.sha256(rv.data).hexdigest()
        check("downloaded sha256 matches plaintext", got_sha == expected_sha)
        # Admin can also download
        rv = client.get(f"/api/files/{file_id}", headers=admin_h)
        check("admin download any file 200", rv.status_code == 200)

    # ─── Admin: logs & alerts + 403 for non-admin ────────────────────────────
    section("Admin: logs & alerts")
    hit(client, "get", "/admin/logs", headers=user_h, expect=403,
        name="non-admin /admin/logs -> 403")
    hit(client, "get", "/admin/alerts", headers=user_h, expect=403,
        name="non-admin /admin/alerts -> 403")
    hit(client, "get", "/admin/logs", expect=401, name="anon /admin/logs -> 401")
    hit(client, "get", "/admin/logs?page=1&per_page=10", headers=admin_h,
        expect=200, name="admin /admin/logs 200")

    # Trigger brute-force to ensure /admin/alerts has data
    for i in range(6):
        client.post("/api/auth/login",
                    json={"email": user_email, "password": f"wrong-{i}"})
    rv, body = hit(client, "get", "/admin/alerts?page=1&per_page=20",
                   headers=admin_h, expect=200, name="admin /admin/alerts 200")
    items = body.get("items") or body.get("alerts") or []
    bf = [a for a in items if a.get("type") == "brute_force_login"]
    check("brute_force_login alert present after 6 failed logins", len(bf) >= 1)
    if bf:
        aid = bf[0].get("id")
        hit(client, "patch", f"/admin/alerts/{aid}/resolve", headers=admin_h,
            expect=200, name="admin resolve alert 200")

    # ─── Error cases ─────────────────────────────────────────────────────────
    section("Error cases")
    hit(client, "post", "/api/projects", headers=user_h, json={}, expect=400,
        name="project missing name -> 400")
    hit(client, "post", "/api/tasks", headers=user_h, json={}, expect=400,
        name="task missing fields -> 400")

    # ─── Cleanup ─────────────────────────────────────────────────────────────
    section("Cleanup")
    hit(client, "delete", f"/api/tasks/{task_id}", headers=user_h, expect=200,
        name="delete task 200")
    hit(client, "delete", f"/api/projects/{project_id}", headers=user_h,
        expect=200, name="delete project 200")

    # Wipe any rows referencing the test users so reruns stay clean.
    from models.log import Log as AuditLog
    from models.login_log import LoginLog
    with app.app_context():
        AuditLog.query.filter(
            AuditLog.user_id.in_([uuid.UUID(admin_id), uuid.UUID(user_id)])
        ).delete(synchronize_session=False)
        LoginLog.query.filter(
            LoginLog.user_id.in_([uuid.UUID(admin_id), uuid.UUID(user_id)])
        ).delete(synchronize_session=False)
        Notification.query.filter(
            Notification.user_id.in_([uuid.UUID(admin_id), uuid.UUID(user_id)])
        ).delete(synchronize_session=False)
        # Other test user (registered by HTTP register)
        other = User.query.filter_by(email=other_email).first()
        ids_to_del = [uuid.UUID(admin_id), uuid.UUID(user_id)]
        if other is not None:
            AuditLog.query.filter(AuditLog.user_id == other.id).delete(
                synchronize_session=False)
            LoginLog.query.filter(LoginLog.user_id == other.id).delete(
                synchronize_session=False)
            Notification.query.filter(Notification.user_id == other.id).delete(
                synchronize_session=False)
            ids_to_del.append(other.id)
        User.query.filter(User.id.in_(ids_to_del)).delete(
            synchronize_session=False)
        db.session.commit()
        print("  cleaned")

    # ─── Summary ─────────────────────────────────────────────────────────────
    print("\n" + "=" * 70)
    print(f"PASSED: {len(PASSED)}    FAILED: {len(FAILED)}")
    if FAILED:
        print("\nFailures:")
        for n, d in FAILED:
            print(f"  - {n}  ::  {d}")
        return 1
    print("All endpoint checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
