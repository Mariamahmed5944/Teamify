import pytest
import datetime
from freezegun import freeze_time
from models import db
from models.user import User
from models.login_log import LoginLog

pytestmark = pytest.mark.integration

class TestSecurityIntegration:
    """Step 6: Security Testing (Brute-Force, XSS, and Audit Logging)."""

    @pytest.fixture(autouse=True)
    def clean_db(self, app, _db):
        with app.app_context():
            db.session.query(LoginLog).delete()
            db.session.query(User).delete()
            db.session.commit()
            yield
            db.session.query(LoginLog).delete()
            db.session.query(User).delete()
            db.session.commit()

    @pytest.fixture
    def setup_target_user(self, client):
        client.post("/api/auth/register", json={
            "display_name": "target_user",
            "email": "target@example.com",
            "password": "CorrectPassword1"
        })

    def test_brute_force_lockout(self, client, setup_target_user):
        """Verify that 5 failed logins lock the account, returning 429."""
        payload = {"email": "target@example.com", "password": "WrongPassword1"}

        # Attempt 1-5 (Should return 401 Unauthorized)
        for i in range(5):
            resp = client.post("/api/auth/login", json=payload)
            # The 5th attempt triggers the lockout, but wait, the auth.py route says:
            # if user.failed_login_attempts >= MAX_FAILED_ATTEMPTS: return 429
            # Wait, the 5th failure returns 429 directly because it increments BEFORE checking.
            if i < 4:
                assert resp.status_code == 401
            else:
                assert resp.status_code == 429
                assert "locked" in resp.get_json()["message"].lower()

        # Attempt 6 (Should return 429 Too Many Requests immediately because locked_until is set)
        resp6 = client.post("/api/auth/login", json=payload)
        assert resp6.status_code == 429

        # Use freezegun to jump 16 minutes into the future (lockout is 15 minutes)
        with freeze_time(datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(minutes=16)):
            # Attempt login with correct password
            resp_success = client.post("/api/auth/login", json={
                "email": "target@example.com",
                "password": "CorrectPassword1"
            })
            # Lockout expired, so it should succeed
            assert resp_success.status_code == 200

    def test_xss_and_payload_sanitization(self, client):
        """Verify that malicious XSS payloads in string fields are stripped out."""
        malicious_payload = {
            "display_name": "<script>alert('XSS')</script>hacker",
            "email": "hacker@example.com",
            "password": "Password1",
            "reason_for_joining": "I want to <img src=x onerror=alert(1)> hack."
        }
        resp = client.post("/api/auth/register", json=malicious_payload)
        
        # It should succeed but the tags should be stripped
        assert resp.status_code == 201
        data = resp.get_json()["user"]
        
        # `<script>alert('XSS')</script>` becomes `alert('XSS')hacker`
        assert "script" not in data["display_name"]
        assert "img" not in data["reason_for_joining"]
        assert data["display_name"] == "alert('XSS')hacker"

    def test_json_audit_logging_brute_force(self, client, setup_target_user):
        """Verify that the brute-force failures are properly recorded in the audit/log tables."""
        payload = {"email": "target@example.com", "password": "WrongPassword1"}

        # Attempt 5 times
        for _ in range(5):
            client.post("/api/auth/login", json=payload)

        # Check LoginLog database table
        user = User.query.filter_by(email="target@example.com").first()
        logs = LoginLog.query.filter_by(user_id=user.id).all()
        
        # The 5th attempt triggers an early 429 return in the route, so only 4 standard fail logs are recorded before lockout
        assert len(logs) == 4
        for log in logs:
            assert log.status == "fail"

        # Check the JSON audit log file
        import os
        import json
        log_file_path = os.path.join(os.getcwd(), "logs", "security.log")
        assert os.path.exists(log_file_path), "Security log file was not created"

        lockout_found = False
        with open(log_file_path, "r") as f:
            for line in f:
                if not line.strip():
                    continue
                try:
                    record = json.loads(line)
                    if record.get("action") == "ACCOUNT_LOCKED" and record.get("user_id") == user.id:
                        lockout_found = True
                        assert "attempts" in record.get("details", {})
                        break
                except json.JSONDecodeError:
                    pass
        
        assert lockout_found, "ACCOUNT_LOCKED event was not found in the JSON audit log"
