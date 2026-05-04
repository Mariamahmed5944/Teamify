import pytest
from models.user import User
from models import db
from flask_jwt_extended import decode_token
from unittest.mock import patch, MagicMock

pytestmark = pytest.mark.integration

@pytest.fixture(autouse=True)
def clean_db(app, _db):
    """
    Ensure the database is clean before each integration test.
    We delete all users instead of recreating tables to be faster.
    """
    with app.app_context():
        db.session.query(User).delete()
        db.session.commit()
        yield
        db.session.query(User).delete()
        db.session.commit()

class TestAuthAPIIntegration:
    """Step 2 & 3: Integration and API Testing for Auth Routes hitting the real SQLite DB."""
    
    def test_full_registration_and_login_flow(self, client):
        """Test the end-to-end flow of registering a user and then logging in."""
        # 1. Register a new user
        reg_payload = {
            "display_name": "int_user",
            "email": "int@example.com",
            "password": "Password123",
            "role": "member",
            "user_type": "freelancer"
        }
        resp = client.post("/api/auth/register", json=reg_payload)
        
        assert resp.status_code == 201
        data = resp.get_json()
        assert data["message"] == "User registered successfully"
        assert "access_token" in data
        
        # Verify DB insertion
        user = User.query.filter_by(email="int@example.com").first()
        assert user is not None
        assert user.display_name == "int_user"
        
        # 2. Login with the new user (should fail because freelancer is pending)
        login_payload = {
            "email": "int@example.com",
            "password": "Password123"
        }
        resp = client.post("/api/auth/login", json=login_payload)
        assert resp.status_code == 403
        
        # 3. Approve the user manually in the DB
        with client.application.app_context():
            user = User.query.filter_by(email="int@example.com").first()
            user.account_status = "approved"
            db.session.commit()

        # 4. Login again (should succeed now)
        resp = client.post("/api/auth/login", json=login_payload)
        assert resp.status_code == 200
        data = resp.get_json()
        assert "access_token" in data
        assert data["user"]["email"] == "int@example.com"

    def test_registration_duplicate_email(self, client):
        """Test that registering with an existing email correctly returns 409 Conflict."""
        payload = {
            "display_name": "user1",
            "email": "dup@example.com",
            "password": "Password123"
        }
        # First registration succeeds
        resp1 = client.post("/api/auth/register", json=payload)
        assert resp1.status_code == 201
        
        # Second registration with same email fails
        payload["display_name"] = "user2"  # Change display name to isolate email conflict
        resp2 = client.post("/api/auth/register", json=payload)
        assert resp2.status_code == 409
        assert resp2.get_json()["message"] == "Email already exists"

    def test_login_invalid_credentials(self, client):
        """Test login fails properly with non-existent user or wrong password."""
        # Unregistered user
        resp = client.post("/api/auth/login", json={
            "email": "nobody@example.com",
            "password": "Password123"
        })
        assert resp.status_code == 401
        
        # Register a user
        client.post("/api/auth/register", json={
            "display_name": "wrongpass",
            "email": "wrongpass@example.com",
            "password": "Password123"
        })
        
        # Login with wrong password
        resp = client.post("/api/auth/login", json={
            "email": "wrongpass@example.com",
            "password": "WrongPassword1"
        })
        assert resp.status_code == 401

    def test_get_me_endpoint_with_real_token(self, client):
        """Test the /me endpoint using a freshly generated JWT token."""
        # Register to get token
        resp = client.post("/api/auth/register", json={
            "display_name": "me_user",
            "email": "me@example.com",
            "password": "Password123"
        })
        token = resp.get_json()["access_token"]
        
        # Access /me endpoint
        me_resp = client.get(
            "/api/auth/me",
            headers={"Authorization": f"Bearer {token}"}
        )
        assert me_resp.status_code == 200
        assert me_resp.get_json()["user"]["email"] == "me@example.com"
        
    def test_unauthorized_access(self, client):
        """Test that protected endpoints reject requests without a token."""
        resp = client.get("/api/auth/me")
        assert resp.status_code == 401

    @patch("requests.get")
    @patch("requests.post")
    def test_github_login(self, mock_post, mock_get, client):
        """Test GitHub OAuth login flow."""
        # Mock the token response
        mock_token_resp = MagicMock()
        mock_token_resp.status_code = 200
        mock_token_resp.json.return_value = {"access_token": "gho_fake_token"}

        # Mock the profile response
        mock_profile_resp = MagicMock()
        mock_profile_resp.status_code = 200
        mock_profile_resp.json.return_value = {
            "id": 123456,
            "login": "testghuser",
            "name": "Test GitHub User",
            "email": "github@example.com"
        }

        mock_post.return_value = mock_token_resp
        mock_get.return_value = mock_profile_resp

        # Perform the request
        payload = {"code": "fake_oauth_code"}
        resp = client.post("/api/auth/github", json=payload)
        
        assert resp.status_code == 200
        data = resp.get_json()
        assert data["message"] == "GitHub login successful"
        assert "access_token" in data
        assert data["user"]["github_id"] == "123456"
        assert data["user"]["email"] == "github@example.com"
        assert data["user"]["account_status"] == "approved"
        
        # Verify user was created in DB
        with client.application.app_context():
            user = User.query.filter_by(github_id="123456").first()
            assert user is not None
            assert user.email == "github@example.com"
            assert user.role == "member"
