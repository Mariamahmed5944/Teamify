"""Verify every documented HTTP status code in routes/auth.py.

Endpoints + status codes covered:
  POST /api/auth/register          201 / 400 / 409
  POST /api/auth/login             200 / 400 / 401
  GET  /api/auth/me                200 / 401 / 404
  POST /api/auth/refresh           200 / 401
  POST /api/auth/logout            200 / 401
  POST /api/auth/forgot-password   200 / 400
  POST /api/auth/verify-otp        200 / 400
  POST /api/auth/reset-password    200 / 400 / 401 / 404

Run: .\.venv\Scripts\python.exe test_auth_status_codes.py
"""
from __future__ import annotations

import datetime as _dt
import os
import secrets
import sys
import uuid

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app
from models import db
from models.user import User
from models.log import Log as AuditLog
from models.login_log import LoginLog
from flask_bcrypt import Bcrypt
from flask_jwt_extended import create_access_token


PASSED: list[str] = []
FAILED: list[tuple[str, str]] = []


def check(name: str, expected: int, got: int, body: str = "") -> None:
    ok = expected == got
    label = f"{name}  expected={expected} got={got}"
    if ok:
        print(f"  [PASS] {label}")
        PASSED.append(name)
    else:
        snippet = body[:200].replace("\n", " ")
        print(f"  [FAIL] {label}  body={snippet}")
        FAILED.append((name, f"expected={expected} got={got}"))


def check_body(name: str, rv, required_keys: list[str]) -> dict:
    """Assert the response body is JSON, contains every required key, and that
    each required value is non-empty (non-None, non-empty string/list/dict).
    Returns the parsed body so callers can pull tokens out of it.
    """
    raw = rv.get_data(as_text=True)
    body = rv.get_json(silent=True)
    if body is None:
        print(f"  [FAIL] {name} body is not JSON  raw={raw[:200]}")
        FAILED.append((name, "non-JSON body"))
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
    return body or {}


def section(title: str) -> None:
    print(f"\n=== {title} ===")


def post(client, path, *, json=None, headers=None):
    return client.post(path, json=json, headers=headers or {})


def get(client, path, *, headers=None):
    return client.get(path, headers=headers or {})


def main() -> int:
    app = create_app()
    # Disable rate limiting so dense, repeated calls don't return 429.
    from app import limiter as _limiter
    _limiter.enabled = False
    bcrypt = Bcrypt(app)
    client = app.test_client()
    suffix = secrets.token_hex(3)

    user_email = f"u_{suffix}@test.local"
    second_email = f"u2_{suffix}@test.local"
    password = "Passw0rd1"
    weak_password = "weak"

    # ─── Seed a known user so login/me/logout/refresh paths work ────────────
    section("Setup")
    with app.app_context():
        u = User(
            display_name=f"u_{suffix}",
            email=user_email,
            password=bcrypt.generate_password_hash(password).decode(),
            role="member",
        )
        db.session.add(u)
        db.session.commit()
        seeded_id = str(u.id)
    print(f"  seeded user_id={seeded_id}")

    # ─── /register ───────────────────────────────────────────────────────────
    section("POST /api/auth/register")
    valid_reg = {
        "display_name": f"new_{suffix}",
        "email": second_email,
        "password": password,
        "full_name": "New User",
        "role": "member",
        "user_type": "freelancer",
    }
    r = post(client, "/api/auth/register", json=valid_reg)
    check("register valid -> 201", 201, r.status_code, r.get_data(as_text=True))
    check_body("register valid body", r,
               ["message", "user", "access_token", "refresh_token"])

    r = post(client, "/api/auth/register", json={})
    check("register empty body -> 400", 400, r.status_code, r.get_data(as_text=True))
    check_body("register empty body has error", r, ["error"])

    r = post(client, "/api/auth/register", json={
        "display_name": f"x_{suffix}", "email": "not-an-email",
        "password": password})
    check("register bad email -> 400", 400, r.status_code, r.get_data(as_text=True))
    check_body("register bad email body", r, ["error", "messages"])

    r = post(client, "/api/auth/register", json={
        "display_name": f"y_{suffix}", "email": f"y_{suffix}@t.local",
        "password": weak_password})
    check("register weak password -> 400", 400, r.status_code, r.get_data(as_text=True))
    check_body("register weak password body", r, ["error", "messages"])

    # Duplicate email (same payload again)
    r = post(client, "/api/auth/register", json=valid_reg)
    check("register duplicate email -> 409", 409, r.status_code, r.get_data(as_text=True))
    check_body("register duplicate email body", r, ["error", "message"])

    # Duplicate display_name (different email)
    r = post(client, "/api/auth/register", json={
        **valid_reg, "email": f"dup_{suffix}@t.local"})
    check("register duplicate display_name -> 409", 409, r.status_code,
          r.get_data(as_text=True))
    check_body("register duplicate display_name body", r, ["error", "message"])

    # ─── /login ──────────────────────────────────────────────────────────────
    section("POST /api/auth/login")
    r = post(client, "/api/auth/login",
             json={"email": user_email, "password": password})
    check("login valid -> 200", 200, r.status_code, r.get_data(as_text=True))
    body = check_body("login valid body", r,
                      ["message", "user", "access_token", "refresh_token"])
    access = body.get("access_token", "")
    refresh = body.get("refresh_token", "")

    r = post(client, "/api/auth/login", json={})
    check("login empty body -> 400", 400, r.status_code, r.get_data(as_text=True))
    check_body("login empty body has error", r, ["error"])

    r = post(client, "/api/auth/login", json={"email": user_email})
    check("login missing password -> 400", 400, r.status_code,
          r.get_data(as_text=True))
    check_body("login missing password body", r, ["error"])

    r = post(client, "/api/auth/login",
             json={"email": user_email, "password": "WRONG-pass"})
    check("login wrong password -> 401", 401, r.status_code,
          r.get_data(as_text=True))
    check_body("login wrong password body", r, ["error"])

    r = post(client, "/api/auth/login",
             json={"email": "nobody@nowhere.tld", "password": password})
    check("login unknown email -> 401", 401, r.status_code,
          r.get_data(as_text=True))
    check_body("login unknown email body", r, ["error"])

    auth_h = {"Authorization": f"Bearer {access}"} if access else {}
    refr_h = {"Authorization": f"Bearer {refresh}"} if refresh else {}

    # ─── /me ─────────────────────────────────────────────────────────────────
    section("GET /api/auth/me")
    r = get(client, "/api/auth/me", headers=auth_h)
    check("me with token -> 200", 200, r.status_code, r.get_data(as_text=True))
    check_body("me with token body", r, ["user"])

    r = get(client, "/api/auth/me")
    check("me no token -> 401", 401, r.status_code, r.get_data(as_text=True))
    check_body("me no token body", r, ["error"])

    # 404: token whose subject (UUID) does not exist
    with app.app_context():
        ghost_token = create_access_token(identity=str(uuid.uuid4()))
    r = get(client, "/api/auth/me",
            headers={"Authorization": f"Bearer {ghost_token}"})
    check("me unknown user -> 404", 404, r.status_code, r.get_data(as_text=True))
    check_body("me unknown user body", r, ["error"])

    # ─── /refresh ────────────────────────────────────────────────────────────
    section("POST /api/auth/refresh")
    r = post(client, "/api/auth/refresh", headers=refr_h)
    check("refresh valid -> 200", 200, r.status_code, r.get_data(as_text=True))
    check_body("refresh valid body", r, ["access_token"])

    r = post(client, "/api/auth/refresh")
    check("refresh no token -> 401", 401, r.status_code, r.get_data(as_text=True))
    # JWT-Extended returns {"msg": ...} on missing tokens
    check_body("refresh no token body", r, ["msg"])

    # Sending an access token where a refresh token is required -> 401/422.
    # flask-jwt-extended returns 422 by default for the wrong token type, but
    # we accept either 401 or 422 here as both indicate authorization failure.
    r = post(client, "/api/auth/refresh", headers=auth_h)
    ok = r.status_code in (401, 422)
    label = f"refresh with access token -> 401/422 (got {r.status_code})"
    if ok:
        print(f"  [PASS] {label}")
        PASSED.append(label)
    else:
        print(f"  [FAIL] {label}  body={r.get_data(as_text=True)[:200]}")
        FAILED.append((label, str(r.status_code)))

    # ─── /logout ─────────────────────────────────────────────────────────────
    section("POST /api/auth/logout")
    # Need a fresh access token (refresh above may have cooled the previous).
    r = post(client, "/api/auth/login",
             json={"email": user_email, "password": password})
    access2 = (r.get_json() or {}).get("access_token", "")
    auth2_h = {"Authorization": f"Bearer {access2}"}
    r = post(client, "/api/auth/logout", headers=auth2_h)
    check("logout valid -> 200", 200, r.status_code, r.get_data(as_text=True))
    check_body("logout valid body", r, ["message"])

    r = post(client, "/api/auth/logout")
    check("logout no token -> 401", 401, r.status_code, r.get_data(as_text=True))
    check_body("logout no token body", r, ["msg"])

    # ─── /forgot-password ────────────────────────────────────────────────────
    section("POST /api/auth/forgot-password")
    r = post(client, "/api/auth/forgot-password", json={"email": user_email})
    check("forgot known email -> 200", 200, r.status_code, r.get_data(as_text=True))
    check_body("forgot known email body", r, ["message"])

    r = post(client, "/api/auth/forgot-password",
             json={"email": "ghost@nowhere.tld"})
    check("forgot unknown email -> 200 (no enumeration)", 200, r.status_code,
          r.get_data(as_text=True))
    check_body("forgot unknown email body", r, ["message"])

    r = post(client, "/api/auth/forgot-password", json={})
    check("forgot missing email -> 400", 400, r.status_code,
          r.get_data(as_text=True))
    check_body("forgot missing email body", r, ["error"])

    # ─── /verify-otp ─────────────────────────────────────────────────────────
    section("POST /api/auth/verify-otp")
    # Generate a real OTP for the seeded user, then verify it.
    with app.app_context():
        u = User.query.filter_by(email=user_email).first()
        otp_code = u.generate_otp()
        db.session.commit()
    r = post(client, "/api/auth/verify-otp",
             json={"email": user_email, "otp": otp_code})
    check("verify-otp valid -> 200", 200, r.status_code, r.get_data(as_text=True))
    body = check_body("verify-otp valid body", r, ["message", "reset_token"])
    reset_token = body.get("reset_token", "")

    r = post(client, "/api/auth/verify-otp", json={})
    check("verify-otp missing fields -> 400", 400, r.status_code,
          r.get_data(as_text=True))
    check_body("verify-otp missing fields body", r, ["error"])

    r = post(client, "/api/auth/verify-otp",
             json={"email": user_email, "otp": "000000"})
    check("verify-otp wrong code -> 400", 400, r.status_code,
          r.get_data(as_text=True))
    check_body("verify-otp wrong code body", r, ["error"])

    r = post(client, "/api/auth/verify-otp",
             json={"email": "ghost@nowhere.tld", "otp": "1234"})
    check("verify-otp unknown email -> 400", 400, r.status_code,
          r.get_data(as_text=True))
    check_body("verify-otp unknown email body", r, ["error"])

    # ─── /reset-password ─────────────────────────────────────────────────────
    section("POST /api/auth/reset-password")
    new_password = "Newpass1A"

    r = post(client, "/api/auth/reset-password", json={})
    check("reset-password missing fields -> 400", 400, r.status_code,
          r.get_data(as_text=True))
    check_body("reset-password missing fields body", r, ["error"])

    r = post(client, "/api/auth/reset-password",
             json={"reset_token": reset_token, "new_password": "weak"})
    check("reset-password weak new_password -> 400", 400, r.status_code,
          r.get_data(as_text=True))
    check_body("reset-password weak password body", r, ["error"])

    r = post(client, "/api/auth/reset-password",
             json={"reset_token": "garbage", "new_password": new_password})
    check("reset-password bad token -> 401", 401, r.status_code,
          r.get_data(as_text=True))
    check_body("reset-password bad token body", r, ["error"])

    # 401: a real JWT but without purpose=password_reset
    with app.app_context():
        wrong_purpose = create_access_token(identity=seeded_id)
    r = post(client, "/api/auth/reset-password",
             json={"reset_token": wrong_purpose, "new_password": new_password})
    check("reset-password wrong purpose -> 401", 401, r.status_code,
          r.get_data(as_text=True))
    check_body("reset-password wrong purpose body", r, ["error"])

    # 404: token with valid purpose but subject = unknown UUID
    with app.app_context():
        from flask_jwt_extended import create_access_token as _cat
        ghost_reset = _cat(
            identity=str(uuid.uuid4()),
            expires_delta=_dt.timedelta(minutes=5),
            additional_claims={"purpose": "password_reset"},
        )
    r = post(client, "/api/auth/reset-password",
             json={"reset_token": ghost_reset, "new_password": new_password})
    check("reset-password unknown user -> 404", 404, r.status_code,
          r.get_data(as_text=True))
    check_body("reset-password unknown user body", r, ["error"])

    # 200: valid reset (need a fresh token because we may have spent it)
    with app.app_context():
        u = User.query.filter_by(email=user_email).first()
        otp_code2 = u.generate_otp()
        db.session.commit()
    r = post(client, "/api/auth/verify-otp",
             json={"email": user_email, "otp": otp_code2})
    fresh_reset = (r.get_json() or {}).get("reset_token", "")
    r = post(client, "/api/auth/reset-password",
             json={"reset_token": fresh_reset, "new_password": new_password})
    check("reset-password valid -> 200", 200, r.status_code, r.get_data(as_text=True))
    check_body("reset-password valid body", r, ["message"])

    # ─── Cleanup ─────────────────────────────────────────────────────────────
    section("Cleanup")
    with app.app_context():
        emails = [user_email, second_email, f"dup_{suffix}@t.local",
                  f"y_{suffix}@t.local"]
        ids = [u.id for u in User.query.filter(User.email.in_(emails)).all()]
        if ids:
            AuditLog.query.filter(AuditLog.user_id.in_(ids)).delete(
                synchronize_session=False)
            LoginLog.query.filter(LoginLog.user_id.in_(ids)).delete(
                synchronize_session=False)
            User.query.filter(User.id.in_(ids)).delete(synchronize_session=False)
            db.session.commit()
        print(f"  removed {len(ids)} test users")

    # ─── Summary ─────────────────────────────────────────────────────────────
    print("\n" + "=" * 70)
    print(f"PASSED: {len(PASSED)}    FAILED: {len(FAILED)}")
    if FAILED:
        print("\nFailures:")
        for n, d in FAILED:
            print(f"  - {n}  ::  {d}")
        return 1
    print("All auth status-code checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
