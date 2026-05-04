import pytest
from models import db
from models.user import User

pytestmark = pytest.mark.integration

class TestTOTP2FAIntegration:
    """Step 5: Advanced Authentication - TOTP 2FA Verification."""

    @pytest.fixture(autouse=True)
    def clean_db(self, app, _db):
        with app.app_context():
            db.session.query(User).delete()
            db.session.commit()
            yield
            db.session.query(User).delete()
            db.session.commit()

    @pytest.fixture
    def setup_2fa_user(self, client):
        """Register a user and initiate 2FA setup to get the secret."""
        # Register
        client.post("/api/auth/register", json={
            "display_name": "totp_user",
            "email": "totp@example.com",
            "password": "Password123"
        })
        # Login to get token
        resp = client.post("/api/auth/login", json={
            "email": "totp@example.com",
            "password": "Password123"
        })
        token = resp.get_json()["access_token"]

        # Call /2fa/setup
        setup_resp = client.post("/api/auth/2fa/setup", headers={"Authorization": f"Bearer {token}"})
        assert setup_resp.status_code == 200
        secret = setup_resp.get_json()["secret"]

        return {"token": token, "secret": secret}

    def test_2fa_verification_success(self, client, setup_2fa_user):
        """Verify that a valid TOTP code correctly enables 2FA."""
        import pyotp
        token = setup_2fa_user["token"]
        secret = setup_2fa_user["secret"]

        # Generate a valid TOTP code using the secret
        totp = pyotp.TOTP(secret)
        valid_code = totp.now()

        # Call /2fa/verify
        resp = client.post(
            "/api/auth/2fa/verify",
            headers={"Authorization": f"Bearer {token}"},
            json={"token": valid_code}
        )
        
        assert resp.status_code == 200
        assert resp.get_json()["message"] == "2FA verified successfully. Two-factor authentication is now active."

        # Ensure DB state is updated
        user = User.query.filter_by(email="totp@example.com").first()
        assert user.totp_enabled is True

    def test_2fa_verification_failure(self, client, setup_2fa_user):
        """Verify that an invalid TOTP code is rejected with 400."""
        token = setup_2fa_user["token"]

        # Provide an invalid code
        resp = client.post(
            "/api/auth/2fa/verify",
            headers={"Authorization": f"Bearer {token}"},
            json={"token": "000000"}  # Highly likely invalid
        )
        
        assert resp.status_code == 400
        assert resp.get_json()["error"] == "Invalid or expired TOTP token"

        # Ensure DB state reflects failure
        user = User.query.filter_by(email="totp@example.com").first()
        assert user.totp_enabled is False

    def test_2fa_setup_conflict(self, client, setup_2fa_user):
        """Verify that /2fa/setup returns 409 if 2FA is already enabled."""
        import pyotp
        token = setup_2fa_user["token"]
        secret = setup_2fa_user["secret"]

        # Verify once to enable it
        valid_code = pyotp.TOTP(secret).now()
        client.post(
            "/api/auth/2fa/verify",
            headers={"Authorization": f"Bearer {token}"},
            json={"token": valid_code}
        )

        # Try to setup again
        setup_resp = client.post("/api/auth/2fa/setup", headers={"Authorization": f"Bearer {token}"})
        assert setup_resp.status_code == 409
        assert setup_resp.get_json()["message"] == "2FA is already enabled for this account."

    def test_2fa_disable_success(self, client, setup_2fa_user):
        """Verify that 2FA can be disabled by providing a valid code."""
        import pyotp
        token = setup_2fa_user["token"]
        secret = setup_2fa_user["secret"]
        totp = pyotp.TOTP(secret)

        # Enable it
        client.post(
            "/api/auth/2fa/verify",
            headers={"Authorization": f"Bearer {token}"},
            json={"token": totp.now()}
        )

        # Disable it
        resp = client.delete(
            "/api/auth/2fa/disable",
            headers={"Authorization": f"Bearer {token}"},
            json={"token": totp.now()}
        )
        assert resp.status_code == 200
        assert resp.get_json()["message"] == "Two-factor authentication has been disabled."

        user = User.query.filter_by(email="totp@example.com").first()
        assert user.totp_enabled is False
        assert user.totp_secret is None
