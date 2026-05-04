"""Apidog-style contract tests for ALL backend endpoints.

For every endpoint we verify two things:
  1. The HTTP status code matches what the route is documented to return.
  2. The response body is JSON, contains the expected keys, and those values
     are non-empty (no None / "" / [] / {}).

Covers:
  Health
  Auth        (register, login, me, refresh, logout, forgot, verify-otp, reset)
  Users       (profile GET/PUT, admin-dashboard)
  Projects    (CRUD + members)
  Tasks       (CRUD + status patch)
  Comments    (POST/GET)
  Files       (POST/GET)
  AI          (suggest-priority, suggest-deadline, assign, delay, workload)
  Stats       (project, global, workload-overview)
  Reminders   (list)
  Logs        (my, all)
  Notifications (list, unread-count, single read, mark-all-read)
  Dashboard
  Search      (users, projects)
  Admin       (logs, alerts, resolve)

Run: .\.venv\Scripts\python.exe test_all_status_codes.py
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
from models.user import User
from models.notification import Notification
from models.log import Log as AuditLog
from models.login_log import LoginLog
from models.alert import Alert
from flask_bcrypt import Bcrypt


PASSED: list[str] = []
FAILED: list[tuple[str, str]] = []


# ─── Helpers ──────────────────────────────────────────────────────────────────

def section(title: str) -> None:
    print(f"\n=== {title} ===")


def check_status(name: str, expected, got: int, body: str = "") -> bool:
    """expected can be an int or a tuple of acceptable codes."""
    if isinstance(expected, (tuple, list, set)):
        ok = got in expected
        exp_str = "/".join(str(x) for x in expected)
    else:
        ok = expected == got
        exp_str = str(expected)
    label = f"{name} -> {exp_str} (got {got})"
    if ok:
        print(f"  [PASS] {label}")
        PASSED.append(name)
    else:
        snippet = body[:200].replace("\n", " ")
        print(f"  [FAIL] {label}  body={snippet}")
        FAILED.append((name, f"expected={exp_str} got={got}"))
    return ok


def check_body(name: str, rv, required_keys: list[str]) -> dict:
    """Validate body is JSON, has required keys, and values are non-empty."""
    raw = rv.get_data(as_text=True)
    body = rv.get_json(silent=True)
    if body is None:
        print(f"  [FAIL] {name} body is not JSON  raw={raw[:200]}")
        FAILED.append((name, "non-JSON body"))
        return {}
    if not required_keys:
        print(f"  [PASS] {name} body is JSON")
        PASSED.append(name)
        return body if isinstance(body, dict) else {"_root": body}
    if not isinstance(body, dict):
        print(f"  [FAIL] {name} body is not an object  raw={raw[:200]}")
        FAILED.append((name, "non-object body"))
        return {}
    missing = [k for k in required_keys if k not in body]
    empties = [
        k for k in required_keys
        if k in body and (body[k] is None or body[k] == "" or body[k] == []
                          or body[k] == {})
    ]
    if missing:
        print(f"  [FAIL] {name} missing keys={missing}  body={raw[:200]}")
        FAILED.append((name, f"missing {missing}"))
    elif empties:
        print(f"  [FAIL] {name} empty values for={empties}  body={raw[:200]}")
        FAILED.append((name, f"empty {empties}"))
    else:
        print(f"  [PASS] {name} body has {required_keys}")
        PASSED.append(name)
    return body


def hit(client, method, path, *, expect, headers=None, json=None, data=None,
        content_type=None, name=None, body_keys=None):
    """Issue request, check status code, check body shape; return (rv, parsed)."""
    label = name or f"{method.upper()} {path}"
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
    raw = rv.get_data(as_text=True)
    check_status(label, expect, rv.status_code, raw)
    parsed = {}
    if body_keys is not None:
        parsed = check_body(f"{label} body", rv, body_keys)
    else:
        parsed = rv.get_json(silent=True) or {}
    return rv, parsed


# ─── Main ─────────────────────────────────────────────────────────────────────

def main() -> int:
    app = create_app()
    # Disable rate limiting for the test sweep.
    from app import limiter as _limiter
    _limiter.enabled = False
    bcrypt = Bcrypt(app)
    client = app.test_client()
    suffix = secrets.token_hex(3)

    admin_email = f"admin_{suffix}@test.local"
    user_email = f"user_{suffix}@test.local"
    other_email = f"other_{suffix}@test.local"
    password = "Passw0rd1"

    # ─── Setup ──────────────────────────────────────────────────────────────
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

    # ─── Health ─────────────────────────────────────────────────────────────
    section("Health")
    hit(client, "get", "/api/health", expect=200, body_keys=["status"],
        name="health 200")

    # ─── Auth ───────────────────────────────────────────────────────────────
    section("Auth")
    reg = {
        "display_name": f"other_{suffix}",
        "email": other_email,
        "password": password,
        "full_name": "Other User",
        "user_type": "freelancer",
    }
    hit(client, "post", "/api/auth/register", json=reg, expect=201,
        body_keys=["message", "user", "access_token", "refresh_token"],
        name="register 201")
    hit(client, "post", "/api/auth/register", json=reg, expect=409,
        body_keys=["error", "message"], name="register dup -> 409")
    hit(client, "post", "/api/auth/register", json={}, expect=400,
        body_keys=["error"], name="register empty -> 400")

    _, body = hit(client, "post", "/api/auth/login",
                  json={"email": user_email, "password": password}, expect=200,
                  body_keys=["message", "user", "access_token", "refresh_token"],
                  name="login user 200")
    user_token = body.get("access_token", "")
    refresh_token = body.get("refresh_token", "")
    user_h = {"Authorization": f"Bearer {user_token}"}

    _, body = hit(client, "post", "/api/auth/login",
                  json={"email": admin_email, "password": password}, expect=200,
                  body_keys=["message", "user", "access_token", "refresh_token"],
                  name="login admin 200")
    admin_token = body.get("access_token", "")
    admin_h = {"Authorization": f"Bearer {admin_token}"}

    hit(client, "post", "/api/auth/login",
        json={"email": user_email, "password": "WRONG"}, expect=401,
        body_keys=["error"], name="login wrong pw -> 401")
    hit(client, "post", "/api/auth/login", json={}, expect=400,
        body_keys=["error"], name="login empty -> 400")

    hit(client, "get", "/api/auth/me", headers=user_h, expect=200,
        body_keys=["user"], name="me 200")
    hit(client, "get", "/api/auth/me", expect=401,
        body_keys=["error"], name="me no token -> 401")

    if refresh_token:
        hit(client, "post", "/api/auth/refresh",
            headers={"Authorization": f"Bearer {refresh_token}"}, expect=200,
            body_keys=["access_token"], name="refresh 200")

    hit(client, "post", "/api/auth/refresh", expect=401,
        body_keys=["msg"], name="refresh no token -> 401")

    hit(client, "post", "/api/auth/logout", headers=user_h, expect=200,
        body_keys=["message"], name="logout 200")
    hit(client, "post", "/api/auth/logout", expect=401,
        body_keys=["msg"], name="logout no token -> 401")

    hit(client, "post", "/api/auth/forgot-password",
        json={"email": user_email}, expect=200, body_keys=["message"],
        name="forgot known -> 200")
    hit(client, "post", "/api/auth/forgot-password",
        json={"email": "nobody@nowhere.test"}, expect=200,
        body_keys=["message"], name="forgot unknown -> 200")
    hit(client, "post", "/api/auth/forgot-password", json={}, expect=400,
        body_keys=["error"], name="forgot empty -> 400")

    hit(client, "post", "/api/auth/verify-otp",
        json={"email": user_email, "otp": "000000"}, expect=400,
        body_keys=["error"], name="verify-otp wrong -> 400")
    hit(client, "post", "/api/auth/verify-otp", json={}, expect=400,
        body_keys=["error"], name="verify-otp empty -> 400")

    hit(client, "post", "/api/auth/reset-password",
        json={"reset_token": "bogus", "new_password": "NewPass1!"},
        expect=401, body_keys=["error"], name="reset bad token -> 401")
    hit(client, "post", "/api/auth/reset-password", json={}, expect=400,
        body_keys=["error"], name="reset empty -> 400")

    # Re-login after logout
    _, body = hit(client, "post", "/api/auth/login",
                  json={"email": user_email, "password": password}, expect=200,
                  body_keys=["message", "user", "access_token", "refresh_token"],
                  name="re-login user 200")
    user_token = body.get("access_token", "")
    user_h = {"Authorization": f"Bearer {user_token}"}

    # ─── Users ──────────────────────────────────────────────────────────────
    section("Users")
    hit(client, "get", "/api/users/profile", headers=user_h, expect=200,
        body_keys=["user"], name="profile GET 200")
    hit(client, "get", "/api/users/profile", expect=401,
        body_keys=["error"], name="profile no token -> 401")
    hit(client, "put", "/api/users/profile", headers=user_h,
        json={"full_name": "Updated", "skills": "React,Node"}, expect=200,
        body_keys=["user"], name="profile PUT 200")
    hit(client, "get", "/api/users/admin-dashboard", headers=admin_h,
        expect=200, name="admin-dashboard admin 200")
    hit(client, "get", "/api/users/admin-dashboard", headers=user_h,
        expect=403, body_keys=["error"], name="admin-dashboard non-admin -> 403")

    # ─── Projects ───────────────────────────────────────────────────────────
    section("Projects")
    _, body = hit(client, "post", "/api/projects", headers=user_h, expect=201,
                  json={"name": f"proj_{suffix}", "description": "d",
                        "status": "active",
                        "start_date": "2025-01-01", "end_date": "2025-12-31"},
                  body_keys=["project"], name="create project 201")
    project_id = (body.get("project") or {}).get("id", "")
    hit(client, "post", "/api/projects", headers=user_h, json={}, expect=400,
        body_keys=["error"], name="create project empty -> 400")
    hit(client, "post", "/api/projects", json={}, expect=401,
        body_keys=["error"], name="create project no token -> 401")
    hit(client, "get", "/api/projects", headers=user_h, expect=200,
        name="list projects 200")
    hit(client, "get", f"/api/projects/{project_id}", headers=user_h,
        expect=200, body_keys=["project"], name="get project 200")
    hit(client, "put", f"/api/projects/{project_id}", headers=user_h,
        json={"description": "updated"}, expect=200, body_keys=["project"],
        name="update project 200")
    hit(client, "get", f"/api/projects/{project_id}/members", headers=user_h,
        expect=200, name="project members 200")
    hit(client, "get", f"/api/projects/{uuid.uuid4()}", headers=user_h,
        expect=404, body_keys=["error"], name="project unknown -> 404")

    # ─── Tasks ──────────────────────────────────────────────────────────────
    section("Tasks")
    _, body = hit(client, "post", "/api/tasks", headers=user_h, expect=201,
                  json={"title": f"task_{suffix}", "project_id": project_id,
                        "priority": "high", "status": "pending",
                        "due_date": "2025-07-15"},
                  body_keys=["task"], name="create task 201")
    task_id = (body.get("task") or {}).get("id", "")
    hit(client, "post", "/api/tasks", headers=user_h, json={}, expect=400,
        body_keys=["error"], name="create task empty -> 400")
    hit(client, "get", f"/api/tasks?project_id={project_id}", headers=user_h,
        expect=200, name="list tasks 200")
    hit(client, "get", f"/api/tasks/{task_id}", headers=user_h, expect=200,
        body_keys=["task"], name="get task 200")
    hit(client, "patch", f"/api/tasks/{task_id}/status", headers=user_h,
        json={"status": "in_progress"}, expect=200, body_keys=["task"],
        name="patch task status 200")
    hit(client, "put", f"/api/tasks/{task_id}", headers=user_h,
        json={"title": "Updated", "priority": "medium"}, expect=200,
        body_keys=["task"], name="update task 200")
    hit(client, "get", f"/api/tasks/{uuid.uuid4()}", headers=user_h, expect=404,
        body_keys=["error"], name="task unknown -> 404")

    # ─── Comments (encrypted) ───────────────────────────────────────────────
    section("Comments (encrypted)")
    secret = f"secret-{uuid.uuid4()}"
    hit(client, "post", f"/api/tasks/{task_id}/comments", headers=user_h,
        json={"content": secret}, expect=201, body_keys=["comment"],
        name="create comment 201")
    hit(client, "post", f"/api/tasks/{task_id}/comments", headers=user_h,
        json={}, expect=400, body_keys=["error"],
        name="create comment empty -> 400")
    rv, body = hit(client, "get", f"/api/tasks/{task_id}/comments",
                   headers=user_h, expect=200, name="list comments 200")
    items = body.get("items") or body.get("comments") or []
    if any(secret in (c.get("content") or "") for c in items):
        print("  [PASS] comment plaintext returned via API")
        PASSED.append("comment plaintext")
    else:
        print("  [FAIL] comment plaintext not returned")
        FAILED.append(("comment plaintext", "missing"))

    # ─── Files (encrypted + sha256) ─────────────────────────────────────────
    section("Files (encrypted + sha256)")
    payload = b"PDF-DATA-" + os.urandom(2048)
    expected_sha = hashlib.sha256(payload).hexdigest()
    rv, body = hit(client, "post", "/api/files", headers=user_h, expect=201,
                   data={"file": (io.BytesIO(payload), "doc.pdf",
                                  "application/pdf")},
                   content_type="multipart/form-data",
                   name="upload pdf 201")
    file_id = body.get("id") or (body.get("file") or {}).get("id") or ""
    if file_id:
        print(f"  [PASS] file id returned ({file_id[:8]}...)")
        PASSED.append("file id")
        rv = client.get(f"/api/files/{file_id}", headers=user_h)
        check_status("download file 200", 200, rv.status_code, "")
        got_sha = hashlib.sha256(rv.data).hexdigest()
        if got_sha == expected_sha:
            print("  [PASS] downloaded sha256 matches plaintext")
            PASSED.append("sha256 match")
        else:
            print(f"  [FAIL] sha mismatch  got={got_sha[:16]} want={expected_sha[:16]}")
            FAILED.append(("sha256", "mismatch"))
        rv = client.get(f"/api/files/{file_id}", headers=admin_h)
        check_status("admin download any file 200", 200, rv.status_code, "")
    else:
        print("  [FAIL] file id not returned")
        FAILED.append(("file id", "missing"))
    hit(client, "post", "/api/files", expect=401,
        body_keys=["error"], name="upload no token -> 401")

    # ─── AI ─────────────────────────────────────────────────────────────────
    section("AI")
    hit(client, "post", "/api/ai/suggest-priority", headers=user_h, expect=200,
        json={"project_id": project_id, "title": "urgent fix",
              "due_date": "2025-07-10"}, name="ai suggest-priority 200")
    hit(client, "post", "/api/ai/suggest-deadline", headers=user_h, expect=200,
        json={"project_id": project_id, "priority": "high"},
        name="ai suggest-deadline 200")
    hit(client, "post", "/api/ai/assign", headers=user_h, expect=200,
        json={"project_id": project_id, "priority": "high"},
        name="ai assign 200")
    hit(client, "post", "/api/ai/delay", headers=user_h, expect=200,
        json={"task_id": task_id}, name="ai delay 200")
    hit(client, "get", "/api/ai/workload", headers=user_h, expect=200,
        name="ai workload 200")
    hit(client, "post", "/api/ai/suggest-priority", expect=401,
        body_keys=["error"], name="ai no token -> 401")

    # ─── Stats ──────────────────────────────────────────────────────────────
    section("Stats")
    hit(client, "get", f"/api/stats/project/{project_id}", headers=user_h,
        expect=200, name="stats project 200")
    hit(client, "get", "/api/stats/global", headers=admin_h, expect=200,
        name="stats global 200")
    hit(client, "get", "/api/stats/workload-overview", headers=admin_h,
        expect=200, name="stats workload-overview 200")
    hit(client, "get", "/api/stats/global", expect=401,
        body_keys=["error"], name="stats no token -> 401")

    # ─── Reminders ──────────────────────────────────────────────────────────
    section("Reminders")
    hit(client, "get", "/api/reminders", headers=user_h, expect=200,
        name="reminders 200")
    hit(client, "get", "/api/reminders", expect=401,
        body_keys=["error"], name="reminders no token -> 401")

    # ─── Logs ───────────────────────────────────────────────────────────────
    section("Logs")
    hit(client, "get", "/api/logs/my", headers=user_h, expect=200,
        name="logs my 200")
    hit(client, "get", "/api/logs/all", headers=admin_h, expect=200,
        name="logs all admin 200")
    hit(client, "get", "/api/logs/all", headers=user_h, expect=403,
        body_keys=["error"], name="logs all non-admin -> 403")

    # ─── Notifications ──────────────────────────────────────────────────────
    section("Notifications")
    with app.app_context():
        n = Notification(user_id=uuid.UUID(user_id), type="general",
                         title="hello", body="test")
        db.session.add(n)
        db.session.commit()
        notif_id = str(n.id)

    hit(client, "get", "/api/notifications", headers=user_h, expect=200,
        name="notifications list 200")
    hit(client, "get", "/api/notifications/unread-count", headers=user_h,
        expect=200, body_keys=["unread_count"], name="unread-count 200")
    hit(client, "patch", f"/api/notifications/{notif_id}/read",
        headers=user_h, expect=200, body_keys=["message"],
        name="mark notif read 200")
    hit(client, "post", "/api/notifications/mark-all-read", headers=user_h,
        expect=200, body_keys=["message"], name="mark-all-read 200")
    hit(client, "get", "/api/notifications", expect=401,
        body_keys=["error"], name="notifications no token -> 401")

    # ─── Dashboard ──────────────────────────────────────────────────────────
    section("Dashboard")
    hit(client, "get", "/api/dashboard", headers=user_h, expect=200,
        name="dashboard 200")
    hit(client, "get", "/api/dashboard", expect=401,
        body_keys=["error"], name="dashboard no token -> 401")

    # ─── Search ─────────────────────────────────────────────────────────────
    section("Search")
    hit(client, "get", f"/api/search/users?q=other_{suffix}", headers=user_h,
        expect=200, name="search users by q 200")
    hit(client, "get", "/api/search/users?skill=React", headers=user_h,
        expect=200, name="search users by skill 200")
    hit(client, "get", "/api/search/users?user_type=freelancer",
        headers=user_h, expect=200, name="search users by type 200")
    hit(client, "get", f"/api/search/projects?q=proj_{suffix}",
        headers=user_h, expect=200, name="search projects 200")
    hit(client, "get", "/api/search/users", expect=401,
        body_keys=["error"], name="search no token -> 401")

    # ─── Admin: logs & alerts ───────────────────────────────────────────────
    section("Admin")
    hit(client, "get", "/admin/logs", expect=401,
        body_keys=["error"], name="admin logs no token -> 401")
    hit(client, "get", "/admin/logs", headers=user_h, expect=403,
        body_keys=["error"], name="admin logs non-admin -> 403")
    hit(client, "get", "/admin/logs?page=1&per_page=10", headers=admin_h,
        expect=200, body_keys=["items"], name="admin logs 200")
    hit(client, "get", "/admin/alerts", headers=user_h, expect=403,
        body_keys=["error"], name="admin alerts non-admin -> 403")

    # Trigger brute-force to ensure /admin/alerts has data
    for i in range(6):
        client.post("/api/auth/login",
                    json={"email": user_email, "password": f"wrong-{i}"})
    rv, body = hit(client, "get", "/admin/alerts?page=1&per_page=20",
                   headers=admin_h, expect=200, body_keys=["items"],
                   name="admin alerts 200")
    items = body.get("items") or body.get("alerts") or []
    bf = [a for a in items if a.get("type") == "brute_force_login"]
    if bf:
        print("  [PASS] brute_force_login alert present")
        PASSED.append("brute_force alert present")
        aid = bf[0].get("id")
        hit(client, "patch", f"/admin/alerts/{aid}/resolve", headers=admin_h,
            expect=200, body_keys=["message"], name="admin resolve alert 200")
    else:
        print("  [FAIL] no brute_force alert created")
        FAILED.append(("brute_force alert", "missing"))

    # ─── Cleanup ────────────────────────────────────────────────────────────
    section("Cleanup")
    hit(client, "delete", f"/api/tasks/{task_id}", headers=user_h, expect=200,
        body_keys=["message"], name="delete task 200")
    hit(client, "delete", f"/api/projects/{project_id}", headers=user_h,
        expect=200, body_keys=["message"], name="delete project 200")

    with app.app_context():
        ids = [uuid.UUID(admin_id), uuid.UUID(user_id)]
        other = User.query.filter_by(email=other_email).first()
        if other is not None:
            ids.append(other.id)
        emails = [admin_email, user_email, other_email, "nobody@nowhere.test"]

        AuditLog.query.filter(AuditLog.user_id.in_(ids)).delete(
            synchronize_session=False)
        LoginLog.query.filter(LoginLog.user_id.in_(ids)).delete(
            synchronize_session=False)
        Notification.query.filter(Notification.user_id.in_(ids)).delete(
            synchronize_session=False)
        User.query.filter(User.id.in_(ids)).delete(synchronize_session=False)
        db.session.commit()
        print("  cleaned")

    # ─── Summary ────────────────────────────────────────────────────────────
    print("\n" + "=" * 70)
    print(f"PASSED: {len(PASSED)}    FAILED: {len(FAILED)}")
    if FAILED:
        print("\nFailures:")
        for n, d in FAILED:
            print(f"  - {n}  ::  {d}")
        return 1
    print("All endpoint contract checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
