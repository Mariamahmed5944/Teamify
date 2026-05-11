import pytest
from models.user import User
from models import db
from flask_jwt_extended import create_access_token

pytestmark = pytest.mark.integration

@pytest.fixture(autouse=True)
def clean_db(app):
    """Ensure the database is clean before each integration test."""
    with app.app_context():
        db.session.query(User).delete()
        db.session.commit()
        yield
        db.session.query(User).delete()
        db.session.commit()

@pytest.fixture
def admin_token(app):
    """Fixture to create an admin user and return a valid access token."""
    with app.app_context():
        admin_user = User(
            display_name="admin_user",
            email="admin@example.com",
            password="AdminPassword123",
            role="admin",
            account_status="approved",
            user_type="admin"
        )
        db.session.add(admin_user)
        db.session.commit()
        return create_access_token(identity=str(admin_user.id))

@pytest.fixture
def pending_user(app):
    """Fixture to create a pending freelancer user."""
    with app.app_context():
        user = User(
            display_name="freelancer_1",
            email="freelancer1@example.com",
            password="Password123",
            role="member",
            account_status="pending",
            user_type="freelancer"
        )
        db.session.add(user)
        db.session.commit()
        return user.id

class TestAdminAPIIntegration:
    def test_list_pending_users(self, client, admin_token, pending_user):
        """Test that admin can list pending users."""
        resp = client.get(
            "/admin/users/pending",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert resp.status_code == 200
        data = resp.get_json()
        assert data["total"] == 1
        assert data["items"][0]["display_name"] == "freelancer_1"
        assert data["items"][0]["account_status"] == "pending"

    def test_approve_user(self, client, admin_token, pending_user):
        """Test that admin can approve a pending user."""
        resp = client.patch(
            f"/admin/users/{pending_user}/approve",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert resp.status_code == 200
        data = resp.get_json()
        assert data["message"] == "User approved"
        assert data["user"]["account_status"] == "approved"

        # Verify DB updated
        with client.application.app_context():
            user = db.session.get(User, pending_user)
            assert user.account_status == "approved"

    def test_reject_user(self, client, admin_token, pending_user):
        """Test that admin can reject a pending user with a reason."""
        resp = client.patch(
            f"/admin/users/{pending_user}/reject",
            json={"reason": "Incomplete profile"},
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert resp.status_code == 200
        data = resp.get_json()
        assert data["message"] == "User rejected"
        assert data["user"]["account_status"] == "rejected"
        assert data["user"]["account_status_note"] == "Incomplete profile"

    def test_admin_access_denied_for_regular_user(self, client, pending_user):
        """Test that a regular user cannot access admin routes."""
        # Create a regular user and token
        with client.application.app_context():
            user = User(
                display_name="regular_user",
                email="regular@example.com",
                password="Password123",
                role="member",
                account_status="approved",
                user_type="student"
            )
            db.session.add(user)
            db.session.commit()
            user_token = create_access_token(identity=str(user.id))

        resp = client.get(
            "/admin/users/pending",
            headers={"Authorization": f"Bearer {user_token}"}
        )
        assert resp.status_code == 403
        assert resp.get_json()["message"] == "Admin access required."

    def test_analytics_overview(self, client, admin_token):
        """Test admin analytics overview endpoint."""
        resp = client.get(
            "/admin/analytics/overview",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert resp.status_code == 200
        data = resp.get_json()
        assert "users" in data
        assert "projects" in data
        assert "tasks" in data
