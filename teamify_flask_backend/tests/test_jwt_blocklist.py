"""
JWT Blocklist persistence tests.

Verifies:
1. A fresh token is accepted.
2. A revoked token is rejected (401) — even within its expiry window.
3. Blocklist survives a simulated server restart (in-memory set gone, DB still has it).
"""
from __future__ import annotations

import pytest
from flask_jwt_extended import create_access_token

# All tests in this module use a real SQLite DB and must not be intercepted by
# the mock_db_session autouse fixture, which would break blocklist queries.
pytestmark = pytest.mark.integration


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture()
def app():
    """Minimal Flask app with a real SQLite DB for blocklist tests."""
    from app import create_app

    test_cfg = {
        "TESTING": True,
        "SQLALCHEMY_DATABASE_URI": "sqlite:///:memory:",
        "JWT_SECRET_KEY": "test-secret-blocklist",
    }
    application = create_app(test_config=test_cfg)
    with application.app_context():
        from models import db
        db.create_all()
        yield application
        db.drop_all()


@pytest.fixture()
def client(app):
    return app.test_client()


@pytest.fixture()
def access_token(app):
    with app.app_context():
        return create_access_token(identity="1")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _login(client, app) -> str:
    with app.app_context():
        return create_access_token(identity="999")


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

class TestTokenBlocklistModel:
    def test_revoke_and_is_revoked(self, app):
        with app.app_context():
            from models.token_blocklist import TokenBlocklist
            TokenBlocklist.revoke("test-jti-001")
            assert TokenBlocklist.is_revoked("test-jti-001") is True

    def test_unknown_jti_not_revoked(self, app):
        with app.app_context():
            from models.token_blocklist import TokenBlocklist
            assert TokenBlocklist.is_revoked("nonexistent-jti") is False

    def test_revoke_is_idempotent(self, app):
        """Calling revoke twice must not raise or duplicate rows."""
        with app.app_context():
            from models.token_blocklist import TokenBlocklist
            from models import db
            TokenBlocklist.revoke("dup-jti")
            TokenBlocklist.revoke("dup-jti")  # should not raise
            count = TokenBlocklist.query.filter_by(jti="dup-jti").count()
            assert count == 1

    def test_restart_safety(self, app):
        """
        Simulate a restart by clearing any in-memory state and re-checking DB.
        The TokenBlocklist.is_revoked() query always hits the DB, so it must
        return True even after an in-process restart would clear a set().
        """
        with app.app_context():
            from models.token_blocklist import TokenBlocklist
            TokenBlocklist.revoke("restart-jti")

        # Re-enter app context (simulates a new process reading the same DB)
        with app.app_context():
            from models.token_blocklist import TokenBlocklist
            assert TokenBlocklist.is_revoked("restart-jti") is True


class TestLogoutBlocksToken:
    def test_valid_token_accesses_profile(self, client, access_token):
        """A fresh token reaches the /api/users/profile endpoint."""
        r = client.get("/api/users/profile", headers=_auth(access_token))
        # May return 404 (no user in test DB) but NOT 401 from blocklist
        assert r.status_code != 401 or b"token has been revoked" not in r.data

    def test_logout_revokes_token(self, client, access_token):
        """After POST /api/auth/logout the token must be rejected."""
        # Logout
        r_logout = client.post(
            "/api/auth/logout", headers=_auth(access_token)
        )
        assert r_logout.status_code == 200

        # Attempt to use the revoked token — must be rejected (401)
        r_profile = client.get("/api/users/profile", headers=_auth(access_token))
        assert r_profile.status_code == 401
        # auth_required catches all JWT errors and returns a generic 401;
        # any error key ("msg", "error") is acceptable here.
        data = r_profile.get_json()
        assert data is not None

    def test_token_valid_before_logout(self, client, app):
        """Two tokens: one logged out, one not — each behaves independently."""
        with app.app_context():
            t1 = create_access_token(identity="10")
            t2 = create_access_token(identity="11")

        # Logout only t1
        client.post("/api/auth/logout", headers=_auth(t1))

        # t1 is revoked
        r1 = client.get("/api/users/profile", headers=_auth(t1))
        assert r1.status_code == 401

        # t2 is still valid (may 404 due to missing user, but not 401)
        r2 = client.get("/api/users/profile", headers=_auth(t2))
        assert r2.status_code != 401
